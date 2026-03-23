# Session Harvester - Plugin Specification

## Overview

세션 중 반복된 작업 패턴을 자동 감지하고, 재사용 가능한 스킬(Skill), 서브에이전트(Subagent), Hook으로 변환하는 것을 제안하는 Claude Code 플러그인.

## Problem Statement

Claude Code 사용 중 같은 유형의 작업을 반복하는 경우가 많다. 예를 들어 "특정 패턴의 파일을 찾아서 수정", "테스트 실행 후 실패 시 수정" 등의 워크플로우가 세션마다 반복되지만, 이를 재사용 가능한 형태로 만드는 것은 수동 작업이다. 이 플러그인은 이 과정을 자동화한다.

---

## Architecture

### 트리거 시점

세션 종료 시 `SessionEnd` hook이 로그 분석과 패턴 요약을 수행한다. 단, **`SessionEnd` hook은 셸 스크립트로 실행되므로 사용자에게 대화형 리포트를 표시할 수 없다.** 따라서 다음과 같은 2단계 흐름을 사용한다:

1. **세션 종료 시** (`SessionEnd` hook): 로그 분석 → 패턴 요약 저장 → 원본 로그 삭제
2. **다음 세션 시작 시** (`SessionStart` hook): 보류 중인 분석 결과가 있으면 컨텍스트에 주입
   ```
   [Session Harvester] 지난 세션에서 3개의 반복 패턴이 감지되었습니다.
   `/harvest`를 실행하여 확인하세요.
   ```
3. **사용자가 `/harvest` 실행**: 상세 리포트 표시 → 생성할 항목 선택 → craft:skill-creator에 위임

이 방식의 이점:
- 세션 종료 시 사용자를 붙잡지 않음 (자연스러운 흐름)
- 분석이 타임아웃 없이 충분히 수행 가능
- 다음 세션 시작이 자연스러운 온보딩 지점

### 데이터 수집 방식: Hook 기반 로깅

Claude Code의 Hook 시스템을 활용하여 세션 중 발생하는 이벤트를 구조화된 로그로 기록한다.

#### Hook 이벤트 매핑

| Hook Event | 수집 데이터 | 용도 |
|------------|------------|------|
| `SessionStart` | session_id, cwd | 로그 파일 초기화, 보류 분석 결과 알림 |
| `UserPromptSubmit` | prompt | 사용자 의도 캡처 |
| `PreToolUse` | tool_name, tool_input | 도구 호출 시퀀스 기록 |
| `PostToolUse` | tool_name, tool_input | 성공한 도구 호출 확인 |
| `PostToolUseFailure` | tool_name, error | 실패 패턴 추적 (재시도 루프 감지) |
| `SessionEnd` | reason | 로그 분석 트리거 |

#### 수집 데이터 범위

| 데이터 | 수집 | 설명 |
|--------|------|------|
| 도구 이름 | O | 사용된 도구 식별자 (Read, Edit, Grep 등) |
| 도구 파라미터 | O | 파일 경로, 검색 패턴 등 (마스킹 후 저장) |
| 타임스탬프 | O | 도구 호출 시점 |
| 사용자 프롬프트 | O | 사용자의 자연어 요청 원문 (마스킹 후 저장) |
| 도구 결과 | X | 크기가 크고 민감 정보 포함 가능성이 높아 제외 |
| 도구 실패 메시지 | O | 재시도 패턴 감지에 필요 |

#### 로그 레코드 구조

모든 이벤트는 `$CLAUDE_PLUGIN_DATA/sessions/<session_id>.jsonl`에 JSON Lines로 저장한다:

```jsonc
// UserPromptSubmit
{"ts": 1711152000, "event": "prompt", "prompt": "src/api에서 GET 엔드포인트를 추가해줘"}

// PreToolUse
{"ts": 1711152001, "event": "tool", "tool": "Grep", "input": {"pattern": "router.get", "path": "src/api/"}}

// PostToolUseFailure
{"ts": 1711152005, "event": "tool_error", "tool": "Bash", "error": "exit code 1"}
```

#### 보안: 인라인 마스킹

로그 저장 시 `logger.sh` 내에서 `sed` 기반으로 민감 정보를 마스킹한다. Python 프로세스를 매번 기동하지 않아 성능 부담이 없다.

마스킹 대상 패턴:
- API 키: `sk-[a-zA-Z0-9]+`, `api[_-]?key[=:]\s*\S+`
- 토큰: `Bearer\s+\S+`, `token[=:]\s*\S+`
- 비밀번호: `password[=:]\s*\S+`, `secret[=:]\s*\S+`
- 환경 변수 값: `[A-Z_]*(KEY|SECRET|TOKEN|PASSWORD)[=:]\s*\S+`
- 사용자 정의 패턴: 설정의 `masking_patterns`에 추가 가능

모든 매칭은 `[REDACTED]`로 치환된다.

#### 로그 라이프사이클

```
[세션 중]
  이벤트 발생 → logger.sh → sed 마스킹 → $CLAUDE_PLUGIN_DATA/sessions/<session_id>.jsonl

[세션 종료 시] (SessionEnd hook)
  session.jsonl → harvest-analyze.sh (LLM 없이 구조적 분석)
               → 패턴 요약을 $CLAUDE_PLUGIN_DATA/patterns.jsonl에 누적
               → session.jsonl 삭제

[다음 세션 시작 시] (SessionStart hook)
  patterns.jsonl 확인 → 보류 중인 미제안 패턴이 있으면 컨텍스트에 알림 주입
```

---

## Pattern Detection

### 분석 전략: 구조적 전처리 + LLM 의미 분석

패턴 감지를 두 단계로 나눈다:

**1단계: 구조적 전처리** (`harvest-analyze.sh`, SessionEnd hook에서 실행)

셸 스크립트로 수행 가능한 경량 분석:
- 도구 호출 시퀀스를 문자열로 변환 (예: `G-R-E-B` = Grep→Read→Edit→Bash)
- 동일 시퀀스 패턴의 출현 빈도 카운트 (`sort | uniq -c`)
- 실패→재시도 루프 감지 (tool_error 직후 동일 tool 재호출)
- 파일 경로에서 glob 패턴 추출 (`src/api/*.ts` 등)
- 결과를 JSON으로 `$CLAUDE_PLUGIN_DATA/pending_analysis.json`에 저장

**2단계: LLM 의미 분석** (`harvest` 스킬, 사용자가 `/harvest` 실행 시)

LLM이 잘하는 고수준 분석:
- 사용자 프롬프트에서 의도 클러스터링 (의미적으로 유사한 요청 그룹화)
- 도구 시퀀스 + 프롬프트를 종합하여 "워크플로우" 단위로 추상화
- 변수 부분과 고정 부분 분리 (파라미터화)
- 기존 스킬과의 유사도 판단
- 누적된 패턴 요약과 현재 세션 패턴의 교차 분석

이 2단계 분리의 이점:
- SessionEnd hook에서 LLM 호출 없이 빠르게 완료 (타임아웃 안전)
- 의미적 분석은 사용자가 `/harvest`를 실행할 때 대화형으로 수행
- Python 의존성 제거 (셸 스크립트 + jq만으로 1단계 완료)

### 복합 휴리스틱 차원

#### 1. 도구 호출 시퀀스 유사도

```
예: Grep → Read → Edit → Bash(test) 패턴이 3회 반복
    → 시퀀스 문자열: "G-R-E-B"
    → 빈도: 3회
```

- 1단계에서 시퀀스 문자열 빈도 카운트
- 2단계에서 LLM이 유사 시퀀스를 그룹화 (G-R-E-B와 G-R-E-E-B를 같은 패턴으로)

#### 2. 프롬프트 템플릿 유사도

```
예: "X 파일에서 Y 함수를 찾아서 Z로 변경해줘" 패턴이 반복
    → 변수: X(파일), Y(함수명), Z(변경내용)
```

- 2단계에서 LLM이 프롬프트 구조 비교 및 변수 추출

#### 3. 파일 패턴 분석

```
예: 항상 src/components/*.tsx 파일을 대상으로 작업
    → glob 패턴으로 추상화
```

- 1단계에서 파일 경로를 glob으로 추상화
- 2단계에서 LLM이 파일 패턴과 워크플로우 의도를 연결

### 멀티 세션 누적 분석

패턴 요약이 `patterns.jsonl`에 누적되므로:
- 단일 세션에서는 1회만 나타난 패턴이 5개 세션에 걸쳐 반복된 경우도 감지
- `count`(빈도)와 `last_seen`(최근성)을 함께 고려하여 제안 우선순위 결정

패턴 요약 레코드:
```json
{
  "id": "sha256-hash-of-sequence",
  "sequence": "G-R-E-B",
  "intent": "API 엔드포인트 추가",
  "file_pattern": "src/api/**/*.ts",
  "sample_prompts": ["src/api에서 GET 엔드포인트를 추가해줘"],
  "count": 5,
  "first_seen": "2026-03-20",
  "last_seen": "2026-03-23",
  "suggested": false
}
```

---

## Output: 자동 추천 + 사용자 오버라이드

### 자동 분류 로직

패턴의 복잡도에 따라 출력 형태를 자동 추천한다:

| 복잡도 | 추천 형태 | 기준 |
|--------|----------|------|
| 낮음 | **Skill** | 선형적 도구 호출 (3단계 이하), 단일 프롬프트 템플릿 |
| 중간 | **Subagent** | 분기/반복/재시도 포함, 멀티파일 작업, 5단계 이상 |
| 특수 | **Hook** | 이벤트 기반 자동 실행 패턴 (예: Edit 후 항상 Bash(tsc) 실행) |

사용자는 추천된 형태를 확인 후 다른 형태로 변경할 수 있다.

### `/harvest` 스킬 UX: 상세 리포트

사용자가 `/harvest`를 실행하면 다음 리포트를 표시한다:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Session Harvester Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

발견된 반복 패턴: 3개

1. API 엔드포인트 추가 워크플로우
   반복: 4회 (이번 세션) | 구조: Grep -> Read -> Edit -> Bash
   추천: Skill | 유사 기존 스킬: 없음

2. 테스트 실패 -> 자동 수정 루프
   반복: 3회 (3개 세션 누적) | 구조: Bash(test) -> Read -> Edit -> ...
   추천: Subagent | 유사 기존 스킬: 없음

3. 파일 저장 후 타입 체크
   반복: 7회 (이번 세션) | 구조: Edit -> Bash(tsc)
   추천: Hook | 유사 기존 스킬: 'type-check' -> 병합 제안
```

사용자는 생성할 항목을 선택하고, 선택된 항목은 craft:skill-creator에 위임된다.

### 중복 처리: 병합 제안

기존에 유사한 스킬/서브에이전트가 존재하는 경우:
- `.claude/` 및 `~/.claude/` 하위의 기존 스킬을 스캔
- LLM이 패턴과 기존 스킬의 유사도를 판단
- 병합할지 별도 생성할지 사용자에게 제안
- 병합 시 기존 스킬에 새 패턴의 기능을 확장

---

## Skill Generation: craft:skill-creator 위임

### 위임 전략

스킬/서브에이전트/Hook 생성은 **이 플러그인이 직접 수행하지 않고 craft:skill-creator에 위임한다.** 이유:

1. craft:skill-creator가 이미 스킬 생성, eval, dry-run, 대화형 튜닝, description 최적화를 모두 지원
2. 중복 구현을 피하고 단일 책임 원칙(SRP) 준수
3. craft 플러그인이 업데이트되면 자동으로 생성 품질 향상

### 위임 흐름

```
harvest 스킬 (패턴 분석 + 리포트)
  → 사용자 선택
  → craft:skill-creator에 다음 정보를 전달:
     - 추출된 워크플로우 구조 (도구 시퀀스)
     - 파라미터화된 변수 목록
     - 샘플 프롬프트 (실제 사용 예시)
     - 추천된 출력 형태 (Skill/Subagent/Hook)
     - 대상 파일 패턴
  → craft:skill-creator가 생성 + eval + 튜닝 수행
```

### craft 미설치 시 폴백

craft 플러그인이 설치되지 않은 경우:
- harvest 스킬이 자체적으로 기본 SKILL.md 템플릿을 생성
- eval/dry-run/description 최적화는 스킵
- 사용자에게 craft 플러그인 설치를 권장하는 메시지 표시

### 출력물 형태별 구조

#### Skill

```
skills/<skill-name>/
├── SKILL.md          # 스킬 프롬프트
└── references/       # 참조 문서 (필요 시)
```

#### Subagent

```
agents/<agent-name>.md    # 에이전트 프롬프트 (도구 접근 권한 포함)
```

#### Hook

```
hooks/<hook-name>.sh      # Hook 실행 스크립트
```

+ 해당 Hook을 settings.json에 등록하는 설정 변경 제안

### 저장 위치: 사용자 선택

생성 시 사용자에게 저장 위치를 선택하게 한다:

- **프로젝트 로컬** (`.claude/`): 해당 프로젝트에서만 사용
- **글로벌** (`~/.claude/`): 모든 프로젝트에서 사용 가능

---

## Configuration

`plugin.json`의 `settings` 필드로 관리:

```json
{
  "settings": {
    "enabled": true,
    "min_repeat_threshold": 2,
    "excluded_tools": [],
    "log_user_prompts": true,
    "auto_masking": true,
    "masking_patterns": [],
    "pattern_retention_days": 90,
    "max_suggestions": 5,
    "default_save_location": "ask"
  }
}
```

| 설정 | 기본값 | 설명 |
|------|--------|------|
| `enabled` | `true` | 플러그인 활성화 여부 |
| `min_repeat_threshold` | `2` | 패턴으로 인식할 최소 반복 횟수 |
| `excluded_tools` | `[]` | 분석에서 제외할 도구 목록 |
| `log_user_prompts` | `true` | 사용자 프롬프트 로깅 여부 |
| `auto_masking` | `true` | 민감 정보 자동 마스킹 |
| `masking_patterns` | `[]` | 사용자 정의 마스킹 정규식 |
| `pattern_retention_days` | `90` | 패턴 요약 보존 기간 (일) |
| `max_suggestions` | `5` | 회당 최대 제안 수 |
| `default_save_location` | `"ask"` | `"local"`, `"global"`, `"ask"` |

> `auto_generate`, `dry_run_max_retries` 등 스킬 생성 관련 설정은 craft:skill-creator의 설정을 따르므로 이 플러그인에서는 관리하지 않는다.

---

## Plugin Stack Structure

```
plugins/session-harvester/
├── .claude-plugin/
│   ├── plugin.json              # 플러그인 메타데이터
│   └── hooks.json               # Hook 이벤트 등록
├── README.md
├── SPEC.md                      # 이 문서
├── hooks/
│   ├── logger.sh                # 도구 호출 + 프롬프트 로깅 (sed 마스킹 포함)
│   ├── harvest-analyze.sh       # 세션 종료 시 구조적 패턴 분석
│   └── session-notify.sh        # 세션 시작 시 보류 패턴 알림
├── skills/
│   └── harvest/
│       └── SKILL.md             # /harvest — LLM 의미 분석 + 리포트 + craft 위임
└── references/
    └── output-templates.md      # Skill/Subagent/Hook 생성 시 craft에 전달할 템플릿
```

### hooks.json

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-notify.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/logger.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/logger.sh"
          }
        ]
      }
    ],
    "PostToolUseFailure": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/logger.sh"
          }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/harvest-analyze.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### 컴포넌트 역할

| 컴포넌트 | 런타임 | 의존성 | 역할 |
|----------|--------|--------|------|
| `logger.sh` | Hook (셸) | jq, sed | stdin JSON 파싱 → 마스킹 → JSONL 기록 |
| `harvest-analyze.sh` | Hook (셸) | jq, sort, uniq | 구조적 패턴 분석 → 요약 누적 → 원본 삭제 |
| `session-notify.sh` | Hook (셸) | jq | 보류 패턴 확인 → stdout으로 알림 텍스트 주입 |
| `harvest` 스킬 | LLM | (craft 선택적) | LLM 의미 분석 + 리포트 + craft:skill-creator 위임 |

> **Python 의존성 없음.** 모든 Hook 스크립트는 jq + sed + 표준 POSIX 유틸리티만 사용한다. LLM이 필요한 의미 분석은 harvest 스킬(LLM 런타임) 내에서 수행한다.

### 데이터 흐름

```
[세션 중]
  UserPromptSubmit → logger.sh → sed 마스킹 → $CLAUDE_PLUGIN_DATA/sessions/<id>.jsonl
  PreToolUse       → logger.sh → sed 마스킹 → $CLAUDE_PLUGIN_DATA/sessions/<id>.jsonl
  PostToolUseFailure → logger.sh → sed 마스킹 → $CLAUDE_PLUGIN_DATA/sessions/<id>.jsonl

[세션 종료]
  SessionEnd → harvest-analyze.sh:
    1. sessions/<id>.jsonl 읽기
    2. 도구 시퀀스 추출 + 빈도 카운트
    3. 파일 경로 glob 추상화
    4. 실패-재시도 루프 감지
    5. 패턴 요약을 patterns.jsonl에 누적 (suggested: false)
    6. 만료된 패턴 정리 (pattern_retention_days 초과)
    7. sessions/<id>.jsonl 삭제

[다음 세션 시작]
  SessionStart → session-notify.sh:
    1. patterns.jsonl에서 suggested: false인 항목 확인
    2. 있으면 stdout으로 알림 텍스트 출력 (Claude 컨텍스트에 주입)

[사용자가 /harvest 실행]
  harvest 스킬:
    1. patterns.jsonl + pending_analysis.json 읽기
    2. LLM이 의미적 분석 수행 (프롬프트 클러스터링, 변수 추출)
    3. 상세 리포트 표시
    4. 사용자 선택
    5. craft:skill-creator에 위임 (또는 자체 폴백 생성)
    6. 제안된 패턴의 suggested: true로 업데이트
```

### 저장소 구조 ($CLAUDE_PLUGIN_DATA)

```
$CLAUDE_PLUGIN_DATA/
├── sessions/               # 활성 세션 로그 (세션 종료 시 삭제)
│   └── <session_id>.jsonl
├── patterns.jsonl           # 누적 패턴 요약 (영속)
└── pending_analysis.json    # 마지막 세션의 구조적 분석 결과
```

---

## Edge Cases

### 짧은 세션
- 도구 호출이 5회 미만인 세션에서는 harvest-analyze.sh가 분석을 스킵
- 로그는 삭제하되, 기존 패턴 요약의 만료 처리만 수행

### jq 미설치 환경
- logger.sh가 시작 시 `command -v jq` 확인
- 없으면 stdin을 그대로 JSONL에 덤프 (마스킹 미적용, 경고 메시지 출력)
- harvest-analyze.sh는 jq 없으면 스킵하고 다음 세션에 재시도

### 컨텍스트 압축 후 세션
- Hook 로그가 원본 데이터이므로 컨텍스트 압축의 영향 없음

### 동시 세션
- session_id로 로그 파일이 분리되므로 충돌 없음

### craft 플러그인과의 관계
- session-harvester는 **패턴 감지와 제안**에 집중 (단일 책임)
- 스킬 **생성과 검증**은 craft:skill-creator에 위임
- craft 미설치 시 기본 SKILL.md 템플릿으로 폴백 생성

### SessionEnd hook 타임아웃
- harvest-analyze.sh의 타임아웃을 30초로 설정
- 도구 호출 100회 이상의 대규모 세션에서도 jq + sort + uniq는 충분히 빠름
- 만약 초과 시 부분 분석 결과만 저장하고 종료

---

## Future Considerations (v2+)

> 아래 항목은 현재 스펙 범위에 포함되지 않으며, 추후 확장을 위한 참고용이다.

- 실시간 세션 중 제안 모드 (`Stop` hook에서 패턴 누적 감지 시 알림)
- 팀 레벨 패턴 공유 (조직 내 공통 워크플로우 감지)
- 스킬 효과 측정 (생성된 스킬이 실제로 시간을 절약하는지 트래킹)
- 마켓플레이스 자동 퍼블리시 (생성된 스킬을 마켓플레이스에 공유)
- PostToolUse 로깅 추가 (성공 도구 결과도 기록하여 분석 정밀도 향상)
