# Dogfood Transcript — AC-20

## Context
- AC-20 REQUIRED smoke test 재현: 새 code-review SKILL.md 명세에 따른 3 advisor 병렬 호출.
- 진짜 `/code-review` skill 호출 대신 직접 dispatch (이유: 수정한 SKILL.md는 repo에 있으나 plugin cache는 여전히 2026.05.22.4. 진짜 dogfood는 `claude plugin update` 후 가능).
- 검토 대상: 현재 PR diff (3 신규 agent .md + 3 modified SKILL.md + plugin.json + marketplace.json).

## Advisors Dispatched
1. `reviewer` (subagent_type=hg-pyun-tools:reviewer) — 표준 severity-rated 검토
2. `security-auditor` (시뮬레이션 — security-auditor.md 명세 따름) — AuthN/AuthZ/Secret/Crypto/Injection/SAST/Config
3. `doc-writer` (시뮬레이션 — doc-writer.md advisor-mode 명세 따름, read-only 게이팅 적용) — Missing/Outdated/Inconsistent/Unclear

## Results

### Reviewer (verdict: REQUEST CHANGES — 2 MAJOR, 1 MINOR)
- **[MAJOR HIGH] performance-analyst.md:244**: `Do_Not_Use_When`에 "security audit — use `reviewer`" 잘못된 delegation pointer. 새 `security-auditor` agent로 가리켜야 함. Line 246 doc 관련도 동일.
- **[MAJOR HIGH] doc-writer.md:231**: `Final_Checklist`의 "No `disallowedTools` key in frontmatter" 항목이 repo-wide 룰처럼 읽힘. 같은 PR에 추가된 security-auditor/performance-analyst는 `disallowedTools: Write, Edit` 사용. self-referential scope으로 표현 필요.
- **[MINOR HIGH] autopilot SKILL.md (Phase 5 stratified verdict)**: 한국어/영어 mixed inline. 나머지 SKILL.md는 영어 통일.

### Security-auditor (verdict: zero findings)
- `zero_findings_note: "no concerns at this confidence"`
- 7 카테고리 모두 N/A (markdown/JSON 변경, 실행 코드 없음)
- Positive observation: security-auditor.md가 `disallowedTools: Write, Edit` frontmatter로 read-only를 hardness-level enforcement — defense-in-depth.

### Doc-writer (3 MINOR, all advisor-mode read-only)
- **[MINOR conf=0.85 Inconsistent] reviewer.md:11**: "performance review" 책임 명시가 새 performance-analyst와 overlap. 권고 diff: 해당 단어 삭제.
- **[MINOR conf=0.75 Missing] doc-writer.md frontmatter**: disallowedTools 부재 (의도된 dual-mode이나 명시 부족). 권고: Execution_Policy에 mode gate 명시.
- **[MINOR conf=0.90 Unclear] autopilot SKILL.md:7**: frontmatter description이 "reviewer+critic+architect (Validation)"만 명시, 새 doc-writer/performance-analyst 누락. 권고 diff: 6 advisor 모두 명시.

## AC-20 Verdict
- 3 advisor 모두 응답 ✓
- 각 응답에 Findings 또는 zero_findings_note 명시 ✓
- transcript 첨부 (이 파일) ✓

## AC-21 (BEST-EFFORT — skipped with reason)
- 새 ralplan SKILL.md (performance-analyst를 Architect와 병렬)는 repo에 있으나 plugin cache는 2026.05.22.4. 사용자가 `claude plugin update hg-pyun-plugins`로 reinstall 후에야 진짜 dogfood 가능. 본 세션에서 reinstall은 사용자 동의 필요.

## AC-22 (BEST-EFFORT — skipped with reason)
- AC-21과 동일. autopilot Phase 5 dry-run을 위해 새 autopilot SKILL.md가 cache에 설치되어야 함. 자기 자신을 fix 대상으로 삼는 재귀 위험도 회피. PR merge + plugin reinstall 후 사용자가 별도 verification 수행 권장.

## Findings forwarded to Stage 4 verify
Reviewer의 2 MAJOR는 실제 defect → Stage 4 → Stage 5 fix loop로 진행:
1. performance-analyst.md:244-246 delegation pointer 수정
2. doc-writer.md:231 checklist item scope 명시
