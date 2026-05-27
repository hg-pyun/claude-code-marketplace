---
name: ralplan
description: Consensus planning skill. Delegates plan drafting to `planner`, runs Architect + Performance-analyst review in parallel, and uses `critic` as the sole verdict authority in a max-5-iteration loop. Produces an ADR at `.dt-handoff/<slug>/plan.md`, marked `pending approval`. TRIGGER on "/ralplan", "ralplan", "plan this", "합의 계획". DO NOT TRIGGER for execution requests (those go to ralph / autopilot) or for free-form brainstorming.
---

<Purpose>
Produce a consensus-approved implementation plan as an ADR at `.dt-handoff/<slug>/plan.md`, ready to feed into `ralph` or `autopilot`. The `planner` agent authors the draft; `architect` and `performance-analyst` review it in parallel; `critic` issues the sole verdict. Iterations continue (max 5) until `critic` finalizes. The output is always marked `pending approval` — this skill never executes code or delegates implementation.
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
Plans written by one author and approved by the same author tend to share that author's blind spots — they overweight the chosen approach and underweight alternatives. Extracting draft authorship to `planner` separates the sequencing/decomposition concern from the consensus-loop orchestration. The Architect + Critic loop then forces an adversarial pass: Architect supplies the strongest steelman antithesis and at least one tradeoff tension; Critic enforces principle-option consistency, fair alternatives, risk-mitigation clarity, testable acceptance criteria, and concrete verification steps.

Marking output `pending approval` instead of `approved` exists because execution skills (`ralph`, `team`, `autopilot`) consume this artifact, and they should never auto-execute a plan the user did not explicitly approve. The boundary is enforced here, at the planning layer, so downstream skills can trust the artifact.

Structured deliberation (Principles / Drivers / Options / pre-mortem) exists because plans framed only as "what we'll do" hide the reasoning. Writing the principles first makes it possible to challenge a plan on its own logic later, when memory of the original tradeoffs has faded.
</Why_This_Exists>

<Execution_Policy>
**Planning/Execution boundary**: planning-only. MAY inspect context and write `.dt-handoff/<slug>/plan.md` (+ `events.jsonl`). MUST mark the artifact `Status: pending approval`. MUST NOT run mutating shell commands, edit source outside `.dt-handoff/`, commit, push, open PRs, or invoke execution skills (`executor`/`ralph`/`team`/`autopilot`).

**Output language**: plan content uses `$LANGUAGE`. Section headers (`## Decision`, `## Drivers`, …) stay English.

**Sequential passes**: Phase 3 (architect + performance-analyst, one parallel batch) and Phase 4 (critic) run STRICTLY sequentially. Never dispatch critic until BOTH Phase 3 outputs return.

**Critic single-verdict authority**: critic alone returns the machine-readable `verdict`. performance-analyst is an advisor whose Findings feed critic; its output never overrides the verdict.

**Verdict routing** (single source — consume the `verdict` field from critic's `@handoff-out`, never prose matching):
- `APPROVE` or `ACCEPT_WITH_RESERVATIONS` → finalize (Phase 6). On `ACCEPT_WITH_RESERVATIONS`, note reservations in the Verdict Trail.
- `ITERATE`, `REVISE`, or `REJECT` → iterate (Phase 2 redux), up to the cap.

**Iteration cap**: max 5 planner → critic loops. If still non-finalizing after 5, finalize the best version with `Status: best-effort consensus not reached`.

**Deliberate mode**: forced via `--deliberate`, or auto-enabled when the task contains a high-risk signal (set in `<Advanced>`). Adds a pre-mortem (3 failure scenarios) and an expanded test plan (unit / integration / e2e / observability).

**Interactive mode** (`--interactive`): prompt the user at draft review (Step 7) and final approval (Step 15) via `AskUserQuestion`. Without it, the workflow runs fully automated and stops at `pending approval` without prompting.

**events.jsonl logging**: append one line to `.dt-handoff/<slug>/events.jsonl` for every agent dispatch and every agent return (this is a leaf orchestrator — per-dispatch granularity is intended). Format and field rules: handoff-protocol §9 (mirrored in `<Tool_Usage>`).
</Execution_Policy>

<Settings_Reference>
| Flag | Default | Effect |
|------|---------|--------|
| `--lang=<value>` | `plugin.json` `settings.language` (`Korean`) | Output language for plan content. Presets: Korean, English, Japanese, Chinese; custom passed through. |
| `--from-spec=<path>` | infer from task; if not inferable, ask | Consume an existing `.dt-handoff/<slug>/spec.md` as input. |
| `--deliberate` | off (auto-on for high-risk keywords) | Force pre-mortem + expanded test plan. |
| `--interactive` | off | Prompt at draft review and final approval; otherwise run automated to `pending approval`. |
</Settings_Reference>

<Arguments>
Optional task description plus the flags above. Examples:
- `/ralplan "Linear webhook 처리 서비스"`
- `/ralplan --interactive --deliberate "auth middleware 리팩터"`
- `/ralplan --from-spec=.dt-handoff/foo/spec.md`
</Arguments>

<Steps>
Each step is declarative: **goal · delegate · input→output · success/fail**. The per-agent prompt intent is one line; cross-cutting mechanics (handoff blocks, verdict routing, events logging) follow the single rules in `<Execution_Policy>` and `<Tool_Usage>` — not re-spelled per step.

### Phase 1 — Setup
1. Parse the task description + flags. If `--from-spec`, Read that file. Otherwise infer a kebab-case `slug` (≤ 40 chars).
2. `mkdir -p .dt-handoff/<slug>/`; create `events.jsonl` if absent. If a `plan.md` already exists, ask (`AskUserQuestion`) whether to overwrite, append a new iteration section, or abort.
3. Detect deliberate mode: scan the task for high-risk signals (`<Advanced>`); if matched, treat as `--deliberate` and note the auto-detection in the output.

### Phase 2 — Draft Plan
4. **Dispatch `planner`** with an `@handoff-in` referencing the spec/task (`kind: spec @ .dt-handoff/<slug>/spec.md`, or the task description when ad-hoc).
   - **Intent**: author an ADR draft — Decision, Drivers (top 3), Principles (3–5), Options (≥ 2 viable, each with bounded pros/cons; if only one viable, explicit invalidation rationale for alternatives), Chosen Approach, Consequences, Follow-ups, Acceptance Criteria (testable, file-anchored). In deliberate mode, also a Pre-mortem (3 scenarios) + Test Plan.
   - **Output**: draft plan body. **Success**: `@handoff-out` returns `status: complete`. **Fail**: error/unavailable → retry once, else write the best draft with a note that the pass did not run.

### Phase 3 — Architect + Performance Analysis (parallel)
5. **Dispatch `architect` and `performance-analyst` in a single parallel batch** (both Task calls in one message), each with `@handoff-in` `kind: plan @ .dt-handoff/<slug>/plan.md`.
   - **architect intent**: strongest steelman antithesis against the chosen option; ≥ 1 real tradeoff tension the plan glosses over; synthesis where possible; (deliberate) flag any principle violations. Design/tradeoff concerns only.
   - **performance-analyst intent**: review by Hotpath / Complexity / IO / Memory / Cache; return Findings (severity, category, location, evidence, recommendation, confidence). Zero findings → `zero_findings_note`.
6. **Wait for BOTH outputs** before Phase 4. Parse each `@handoff-out`.

### Phase 4 — Critic Pass (sole verdict)
7. **(--interactive only) Draft review** before critic: `AskUserQuestion` showing Principles / Drivers / Options summary — [Proceed] / [Request changes] / [Approve as-is].
8. **Dispatch `critic`** (only after BOTH Phase 3 outputs return), with `@handoff-in` `kind: plan` plus the architect feedback and performance findings (reference their `@handoff-out` paths; inline only if small).
   - **Intent**: enforce principle-option consistency, fair alternatives, named-risk → named-mitigation, testable AC (each with a concrete verification step); in deliberate mode the pre-mortem and expanded test plan must be present and non-trivial. Return the machine-readable `verdict` in `@handoff-out`. Critic is the sole verdict owner; performance findings are advisory.

### Phase 5 — Iteration Loop (max 5)
9. Route on critic's `verdict` per the routing table in `<Execution_Policy>`.
10. On a non-finalizing verdict: collect architect + critic feedback (from their `@handoff-out` paths), re-dispatch `planner` with the revised scope (Phase 2 redux), then re-run Phase 3 → Phase 4. Repeat up to 5 total iterations; on the 5th without a finalizing verdict, finalize with `Status: best-effort consensus not reached`.

### Phase 6 — Finalize
11. **Write the plan** to `.dt-handoff/<slug>/plan.md` using the Structure below, opening with the descriptor frontmatter before the `# Plan:` heading.
12. **(--interactive only) Final approval**: `AskUserQuestion` — [Approve and proceed to ralph] / [Approve and proceed to team] / [Request changes → Phase 2] / [Reject — keep artifact, stop].
13. **Without --interactive**: write file, report path, STOP. Do NOT auto-invoke ralph/team.

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
The legacy `Status: pending approval` line inside `## Metadata` remains for backward compatibility, mapped to descriptor `status: pending`.

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
- **Read**: load `.dt-handoff/<slug>/spec.md` (`--from-spec`); read sibling code only when AC need file:line anchors.
- **Write**: emit `.dt-handoff/<slug>/plan.md` and append `events.jsonl`. These are the ONLY mutations this skill makes.
- **Bash**: `mkdir -p .dt-handoff/<slug>/` only. No other mutating Bash.
- **Task**: `planner` (Phase 2 draft + redux); `architect` + `performance-analyst` in one parallel batch (Phase 3); `critic` after both return (Phase 4). Phase 3 → Phase 4 is always sequential. Bare agent names — no plugin prefix. Do NOT delegate to `executor`/`ralph`/`team`/`autopilot`.
- **AskUserQuestion**: only when `--interactive` (draft review + final approval).
- **Handoff contract** (single rule — do not re-spell per dispatch): when dispatching an agent that consumes a persisted artifact, include an `@handoff-in` block (`kind`, `path`, `contentHash`, `sizeBytes`; inline the body only when `sizeBytes ≤ INLINE_MAX_BYTES`). Consume the returning `@handoff-out` and route on its `verdict`. Block shapes, descriptor schema, `verdict` enum, and `INLINE_MAX_BYTES` are defined in handoff-protocol §6/§7/§8 — mirrored in the `scripts/validate.sh` header.
- **events.jsonl** (single rule): one JSON object per line, append-only at `.dt-handoff/<slug>/events.jsonl` (`kind: trace`, `retention: session`), per handoff-protocol §9 — appended before each Task dispatch and immediately after parsing each `@handoff-out`.
</Tool_Usage>

<Examples>
**Example 1 — non-interactive plan from spec**:
User: "/ralplan --from-spec=.dt-handoff/linear-webhook/spec.md"
Flow: Read spec → planner draft → architect + performance-analyst (parallel) → wait for both → critic returns `verdict: APPROVE` on iteration 2 → write `.dt-handoff/linear-webhook/plan.md` with `Status: pending approval` → report path, STOP. events.jsonl has 6 entries (3 dispatch + 3 return).

**Example 2 — interactive deliberate mode**:
User: "/ralplan --interactive --deliberate 'auth middleware 리팩터'"
Flow: detect security keyword → deliberate auto-enabled → planner draft (pre-mortem + test plan) → `AskUserQuestion` draft review → "Proceed" → architect + performance-analyst → critic `verdict: ITERATE` → planner redux → architect + performance-analyst → critic `verdict: APPROVE` → write plan.md → `AskUserQuestion` final approval → "Approve and proceed to ralph" → STOP (do not auto-invoke ralph).

**Example 3 — consensus not reached**:
User: "/ralplan 'redesign storage layer'"
Flow: 5 iterations, critic returns `verdict: REVISE` each time → write plan with `Status: best-effort consensus not reached` → report unresolved concerns from the final critic `@handoff-out` → STOP.

**Example 4 — ACCEPT_WITH_RESERVATIONS**:
Critic returns `verdict: ACCEPT_WITH_RESERVATIONS` on iteration 3 → treat as finalizing → write plan with `Status: pending approval`, note reservations in the Verdict Trail → STOP without further iteration.
</Examples>

<Final_Checklist>
- Parsed `--interactive` / `--deliberate` / `--lang` / `--from-spec` correctly?
- Dispatched `planner` for the draft (not authored in the main session)?
- `planner` `@handoff-out` returned before Phase 3 started?
- architect + performance-analyst ran in one parallel batch, and BOTH completed before critic started?
- Routed on critic's machine-readable `verdict` field (never prose), per the `<Execution_Policy>` table?
- Treated `APPROVE` / `ACCEPT_WITH_RESERVATIONS` as finalizing and `ITERATE` / `REVISE` / `REJECT` as iterate, within the 5-iteration cap?
- Appended events.jsonl for every dispatch and return?
- Final artifact landed at `.dt-handoff/<slug>/plan.md` with the descriptor frontmatter (all required fields per `scripts/validate.sh` `DESC_*`)?
- `Status` line is `pending approval` (or `best-effort consensus not reached`)?
- Avoided invoking `executor` / `ralph` / `team` / `autopilot`?
- `--interactive`: prompted at draft review and final approval. Non-interactive: stopped without prompting after writing.
- Section headers English, content in `$LANGUAGE`?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
- User says "stop" / "cancel" / "abort": stop immediately; do not write the plan.
- 5-iteration cap reached without a finalizing verdict: write the best version with `Status: best-effort consensus not reached`, report unresolved concerns from the final critic `@handoff-out`.
- planner / architect / critic errors or is unavailable: retry once; if still failing, write the best draft with a note that one of the passes did not run.
- `--from-spec` path does not exist: ask the user to provide it (`AskUserQuestion`); do not proceed.
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
The `plan.md` ADR is consumed by `ralph` (reads Acceptance Criteria into `prd.json` stories), `team` (reads decomposition cues from Consequences + Follow-ups), and `autopilot` (orchestrates the handoff to execution). If a consumer needs extra fields (dependency graph, parallelization hints), surface them as Follow-ups rather than embedding them in the chosen option. Verdict routing is single-sourced in `<Execution_Policy>`; the enum is defined in handoff-protocol §7.2 / `scripts/validate.sh` `DESC_VERDICT_ENUM`.
</Advanced>
</content>
</invoke>
