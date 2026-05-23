---
name: ralplan
description: Consensus planning skill. Runs Architect → Performance-analyst → Critic loop with RALPLAN-DR structured deliberation, produces an ADR at .specs/<slug>/plan.md, and marks it `pending approval`. Use when an idea or spec needs a vetted plan before execution. TRIGGER on "/ralplan", "ralplan", "plan this", "합의 계획". DO NOT TRIGGER for execution requests (those go to ralph / autopilot) or for free-form brainstorming.
---

<Purpose>
Produce a consensus-approved implementation plan as an ADR at `.specs/<slug>/plan.md`, ready to feed into `ralph` or `autopilot`. The main session writes the draft plan and the `architect` and `critic` agents pressure-test it in sequence; iterations continue (max 5) until `critic` returns APPROVE. The output is always marked `pending approval` — this skill never executes code or delegates implementation.
</Purpose>

<Use_When>
- A spec (`.specs/<slug>/spec.md` from `deep-interview` or an ad-hoc description) needs a vetted implementation plan before any code is written.
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
Plans written by one author and approved by the same author tend to share that author's blind spots — they overweight the chosen approach and underweight alternatives. The Architect + Critic loop forces an adversarial pass: Architect supplies the strongest steelman antithesis and at least one tradeoff tension; Critic enforces principle-option consistency, fair alternatives, risk mitigation clarity, testable acceptance criteria, and concrete verification steps.

Marking output `pending approval` instead of `approved` exists because execution skills (`ralph`, `team`, `autopilot`) consume this artifact, and they should never auto-execute a plan that was not explicitly approved by the user. The boundary is enforced here, at the planning layer, so downstream skills can trust the artifact.

RALPLAN-DR structured deliberation (Principles / Drivers / Options / pre-mortem) exists because plans framed only as "what we'll do" hide the reasoning. Writing the principles first makes it possible to challenge a plan on its own logic later, when memory of the original tradeoffs has faded.
</Why_This_Exists>

<Execution_Policy>
**Planning/Execution boundary**: this skill is planning-only. It MAY inspect context and write `.specs/<slug>/plan.md`, but it MUST mark the artifact `Status: pending approval`. It MUST NOT run mutating shell commands, edit source files outside `.specs/`, commit, push, open PRs, or invoke execution skills.

**Output language**: plan content uses `$LANGUAGE`. Section headers (`## Decision`, `## Drivers`, …) stay English; content uses `$LANGUAGE`.

**Sequential agent passes**: Steps 3 (Architect + performance-analyst, parallel) and 4 (Critic) MUST run sequentially. Never invoke Critic before all Phase 3 outputs return. Within Phase 3, architect and performance-analyst are called in a single parallel batch (same message). Critic remains the sole verdict owner.

**Critic single-verdict authority**: performance-analyst is an advisor whose Findings feed Critic; Critic alone returns APPROVE / ITERATE / REJECT. performance-analyst output never replaces or overrides the Critic verdict.

**Iteration cap**: max 5 Architect → Critic loops. If Critic still rejects after 5, present the best version to the user with a note that consensus was not reached.

**Deliberate mode**: forced via `--deliberate`, or auto-enabled when the task description contains high-risk signals (auth/security, migration, destructive change, production incident, compliance/PII, public API break). Adds:
- Pre-mortem with 3 failure scenarios.
- Expanded test plan covering unit / integration / e2e / observability.

**Interactive mode**: enabled via `--interactive`. Prompts the user at draft review (Step 2.5) and at final approval (Step 6) via `AskUserQuestion`. Without the flag, the workflow runs fully automated and stops at `pending approval` without prompting.

**Verdict semantics**: Critic returns one of APPROVE / ITERATE / REJECT. Any non-APPROVE verdict triggers the iteration loop. APPROVE marks the plan ready for `pending approval` finalization.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: from `plugin.json` `settings.language` (default `Korean`). Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.
- `--interactive`: prompt the user at draft review and final approval. Without it, runs fully automated to `pending approval`.
- `--deliberate`: force pre-mortem + expanded test plan. Auto-enabled on high-risk keywords.
- `--from-spec=<path>`: consume an existing `.specs/<slug>/spec.md` as the input. Default: infer from the task description; if not inferable, ask the user.
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
- `/ralplan --from-spec=.specs/foo/spec.md`
</Arguments>

<Steps>

### Phase 1: Setup
1. **Parse the input**: extract task description and flags. If `--from-spec` is provided, Read that file. Otherwise infer slug from the task description (kebab-case, ≤40 chars).
2. **Determine slug** and ensure `.specs/<slug>/` exists. If a `plan.md` already exists there, ask the user (`AskUserQuestion`) whether to overwrite, append a new iteration section, or abort.
3. **Detect deliberate mode**: scan the task description for high-risk signals. If matched, treat as `--deliberate` even if the flag is absent. Note the auto-detection in the output.

### Phase 2: Draft Plan (Main Session)
4. **Draft the initial plan** directly (do NOT delegate Step 4 to an agent — the main session owns authorship). Include:
   - **Decision**: 1-2 sentence summary of what will be done.
   - **Drivers (top 3)**: what's forcing the decision now.
   - **Principles (3-5)**: invariants the plan must respect.
   - **Options (≥2 viable)**: each with bounded pros/cons. If only one viable option, include explicit invalidation rationale for alternatives.
   - **Chosen Approach**: which option + why.
   - **Consequences**: what changes, what becomes harder, what becomes easier.
   - **Follow-ups**: deferred work explicitly out of scope.
   - **Acceptance Criteria**: testable, file-anchored where possible.
   - If deliberate: **Pre-mortem** (3 failure scenarios) + **Test Plan** (unit / integration / e2e / observability).
5. **(--interactive only) Draft review**: `AskUserQuestion` showing Principles / Drivers / Options summary. Options: [Proceed to review] / [Request changes] / [Skip review and approve as-is].

### Phase 3: Architect Pass + Performance Analysis (parallel)
6. **Delegate to architect and performance-analyst in a single parallel batch** (both Task calls issued in the same message):
   ```
   [
     Task(
       subagent_type="architect",
       prompt="Review the following plan. Provide:
       1. The strongest steelman antithesis (best argument AGAINST the chosen option).
       2. At least one real tradeoff tension that the plan glosses over.
       3. Synthesis when possible — how to integrate the antithesis without abandoning the plan.
       {deliberate ? 4. Explicit flags for any principle violations.}

       <draft plan content>"
     ),
     Task(
       subagent_type="performance-analyst",
       prompt="Performance review of the following plan using Hotpath / Complexity / IO / Memory / Cache categories. Return Findings as a list, each with: severity, category, location, evidence, recommendation, confidence. If zero findings, set zero_findings_note: 'no concerns at this confidence'.

       <draft plan content>"
     )
   ]
   ```
7. **Wait for ALL Phase 3 outputs** (architect + performance-analyst). Do not start Critic until both return.

### Phase 4: Critic Pass
8. **Delegate to critic** (only after ALL Step 7 outputs return):
   ```
   Task(
     subagent_type="critic",
     prompt="Evaluate the plan + architect feedback + performance findings. Enforce:
     - Principle-option consistency (chosen option respects stated principles).
     - Fair alternatives (every option got honest pros/cons).
     - Risk mitigation clarity (named risks have named mitigations).
     - Testable acceptance criteria (each AC has a concrete verification step).
     - {deliberate ? Pre-mortem and expanded test plan must be present and non-trivial.}

     Return verdict: APPROVE / ITERATE / REJECT with explicit reasoning.
     Note: you are the sole verdict owner — performance-analyst findings are advisory input only.

     <plan>
     <plan content>
     </plan>

     ## Architect feedback
     <architect output>

     ## Performance findings (from performance-analyst)
     <performance-analyst output>"
   )
   ```

### Phase 5: Iteration Loop (max 5)
9. **If Critic returns APPROVE** → proceed to Phase 6.
10. **If Critic returns ITERATE or REJECT**:
   a. Collect Architect + Critic feedback.
   b. Main session revises the plan (Step 4 redux, focused on addressed concerns).
   c. Return to Step 6 (new Architect pass) → Step 8 (new Critic pass).
   d. Repeat up to 5 total iterations.
   e. If 5 iterations reached without APPROVE, proceed to Phase 6 with `Status: best-effort, consensus not reached`.

### Phase 6: Finalize
11. **Write the plan** to `.specs/<slug>/plan.md` with the structure below. The file MUST open with the OMC hand-off descriptor frontmatter described below before the `# Plan:` heading.
12. **(--interactive only) Final approval**: `AskUserQuestion` with options:
   - [Approve and proceed to ralph]
   - [Approve and proceed to team]
   - [Request changes — back to Phase 2]
   - [Reject — keep artifact but stop]
13. **Without --interactive**: write file, report path, stop. Do NOT auto-invoke ralph/team.

**Hand-off descriptor frontmatter** (OMC parity; see `plugins/hg-pyun-tools/SPEC.md` for full schema):

```yaml
---
kind: plan
path: .specs/<slug>/plan.md
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

### Plan Structure (`.specs/<slug>/plan.md`)

```markdown
# Plan: <title>

## Metadata
- Slug: <slug>
- Generated: YYYY-MM-DD
- Mode: short | deliberate (+auto-detected reason if applicable)
- Iterations: N/5
- Status: pending approval | best-effort consensus not reached
- Input spec: <.specs/<slug>/spec.md or "ad-hoc">

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
| Iteration | Architect Summary | Critic Verdict | Critic Notes |
|-----------|-------------------|----------------|--------------|
| 1         | ...               | ITERATE        | ...          |
| 2         | ...               | APPROVE        | ...          |
```

</Steps>

<Tool_Usage>
- **Read**: load `.specs/<slug>/spec.md` if `--from-spec` is set; read sibling code only when the plan needs file:line anchors for Acceptance Criteria.
- **Write**: emit `.specs/<slug>/plan.md` (and create the directory if missing). This is the ONLY mutation allowed by this skill.
- **Bash**: create the `.specs/<slug>/` directory if missing (`mkdir -p`). No other mutating Bash.
- **Task**: delegate to `architect` and `performance-analyst` in a single parallel batch (Step 6), then to `critic` (Step 8) after both Phase 3 outputs return. Phase 3 → Phase 4 is always sequential.
- **AskUserQuestion**: only when `--interactive` is set (draft review + final approval).
- Do NOT delegate to `executor`, `ralph`, `team`, `autopilot` — this skill is planning-only.
</Tool_Usage>

<Examples>
**Example 1 — non-interactive plan from spec**:
User: "/ralplan --from-spec=.specs/linear-webhook/spec.md"
Flow: Read spec → draft plan → Task(architect) → wait → Task(critic) → APPROVE on iteration 2 → write `.specs/linear-webhook/plan.md` with `Status: pending approval` → report path. Stop without prompting.

**Example 2 — interactive deliberate mode**:
User: "/ralplan --interactive --deliberate 'auth middleware 리팩터'"
Flow: detect security keyword → confirm deliberate auto-enabled → draft with pre-mortem + test plan → AskUserQuestion (draft review) → user picks "Proceed to review" → Task(architect) → Task(critic) → ITERATE → revise → Task(architect) → Task(critic) → APPROVE → write plan.md → AskUserQuestion (final approval) → user picks "Approve and proceed to ralph" → STOP (do not auto-invoke ralph; the user will).

**Example 3 — consensus not reached**:
User: "/ralplan 'redesign storage layer'"
Flow: 5 iterations, Critic still ITERATE on iteration 5 → write plan with `Status: best-effort consensus not reached` → report unresolved concerns from final Critic pass → stop.
</Examples>

<Final_Checklist>
- Did I parse `--interactive` / `--deliberate` / `--lang` / `--from-spec` correctly?
- Did the draft include all required sections (Decision / Drivers / Principles / Options / Chosen / Consequences / AC / Follow-ups)?
- If deliberate: did I include Pre-mortem (3 scenarios) and expanded Test Plan?
- Did architect + performance-analyst run in parallel (Phase 3), and did both complete before Critic started (Phase 4)?
- Did I respect the 5-iteration cap?
- Did the final artifact land at `.specs/<slug>/plan.md`?
- Is the `Status` line `pending approval` (or `best-effort consensus not reached`)?
- Did I avoid invoking `executor`, `ralph`, `team`, or `autopilot`?
- For `--interactive`: did I prompt at draft review and final approval?
- For non-interactive: did I stop without prompting after writing the file?
- Did all section headers stay English, with content in `$LANGUAGE`?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
- User says "stop", "cancel", "abort": stop immediately; do not write the plan.
- 5 iteration cap reached without APPROVE: write the best version with `Status: best-effort consensus not reached`, report unresolved concerns.
- Architect or Critic returns an error / unavailable: retry once; if still failing, write the best draft with a note that one of the two passes did not run.
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
| Iteration | Architect must add | Critic must check |
|-----------|--------------------|--------------------|
| 1 | initial steelman | basic consistency |
| 2 | tradeoff tensions | risk mitigations |
| 3 | principle violations | testable AC |
| 4 | synthesis attempt | option fairness |
| 5 | final stress test | verdict + unresolved-concerns list |

## ADR-Plan Cross-reference
The `plan.md` ADR is consumed by:
- `ralph` — reads Acceptance Criteria into `prd.json` stories.
- `team` — reads decomposition cues from Consequences + Follow-ups.
- `autopilot` — orchestrates the handoff between this plan and execution.

If consumers need additional fields (e.g., dependency graph, parallelization hints), surface them as Follow-ups rather than embedding them in the chosen option.
</Advanced>
