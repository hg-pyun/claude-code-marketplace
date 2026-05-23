---
kind: spec
path: .specs/agent-file-handoff-strategy/spec.md
contentHash: sha256:ca937fab25363fae3c736faec1d8cbed45faac3a6c7e655d536f0d598cbb1f24
createdAt: 2026-05-23T00:00:00Z
producer: deep-interview
sizeBytes: 19514
retention: permanent
expiresAt: null
status: PASSED
---

# Deep Interview Spec: Agent File Hand-off Interface (hg-pyun-tools)

## Metadata
- Generated: 2026-05-23
- Rounds: 9 (R0 topology + R1~R9)
- Final Ambiguity: 14%
- Threshold: 20%
- Type: brownfield
- Status: PASSED

## Clarity Breakdown
| Dimension          | Score | Weight | Weighted |
|--------------------|-------|--------|----------|
| Goal               | 0.90  | 0.35   | 0.315    |
| Constraints        | 0.85  | 0.25   | 0.2125   |
| Success Criteria   | 0.85  | 0.25   | 0.2125   |
| Context (brownfield) | 0.80| 0.15   | 0.120    |
| **Total Clarity**  |       |        | **0.860**|
| **Ambiguity**      |       |        | **14%**  |

## Topology
| # | Component | Status | Description | Coverage Note |
|---|-----------|--------|-------------|---------------|
| 1 | Descriptor & Status Schema | active | OMC parity 8-field schema + status enum on every hand-off artifact | hybrid 위치: .md=frontmatter, .json=`_descriptor` key |
| 2 | Storage Layout & Naming | active | `.specs/<slug>/` 하위 4개 서브디렉터리 (state/, artifacts/ask/, notepads/, events.jsonl) 추가 | 기존 spec.md/plan.md/prd.json 경로 불변 |
| 3 | Agent I/O Contract Surface | active | **agents/*.md 미수정**. 6개 invoking SKILL.md `<Tool_Usage>`에 인라인 표준 template 추가 | Contrarian R4 결정: skill-layer only |
| 4 | Concurrency & Lifecycle Controls | active | `mkdir .lock` atomic locking + retention/expiresAt + dual cleanup (auto+manual) | cross-platform safe (POSIX flock 회피) |

## Goal
yeachan-heo/oh-my-claudecode (OMC)의 file hand-off 패턴을 hg-pyun-tools에 도입하여, skill 간·skill↔agent 간 산출물 교환을 **OMC parity descriptor + 표준 storage layout + atomic concurrency + dual-trigger lifecycle**로 공식화한다. 단, agents/*.md는 미수정하고 invoking skill 레이어에서만 표준화한다.

## Constraints

### C1. Descriptor format (hybrid 위치)
- `.md` 파일 (spec.md, plan.md, team-*.md, notepads/*.md, artifacts/ask/*.md): YAML frontmatter
- `.json` 파일 (prd.json, state/*.json): 예약 키 `_descriptor` (다른 stories/fields와 형제)
- `events.jsonl`: 각 라인 자체가 event payload — descriptor는 file-level이 아닌 stream-level이므로 별도 메타 없음 (`.specs/<slug>/state/events-meta.json`에 분리)

### C2. Descriptor 8개 필드 (OMC parity)
| 필드 | 타입 | 값 예 | 비고 |
|------|------|-------|------|
| `kind` | enum | spec\|plan\|prd\|advisor\|notepad\|state\|handoff\|trace | 우리 artifact 종류로 OMC base 확장 |
| `path` | string | `.specs/<slug>/spec.md` | 절대 또는 cwd-relative |
| `contentHash` | string | `sha256:abc123...` | self-hash 회피: descriptor block 제외한 contents의 hash |
| `createdAt` | ISO8601 | `2026-05-23T11:30:00Z` | UTC |
| `producer` | string | `deep-interview` (skill) 또는 `architect` (agent) | skill 또는 agent 이름; format은 일관 |
| `sizeBytes` | int | `12345` | bytes |
| `retention` | enum | session\|day\|permanent | session=autopilot 종료 시 정리, day=24h, permanent=수동만 |
| `expiresAt` | ISO8601 또는 null | `2026-05-24T11:30:00Z` 또는 `null` | retention=permanent면 null |

추가 필드 (status enum, 모든 hand-off 파일 공통):
- `status`: pending | approved | complete | failed | cancelled | PASSED | EARLY_EXIT | HARD_CAP
  - 기존 deep-interview spec.md의 `Status: PASSED/EARLY_EXIT/HARD_CAP` 호환 유지
  - 기존 ralplan plan.md의 `Status: pending approval` → `pending` 정규화

### C3. Storage layout (4개 서브디렉터리 추가)
```
.specs/<slug>/
├── spec.md              # (기존, descriptor frontmatter 추가)
├── plan.md              # (기존, descriptor frontmatter 추가)
├── prd.json             # (기존, _descriptor key 추가)
├── progress.txt         # (기존, descriptor 없음 — trace 용도)
├── state/                       # 신규: control plane
│   ├── autopilot.json          # phase tracking, stage_history
│   ├── ralph.json              # iteration state
│   ├── team.json               # team-level state
│   └── events-meta.json        # events.jsonl 메타 (각 line은 inline event)
├── artifacts/ask/               # 신규: advisor 산출물
│   ├── architect-<ISO8601>.md
│   ├── critic-<ISO8601>.md
│   ├── reviewer-<ISO8601>.md
│   ├── security-auditor-<ISO8601>.md
│   ├── performance-analyst-<ISO8601>.md
│   └── doc-writer-<ISO8601>.md
├── notepads/                    # 신규: ralph cross-iteration memory
│   ├── learnings.md
│   ├── decisions.md
│   ├── issues.md
│   └── problems.md
└── events.jsonl                 # 신규 (team mode 전용): append-only
```

### C4. Lock 메커니즘 (mkdir-based atomic)
- 파일명 컨벤션: `<target>.lock/` (디렉터리)
- 획득: `mkdir <target>.lock` 성공 시 점유. 실패 시 다른 호출자 점유 중.
- 해제: 작업 종료 시 `rmdir <target>.lock`.
- 만료 처리: `.lock/owner.txt`에 session/owner 식별자와 ISO8601 시각 기록. 생성 후 1시간 경과 시 만료된 lock으로 간주하여 후속 호출자가 재획득 허용.
- 적용 대상: team mode 협업이 동일 파일에 쓸 가능성이 있는 모든 경로 (현재 보수적으로 `.specs/<slug>/state/team.json` + `prd.json` + `events.jsonl`).

### C5. Cleanup (dual trigger)
- **자동 (autopilot Phase 6)**: autopilot 종료 시 `retention: session` 파일을 일괄 제거.
- **수동 (`scripts/cleanup.sh`)**: 인자로 슬러그 또는 `--all`. expiresAt 지난 파일을 모두 제거.
- skip 정책: `retention: permanent`은 절대 자동 삭제 안 함.

### C6. Hierarchy 가시성 (하위 호환성)
- 기존 코드/skill이 읽는 경로 (`.specs/<slug>/spec.md`, `plan.md`, `prd.json`)는 **그대로 유지**.
- 신규 서브디렉터리 추가만 변경. 기존 파일을 신규 위치로 옮기지 않음.
- descriptor frontmatter는 기존 markdown reader가 무해하게 무시 (YAML frontmatter 표준).

### C7. agents/*.md는 미수정 (Contrarian 결정)
- 12개 agent.md 파일에 `handoff:` 같은 frontmatter 추가하지 않음.
- I/O 명세는 invoking skill의 prompt assembly에서만 이루어짐.

## Non-Goals
- **agent.md 스키마 확장**: 12개 agent 파일의 frontmatter 변경 없음.
- **`.omc/` 디렉터리 도입**: hg-pyun-tools는 `.specs/<slug>/` 단일 루트 유지. OMC 전체 디렉터리 계층 이식 X.
- **`.omc/project-memory.json` / `.omc/notepad.md` 같은 globals**: cross-session, cross-slug 영속 메모리는 본 spec 범위 아님 (향후 별도 spec).
- **외부 세션 worker**: claude code 내 단일 세션 가정. lock은 미래 확장을 위한 인프라일 뿐 다른 세션 간 협업 시나리오는 본 spec 범위 외.
- **Windows POSIX-flock 지원**: mkdir-based locking 사용으로 우회. flock(2) 의존 없음.
- **기존 spec.md/plan.md/prd.json migration**: 기존 파일은 descriptor 없이도 동작 (graceful read).

## Acceptance Criteria
- [ ] **A. Descriptor frontmatter**: autopilot의 모든 phase 완료 시 산출된 .md 파일은 YAML frontmatter (8 OMC 필드 + status)를 가진다. .json 파일은 `_descriptor` 예약 키를 가진다.
- [ ] **B. Status enum 통일**: deep-interview, ralplan, ralph, team, autopilot, code-review가 status에 대해 공통 enum (pending|approved|complete|failed|cancelled|PASSED|EARLY_EXIT|HARD_CAP)을 사용한다. validator는 enum에 없는 status 값을 거부 처리한다.
- [ ] **C. Advisor 파일화**: autopilot Phase 5의 6개 advisor + code-review의 advisor 호출이 `.specs/<slug>/artifacts/ask/<agent>-<ISO8601>.md`을 생성한다. 파일 내용은 advisor의 in-session 리포트와 동일하되 descriptor frontmatter가 추가된다.
- [ ] **D. Notepads**: ralph가 iteration 진행 중 발견사항을 `.specs/<slug>/notepads/{learnings,decisions,issues,problems}.md`에 append한다. 각 append는 ISO8601 timestamped section.
- [ ] **E. Lock**: team skill의 `state/team.json`/`prd.json`/`events.jsonl` 쓰기 시 `<file>.lock/` 디렉터리 획득 후 진행. 경쟁 시 mkdir 실패 측은 대기 또는 retry.
- [ ] **F. Auto cleanup**: autopilot Phase 6 (혹은 종료 직전) 시점에 해당 슬러그 내 `retention: session` 파일들이 자동 제거된다. permanent 파일은 보존.
- [ ] **G. Validator**: `scripts/validate.sh`가 descriptor schema (필수 필드 존재, enum 값 유효, contentHash 형식)를 모든 hand-off 파일에 대해 검증한다. CI 통과 조건.
- [ ] **H. 하위 호환**: descriptor 없는 기존 `.specs/<slug>/spec.md/plan.md/prd.json`을 읽는 코드는 그대로 동작한다 (graceful degradation). frontmatter parser가 missing이면 descriptor=null 처리.

## Technical Direction

### 6개 invoking SKILL.md 인라인 표준화 변경 매트릭스
| Skill | 변경 위치 | 변경 내용 |
|-------|----------|----------|
| `deep-interview` | Phase 5 Crystallize Spec | spec.md 작성 시 frontmatter (kind=spec, status=PASSED/EARLY_EXIT/HARD_CAP) 추가 |
| `ralplan` | Step "draft plan" | plan.md 작성 시 frontmatter (kind=plan, status=pending) 추가 |
| `ralph` | Step "scaffold prd.json" / iteration body | prd.json에 `_descriptor` 추가 + notepads/*.md append 패턴 표준화 |
| `team` | Stages 1-6 | team-*.md 파일 frontmatter + lock 획득/해제 + events.jsonl append |
| `autopilot` | Phase 5 + Phase 6 | Phase 5 advisor 호출 시 prompt에 "산출 파일 경로 명시" 표준 template + Phase 6 cleanup 호출 |
| `code-review` | Step "delegate to advisors" | advisor 호출 시 산출 파일 경로 명시 표준 template |

### 신규 스크립트
- `scripts/validate.sh` (또는 기존 validate.sh 확장): descriptor schema validator
- `scripts/cleanup.sh` (신규): `--slug=<slug>` 또는 `--all`로 expired/session 파일 정리

### Prompt template (skill SKILL.md에 인라인 추가, 6개 모두 동일 형식)
````
When invoking advisor agent <name>, the Task prompt MUST include:

1. **Input descriptor reference**: <input file path> + brief content summary
2. **Output instruction**: "Write your findings to `.specs/<slug>/artifacts/ask/<agent>-<ISO8601>.md` with frontmatter:
   ```yaml
   ---
   kind: advisor
   path: <output path>
   producer: <agent name>
   createdAt: <ISO8601>
   retention: session
   status: complete
   ---
   ```
3. **Status semantics**: advisor outputs use status=complete; verdict (APPROVE/REJECT/REVISE) is in the body, not the descriptor.
````

## Context (brownfield)

### 현재 hg-pyun-tools 구조 (explorer 매핑 결과)
- **Explicit skill↔skill 파일**: `.specs/<slug>/spec.md`, `plan.md`, `prd.json`, `progress.txt`, `team-*.md` (6개 stage), `autopilot-validation.md`
- **Implicit skill↔agent**: `Task` prompt 텍스트로만 (architect/critic/reviewer/security-auditor/performance-analyst/doc-writer/executor/test-engineer/explorer 9개 agent — agent.md 파일은 역할/핸드북만 담음)
- **현재 부족한 OMC 패턴** (research-omc.md §7):
  - Artifact descriptor schema 부재
  - Status enum 불통일 (spec.md=`Status: PASSED` vs plan.md=`Status: pending approval`)
  - State write contract 부재 (autopilot 재개 불가능)
  - Phase boundary marker 부재
  - Lock 부재
  - Persistence tag (`<remember>`) 부재

### OMC 핵심 참조 (research-omc.md §1-6)
- §1 디렉터리: `.omc/state/`, `.omc/specs/`, `.omc/plans/`, `.omc/notepads/<plan-name>/{learnings,decisions,issues,problems}.md`, `.omc/artifacts/ask/<provider>-<slug>-<ts>.md`
- §3 Artifact descriptor: 8개 필드 (kind/path/contentHash/createdAt/producer/sizeBytes/retention/expiresAt)
- §3 PRD story: id/title/acceptanceCriteria/passes
- §3 State write: `state_write(mode, current_phase, state={stage_history})`
- §4 Locks: `tasks/<team>/.lock`
- §4 Events: append-only `events.jsonl` (V2 source of truth)
- §6 원칙: "Never paste large payloads inline — use descriptors when over threshold"

### 의존 가능한 기존 패턴
- 9-section SKILL.md house style (CLAUDE.md L80 — Purpose / Use_When / Do_Not_Use_When / Why_This_Exists / Execution_Policy / Steps / Tool_Usage / Examples / Final_Checklist)
- `subagent_type` bare-name agent invocation (CLAUDE.md L67)
- Plugin version management (CLAUDE.md L1-30 — 변경 시 plugin.json + marketplace.json 동시 bump)
- `settings.language` + `$LANGUAGE` 표준 (CLAUDE.md L85)

## Tradeoffs
| Choice | Pros | Cons |
|--------|------|------|
| Descriptor 위치: (d) hybrid (.md=frontmatter, .json=`_descriptor`) | 각 파일 자급자족, native 관례 존중 | 두 포맷 처리 코드 모두 필요 |
| Storage: 기존 `.specs/<slug>/` 하위 확장 (vs `.omc/` 신규 도입) | 하위 호환, marketplace 외부 충돌 없음 | OMC 다른 ecosystem과 직접 호환 안 됨 |
| Agent I/O: skill-layer만 표준 (vs agent.md 수정) | 12개 agent.md 수정 면제, maintenance 작음 | agent 명세에서 I/O 자체 가시성 낮음 (skill SKILL.md 봐야 알 수 있음) |
| Skill 표준화: (a) inline (vs (b) HANDOFF.md 공용) | 자기완결, 9-section grain 유지 | template 변경 시 6 SKILL.md 동기화 필요 |
| Lock: mkdir-based (vs POSIX flock) | cross-platform, atomic | 만료 lock 정리 로직 직접 구현 필요 |
| Cleanup: dual trigger (vs auto-only) | 사용자 수동 제어, 디버깅 용이 | cleanup 책임 위치가 2곳 (autopilot + scripts) |

## Assumptions Exposed & Resolved
| Assumption | Challenge | Resolution |
|------------|-----------|------------|
| "agents간 hand-off" = agent.md 수정 | Contrarian R4: skill이 이미 prompt로 명시함 — agent.md 변경 불필요 | agent.md 미수정, skill-layer만 표준화 |
| 전체 OMC parity (descriptor 8 필드) 필요 | R1: 어떤 목적이 우선? | OMC parity 풀 세트 채택 (지난 spec/plan retention 자동화) |
| 풀 acceptance (8개 AC) 최소 세트 | Simplifier R6: 최소 MVP 가능? | 사용자 explicit 선택으로 풀 8개 모두 채택 |
| Lock은 POSIX flock 필요 | R8 contrarian (변형): cross-platform? | mkdir-based atomic locking 채택 — Windows safe |
| cleanup은 autopilot 자동만 | R8: 수동 명령도? | dual trigger (auto + manual scripts/cleanup.sh) |
| `.omc/` 디렉터리 신규 도입 | 하위 호환 가능한가? | `.specs/<slug>/` 하위 확장으로 결정 — 기존 경로 불변 |

## Ontology (Key Entities)
| Entity | Type | Fields | Relationships |
|--------|------|--------|---------------|
| Descriptor | core | kind, path, contentHash, createdAt, producer, sizeBytes, retention, expiresAt, status | attaches-to Artifact |
| Artifact | core | file path, content, descriptor | produced-by Skill or Agent |
| Skill | supporting | name, version, invokes(Agent) | orchestrates Agent calls |
| Agent | supporting | name, role, model | called-by Skill (Task) |
| State | supporting | mode, current_phase, stage_history | written-by Skill |
| Notepad | supporting | kind (learnings/decisions/issues/problems), entries | maintained-by ralph |
| EventsLog | external | line-by-line events (team mode) | append-only by team workers |
| Phase | supporting | autopilot 1-6, ralph iter, team stage | tracked-in State |
| PromptTemplate | supporting | skill-side template (inline in SKILL.md) | references Descriptor |
| Lock | supporting | target file path, owner identifier, createdAt | mkdir-based atomic |

## Ontology Convergence
| Round | Entity Count | New | Changed | Stable | Stability |
|-------|--------------|-----|---------|--------|-----------|
| 1     | 4 (Descriptor, Artifact, Agent, Skill) | 4 | - | - | N/A |
| 3     | 8 (+ State, Notepad, EventsLog, Phase) | 4 | 0 | 4 | 0.50 |
| 4     | 9 (+ PromptTemplate; Agent.md unmodified) | 1 | 1 (Agent 역할 좁힘) | 7 | 0.89 |
| 5     | 10 (+ Lock) | 1 | 0 | 9 | 0.90 |
| 6-9   | 10 (변동 없음) | 0 | 0 | 10 | 1.00 |

## Open Questions
- `producer` 형식이 skill 이름과 agent 이름을 자유롭게 섞을지, 별도 namespace prefix (`skill:deep-interview`, `agent:architect`)를 둘지 — 현재 spec은 free string으로 두지만 향후 정합성 검증 시 prefix 권장.
- `events.jsonl`의 event schema (각 line의 JSON 형식)은 본 spec 범위 외 — ralplan 단계에서 정의.
- `contentHash` 산출 시 descriptor 자체를 제외하는 알고리즘 (split-on-marker vs sha-of-rest) — 구현 시점 결정.
- `state/team.json`의 lock contention 시 retry 정책 (backoff) — ralplan 단계에서 결정.

## Interview Transcript

<details>
<summary>Full Q&A (9 rounds + Phase 0)</summary>

### Phase 0: Pre-research (autopilot Phase 0)
- 산출물: `.specs/agent-file-handoff-strategy/research-omc.md` (OMC 패턴 survey, 2026-05-23 producer=autopilot-phase0-research)
- explorer agent: hg-pyun-tools 현재 hand-off 매핑 (skill↔skill explicit, skill↔agent implicit)

### Round 0 — Topology Confirmation
**Q:** 4-component proposal (Descriptor / Storage / Agent I/O / Concurrency & Lifecycle).
**A:** "4개 모두 OK"
**Topology:** 4 active, 0 deferred. Locked.

### Round 1 — Component 1 (Descriptor) Goal
**Q:** OMC parity (8 필드) vs 부분 채택?
**A:** "OMC parity 풀 세트"
**Ambiguity:** 77%

### Round 2 — Component 3 (Agent I/O) Goal
**Q:** skill↔skill 공식화 / agent도 파일 / 둘 다 / agent.md만?
**A:** "omc에서는 어떻게하는지 판단해서 벤치마킹"
**Ambiguity:** 70% (assistant가 OMC 해석 후 다음 라운드에서 구체 layout 확인)

### Round 3 — Component 2 (Storage) Goal
**Q:** OMC-derived layout (4개 서브디렉터리: state, artifacts/ask, notepads, events.jsonl)?
**A:** "제안대로 적용 (권장)"
**Ambiguity:** 66.5%

### Round 4 — Component 3 (Agent I/O) Contrarian
**Q:** agents/*.md를 전혀 건드리지 않아도 되지 않나? (skill-only 표준화)
**A:** "agents/*.md 곳 그대로, skill만 표준화"
**Ambiguity:** 62.5% (scope reduction: 12개 agent.md 미수정 확정)

### Round 5 — Component 4 (Concurrency & Lifecycle) Goal
**Q:** lock만 / TTL만 / 둘 다 / 전체 defer?
**A:** "lock·TTL 둘 다 포함 (풌 OMC)"
**Ambiguity:** 40.75%

### Round 6 — Cross-component Success Criteria (Simplifier)
**Q:** 최소 acceptance set vs 풀 8개?
**A:** "A·B·C·D·E·F·G·H 전부 (풌)" — Simplifier 거부, 풀 세트 선택
**Ambiguity:** 30%

### Round 7 — Component 1 (Descriptor) Constraints
**Q:** descriptor 위치 — (a) frontmatter / (b) 사이드카 / (c) 중앙 index / (d) hybrid?
**A:** "(d) hybrid: .md는 YAML frontmatter, .json은 _descriptor key"
**Ambiguity:** 25.25%

### Round 8 — Component 4 (Concurrency) Constraints
**Q:** Lock 메커니즘 + cleanup 트리거 조합?
**A:** "Lock = `mkdir .lock` (atomic) + Cleanup = (iii) 둘 다"
**Ambiguity:** 22.75%

### Round 9 — Component 3 (Agent I/O) Constraints
**Q:** Skill 표준화 방식 — (a) inline / (b) 공용 HANDOFF.md / (c) hybrid / (d) 최소?
**A:** "(a) 인라인 표준화, 6개 SKILL.md + scripts/ 모두 수정"
**Ambiguity:** 14% — **THRESHOLD MET**

</details>

## Challenge Agents Activation Record
- **R4 Contrarian** (활성화 + 사용): "agents/*.md 수정 필요한가?" → 결과: 미수정 결정. 구현 면적 크게 축소.
- **R6 Simplifier** (활성화 + 사용): "최소 MVP?" → 사용자 풀 8개 AC 선택. Simplifier 거부 사례.
- **R8 Ontologist** (R8 gate 시점 ambiguity=25.25% ≤ 0.3 → 비활성). 정책상 ambiguity > 0.3 조건 미충족.
