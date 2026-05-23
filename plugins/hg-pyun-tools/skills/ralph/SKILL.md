---
name: ralph
description: PRD-driven persistence loop. Reads .specs/<slug>/prd.json, picks the highest-priority story with passes:false, drives Red→Green→Refactor via test-engineer + executor, verifies acceptance criteria with fresh evidence, runs reviewer approval, runs code-review skill as cleanup, re-verifies regression, and reports stopping point. Auto commit/PR is PROHIBITED — those steps are the user's call. TRIGGER on "/ralph", "ralph", "끝까지 가줘", "keep going until done".
---

<Purpose>
Drive a PRD-defined task to completion through a story-by-story execution loop with TDD-first authoring, fresh-evidence verification, reviewer approval, and code-review cleanup. Output is changes-on-disk plus a status report — commit, push, and PR creation are explicitly left to the user. The loop continues across multiple iterations until every `prd.json` story has `passes: true` and the chosen reviewer approves the final state, then re-verifies regression after the cleanup pass.
</Purpose>

<Use_When>
- A plan (`.specs/<slug>/plan.md`) has been approved and execution must complete every story before stopping.
- User says "ralph", "/ralph", "keep going until done", "끝까지 가줘", "finish this".
- The task benefits from structured PRD-driven progress (multiple stories, each independently verifiable).
- `autopilot` Phase 3 (Execution) invokes this skill as a sub-step.
- A prior `ralph` run left an incomplete `prd.json` and needs resumption.
</Use_When>

<Do_Not_Use_When>
- The user wants requirements capture — use `deep-interview`.
- The user wants consensus planning — use `ralplan`.
- The user wants parallel multi-agent decomposition — use `team`.
- The user wants a one-shot fix or trivial change — delegate to `executor` directly without the PRD overhead.
- The user wants automatic commit/PR after execution — refuse; this skill stops at "ready for commit" and never invokes git mutations.
- No spec / plan exists and the task is vague — route to `ralplan` first to scope the work.
</Do_Not_Use_When>

<Why_This_Exists>
Complex tasks fail silently when an agent declares "done" on a partial implementation, skips tests, or forgets an edge case. The PRD loop prevents this by structuring work into stories with explicit acceptance criteria and refusing to mark a story complete without fresh evidence per criterion. The reviewer pass adds an independent second opinion before declaring the whole batch ready.

The TDD Iron Law (failing test before production code) is enforced inside every story to ensure tests encode intent rather than mirror implementation.

The `code-review` cleanup step (Step 7.5) replaces the upstream "ai-slop-cleaner" pass — it removes dead code, unused imports, and other slop introduced during the loop while keeping the scope bounded to changed files. The post-cleanup regression re-verify exists because cleanup edits can introduce regressions even when individually small.

Auto commit/PR is prohibited because this marketplace's commit and PR skills (`git-commit`, `github-pr`) are designed to be user-triggered. Chaining them after ralph would skip review opportunities the user expects to have.
</Why_This_Exists>

<Execution_Policy>
**Output language**: status reports, story descriptions, and `progress.txt` entries use `$LANGUAGE`. `prd.json` field VALUES (descriptions, AC text) use `$LANGUAGE`; field NAMES stay English.

**TDD Iron Law (non-negotiable)**:
- For each story, the test-engineer pass MUST produce a Red test BEFORE executor writes production code. Skipping the Red step is forbidden.
- The Red test must run and fail for the expected reason before executor is invoked.
- Exception: pure-refactor stories tagged `refactor` may proceed without a new Red test if all existing tests cover the behavior; this exception MUST be noted in the story's progress entry.

**Auto commit/PR PROHIBITED**:
- Never run `git commit`, `git push`, `gh pr create`, or invoke `git-commit` / `github-pr` skills automatically.
- After ralph completes, the report includes a "Next steps" line suggesting `git-commit` / `github-pr` — but the user must trigger them.

**Reviewer tier selection**:
- < 5 files OR < 100 lines changed with tests present → STANDARD tier (sonnet `reviewer`).
- ≥ 20 files OR security-sensitive OR architectural changes → THOROUGH tier (opus `architect` reviewing as approver).
- Default: STANDARD. Floor: always at least STANDARD even for tiny changes.
- `--critic=critic`: use the `critic` agent for the approval pass instead of `reviewer`.

**Cleanup step (7.5)**:
- Default: invoke `Skill("hg-pyun-tools:code-review")` on changed files only.
- `--no-deslop`: skip the cleanup pass entirely. Use only when cleanup is intentionally out of scope.

**Iteration cap**:
- Soft cap: 20 stories in `prd.json`. Above 20, ralph emits a warning and asks the user to split.
- Hard cap: 50 stories. Above 50, ralph refuses and routes to `ralplan` for re-decomposition.
- Stuck story cap: if the same story fails verification 3 consecutive times with the same error, escalate to `architect` via the executor's standard 3-fail rule.

**Story boundary**:
- A "story" is a unit of work completable in one Red-Green-Refactor cycle.
- Acceptance criteria MUST be testable (no "feels right", no "looks correct").
- Each story gets ONE worker per role: test-engineer authors Red, executor makes Green, executor refactors. No fan-out within a story.

**Parallel execution**:
- Across independent stories with no `dependsOn`, ralph MAY fire multiple `executor` Task calls in a single message for Green/Refactor work.
- Within a single story, work is sequential (Red → Green → Refactor).
- Reviewer / cleanup / regression passes are always sequential (one at a time, after all stories pass).

**Stop conditions**:
- All `prd.json` stories have `passes: true` AND reviewer APPROVE AND cleanup pass complete AND post-cleanup regression passes → report and stop.
- Hard cap reached → stop with status `OVER_BUDGET`.
- Same story fails 3 times consecutively → escalate to `architect` and stop with status `BLOCKED`.
- User says "stop" / "cancel" / "충분해" → stop with status `USER_HALTED`.
- Any reviewer rejection at HIGH confidence → fix, re-verify, do NOT skip.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`.
- `--no-deslop`: skip Step 7.5 (`code-review` cleanup pass).
- `--critic=critic`: use `critic` agent for Step 7 approval pass instead of default `reviewer`.
- `--from-plan=<path>`: consume an existing `.specs/<slug>/plan.md` as input (default: infer slug from current directory's recent `.specs/` activity or ask).
- `--max-stories=<n>`: override the 20-story soft cap (max 50).
</Settings_Reference>

<Arguments>
Task description plus flags:
- `--no-deslop` — skip cleanup pass
- `--critic=architect|critic` — choose approver (default: `reviewer`)
- `--from-plan=<path>` — explicit plan input
- `--lang=<value>` — output language override
- `--max-stories=<n>` — story-count cap override
Examples:
- `/ralph "Linear webhook 처리 서비스 구현"`
- `/ralph --from-plan=.specs/linear-webhook/plan.md`
- `/ralph --no-deslop --critic=critic "auth middleware 리팩터"`
</Arguments>

<Steps>

### Step 1: PRD Bootstrap
1. **Resolve slug**: from `--from-plan` path, or from the most recently modified `.specs/<slug>/plan.md`, or ask the user.
2. **Check `.specs/<slug>/prd.json`**:
   - If absent: scaffold it from `plan.md` Acceptance Criteria. Each AC becomes a story with `passes: false`. Use `Read` on `plan.md`, then `Write` the new `prd.json`. The scaffolded JSON MUST include a top-level `_descriptor` key with the OMC hand-off descriptor (kind=prd, producer=ralph, retention=permanent, status=pending). See `plugins/hg-pyun-tools/SPEC.md` for the full schema.
   - If present: validate JSON, list incomplete stories.
3. **Refine generic criteria**: replace any scaffold AC like "Implementation is complete" with task-specific testable criteria (file:line, behavior, or runtime check). This is CRITICAL — generic ACs cannot be verified.
4. **Initialize `.specs/<slug>/progress.txt`** if absent. Append session header with date + plan link.
5. **Sanity check counts**: if stories > 20, warn the user. If > 50, refuse and route to `ralplan`.

### Step 2: Pick Next Story
6. **Read `prd.json`** and select the highest-priority story with `passes: false` and all `dependsOn` satisfied. Tie-break by lower `priority` integer, then by array order.
7. Announce the story to the user: ID, description, AC list, layer (test / build / impl / refactor).

### Step 3: Implement the Story (TDD cycle)
8. **Red step** (test-engineer):
   ```
   Task(
     subagent_type="test-engineer",
     prompt="Author failing test(s) for story <story.id>. Behavior: <story.description>.
     Acceptance criteria: <story.acceptanceCriteria>.
     Match existing test patterns. Confirm the test fails for the right reason; paste output."
   )
   ```
9. **Verify the Red test fails as expected**. If it passes immediately, the test or the behavior assumption is wrong — fix before continuing.
10. **Green step** (executor):
    ```
    Task(
      subagent_type="executor",
      prompt="Make the failing test at <test file:line> pass with the smallest viable diff.
      Match existing codebase patterns. Do not touch unrelated code.
      Paste fresh test/build/lint output."
    )
    ```
11. **Refactor step** (executor, if needed):
    ```
    Task(
      subagent_type="executor",
      prompt="Refactor the implementation at <files> for clarity while keeping all tests green.
      No new behavior. Paste fresh test/build output."
    )
    ```

### Step 4: Verify Story Acceptance Criteria
12. **For each acceptance criterion**:
    - Run the relevant check (test command, build, lint, typecheck, or a direct Read for "exists at path" criteria).
    - Read the output. Confirm the criterion is met with the evidence in hand.
    - If unmet → loop back to Step 3 with the gap noted.
13. **Do NOT mark passes:true until every criterion is verified with fresh output**.

### Step 5: Mark Story Complete
14. **Update `prd.json`**: set `stories[i].passes = true`, add `completedAt` timestamp, attach evidence references (test file path + last passing run summary).
15. **Append to `progress.txt`**: story ID, behavior implemented, files changed, learnings or patterns discovered, anything unexpected.
15a. **Update `.specs/<slug>/notepads/` (cross-iteration memory)**: append ISO8601-timestamped sections to the appropriate file:
   - `notepads/learnings.md` — patterns or facts discovered that future stories can rely on
   - `notepads/decisions.md` — choices made between options + their rationale
   - `notepads/issues.md` — open questions surfaced but not resolved in this story
   - `notepads/problems.md` — verification failures or escalations
   Create the `notepads/` directory and the 4 files lazily (only on first write). Each section header uses the form `## <ISO8601> — US-<id>` so later passes can resume by story. These files are session/day retention; do not commit them.

### Step 6: PRD Completion Check
16. **Read `prd.json` again**. Are ALL stories `passes: true`?
    - No → return to Step 2.
    - Yes → proceed to Step 7.

### Step 7: Reviewer Verification
17. **Select tier** by changed-file count and risk (per Execution_Policy).
18. **Delegate to approver** (default `reviewer`, or `critic` if `--critic=critic`):
    ```
    Task(
      subagent_type="reviewer",   // or "critic"
      prompt="Verify implementation against acceptance criteria from .specs/<slug>/prd.json.
      Changed files: <list>.
      Evaluate: (1) every AC met with fresh evidence; (2) any logic / security / correctness issues;
      (3) is there a meaningfully better approach we missed?
      Return verdict + findings."
    )
    ```
19. **On REQUEST CHANGES / ITERATE / REJECT**: address the findings, mark related stories `passes: false`, return to Step 2.
20. **On APPROVE**: proceed to Step 7.5 immediately in the same turn. Do NOT pause to report — reporting happens at Step 8.

### Step 7.5: Cleanup Pass (skip if `--no-deslop`)
21. **Invoke `Skill("hg-pyun-tools:code-review")`** scoped to changed files:
    ```
    Skill("hg-pyun-tools:code-review", args="--scope=<changed file list>")
    ```
22. **Apply ONLY the findings inside the changed-file set**. Do not expand the cleanup scope to unrelated files.
23. **If cleanup introduces additional edits**, those edits become part of the same ralph batch (no separate commit).

### Step 7.6: Post-Cleanup Regression
24. **Re-run tests, build, lint** on the full changed-file set. Read the output.
25. **If regression fails**: roll back the offending cleanup edit OR fix it, then re-run. Loop until regression passes.
26. Only proceed once post-cleanup regression is GREEN (or Step 7.5 was skipped via `--no-deslop`).

### Step 8: Report and Stop
27. **Compose the final report** in `$LANGUAGE`:
    - Stories completed: count
    - Files changed: list with line deltas
    - Approver verdict: APPROVE (with findings count if any non-blocking COMMENTs)
    - Cleanup pass: completed / skipped
    - Final regression: PASS
    - **Next steps**: "Run `/git-commit` to commit these changes" and "Run `/github-pr` to open a PR" — do NOT invoke them.
28. **Append final entry to `progress.txt`** with session close timestamp + summary.
29. **STOP**. Do not invoke git mutations.

### Step 9: On Rejection (any verification failure)
30. **Fix the issues** raised by reviewer / critic / cleanup pass / regression check.
31. **Re-mark affected stories** `passes: false` with a note explaining why.
32. **Return to Step 2** (pick next story to address the regression).
33. **Do NOT loop forever**: respect the 3-fail rule per story — escalate to `architect` after 3 consecutive failed attempts on the same story.

### `prd.json` Schema

```json
{
  "slug": "linear-webhook",
  "plan": ".specs/linear-webhook/plan.md",
  "created": "2026-05-22T10:00:00Z",
  "stories": [
    {
      "id": "US-001",
      "priority": 1,
      "description": "Webhook 수신 endpoint 구현",
      "layer": "impl",
      "tags": ["http", "ingestion"],
      "dependsOn": [],
      "acceptanceCriteria": [
        "POST /webhooks/linear returns 200 within 50ms",
        "Request signature is validated against LINEAR_WEBHOOK_SECRET",
        "Unit test webhook-handler.test.ts:42 passes"
      ],
      "passes": false,
      "completedAt": null,
      "evidence": null
    }
  ]
}
```

</Steps>

<Tool_Usage>
- **Read**: load `prd.json`, `plan.md`, source files for AC verification.
- **Write/Edit**: update `prd.json` (story completion), append `progress.txt`, scaffold initial PRD from plan.
- **Bash**: run tests / build / lint / typecheck for AC verification and regression. NO `git commit`, `git push`, `gh pr` — those are forbidden.
- **Task**: delegate to `test-engineer` (Red), `executor` (Green / Refactor), `reviewer` or `critic` (approval), `architect` (3-fail escalation).
- **Skill**: invoke `hg-pyun-tools:code-review` for Step 7.5 cleanup.
- **TodoWrite**: track story-by-story progress in-session (in addition to `prd.json` for persistence).
- Do NOT invoke `git-commit`, `github-pr`, `team`, `autopilot`, or any other mutation-oriented skill from inside ralph.
</Tool_Usage>

<Examples>
**Example 1 — fresh execution from approved plan**:
User: "/ralph --from-plan=.specs/linear-webhook/plan.md"
Flow:
- Step 1: scaffold prd.json from plan's AC (4 stories) → refine generic AC to file-anchored ones.
- Step 2: pick US-001 (no deps).
- Step 3: test-engineer authors webhook-handler.test.ts:42 (Red) → executor implements handler (Green) → tests pass.
- Step 4: verify all 3 AC → all green.
- Step 5: prd.json US-001 passes:true.
- Loop Step 2-6 for US-002 / US-003 / US-004.
- Step 7: reviewer APPROVE.
- Step 7.5: code-review skill → 1 minor cleanup (unused import) → applied.
- Step 7.6: regression PASS.
- Step 8: report "Ready for commit. Suggest `/git-commit`." STOP.

**Example 2 — `--no-deslop` for hotfix**:
User: "/ralph --no-deslop 'fix login timeout bug'"
Flow: scaffold single-story prd.json → test-engineer Red → executor Green → reviewer APPROVE → SKIP Step 7.5 → regression check → report.

**Example 3 — story fails 3 times, escalation**:
Story US-002 fails verification 3 consecutive times with the same TypeError.
Action: ralph stops the loop on US-002. Delegate to architect with: 3 attempts, what was tried, where it failed. Report status `BLOCKED — architect escalated`. Do NOT continue to US-003 until US-002 unblocks.

**Example 4 — user halts mid-loop**:
User: "충분해, 그만"
Flow: stop immediately. Update progress.txt with `Status: USER_HALTED at story <id>, <n>/<total> stories complete`. Report incomplete stories. Do NOT commit anything.
</Examples>

<Final_Checklist>
- Did I bootstrap or load `.specs/<slug>/prd.json` with task-specific acceptance criteria (no generic boilerplate)?
- Did each story go through the FULL TDD cycle (test-engineer Red → executor Green → executor Refactor)?
- Did I verify every AC with fresh output before marking `passes: true`?
- Did the reviewer / critic pass run AFTER all stories were complete?
- Did the cleanup pass (`code-review` skill) run on changed files only? (Or was `--no-deslop` set?)
- Did the post-cleanup regression run GREEN?
- Did I refrain from running `git commit`, `git push`, `gh pr`, or invoking `git-commit`/`github-pr` skills?
- Did the final report include a "Next steps" line suggesting (not invoking) `/git-commit` and `/github-pr`?
- Did `progress.txt` get appended after each story and at session close?
- For 3-fail stuck stories, did I escalate to `architect` instead of trying variation #4?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
- All stories `passes: true` + reviewer APPROVE + cleanup done + regression GREEN → report and stop.
- User says "stop", "cancel", "abort", "충분해" → stop immediately; update progress.txt with `USER_HALTED`.
- Same story fails 3 consecutive times with the same root error → escalate to `architect`; stop with status `BLOCKED`.
- Over hard cap (50 stories) → refuse; route to `ralplan` for decomposition.
- Reviewer / critic returns REJECT three iterations in a row → stop with status `REVIEW_BLOCKED`; do not continue grinding.
- `code-review` skill (Step 7.5) introduces edits that break regression and cannot be auto-fixed within 2 attempts → roll back to pre-cleanup state, run with `--no-deslop` semantics for this batch, report the issue.
- Approve verdict is followed by deslop → regression → Step 8 IN THE SAME TURN. Do NOT treat APPROVE as a reporting checkpoint; reporting happens only at Step 8.
</Escalation_And_Stop_Conditions>

<Advanced>
## Story Tags Convention
- `test` — story whose primary deliverable is test coverage (test-engineer leads).
- `impl` — production-code story (executor leads after Red).
- `refactor` — pure refactor (TDD exception applies; cite existing coverage in evidence).
- `infra` — config, build, CI changes (executor + reviewer focus on safety not behavior).
- `docs` — README/SPEC.md updates (skip test-engineer; reviewer focuses on accuracy).

## Tier Mapping for Reviewer Step
| Surface | Tier | Approver |
|---------|------|----------|
| < 5 files, < 100 lines, tests present | STANDARD | `reviewer` (sonnet) |
| 5-20 files | STANDARD | `reviewer` (sonnet) |
| ≥ 20 files OR security/auth/migration | THOROUGH | `architect` (opus) acting as approver |
| `--critic=critic` flag | adversarial | `critic` (opus) |

## Parallel Execution Within ralph
Independent stories (no shared `dependsOn`, no overlapping file scope) MAY have their Green/Refactor steps fired in parallel:
```
[Task(executor, story US-002 Green), Task(executor, story US-005 Green)]
```
The TDD Red step is always sequential per story. Reviewer / cleanup / regression are always sequential globally.

## Resumption Semantics
Re-invoking `/ralph` on an existing `.specs/<slug>/prd.json` resumes from the first `passes: false` story. Completed stories are not retouched unless the reviewer pass flags a regression in them.
</Advanced>
