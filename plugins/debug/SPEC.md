# cURL Debug - Plugin Specification

## Overview

cURL 한 줄로 API 응답에서 코드 원인까지 역추적하는 스킬. 응답에서 시그널을 추출하고, **가장 강한 시그널부터 따라가며** 버그 원인을 찾는다. 원인을 설명할 수 있으면 멈춘다.

---

## Core: Signal-Driven Routing

### 기존 접근의 문제

모든 버그를 "라우터 → 핸들러 → 서비스 → 모델" 순으로 추적하면, stack trace가 있는 500 에러에서도 라우터부터 찾아야 하고, 422 validation 에러에서도 핸들러를 거쳐야 한다. 개발자는 이렇게 하지 않는다 — stack trace가 있으면 바로 그 파일을 열고, validation 에러면 에러 메시지를 grep한다.

### 시그널 우선순위

응답과 요청에서 추출한 시그널을 아래 우선순위로 따라간다. **각 단계 후 멈출 수 있는지 확인한다.**

| 우선순위 | 시그널 | 진입점 | 추적 방향 |
|---------|--------|--------|-----------|
| **1** | Stack trace | 파일:라인 직접 접근 | 해당 함수의 맥락 → 호출 체인 확인 |
| **2** | Error message | 에러 문자열로 코드베이스 검색 | 발생 지점 → schema/validation 레이어로 |
| **3** | Error code/type | 상수/enum 정의 검색 | 정의 → 사용처 → 발생 조건 |
| **4** | URL path | 라우트 정의 검색 | 라우터 → 핸들러 → 서비스 체인 |
| **5** | Request body 필드명 | 스키마/타입 정의 검색 | 타입 정의 → validation 규칙 → 값 불일치 |
| **6** | Response body 구조 | DTO/직렬화 코드 검색 | 직렬화 → DB 쿼리 → 데이터 매핑 |

이 우선순위가 분류를 대체한다:
- 422 + 명확한 에러 메시지 → 우선순위 2에서 바로 해결
- 500 + stack trace → 우선순위 1에서 즉시 해결
- Opaque 500 → 1~3 실패, 4로 진입 → 전체 체인 추적 필요
- 200 + 데이터 이상 → 1~4 의미 없음, 5~6에서 해결

### 멈춤 조건

다음 **3가지를 모두** 답할 수 있으면 추적을 멈춘다:

1. **무엇이** 잘못되었는가 (증상의 기술적 원인)
2. **어디서** 발생하는가 (파일:라인)
3. **왜** 발생하는가 (근본 원인)

하나라도 답하지 못하면 다음 우선순위 시그널로 진행한다.

### Short-Circuit Rules

시그널 추적을 시작하기 전에 확인하는 특수 조건. 해당되면 일반 우선순위 흐름을 건너뛴다.

| 조건 | 동작 | 이유 |
|------|------|------|
| **401/403** | 코드 추적 전에 토큰 갱신 재시도를 먼저 제안. 재시도 후에도 실패하면 auth 미들웨어 추적 | 대부분 만료된 토큰이지 코드 버그가 아님 |
| **404** | 라우트 등록만 확인. 핸들러/서비스 추적 안 함 | 요청이 핸들러에 도달하지 않았으므로 |
| **2xx + 데이터 이상** | 예상 response를 사용자에게 물어봄 → diff를 시그널로 활용 | 에러 시그널이 없어서 diff가 유일한 단서 |
| **406/415** | request headers와 서버 파서/미들웨어 설정 비교 | 핸들러까지 도달하지 않는 파서 레벨 거부 |
| **네트워크 에러** | 서버 상태 확인 제안 + URL path로 코드 추적은 수행 | 서버가 죽어도 코드는 존재 |

### 병렬 탐색 기준

시그널 우선순위 1~3이 **모두 실패**하여 진입점이 URL path(우선순위 4)뿐인 경우 → Subagent 병렬 탐색:
- **Agent A**: URL path → 라우터 → 핸들러 → 서비스 체인 추적
- **Agent B**: Request body 필드명 → 모델/스키마 추적

그 외에는 순차 추적. 우선순위 1~3 시그널이 있으면 1~2단계로 끝나므로 병렬이 불필요.

---

## Procedure

### Step 1: 실행

사용자의 raw cURL을 Bash로 실행하고, status code/headers/body/응답 시간을 캡처한다.

원본 cURL에 `-s -w '\n%{http_code}\n%{time_total}' -i`를 추가하되, 이미 있는 플래그는 중복 추가하지 않는다.

### Step 2: 분석 & 라우팅

응답에서 시그널을 추출하고, short-circuit rules를 확인한 뒤, 시그널 우선순위에 따라 추적 경로를 결정한다.

**시그널 추출 체크리스트**:
- JSON body → error/message/detail/code/stack 필드
- HTML body → title/h1, 프레임워크 에러 페이지 패턴
- 예상 response 제공 시 → diff 분석, 차이 필드를 추가 시그널로

**항상 분석한다** — 2xx여도. 이 스킬이 호출된 것 자체가 "무언가 기대와 다르다"는 의미.

### Step 3: 추적

결정된 경로대로 코드베이스를 추적한다. **단계별로 실시간 출력**한다 (완료 후 일괄 출력 아님).

**추적 시 핵심 원칙**:

- **URL path 검색**: 변별력 높은 segment부터 (`orders` > `api`). path param(숫자, UUID)은 와일드카드로 일반화. HTTP method와 결합하여 정밀도 향상
- **에러 메시지 검색**: 의미 단위로 분절하여 검색. error code가 있으면 enum/constant 정의를 먼저
- **Body 필드 → 스키마**: 타입 정의(DTO, interface, Zod, Pydantic 등)를 찾고, 실제 전송 값과의 불일치에 주목
- **라우트 → 핸들러 체인**: import/require를 따라가며 함수 호출 체인 추적
- **404 특화**: "왜 매칭 안 되는가"에 초점 — 미등록, 오타, 라우트 순서, 미들웨어 차단
- **Stack trace**: 프레임워크 내부 프레임은 건너뛰고 사용자 코드의 첫 프레임에서 시작

**매 단계마다 멈춤 조건 체크**: 무엇이/어디서/왜 — 3가지 모두 답할 수 있으면 Step 4로.

### Step 4: 보고 & 후속 액션

**출력 구성**:

1. **요청/응답 요약** — method, URL, status code, 응답 시간, 핵심 에러
2. **코드 추적 경로** — 실제 추적한 경로를 `파일:라인 → 함수명` 형식으로
3. **버그 원인** — 무엇이 잘못되었고, 어디서, 왜 (멈춤 조건의 3가지)
4. **수정 제안** — 여러 옵션 + 각각의 트레이드오프. 정확한 파일:라인 포함. 수정을 직접 적용하지는 않음

**후속 액션**: AskUserQuestion으로 상황에 맞는 옵션을 동적 구성:

| 옵션 | 조건 | 동작 |
|------|------|------|
| 파라미터 변경 후 재시도 | 항상 | 값 입력받고 Step 1부터 재수행 |
| 수정 제안 상세 보기 | 수정 옵션이 여러 개일 때 | 선택된 옵션의 코드 변경 상세 출력 |
| 관련 코드 더 탐색 | 항상 | 호출 체인 확장 (caller/callee) |
| 예상 response 입력 | 2xx이고 예상값 미제공 시 | diff 분석으로 추가 추적 |
| 서버 로그 제공 | 시그널 1~3 모두 실패 시 | 사용자에게 로그 경로/내용 입력 요청 |
| 새 토큰으로 재시도 | 401/403일 때 | 인증 정보 갱신 후 재실행 |
| 헤더 변경 후 재시도 | 406/415일 때 | Content-Type 등 수정 후 재실행 |
| 종료 | 항상 | — |

---

## Triggering

### 명시적 호출
`/curl-debug`로 직접 호출. cURL 문자열은 `$ARGUMENTS`로 전달.

### 자동 감지
사용자 메시지에 다음 조건이 **모두** 충족될 때:
1. `curl ` 명령어가 포함됨 (실제 cURL 커맨드)
2. 버그/에러/예상과 다른 동작에 대한 질문이 함께 있음

**description**:
```
Execute a cURL command and trace the response back through the codebase to find
the root cause of bugs. TRIGGER when: user shares a cURL command along with a
question about a bug, error, or unexpected behavior (e.g., "이 curl 요청이 500
에러가 나는데 왜 그런지 봐줘", "curl로 보내면 잘못된 데이터가 오는데",
"이 API가 왜 이렇게 응답하는지 코드에서 찾아줘"). Also trigger with
/curl-debug slash command. DO NOT TRIGGER when: user is just asking to execute
a cURL without debugging intent, discussing cURL syntax, or sharing cURL for
documentation purposes.
```

---

## Plugin Structure

```
plugins/debug/
├── .claude-plugin/
│   └── plugin.json
├── SPEC.md                          # 이 문서
└── skills/
    └── curl-debug/
        └── SKILL.md                 # /curl-debug 스킬 프롬프트
```

---

## Configuration

`plugin.json`:

```json
{
  "name": "debug",
  "description": "API debugging tools — execute cURL requests and trace bugs through the codebase",
  "version": "2026.03"
}
```

---

## Design Decisions

### 분류 테이블 대신 시그널 우선순위를 쓰는 이유
7가지 분류 × 개별 전략이라는 이중 참조 구조는 LLM에게 불필요한 인지 단계를 만든다. 시그널 우선순위는 단일 테이블 하나로 "무엇을 먼저 하는가"를 결정하며, 분류가 자연스럽게 창발된다: 422는 우선순위 2(에러 메시지)에서 해결되고, opaque 500은 우선순위 4(URL path)까지 내려가 전체 체인을 추적하게 된다. 동일한 결과를 더 적은 구조로 달성한다.

### 멈춤 조건을 명시하는 이유
"무엇이/어디서/왜"라는 3가지 기준 없이는 LLM이 과잉 추적(이미 원인을 찾았는데 계속 탐색)하거나 과소 추적(코드 위치만 찾고 근본 원인을 설명하지 않음)한다. 멈춤 조건이 추적의 깊이를 자가 조절한다.

### LLM이 아는 것은 쓰지 않는 이유
cURL 파싱 방법, grep 사용법, import 추적 방법, JSON 파싱 — 이런 것을 스킬에 적으면 실제 지침(시그널 우선순위, short-circuit, 멈춤 조건)이 희석된다. 스킬은 **LLM이 모르는 판단 기준**만 담아야 한다.

### Bash 실행 위임
cURL 옵션 조합은 무한(`--data-raw`, `--data-binary`, `@file`, `--form` 등). 직접 파싱보다 Bash에 실행을 위임하고 분석에 필요한 요소만 별도 추출하는 것이 안정적.

### 보안: 민감 정보 그대로 처리
Authorization 헤더나 Cookie를 마스킹하면 요청이 실패하여 디버깅 불가. 로컬 환경이므로 보안 책임은 사용자에게.

---

## Future Considerations (v2+)

> 현재 스펙 범위 밖. 추후 확장 참고용.

- **HAR 파일 입력**: 여러 요청 일괄 분석
- **자동 변주 테스트**: 파라미터 자동 변경하며 버그 경계 조건 좁히기
- **OpenAPI/Swagger 연동**: API 스펙과 실제 응답 자동 비교
- **서버 로그 연동**: request-id로 서버 로그 매칭
