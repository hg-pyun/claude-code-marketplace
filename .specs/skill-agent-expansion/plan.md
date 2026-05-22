# Plan: hg-pyun-tools Skill-Agent Expansion

## Metadata
- Slug: skill-agent-expansion
- Generated: 2026-05-22
- Mode: short (deliberate 자동감지 신호 없음)
- Iterations: 3/5
- Status: pending approval
- Input spec: .specs/skill-agent-expansion/spec.md (erratum 적용 예정 — AC-18 참조)

## Decision
hg-pyun-tools plugin에 advisor agent 3개(security-auditor[opus], performance-analyst[sonnet], doc-writer[sonnet])를 추가하고 autopilot/code-review/ralplan SKILL.md를 확장한다. 9-section XML agent 구조 유지, Phase 5 verdict는 도메인 stratified, doc-writer는 advisor phase에서 skill prompt 게이팅으로 read-only 강제, ralplan에서 performance-analyst는 Architect와 병렬로 호출되고 Critic이 단일 verdict를 유지한다.

## Drivers
1. autopilot Phase 5의 기존 3 advisor(architect/critic/reviewer)가 보안·성능·문서 도메인 특화 finding을 일반 관점으로 다루다 누락
2. code-review skill이 reviewer 단일 호출 — 도메인 다양성 부족
3. ralplan의 Critic 단계가 성능 trade-off를 plot할 시점 부재

## Principles
1. 새 advisor의 calling-time contract는 read-only 통일 — doc-writer는 agent-level Write/Edit 권한 보유, calling skill prompt가 게이팅
2. 출력 스키마는 도메인-agnostic 통일(Findings 배열) + 도메인-specific category enum
3. 9-section XML 구조는 SKILL.md/commands/agents 모두 유지 (기존 agent 컨벤션 + post-`314905b` 정렬)
4. 모델 티어는 도메인 추론 깊이에 비례 (security=opus, perf/doc=sonnet)
5. Critic의 단일-verdict 권한 보존 — performance-analyst는 advisor로 추가되지만 verdict 결정권 없음
6. 변경 범위는 hg-pyun-tools + 마켓플레이스 manifest 동시 bump 외 다른 plugin 미접촉

## Options Considered

### Option A: 단일 PR 전체 통합 (Spec 권장 + architect 4-amendment + critic 3-fix) ★ Chosen
- 3 agents + 3 SKILL.md + plugin.json + marketplace.json + spec erratum 동시 변경 (9 파일)
- Pros: 도메인 분산 통합 1회 dogfood로 검증, sub-PR 누적 시간 없음, architect/critic amendment 일관 적용
- Cons: PR 크기 ↑ (9 파일), Phase 5 6병렬 first-pass token cost ↑, 회귀 롤백 단위 큼

### Option B: 3단계 PR (security → docs → performance)
- 1차: security-auditor + autopilot Phase 5 1 advisor 추가
- 2차: doc-writer + code-review 확장
- 3차: performance-analyst + ralplan Critic-병렬
- Pros: 회귀 노출 최소화, 단계 dogfood, 롤백 단위 작음
- Cons: 3 PR 누적 시간 ↑, 통합 완성 시점 늦어짐, architect amendment 3개를 3 PR에 분산하면 일관성 검증 어려움
- Invalidation rationale: 사용자가 deep-interview Round 6 Simplifier 옵션 검토 후 명시적으로 단계적 안을 거부하고 "병렬 확장" 선택 (spec.md interview transcript Round 6)

### Option C: agent만 추가, skill 통합은 후속 PR
- 1차: 3 agents .md만 추가
- 2차: SKILL.md 3개 동시 수정
- Pros: agent 구조 안정화 후 통합
- Cons: orphan agent 단계 — 호출 안 됨, dogfood 합격선 미충족
- Invalidation rationale: dogfood 합격선("실제 호출 시 응답 확인")이 통합 후에만 검증 가능, 후속 PR로 미루면 agent 검증 미완 상태로 머지됨

## Chosen Approach
Option A + architect 4-amendment + critic 3-fix.
- 사용자가 Round 6 Simplifier 검토 후 명시적으로 "병렬 확장: Phase 5에 advisor 3개 주가" 선택
- dogfood 합격선("code-review 1회 호출 후 advisor 응답 관찰")이 통합 완료 후에만 검증 가능
- 도메인 분산 통합 결정이 Round 3에서 확정 — 다른 옵션은 spec 재작성 비용

## Consequences

### 변경되는 파일 (총 9개)
1. 추가: `plugins/hg-pyun-tools/agents/security-auditor.md` — `model: opus`, `disallowedTools: Write, Edit`, 9-section XML
2. 추가: `plugins/hg-pyun-tools/agents/performance-analyst.md` — `model: sonnet`, `disallowedTools: Write, Edit`, 9-section XML
3. 추가: `plugins/hg-pyun-tools/agents/doc-writer.md` — `model: sonnet`, `disallowedTools` 키 미존재 (Write/Edit 가능), 9-section XML + Refusal Conditions에 advisor phase 거부 명시
4. 수정: `plugins/hg-pyun-tools/skills/autopilot/SKILL.md` — Phase 5 6 Task 콜 단일 메시지 + stratified verdict rule + doc-writer 게이팅 prompt + Parallelism Note(line 287-293) 업데이트
5. 수정: `plugins/hg-pyun-tools/skills/code-review/SKILL.md` — 3 Task 콜 (reviewer + security-auditor + doc-writer) 단일 메시지 + doc-writer 게이팅 prompt
6. 수정: `plugins/hg-pyun-tools/skills/ralplan/SKILL.md` — performance-analyst를 Architect와 같은 Task 배치(병렬), Critic prompt에 input 합산, Critic 단일 verdict
7. 수정: `plugins/hg-pyun-tools/.claude-plugin/plugin.json` — version `2026.05.22.5`
8. 수정: `.claude-plugin/marketplace.json` — hg-pyun-tools entry version `2026.05.22.5`
9. 수정: `.specs/skill-agent-expansion/spec.md` — erratum (line 25, 70, 73-78, 105)

### Phase 5 Verdict Stratified Rule (autopilot SKILL.md 신규 명세)
**Hard block (REJECT 반환, Phase 3 재진입)**:
- reviewer / architect / critic / security-auditor 중 하나라도 REJECT
- 또는 위 4개 advisor 중 하나라도 CRITICAL@HIGH confidence finding 1개 이상

**Soft block (REVISE 반환, Phase 3 재진입)**:
- doc-writer가 `Missing` 또는 `Inconsistent` 카테고리에서 CRITICAL/MAJOR@HIGH 발견 (non-doc 아티팩트 대상)
- 또는 performance-analyst가 `Hotpath` 또는 `Complexity`에서 CRITICAL@HIGH

**Annotation only (Phase 3 재진입 없음, autopilot-validation.md에만 기록)**:
- doc-writer `Outdated` 또는 `Unclear` 단독 finding
- performance-analyst `IO/Memory/Cache` MAJOR 이하 finding

### 어려워지는 일
- Phase 5 verdict stratified rule 신규 구현 (autopilot SKILL.md 명시 텍스트)
- 6병렬 first-pass fan-out으로 Phase 5 token cost 약 2배 증가 추정
- doc-writer dual-mode contract (agent-level Write/Edit, calling-time read-only) 학습 비용

### 쉬워지는 일
- code-review 단독 호출 시 보안·문서 관점 자동 커버
- ralplan에서 성능 trade-off가 Critic 종합 입력에 plot
- 향후 새 advisor 추가 시 패턴 재사용

## Acceptance Criteria

### Agent 추가
- [ ] **AC-1**: `plugins/hg-pyun-tools/agents/security-auditor.md` 존재. frontmatter `name: security-auditor`, `description: <one-line>`, `model: opus`, `disallowedTools: Write, Edit` (정확 표기), 본문 9-section XML(`<Purpose>` ~ `<Final_Checklist>`), `<Settings_Reference>` 블록 미포함(기존 advisor 컨벤션). 검증:
  - `grep -E '^disallowedTools: Write, Edit$' plugins/hg-pyun-tools/agents/security-auditor.md` 통과
  - `grep -c '<Settings_Reference>' plugins/hg-pyun-tools/agents/security-auditor.md` = 0
  - 9 XML 태그 (`<Purpose>` `<Use_When>` `<Do_Not_Use_When>` `<Why_This_Exists>` `<Execution_Policy>` `<Steps>` `<Tool_Usage>` `<Examples>` `<Final_Checklist>`) 모두 존재
- [ ] **AC-2**: `plugins/hg-pyun-tools/agents/performance-analyst.md` 존재. `model: sonnet`, `disallowedTools: Write, Edit`, 9-section XML, `<Settings_Reference>` 미포함. 검증 동일.
- [ ] **AC-3**: `plugins/hg-pyun-tools/agents/doc-writer.md` 존재. `model: sonnet`, `disallowedTools` 키 미존재 (Write/Edit 가능), 9-section XML, `<Settings_Reference>` 미포함. `<Do_Not_Use_When>` 또는 `<Execution_Policy>`에 "When invoked under advisor phases (autopilot Phase 5, code-review), refuse Write/Edit and return diff-shaped recommendations only" 명시. 검증:
  - `grep -c '^disallowedTools' plugins/hg-pyun-tools/agents/doc-writer.md` = 0
  - `grep -c '<Settings_Reference>' plugins/hg-pyun-tools/agents/doc-writer.md` = 0
  - `grep -q "advisor phase" plugins/hg-pyun-tools/agents/doc-writer.md` 통과
- [ ] **AC-4**: 각 agent에 출력 스키마 명시 — `Findings: [{severity, category, location, message, evidence, recommendation, confidence}]`. severity enum `CRITICAL/MAJOR/MINOR/INFO`. confidence enum `HIGH/MEDIUM/LOW`. 0 findings 시 응답 **최상위 `zero_findings_note` 필드**에 "no concerns at this confidence" 문자열. 검증: 각 agent .md에 `severity`, `category`, `confidence`, `zero_findings_note` 4개 토큰 모두 grep 통과.
- [ ] **AC-5**: security-auditor 카테고리 enum: `AuthN`, `AuthZ`, `Secret`, `Crypto`, `Injection`, `SAST`, `Config`. 검증: 7개 토큰 모두 grep.
- [ ] **AC-6**: performance-analyst 카테고리 enum: `Hotpath`, `Complexity`, `IO`, `Memory`, `Cache`. 검증: 5개 토큰 모두 grep.
- [ ] **AC-7**: doc-writer 카테고리 enum: `Missing`, `Outdated`, `Inconsistent`, `Unclear`. 검증: 4개 토큰 모두 grep.

### Skill 수정
- [ ] **AC-8**: `plugins/hg-pyun-tools/skills/autopilot/SKILL.md` Phase 5 Steps에 6 Task 콜 단일 메시지 명시. 검증: PR 직전 baseline `grep -c 'subagent_type="' plugins/hg-pyun-tools/skills/autopilot/SKILL.md` 측정 후 변경 후 카운트 = baseline + 3 (정확 숫자는 PR description에 명시).
- [ ] **AC-9**: autopilot Phase 5 stratified verdict rule을 `<Execution_Policy>` 또는 `<Steps>` Phase 5에 명시. "Hard block", "Soft block", "Annotation only" 3단 모두 + 각각의 재진입 조건. 검증: 3 토큰 grep + "Phase 3 재진입" 또는 영문 동등 표현(`re-entry to Phase 3`) 존재.
- [ ] **AC-10**: autopilot doc-writer 호출 prompt에 영문 게이팅 문구 "Do not call Write/Edit during this invocation. Return diff-shaped recommendations only." 정확 포함. 검증: `grep -F 'diff-shaped recommendations only' plugins/hg-pyun-tools/skills/autopilot/SKILL.md` 통과 + `grep -F 'Do not call Write/Edit during this invocation' plugins/hg-pyun-tools/skills/autopilot/SKILL.md` 통과.
- [ ] **AC-11**: `plugins/hg-pyun-tools/skills/code-review/SKILL.md` 에 reviewer + security-auditor + doc-writer 3 Task 콜 단일 메시지 명시 (performance-analyst 미포함). 검증: PR 직전 baseline subagent_type 카운트 측정 후 = baseline + 2.
- [ ] **AC-12**: code-review doc-writer 호출 prompt에도 동일 영문 게이팅 문구. 검증: `grep -F 'diff-shaped recommendations only' plugins/hg-pyun-tools/skills/code-review/SKILL.md` 통과.
- [ ] **AC-13**: `plugins/hg-pyun-tools/skills/ralplan/SKILL.md` Phase 3 (Architect Pass) 와 같은 Task 배치(병렬)에 performance-analyst 호출 추가. Phase 4 (Critic) prompt에 `## Performance findings (from performance-analyst)` 또는 동등 section 라벨로 input 포함. Critic이 단일 verdict 발행. 검증:
  - `grep "performance-analyst" plugins/hg-pyun-tools/skills/ralplan/SKILL.md` 통과
  - Critic 호출 prompt 내에 "performance" 토큰을 포함한 section 라벨 존재
- [ ] **AC-14**: 변경된 SKILL.md 3개의 9-section XML 구조 보존 (9 태그 모두 존재). 검증: `scripts/validate.sh` 통과 + 각 파일에 `<Purpose>`, `<Final_Checklist>` 등 9 태그 모두 grep.
- [ ] **AC-15**: `plugins/hg-pyun-tools/skills/autopilot/SKILL.md` 의 "Phase 5 Parallelism Note" 섹션(현재 line 287-293, 변경 후 위치 이동 가능) 업데이트 — 6 advisor 이름(`architect`, `critic`, `reviewer`, `security-auditor`, `performance-analyst`, `doc-writer`) 모두 명시 + "final code" 또는 "moving target" 토큰 보존. 검증:
  - `grep -E '(architect|critic|reviewer|security-auditor|performance-analyst|doc-writer)' plugins/hg-pyun-tools/skills/autopilot/SKILL.md` 에서 6 advisor 이름 모두 발견
  - `grep -E '(final code|moving target)' plugins/hg-pyun-tools/skills/autopilot/SKILL.md` 통과

### Version 및 Manifest
- [ ] **AC-16**: `plugins/hg-pyun-tools/.claude-plugin/plugin.json` 의 `version` 이 `2026.05.22.5`. 검증: `jq -r '.version' plugins/hg-pyun-tools/.claude-plugin/plugin.json` = `2026.05.22.5`.
- [ ] **AC-17**: `.claude-plugin/marketplace.json` 의 hg-pyun-tools 항목 `version` 이 `2026.05.22.5`. 검증: `jq -r '.plugins[] | select(.name=="hg-pyun-tools") | .version' .claude-plugin/marketplace.json` = `2026.05.22.5`.

### Spec Erratum
- [ ] **AC-18**: `.specs/skill-agent-expansion/spec.md` 의 다음 영역에서 stale text 완전 삭제 또는 quarantine (HTML comment `<!-- ... -->` 또는 markdown strikethrough `~~...~~` 둘 다 허용):
  - **line 25** (Topology row): "9-section 미적용 — agents는 marketplace agent 표준 구조"
  - **line 70** (dogfood AC): "4개 advisor 모두에서 응답이 돌아옴"
  - **line 73-78** (Technical Direction agent 본문 표준 5-section markdown 권장)
  - **line 105** (Context): "agents는 9-section 적용 안 함"
  - 검증: `grep -cE '(^\| Agent Authoring \|.*9-section 미적용)|(4개 advisor 모두에서 응답)|(^- \`## Role\` —)|(^- \`## When called\` —)|(^- \`## How it works\` —)|(^- \`## Output format\` —)|(^- \`## Refusal conditions\` —)|(agents는 9-section 적용 안 함)' .specs/skill-agent-expansion/spec.md` 결과가 **0** (정확히 0).
  - quarantine 시 HTML comment / strikethrough 가 정규식 앞에 prepend되어 패턴 매치 회피됨.

### CLAUDE.md
- [ ] **AC-19**: CLAUDE.md `settings.language` 표준의 "Within `hg-pyun-tools`, exempt artifacts" 리스트 미수정. 새 agent .md 3개는 calling session $LANGUAGE 따름 — 기존 advisor 컨벤션과 동일. 검증: `git diff CLAUDE.md` 빈 결과.

### Smoke Test
- [ ] **AC-20**: dogfood smoke (a) **REQUIRED**: `/code-review` 1회 호출 (대상: 작은 README 변경 또는 임의의 diff). 3 advisor(reviewer/security-auditor/doc-writer) 모두 응답. 각 응답에 `Findings` 배열 또는 `zero_findings_note` 명시. transcript snippet은 **PR description 또는 `.specs/skill-agent-expansion/dogfood-transcript.md`** 둘 중 한 곳에 첨부 (필수).
- [ ] **AC-21**: dogfood smoke (b) **BEST-EFFORT**: `/ralplan` 1회 호출 시 performance-analyst Finding이 validation 흐름에 plot. 시간/토큰 자원 제약 시 skip 가능, plan.md 또는 PR description에 1문장 skip 사유 명시.
- [ ] **AC-22**: dogfood smoke (c) **BEST-EFFORT**: autopilot Phase 5 dry-run 시 6 advisor 응답이 `autopilot-validation.md`에 기록. 시간 자원 제약 시 skip 가능. (재귀 호출 위험 회피 — 자기 자신을 fix 대상으로 삼지 않음)

### Validate
- [ ] **AC-23**: `scripts/validate.sh` 통과 (9-section soft check 포함).

## Risk Mitigation Matrix

| Risk | Severity | Mitigation | Residual |
|------|----------|------------|----------|
| 6병렬 Phase 5 first-pass fan-out token cost ~2배 | MAJOR | **수용된 known cost** — Follow-ups에 측정 계획 등록 | HIGH — 측정 후 조건부 호출 옵션 검토 |
| Phase 5 retry cycles 비용 | MAJOR | Stratified verdict로 doc-writer Outdated/Unclear는 annotation으로 강등, retry 유발 안 함 (AC-9) | LOW |
| doc-writer가 advisor phase에서 Write/Edit 사용 (kernel-level enforcement 없음) | MAJOR | Two-layer prompt 게이팅 (AC-3 agent.md + AC-10/AC-12 skill prompt). **Residual: prompt-only enforcement. 최초 위반 관찰 시 doc-writer.md에 `disallowedTools: Write, Edit` 추가 + dual-mode drop** | MEDIUM — 첫 dogfood에서 관찰 |
| performance-analyst가 Critic의 verdict 권한 침범 | MAJOR | ralplan SKILL.md 명시 — Architect와 병렬 advisor, Critic 단일 verdict (AC-13) | LOW |
| spec contradiction 잔존 | MINOR | AC-18 spec erratum 강제 (machine-verifiable 0-grep) | LOW |
| 새 agent가 호출되지 않음 (orphan) | MAJOR | AC-20 dogfood smoke (a) 필수 합격선 | LOW |
| advisor 출력 스키마 위반 | MINOR | autopilot Phase 5에 "schema 위반 advisor는 no-vote" 규칙 (AC-9 포함) | LOW |
| 단일 PR 회귀 시 9 파일 동시 롤백 | MINOR | Rollback Procedure 명시 (아래) | LOW |
| Phase 5 Parallelism Note(287-293) 6 advisor 명시 불일치 | MAJOR | AC-15 — 해당 섹션 직접 업데이트, 6 advisor 명시 + "final code" 조건 재확인 | LOW |
| Finding fatigue (6 advisor 노이즈 ↑) | MINOR | Stratified verdict가 doc-writer noise 흡수, severity 등급으로 사용자 필터링 가능 | MEDIUM — follow-up 관찰 |

## Rollback Procedure
1. AC-20 smoke 실패 시: 즉시 revert commit 생성 (9 파일 + spec).
2. Manifest 우선 되돌림 (plugin.json + marketplace.json) — 사용자가 새 버전을 받지 않도록.
3. 다음 순서로 agents/skills 되돌림: skill SKILL.md (autopilot → code-review → ralplan) → agent .md (security-auditor → performance-analyst → doc-writer) → spec.md.
4. Smoke 실패 사유는 follow-up 이슈로 등록, 다음 PR에서 단계적 안(Option B) 재검토.

## Follow-ups (out of scope)
- code-review에 performance-analyst 통합 (이번 PR 결과 관찰 후 결정)
- infra-engineer / incident-responder agent 추가
- Phase 5 verdict 결합 도메인 가중치 정밀 조정
- 6 advisor 병렬 token cost / latency 측정 후 조건부 호출 옵션
- doc-writer가 SKILL.md 자체를 수정 가능한지 안전성 평가
- 기존 advisor(architect/critic/reviewer) 출력 포맷 통일 (Findings 스키마로)
- "no concerns at this confidence" 응답을 `zero_findings_note` 필드로 강제하는 schema 검증 도구
- doc-writer 를 `doc-writer`(Write/Edit) + `doc-advisor`(read-only) 둘로 분리 검토 (critic Open Question)

## Agent Verdict Trail
| Iteration | Architect Summary | Critic Verdict | Critic Notes |
|-----------|-------------------|----------------|--------------|
| 1         | 4 amendment 식별: (A) spec internal contradiction (5-section vs 9-section); (B) OR-doubling verdict 위험; (C) doc-writer read-only invariant; (D) ralplan Critic verdict ownership | (생략 — iteration 1은 architect만) | — |
| 2         | iteration 1 4-amendment 반영 확인 | ITERATE | 2 CRITICAL (AC-17 line 70 누락, AC-17 verification ambiguity) + 1 MAJOR (Parallelism Note 미업데이트) + minor 다수 |
| 3         | 새 structural 결함 없음. 3 minor 권장 (quarantine 호환·`<Settings_Reference>` 명시·transcript 위치 alternative) — 모두 반영 | **APPROVE** | iteration 2 blocker 모두 해소, grep/jq-verifiable, principle-option consistent, risk mitigation 명시 |
