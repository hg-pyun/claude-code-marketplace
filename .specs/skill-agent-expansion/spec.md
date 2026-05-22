# Deep Interview Spec: hg-pyun-tools Skill-Agent Expansion

## Metadata
- Generated: 2026-05-22
- Rounds: 6 (R0 topology + R1~R6)
- Final Ambiguity: 17.5%
- Threshold: 20%
- Type: brownfield
- Status: PASSED

## Clarity Breakdown
| Dimension          | Score | Weight | Weighted |
|--------------------|-------|--------|----------|
| Goal               | 0.85  | 0.35   | 0.298    |
| Constraints        | 0.85  | 0.25   | 0.213    |
| Success Criteria   | 0.75  | 0.25   | 0.188    |
| Context (brownfield) | 0.85| 0.15   | 0.128    |
| **Total Clarity**  |       |        | **0.825** |
| **Ambiguity**      |       |        | **0.175 (17.5%)** |

## Topology
| Component            | Status | Description                                                                                              | Coverage / Deferral Note |
|----------------------|--------|----------------------------------------------------------------------------------------------------------|--------------------------|
| Coverage Definition  | active | 어떤 새 agent를 추가할지 / 어떤 도메인 공백을 채울지 / 어떤 skill의 어느 phase에 호출할지 결정              | 3개 agent 확정           |
| Agent Authoring      | active | 선정된 agent 3개의 .md 파일 작성 — frontmatter(name/description/model/tools), 본문(역할/작동방식/출력)    | 9-section XML 적용 (기존 agent 컨벤션) |
| Skill Integration    | active | 기존 SKILL.md 수정해서 새 agent를 정해진 phase/병렬 호출에 배선                                          | 대상: autopilot · code-review · ralplan |
| Validation & Release | active | scripts/validate.sh 통과 / 전체 autopilot 파이프라인 dogfood / plugin.json + marketplace.json 버전 bump | smoke test = 전체 파이프라인 1회 |

## Goal
hg-pyun-tools plugin에 보안·성능·문서 도메인 전문 advisor agent 3개(security-auditor, performance-analyst, doc-writer)를 추가하여, 일반 reviewer/architect가 놓치던 도메인 특화 finding을 autopilot Phase 5 / code-review / ralplan에서 명시적으로 생산하도록 한다.

## Constraints
- 이번 PR에서 추가되는 agent 개수: 정확히 3개 (security-auditor, performance-analyst, doc-writer).
- 도구 권한:
  - security-auditor: read-only (Write, Edit 미보유) — advisor 계열.
  - performance-analyst: read-only (Write, Edit 미보유) — advisor 계열.
  - doc-writer: Write 및 Edit 허용 — 문서를 직접 수정/제안할 수 있음.
- Model 티어:
  - security-auditor: `opus` (명제적 추론 비중 큼).
  - performance-analyst: `sonnet`.
  - doc-writer: `sonnet`.
- Skill 수정 범위: SKILL.md 3개 (autopilot, code-review, ralplan). 다른 skill은 이번 PR에서 변경하지 않음.
- subagent_type 호출 컨벤션: 기존 `subagent_type="<bare name>"` 패턴 유지 (CLAUDE.md 명시).
- plugin.json `settings.language`는 변경하지 않음 (기본 Korean 유지).
- 버전 bump: 마켓플레이스 CLAUDE.md 규칙 (plugin.json + marketplace.json 동시 갱신, 같은 날이면 `.N+1` 패치 증가) 준수.

## Non-Goals
- 신규 skill 생성 — agent만 추가, skill은 기존 9개 유지.
- DevOps/infra-engineer agent — 후순위로 식별했으나 이번 PR 범위 밖.
- incident-responder agent — 후순위로 식별했으나 이번 PR 범위 밖.
- 기존 reviewer/architect/critic agent의 프롬프트 확장 — Contrarian 검토 결과 "전문성 분리가 핀수" 결정.
- code-review skill에 performance-analyst 통합 — ralplan에 1회만 투입 (Simplifier 결정).
- 기존 advisor의 출력 포맷 통일 작업 — 새 advisor만 통일 포맷 채택, 기존 advisor는 손대지 않음.

## Acceptance Criteria
- [ ] `plugins/hg-pyun-tools/agents/security-auditor.md` 가 존재하고 frontmatter(`name`, `description`, `model: opus`, `tools` 목록에 Write/Edit 없음) 및 본문 구조(역할 / 작동 방식 / 출력 포맷 / 사용 시점 / 거부 조건)를 갖춤.
- [ ] `plugins/hg-pyun-tools/agents/performance-analyst.md` 가 존재하고 frontmatter(`model: sonnet`, Write/Edit 없음) 및 동일 본문 구조.
- [ ] `plugins/hg-pyun-tools/agents/doc-writer.md` 가 존재하고 frontmatter(`model: sonnet`, `tools`에 Write/Edit 포함) 및 동일 본문 구조.
- [ ] 각 agent 본문에 "출력 형식" 섹션이 명시: `Findings: [{severity, category, file:line, message, evidence, recommendation, confidence}]`, severity 등급 `CRITICAL/MAJOR/MINOR/INFO`, 그리고 "0 findings일 때도 'no concerns at this confidence' 명시" 규칙.
- [ ] security-auditor의 카테고리 정의: `AuthN`, `AuthZ`, `Secret`, `Crypto`, `Injection`, `SAST`, `Config`.
- [ ] performance-analyst의 카테고리 정의: `Hotpath`, `Complexity`, `IO`, `Memory`, `Cache`.
- [ ] doc-writer의 카테고리 정의: `Missing`, `Outdated`, `Inconsistent`, `Unclear`. doc-writer는 file:line 제안과 함께 markdown diff 형태의 권고 출력 가능.
- [ ] `plugins/hg-pyun-tools/skills/autopilot/SKILL.md`의 Phase 5 Steps에 6개 advisor 병렬 호출 명시: 기존 `architect` + `critic` + `reviewer` 에 `security-auditor` + `performance-analyst` + `doc-writer` 추가. 단일 메시지·6 Task 콜.
- [ ] `plugins/hg-pyun-tools/skills/code-review/SKILL.md` 에 reviewer + security-auditor + doc-writer 3개 병렬 호출 명시 (performance-analyst 제외).
- [ ] `plugins/hg-pyun-tools/skills/ralplan/SKILL.md` 의 Critic 단계에 performance-analyst가 advisor로 명시되어 호출됨.
- [ ] 변경된 SKILL.md 3개의 9-section 구조 보존 (`<Purpose>` ~ `<Final_Checklist>`). 새 advisor 호출은 `<Steps>` 와 `<Tool_Usage>` 안에 추가됨.
- [ ] `plugins/hg-pyun-tools/.claude-plugin/plugin.json` 의 `version` 이 `2026.05.22.5` 이상으로 bump.
- [ ] `.claude-plugin/marketplace.json` 의 hg-pyun-tools 항목 `version` 이 plugin.json과 동일.
- [ ] `scripts/validate.sh` 통과 (9-section soft check 포함).
- [ ] dogfood smoke: 작은 변경(예: README의 한 줄 수정) 하나에 대해 `/code-review` skill 을 실제 호출했을 때 3개 advisor 모두에서 응답이 돌아옴 (reviewer + security-auditor + doc-writer; performance-analyst는 ralplan에만 통합) — 각 응답에 `Findings` 또는 `no concerns at this confidence` 가 명시. (autopilot 전체 파이프라인은 dogfooding 가능하나 필수는 아님 — 자기 자신을 호출하는 재귀 위험 회피)

## Technical Direction
<!-- ERRATUM: 9-section XML 사용 (post-`314905b`). 아래 5-section 제안은 무효. -->
<!-- - **Agent 본문 표준**: 기존 reviewer.md / architect.md 의 구조를 templated. 각 새 agent는 다음 섹션 포함: -->
<!-- - `## Role` — 한 단락 역할 정의 -->
<!-- - `## When called` — 호출되는 skill·phase 목록 -->
<!-- - `## How it works` — 분석 절차 (도메인별) -->
<!-- - `## Output format` — 위 Acceptance Criteria에 명시한 Findings 스키마 -->
<!-- - `## Refusal conditions` — 도메인 밖 작업 거부 규칙 (예: security-auditor는 성능 finding 만들지 않음) -->
- **Agent 본문 표준**: 기존 reviewer.md / architect.md 의 9-section XML 구조를 따름 (`<Purpose>` ~ `<Final_Checklist>`). post-`314905b` 컨벤션 적용.
- **Output 스키마 (3개 공통)**:
  ```json
  {
    "summary": "<one-paragraph verdict>",
    "findings": [
      {
        "severity": "CRITICAL | MAJOR | MINOR | INFO",
        "category": "<domain-specific tag>",
        "location": "<file:line>",
        "message": "<one-sentence what>",
        "evidence": "<quoted snippet or observation>",
        "recommendation": "<concrete fix>",
        "confidence": "HIGH | MEDIUM | LOW"
      }
    ],
    "zero_findings_note": "<present only when findings=[]>"
  }
  ```
- **autopilot Phase 5 변경 패턴**: 기존 architect+critic+reviewer 3 Task 콜 블록을 6 Task 콜 블록으로 확장. 메시지 단일, 병렬성 유지. Phase 5 verdict 결합 로직도 6개 입력으로 일반화: "any REJECT or CRITICAL at HIGH confidence" 규칙 확장.
- **code-review skill 변경 패턴**: 현재 reviewer 단일 호출 → reviewer + security-auditor + doc-writer 3개 병렬 호출. severity 등급 통합 보고 표 추가.
- **ralplan 변경 패턴**: Critic round 안에 performance-analyst를 advisor로 등록. critic agent의 최종 판정 전에 performance-analyst의 Findings를 input으로 받아 critic이 종합.
- **Failure 모드**: 새 advisor 중 하나가 출력 스키마 위반(예: findings 키 누락) 시 autopilot Phase 5에서 다른 5개 verdict는 그대로 진행하되 위반한 agent는 "no-vote"로 처리. 다음 PR에서 스키마 강화.

## Context (brownfield)
- `plugins/hg-pyun-tools/agents/` 에 6개 agent 존재 (architect, critic, executor, explorer, reviewer, test-engineer). 새 3개는 같은 디렉토리에 추가.
- 모델 분포 현황: architect/critic = opus, executor/reviewer/test-engineer = sonnet, explorer = haiku. 새 agent는 security=opus (architect/critic과 같은 티어), performance/doc = sonnet (reviewer와 같은 티어).
- 9-section SKILL.md 의무는 skill/command에 적용. agents도 기존 컨벤션상 9-section XML 적용 (post-`314905b`) — CLAUDE.md 명시: "Every `plugins/<plugin>/skills/<skill>/SKILL.md` and `plugins/<plugin>/commands/<command>.md` ... MUST include all nine XML body sections".
- `subagent_type` 호출 컨벤션: 플러그인 prefix 없이 bare name (`reviewer`, `architect` 등) — CLAUDE.md 명시.
- 마켓플레이스 버전 bump 규칙: 같은 날 추가 변경 시 `.N+1` 패치 증가. 오늘 기존 version `2026.05.22.4` → 새 version `2026.05.22.5`.
- autopilot Phase 5 (지금) 호출 패턴은 `[Task(arch), Task(critic), Task(reviewer)]` 단일 메시지 병렬 — 새 3개를 같은 단일 메시지에 추가.

## Tradeoffs
| Choice                                              | Pros                                                          | Cons                                                             |
|-----------------------------------------------------|---------------------------------------------------------------|------------------------------------------------------------------|
| 새 agent 3개 추가 vs reviewer 프롬프트 확장          | 도메인별 깊이 / 다른 skill에서 독립 호출 가능 / 출력 분리      | maintenance surface 증가 / Phase 5에서 6개 병렬 — context cost ↑ |
| security-auditor=opus vs sonnet                     | 명제 추론·취약점 추적에 opus 우위                              | 비용 (architect/critic도 opus라 누적)                              |
| doc-writer Write/Edit 허용 vs read-only             | 문서 변경을 같은 sub-agent 내에서 완결                          | advisor 계열 read-only 원칙 깸 — 단, 도메인 특성상 정당화         |
| code-review에 performance-analyst 미포함 (이번 PR)  | 변경 범위 축소·롤백 쉬움                                       | code-review 단독 사용 시엔 성능 관점이 빠짐                       |
| Phase 5 병렬 6개 vs 단계적 (1차 3개 → 2차 3개)        | 단일 메시지·동시 출력 — 결합 로직 1회                          | 6개 advisor 동시 fan-out → token cost 증가                        |

## Assumptions Exposed & Resolved
| Assumption                                                          | Challenge                                                                 | Resolution                                                                                                                                          |
|---------------------------------------------------------------------|---------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| "효과 극대화 = 새 agent 추가"                                       | Contrarian: reviewer 프롬프트 확장으로 동일 효과 가능                     | 사용자 결정: 전문성 분리가 핀수 — 단일 agent가 여러 관점을 가지면 깊이 손실(올라운더링 효과)                                                       |
| "Phase 5의 advisor 3개로 충분"                                      | reviewer 1명이 보안·성능·문서까지 일반 관점으로 다루던 한계                | 도메인 advisor 3개 추가하여 6개 병렬 — 도메인 finding 명시화                                                                                       |
| "1개 PR에서 3개 + 3개 skill 모두 변경 가능"                          | Simplifier: 최소 연결만 하고 나머지 다음 PR로?                            | 사용자 결정: Phase 5 + code-review + ralplan 한 번에 — 단 code-review는 performance-analyst 제외, ralplan은 Critic에 performance만 투입 (부분 적용) |
| "doc-writer도 read-only advisor 패턴 따라야"                        | 문서 작성/수정은 단일 agent 내에서 완결되는 편이 자연스러움               | doc-writer만 Write/Edit 허용 — 다른 두 agent는 read-only                                                                                            |
| "성공 = '돌아가긴 함'"                                              | 어떻게 측정?                                                              | 합격선: 각 advisor가 호출당 finding ≥1 또는 'no concerns at this confidence' 출력. 출력 스키마 준수.                                               |

## Ontology (Key Entities)
| Entity         | Type       | Fields                                                                       | Relationships                                                          |
|----------------|------------|------------------------------------------------------------------------------|------------------------------------------------------------------------|
| Agent          | core       | name, description, model, tools, role, output_schema                         | Skill → Task(subagent_type=Agent.name)                                 |
| Skill          | core       | name, SKILL.md, phases, called_agents                                        | calls → Agent (via Task tool)                                          |
| Phase          | supporting | skill, ordinal, parallel?, agents[], success_condition                       | belongs-to → Skill, invokes → Agent (1..N)                             |
| Domain         | supporting | name (security/performance/docs/...), categories[]                           | maps-to → Agent (1:1 in this PR)                                       |
| ModelTier      | supporting | tier (haiku/sonnet/opus), cost, latency, reasoning_depth                     | assigned-to → Agent                                                    |
| ToolPermission | supporting | read_only?, allows[Write, Edit]                                              | granted-to → Agent                                                     |
| Finding        | core       | severity, category, location, message, evidence, recommendation, confidence  | produced-by → Agent (advisor only); consumed-by → Skill (verdict step) |

## Ontology Convergence
| Round | Entity Count | New | Changed | Stable | Stability |
|-------|--------------|-----|---------|--------|-----------|
| 1     | 3            | 3   | -       | -      | N/A       |
| 2     | 5            | 2   | 0       | 3      | 0.60      |
| 3     | 6            | 1   | 0       | 5      | 0.83      |
| 4     | 7            | 1   | 0       | 6      | 0.86      |
| 5     | 7            | 0   | 1 (Finding 필드 상세화) | 6 | 1.00      |
| 6     | 7            | 0   | 0       | 7      | 1.00      |

## Open Questions
- (다음 PR) code-review skill의 performance-analyst 통합 — 이번 PR 결과 관찰 후 결정.
- (다음 PR) infra-engineer / incident-responder agent 추가 — 후순위로 식별, 우선순위는 이번 PR 결과 dogfood로 검증 후.
- (다음 PR) Phase 5 6 advisor의 verdict 결합 로직 최적화 — 현재는 "any REJECT or CRITICAL at HIGH" 단순 OR. 도메인 가중치 적용 필요할 수 있음.
- (관찰 항목) Phase 5에서 6 advisor 병렬 시 token cost / latency 증가율 — 측정 후 다음 PR에서 조건부 호출 검토.
- (관찰 항목) doc-writer가 Edit 권한으로 SKILL.md 자체를 수정해도 되는지 — 첫 사용 후 안전 결정.

## Interview Transcript

<details>
<summary>Full Q&A (6 rounds)</summary>

### Round 0 — Topology
**Q:** 4개 컴포넌트 (Coverage Definition / Agent Authoring / Skill Integration / Validation & Release) 토폴로지 확정?
**A:** "이 토폴로지 그대로 진행" — 4개 모두 active 잠금.

### Round 1 — Coverage Definition / Goal (motivation)
**Q:** "효과 극대화"의 진짜 동기는?
**A:** "전문성 공백 메우기 (보안/성능/문서 등)"
**Ambiguity:** 73% (Goal 0.55, Constraints 0.20, Criteria 0.15, Context 0.65)

### Round 2 — Coverage Definition / Goal (narrow)
**Q:** 이번에 우선 추가할 도메인은? + 추가 개수 적정선은?
**A:** "보안 (security-auditor), 문서 (doc-writer), 성능 (performance-analyst)" + "3-4개"
**Ambiguity:** 63% (Goal 0.80, Constraints 0.55, Criteria 0.20, Context 0.70)

### Round 3 — Skill Integration / Goal
**Q:** 3개 agent의 통합 패턴은? + tools 권한 정책은?
**A:** "도메인별 최적 위치에 분산" — security+doc → autopilot Phase 5 + code-review, performance → ralplan + autopilot Phase 5. + "doc-writer는 Write/Edit 허용"
**Ambiguity:** 50% (Goal 0.60, Constraints 0.55, Criteria 0.20, Context 0.70)

### Round 4 — Contrarian Mode / Coverage + Validation / Criteria
**Q:** "새 agent 추가 대신 reviewer 프롬프트 확장으로 충분하지 않나?" + smoke test 범위는?
**A:** "전문성 분리가 핀수 (원안 유지)" + "전체 autopilot 파이프라인 돌려보기"
**Ambiguity:** 27.5% (Goal 0.80, Constraints 0.70, Criteria 0.60, Context 0.80)

### Round 5 — Agent Authoring + Validation / Criteria
**Q:** model 티어 + 출력 형식 확정?
**A:** "security-auditor=opus / performance-analyst=sonnet / doc-writer=sonnet (구수파 권장)" — 출력 스키마(severity/category/file:line/message/evidence/recommendation/confidence) + "0 finding 일 때도 'no concerns at this confidence' 명시" 합격선 확정.
**Ambiguity:** 21.75% (Goal 0.80, Constraints 0.75, Criteria 0.75, Context 0.85)

### Round 6 — Simplifier Mode / Skill Integration / Goal (wiring)
**Q:** 최소 연결로 충분한가, 6개 병렬로 갈 것인가?
**A:** "병렬 확장: Phase 5에 advisor 3개 주가 (권장)" — autopilot Phase 5 6병렬, code-review 4병렬(reviewer + security + doc), ralplan Critic 단계에 performance 1회 투입.
**Ambiguity:** 17.5% (Goal 0.85, Constraints 0.85, Criteria 0.75, Context 0.85) — threshold 20% 충족.

</details>
