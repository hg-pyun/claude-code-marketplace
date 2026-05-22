# Team Stage 2: team-prd (Acceptance Criteria Refinement)

## Inputs
- `.specs/skill-agent-expansion/team-plan.md` (Stage 1 handoff)
- `.specs/skill-agent-expansion/plan.md` (23 AC list)

## Decisions
- **9 stories** finalized in `prd.json`. Generic placeholder AC 없음 — 모든 AC가 plan.md의 file-anchored AC와 1:1 매핑.
- US-008 (smoke + validate)에서 dogfood transcript는 `.specs/skill-agent-expansion/dogfood-transcript.md`로 첨부 (PR description 대안 — plan AC-20 두 위치 모두 허용).
- AC verification 명령(grep/jq)은 모두 description에 포함, executor가 결과 evidence 첨부 가능.

## Rejected Alternatives
- **모든 9 stories를 wave 1에 (단일 wave, 9 parallel)**: --max-parallel=5 기본 cap 초과 + version bump가 source 변경 전에 일어나면 CLAUDE.md "Plugin Version Management Rules" 위반 위험. 채택 안 함.
- **US-007a를 wave 2에**: spec erratum은 source 변경 commit 시 함께 들어가야 하는 spec 정합성 유지 작업. wave 2로 미루면 source는 변경됐는데 spec은 stale인 중간 상태가 생김. wave 1 유지.

## Risks Identified
| Risk | Mitigation |
|------|------------|
| Wave 1 batch_a 5 parallel이 동시 token 사용으로 throttle 트리거 | 5 cap 준수 (executor 평균 token 사용량 markdown 작업에선 낮아 위험 낮음) |
| US-007a AC-18 정규식이 quarantine 패턴 호환성 깨질 가능성 | spec erratum 적용 시 HTML comment 우선 사용 (markdown strikethrough는 일부 grep 정규식과 충돌 가능) |
| US-007b가 wave 2에서 single story로 wallclock 손실 | 1 story지만 sub-second 작업, 무시 가능 |
| US-008 dogfood가 advisor 응답 누락 시 rollback 트리거 | Stage 4 verify 전에 prd.json `passes: false` 마킹 + Stage 5 fix loop 진입 |

## Outputs
- `.specs/skill-agent-expansion/prd.json` (9 stories, wave schedule)
- `.specs/skill-agent-expansion/team-prd.md` (this file)

## Remaining Work
- Stage 3 (team-exec): wave 1 (2 batches) → wave 2 → wave 3.
- Stage 4 (team-verify): reviewer + critic 병렬, US-004에 추가 주의.
- Stage 4.5 (team-cleanup): code-review skill cleanup.
- Stage 5 (team-fix): bounded 3-iter loop if needed.
- Stage 6 (team-final): report + stop.

## Dependency DAG Visualization

```
Wave 1 (no deps, parallel):
[US-001] [US-002] [US-003] [US-004] [US-005] [US-006] [US-007a]
   │        │        │        │        │        │        │
   └────────┴────────┴────────┴────────┴────────┴────────┘
                          │
Wave 2:               [US-007b]   (version bump after all source ready)
                          │
Wave 3:               [US-008]    (validate + smoke + CLAUDE.md unchanged)
```

## AC Quality Notes
- All AC have explicit grep / jq / file-existence verification commands.
- 0-strict assertions (e.g., AC-18) require quarantine via HTML comment to avoid regex collision.
- AC-8/AC-11 baseline counts must be measured PRE-edit per file; expected count = baseline + N is locked in story description.

## Story-level Worker Routing
- All 9 stories → `executor` (refactor layer, no test authoring).
- TDD Red step skipped (no production code added).
- Stage 4 will dispatch `reviewer` + `critic` against the aggregated diff.
