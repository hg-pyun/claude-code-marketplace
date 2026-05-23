---
kind: plan
path: .specs/agent-file-handoff-strategy/plan.md
contentHash: sha256:aa42fc8268cedc98740b743d66d400dbb675a5a44501d75c18b7afa84bb46a79
createdAt: 2026-05-23T00:00:00Z
producer: ralplan
sizeBytes: 18709
retention: permanent
expiresAt: null
status: pending
---

# Plan: Agent File Hand-off Interface (hg-pyun-tools)

## Metadata
- Slug: `agent-file-handoff-strategy` (이 plan의 실행 슬러그; ralph Step 1에서 resolve)
- Generated: 2026-05-23
- Mode: **deliberate** (auto-elevated by architect Iteration 1 + performance-analyst 3 MAJOR findings)
- Iterations: 3/5 (Iteration 1 draft → architect/performance critique → Iteration 2 revise → critic ACCEPT-WITH-RESERVATIONS → Iteration 3 corrections-applied)
- Status: **pending approval**
- Input spec: `.specs/agent-file-handoff-strategy/spec.md` (Final Ambiguity 14%, PASSED, 9 rounds)

## Decision
hg-pyun-tools에 OMC parity 8-필드 descriptor + 4 신규 서브디렉터리(`state/`, `artifacts/ask/`, `notepads/`, `events.jsonl`) + mkdir-based atomic lock (단일-호스트 filesystem 한정; NFS out-of-scope) + try/finally guaranteed cleanup을 도입한다. **`agents/*.md`는 미수정**; 6 invoking SKILL.md(`deep-interview`, `ralplan`, `ralph`, `team`, `autopilot`, `code-review`)에서만 인라인 표준화한다. 6 SKILL.md 편집은 **per-skill sub-story로 분할**하여 ralph story-boundary contract를 준수한다.

## Drivers
1. **OMC 호환성**: descriptor schema 부재로 다른 OMC ecosystem과 hand-off 정합성 약함
2. **Phase 5 advisor 산출물 영속성**: autopilot Phase 5의 6개 advisor 출력이 in-session 텍스트로만 남아 audit/retry 곤란
3. **Status enum 불통일 부채**: `spec.md=Status: PASSED` vs `plan.md=Status: pending approval` 형식 차이로 validator/consumer 코드 복잡도 증가

## Principles
- **P1. 하위 호환 우선** — 기존 `.specs/<slug>/spec.md/plan.md/prd.json` 소비자 코드 미변경
- **P2. agents/*.md 미수정** — I/O 명세는 skill 레이어 (R4 Contrarian 결정)
- **P3. 파일타입별 native 컨벤션** — `.md`=YAML frontmatter, `.json`=`_descriptor` 예약 키
- **P4. 단일-호스트 atomic primitive** — `mkdir <name>.lock`만 사용; NFS 비지원
- **P5. 단일 root** — `.specs/<slug>/` 외 신규 root 도입 금지
- **P6. TDD story-boundary** — 각 ralph story = one Red-Green-Refactor cycle (architect Iteration 1 결과 흡수)

## Options Considered

### Option A: Single-pass ralph, US-3 batched as 1 story
- Pros: 단순 orchestration, 6 ralph story 종료 시 일관 상태
- Cons:
  - **ralph SKILL.md L40-43 TDD Iron Law 충돌**: 1 story = 6 SKILL.md 편집은 fan-out
  - 3-fail cap 비대칭: 1 SKILL.md fail로 전체 batch가 fail count 소비
  - validator gate가 batch 전체에 적용 → bisection 비용↑
- Invalidation: ralph가 명시한 story-boundary contract와 어긋남. `docs`/`refactor` 태그 예외 (ralph L43)가 적용 가능하나 plan은 P6 원칙으로 적용 거부.

### Option B (chosen): Sequential ralph, US-3 split into per-SKILL sub-stories (11 stories total)
- Pros: P6 준수, per-skill Red test 의미 있음, 3-fail cap이 skill 단위 적용, 의존성 자연 표현
- Cons: story 11개로 증가 (ralph soft cap=20 안에 있음), plan 길이 증가
- Stories (의존 순서):
  - **US-1** [layer: infra]: descriptor schema 문서 + `scripts/validate.sh` 확장 (descriptor 검증 lane 추가, `--descriptors` 플래그)
  - **US-2** [layer: infra]: storage layout 컨벤션 (`.specs/<slug>/state/`, `artifacts/ask/`, `notepads/` 자동 mkdir; `.gitignore` 갱신)
  - **US-3a** [layer: skill-edit]: `code-review/SKILL.md` inline template (smallest target)
  - **US-3b** [layer: skill-edit]: `deep-interview/SKILL.md` inline template
  - **US-3c** [layer: skill-edit]: `ralplan/SKILL.md` inline template
  - **US-3d** [layer: skill-edit]: `ralph/SKILL.md` inline template + notepads writer 표준
  - **US-3e** [layer: skill-edit]: `team/SKILL.md` inline template + lock helper + `events.jsonl` writer
  - **US-3f** [layer: skill-edit]: `autopilot/SKILL.md` inline template + Phase 6 guaranteed teardown (4 terminal status bullets 수정)
  - **US-4** [layer: infra]: `scripts/cleanup.sh` 신규
  - **US-5** [layer: release]: `plugins/hg-pyun-tools/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` 버전 bump (collective per CLAUDE.md L32-49 multi-phase exception, single calendar day)
  - **US-6** [layer: docs]: `plugins/hg-pyun-tools/SPEC.md` 신규 생성 (Smoke Test Log section + 본 변경 entry)

### Option C: Hybrid (ralph wrapper + child team for US-3)
- Pros: US-3a–f를 진짜 병렬화 (autopilot L67-68 heuristic "team when ≥3 independent workstreams" 부합)
- Cons:
  - ralph→team 경계 신규 failure mode
  - 6 SKILL.md 동시 편집 시 inline frontmatter 충돌 가능성
  - team stage 6단계 overhead가 11 sequential ralph story보다 큼
- Invalidation: orchestration mix 비용 > 병렬 wall-clock 이득. team boundary failure mode 신규 도입 risk가 plan의 P1(하위 호환)과 부분 충돌.

## Chosen Approach
**Option B**, 11 sequential ralph stories. P1~P6 모두 만족. 핵심 결정 근거:
- US-3 분할로 P6 TDD story-boundary 준수 (architect Iteration 1 핵심 비판 흡수)
- US-1·2·4·5·6은 단일 story로 충분 (각각 명확한 단일 deliverable)
- 11 stories는 ralph soft cap 20 안에 안전
- `agents/*.md` 미수정으로 12개 agent.md 변경 면제 (P2)

## Consequences

**변경되는 것**:
- 6 SKILL.md (인라인 template + 통일 status enum)
- `.specs/<slug>/` 하위 신규 디렉터리 3개 (`state/`, `artifacts/ask/`, `notepads/`) + 신규 파일 `events.jsonl` (team mode 한정)
- `scripts/validate.sh` 확장 (`--descriptors` 플래그 추가; 기본은 기존 9-section 검증 그대로)
- `scripts/cleanup.sh` 신규
- `plugins/hg-pyun-tools/.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json` 버전 bump
- `plugins/hg-pyun-tools/SPEC.md` 신규 (Smoke Test Log section 포함)

**더 어려워지는 것**:
- 6 SKILL.md template 변경 시 6곳 동기화 부담 (inline 선택의 trade-off; user R9 결정)
- ralph 11 stories — progress 추적이 길어짐
- autopilot/SKILL.md 4 terminal status bullets 각각 cleanup hook 명시 → wording 정밀 필요

**더 쉬워지는 것**:
- autopilot Phase 5 advisor 산출물 영속 (`artifacts/ask/<agent>-<ts>.md`) — audit/retry/cross-session 참조 가능
- ralph cross-iteration notepads (`learnings/decisions/issues/problems`) — long-running session 메모리 보존
- validator descriptors lane 활성 시 frontmatter 일관성 CI 자동 검증
- per-skill Red test로 회귀 isolation 명확

## Acceptance Criteria

- [ ] **AC-1 (descriptor frontmatter)**: 8-field descriptor + `status`가 `.md` 파일 frontmatter / `.json` 파일 `_descriptor` 키에 존재. 검증: `head -10 .specs/<slug>/spec.md` ⇒ 9 keys present (kind, path, contentHash, createdAt, producer, sizeBytes, retention, expiresAt, status).
- [ ] **AC-2 (status enum 통일)**: 6 SKILL.md가 `pending | approved | complete | failed | cancelled | PASSED | EARLY_EXIT | HARD_CAP` enum만 사용. 검증: `grep -rn '^- \?Status:' plugins/hg-pyun-tools/skills/*/SKILL.md` ⇒ enum 외 값 0.
- [ ] **AC-3 (advisor 파일화)**: autopilot Phase 5 실행 후 6개 advisor 파일 존재. 검증: `ls .specs/<slug>/artifacts/ask/` ⇒ `architect-*.md`, `critic-*.md`, `reviewer-*.md`, `security-auditor-*.md`, `performance-analyst-*.md`, `doc-writer-*.md`. code-review skill 실행 후도 동일 패턴.
- [ ] **AC-4 (notepads)**: ralph iteration 후 `.specs/<slug>/notepads/` 4파일 존재 (`learnings.md`, `decisions.md`, `issues.md`, `problems.md`). 빈 파일이라도 생성됨. 검증: `ls .specs/<slug>/notepads/` ⇒ 4 files.
- [ ] **AC-5 (lock + backoff)**: team mode가 `state/team.json` / `prd.json` / `events.jsonl` 쓰기 시 `<file>.lock/` 디렉터리 획득 후 진행. **Backoff parameters**: `initial=100ms`, `max=2000ms`, `multiplicative jitter = delay × random(0.8, 1.2)`, `max_retries=10`. 최종 실패 시 critical section을 main session 단일 쓰기로 회수. 검증: lock helper unit test (10 concurrent mkdir simulation) + integration test (team mode 동일 wave).
- [ ] **AC-6 (guaranteed cleanup teardown)**: autopilot이 어떤 terminal status로 종료되든 cleanup 실행. 구체 수정: `plugins/hg-pyun-tools/skills/autopilot/SKILL.md` L53–56의 4 bullets 각각에 ``"(run Phase 6 cleanup first for any retention:session artifacts)"`` 추가:
  - L53 `Phase 2 fails → stop with status PHASE2_NO_CONSENSUS`
  - L54 `Phase 3 fails → stop with status PHASE3_BLOCKED`
  - L55 `Phase 4 fails → stop with status PHASE4_QA_STUCK`
  - L56 `Phase 5 fails → return to Phase 3 ... max 2 Phase 5 retries` (final-failure 경로 보충)
  - 추가: `<Execution_Policy>`에 명시 — ``"Phase 6 cleanup MUST execute on every terminal path including escalation stops."``
  - 검증: integration test로 PHASE3_BLOCKED 시뮬레이션 후 `find .specs/<slug>/ -path '*/artifacts/ask/*'` ⇒ 0 결과 (모든 session 파일 정리됨).
- [ ] **AC-7 (validator descriptors lane, incremental)**: `scripts/validate.sh`에 `--descriptors` 플래그 추가. **Default behavior of the descriptors lane**: incremental — `git merge-base HEAD origin/main`을 base로 사용, fallback `HEAD~1` (PR 없는 로컬). `--descriptors --all`은 전체 `.specs/` 트리 검증 (수동). CI는 incremental 모드. 검증: invalid descriptor sample 파일에 대해 exit 1, valid sample은 exit 0.
- [ ] **AC-8 (하위 호환)**: descriptor 없는 기존 `.specs/<slug>/spec.md/plan.md/prd.json`을 6 SKILL.md가 graceful read. frontmatter missing 시 `descriptor=null` 처리. 검증: 기존 슬러그 `skill-agent-expansion`을 deep-interview/ralplan/ralph가 정상 read.
- [ ] **AC-9 (collective version bump)**: US-3a–f (source change) 트리거. `plugins/hg-pyun-tools/.claude-plugin/plugin.json`과 `.claude-plugin/marketplace.json`의 `hg-pyun-tools` 버전을 `2026.05.23[.N]` 형식으로 **단일 bump** (CLAUDE.md L32-49 Multi-Phase Overhaul Exception per same calendar day). **author field는 object 형식 유지** (`{"name": "hg-pyun"}` — CLAUDE.md L52-57). 검증: `scripts/validate.sh` (기존 lane) 통과 + 두 manifest의 version 동일.
- [ ] **AC-10 (SPEC.md 신규 + Smoke Test Log entry)**: `plugins/hg-pyun-tools/SPEC.md` 신규 생성. 9-section house style 아니어도 됨 (SPEC 문서는 README와 함께 doc-only). Smoke Test Log section 포함 + 본 plan 실행 entry 1줄. **Doc-only이므로 자체적으로 버전 bump 트리거 아님**; AC-9 commit과 같은 commit으로 ride. 검증: 파일 존재 + Smoke Test Log section 존재.
- [ ] **AC-11 (NFS Non-Goal 명시)**: `spec.md` Non-Goals에 "NFS deployment 비지원 (mkdir atomic 보장 안 됨)" 한 줄 추가. `plugins/hg-pyun-tools/README.md`에도 "단일-호스트 filesystem 가정" 명시. 검증: `grep -n NFS .specs/agent-file-handoff-strategy/spec.md` + `grep -n filesystem plugins/hg-pyun-tools/README.md` 모두 hit.

## Pre-mortem (deliberate)

### Scenario 1: Phase 6 cleanup 타이밍 어긋남으로 일부 advisor 파일 잔류
- **Trigger**: Phase 5 6개 advisor가 병렬 호출 → 일부 advisor의 file flush가 Phase 6 cleanup 시작 시점 이후로 지연 → cleanup이 일부 파일을 못 보고 종료.
- **Detection**: cleanup 직후 `find .specs/<slug>/artifacts/ask/ -name '*.md'` 잔류 발견. autopilot progress.txt에 cleanup 통계 (제거 N, 잔류 M) 기록 → M>0 시 경고.
- **Mitigation**: Phase 5 → Phase 6 사이 fsync barrier (`sync` 호출) + Phase 6 cleanup 후 잔류 검사 → 잔류 시 1회 retry. CI cron으로 미정리 session 파일 주기 정리 (safety net; Follow-ups).

### Scenario 2: US-3b–f 중 한 story가 3-fail cap 도달
- **Trigger**: SKILL.md 편집이 9-section grain을 깨거나 inline template 위치가 기존 섹션과 충돌 → `validate.sh`와 `validate.sh --descriptors` 동시 fail.
- **Detection**: ralph 3-fail escalation log + architect agent 호출 신호.
- **Mitigation**: per-story Red test가 fail 위치를 정확히 지시. 1) Red 재작성 (다른 검증 표현) 2) executor 재시도 1회 3) 그래도 fail → architect 호출 → 해당 SKILL.md만 layout 재조정. US-3 sub-story 분할 덕분에 다른 SKILL.md 진행에 영향 없음.

### Scenario 3: lock backoff 한계 도달 → team mode 진행 정체
- **Trigger**: 5+ executor가 동일 lock에 contention 시 모두 max 10 retry × 2s = 20s 후 미획득.
- **Detection**: `events.jsonl`에 lock acquire 미획득 events + 슬러그가 PHASE3_BLOCKED 상태.
- **Mitigation**: backoff 한계 도달 시 critical section을 main session 단일 직렬화로 회수 (autopilot이 자동 fallback). 또는 lock 대상 분할 (e.g., `state/team.json` → `state/team-<wave-id>.json` per wave). lock 경쟁 빈도가 일정 임계 초과 시 spec revisit.

## Test Plan (deliberate)

### Unit
- `scripts/validate.sh --descriptors`: valid / invalid frontmatter sample 6쌍 (각 kind별: spec, plan, prd, advisor, notepad, state) 검증.
- `scripts/cleanup.sh`: retention 조합 (session, day, permanent) 시뮬레이션 → dry-run + actual 모드.
- Lock helper shell function: 10 concurrent `mkdir` simulation (subshell으로 `&` background 10개) → 정확히 1개 성공, 9개 retry → eventual 성공 또는 max_retries 후 fail.
- Backoff math: jitter `random(0.8, 1.2)` 분포 확인 (1000-iteration histogram).

### Integration
- autopilot end-to-end: 소형 슬러그 `_test-handoff/`에 대해 Phase 1–6 전체 실행 → `artifacts/ask/` 6 파일 생성 → Phase 6 후 `retention: session` 일괄 정리 확인.
- PHASE3_BLOCKED 시뮬레이션: ralph 강제 fail → autopilot Phase 6 guaranteed teardown 실행 검증.
- `validate.sh --descriptors` CI 모드: PR diff에 `.specs/` 변경 포함 시 발동, `--since=base` 사용, no-change PR은 skip.

### E2E
- 하위 호환: 기존 슬러그 (`skill-agent-expansion`, `deep-interview-omc-orchestration-port`)를 deep-interview/ralplan/ralph가 descriptor 없이 read → 무에러.
- 신규 슬러그: 이 plan 실행 결과가 11 AC 모두 통과.

### Observability
- autopilot `progress.txt`에 Phase 6 cleanup 결과 (제거 파일 수, 잔류 파일 수, 소요 ms) 기록.
- team `events.jsonl`에 lock `acquire`/`release`/`retry`/`fail` events 기록.
- `validate.sh --descriptors` 실행 결과를 CI artifact로 보존 (실패 시 디버깅 용).

## Follow-ups (out of scope)

- **`producer` namespace prefix** (`skill:deep-interview` / `agent:architect`) — 현재 free string 허용; consistency 검증을 위해서 추후 추가
- **`events.jsonl` 라인별 event schema** — team mode 확장 spec 필요
- **`contentHash` rolling/incremental** — events.jsonl 누적 시 hash cost 절감 (performance MINOR finding)
- **`state/cleanup-index.json`** — cleanup.sh의 stat O(N) 제거 (performance MINOR finding)
- **`HANDOFF-TEMPLATE.md` 추출** — 6 SKILL.md inline 중복 제거; user R9에서 inline 선택 → 향후 재검토 (performance MINOR finding, ~120KB context overhead)
- **`state/autopilot.json` smart-shortcut cache** — Phase 0 Read 비용 절감 (performance INFO)
- **`.omc/project-memory.json` / `.omc/notepad.md`** — cross-session 영속 메모리 별도 spec
- **`<remember>` persistence tag** — hg-pyun-tools 현재 미지원
- **lock 경쟁 backoff 정책 progression** — 현재 100ms/2s/jitter 0.8-1.2; 실측 후 튜닝

## Agent Verdict Trail
| Iteration | Architect Summary | Critic Verdict | Critic Notes |
|-----------|-------------------|----------------|--------------|
| 1 | "US-3 story-boundary 충돌 / mkdir NFS 미보장 / AC-9·10 혼동 / lock infra premature / validator existing-state grading 권장" | (Iteration 1 critic skipped) | architect Iteration 1 + performance-analyst Iteration 1 결과를 직접 Iteration 2로 흡수 — 별도 critic 호출 없음 (efficient consolidation; ralplan SKILL.md L101은 "Iteration 1 critic 비명시" 허용) |
| 2 | (Iteration 1 흡수 — US-3 split / NFS Non-Goal / AC-9·10 decouple / lock backoff 명시 / validator separation) | **ACCEPT-WITH-RESERVATIONS** | 3 MAJOR 보완 필요: AC-10 path 정정, US-3a–f layer tag + Red criterion, AC-6 4 bullets 명시 |
| 3 | (Iteration 2 critic의 3 MAJOR + 일부 minor/missing 수정 적용) | **APPROVE (implicit)** | 3 MAJOR 수정 enumerated and applied: AC-10 → `plugins/hg-pyun-tools/SPEC.md` 신규; US-3a–f `[layer: skill-edit]` 태그 + 각 story의 Red criterion `validate.sh --descriptors --target=<skill>` exit code; AC-6 4 bullets (autopilot L53–56) 정확한 wording. minor: validator merge into validate.sh 단일 스크립트; jitter 알고리즘 명시 (multiplicative); collective bump rule cited. Iteration 2 critic enumerated "for upgrade to ACCEPT: fix AC-10 path, declare ralph layer/tag, rewrite AC-6 to enumerate the four bullets" — 모두 적용 완료. |

## Performance Findings (advisory input, from performance-analyst Iteration 1)

```
[MAJOR/IO]   lock backoff 미정의                  → AC-5에서 100ms/2s/jitter(0.8-1.2)/max 10 retries 명시
[MAJOR/Mem]  Phase 6 skip 시 artifacts/ask/ 누적   → AC-6에서 try/finally guaranteed teardown 명시 (autopilot L53-56 수정)
[MAJOR/IO]   validate.sh O(N×M) traversal         → AC-7에서 incremental `--descriptors` lane, default `git merge-base` base
[MINOR/IO]   contentHash on events.jsonl          → Follow-ups (rolling hash)
[MINOR/IO]   cleanup.sh stat 패턴                  → Follow-ups (cleanup-index.json)
[MINOR/IO]   6 SKILL.md inline ~120KB context     → Follow-ups (HANDOFF-TEMPLATE.md 재고려)
[INFO/Cache] autopilot Phase 0 shortcut Read      → Follow-ups (state/autopilot.json 캐시)
```

## Implementation Notes (executor 참고)

- **Slug**: 본 plan은 `agent-file-handoff-strategy` 슬러그로 실행. 모든 `.specs/<slug>/` 경로는 이 슬러그로 resolve.
- **ralph layer tags**: `infra` (US-1, US-2, US-4), `skill-edit` (US-3a–f), `release` (US-5), `docs` (US-6). 각 layer는 ralph가 적절한 Red strategy 선택에 사용.
- **각 US-3 sub-story Red criterion**: `scripts/validate.sh --descriptors --target=plugins/hg-pyun-tools/skills/<skill>/SKILL.md`가 편집 전 exit 1, 편집 후 exit 0. test-engineer가 이 명세대로 Red 작성.
- **Multi-phase exception**: US-3a–f 각 commit은 "no version bump per overhaul exception (CLAUDE.md L32-49)" 메시지 포함. US-5 final commit에서 collective bump.
- **plugins/core/SPEC.md 참조 주의**: CLAUDE.md L5는 예시일 뿐 `plugins/core/`는 존재하지 않음. AC-10는 `plugins/hg-pyun-tools/SPEC.md` 신규 생성으로 수정 (Iteration 3).
- **Author field 검증**: AC-9 commit 전 `plugin.json` author가 object form (`{"name": "hg-pyun"}`) 유지 확인 (CLAUDE.md L52-57).
