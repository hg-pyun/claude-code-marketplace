---
name: ralph
description: PRD-driven persistence loop. Reads .dt-handoff/<slug>/prd.json, drives each story Red→Green→Refactor via test-engineer + executor, verifies acceptance criteria via the verifier agent on fresh evidence, runs reviewer approval, runs code-simplifier cleanup, re-verifies regression, and reports the stopping point. Auto commit/PR PROHIBITED. TRIGGER on "/ralph", "ralph", "끝까지 가줘", "keep going until done".
---

<Purpose>
Drive a PRD-defined task to completion through a story-by-story loop: TDD-first authoring, fresh-evidence verification via the `verifier` agent (never inline self-verification), reviewer approval, and `code-simplifier` cleanup. Output is changes-on-disk plus a status report — commit, push, and PR creation are the user's call. The loop continues across iterations until every `prd.json` story has `passes: true`, the chosen approver returns `verdict: APPROVE`, and post-cleanup regression re-verifies GREEN.
</Purpose>

<Use_When>
- A plan (`.dt-handoff/<slug>/plan.md`) is approved and execution must complete every story before stopping.
- User says "ralph", "/ralph", "keep going until done", "끝까지 가줘", "finish this".
- The task suits PRD-driven progress (multiple independently verifiable stories).
- `autopilot` Phase 3 (Execution) invokes this skill as a sub-step.
- A prior run left an incomplete `.dt-handoff/<slug>/prd.json` to resume.
</Use_When>

<Do_Not_Use_When>
- The user wants requirements capture → `deep-interview`.
- The user wants consensus planning → `ralplan`.
- The user wants parallel multi-agent decomposition → `team`.
- The user wants a one-shot / trivial change → delegate to `executor` directly, no PRD overhead.
- The user wants automatic commit/PR → refuse; ralph stops at "ready for commit".
- No spec / plan exists and the task is vague → route to `ralplan` first to scope the work.
</Do_Not_Use_When>

<Why_This_Exists>
Complex tasks fail silently when an agent declares "done" on a partial implementation, skips tests, or forgets an edge case. The PRD loop structures work into stories with testable acceptance criteria and refuses to mark a story complete without fresh per-criterion evidence from the `verifier` agent — not inline self-verification. The reviewer pass adds an independent second opinion before declaring the batch ready.

The TDD Iron Law (failing test before production code) is enforced inside every story so tests encode intent rather than mirror implementation. The `code-simplifier` cleanup (Step 7.5) removes slop introduced during the loop, scoped to changed files; the post-cleanup regression re-verify exists because even small cleanup edits can regress. The 3-failure escalation branches by failure type — root cause unclear → `debugger`, design fundamentally wrong → `architect` — to avoid grinding on the wrong specialist.

Auto commit/PR is prohibited because this marketplace's `git-commit` / `github-pr` skills are user-triggered by design; chaining them would skip review opportunities the user expects.

The loop stays thin: handoff mechanics (`@handoff-in`/`@handoff-out`, descriptors, `events.jsonl`) are defined once in the handoff protocol; this skill *references* them rather than re-spelling them per step.
</Why_This_Exists>

<Execution_Policy>
**Output language**: status reports, story descriptions, and `progress.txt` use `$LANGUAGE`. `prd.json` field VALUES (descriptions, AC text) use `$LANGUAGE`; field NAMES stay English.

**TDD Iron Law (non-negotiable)**: for each story, the `test-engineer` pass MUST produce a Red test that runs and fails for the expected reason BEFORE `executor` writes production code. Skipping Red is forbidden. Exception: pure-refactor stories tagged `refactor` may proceed without a new Red test if existing tests cover the behavior — note the exception in the story's progress entry.

**Verdict routing** (single source — steps reference this, never re-describe): `verifier` and the approver (`reviewer` or `critic`) return a machine-readable `@handoff-out` block with a `verdict` field. Route on the enum, NEVER on prose keyword matching:
- `APPROVE` / `ACCEPT_WITH_RESERVATIONS` → proceed (note reservations in the report).
- `REVISE` / `ITERATE` → mark affected stories `passes: false`, dispatch `executor` to fix, re-invoke the same agent; loop to Step 2. Do NOT self-verify.
- `REJECT` (3rd consecutive from the approver) → stop `REVIEW_BLOCKED`.

**Iteration caps**: soft cap 20 stories (warn + ask the user to split above it); hard cap 50 (refuse, route to `ralplan`). Per-story stuck cap = 3 consecutive verification failures (see `<Escalation_And_Stop_Conditions>` for the branching).

**Reviewer tier**: select STANDARD vs THOROUGH by changed-file count / risk; `--critic=critic|architect` swaps the Step 7 approver. The tier table is the single source in `<Advanced>`.

**Cleanup (Step 7.5)**: delegate to `code-simplifier` scoped strictly to the changed-file set. `--no-deslop` skips it entirely (use only when cleanup is intentionally out of scope).

**Story boundary**: a story is one Red→Green→Refactor cycle with testable AC (no "feels right"). ONE worker per role within a story — no fan-out.

**Parallel execution**: independent stories (no shared `dependsOn`, no overlapping file scope) MAY have Green/Refactor fired as parallel `executor` Tasks in one message; each still gets its own `verifier` pass. Within a story, work is sequential (Red → Green → Refactor → verifier). Reviewer / cleanup / regression are always globally sequential, after all stories pass.

**events.jsonl logging**: append one event per dispatch and per return for every agent handoff to `.dt-handoff/<slug>/events.jsonl` (per handoff-protocol §9; format mirrored in `scripts/validate.sh` header). Do NOT inline JSON literals in steps. `kind: trace`, `retention: session`, never committed.

**Stop conditions**: see `<Escalation_And_Stop_Conditions>` (single source).

**Auto commit/PR PROHIBITED**: never run `git commit`, `git push`, `gh pr create`, or invoke `git-commit` / `github-pr`. The report's "Next steps" line suggests them; the user triggers them.
</Execution_Policy>

<Settings_Reference>
| Flag | Default | Effect |
|------|---------|--------|
| `--lang=<value>` | `plugin.json` `settings.language` (`Korean`) | Output language for reports / progress.txt. |
| `--no-deslop` | off | Skip Step 7.5 (`code-simplifier` cleanup pass). |
| `--critic=critic\|architect` | `reviewer` | Swap the Step 7 approver to `critic` (adversarial) or `architect` (design-focused); default `reviewer`. |
| `--from-plan=<path>` | infer | Consume an existing `plan.md` as input; else infer slug from recent `.dt-handoff/` activity or ask. |
| `--max-stories=<n>` | 20 (max 50) | Override the soft story-count cap. |
</Settings_Reference>

<Arguments>
Task description plus any flags above. Examples:
- `/ralph "Linear webhook 처리 서비스 구현"`
- `/ralph --from-plan=.dt-handoff/linear-webhook/plan.md`
- `/ralph --no-deslop --critic=critic "auth middleware 리팩터"`
</Arguments>

<Steps>
Each step is declarative: **goal · delegate · input→output · success / fail**. Cross-cutting mechanics (handoff blocks, verdict routing, events logging) follow the single rules in `<Execution_Policy>` and `<Tool_Usage>` — not re-spelled per step.

### Step 1 — PRD Bootstrap
- Resolve `slug`: from `--from-plan` path, the most recently modified `.dt-handoff/<slug>/plan.md`, or ask.
- `prd.json` absent → scaffold from `plan.md` Acceptance Criteria, one story per AC with `passes: false`, including the top-level `_descriptor` key (`kind: prd`, `producer: ralph`, `retention: permanent`, `status: pending`; full schema in `scripts/validate.sh` header). Present → validate JSON, list incomplete stories.
- **Refine generic criteria** (CRITICAL): replace any scaffold AC like "Implementation is complete" with task-specific testable criteria (file:line / behavior / runtime check). Generic ACs cannot be verified.
- Init `.dt-handoff/<slug>/progress.txt` if absent; append a session header (date + plan link).
- Sanity-check counts: > 20 stories → warn; > 50 → refuse, route to `ralplan`.

### Step 2 — Pick Next Story
- Read `prd.json`; select the highest-priority story with `passes: false` and all `dependsOn` satisfied (tie-break: lower `priority`, then array order).
- Announce ID, description, AC list, layer (test / impl / refactor) to the user.

### Step 3 — Implement the Story (TDD cycle)
- **Red** — delegate `test-engineer`: author failing test(s) for the story, match existing patterns, confirm Red for the right reason. Input: `prd.json` (story). Output: failing test at `<file:line>`. If the test passes immediately, the test or behavior assumption is wrong — fix before continuing.
- **Green** — delegate `executor`: make the failing test pass with the smallest viable diff, match codebase patterns, touch no unrelated code. Input: `prd.json` + failing-test `<file:line>`. Output: green tests + fresh test/build/lint output.
- **Refactor** (if needed) — delegate `executor`: improve clarity with all tests green, no new behavior.

### Step 4 — Verify Acceptance Criteria (verifier — fresh evidence)
- **Goal**: confirm each AC met on fresh evidence; self-verification is PROHIBITED.
- **Delegate** `verifier`. Input: `prd.json` (story) + changed-file manifest. Output: findings file + `@handoff-out` verdict.
- **Route** on `verdict` per `<Execution_Policy>`: `APPROVE` → Step 5; `REVISE`/`ITERATE` → fix via `executor` then re-invoke `verifier`; `REJECT` → 3-fail escalation. Do NOT mark `passes: true` until `verifier` returns `APPROVE`.

### Step 5 — Mark Story Complete
- Update `prd.json`: `stories[i].passes = true`, add `completedAt`, attach evidence (verifier findings path + APPROVE summary).
- Append to `progress.txt`: story ID, behavior, files changed, learnings, anything unexpected.
- Update `.dt-handoff/<slug>/notepads/` cross-iteration memory (create lazily on first write; session/day retention, never committed): `learnings.md` (reusable facts/patterns), `decisions.md` (choices + rationale), `issues.md` (open questions), `problems.md` (verification failures / escalations). Section header form `## <ISO8601> — US-<id>` so later passes resume by story.

### Step 6 — PRD Completion Check
- Re-read `prd.json`. Not all `passes: true` → return to Step 2. All true → Step 7.

### Step 7 — Reviewer Approval
- **Goal**: independent sign-off on the complete batch.
- Select tier per `<Advanced>` table (`--critic=critic` swaps in `critic`).
- **Delegate** the approver. Input: `prd.json` + changed-file list. Prompt asks: (1) every AC met with fresh evidence; (2) logic/security/correctness issues; (3) a meaningfully better approach missed. Output: `@handoff-out` with `verdict`.
- **Route** on `verdict` per `<Execution_Policy>`: APPROVE → Step 7.5 (do NOT pause to report; reporting is Step 8); REVISE/ITERATE → mark related stories `passes: false`, return to Step 2; 3rd consecutive REJECT → `REVIEW_BLOCKED`.

### Step 7.5 — Cleanup Pass (skip if `--no-deslop`)
- **Delegate** `code-simplifier` scoped strictly to the changed-file set. Input: changed-files manifest. Output: simplified files, no behavior change. Apply ONLY findings inside the changed-file set; do not expand scope.
- `code-simplifier` edits join the same ralph batch (no separate commit).

### Step 7.6 — Post-Cleanup Regression (verifier)
- **Delegate** `verifier` to re-verify the full changed-file set: confirm tests, build, lint still pass. Input: `prd.json` + changed files. Output: `@handoff-out` verdict.
- **Route**: APPROVE → Step 8. REVISE → roll back the offending cleanup edit OR fix via `executor`, then re-run; loop to GREEN or 2 attempts. After 2 failed attempts → roll back to pre-cleanup state, apply `--no-deslop` semantics for this batch, report the issue.
- Proceed only once this returns APPROVE (or Step 7.5 was skipped).

### Step 8 — Report and Stop
- Compose the final report in `$LANGUAGE`: stories completed (count); files changed with line deltas; approver verdict (with non-blocking comment count); cleanup completed/skipped; final regression PASS (verifier APPROVE).
- **Next steps**: suggest `/git-commit` then `/github-pr` — do NOT invoke them.
- Append a session-close entry to `progress.txt`. STOP. No git mutations.

### Step 9 — On Rejection (any verification failure)
- Fix the issues raised by reviewer / critic / verifier / cleanup / regression. Re-mark affected stories `passes: false` with a note. Return to Step 2. Respect the per-story 3-fail rule — escalate to `debugger` (root unclear) or `architect` (design wrong) after 3 consecutive failed attempts on the same story.

### `prd.json` Schema
```json
{
  "slug": "linear-webhook",
  "plan": ".dt-handoff/linear-webhook/plan.md",
  "created": "2026-05-22T10:00:00Z",
  "_descriptor": {
    "kind": "prd",
    "path": ".dt-handoff/linear-webhook/prd.json",
    "contentHash": "sha256:<hash>",
    "createdAt": "2026-05-22T10:00:00Z",
    "producer": "ralph",
    "sizeBytes": 1024,
    "retention": "permanent",
    "expiresAt": null,
    "status": "pending"
  },
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
- **Read**: load `prd.json`, `plan.md`, source files for AC checks; read `@handoff-in` paths and verify `contentHash`.
- **Write/Edit**: update `prd.json` (story completion), append `progress.txt`, scaffold the initial PRD, write `events.jsonl` lines, write changed-file manifests for dispatch.
- **Bash**: run tests / build / lint / typecheck only for triage before dispatching `verifier`. NO `git commit` / `git push` / `gh pr`. Do NOT self-verify — that is `verifier`'s job.
- **Task**: bare agent names (no plugin prefix) — `test-engineer` (Red), `executor` (Green/Refactor), `verifier` (AC + regression), `reviewer` or `critic` (approval), `code-simplifier` (Step 7.5), `debugger` / `architect` (3-fail escalation).
- **TodoWrite**: track story progress in-session (alongside `prd.json` for persistence).
- **Handoff contract** (single rule — do not re-spell per step): when dispatching an agent that consumes a persisted artifact, include a `@handoff-in` reference (`kind`, `path`, `contentHash`, `sizeBytes`; inline the body only when `sizeBytes ≤ INLINE_MAX_BYTES`). List multiple `@handoff-in` blocks for multiple inputs (e.g. verifier = prd.json story + changed-file manifest). Consume the returning `@handoff-out` block and route on its `verdict`. The block shapes, descriptor schema, `verdict` enum, and `INLINE_MAX_BYTES` are defined in the handoff protocol — mirrored in the `scripts/validate.sh` header.
- Do NOT invoke `git-commit`, `github-pr`, `team`, `autopilot`, or any other mutation-oriented skill from inside ralph.
</Tool_Usage>

<Examples>
**Example 1 — fresh execution from approved plan**:
`/ralph --from-plan=.dt-handoff/linear-webhook/plan.md` → Step 1 scaffolds prd.json (4 stories, `_descriptor`), refines generic AC to file-anchored. Step 2 picks US-001 (no deps). Step 3: test-engineer authors webhook-handler.test.ts:42 (Red) → executor implements (Green). Step 4: verifier `APPROVE`. Step 5: US-001 `passes: true`. Loop US-002/003/004. Step 7: reviewer `APPROVE`. Step 7.5: code-simplifier removes 1 unused import. Step 7.6: verifier `APPROVE`. Step 8: "Ready for commit — suggest `/git-commit`." STOP.

**Example 2 — `--no-deslop` hotfix**:
`/ralph --no-deslop "fix login timeout bug"` → single-story prd.json → Red → Green → verifier `APPROVE` → reviewer `APPROVE` → SKIP Step 7.5 → report.

**Example 3 — story fails 3 times, escalation**:
US-002 fails verifier 3 consecutive times with the same TypeError → root cause unclear → delegate `debugger` (story + error evidence). Stop `BLOCKED — debugger escalated`; do not advance to US-003. If the post-debugger fix still fails 3 more times → escalate `architect`.

**Example 4 — reviewer returns REVISE**:
reviewer `@handoff-out` `verdict: REVISE` ("'validates signature' not covered by tests") → route on the field (not prose). Mark US-001 `passes: false`, return to Step 2: test-engineer adds coverage → executor implements → verifier `APPROVE` → loop back to Step 7.

**Example 5 — user halts mid-loop**:
"충분해, 그만" → stop immediately. progress.txt: `Status: USER_HALTED at story <id>, <n>/<total> complete`. Report incomplete stories. No commit.
</Examples>

<Final_Checklist>
- Did I bootstrap/load `prd.json` with task-specific acceptance criteria (no generic boilerplate)?
- Did each story go through the FULL TDD cycle (test-engineer Red → executor Green → executor Refactor)?
- Did I invoke `verifier` for every story's AC check and gate on `verdict: APPROVE` before marking `passes: true`?
- Did I route on the `@handoff-out` `verdict` field — NEVER prose keyword matching?
- Did the reviewer / critic pass run AFTER all stories completed, consuming the `verdict`?
- Did the cleanup pass (`code-simplifier`) run on changed files only (or was `--no-deslop` set)?
- Did post-cleanup regression (`verifier`) return `verdict: APPROVE`?
- Did I append one `events.jsonl` event per dispatch and per return, and include `@handoff-in` blocks when dispatching?
- Did I refrain from `git commit` / `git push` / `gh pr` and from invoking `git-commit` / `github-pr`?
- Did the final report include a "Next steps" line suggesting (not invoking) `/git-commit` + `/github-pr`?
- Did `progress.txt` get appended after each story and at session close?
- For 3-fail stuck stories, did I escalate to `debugger` (root unclear) or `architect` (design wrong) instead of trying variation #4?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
Single source for terminal statuses.
- All stories `passes: true` + approver `verdict: APPROVE` + cleanup done + post-cleanup verifier `verdict: APPROVE` → report and stop (success).
- User says "stop" / "cancel" / "abort" / "충분해" → stop immediately; progress.txt `USER_HALTED`.
- Same story fails verifier 3 consecutive times, root cause unclear → escalate `debugger`; stop `BLOCKED`.
- Same story fails 3 consecutive times, design fundamentally wrong → escalate `architect`; stop `BLOCKED`.
- Over hard cap (50 stories) → refuse; route to `ralplan` for re-decomposition; stop `OVER_BUDGET`.
- Approver returns `verdict: REJECT` three iterations in a row → stop `REVIEW_BLOCKED`; do not keep grinding.
- `code-simplifier` cleanup breaks regression and `verifier` returns `REVISE` for 2 attempts → roll back to pre-cleanup state, apply `--no-deslop` semantics for this batch, report the issue.
- A success `verdict: APPROVE` flows into deslop → regression verifier → Step 8 IN THE SAME TURN. Do NOT treat APPROVE as a reporting checkpoint; reporting happens only at Step 8.
</Escalation_And_Stop_Conditions>

<Advanced>
## Story Tags Convention
- `test` — primary deliverable is test coverage (test-engineer leads).
- `impl` — production-code story (executor leads after Red).
- `refactor` — pure refactor (TDD exception applies; cite existing coverage in evidence).
- `infra` — config / build / CI (executor + reviewer focus on safety, not behavior).
- `docs` — README/CLAUDE.md updates (skip test-engineer; reviewer focuses on accuracy).

## Reviewer Tier Mapping (single source)
| Surface | Tier | Approver |
|---------|------|----------|
| < 5 files, < 100 lines, tests present | STANDARD | `reviewer` (sonnet) |
| 5–20 files | STANDARD | `reviewer` (sonnet) |
| ≥ 20 files OR security/auth/migration OR architectural | THOROUGH | `architect` (opus) acting as approver |
| `--critic=critic` flag | adversarial | `critic` (opus) |
Floor: always at least STANDARD, even for tiny changes.

## Parallel Execution Within ralph
Independent stories (no shared `dependsOn`, no overlapping file scope) MAY have Green/Refactor fired in parallel, e.g. `[Task(executor, US-002 Green), Task(executor, US-005 Green)]`. Each story still requires its own `verifier` pass. Reviewer / cleanup / post-cleanup regression are always globally sequential.

## Resumption Semantics
Re-invoking `/ralph` on an existing `prd.json` resumes from the first `passes: false` story. Completed stories are not retouched unless the reviewer pass flags a regression in them.
</Advanced>
</content>
</invoke>
