---
name: ralplan
description: Consensus planning skill. Delegates plan drafting to `planner`, runs Architect + Performance-analyst review in parallel, and uses `critic` as the sole verdict authority in a max-5-iteration loop. Produces an ADR at `.dt-handoff/<slug>/plan.md`, marked `pending approval`. TRIGGER on "/ralplan", "ralplan", "plan this", "합의 계획". DO NOT TRIGGER for execution requests (those go to ralph / autopilot) or for free-form brainstorming.
---

<Purpose>
Produce a consensus-approved implementation plan as an ADR at `.dt-handoff/<slug>/plan.md`, ready to feed into `ralph` or `autopilot`. The `planner` agent authors the draft plan; `architect` and `performance-analyst` review it in parallel; `critic` issues the sole verdict. Iterations continue (max 5) until `critic` returns APPROVE or ACCEPT_WITH_RESERVATIONS. The output is always marked `pending approval` — this skill never executes code or delegates implementation.
</Purpose>

<Use_When>
- A spec (`.dt-handoff/<slug>/spec.md` from `deep-interview` or an ad-hoc description) needs a vetted implementation plan before any code is written.
- User invokes `/ralplan`, says "ralplan", "plan this with consensus", "합의 계획 잡아줘".
- The work involves architectural choices, migrations, or high-risk areas (auth, security, destructive changes) and warrants pre-mortem + expanded test planning.
- `autopilot` Phase 2 (Planning) calls this skill as a sub-step.
</Use_When>

<Do_Not_Use_When>
- The user wants execution, not planning — route to `ralph` or `autopilot`.
- The user wants requirements capture (WHAT, not HOW) — route to `deep-interview`.
- The user wants a one-shot bug fix or trivial change — delegate to `executor` directly.
- The user wants free-form brainstorming with no committed artifact — answer directly without invoking ralplan.
- The user wants severity-rated review of an existing plan — use `code-review` or `critic` directly.
</Do_Not_Use_When>

<Why_This_Exists>
Plans written by one author and approved by the same author tend to share that author's blind spots — they overweight the chosen approach and underweight alternatives. Extracting draft authorship to `planner` separates the sequencing/decomposition concern from the consensus loop orchestration. The Architect + Critic loop then forces an adversarial pass: Architect supplies the strongest steelman antithesis and at least one tradeoff tension; Critic enforces principle-option consistency, fair alternatives, risk mitigation clarity, testable acceptance criteria, and concrete verification steps.

Marking output `pending approval` instead of `approved` exists because execution skills (`ralph`, `team`, `autopilot`) consume this artifact, and they should never auto-execute a plan that was not explicitly approved by the user. The boundary is enforced here, at the planning layer, so downstream skills can trust the artifact.

RALPLAN-DR structured deliberation (Principles / Drivers / Options / pre-mortem) exists because plans framed only as "what we'll do" hide the reasoning. Writing the principles first makes it possible to challenge a plan on its own logic later, when memory of the original tradeoffs has faded.
</Why_This_Exists>

<Execution_Policy>
**Planning/Execution boundary**: this skill is planning-only. It MAY inspect context and write `.dt-handoff/<slug>/plan.md`, but it MUST mark the artifact `Status: pending approval`. It MUST NOT run mutating shell commands, edit source files outside `.dt-handoff/`, commit, push, open PRs, or invoke execution skills.

**Output language**: plan content uses `$LANGUAGE`. Section headers (`## Decision`, `## Drivers`, …) stay English; content uses `$LANGUAGE`.

**Sequential agent passes**: Phase 3 (Architect + performance-analyst, parallel) and Phase 4 (Critic) MUST run sequentially. Never invoke Critic before all Phase 3 outputs return. Within Phase 3, architect and performance-analyst are called in a single parallel batch (same message). Critic remains the sole verdict owner.

**Critic single-verdict authority**: performance-analyst is an advisor whose Findings feed Critic; Critic alone returns the machine-readable `verdict` field. performance-analyst output never replaces or overrides the Critic verdict.

**Verdict routing**: consume the `verdict` field from Critic's `@handoff-out` block (not prose keyword matching). Routing table:
- `APPROVE` or `ACCEPT_WITH_RESERVATIONS` → finalize (proceed to Phase 6).
- `ITERATE`, `REVISE`, or `REJECT` → iterate (return to Phase 2 redux, up to the cap).

**Iteration cap**: max 5 planner → Critic loops. If Critic still returns a non-finalizing verdict after 5, present the best version to the user with `Status: best-effort, consensus not reached`.

**Deliberate mode**: forced via `--deliberate`, or auto-enabled when the task description contains high-risk signals (auth/security, migration, destructive change, production incident, compliance/PII, public API break). Adds:
- Pre-mortem with 3 failure scenarios.
- Expanded test plan covering unit / integration / e2e / observability.

**Interactive mode**: enabled via `--interactive`. Prompts the user at draft review (Step 5) and at final approval (Step 12) via `AskUserQuestion`. Without the flag, the workflow runs fully automated and stops at `pending approval` without prompting.

**events.jsonl logging**: append one JSON line to `.dt-handoff/<slug>/events.jsonl` for every agent dispatch and every agent return (§9 of handoff-protocol.md format). Log before each Task call and immediately after processing the `@handoff-out` block.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: from `plugin.json` `settings.language` (default `Korean`). Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.
- `--interactive`: prompt the user at draft review and final approval. Without it, runs fully automated to `pending approval`.
- `--deliberate`: force pre-mortem + expanded test plan. Auto-enabled on high-risk keywords.
- `--from-spec=<path>`: consume an existing `.dt-handoff/<slug>/spec.md` as the input. Default: infer from the task description; if not inferable, ask the user.
</Settings_Reference>

<Arguments>
Optional task description plus flags:
- `--interactive` — enable user prompts at draft review and final approval.
- `--deliberate` — force deliberate mode (pre-mortem + expanded tests).
- `--lang=<value>` — output language override.
- `--from-spec=<path>` — feed an existing spec file as input.
Examples:
- `/ralplan "Linear webhook 처리 서비스"`
- `/ralplan --interactive --deliberate "auth middleware 리팩터"`
- `/ralplan --from-spec=.dt-handoff/foo/spec.md`
</Arguments>

<Steps>

### Phase 1: Setup
1. **Parse the input**: extract task description and flags. If `--from-spec` is provided, Read that file. Otherwise infer slug from the task description (kebab-case, ≤40 chars).
2. **Determine slug** and ensure `.dt-handoff/<slug>/` exists (`mkdir -p`). If a `plan.md` already exists there, ask the user (`AskUserQuestion`) whether to overwrite, append a new iteration section, or abort.
3. **Detect deliberate mode**: scan the task description for high-risk signals. If matched, treat as `--deliberate` even if the flag is absent. Note the auto-detection in the output.
4. **Initialize events log**: create or verify `.dt-handoff/<slug>/events.jsonl` exists. This file accumulates one JSON line per agent dispatch/return throughout the run.

### Phase 2: Draft Plan (planner agent)
5. **Dispatch planner** with `@handoff-in` referencing the spec or task description. Include `path`, `contentHash`, and `sizeBytes`; inline the body if `sizeBytes ≤ 4096`.
   ```
   Task(
     subagent_type="planner",
     prompt="Draft an ADR plan for the following task/spec. Include:
     - Decision (1-2 sentence summary of what will be done)
     - Drivers (top 3): what's forcing the decision now
     - Principles (3-5): invariants the plan must respect
     - Options (≥2 viable): each with bounded pros/cons; if only one viable option, include explicit invalidation rationale for alternatives
     - Chosen Approach: which option + why
     - Consequences: what changes, what becomes harder, what becomes easier
     - Follow-ups: deferred work explicitly out of scope
     - Acceptance Criteria: testable, file-anchored where possible
     {deliberate ? - Pre-mortem (3 failure scenarios) + Test Plan (unit/integration/e2e/observability)}

     @handoff-in
     kind: spec
     path: .dt-handoff/<slug>/spec.md
     contentHash: sha256:<hash>
     sizeBytes: <bytes>
     note: <task description or 'see spec file'>"
   )
   ```
   Append dispatch event to `events.jsonl`:
   ```json
   {"ts":"<ISO8601>","producer":"ralplan","consumer":"planner","event":"dispatch","kind":"spec","path":".dt-handoff/<slug>/spec.md","status":"pending","verdict":null}
   ```
6. **Receive planner output**. Parse `@handoff-out` block; record return event:
   ```json
   {"ts":"<ISO8601>","producer":"planner","consumer":"ralplan","event":"return","kind":"advisor","path":"<planner-output-path>","status":"complete","verdict":null}
   ```
7. **(--interactive only) Draft review**: `AskUserQuestion` showing Principles / Drivers / Options summary. Options: [Proceed to review] / [Request changes] / [Skip review and approve as-is].

### Phase 3: Architect Pass + Performance Analysis (parallel)
8. **Dispatch architect and performance-analyst in a single parallel batch** (both Task calls issued in the same message). Append one dispatch event to `events.jsonl` per call:
   ```
   [
     Task(
       subagent_type="architect",
       prompt="Review the following plan. Provide:
       1. The strongest steelman antithesis (best argument AGAINST the chosen option).
       2. At least one real tradeoff tension that the plan glosses over.
       3. Synthesis when possible — how to integrate the antithesis without abandoning the plan.
       {deliberate ? 4. Explicit flags for any principle violations.}
       Focus on design and trade-off concerns only (not root-cause debugging).

       @handoff-in
       kind: plan
       path: .dt-handoff/<slug>/plan.md
       contentHash: sha256:<hash>
       sizeBytes: <bytes>
       note: steelman antithesis + tradeoff tensions"
     ),
     Task(
       subagent_type="performance-analyst",
       prompt="Performance review of the following plan using Hotpath / Complexity / IO / Memory / Cache categories. Return Findings as a structured list, each with: severity, category, location, evidence, recommendation, confidence. If zero findings, set zero_findings_note: 'no concerns at this confidence'.

       @handoff-in
       kind: plan
       path: .dt-handoff/<slug>/plan.md
       contentHash: sha256:<hash>
       sizeBytes: <bytes>
       note: performance analysis of proposed design"
     )
   ]
   ```
9. **Wait for ALL Phase 3 outputs** (architect + performance-analyst). Parse each `@handoff-out` block. Append one return event per agent. Do not start Critic until both return.

### Phase 4: Critic Pass
10. **Dispatch critic** (only after ALL Step 9 outputs return). Append dispatch event to `events.jsonl`:
    ```
    Task(
      subagent_type="critic",
      prompt="Evaluate the plan + architect feedback + performance findings. Enforce:
      - Principle-option consistency (chosen option respects stated principles).
      - Fair alternatives (every option got honest pros/cons).
      - Risk mitigation clarity (named risks have named mitigations).
      - Testable acceptance criteria (each AC has a concrete verification step).
      {deliberate ? - Pre-mortem and expanded test plan must be present and non-trivial.}

      Return machine-readable verdict in your @handoff-out block:
        verdict: APPROVE | ACCEPT_WITH_RESERVATIONS | ITERATE | REVISE | REJECT
      You are the sole verdict owner — performance-analyst findings are advisory input only.

      @handoff-in
      kind: plan
      path: .dt-handoff/<slug>/plan.md
      contentHash: sha256:<hash>
      sizeBytes: <bytes>
      note: consensus verdict for ralplan iteration N

      ## Architect feedback
      (path: <architect @handoff-out path>; inline if small or summarize key points)

      ## Performance findings (from performance-analyst)
      (path: <performance-analyst @handoff-out path>; inline if small or summarize key points)"
    )
    ```
11. **Parse Critic's `@handoff-out`** block. Extract `verdict` field. Append return event:
    ```json
    {"ts":"<ISO8601>","producer":"critic","consumer":"ralplan","event":"return","kind":"advisor","path":"<critic-output-path>","status":"complete","verdict":"<APPROVE|ACCEPT_WITH_RESERVATIONS|ITERATE|REVISE|REJECT>"}
    ```

### Phase 5: Iteration Loop (max 5)
12. **If `verdict` is `APPROVE` or `ACCEPT_WITH_RESERVATIONS`** → proceed to Phase 6.
13. **If `verdict` is `ITERATE`, `REVISE`, or `REJECT`**:
    a. Collect Architect + Critic feedback from their `@handoff-out` paths.
    b. Dispatch planner again with the revised scope, referencing critic and architect findings.
    c. Return to Step 8 (new Architect + performance-analyst pass) → Step 10 (new Critic pass).
    d. Repeat up to 5 total iterations.
    e. If 5 iterations reached without a finalizing verdict, proceed to Phase 6 with `Status: best-effort, consensus not reached`.

### Phase 6: Finalize
14. **Write the plan** to `.dt-handoff/<slug>/plan.md` with the structure below. The file MUST open with the descriptor frontmatter before the `# Plan:` heading.
15. **(--interactive only) Final approval**: `AskUserQuestion` with options:
    - [Approve and proceed to ralph]
    - [Approve and proceed to team]
    - [Request changes — back to Phase 2]
    - [Reject — keep artifact but stop]
16. **Without --interactive**: write file, report path, stop. Do NOT auto-invoke ralph/team.

**Descriptor frontmatter** (machine truth: `scripts/validate.sh` `DESC_*` vars):

```yaml
---
kind: plan
path: .dt-handoff/<slug>/plan.md
contentHash: sha256:<hash of body below>
createdAt: <ISO8601-now>
producer: ralplan
sizeBytes: <byte count of body below>
retention: permanent
expiresAt: null
status: pending        # or approved (after user approval) | best-effort
---
```

The legacy `Status: pending approval` line inside the `## Metadata` block remains for backward compatibility, mapped to descriptor `status: pending`.

### Plan Structure (`.dt-handoff/<slug>/plan.md`)

```markdown
# Plan: <title>

## Metadata
- Slug: <slug>
- Generated: YYYY-MM-DD
- Mode: short | deliberate (+auto-detected reason if applicable)
- Iterations: N/5
- Status: pending approval | best-effort consensus not reached
- Input spec: <.dt-handoff/<slug>/spec.md or "ad-hoc">

## Decision
<1-2 sentence summary>

## Drivers
1. <driver>
2. <driver>
3. <driver>

## Principles
- <principle>
- <principle>
- ...

## Options Considered
### Option A: <name>
- Pros: ...
- Cons: ...
- Invalidation rationale (if not chosen): ...

### Option B: <name>
- ...

## Chosen Approach
<which option + why; reference principles + drivers>

## Consequences
- <what changes>
- <what becomes harder>
- <what becomes easier>

## Acceptance Criteria
- [ ] <testable criterion with file path or behavior reference>
- [ ] ...

## Pre-mortem (deliberate mode only)
### Scenario 1: <failure mode>
- Trigger: ...
- Detection: ...
- Mitigation: ...

### Scenario 2: ...
### Scenario 3: ...

## Test Plan (deliberate mode only)
- Unit: ...
- Integration: ...
- E2E: ...
- Observability: ...

## Follow-ups (out of scope)
- ...

## Agent Verdict Trail
| Iteration | Planner Summary | Architect Key Tension | Critic Verdict | Critic Notes |
|-----------|-----------------|-----------------------|----------------|--------------|
| 1         | ...             | ...                   | ITERATE        | ...          |
| 2         | ...             | ...                   | APPROVE        | ...          |
```

</Steps>

<Tool_Usage>
- **Read**: load `.dt-handoff/<slug>/spec.md` if `--from-spec` is set; read sibling code only when the plan needs file:line anchors for Acceptance Criteria.
- **Write**: emit `.dt-handoff/<slug>/plan.md` and append to `.dt-handoff/<slug>/events.jsonl`. These are the ONLY mutations allowed by this skill.
- **Bash**: `mkdir -p .dt-handoff/<slug>/` to create the slug directory if missing. No other mutating Bash.
- **Task**: delegate to `planner` for draft authoring (Step 5 and redux in Step 13b); delegate to `architect` and `performance-analyst` in a single parallel batch (Step 8) for design and performance review; delegate to `critic` (Step 10) after all Phase 3 outputs return. Phase 3 → Phase 4 is always sequential.
- **AskUserQuestion**: only when `--interactive` is set (draft review + final approval).
- Do NOT delegate to `executor`, `ralph`, `team`, `autopilot` — this skill is planning-only.

**@handoff-in construction**: for every Task dispatch, build an `@handoff-in` block with `{kind, path, contentHash, sizeBytes}`. Inline the body only when `sizeBytes ≤ 4096`. Reference contract: `scripts/validate.sh` `DESC_*` vars (machine truth for enums and required fields).

**events.jsonl format** (one JSON object per line, append-only):
```json
{"ts":"<ISO8601>","producer":"<caller>","consumer":"<agent>","event":"dispatch|return","kind":"<kind>","path":"<artifact-path>","status":"<status>","verdict":null|"<VERDICT>"}
```
Location: `.dt-handoff/<slug>/events.jsonl`, `kind: trace`, `retention: session`.
</Tool_Usage>

<Examples>
**Example 1 — non-interactive plan from spec**:
User: "/ralplan --from-spec=.dt-handoff/linear-webhook/spec.md"
Flow: Read spec → dispatch planner → receive draft → dispatch architect + performance-analyst (parallel) → wait for both → dispatch critic → parse `verdict: APPROVE` on iteration 2 → write `.dt-handoff/linear-webhook/plan.md` with `Status: pending approval` → report path. Stop without prompting. events.jsonl has 6 entries (3 dispatches + 3 returns).

**Example 2 — interactive deliberate mode**:
User: "/ralplan --interactive --deliberate 'auth middleware 리팩터'"
Flow: detect security keyword → confirm deliberate auto-enabled → dispatch planner (with pre-mortem + test plan instruction) → AskUserQuestion (draft review) → user picks "Proceed to review" → dispatch architect + performance-analyst → dispatch critic → parse `verdict: ITERATE` → revise: dispatch planner again → dispatch architect + performance-analyst → dispatch critic → parse `verdict: APPROVE` → write plan.md → AskUserQuestion (final approval) → user picks "Approve and proceed to ralph" → STOP (do not auto-invoke ralph; the user will).

**Example 3 — consensus not reached**:
User: "/ralplan 'redesign storage layer'"
Flow: 5 iterations, critic returns `verdict: REVISE` on iterations 1-5 → write plan with `Status: best-effort consensus not reached` → report unresolved concerns from final Critic `@handoff-out` path → stop.

**Example 4 — ACCEPT_WITH_RESERVATIONS**:
Critic returns `verdict: ACCEPT_WITH_RESERVATIONS` on iteration 3 → treat as finalizing (same as APPROVE) → write plan with `Status: pending approval` → note reservations from critic findings in the Agent Verdict Trail row → stop without further iteration.
</Examples>

<Final_Checklist>
- Did I parse `--interactive` / `--deliberate` / `--lang` / `--from-spec` correctly?
- Did I dispatch `planner` for draft authoring (not write the draft in the main session)?
- Did I build `@handoff-in` blocks (path + contentHash + sizeBytes) for every agent dispatch?
- Did planner's `@handoff-out` return before Phase 3 started?
- Did architect + performance-analyst run in parallel (Phase 3), and did both complete before Critic started (Phase 4)?
- Did I route based on Critic's machine-readable `verdict` field (not prose matching)?
- Did I treat `APPROVE` and `ACCEPT_WITH_RESERVATIONS` as finalizing, and `ITERATE`/`REVISE`/`REJECT` as iterate?
- Did I respect the 5-iteration cap?
- Did I append events.jsonl entries for every dispatch and return?
- Did the final artifact land at `.dt-handoff/<slug>/plan.md`?
- Is the descriptor frontmatter present with all required fields (reference: `scripts/validate.sh` `DESC_*` vars)?
- Is the `Status` line `pending approval` (or `best-effort consensus not reached`)?
- Did I avoid invoking `executor`, `ralph`, `team`, or `autopilot`?
- For `--interactive`: did I prompt at draft review and final approval?
- For non-interactive: did I stop without prompting after writing the file?
- Did all section headers stay English, with content in `$LANGUAGE`?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
- User says "stop", "cancel", "abort": stop immediately; do not write the plan.
- 5 iteration cap reached without a finalizing verdict: write the best version with `Status: best-effort consensus not reached`, report unresolved concerns from final Critic `@handoff-out`.
- Planner, Architect, or Critic returns an error / is unavailable: retry once; if still failing, write the best draft with a note that one of the passes did not run.
- Spec file referenced by `--from-spec` does not exist: ask the user to provide it via `AskUserQuestion`; do not proceed.
</Escalation_And_Stop_Conditions>

<Advanced>
## High-risk keyword set (auto-enables `--deliberate`)
- auth, authn, authz, oauth, jwt, session
- migration, schema change, alter table, data backfill
- destructive (delete, drop, truncate, rm -rf, force)
- production incident, hotfix
- compliance, PII, PHI, GDPR, SOC2
- public API break, breaking change

## Iteration Quality Gates
| Iteration | Planner must include | Architect must add | Critic must check |
|-----------|---------------------|--------------------|-------------------|
| 1 | full ADR draft | initial steelman | basic consistency |
| 2 | addressed concerns | tradeoff tensions | risk mitigations |
| 3 | refined options | principle violations | testable AC |
| 4 | synthesis attempt | synthesis proposal | option fairness |
| 5 | final version | final stress test | verdict + unresolved-concerns list |

## ADR-Plan Cross-reference
The `plan.md` ADR is consumed by:
- `ralph` — reads Acceptance Criteria into `prd.json` stories.
- `team` — reads decomposition cues from Consequences + Follow-ups.
- `autopilot` — orchestrates the handoff between this plan and execution.

If consumers need additional fields (e.g., dependency graph, parallelization hints), surface them as Follow-ups rather than embedding them in the chosen option.

## Verdict enum (from handoff-protocol.md §7.2 / scripts/validate.sh DESC_VERDICT_ENUM)
| Critic verdict | ralplan routing |
|----------------|-----------------|
| APPROVE | finalize → Phase 6 |
| ACCEPT_WITH_RESERVATIONS | finalize → Phase 6 (note reservations) |
| ITERATE | iterate → Phase 2 redux |
| REVISE | iterate → Phase 2 redux |
| REJECT | iterate → Phase 2 redux |
</Advanced>
