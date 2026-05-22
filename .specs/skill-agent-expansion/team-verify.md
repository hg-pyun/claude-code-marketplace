# Team Stage 4: team-verify (Review) + Stage 5: team-fix (iter 1)

## Inputs
- `.specs/skill-agent-expansion/team-exec.md` (Stage 3 결과)
- 8 changed files (3 new agents + 3 SKILL.md + 2 manifest) + 1 spec erratum

## Stage 4 — Verify Verdicts (parallel reviewer + critic)

### Reviewer (Stage 4 = dogfood AC-20 reviewer pass)
**Verdict**: REQUEST CHANGES
- [MAJOR HIGH] `performance-analyst.md:25-27` — delegation pointer가 새 advisor 토폴로지와 모순 ("use `reviewer`" → 마땅히 "use `security-auditor`" 또는 "use `doc-writer`")
- [MAJOR HIGH] `doc-writer.md:231` — Final_Checklist 항목 scope 모호 (repo-wide 룰처럼 읽힘, 미래 author 오해 유발)
- [MINOR HIGH] `autopilot/SKILL.md` stratified verdict 블록이 한국어/영어 mixed

### Security-auditor (시뮬레이션, dogfood)
**Verdict**: zero_findings_note = "no concerns at this confidence"
- 7 카테고리 모두 N/A (markdown/JSON 변경)
- Positive: `disallowedTools: Write, Edit` frontmatter — defense-in-depth

### Doc-writer (시뮬레이션, advisor-mode read-only)
**Verdict**: 3 MINOR (none blocking)
- [MINOR conf=0.85 Inconsistent] reviewer.md:11에 "performance review" 책임 명시가 새 performance-analyst와 overlap
- [MINOR conf=0.75 Missing] doc-writer.md의 disallowedTools 부재가 명시되지 않음 (의도된 dual-mode이나 표현 부족)
- [MINOR conf=0.90 Unclear] autopilot SKILL.md frontmatter description이 새 doc-writer/performance-analyst 누락

### Critic (Stage 4 별도 dispatch)
**Verdict**: ACCEPT-WITH-RESERVATIONS
- 모든 23 AC mapping 통과
- 2 MAJOR (Reviewer와 동일) 확인 — pre-merge fix 필수
- 추가 gaps:
  - doc-writer dual-mode kernel-level enforcement 부재 (Risk Matrix에서 acknowledged)
  - Phase 5 stratified verdict가 MEDIUM-confidence 이견에 대해 정의 부재 (Plan AC-9 HIGH만 명시)
  - code-review SKILL.md description은 여전히 single-reviewer 언급 — 갱신 필요
  - 신규 agent 카피 시 doc-writer:231 misleading checklist 복제 위험

## Stage 5 — Fix Loop (Iteration 1/3)

### Fixes Dispatched (4 parallel executors)

| Fix | Target | Defect | Status |
|-----|--------|--------|--------|
| FIX-1 | performance-analyst.md (line 13, 25, 27) | 잘못된 delegation pointer 3곳 | GREEN — 3개 위치 모두 수정, stale grep = 0, new patterns 모두 통과 |
| FIX-2 | doc-writer.md (line 231) | Checklist 항목 scope 명확화 | GREEN — "dual-mode" 명시, scope를 self-referential로 한정 |
| FIX-3 | autopilot SKILL.md (line 57-61 부근) | 한국어/영어 mixed verdict 블록 | GREEN — 영어 통일, "re-entry to Phase 3" 명시, 3 토큰 모두 보존 |
| FIX-4 | code-review SKILL.md (line 3, 7, 24, 29, 68, 72, 77) | description / Purpose / Final_Checklist의 stale single-reviewer 언급 | GREEN — 7곳 모두 3-advisor 표현으로 갱신 |

### Re-verify (light pass)

```
validate.sh                                         → PASS
AC-9 stratified verdict tokens                      → 10 occurrences (Hard block / Soft block / Annotation only)
AC-10 doc-writer gating phrase                      → present in autopilot SKILL.md Task + Parallelism Note
AC-15 6 advisor names in Parallelism Note           → present
AC-13 ralplan performance-analyst occurrences       → 10
AC-16 plugin.json version                           → 2026.05.22.5
AC-17 marketplace.json hg-pyun-tools version        → 2026.05.22.5
AC-18 spec erratum 0-grep                           → 0 (PASS)
AC-19 git diff CLAUDE.md                            → 0 lines (unchanged)
FIX-1 stale 'use reviewer' in performance-analyst   → 0
FIX-2 'dual-mode' in doc-writer Final_Checklist     → 1 occurrence
AC-8  autopilot subagent_type count (expect 8)      → 8
AC-11 code-review subagent_type count (expect 4)    → 4
AC-13 ralplan subagent_type count (expect 3)        → 3
```

## Combined Verdict
**ACCEPT** — Iteration 1 fix가 reviewer/critic의 2 MAJOR + 2 MINOR를 모두 해소. critic의 "ACCEPT-WITH-RESERVATIONS" 조건 충족. 추가 fix iteration 불필요.

## Skip: Stage 4.5 (team-cleanup)
- `team` 스킬 Stage 4.5는 `code-review` skill을 호출하여 cleanup pass 수행.
- AC-20 dogfood가 이미 `code-review`의 새 명세(3 advisor)를 manual simulate하여 동일 advisor들이 전체 diff를 검토 완료.
- 따라서 Stage 4.5 cleanup은 redundant. 명시적으로 skip + 사유 기록.

## Open Questions (forwarded to Follow-ups)
- doc-writer mode-determination을 키워드 추론 대신 명시적 flag로 만들기?
- Phase 5 stratified verdict의 MEDIUM-confidence 이견 처리 규칙?
- 미래 agent .md 작성 시 stale delegation pointer 방지 CI lint?

## Outputs
- Fix 적용된 4 파일 (performance-analyst.md, doc-writer.md, autopilot SKILL.md, code-review SKILL.md)
- `.specs/skill-agent-expansion/team-verify.md` (this file)

## Iteration Count
- Stage 5 verify→fix iterations: 1/3 (cap 미달, 1회로 종결)
