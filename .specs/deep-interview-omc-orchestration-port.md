# Deep Interview Spec: OMC Orchestration Port (team / autopilot / ralplan / ralph + executor / test-engineer)

## Metadata
- Generated: 2026-05-22
- Rounds: 10
- Final Ambiguity: 21.5%
- Threshold: 20% (위임 결정으로 실질 도달 처리)
- Type: brownfield
- Status: EARLY_EXIT (위임 — 마지막 라운드에서 사용자가 판단 위임)

## Clarity Breakdown
| Dimension          | Score | Weight | Weighted |
|--------------------|-------|--------|----------|
| Goal               | 0.8   | 0.35   | 0.28     |
| Constraints        | 0.8   | 0.25   | 0.20     |
| Success Criteria   | 0.8   | 0.25   | 0.20     |
| Context (brownfield) | 0.7 | 0.15   | 0.105    |
| **Total Clarity**  |       |        | **0.785** |
| **Ambiguity**      |       |        | **21.5%** |

## Topology
| Component | Status | Description | Coverage / Deferral Note |
|-----------|--------|-------------|--------------------------|
| `team` skill          | active | 1–20명 multi-agent native team orchestration. 5-stage pipeline(plan→prd→exec→verify→fix) | OMC 5-stage 그대로 이식 |
| `autopilot` skill     | active | Idea → 동작 코드까지 5-phase end-to-end(expansion→planning→execution→QA→validation) sequencing | Sibling Skill 호출로 deep-interview→ralplan→ralph 연결 |
| `ralplan` skill       | active | Planner / Architect / Critic 합의 루프, ADR 산출물 | `.specs/<slug>/plan.md` 생성 |
| `ralph` skill         | active | PRD 기반 persistence loop. story-by-story 검증, reviewer 승인 후 정지 | `prd.json` story 완료까지 자동, commit/PR은 사용자 |
| `test-engineer` agent | active | TDD/테스트 전략 specialist. failing test 우선 enforcement | TDD Iron Law 전면 강제 |
| `executor` agent      | active | 코드 작성/편집/검증 실행자. small-correct-diff 원칙 | 3 fail → architect 자동 escalation |

## Goal

OMC(oh-my-claudecode)의 multi-agent orchestration 자산 4개 skill(`team`, `autopilot`, `ralplan`, `ralph`)과 2개 agent(`test-engineer`, `executor`)를 단일 plugin `hg-pyun-tools`에 이식한다. 단, OMC 전용 인프라(`.omc/state/`, `Skill("ai-slop-cleaner")`, `omc ask codex`, `ultrawork`, `oh-my-claudecode:*` sibling 참조)에는 의존하지 않고, 우리 marketplace의 자산(advisor agents, `code-review` skill, `.specs/` 산출물, `Task`/`Skill`/`AskUserQuestion` 표준 도구)으로 재배선한다. 모든 코드 작성 경로(executor / ralph / team / autopilot)는 **TDD Iron Law**(failing test 없이는 production 코드 금지)를 강제하며, 산출물은 항상 `pending approval` 상태로 멈춰 사용자가 commit/PR 트리거를 명시한다.

## Constraints

- 새 plugin을 만들지 않는다. 모두 기존 `hg-pyun-tools` 안에 들어간다.
- OMC sibling skills/agents 호출 금지. 다음으로 매핑:
  - `Skill("oh-my-claudecode:ai-slop-cleaner")` → `Skill("hg-pyun-tools:code-review")`
  - `Task(subagent_type="oh-my-claudecode:executor")` → `Task(subagent_type="executor")` (이번에 신규)
  - `Task(subagent_type="oh-my-claudecode:architect"|"critic"|"reviewer"|"explorer")` → 우리 plugin의 bare name (`architect` 등)
  - `Skill("oh-my-claudecode:cancel")` 호출 단계는 제거하고 "사용자에게 보고 후 종료"로 대체
  - `omc ask codex --agent-prompt critic` 등 외부 CLI 호출 제거. flag 자체(`--critic=codex`)도 제거
  - `ultrawork` 의존 제거. ralph의 parallel 실행은 main 세션이 직접 multi-Task 병렬 호출
- State 위치는 `.omc/state/sessions/{id}/` 대신 `.specs/<slug>/` 단일 디렉토리. session ID 관리 안 함.
- 4-file 산출물 계약:
  - `.specs/<slug>/spec.md` — deep-interview의 WHAT (이미 존재하는 형식 활용; deep-interview 출력 경로는 별도로 `.specs/deep-interview-<slug>.md`이지만 autopilot/ralplan 흐름에선 `.specs/<slug>/spec.md`로 재배치/심볼릭)
  - `.specs/<slug>/plan.md` — ralplan ADR (Decision/Drivers/Alternatives/Why chosen/Consequences/Follow-ups + RALPLAN-DR summary)
  - `.specs/<slug>/prd.json` — ralph stories(`stories[].acceptanceCriteria[]`, `stories[].passes`, `stories[].tags[]`)
  - `.specs/<slug>/progress.txt` — ralph journal (story별 구현 요약 + 학습)
- 9-section XML house style 강제 (`<Purpose>`/`<Use_When>`/`<Do_Not_Use_When>`/`<Why_This_Exists>`/`<Execution_Policy>`/`<Steps>`/`<Tool_Usage>`/`<Examples>`/`<Final_Checklist>`).
- 출력 언어 변수 `$LANGUAGE` 사용. 기본 Korean. agent 산출물은 calling-session language(현재 컨벤션).
- `plugin.json`과 `marketplace.json`의 version을 동일 일자로 bump (`2026.05.22.N`). 본 작업은 단일 day overhaul 예외 활용 가능하나 최종 phase에서 두 값 동기화.
- ralph 완주 경계: PRD 전 story `passes:true` + reviewer approve + (deslop 자리에서 `code-review` skill 통과) + post-deslop regression OK → 사용자에게 결과 보고 후 정지. **commit/PR은 사용자 후속 지시.**
- TDD Iron Law: production 코드를 작성할 모든 agent/skill 경로(executor/ralph/team/autopilot)는 failing test가 먼저 존재하지 않으면 작업 거부. executor는 거부 사유를 명확히 보고하고 test-engineer 호출을 권유 또는 자동 위임한다.

## Non-Goals

- OMC의 `cancel`, `ultrawork`, `ai-slop-cleaner`, `ralplan-DR deliberate mode`의 별도 코드 포팅은 하지 않는다(behavior는 일부 흡수, 별도 skill로 만들지 않는다).
- `.omc/state/` 경로 호환성 유지 안 함.
- Codex CLI 통합(`--critic=codex`, `--architect codex`) 제공 안 함.
- 새 plugin 추가 안 함 — 모두 `hg-pyun-tools` 내부.
- 본 spec은 **요구사항 정의까지만**. 코드 구현은 후속 ralplan + ralph 단계가 수행.
- README/SPEC.md 등 문서-only 변경은 본 작업 범위에서 추적하되 별도 phase로 분리해도 무방.

## Acceptance Criteria

### 산출물 위치
- [ ] `plugins/hg-pyun-tools/skills/team/SKILL.md` 존재 (9-section XML)
- [ ] `plugins/hg-pyun-tools/skills/autopilot/SKILL.md` 존재 (9-section XML)
- [ ] `plugins/hg-pyun-tools/skills/ralplan/SKILL.md` 존재 (9-section XML)
- [ ] `plugins/hg-pyun-tools/skills/ralph/SKILL.md` 존재 (9-section XML)
- [ ] `plugins/hg-pyun-tools/agents/test-engineer.md` 존재 (기존 4개 agent와 동일한 9-section 구조)
- [ ] `plugins/hg-pyun-tools/agents/executor.md` 존재 (동일 구조)

### 9-section house style 준수
- [ ] 모든 신규 SKILL.md / 신규 agent 파일이 `<Purpose>`/`<Use_When>`/`<Do_Not_Use_When>`/`<Why_This_Exists>`/`<Execution_Policy>`/`<Steps>`/`<Tool_Usage>`/`<Examples>`/`<Final_Checklist>` 9 섹션 포함
- [ ] `scripts/validate.sh` (또는 동등 검증) 통과

### OMC 의존성 제거
- [ ] `oh-my-claudecode:` 접두어 문자열이 신규 파일에서 zero hit (`grep -R 'oh-my-claudecode' plugins/hg-pyun-tools/skills/{team,autopilot,ralplan,ralph}`)
- [ ] `.omc/state/`, `ai-slop-cleaner`, `omc ask codex`, `ultrawork` 키워드가 신규 파일에서 zero hit
- [ ] 모든 agent 호출이 `Task(subagent_type="<bare name>")` 형식 (architect/critic/reviewer/explorer/executor/test-engineer)
- [ ] 모든 skill 호출이 `Skill("hg-pyun-tools:<name>")` 형식

### 산출물 계약
- [ ] `ralplan` skill이 `.specs/<slug>/plan.md`를 생성하며 ADR 6요소 + RALPLAN-DR Principles/Drivers/Options/(deliberate시) Pre-mortem 섹션 포함
- [ ] `ralph` skill이 `.specs/<slug>/prd.json`을 읽고 story 단위로 update, `.specs/<slug>/progress.txt`에 journal 기록
- [ ] `autopilot` skill이 `Skill("hg-pyun-tools:deep-interview")` → `Skill("hg-pyun-tools:ralplan")` → `Skill("hg-pyun-tools:ralph")` 순서를 명시
- [ ] 4-file 산출물 디렉토리 구조가 `<Examples>` 섹션에 적어도 1개 예시로 포함

### TDD Iron Law
- [ ] `executor` agent의 `<Execution_Policy>`에 "no production code without failing test first" 명시
- [ ] `ralph`/`team`/`autopilot`이 story/phase 시작 전 test-engineer 단계를 명시(test 부재시 거부 또는 test-engineer 자동 위임)
- [ ] `test-engineer` agent의 70/20/10 pyramid + Red-Green-Refactor cycle 명시

### 완주 경계
- [ ] `ralph` Step 8에 "결과 보고 후 정지, commit/PR은 사용자 후속 지시" 명시 (자동 commit/PR 금지)
- [ ] `ralph` Step 7.5 자리에 `Skill("hg-pyun-tools:code-review")` 호출이 명시되어 deslop 자리 대체
- [ ] `ralph` Step 7.6 regression re-verify 유지
- [ ] `executor` agent에 "3 failed attempts → escalate to architect agent" 자동화 명시

### Version & Doc 동기화
- [ ] `plugins/hg-pyun-tools/.claude-plugin/plugin.json` version이 `2026.05.22.N` 형식으로 bump
- [ ] `.claude-plugin/marketplace.json`의 `hg-pyun-tools` version이 동일 값
- [ ] `plugins/hg-pyun-tools/README.md`의 skills/agents 목록 업데이트 (doc-only 변경은 별도 commit 가능)

### Settings & Language
- [ ] 4개 신규 skill 모두 `$LANGUAGE` 변수 사용 (산출물 일부가 사용자 가시 텍스트인 한)
- [ ] `<Settings_Reference>` 섹션 포함 (language + skill 고유 flag)

## Technical Direction

### 1. Plugin layout
모든 자산은 단일 plugin `hg-pyun-tools` 내부에 추가:

```
plugins/hg-pyun-tools/
├── agents/
│   ├── architect.md            (기존)
│   ├── critic.md               (기존)
│   ├── explorer.md             (기존)
│   ├── reviewer.md             (기존)
│   ├── executor.md             ← 신규
│   └── test-engineer.md        ← 신규
├── skills/
│   ├── code-review/SKILL.md    (기존, deslop 자리에서 재사용)
│   ├── core-verify/SKILL.md    (기존)
│   ├── curl-debug/SKILL.md     (기존)
│   ├── deep-interview/SKILL.md (기존, autopilot의 Expansion phase)
│   ├── git-commit/SKILL.md     (기존)
│   ├── github-pr/SKILL.md      (기존)
│   ├── team/SKILL.md           ← 신규
│   ├── autopilot/SKILL.md      ← 신규
│   ├── ralplan/SKILL.md        ← 신규
│   └── ralph/SKILL.md          ← 신규
└── .claude-plugin/plugin.json  ← version bump
```

### 2. autopilot phase wiring

```
autopilot 입력: 자유서술 idea + flags

Phase 1 Expansion
  → Skill("hg-pyun-tools:deep-interview")
  → 산출물: .specs/deep-interview-<slug>.md
  → autopilot이 결과 파일을 .specs/<slug>/spec.md로 link/copy
  → ambiguity > threshold면 fail-fast로 사용자에게 보고

Phase 2 Planning
  → Skill("hg-pyun-tools:ralplan") --interactive 가능
  → 산출물: .specs/<slug>/plan.md (ADR)
  → 합의 실패시 사용자에게 보고

Phase 3 Execution
  → Skill("hg-pyun-tools:ralph")
  → 산출물: .specs/<slug>/prd.json, .specs/<slug>/progress.txt
  → ralph 내부 story-by-story loop + TDD Iron Law

Phase 4 QA
  → Task(subagent_type="test-engineer", prompt="<coverage gaps + flaky audit + fresh test run>")
  → ralph는 이미 test를 검증했지만 QA는 별도 lane에서 coverage 분석 + 추가 test 보강
  → 최대 5 iteration (test 추가 → run → fix), 동일 실패 3회 누적시 stop

Phase 5 Validation
  → Task(subagent_type="architect", prompt="full-system architectural review")
  → Task(subagent_type="critic", prompt="adversarial review")
  → Task(subagent_type="reviewer", prompt="severity-rated diff review")
  → 3 verdict 종합 후 pending approval로 사용자에게 보고
  → commit/PR은 사용자 후속 지시
```

### 3. ralplan consensus loop

```
ralplan 입력: <task description> [--interactive] [--deliberate]

Step 1 Planner draft
  → Task(subagent_type="architect", prompt="<draft plan + RALPLAN-DR summary: Principles, Drivers, Options, (deliberate시) Pre-mortem>")

Step 2 Architect review
  → Task(subagent_type="architect", prompt="<steelman antithesis + tradeoff tension + synthesis>")
  (Step 1과 다른 agent type을 쓰는 게 이상적이나, 우리는 architect가 가장 가까움.
   Step 1을 hg-pyun-tools:executor가 plan-writer 모드로 수행하거나, 단순히 main 세션이 직접 draft를 쓰는 대안 가능.
   본 spec에선 main 세션이 직접 draft를 쓰고 architect는 review-only로 호출.)

Step 3 Critic review
  → Task(subagent_type="critic", prompt="<principle-option consistency + risk mitigation + test plan + verdict APPROVE/ITERATE/REJECT>")
  → Step 2 완료 후에만 호출 (병렬 금지)

Step 4 Iteration loop
  → Critic verdict가 APPROVE 아니면 max 5회 iterate
  → Architect → Critic 한 묶음을 매 iteration마다 다시 돌림

Step 5 Output
  → .specs/<slug>/plan.md 생성 (ADR 6요소 + RALPLAN-DR summary)
  → 항상 "pending approval" 마크
  → --interactive시 AskUserQuestion으로 Approve/Reject/Request changes
```

### 4. ralph PRD loop

```
ralph 입력: <task description> [--no-deslop] [--critic=architect|critic]

Step 1 PRD bootstrap
  → .specs/<slug>/prd.json 없으면 scaffold 생성 (story[] 빈 배열)
  → 있으면 read + sanity check
  → CRITICAL: scaffold의 generic AC를 task-specific으로 refine

Step 2 Pick next story
  → passes:false 중 우선순위 highest 선택

Step 3 Implement (TDD Iron Law)
  → 3a. test-engineer 단계: failing test 작성 (Red)
  → 3b. executor 단계: minimum code to pass (Green)
  → 3c. executor 단계: refactor while green
  → 단계별 sonnet 기본, security/architecture 무거운 건 opus

Step 4 Verify story AC
  → 각 acceptanceCriteria에 대해 fresh evidence (test/build/lint output)
  → 미충족시 Step 3로

Step 5 Mark complete
  → prd.json story.passes = true
  → progress.txt에 implementation summary + learnings append

Step 6 PRD completion check
  → 모든 story passes? 아니면 Step 2로

Step 7 Reviewer verification
  → tier 선택: 변경 <5 files / <100 lines → STANDARD (sonnet reviewer)
  → 변경 ≥20 files or security → THOROUGH (opus reviewer)
  → --critic=critic이면 critic agent로 approval pass
  → 산출물: 승인/반려 + 근거

Step 7.5 Cleanup pass (--no-deslop 없을 때)
  → Skill("hg-pyun-tools:code-review") on changed files only
  → cleanup edit는 같은 scope 안에서 처리

Step 7.6 Regression re-verify
  → 변경 file 대상 test/build/lint 재실행
  → 실패시 roll back or fix, 다시 verify

Step 8 Report and stop
  → 결과 요약을 사용자에게 보고
  → "다음 단계: commit / PR / cleanup — 지시 대기" 명시
  → 자동 commit/PR 금지

Step 9 On rejection
  → 반려 사유 fix → 같은 reviewer로 재검증 → loop
```

### 5. team 5-stage pipeline

```
team 입력: [N:agent-type] [ralph] "<task>"

Stage 1 team-plan
  → Task(subagent_type="explorer", prompt="<scope discovery>")
  → Task(subagent_type="architect", prompt="<decompose into subtasks with dependencies>")
  → 산출물: .specs/<slug>/team-plan.md (handoff doc)

Stage 2 team-prd
  → main 세션이 plan.md를 읽어 .specs/<slug>/prd.json story[] 생성
  → 각 story마다 acceptanceCriteria + tags(test/build/exec) 부여

Stage 3 team-exec (parallel)
  → main 세션이 N개의 Task 호출을 단일 message에 묶어 병렬 fire
  → tag에 따라 worker 선택:
    test → test-engineer
    build/code → executor
    architecture-heavy → architect
  → 각 worker는 자신의 story.passes를 update + SendMessage로 보고
  → 단, SendMessage tool은 deferred — fallback으로 worker가 직접 .specs/<slug>/prd.json을 write

Stage 4 team-verify
  → Task(subagent_type="reviewer", prompt="<diff + acceptance criteria>")
  → Task(subagent_type="critic", prompt="<adversarial>")
  → 두 verdict 종합

Stage 5 team-fix
  → verify에서 잡힌 결함을 executor로 재처리
  → Stage 4로 loop
  → 동일 결함 3회 반복시 stop and report

종료: 모든 story passes:true + verify APPROVE → 사용자 보고
```

### 6. executor agent 핵심

```
- Role: 코드 작성/편집/검증 실행자. small-correct-diff 원칙.
- TDD enforcement: failing test가 없는 production code 작업 요청은 거부.
  → 거부 사유 명시 + test-engineer 위임 권유 (또는 main 세션이 위임)
- 작업 분류: Trivial / Scoped / Complex
- 도구: Read/Write/Edit/Bash/Grep/Glob; Task(subagent_type="explorer")는 최대 3 호출까지 허용
- Escalation: 동일 이슈 3회 실패 → Task(subagent_type="architect")로 자동 escalation + 본인 작업 중단
- 산출: 변경 file 목록 + fresh test/build output + 1줄 PR-친화 요약 (commit은 안 함)
```

### 7. test-engineer agent 핵심

```
- Role: 테스트 전략 + TDD enforcement.
- Iron Law: "No production code without failing test first."
- 70/20/10 pyramid 목표.
- Red-Green-Refactor cycle 명시.
- 작업: failing test 작성 / coverage 분석 / flaky 진단 / e2e 설계
- 도구: Read/Write/Edit/Bash/Grep; production code 직접 수정은 자제 (test 파일 위주)
- Escalation: 테스트 작성으로 풀리지 않는 design 문제 → architect로
```

### 8. ralph Step 7.5 deslop 대체

OMC 원본 `Skill("oh-my-claudecode:ai-slop-cleaner")` 호출 자리에 우리의 `Skill("hg-pyun-tools:code-review")` 호출을 명시. code-review skill의 출력에서 actionable suggestions만 같은 scope 안에서 적용. `--no-deslop`(또는 동등 flag명) 사용시 단계 통째 skip.

### 9. Version bump 전략

- 본 작업은 multi-phase overhaul 예외 활용 가능 (모두 같은 날 작업시).
- 최종 phase에서 `plugins/hg-pyun-tools/.claude-plugin/plugin.json`과 `.claude-plugin/marketplace.json` 두 곳에 `2026.05.22.N` (N은 당일 bump 횟수+1) 동기화.
- 중간 commit이 있다면 메시지에 "no version bump per overhaul exception" 명시.
- 모든 commit message는 영어 (메모리 저장 규칙).

## Context (brownfield)

- 현재 marketplace에 `hg-pyun-tools` 단일 plugin만 존재 (5개 → 1개 consolidation은 2026.05.22.1에 완료됨).
- 기존 agents (4개): `architect`, `critic`, `explorer`, `reviewer` — 모두 read-only advisor.
- 기존 skills (6개): `code-review`, `core-verify`, `curl-debug`, `deep-interview`, `git-commit`, `github-pr`.
- `deep-interview`는 이미 `.specs/deep-interview-<slug>.md` 산출물을 만든다 — autopilot Phase 1에서 재사용.
- `code-review`는 ralph Step 7.5의 ai-slop-cleaner 대체로 재사용.
- 9-section XML house style 강제, `$LANGUAGE` 변수, `Task(subagent_type="<bare>")` 컨벤션, plugin.json `author` 객체형 강제 — 모두 `CLAUDE.md`에 documented.
- `TeamCreate`/`TaskCreate`/`SendMessage` 같은 native team tool은 deferred이므로 ToolSearch로 schema 로드 후 사용 가능. 그러나 team SKILL.md는 이들을 hard dependency로 보지 말고 폴백(직접 prd.json write) 경로도 안내.
- `scripts/validate.sh`가 9-section 검증 + plugin.json 검증을 함.

## Tradeoffs

| Choice | Pros | Cons |
|--------|------|------|
| 5개 모두 full port | Reference 충실, 완성된 multi-agent 시스템 | 작업량 큼, 유지보수 부담↑ |
| 단일 plugin 안에 추가 | 사용자 import 단순, 의존성 관리 한 곳 | hg-pyun-tools 비대화 |
| OMC 의존성 전면 제거 | hg-pyun-tools 독립성↑, 외부 sibling 부재시 fallback 불필요 | 일부 OMC 기능(cancel, deslop) 직접 재구현 필요 |
| TDD Iron Law 전면 강제 | 회귀 사고 방지, reference 충실 | 빠른 prototyping이 어려워짐, opt-out 없음 |
| 4-file 산출물 (spec/plan/prd/progress) | 단계별 추적 명확, 산출물 책임 분리 | 파일 수 증가, 일관성 유지 부담 |
| ralph 자동 commit/PR 금지 | 사용자 통제력↑, 마켓플레이스 표준과 일치 | OMC 원본의 "boulder never stops" 가치 약화 |
| Skill 이어달리기 (autopilot phase wiring) | 모듈성↑, 각 skill을 단독 사용 가능 | autopilot 자체가 얇은 sequencing — 가치 의문 가능성 |
| code-review skill을 deslop 대체로 재사용 | 기존 자산 활용, 가치 유지 | 의미상 정확히 같진 않음(cleanup vs review) |
| executor 3-fail 자동 escalation | OMC reference 충실, 무한 retry 방지 | 사용자 개입 없이 architect 호출 — 비용↑ |

## Assumptions Exposed & Resolved

| Assumption | Challenge | Resolution |
|------------|-----------|------------|
| 4개 skill + 1 agent 모두 그대로 이식하면 가치가 있을 것 | Contrarian: autopilot은 ralplan+ralph wrapper에 불과, 따로 필요한가? | 사용자가 명시적으로 "5개 모두 full port" 선택. 단, 각 skill을 단독 호출 가능하게 분리 |
| OMC 인프라를 그대로 유지해야 reference에 충실 | Contrarian: 우리 marketplace의 advisor agent + code-review skill로 대체 가능 | "필수만 남기고 단순화" 결정. OMC 전용 의존성은 모두 우리 자산으로 재배선 |
| ralph는 "boulder never stops" — approve 후 commit/PR까지 자동 | Contrarian: 우리 marketplace의 git-commit/github-pr은 사용자 confirm 필요 | "approve까지만 자동, commit/PR은 사용자" 결정 |
| autopilot은 5-phase 전부 별도 단계여야 한다 | Simplifier: Phase 4/5는 ralph 내부 verifier와 중복 | 사용자가 "OMC 5-phase 그대로 이식" 선택. autopilot 레벨에서도 multi-perspective review 한 차례 더 수행 |
| ralplan은 plan skill의 alias이므로 plan skill을 먼저 만들어야 | Ontologist: 우리에겐 plan skill이 없고 만들 필요도 없음 — ralplan이 자체 합의 loop를 가지면 됨 | 단일 ralplan skill이 합의 loop을 직접 구현. plan.md(ADR) 산출물로 본질 정의 |
| test-engineer는 opt-in이면 충분 | TDD Iron Law는 너무 엄격 | 사용자가 "TDD Iron Law 전면 강제" 선택 — executor/ralph/team/autopilot 모두 failing test 우선 |
| deslop step은 ai-slop-cleaner 없으면 제거가 옳다 | code-review skill로 대체 가능 (위임 결정) | code-review를 deslop 자리에 호출. cleanup 가치 유지 |
| executor 3-fail 처리는 수동이 안전 | OMC reference는 자동 escalation | 자동 escalation을 채택 (위임 결정) |

## Ontology (Key Entities)

| Entity | Type | Fields | Relationships |
|--------|------|--------|---------------|
| `team` skill | core | `pipeline_stages[]`, `worker_pool[]`, `handoff_paths[]` | uses `executor`, `test-engineer`, `reviewer`, `critic` agents; reads/writes `prd.json` |
| `autopilot` skill | core | `phases[5]`, `phase_transitions[]`, `failure_modes[]` | invokes `deep-interview`, `ralplan`, `ralph` skills + Phase 4/5 agents |
| `ralplan` skill | core | `flags{}`, `consensus_iterations`, `adr_fields[]` | uses `architect`, `critic` agents; produces `plan.md` |
| `ralph` skill | core | `steps[1..9]`, `prd_path`, `reviewer_tier` | uses `executor`, `test-engineer`, `reviewer`/`critic`; uses `code-review` skill; reads/writes `prd.json`, `progress.txt` |
| `executor` agent | core | `task_class`, `escalation_threshold=3`, `tdd_enforced=true` | escalates to `architect`; defers test work to `test-engineer` |
| `test-engineer` agent | core | `pyramid_target={70,20,10}`, `tdd_iron_law=true`, `cycle=[Red,Green,Refactor]` | invoked by `executor`, `ralph`, `team`, `autopilot` |
| `spec.md` | supporting | `WHAT` (requirements) | output of `deep-interview` |
| `plan.md` | supporting | `HOW` (ADR + RALPLAN-DR summary) | output of `ralplan` |
| `prd.json` | supporting | `stories[].acceptanceCriteria[]`, `passes`, `tags` | shared by `ralph`, `team`, `autopilot` |
| `progress.txt` | supporting | `journal` (story-by-story implementation + learnings) | written by `ralph` |
| `architect`, `critic`, `reviewer`, `explorer` agents | external | existing 4 advisor agents | consumed by new skills/agents |
| `code-review` skill | external | existing skill | invoked by `ralph` Step 7.5 in place of OMC ai-slop-cleaner |
| `deep-interview` skill | external | existing skill | invoked by `autopilot` Phase 1 |

## Ontology Convergence

| Round | Entity Count | New | Changed | Stable | Stability |
|-------|--------------|-----|---------|--------|-----------|
| 1     | 5 (4 skills + 1 agent) | 5 | - | - | N/A |
| 2     | 7 (+ spec.md, prd.json) | 2 | 0 | 5 | 1.00 |
| 3     | 9 (+ executor agent, advisor pool 매핑) | 2 | 0 | 7 | 1.00 |
| 4     | 9 | 0 | 0 | 9 | 1.00 |
| 5     | 10 (+ team 5-stage pipeline) | 1 | 0 | 9 | 1.00 |
| 6     | 10 | 0 | 0 | 10 | 1.00 |
| 7     | 10 | 0 | 0 | 10 | 1.00 |
| 8     | 13 (+ spec.md/plan.md/progress.txt 분리 정의) | 3 | 0 | 10 | 1.00 |
| 9     | 13 | 0 | 0 | 13 | 1.00 |
| 10    | 14 (+ code-review를 deslop 대체로 명시) | 1 | 0 | 13 | 1.00 |

## Open Questions

이 spec에서 의도적으로 미정으로 남긴 영역 (후속 ralplan에서 결정):

- `ralplan`이 draft를 직접 작성할지 vs `architect`에게 plan-writer 모드로 위임할지의 구체적 분담 — 본 spec은 main 세션이 직접 draft, architect는 review-only로 가정. ralplan이 단독 호출됐을 땐 plugin command에서 main 세션 역할을 누가 할지 명확화 필요.
- `team` skill의 native multi-agent tool (`TeamCreate`/`TaskCreate`/`SendMessage`) 사용 vs fallback (직접 prd.json write) 결정 — deferred tool이라 ToolSearch 로드 비용 + 환경 의존성. 본 spec은 양쪽 모두 지원하되 fallback 우선 권장.
- `autopilot` Phase 4의 QA iteration 횟수 (OMC 원본 = 5) — 우리 환경에서 합리적 기본값 점검 필요.
- `ralplan --deliberate` 자동 활성화 조건 (auth/security, migrations, destructive changes 등 키워드 매칭) — 키워드 리스트는 후속 결정.
- `ralph`의 `--max-rounds`/`--max-stories` 같은 hard cap 도입 여부 — 본 spec은 hard cap 안 잡음.
- `executor`가 3 fail 후 architect로 escalate한 뒤 architect가 design을 제안하면 그걸 누가 받아 실행하는가 — main 세션? 같은 executor? 본 spec은 main 세션이 architect 제안을 다시 executor에게 위임하는 패턴을 가정.
- `test-engineer`가 작성한 failing test가 ill-defined 경우 (test 자체가 잘못된 경우) 어떤 escalation 경로를 가질지 — 본 spec은 architect로 escalate 가정.
- README.md (`plugins/hg-pyun-tools/README.md`) 업데이트 범위 — 본 spec의 acceptance에는 포함됐지만 doc-only이므로 별도 commit 가능.
- 각 skill에 도입할 flag 명세 (`--no-deslop` vs `--no-cleanup` 등 이름 통일) — 후속 결정.

## Interview Transcript

<details>
<summary>Full Q&A (10 rounds)</summary>

### Round 0 — Topology confirmation
**Q:** 5개 컴포넌트 topology(team/autopilot/ralplan/ralph/test-engineer) 맞는지?
**A:** "5개 모두 (full port)" — 단, 사용자가 옵션에 명시되지 않은 executor agent를 후에 추가 요청.
**Topology locked**: 6 components after Round 3.

### Round 1 — OMC infrastructure handling
**Q:** OMC sibling skill/state/CLI 의존성을 어떻게 다룰지?
**A:** "필수만 남기고 단순화" — 모두 우리 marketplace 자산으로 재배선.
**Ambiguity:** 75% → 68.5%

### Round 2 — PRD artifact format
**Q:** ralph가 쓸 PRD 산출물 형식과 경로?
**A:** ".specs/<slug>/prd.json + deep-interview 연결" — 4-file 구조 시작.
**Ambiguity:** 68.5% → 66%

### Round 3 — Worker pool for team/ralph
**Q:** 코드 작성을 누가 할 것인가?
**A:** "executor agent를 새로 추가" — topology 5 → 6.
**Ambiguity:** 66% → 61.5%
**External addendum:** 사용자가 https://github.com/Yeachan-Heo/oh-my-claudecode/blob/main/agents/executor.md reference 제공 → executor 핵심 원칙(small-correct-diff, 3-fail escalation, no over-engineering) 확보.

### Round 4 — ralph 완주 경계 (Contrarian Mode)
**Q:** reviewer approve 후 commit/PR까지 자동인가?
**A:** "approve까지만 자동, commit/PR은 사용자가" — marketplace 표준과 일치.
**Ambiguity:** 61.5% → 55%

### Round 5 — team pipeline depth
**Q:** team을 OMC 5-stage 그대로 vs 단순화?
**A:** "OMC 5-stage 그대로" — plan/prd/exec/verify/fix 모두 유지.
**Ambiguity:** 55% → 46.5%

### Round 6 — autopilot phase 수 (Simplifier Mode)
**Q:** Phase 4(QA)/5(Validation)가 ralph 내부 verifier와 중복되는데 단순화할지?
**A:** "OMC 5-phase 그대로 이식" — autopilot 레벨에서도 한 번 더 multi-perspective review 수행.
**Ambiguity:** 46.5% (no change due to score formula caps)

### Round 7 — TDD enforcement strictness
**Q:** test-engineer 자동 vs opt-in, TDD Iron Law를 어디까지 강제?
**A:** "OMC 원본처럼 TDD Iron Law 전면 강제" — executor/ralph/team/autopilot 모두 failing test 우선.
**Ambiguity:** 46.5% → 41.5%

### Round 8 — ralplan ontology (Ontologist Mode)
**Q:** ralplan 본질과 산출물 4-file 구조 확인?
**A:** "제안대로 (spec.md + plan.md + prd.json + progress.txt)" — 산출물 책임 분리 확정.
**Ambiguity:** 41.5% → 28%

### Round 9 — autopilot phase 트리거 메커니즘
**Q:** sibling Skill 호출 vs main 세션 sequencing vs hybrid?
**A:** "Skill('hg-pyun-tools:<name>') 이어달리기" — autopilot 내부에서 Skill tool 사용.
**Ambiguity:** 28% → 24%

### Round 10 — Deslop & executor escalation (Soft warning 발동)
**Q:** ralph Step 7.5 deslop 자리 처리 + executor escalation 자동/수동?
**A:** "판단에 위임" → assistant 결정: "Deslop 자리에 code-review skill + executor escalation 자동".
**Ambiguity:** 24% → 21.5% (위임으로 EARLY_EXIT 처리)

</details>
