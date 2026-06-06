---
name: ralplan
description: Consensus panel planning skill. Generates N risk-proportional candidate approaches via `architect` fan-out, independently evaluates them, then has a SEPARATED `critic` adversarially attack each (author≠attacker enforced by dispatch topology) and a distinct `critic` synthesize a ranked consensus ADR at `.dt-handoff/<slug>/plan.md`, marked `pending approval`. Panel width and attack depth scale to risk (LOW/MEDIUM/HIGH). TRIGGER on "/ralplan", "ralplan", "plan this", "합의 계획". DO NOT TRIGGER for execution requests (those go to ralph / autopilot) or for free-form brainstorming.
---

<Purpose>
Produce a consensus-approved implementation plan as an ADR at `.dt-handoff/<slug>/plan.md`, ready to feed into `ralph` or `autopilot`. ralplan is a **candidate-panel consensus engine**: it generates N genuinely distinct candidate approaches by fanning out `architect` instances, independently evaluates them, has a **separated `critic`** adversarially attack each candidate, and a **distinct `critic`** synthesize and rank them into a single ADR. Panel width (N) and attack depth scale to the task's risk. The output is always marked `pending approval` — this skill never executes code or delegates implementation.

The non-negotiable invariant is **adversarial blind-spot elimination = author ≠ attacker**: the agent that authors a candidate is never the agent that attacks it, and the synthesizer is distinct from every attacker. This separation is enforced by **dispatch topology** (different `subagent_type` in different Task calls). What that structurally guarantees is narrow but real — *no single context ever authors and then approves its own work*. Independence beyond that (that the separate attacker/synthesizer does not share the author's systematic blind spots) is strengthened by orthogonal lenses + model diversity, but is a prose-enforced convention, not a harness-level code gate.
</Purpose>

<Use_When>
- A spec (`.dt-handoff/<slug>/spec.md` from `deep-interview`/`interview`, or an ad-hoc description) needs a vetted implementation plan before any code is written.
- User invokes `/ralplan`, says "ralplan", "plan this with consensus", "합의 계획 잡아줘".
- The work involves architectural choices, migrations, or high-risk areas (auth, security, destructive changes) and warrants a wider panel + pre-mortem + expanded test planning (auto-detected → HIGH tier).
- `autopilot` Phase 2 (Planning) calls this skill as a sub-step.
</Use_When>

<Do_Not_Use_When>
- The user wants execution, not planning — route to `ralph` or `autopilot`.
- The user wants requirements capture (WHAT, not HOW) — route to `deep-interview` / `interview`.
- The user wants a one-shot bug fix or trivial change with no design choice — delegate to `executor` directly (ralplan will still run a minimal N=1 panel if invoked, but it is overkill).
- The user wants free-form brainstorming with no committed artifact — answer directly without invoking ralplan.
- The user wants severity-rated review of an existing plan — use `code-review` or `critic` directly.
</Do_Not_Use_When>

<Why_This_Exists>
Plans written by one author and approved by the same author share that author's blind spots — they overweight the chosen approach and underweight alternatives. The classic fix (one draft, then a reviewer) only weakens this; the draft still anchors the whole deliberation. A **panel of independent candidates**, each grown from a different starting framing and each attacked by a *separate* adversary, eliminates blind spots structurally rather than behaviorally: there is no single draft to anchor on, and no agent ever grades its own work.

Two corrections make the separation real rather than cosmetic. First, candidate authorship belongs to `architect`, not `planner`: `planner` explicitly refuses design judgment and delegates it, while `architect` is the agent that produces multi-option/trade-off analysis. Second, decorrelation must be real — identical-weight models share systematic blind spots ("capability symmetry ≠ judgment independence"), so the attacker is decorrelated from the author by an orthogonal attack lens and, when the runtime allows per-dispatch model selection, by a different model tier.

Risk-proportional depth replaces the old cost machinery (mode-gate / Critic-input-set / model-routing / Dispatch Ledger), whose savings were never observed in practice. A single dial — risk tier — sets panel width, attack depth, and whether a pre-mortem runs. Cost is controlled by three visible knobs (N, attack-lens count, model tier), not by conditional fast-paths.

Marking output `pending approval` instead of `approved` exists because execution skills (`ralph`, `team`, `autopilot`) consume this artifact and must never auto-execute a plan the user did not explicitly approve. The boundary is enforced here so downstream skills can trust the artifact.
</Why_This_Exists>

<Execution_Policy>
**Planning/Execution boundary**: planning-only. MAY inspect context and write `.dt-handoff/<slug>/plan.md` (+ `events.jsonl`). MUST mark the artifact `Status: pending approval` (descriptor `status: pending`). MUST NOT run mutating shell commands, edit source outside `.dt-handoff/`, commit, push, open PRs, or invoke execution skills (`executor`/`ralph`/`team`/`autopilot`).

**Output language**: plan content uses `$LANGUAGE`. Section headers (`## Decision`, `## Drivers`, …) stay English.

**The invariant (author ≠ attacker), enforced by dispatch topology**: candidate authorship is dispatched as `subagent_type=architect`; adversarial attack as `subagent_type=critic`; synthesis/ranking as a `critic` that is a DIFFERENT Task from every attacker critic. These are always separate Task calls. What this structurally guarantees is narrow but real: *no single context ever authors and then approves its own work*. It is enforced by separate Task dispatch — not by labels, and not by an `events.jsonl` "machine check" (events are append-only trace, never read back as a gating input). Decorrelating the attacker/synthesizer from the author's systematic blind spots *beyond* within-context separation rests on orthogonal lenses + model diversity and is a prose-enforced convention — honestly weaker than a code gate, the same candor applied to the parallel barrier below.

**Risk triage sets depth, never skips the adversary**: Phase 0 classifies the task into a risk tier and derives `{N, attack_lens count, premortem}`. Triage scales panel width and attack depth ONLY — a separated `critic` attack is NEVER skipped, even at N=1. Ambiguous signal → escalate (false-HIGH > false-LOW). The high-risk keyword set (`<Advanced>`) forces a HIGH floor + `premortem=true`. The triage decision and its rationale are recorded visibly in the plan's `## Metadata`.

**Tier → depth** (single source): `LOW → N=1`, `MEDIUM → N=2`, `HIGH → N=3` (hard cap **4**). LOW skips Phase 2 (independent evaluation) and the pre-mortem; HIGH adds per-candidate `performance-analyst` evaluation, multi-lens attack, and a pre-mortem.

**Decorrelation (two layers)**:
- (1) **framing orthogonality** — the 1st, fully portable floor. Each candidate `architect` receives one orthogonal framing lens (`<Advanced>` palette) + a "you do not see the other candidates" isolation instruction. Each attacker `critic` is assigned an attack lens *orthogonal to that candidate's generation framing* (the orchestrator assigns from the orthogonal complement — not the agent's self-report).
- (2) **model diversity** — applied by default when the runtime supports per-dispatch `model=`: the **attack critic is always `opus`** (the gate stays strong), candidate-generation `architect`s are **spread across tiers** (e.g. opus/sonnet), and for each candidate the attacker's model ≠ that candidate's author's model. When per-dispatch `model=` is unavailable, fall back to framing-only and record `model-diversity: unavailable, framing-only` in the Verdict Trail. all-opus is the fallback floor, not the goal.

**No self-report gating**: the mandatory re-attack after synthesis/iteration is gated by a **plan diff** — if the synthesized/iterated plan touches the `Decision`, `Drivers`, or `Options` sections, Phase 3 re-attack is forced. This is an LLM section-diff (honestly a heuristic, NOT advertised as non-gameable code enforcement); it is strictly better than the prior `planner` self-report ("approach unchanged"). AC-wording/typo-only changes may skip the re-attack.

**Verdict routing** (single source — consume the `verdict` field from the synthesizing critic's `@handoff-out`, never prose matching):
- `APPROVE` or `ACCEPT_WITH_RESERVATIONS` → finalize (Phase 5). On `ACCEPT_WITH_RESERVATIONS`, note reservations in the Verdict Trail.
- `ITERATE`, `REVISE`, or `REJECT` → iterate (re-attack survivors or generate one fresh candidate, then re-synthesize), up to the cap.

**Iteration cap (tier-proportional)**: `LOW=1`, `MEDIUM=2`, `HIGH=3`; if every candidate is invalidated, HIGH gets `+1` (=4). If still non-finalizing at the cap, finalize the best version with `Status: best-effort consensus not reached` and report unresolved concerns from the final critic `@handoff-out`.

**Always write plan.md**: even when triage suggests the task may be trivial, the skill ALWAYS produces `.dt-handoff/<slug>/plan.md` and stops (no self-skip) — `autopilot` Phase 3 reads this artifact to route `ralph`/`team`, so the precondition must hold. There is no "skip ralplan, go straight to executor" advisory message.

**Cost knobs (no machinery)**: cost is controlled ONLY by three visible knobs — `N`, attack-lens count, and model tier. There is no mode-gate, no Critic-input-set promotion, no model-routing fast-path, and no Dispatch Ledger.

**Output contract preserved**: the engine is fully replaced but the `plan.md` ADR schema, the descriptor frontmatter, and the `pending-approval` boundary are unchanged — `ralph` (AC → `prd.json`), `team` (decomposition cues), and `autopilot` (Status gate + workstream routing) consume the same artifact with zero migration. New `## Metadata` fields are additive only.

**Interactive mode** (`--interactive`): prompt the user at the candidate-review checkpoint (after Phase 1) and at final approval (Phase 5) via `AskUserQuestion`. Without it, the workflow runs fully automated and stops at `pending approval`.

**events.jsonl logging**: append one line per agent dispatch and per agent return to `.dt-handoff/<slug>/events.jsonl` (`kind: trace`, `retention: session`, append-only). This is an audit trace ONLY — it is never read back as a gating input. Format per handoff-protocol §9 (mirrored in `<Tool_Usage>`).
</Execution_Policy>

<Settings_Reference>
| Flag | Default | Effect |
|------|---------|--------|
| `--lang=<value>` | `plugin.json` `settings.language` (`Korean`) | Output language for plan content. Presets: Korean, English, Japanese, Chinese; custom passed through. |
| `--from-spec=<path>` | infer from task; if not inferable, ask | Consume an existing `.dt-handoff/<slug>/spec.md` as input. |
| `--tier=LOW\|MEDIUM\|HIGH` | auto (Phase 0 triage) | Manually override the risk tier (panel width + attack depth). Coexists with conservative auto-escalation; use to correct a suspected triage misclassification. |
| `--deliberate` | off | Alias for `--tier=HIGH` (forces N=3 + pre-mortem + multi-lens attack). Retained for backward compatibility (e.g. `autopilot` forwards it). |
| `--interactive` | off | Prompt at the candidate-review checkpoint and at final approval; otherwise run automated to `pending approval`. |
</Settings_Reference>

<Arguments>
Optional task description plus the flags above. Examples:
- `/ralplan "Linear webhook 처리 서비스"`
- `/ralplan --tier=HIGH "auth middleware 리팩터"` (or the `--deliberate` alias)
- `/ralplan --from-spec=.dt-handoff/foo/spec.md --interactive`
</Arguments>

<Steps>
Each step is declarative: **goal · delegate · input→output · gate**. Cross-cutting mechanics (the invariant, decorrelation, verdict routing, events logging) follow the single rules in `<Execution_Policy>` and `<Tool_Usage>` — not re-spelled per step.

### Phase 0 — Risk Triage & Depth Assignment (no dispatch)
1. Parse the task description + flags. If `--from-spec`, `Read` that file. Otherwise infer a kebab-case `slug` (≤ 40 chars). `mkdir -p .dt-handoff/<slug>/`; create `events.jsonl` if absent. If a `plan.md` already exists, ask (`AskUserQuestion`) whether to overwrite, append a new iteration section, or abort.
2. Classify the **risk tier** by a lightweight inline keyword scan (no agent dispatch): high-risk keywords (`<Advanced>`) → **HIGH** floor + `premortem=true`. Otherwise weigh design-choice / migration / boundary-shift signals → MEDIUM, else LOW. **Ambiguous → escalate** (false-HIGH > false-LOW). Apply `--tier=` / `--deliberate` override if present.
3. Derive `{tier → N, attack_lens count, premortem}` (LOW=1 / MEDIUM=2 / HIGH=3, cap 4). LOW+obvious proceeds on the N=1 lightweight path (no skip advisory; `plan.md` still required). **Gate**: `{tier, N, lenses, premortem}` + slug fixed; plan.md conflict resolved. Record tier + rationale for the plan `## Metadata`.

### Phase 1 — Candidate Generation (`architect ×N` fan-out)
4. **Dispatch `architect ×N` in a single parallel batch** (fire N Task calls in ONE message; N=1 → a single Task). Each carries `@handoff-in` referencing the spec/task, a distinct orthogonal **framing lens** (slot-fixed: `A=MVP-first / B=risk-first / C=alt-architecture / D=reuse-first`), and a "you do NOT see the other candidates" isolation instruction. (Model diversity: spread generation across tiers per `<Execution_Policy>` decorrelation when `model=` is available.)
   - **Intent**: each `architect` authors ONE candidate as an ADR fragment — Decision, Drivers (top 3), Principles (3–5), a single Chosen-sketch with bounded Pros/Cons self-statement, Acceptance Criteria draft (testable, file-anchored), Consequences.
   - **Gate**: N `@handoff-out` `status: complete` received (wait for ALL before Phase 2/3 — prose barrier; see `<Tool_Usage>`). **Distinctness labeling, NOT merging**: only when two candidates share the same Decision + same fileScope + same core verbs, label a `single-candidate collapse` and do NOT fabricate a filler candidate; if philosophies differ, keep them separate even if they touch the same files (no false-merge).

### Phase 2 — Independent Candidate Evaluation (MEDIUM/HIGH only)
5. **Dispatch `architect ×N` (a DIFFERENT Task from the generating architect)** to evaluate each candidate on its own merits (steelman refinement, not yet adversarial): design soundness, trade-off tension, boundary violations with file:line evidence. **HIGH adds `performance-analyst ×N`** (sonnet, 5 lenses: Hotpath/Complexity/IO/Memory/Cache). **LOW (N=1) skips this entire phase** (keeps the lightweight path lighter than the status quo).
   - **Gate**: each candidate gets an advisory steelman assessment that feeds the synthesizer's ranking. **Phase 2 does NOT eliminate candidates** — it only refines and annotates; every non-collapsed candidate proceeds to the Phase-3 adversarial attack, so no candidate is ever removed by a non-adversary (a same-role evaluator). A weak candidate is carried into `## Options Considered` with its assessment, never silently dropped before the critic sees it.

### Phase 3 — Decorrelated Adversarial Attack (`critic`, author ≠ attacker)
6. **Dispatch `critic` to attack each (non-collapsed) candidate**, each in a separate Task (Phase-2 assessment NEVER exempts a candidate from attack — the Chosen Approach MUST carry a Phase-3 `critic` verdict). Decorrelation protocol (per `<Execution_Policy>`): the critic attacking candidate *i* is (a) NOT the architect that authored *i*, (b) assigned an attack lens orthogonal to *i*'s generation framing, (c) on a different model tier than *i*'s author when available. Attack depth scales with tier: `LOW`/`MEDIUM` = 1 critic (skeptic lens); `HIGH` = multi-lens, **one separate `critic` Task per lens** (no in-context perspective cross-contamination) + a critic pre-mortem (5–7 failure scenarios per `critic`'s protocol).
   - **Intent**: prove why this candidate should NOT be adopted. Return a machine-readable `verdict` (handoff-protocol enum) + invalidation rationale per candidate.
   - **Gate**: a `verdict` for every candidate (wait for ALL before Phase 4). If every candidate is invalidated → regenerate once with a different lens combination (counts toward the cap), else finalize best-effort.

### Phase 4 — Synthesis & Ranking (`critic` sole verdict, separated from attackers)
7. **(--interactive only) Candidate review** before synthesis: `AskUserQuestion` showing the candidate sketches + their attack verdicts — [Proceed] / [Request changes] / [Pick one].
8. **Dispatch a synthesizing `critic` that is a DIFFERENT Task from every Phase-3 attacker** (+1 opus dispatch — eliminates within-agent consistency bias). It ranks survivors (viability + survival + Drivers fit + AC verifiability + blast radius), maps #1 → `## Chosen Approach` and the rest → `## Options Considered` (each with an Invalidation rationale = the critic attack that felled it). Cherry-picking across candidates (A's boundary + B's rollback) yields a NEW option → **mandatory re-attack once** (gated by the plan-diff rule in `<Execution_Policy>`, not self-report).
   - **Gate**: route on the synthesizer's machine `verdict` (never prose). `APPROVE`/`ACCEPT_WITH_RESERVATIONS` → Phase 5. `ITERATE`/`REVISE`/`REJECT` → re-attack survivors or generate one fresh candidate, then re-synthesize, within the tier-proportional cap.

### Phase 5 — Plan Assembly & pending-approval (no dispatch)
9. **Write the plan** to `.dt-handoff/<slug>/plan.md` using the Plan Structure below, opening with the descriptor frontmatter before the `# Plan:` heading. Serialize candidates → `## Options Considered`, attack verdicts → per-option Invalidation, ranking → `## Chosen Approach` + `## Agent Verdict Trail` (record per-candidate framing · generating architect · attacking critic · verdict · ranking rationale · `model-diversity` availability). HIGH → include `## Pre-mortem` + `## Test Plan`. Record `tier · N · candidates generated/surviving · model-diversity` in `## Metadata`. Put any ≥3-independent-workstream cue ONLY in Consequences/Follow-ups (never inferred from the count of rejected Options — protects autopilot's workstream heuristic).
10. **(--interactive only) Final approval**: `AskUserQuestion` — [Approve and proceed to ralph] / [Approve and proceed to team] / [Request changes → Phase 1] / [Reject — keep artifact, stop].
11. **Without --interactive**: write file, report path, STOP. Do NOT auto-invoke ralph/team/autopilot.

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
status: pending        # pending (awaiting approval) | approved (after user approval)
---
```
The legacy `Status: pending approval` line inside `## Metadata` remains for backward compatibility, mapped to descriptor `status: pending`. The 'best-effort consensus not reached' outcome keeps descriptor `status: pending` (still unapproved) and is expressed ONLY in the human-readable `## Metadata` `Status:` line — `best-effort` is NOT a descriptor `status` enum value (`scripts/validate.sh` `DESC_STATUS_ENUM`).

### Plan Structure (`.dt-handoff/<slug>/plan.md`)
```markdown
# Plan: <title>

## Metadata
- Slug: <slug>
- Generated: YYYY-MM-DD
- Risk tier: LOW | MEDIUM | HIGH (+ triage rationale; +auto-detected high-risk reason if applicable)
- Panel: N=<n> candidates generated, <k> surviving
- Model diversity: applied | unavailable, framing-only
- Iterations: N/<cap>
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
- ...

## Options Considered
### Option A: <name>  (framing: <lens>)
- Pros: ...
- Cons: ...
- Invalidation rationale (if not chosen): <the critic attack that felled it>

### Option B: <name>  (framing: <lens>)
- ...

## Chosen Approach
<which option (or synthesis) + why; reference principles + drivers>

## Consequences
- <what changes> / <what becomes harder> / <what becomes easier>
- (workstream cue, if ≥3 independent surfaces — recorded here only)

## Acceptance Criteria
- [ ] <testable criterion with file path or behavior reference>
- [ ] ...

## Pre-mortem (HIGH tier only)
### Scenario 1: <failure mode>
- Trigger / Detection / Mitigation

## Test Plan (HIGH tier only)
- Unit / Integration / E2E / Observability

## Follow-ups (out of scope)
- ...

## Agent Verdict Trail
| Candidate | Framing | Author (architect) | Attacker (critic) | Verdict | Rank / Notes |
|-----------|---------|--------------------|-------------------|---------|--------------|
| A         | MVP-first | architect#1 (opus) | critic#a (opus, risk lens) | REJECT | 2 / ... |
| B         | risk-first | architect#2 (sonnet) | critic#b (opus, MVP lens) | APPROVE | 1 / chosen |
- Synthesizer: critic#s (separate Task) · model-diversity: applied
```
</Steps>

<Tool_Usage>
- **Read**: load `.dt-handoff/<slug>/spec.md` (`--from-spec`); read sibling code only when AC need file:line anchors.
- **Write**: emit `.dt-handoff/<slug>/plan.md` and append `events.jsonl`. These are the ONLY mutations this skill makes.
- **Bash**: `mkdir -p .dt-handoff/<slug>/` only. No other mutating Bash.
- **Task** (bare agent names — no plugin prefix):
  - Phase 1: `architect ×N` candidate generation in ONE parallel batch (NOT `planner` — `planner` refuses design judgment; `architect` is the multi-option author).
  - Phase 2 (MEDIUM/HIGH): `architect ×N` evaluation (a different Task from the generators) + `performance-analyst ×N` on HIGH.
  - Phase 3: `critic` per (non-collapsed) candidate (one Task per candidate; HIGH = one Task per attack lens), each a different Task from that candidate's author.
  - Phase 4: a synthesizing `critic` that is a different Task from every Phase-3 attacker.
  - Do NOT delegate to `executor`/`ralph`/`team`/`autopilot`.
- **Orchestration**: the 1st-class mechanism is **Task parallel fan-out** (portable to every invocation context, including `autopilot`'s sub-call). The per-phase barrier ("wait for all N `@handoff-out` before the next phase") is a **prose convention, advisory** — not harness-enforced (honestly acknowledged; same status as the prior skill's "STRICTLY sequential" prose). Where the `Workflow` tool is available and opted into, it MAY accelerate the fan-out with `parallel()`/`pipeline()` barriers, schema-validated candidate output, and `loop`-capped re-attack; the behavioral meaning is identical, only the determinism is stronger (do not advertise "fully equivalent").
- **AskUserQuestion**: only when `--interactive` (candidate review + final approval), or Phase 0 plan.md-conflict resolution.
- **Handoff contract** (single rule): when dispatching an agent that consumes a persisted artifact, include an `@handoff-in` block (`kind`, `path`, `contentHash`, `sizeBytes`; inline the body only when `sizeBytes ≤ INLINE_MAX_BYTES`). Consume the returning `@handoff-out` and route on its `verdict`. Block shapes, descriptor schema, `verdict` enum, and `INLINE_MAX_BYTES` are defined in handoff-protocol §6/§7/§8 — mirrored in the `scripts/validate.sh` header.
- **events.jsonl** (single rule): one JSON object per line, append-only at `.dt-handoff/<slug>/events.jsonl` (`kind: trace`, `retention: session`), per handoff-protocol §9 — appended before each Task dispatch and immediately after parsing each `@handoff-out`. It is an audit trace ONLY; it is NEVER read back as a gating input. The invariant is enforced by dispatch topology, not by reading events.
</Tool_Usage>

<Examples>
**Example 1 — LOW tier (trivial), N=1**:
User: "/ralplan 'add a null guard to formatUser()'"
Flow: Phase 0 → no high-risk keyword, single obvious surface → LOW, N=1 (no skip advisory). Phase 1: 1 `architect` candidate. Phase 2 skipped. Phase 3: 1 separated `critic` attack (skeptic lens). Phase 4: synthesizing `critic` (separate Task) → `verdict: APPROVE`. Phase 5: write `.dt-handoff/null-guard-formatuser/plan.md` (`Status: pending approval`) → STOP. Dispatch tally: architect 1 (generate) + critic 1 (attack) + critic 1 (synthesize — separate Task, never skipped) = 3. plan.md still produced (autopilot precondition).

**Example 2 — MEDIUM tier, N=2**:
User: "/ralplan 'paginated list endpoint for saved filters'"
Flow: MEDIUM, N=2. Phase 1: `architect ×2` (MVP-first, risk-first), mutually blind. Phase 2: `architect ×2` evaluation. Phase 3: `critic ×2`, each attacking the *other* candidate's framing (risk lens on the MVP candidate, MVP/cost lens on the risk candidate), author≠attacker. Phase 4: separate synthesizer `critic` ranks → Option B chosen, Option A retained with invalidation rationale → `verdict: APPROVE` on iteration 1. Write plan.md → STOP.

**Example 3 — HIGH tier (auto-detected), N=3 + pre-mortem**:
User: "/ralplan 'auth middleware 리팩터'"
Flow: high-risk keyword (auth) → HIGH floor + premortem. N=3 (MVP/risk/alt-architecture). Phase 2: `architect ×3` + `performance-analyst ×3`. Phase 3: multi-lens attack — per candidate, one `critic` Task per lens (skeptic/ops/security) + critic pre-mortem. Phase 4: separate synthesizer `critic` → `verdict: ITERATE` → regenerate/​re-attack → `verdict: APPROVE`. Phase 5: write plan.md with `## Pre-mortem` + `## Test Plan`, Metadata `Risk tier: HIGH`, Verdict Trail with model-diversity. STOP. (`--deliberate` reaches the same path as an alias for `--tier=HIGH`.)

**Example 4 — single-candidate collapse (honest signal)**:
User: "/ralplan 'rename config key X to Y everywhere'"
Flow: MEDIUM N=2, but both candidates converge to the same Decision + fileScope + verbs → Phase 1 labels a `single-candidate collapse` (no filler 2nd candidate fabricated). The single candidate still gets a separated `critic` attack (invariant holds regardless of N). Options Considered notes "Alt collapsed — same core decision". Write plan.md.

**Example 5 — consensus not reached**:
User: "/ralplan 'redesign storage layer'"
Flow: HIGH, N=3. Every candidate invalidated → regenerate once (different lenses, counts toward cap=4). Still non-finalizing at cap → write plan with `Status: best-effort consensus not reached` + unresolved concerns from the final critic `@handoff-out` → STOP.
</Examples>

<Final_Checklist>
- Phase 0 triage set `{tier, N, lenses, premortem}`, escalated on ambiguity (false-HIGH > false-LOW), and recorded the rationale in `## Metadata`? (`--tier=`/`--deliberate` override honored.)
- Candidates generated by `architect ×N` (NOT `planner`), in ONE parallel Task batch (N=1 → single Task), each with an orthogonal framing lens + isolation instruction?
- Adversarial attack dispatched as `critic` in a Task separate from each candidate's author (author ≠ attacker by dispatch topology), with an attack lens orthogonal to that candidate's framing?
- Synthesizer `critic` a DIFFERENT Task from every Phase-3 attacker (within-agent bias eliminated)?
- Model diversity applied by default when `model=` available (attack critic=opus, generation tier-spread, attacker model ≠ author model); else framing-only + recorded in Verdict Trail?
- Adversarial attack NEVER skipped — present even at N=1?
- Mandatory re-attack gated by plan diff (Decision/Drivers/Options touched → re-attack), NOT planner self-report?
- Routed on the synthesizer's machine `verdict` (never prose), within the tier-proportional cap (LOW=1/MEDIUM=2/HIGH=3, all-invalidated HIGH +1)?
- `events.jsonl` appended per dispatch/return but NEVER read back as a gating input (invariant enforced by topology)?
- Distinctness handled by labeling only (no false-merge); single-candidate collapse is an honest signal, no filler fabricated?
- `plan.md` ALWAYS written (no self-skip) at `.dt-handoff/<slug>/plan.md`, with descriptor frontmatter (all required `DESC_*` fields), `Status: pending approval`?
- Candidates → Options Considered, attacks → Invalidation, ranking → Chosen Approach + Agent Verdict Trail; existing ADR schema unchanged; new Metadata fields additive; ≥3-workstream cue only in Consequences/Follow-ups?
- Chosen AC testable + file-anchored (ralph `prd.json` 1:1 scaffold contract preserved)?
- No mode-gate / Critic-input-set / model-routing / Dispatch Ledger anywhere; cost expressed only as N · attack-lens count · model tier?
- Avoided invoking `executor` / `ralph` / `team` / `autopilot`?
- `--interactive`: prompted at candidate review + final approval. Non-interactive: stopped without prompting after writing.
- Section headers English, content in `$LANGUAGE`?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
- User says "stop" / "cancel" / "abort": stop immediately; do not write the plan.
- Cap reached without a finalizing verdict: write the best version with `Status: best-effort consensus not reached`, report unresolved concerns from the final critic `@handoff-out`.
- All candidates invalidated: regenerate once with a different lens combination (counts toward the cap); if still all-invalidated, finalize best-effort.
- `architect` / `performance-analyst` errors or is unavailable: retry once; if still failing, proceed with the surviving dispatches and note "one pass did not run" in the plan.
- **`critic` (adversarial attacker or synthesizer) errors or is unavailable**: the invariant takes precedence over progress. Retry once (escalate model tier if needed). If the chosen/surviving candidate still cannot be adversarially attacked, do NOT finalize as `pending approval` — write `Status: best-effort consensus not reached` with an explicit `adversarial-attack: NOT RUN` note in the Verdict Trail. NEVER emit a `pending approval` plan whose Chosen Approach lacks a Phase-3 attack.
- `--from-spec` path does not exist: ask the user to provide it (`AskUserQuestion`); do not proceed.
</Escalation_And_Stop_Conditions>

<Advanced>
## High-risk keyword set (forces HIGH tier floor + pre-mortem)
- auth, authn, authz, oauth, jwt, session
- migration, schema change, alter table, data backfill
- destructive (delete, drop, truncate, rm -rf, force)
- concurrency, race, lock, transaction, idempotency, consistency (동시성, 경합, 잠금, 트랜잭션, 정합성, 멱등)
- production incident, hotfix
- compliance, PII, PHI, GDPR, SOC2
- public API break, breaking change

## Framing lens palette (generation) & orthogonal attack lens (default mapping)
| Slot | Generation framing | Orthogonal attack lens |
|------|--------------------|------------------------|
| A | MVP-first (minimal surface, shortest path) | risk / ops (failure modes, rollback, operability) |
| B | risk-first (failure modes, rollback, invariants) | MVP / cost-efficiency (over-engineering, YAGNI) |
| C | alt-architecture (boundary / coupling re-placement) | simplicity / migration cost |
| D | reuse-first (reuse existing patterns) | fit / coupling (does the reuse actually fit?) |
The orchestrator assigns generation slots by N (A,B,C,D in order) and the attack lens from the orthogonal complement — the attacking agent never self-selects its lens. For domain-specific tasks, a slot may be specialized (e.g. B → consistency-first for a data-integrity task).

## Tier → depth (single source)
| Tier | N | Phase 2 eval | Attack depth | Pre-mortem | Iteration cap |
|------|---|--------------|--------------|------------|---------------|
| LOW | 1 | skipped | 1 critic, 1 lens | no | 1 |
| MEDIUM | 2 | architect ×N | 1 critic, skeptic lens | no | 2 |
| HIGH | 3 (cap 4) | architect ×N + perf ×N | multi-lens, 1 critic/lens + critic pre-mortem | yes | 3 (all-invalidated → 4) |

> HIGH can fan out to ~11–14 dispatches (N candidates × generation + evaluation + perf + multi-lens attack + pre-mortem + 1 separate synthesizer); the cap (4) + wave-splitting bound it. Inside `autopilot`, expect this per high-risk planning sub-step. Cost knobs to dial down: lower `--tier`, fewer attack lenses, or model tier.

## ADR-Plan cross-reference
The `plan.md` ADR is consumed by `ralph` (reads `## Acceptance Criteria` into `prd.json` stories 1:1 — keep AC testable + file-anchored), `team` (reads decomposition cues from Consequences + Follow-ups), and `autopilot` (gates on `Status: pending approval` and routes ralph/team from plan.md workstreams). If a consumer needs extra fields (dependency graph, parallelization hints), surface them as Follow-ups rather than embedding them in the chosen option. A ≥3-independent-workstream cue is recorded ONLY in Consequences/Follow-ups (never inferred from the count of rejected Options), so autopilot's workstream heuristic does not misread N rejected alternatives as N parallel workstreams. Verdict routing is single-sourced in `<Execution_Policy>`; the enum is `scripts/validate.sh` `DESC_VERDICT_ENUM` (machine truth).
</Advanced>
