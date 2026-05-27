---
name: autopilot
description: End-to-end 5-phase pipeline from idea to code-ready state. Sequences deep-interview (Expansion) → ralplan (Planning) → ralph or team (Execution) → test-engineer + executor + verifier (QA, max 5 iter) → reviewer+critic+architect+security-auditor+performance-analyst+doc-writer (Validation). All artifacts land in .dt-handoff/<slug>/. Appends control-plane events to events.jsonl at every phase boundary and agent dispatch/return. Auto commit/PR PROHIBITED. TRIGGER on "/autopilot", "autopilot", "build me", "create me", "make me", "I want a/an". DO NOT TRIGGER for brainstorming, single bug fixes, or quick changes.
---

<Purpose>
Take a product idea from one-sentence intent through a vetted spec, an approved plan, an implemented change set, a hardened test suite, and a multi-perspective validation pass — all in a single skill invocation. The autopilot does NOT do the work itself; it sequences sibling skills (`deep-interview`, `ralplan`, `ralph` or `team`) and agent passes (`test-engineer`, `executor`, `verifier`, `architect`, `critic`, `reviewer`, `security-auditor`, `performance-analyst`, `doc-writer`) and stops at "ready for commit". Commit and PR creation remain the user's call.

Smart shortcuts: if `.dt-handoff/<slug>/spec.md` already exists from a prior `deep-interview`, Phase 1 is skipped. If `.dt-handoff/<slug>/plan.md` already exists from a prior `ralplan`, Phases 1-2 are both skipped.
</Purpose>

<Use_When>
- User invokes "/autopilot", says "autopilot", "build me X", "create me X", "make me X", "I want a/an X".
- The task is large enough to need full lifecycle management (spec + plan + impl + test + validate).
- The user wants hands-off execution: describe WHAT, not HOW.
- An existing `.dt-handoff/<slug>/spec.md` or `plan.md` is present and the user wants to resume.
</Use_When>

<Do_Not_Use_When>
- The user wants to brainstorm only — answer directly without invoking the pipeline.
- The user wants a single bug fix — delegate to `executor` directly.
- The user wants a quick edit — work directly.
- The user wants only requirements capture (no execution) — use `deep-interview` directly.
- The user wants planning without execution — use `ralplan` directly.
- The user wants automatic commit/PR after execution — refuse; autopilot stops at "ready for commit".
- The user has not specified scope at all ("just improve everything") — refuse and route to `deep-interview` first to establish a target.
</Do_Not_Use_When>

<Why_This_Exists>
Most "build me X" tasks fail not because any single phase was hard, but because phase boundaries leak. Requirements drift during planning, plans drift during execution, tests get skipped when execution gets noisy, and validation gets reduced to "looks fine to me." A skill that owns the phase boundaries — reading the previous phase's artifact, calling the next phase's skill with explicit inputs, and refusing to advance until each phase's success criterion is met — closes those leaks.

The 5-phase structure mirrors how a careful team would do the work without an LLM in the loop: discover, decide, implement, test, validate. Skipping a phase is a known anti-pattern; the autopilot makes each one a named step with a checkable output.

Smart shortcuts exist because resumption is the common case. A user who already ran `deep-interview` yesterday should not be forced to redo it today; reading the existing spec and jumping into Phase 2 is the right behavior.

The Phase 4 (QA) / Phase 5 (Validation) separation exists even though `ralph` already runs a reviewer pass — Phase 4 is dedicated test hardening (coverage gaps, flaky audit) backed by `verifier` fresh-evidence gates, and Phase 5 is multi-perspective review (architecture, adversarial critique, severity-rated diff). Both go beyond what one in-loop reviewer pass provides.

Adding `verifier` to Phase 4 removes the self-approval anti-pattern: the executor that greened a test no longer judges whether the test is actually passing. `verifier` runs the full BUILD/TEST/LINT/FUNCTIONALITY/TODO/ERROR_FREE protocol with pasted output and returns a machine-readable `verdict` field the autopilot can route on deterministically.

Auto commit/PR prohibition matches `ralph` and `team`. The marketplace's `git-commit` / `github-pr` are user-triggered; autopilot stops at the user's decision point.
</Why_This_Exists>

<Execution_Policy>
**Output language**: phase status reports, final summary use `$LANGUAGE`. Section headers (`## Phase 3`) stay English; content uses `$LANGUAGE`. Artifact contents inside each phase follow the sub-skill's own language rules.

**Phase sequencing**: phases run STRICTLY sequentially. Never start Phase N+1 until Phase N reports success. Never parallelize phases.

**Smart shortcuts**:
- If `.dt-handoff/<slug>/spec.md` exists and is recent (< 7 days) → skip Phase 1; confirm with user via `AskUserQuestion` only if `--no-skip-prompt` is NOT set.
- If `.dt-handoff/<slug>/plan.md` exists with `Status: pending approval` or `approved` → skip Phases 1-2.
- If `.dt-handoff/<slug>/prd.json` exists with at least one `passes: true` story → ask the user whether to resume or restart.

**Failure-mode stopping** (every terminal path below MUST run Phase 6 cleanup first for any `retention: session` artifacts under `.dt-handoff/<slug>/` before exiting; see "Guaranteed cleanup teardown" below):
- Phase 1 fails (deep-interview hits hard cap without reaching threshold) → run Phase 6 cleanup, then stop with status `PHASE1_AMBIGUOUS`; do not advance.
- Phase 2 fails (ralplan consensus not reached after 5 iterations) → run Phase 6 cleanup, then stop with status `PHASE2_NO_CONSENSUS`.
- Phase 3 fails (ralph / team escalates to architect or hits hard cap) → run Phase 6 cleanup, then stop with status `PHASE3_BLOCKED`.
- Phase 4 fails (same QA error persists 3 cycles) → run Phase 6 cleanup, then stop with status `PHASE4_QA_STUCK`; fundamental issue requires human input.
- Phase 5 fails (any Hard block or Soft block condition — see Phase 5 stratified verdict below) → return to Phase 3 with the findings; max 2 Phase 5 retries. On final failure (retries exhausted), run Phase 6 cleanup, then stop with status `PHASE5_REJECTED`.

**Guaranteed cleanup teardown**: Phase 6 cleanup MUST execute on every terminal path of autopilot, including the escalation stops above. The cleanup step calls `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.sh" --slug=<slug>` (or equivalent inline behavior) to remove `retention: session` artifacts under `.dt-handoff/<slug>/artifacts/ask/`, `.dt-handoff/<slug>/state/`, and other session-retention paths. `retention: permanent` artifacts (spec.md, plan.md, prd.json) are always preserved.

**Phase 5 stratified verdict (6-advisor)**:
- **Hard block (REJECT)**: `reviewer` or `critic` returns `verdict: REJECT` in their `@handoff-out` block, OR `architect` returns a CRITICAL finding at HIGH confidence → re-entry to Phase 3. Route on the machine-readable `verdict` field from `reviewer` and `critic`; route on finding severity/confidence for non-verdict advisors.
- **Soft block (REVISE)**: `doc-writer` returns CRITICAL/MAJOR at HIGH confidence in the `Missing` or `Inconsistent` category (non-doc artifact), or `performance-analyst` returns CRITICAL at HIGH confidence in `Hotpath` or `Complexity` → re-entry to Phase 3.
- **Annotation only**: `doc-writer` findings limited to `Outdated` or `Unclear`, or `performance-analyst` findings of MAJOR or below in `IO`, `Memory`, or `Cache` → recorded in `autopilot-validation.md` but no Phase 3 re-entry.

**Judgment vs advisory routing in Phase 5**:
- `reviewer` and `critic` are judgment agents: consume their `verdict` field from `@handoff-out` (`APPROVE` / `ACCEPT_WITH_RESERVATIONS` / `ITERATE` / `REVISE` / `REJECT`) for deterministic routing.
- `architect`, `security-auditor`, `performance-analyst`, `doc-writer` are advisory agents: they return Findings with severity/category/confidence; no `verdict` field. Route on finding severity+category as defined in the stratified verdict rule above.
- `verifier` may optionally join Phase 5 (see Phase 5 steps) for a final end-to-end evidence check; if dispatched, consume its `verdict: APPROVE / REVISE / REJECT` per normal verifier protocol.

**Auto commit/PR PROHIBITED**: same rule as ralph / team. Never invoke `git-commit`, `github-pr`, `gh pr`, `git commit`, `git push`.

**Execution path choice (Phase 3)**:
- Default: `ralph` (sequential persistence loop).
- Use `team` when `plan.md` Consequences/Follow-ups explicitly identify ≥ 3 independent workstreams with no shared file scope.
- User can force via `--exec=ralph` or `--exec=team`.

**events.jsonl logging**: append one JSON line to `.dt-handoff/<slug>/events.jsonl` at every phase boundary transition AND at every agent/sub-skill dispatch/return. Format per handoff-protocol §9:
```jsonl
{"ts":"<ISO8601>","producer":"autopilot","consumer":"<agent-or-skill>","event":"dispatch","kind":"<kind>","path":"<artifact-path>","status":"pending","verdict":null}
{"ts":"<ISO8601>","producer":"<agent-or-skill>","consumer":"autopilot","event":"return","kind":"<kind>","path":"<artifact-path>","status":"complete","verdict":"<verdict-or-null>"}
```
The log is `retention: session`. Append before each Task/Skill call and immediately after processing the `@handoff-out` block.

**Phase artifacts**: every phase produces a deterministic artifact in `.dt-handoff/<slug>/`. The autopilot reads each one (using `@handoff-in` blocks where applicable) before invoking the next phase.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`.
- `--exec=ralph|team`: force the Phase 3 execution skill choice. Default: auto-detect from plan.md.
- `--skip-phase1`: assume an existing `.dt-handoff/<slug>/spec.md` is valid; do not re-run deep-interview even if old.
- `--skip-phase2`: assume an existing `.dt-handoff/<slug>/plan.md` is valid; skip ralplan.
- `--no-skip-prompt`: skip the confirmation prompt when smart shortcuts apply (auto-skip silently).
- `--threshold=<0.0-1.0>`: forwarded to Phase 1 `deep-interview`. Default: that skill's own default (0.2).
- `--deliberate`: forwarded to Phase 2 `ralplan`.
- `--max-qa-cycles=<n>`: cap Phase 4 iterations (default 5).
</Settings_Reference>

<Arguments>
Idea description plus flags:
- `--exec=ralph|team` — Phase 3 path
- `--skip-phase1` / `--skip-phase2` — shortcut overrides
- `--no-skip-prompt` — silent shortcut
- `--threshold=<x>` — Phase 1 ambiguity threshold
- `--deliberate` — Phase 2 deliberate mode
- `--max-qa-cycles=<n>` — Phase 4 iteration cap
- `--lang=<value>` — output language
Examples:
- `/autopilot "Linear webhook 처리 서비스 만들어줘"`
- `/autopilot --skip-phase1 --exec=team "auth middleware 리팩터"`
- `/autopilot --deliberate "결제 검증 모듈 추가"`
</Arguments>

<Steps>

### Phase 0: Setup
1. **Parse the idea + flags** from the invocation.
2. **Infer slug** from the idea description (kebab-case, ≤ 40 chars).
3. **Create artifact root** via `mkdir -p .dt-handoff/<slug>/artifacts/ask .dt-handoff/<slug>/state .dt-handoff/<slug>/notepads`.
4. **Initialize events log**: create `.dt-handoff/<slug>/events.jsonl` if absent. Append a phase-start event:
   ```jsonl
   {"ts":"<ISO8601>","producer":"autopilot","consumer":"autopilot","event":"phase_start","kind":"trace","path":".dt-handoff/<slug>/events.jsonl","status":"pending","verdict":null}
   ```
5. **Probe smart shortcuts**:
   - Check `.dt-handoff/<slug>/spec.md` — if present and < 7 days old, candidate for Phase 1 skip.
   - Check `.dt-handoff/<slug>/plan.md` — if present with valid Status, candidate for Phase 1+2 skip.
   - Check `.dt-handoff/<slug>/prd.json` — if present with progress, candidate for full resumption.
6. **Confirm shortcuts** (unless `--no-skip-prompt`): single `AskUserQuestion` listing detected artifacts and proposing the resumption point. Options:
   - [Resume from detected point (Recommended)]
   - [Restart from Phase 1]
   - [Resume but re-run a specific phase] → follow-up question
7. **Announce the pipeline** in `$LANGUAGE`:
   ```
   Autopilot starting. Pipeline:
   - Phase 1: Expansion (deep-interview) — {skip ? "SKIPPED: spec.md exists" : "RUN"}
   - Phase 2: Planning (ralplan)         — {skip ? "SKIPPED: plan.md exists" : "RUN"}
   - Phase 3: Execution ({ralph or team})
   - Phase 4: QA (test-engineer + executor + verifier, max {max-qa-cycles} cycles)
   - Phase 5: Validation (architect + critic + reviewer + security-auditor + performance-analyst + doc-writer)
   - Stop: ready for commit (commit/PR is your call)
   ```

### Phase 1: Expansion (deep-interview)
8. **If not skipped**, append dispatch event to `events.jsonl`, then invoke:
   ```
   Skill("dev-tools:deep-interview", args="<idea> --threshold=<value>")
   ```
9. **Wait for completion**. Construct `@handoff-in` for the produced artifact and read `.dt-handoff/<slug>/spec.md`:
   ```
   @handoff-in
   kind: spec
   path: .dt-handoff/<slug>/spec.md
   contentHash: sha256:<hash>
   sizeBytes: <bytes>
   note: verify Status field and ambiguity score
   ```
10. **Verify success**: confirm `Status: PASSED` (not `EARLY_EXIT` or `HARD_CAP` unless user accepts). Append return event to `events.jsonl`.
11. **On failure**: if `Status` is `EARLY_EXIT` or `HARD_CAP` with high residual ambiguity, ask user via `AskUserQuestion` whether to retry, lower threshold, or abort.

### Phase 2: Planning (ralplan)
12. **If not skipped**, append dispatch event to `events.jsonl`, then invoke:
    ```
    Skill("dev-tools:ralplan", args="--from-spec=.dt-handoff/<slug>/spec.md {--deliberate if set}")
    ```
13. **Wait for completion**. Read `.dt-handoff/<slug>/plan.md` via `@handoff-in`:
    ```
    @handoff-in
    kind: plan
    path: .dt-handoff/<slug>/plan.md
    contentHash: sha256:<hash>
    sizeBytes: <bytes>
    note: verify Status field and acceptance criteria count
    ```
14. **Append return event to `events.jsonl`**. Verify Status: must be `pending approval` (not `best-effort consensus not reached`). If consensus was not reached, ask user whether to accept best-effort or restart Phase 2.

### Phase 3: Execution (ralph or team)
15. **Choose path**:
    - If `--exec` flag set, use it.
    - Else: parse `plan.md` Consequences/Follow-ups + Acceptance Criteria. If ≥ 3 independent workstreams with no file overlap → `team`. Else → `ralph`.
    - Announce the choice and the rationale.
16. **Append dispatch event to `events.jsonl`**, then invoke:
    ```
    Skill("dev-tools:ralph", args="--from-plan=.dt-handoff/<slug>/plan.md")
    // OR
    Skill("dev-tools:team", args="--from-plan=.dt-handoff/<slug>/plan.md")
    ```
17. **Wait for completion**. Read `.dt-handoff/<slug>/prd.json` and the latest `progress.txt` or `team-final.md`:
    ```
    @handoff-in
    kind: prd
    path: .dt-handoff/<slug>/prd.json
    contentHash: sha256:<hash>
    sizeBytes: <bytes>
    note: verify all stories passes:true
    ```
18. **Append return event to `events.jsonl`**. Verify success: all stories `passes: true`, reviewer / critic `verdict: APPROVE`, post-cleanup regression GREEN.
19. **On failure**: capture the blocking status, append a `phase_fail` event to `events.jsonl`, and stop with the matching Phase 3 status (e.g., `PHASE3_BLOCKED`).

### Phase 4: QA (test-engineer + executor + verifier cycles, max --max-qa-cycles)
20. **Append phase_start event** to `events.jsonl`.
21. **Iteration loop** (default 5 cycles):
    a. **Dispatch test hardening**. Append dispatch event to `events.jsonl`:
       ```
       Task(
         subagent_type="test-engineer",
         prompt="Audit the test suite for the changes made in this autopilot session.
         Look for: coverage gaps (HIGH/MEDIUM/LOW), flaky tests, missing edge cases,
         pyramid imbalance (too many e2e where unit would do).

         @handoff-in
         kind: prd
         path: .dt-handoff/<slug>/prd.json
         contentHash: sha256:<hash>
         sizeBytes: <bytes>
         note: Files changed are listed in the evidence fields of each story.

         Propose and author new failing tests for HIGH and MEDIUM gaps.
         Run them and confirm Red. Return findings + new test paths."
       )
       ```
    b. **Wait for output**. Append return event to `events.jsonl`. If new Red tests were authored, dispatch `executor` to make them Green (append dispatch event before, return event after):
       ```
       Task(subagent_type="executor", prompt="Make <new test paths> green with minimal diff")
       ```
    c. **After executor completes**, dispatch `verifier` for a fresh regression verification (append dispatch event):
       ```
       Task(
         subagent_type="verifier",
         prompt="Verify that the QA cycle changes are complete and regression is clean.

         @handoff-in
         kind: prd
         path: .dt-handoff/<slug>/prd.json
         contentHash: sha256:<hash>
         sizeBytes: <bytes>
         note: Run BUILD/TEST/LINT/FUNCTIONALITY/TODO/ERROR_FREE protocol. Changed files include the new test paths: <list>.

         Write findings to .dt-handoff/<slug>/artifacts/ask/verifier-qa-<ISO8601>.md."
       )
       ```
    d. **Consume `verifier` `@handoff-out` `verdict`** (append return event to `events.jsonl`):
       - `verdict: APPROVE` → exit Phase 4 loop (all checks GREEN, no new HIGH/MEDIUM gaps).
       - `verdict: REVISE` → loop back to step (a) with verifier's failing checks as input.
       - `verdict: REJECT` → stop with `PHASE4_QA_STUCK`.
    e. **If same error persists 3 cycles in a row** (verifier returns `REVISE` with identical failing checks) → append `phase_fail` event, stop with `PHASE4_QA_STUCK`.
22. **Append phase_complete event** to `events.jsonl`.

### Phase 5: Validation (multi-perspective)
23. **Append phase_start event** to `events.jsonl`.
24. **Fire 6 perspectives in parallel** (single message, 6 Task calls). Each advisor MUST persist findings to `.dt-handoff/<slug>/artifacts/ask/<agent>-<ISO8601>.md` with the 9-field descriptor frontmatter. The descriptor contract source of truth is `scripts/validate.sh` (see header comments for `DESC_*` variables and `@handoff-in`/`@handoff-out` format).

    Append one dispatch event to `events.jsonl` per advisor **before** firing (or batch as a multi-entry append):
    ```
    [
      Task(subagent_type="architect", prompt="Full-system architectural review of the changes.
        Focus: SOLID violations, scalability concerns, integration risks.

        @handoff-in
        kind: prd
        path: .dt-handoff/<slug>/prd.json
        contentHash: sha256:<hash>
        sizeBytes: <bytes>
        note: Changed files are in each story's evidence. Review for architectural integrity.

        <hand-off directive — see template below>"),

      Task(subagent_type="critic", prompt="Adversarial review. Steelman the strongest case AGAINST
        the chosen implementation. Identify principle-option inconsistencies and missed alternatives.

        @handoff-in
        kind: prd
        path: .dt-handoff/<slug>/prd.json
        contentHash: sha256:<hash>
        sizeBytes: <bytes>
        note: Spec context at .dt-handoff/<slug>/spec.md if needed.

        <hand-off directive — see template below>"),

      Task(subagent_type="reviewer", prompt="Severity-rated diff review. Confirm spec compliance
        (against .dt-handoff/<slug>/spec.md) and code quality. Return CRITICAL/MAJOR/MINOR with confidence.

        @handoff-in
        kind: spec
        path: .dt-handoff/<slug>/spec.md
        contentHash: sha256:<hash>
        sizeBytes: <bytes>

        <hand-off directive — see template below>"),

      Task(subagent_type="security-auditor", prompt="Security-focused review using AuthN/AuthZ/Secret/Crypto/Injection/SAST/Config categories. Return Findings with severity, location, evidence, confidence.
        <hand-off directive — see template below>"),

      Task(subagent_type="performance-analyst", prompt="Performance review using Hotpath/Complexity/IO/Memory/Cache categories. Return Findings.
        <hand-off directive — see template below>"),

      Task(subagent_type="doc-writer", prompt="Do not call Write/Edit during this invocation. Return diff-shaped recommendations only. Documentation review using Missing/Outdated/Inconsistent/Unclear categories. Return Findings.
        <hand-off directive — see template below>")
    ]
    ```

    **Hand-off directive template** (append to each Task prompt above; writing agent computes contentHash and sizeBytes at write time):
    ```
    Also persist your findings to `.dt-handoff/<slug>/artifacts/ask/<agent-name>-<ISO8601>.md` with this YAML frontmatter at the top:
    ---
    kind: advisor
    path: .dt-handoff/<slug>/artifacts/ask/<agent-name>-<ISO8601>.md
    contentHash: sha256:<sha256 of the body content below, excluding this frontmatter block>
    createdAt: <ISO8601-now>
    producer: <agent-name>
    sizeBytes: <byte count of the body content below>
    retention: session
    expiresAt: null
    status: complete
    ---
    followed by the same Findings body as the in-session reply. The descriptor contract is defined in scripts/validate.sh (see DESC_* variables). doc-writer note: this Write of the findings file is the only Write allowed during this invocation.

    Return an @handoff-out block at the end of your response. Judgment agents (reviewer, critic) include a verdict field; advisory agents (architect, security-auditor, performance-analyst, doc-writer) set verdict: null.
    ```

25. **Wait for all 6 to return**. Append one return event per advisor to `events.jsonl` (consuming the `@handoff-out` block from each). Optionally dispatch `verifier` for a final end-to-end evidence check before combining verdicts:
    ```
    Task(
      subagent_type="verifier",
      prompt="Run end-to-end verification for Phase 5 final check.
      @handoff-in
      kind: prd
      path: .dt-handoff/<slug>/prd.json
      contentHash: sha256:<hash>
      sizeBytes: <bytes>
      note: Final regression check after all Phase 5 advisor reviews."
    )
    ```
    If dispatched, consume verifier's `verdict`: `REVISE` or `REJECT` escalates back to Phase 3 (counts as a Hard block).

26. **Combine verdicts** using the Phase 5 stratified verdict rule (defined in `<Execution_Policy>`):
    - Hard block → return to Phase 3 with the findings. Max 2 Phase 5 retries. Append `phase_retry` event.
    - Soft block → return to Phase 3 with the findings. Max 2 Phase 5 retries. Append `phase_retry` event.
    - Annotation only → record in `autopilot-validation.md`; proceed to Phase 6. Append `phase_complete` event.
27. **Write validation summary** to `.dt-handoff/<slug>/autopilot-validation.md` with all 6 perspectives consolidated, including Annotation-only findings.

### Phase 6: Report and Stop
28. **Append phase_start and phase_complete events** to `events.jsonl`.
29. **Compose final report** in `$LANGUAGE`:
    - Phases completed: 1→2→3→4→5 (with SKIPPED markers where applicable)
    - Artifacts produced: list with paths under `.dt-handoff/<slug>/`
    - Stories total / completed
    - Tests added during QA: count
    - Validation verdict: combined APPROVE
    - Final regression: PASS
    - **Next steps**: "Run `/git-commit` to commit" + "Run `/github-pr` to open PR" — do NOT invoke.
30. **Append final session record** to `progress.txt` if it exists.
31. **Run cleanup teardown**:
    ```
    bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.sh" --slug=<slug>
    ```
    This removes `retention: session` artifacts (advisor findings, ephemeral handoffs, events.jsonl) and preserves `retention: permanent` artifacts (spec.md, plan.md, prd.json).
32. **STOP**. Do not invoke git mutations.

</Steps>

<Tool_Usage>
- **Read**: load `.dt-handoff/<slug>/*.md`, `prd.json`, sub-skill outputs. Verify `contentHash` from `@handoff-in` blocks (inline when `sizeBytes ≤ 4096`; otherwise read via path).
- **Write**: write `autopilot-validation.md` consolidating Phase 5 verdicts; append `progress.txt`; append `events.jsonl` (one JSON line per event); create `events.jsonl` at Phase 0.
- **Bash**: `mkdir -p .dt-handoff/<slug>/`, run test/build/lint between phases for verification; invoke `cleanup.sh` at Phase 6.
- **Skill**: invoke `dev-tools:deep-interview` (Phase 1), `dev-tools:ralplan` (Phase 2), `dev-tools:ralph` or `dev-tools:team` (Phase 3). One sub-skill per phase; sequential. Append dispatch+return events to `events.jsonl` around every Skill() call.
- **Task**: delegate to `test-engineer` and `executor` and `verifier` (Phase 4 loop); and to `architect` + `critic` + `reviewer` + `security-auditor` + `performance-analyst` + `doc-writer` in parallel (Phase 5); optionally `verifier` at end of Phase 5. Append dispatch+return events to `events.jsonl` around every Task() call.
- **AskUserQuestion**: confirm smart shortcuts at Phase 0; ask about retries at phase failure points.
- **`@handoff-in` contract**: include a `@handoff-in` block when dispatching agents that consume a persisted artifact. The block must include `kind`, `path`, `contentHash`, `sizeBytes`. Inline body only when `sizeBytes ≤ 4096`.
- **`@handoff-out` contract**: consume the machine-readable `@handoff-out` block from each returning agent; route on the `verdict` field for judgment agents (`reviewer`, `critic`, `verifier`); route on finding severity+category for advisory agents (`architect`, `security-auditor`, `performance-analyst`, `doc-writer`). Never route on prose keyword matching.
- Do NOT invoke `git-commit`, `github-pr`, `linear-tools:enrich-ticket` from inside autopilot.
</Tool_Usage>

<Examples>
**Example 1 — fresh start, full pipeline**:
User: "/autopilot 'Linear webhook 처리 서비스 만들어줘'"
Flow:
- Phase 0: no existing artifacts. Create `.dt-handoff/linear-webhook/`. Initialize `events.jsonl`. Announce pipeline.
- Phase 1: deep-interview runs ~8 rounds → spec.md threshold met → linked to `.dt-handoff/linear-webhook/spec.md`. Append dispatch+return events.
- Phase 2: ralplan runs → consensus on iteration 2 → `.dt-handoff/linear-webhook/plan.md` (pending approval). plan.md has 4 ACs that translate cleanly to 4 stories with some shared file scope → choose `ralph` for Phase 3. Append dispatch+return events.
- Phase 3: ralph runs → 4 stories complete → reviewer `verdict: APPROVE` → cleanup → regression GREEN. Append dispatch+return events.
- Phase 4: test-engineer audits → 2 HIGH gaps → authored 2 Red tests → executor Green → verifier dispatched → `verdict: APPROVE` (all 6 checks PASS) → exit Phase 4 in cycle 1. All events appended.
- Phase 5: architect + critic + reviewer + security-auditor + performance-analyst + doc-writer fire in parallel → all clean / annotation-only findings recorded. reviewer returns `verdict: APPROVE`, critic returns `verdict: APPROVE`. Append return events.
- Phase 6: write `autopilot-validation.md`. Run cleanup.sh. Report "Ready for commit. Suggest /git-commit then /github-pr." STOP.

**Example 2 — smart shortcut: resume from existing plan.md**:
User: "/autopilot 'auth middleware 리팩터'"
Flow:
- Phase 0: detect `.dt-handoff/auth-middleware-refactor/plan.md` from yesterday. AskUserQuestion → user picks "Resume from detected point".
- Phases 1-2: SKIPPED. Append skip events to `events.jsonl`.
- Phase 3: ralph from existing plan → run. Append dispatch+return events.
- Phases 4-5: run normally.
- Phase 6: report includes "Phases 1-2 skipped (artifacts from 2026-05-21 reused)."

**Example 3 — phase failure**:
Phase 3 ralph hits 3-fail escalation on story US-002 → status `PHASE3_BLOCKED`.
Autopilot appends `phase_fail` event to `events.jsonl`, runs Phase 6 cleanup, then stops. Final report names the blocking story, the architect's escalation summary, and the unresolved error. Phases 4-5 not attempted. User decides: fix manually then re-invoke `/autopilot` or address the architectural issue first.

**Example 4 — Phase 5 retry loop**:
Phase 5 critic returns `verdict: REJECT` (in `@handoff-out` block) on iteration 1 with "Missed alternative: A simpler key-value store would serve the same need with less infrastructure."
Autopilot appends `phase_retry` event, routes back to Phase 3 with the finding. ralph adjusts 1 story to evaluate the simpler approach. Re-runs Phase 4 (lightweight, since most tests still pass; verifier confirms `verdict: APPROVE`). Re-runs Phase 5 — reviewer and critic both return `verdict: APPROVE`. Total Phase 5 retries: 1/2.

**Example 5 — Phase 4 verifier REVISE**:
Phase 4 cycle 1: test-engineer authors 2 Red tests → executor greens them → verifier dispatched → `verdict: REVISE` (TEST FAIL: 1 assertion still red in auth.test.ts:88). Autopilot appends return event and loops: dispatches executor again with verifier's failing check as input → re-dispatches verifier → `verdict: APPROVE`. Phase 4 exits in cycle 2.
</Examples>

<Final_Checklist>
- Did I probe smart shortcuts at Phase 0 and confirm with the user (unless `--no-skip-prompt`)?
- Did I create `.dt-handoff/<slug>/` and initialize `events.jsonl` at Phase 0?
- Did I announce the pipeline before starting?
- Did phases run STRICTLY sequentially?
- Did I append `events.jsonl` entries at every phase boundary and every agent dispatch/return?
- For Phase 3: did I auto-select ralph vs team based on plan.md parallelism (unless `--exec` forced it)?
- For Phase 4: did test-engineer actually author new Red tests, did executor Green them, and did `verifier` return `verdict: APPROVE` before exiting the loop?
- Did Phase 4 stop on 3 same-error cycles instead of grinding?
- Did I route on `verifier` `@handoff-out` `verdict` — not prose matching?
- For Phase 5: did architect + critic + reviewer + security-auditor + performance-analyst + doc-writer fire in parallel (one message, six Task calls)?
- Did I route on machine-readable `verdict` for `reviewer` and `critic`, and on severity+category for non-judgment advisors?
- Did I apply the Phase 5 stratified verdict rule (Hard block / Soft block / Annotation only) correctly?
- Did I write `.dt-handoff/<slug>/autopilot-validation.md` consolidating all 6 Phase 5 perspectives?
- Did I refrain from running git/gh mutations?
- Did Phase 6 cleanup teardown run on every terminal path (success and failure)?
- Did the final report list all phases with their status (RUN / SKIPPED / FAILED)?
- Did the final report suggest `/git-commit` and `/github-pr` as next steps without invoking them?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
- All phases complete (with smart-skip respected) + Phase 5 APPROVE + regression GREEN → report and stop.
- Phase 1 hits hard cap without threshold → stop `PHASE1_AMBIGUOUS`.
- Phase 2 consensus not reached after 5 iterations → stop `PHASE2_NO_CONSENSUS`.
- Phase 3 ralph/team escalates or hits cap → stop with the sub-skill's status; do not advance to Phase 4.
- Phase 4 same error persists 3 cycles (verifier returns `REVISE` with identical failures) → stop `PHASE4_QA_STUCK`; report the recurring error.
- Phase 5 REJECT after 2 retries → stop `PHASE5_REJECTED`; surface the unresolved findings.
- User says "stop" / "cancel" → stop immediately; record the phase reached in `progress.txt`; run Phase 6 cleanup.
- Any sub-skill reports user-halt → propagate and stop.
- Every terminal path runs `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.sh" --slug=<slug>` before exiting.
</Escalation_And_Stop_Conditions>

<Advanced>
## Phase Artifact Matrix
| Phase | Sub-skill / Agent | Input | Output | Skip Condition |
|-------|-------------------|-------|--------|----------------|
| 1 Expansion | `deep-interview` | idea | `.dt-handoff/<slug>/spec.md` | spec.md exists, <7d |
| 2 Planning  | `ralplan`        | spec.md | `.dt-handoff/<slug>/plan.md` | plan.md Status valid |
| 3 Execution | `ralph` or `team` | plan.md | `prd.json` + code changes + `progress.txt`/`team-final.md` | prd all-passes + reviewer APPROVE |
| 4 QA        | `test-engineer` + `executor` + `verifier` | code changes + prd.json | new tests in repo; `verifier` findings at `artifacts/ask/verifier-qa-<ISO8601>.md` | verifier `verdict: APPROVE` + no HIGH/MEDIUM gaps |
| 5 Validation | `architect`+`critic`+`reviewer`+`security-auditor`+`performance-analyst`+`doc-writer` (parallel; optional `verifier`) | code changes | `.dt-handoff/<slug>/autopilot-validation.md`; per-agent findings at `artifacts/ask/<agent>-<ISO8601>.md` | all approve / Annotation only |

## Execution Path Auto-Detection (Phase 3)
Heuristic for choosing `ralph` vs `team`:
- Read `plan.md` Acceptance Criteria. For each, parse the implied file scope.
- If ≥ 3 ACs touch entirely disjoint file sets AND have no `dependsOn`-like ordering language → `team`.
- Else → `ralph`.
- Always announce the choice + the parsed reasoning to the user before invoking.

## Phase 5 Parallelism Note
Phase 5 is the one place in this skill family where `architect` + `critic` + `reviewer` + `security-auditor` + `performance-analyst` + `doc-writer` run in parallel against the same artifact. This is safe because:
- Each agent is read-only at calling time. doc-writer is the exception: it has Write/Edit at the agent level but is gated to read-only by the skill prompt for this invocation ("Do not call Write/Edit during this invocation. Return diff-shaped recommendations only.").
- Judgment agent verdicts (`reviewer`, `critic`) are consumed from `@handoff-out` `verdict` field. Advisory agent findings (all others) are evaluated by the stratified verdict rule.
- The autopilot combines verdicts after all six return. Optional `verifier` dispatch happens after all six return and before combining verdicts.

This is NOT a general license to parallelize advisor agents elsewhere — it works here specifically because the artifact is final code, not a moving target.

## events.jsonl Event Reference
Control-plane events appended at each checkpoint (format per handoff-protocol §9):

| Checkpoint | `event` value | `producer` | `consumer` |
|------------|--------------|------------|------------|
| Phase 0 initialization | `phase_start` | autopilot | autopilot |
| Sub-skill / agent dispatch | `dispatch` | autopilot | `<skill-or-agent>` |
| Sub-skill / agent return | `return` | `<skill-or-agent>` | autopilot |
| Phase boundary (success) | `phase_complete` | autopilot | autopilot |
| Phase boundary (failure) | `phase_fail` | autopilot | autopilot |
| Phase 5 retry | `phase_retry` | autopilot | autopilot |

## Skipping the Confirmation Prompt
`--no-skip-prompt` is useful in batch / CI-like contexts where AskUserQuestion is unwanted. The shortcut detection still runs, but the highest-fit shortcut is applied silently and noted in the announce step.
</Advanced>
