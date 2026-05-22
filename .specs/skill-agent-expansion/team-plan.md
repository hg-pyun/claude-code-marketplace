# Team Stage 1: team-plan (Decomposition)

## Inputs
- `.specs/skill-agent-expansion/plan.md` (Iteration 3, Status: pending approval, Critic verdict: APPROVE)
- 23 Acceptance Criteria, 9 changed files

## Decisions
- Decompose into **9 stories** (US-001 ~ US-008 with US-007 split into 007a/007b).
- All stories `layer: refactor` (documentation/config 변경, production code 추가 없음). **TDD Red step 면제** — AC verification은 grep/jq 기반.
- Wave 1에 7 stories 병렬 실행 (US-001/002/003/004/005/006/007a) — 파일 스코프 disjoint, SKILL.md의 advisor 호출 text는 agent .md 존재 여부와 독립.
- Wave 2: US-007b (version bump) — CLAUDE.md "Plugin Version Management Rules"에 따라 source 변경 commit 직전 통합 bump.
- Wave 3: US-008 (validate + smoke + CLAUDE.md unchanged check) — 모든 source 변경 후.
- US-004 (autopilot SKILL.md) blast radius **HIGH**: Phase 5 verdict logic + 6 advisor fan-out 모든 autopilot 호출에 영향. Stage 4 verify에서 reviewer + critic 둘 다 fail-safe로 dispatch.

## Rejected Alternatives
- **8-story flat (단일 wave)**: architect가 semantic dependency 지적 — version bump가 source 변경 전에 일어나면 commit-time 룰 위반. 채택 안 함.
- **4-wave conservative (US-004가 US-001~003에 의존)**: text-only 참조이므로 SKILL.md 변경이 agent .md 존재에 진짜로 의존하지 않음. wallclock 손해 + 정밀도 손해. 채택 안 함.
- **AC-19 (CLAUDE.md no-change)를 US-007에 두기**: negative assertion이라 validate 단계가 자연스러움. AC-19를 US-008로 이동 — 채택.

## Risks Identified
| Risk | Mitigation |
|------|------------|
| Wave 1 7 parallel executor가 token cost 폭증 | 모두 markdown 쓰기/수정, 평균 token 사용 낮음. --max-parallel 기본 5 cap을 명시적으로 7로 상향 안 함 — 2 batches로 split. |
| US-004 stratified verdict text에 ambiguity 잔존 → 모든 autopilot dogfood 영향 | Stage 4 verify에서 US-004 변경 부분을 reviewer + critic 둘 다 패스. critic이 stratified rule을 plan.md와 cross-check. |
| US-007a (spec erratum) grep 0-strict 검증 실패 | erratum 적용 시 HTML comment(`<!-- ... -->`) quarantine 사용 권장. AC-18의 정규식은 `^- \`## Role\` —` 등을 매치하므로 quarantine 후 첫 character가 `<` 또는 `~`가 되어 pattern 회피. |
| US-007b version bump 시 plugin.json과 marketplace.json 불일치 | 한 PR 안에서 같은 commit으로 처리. PR description에 두 파일 동일 version 강조. |
| US-008 dogfood smoke (a)가 실패 (`/code-review` 응답 누락) | Rollback Procedure 트리거. plan.md에 명시된 9-file revert 절차 따름. |

## Outputs
- `.specs/skill-agent-expansion/team-plan.md` (this file).

## Remaining Work
- Stage 2 (team-prd): write `.specs/skill-agent-expansion/prd.json` with 9 stories + AC + assignTo + wave numbers.
- Stage 3 (team-exec): execute waves 1 → 2 → 3 with parallel executor in wave 1.
- Stage 4 (team-verify): reviewer + critic 병렬, US-004에 추가 주의.
- Stage 4.5 (team-cleanup): code-review skill로 cleanup pass.
- Stage 5 (team-fix): if verify finds defects, bounded 3-iter fix loop.
- Stage 6 (team-final): report + stop.

## Story Decomposition Summary

| ID      | Title                                           | layer    | blast | dependsOn               | fileScope                                                                                                                  | ACs covered            |
|---------|-------------------------------------------------|----------|-------|-------------------------|----------------------------------------------------------------------------------------------------------------------------|------------------------|
| US-001  | Write security-auditor.md                       | refactor | medium| []                      | `plugins/hg-pyun-tools/agents/security-auditor.md`                                                                          | AC-1, AC-4(부분), AC-5 |
| US-002  | Write performance-analyst.md                    | refactor | medium| []                      | `plugins/hg-pyun-tools/agents/performance-analyst.md`                                                                       | AC-2, AC-4(부분), AC-6 |
| US-003  | Write doc-writer.md                             | refactor | medium| []                      | `plugins/hg-pyun-tools/agents/doc-writer.md`                                                                                | AC-3, AC-4(부분), AC-7 |
| US-004  | Update autopilot SKILL.md                       | refactor | **HIGH** | []                  | `plugins/hg-pyun-tools/skills/autopilot/SKILL.md`                                                                           | AC-8, AC-9, AC-10, AC-15 |
| US-005  | Update code-review SKILL.md                     | refactor | medium| []                      | `plugins/hg-pyun-tools/skills/code-review/SKILL.md`                                                                         | AC-11, AC-12           |
| US-006  | Update ralplan SKILL.md                         | refactor | medium| []                      | `plugins/hg-pyun-tools/skills/ralplan/SKILL.md`                                                                             | AC-13                  |
| US-007a | Spec erratum                                    | refactor | low   | []                      | `.specs/skill-agent-expansion/spec.md`                                                                                      | AC-18                  |
| US-007b | Version bump (plugin.json + marketplace.json)   | refactor | low   | [US-001..US-006, US-007a]| `plugins/hg-pyun-tools/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`                                       | AC-16, AC-17           |
| US-008  | Validate + Smoke + CLAUDE.md unchanged          | verify   | low   | [US-001..US-007b]       | `scripts/validate.sh` 실행 + `git diff CLAUDE.md` empty + `/code-review` dogfood + smoke transcript 첨부                    | AC-14, AC-19, AC-20, AC-21, AC-22, AC-23 |

## Wave Schedule

```
Wave 1 (parallel, 7 stories):  [US-001] [US-002] [US-003] [US-004] [US-005] [US-006] [US-007a]
                                  │       │       │       │       │       │        │
                                  └───────┴───────┴───────┴───────┴───────┴────────┘
Wave 2 (1 story):                                          [US-007b]
                                                              │
Wave 3 (1 story):                                          [US-008]
```

Wave 1은 --max-parallel=5 기본 cap을 준수하여 2 batches로 split:
- Batch 1a: US-001, US-002, US-003, US-004, US-005 (5)
- Batch 1b: US-006, US-007a (2)

## Parallelism Budget
- Peak wave size: 5 concurrent executors (cap 준수)
- Total executor invocations: 9 (1 per story, wave 1은 batch split이지만 동일 wave)
- Test-engineer invocations: 0 (모든 story가 refactor — Red 면제)
- Stage 4 verify: reviewer + critic 병렬 (1 wave)
- Stage 4.5 cleanup: code-review skill 1회 호출

## Risk-weighted verify allocation
- US-004 (blast HIGH): reviewer + critic 패스에서 stratified verdict text를 plan.md AC-9 명세와 cross-check 강조
- 그 외 stories: 표준 reviewer + critic 패스
