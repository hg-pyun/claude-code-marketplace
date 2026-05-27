---
name: autopilot
description: End-to-end 5-phase pipeline from idea to code-ready state — deep-interview → ralplan → ralph/team → verifier-gated QA → multi-perspective validation. Artifacts land in .dt-handoff/<slug>/. Auto commit/PR PROHIBITED. TRIGGER on "/autopilot", "autopilot", "build me", "create me", "make me", "I want a/an". DO NOT TRIGGER for brainstorming, single bug fixes, or quick changes.
---

<Purpose>
Take a product idea from one-sentence intent to a code-ready state through five sequential phases: a vetted spec, an approved plan, an implemented change set, a verifier-gated test suite, and a multi-perspective validation pass — in a single skill invocation.

Autopilot does NOT do the work itself. It is a **conductor**: it sequences sibling skills (`deep-interview`, `ralplan`, `ralph` or `team`) and agent passes (`test-engineer`, `executor`, `verifier`, plus the Phase 5 panel), reads each phase's artifact, gates on the next phase's success criterion, and stops at "ready for commit". Commit and PR creation remain the user's call.
</Purpose>

<Use_When>
- User invokes "/autopilot", says "autopilot", "build me X", "create me X", "make me X", "I want a/an X".
- The task is large enough to need full lifecycle management (spec + plan + impl + test + validate).
- The user wants hands-off execution: describe WHAT, not HOW.
- An existing `.dt-handoff/<slug>/spec.md` or `plan.md` is present and the user wants to resume.
</Use_When>

<Do_Not_Use_When>
- The user wants to brainstorm only — answer directly.
- The user wants a single bug fix or a quick edit — delegate to `executor`, or work directly.
- The user wants only requirements capture — use `deep-interview`.
- The user wants planning without execution — use `ralplan`.
- The user wants automatic commit/PR — refuse; autopilot stops at "ready for commit".
- The user has not specified scope at all ("just improve everything") — route to `deep-interview` first to establish a target.
</Do_Not_Use_When>

<Why_This_Exists>
Most "build me X" tasks fail not because any single phase was hard, but because phase boundaries leak: requirements drift during planning, plans drift during execution, tests get skipped when execution gets noisy, and validation collapses to "looks fine to me." A conductor that owns the boundaries — reading the previous phase's artifact and refusing to advance until each phase's success criterion is met — closes those leaks.

The five phases mirror how a careful team works: discover, decide, implement, test, validate. Each is a named step with a checkable artifact. Resumption is the common case, so an existing spec/plan short-circuits the early phases.

Two anti-patterns are designed out: (1) **self-approval** — the `verifier` agent, not the executor that greened a test, judges whether tests actually pass, on fresh evidence; (2) **prose-keyword routing** — judgment agents return a machine-readable `verdict` the conductor routes on deterministically.

The conductor stays thin on purpose. The handoff mechanics (`@handoff-in`/`@handoff-out`, descriptors, `events.jsonl`) are defined once in the handoff protocol; this skill *references* them rather than re-spelling them per phase.
</Why_This_Exists>

<Execution_Policy>
**Output language**: phase status reports and the final summary use `$LANGUAGE`. Section headers stay English. Artifact contents follow each sub-skill's own language rules.

**Phase sequencing**: phases run STRICTLY sequentially. Never start Phase N+1 until Phase N reports success. Never parallelize phases (the one intra-phase parallel pass is the Phase 5 panel).

**Resume / skip** (default `--resume=auto`):
- `spec.md` present → skip Phase 1.
- `plan.md` present with Status `pending approval` or `approved` → skip Phases 1–2.
- `prd.json` present with progress → offer resume vs restart.
- Confirm the detected resumption point with one `AskUserQuestion` (suppressed by `--no-prompt`). `--resume=fresh` ignores existing artifacts and restarts at Phase 1.

**Validation model (Phase 5)** — gates decide, advisors annotate:
- **Gates** (a failing gate sends the work back to Phase 3): `reviewer` (`verdict` REVISE/REJECT), `security-auditor` (CRITICAL @ HIGH confidence), `architect` (CRITICAL @ HIGH confidence). With `--full-validation`, `critic` (`verdict` REJECT) joins the gates.
- **Advisors** (recorded in `autopilot-validation.md`, never block): `performance-analyst` and `doc-writer` findings, and `critic` ACCEPT_WITH_RESERVATIONS. Advisors run only under `--full-validation`.
- Max 2 Phase 5 → Phase 3 re-entries; on the third failure stop `PHASE5_REJECTED`.

**Verdict routing**: route on the machine-readable `verdict` field of judgment agents (`reviewer`, `critic`, `verifier`) and on severity+confidence for advisory agents (`architect`, `security-auditor`, `performance-analyst`, `doc-writer`). Never route on prose keyword matching. The `verdict` enum and `@handoff-out` shape are defined in the handoff protocol (see `<Tool_Usage>`).

**Execution path (Phase 3)**: default `ralph` (sequential). Use `team` when `plan.md` identifies ≥ 3 independent workstreams with no shared file scope. `--exec=ralph|team` forces the choice. Announce the choice and rationale.

**events.jsonl** (phase-boundary logging): append one JSON line to `.dt-handoff/<slug>/events.jsonl` at each phase boundary only — `phase_start`, `phase_complete`, `phase_fail`, `phase_retry`. Per-agent dispatch/return tracing is NOT logged here (that granularity lives in `team`'s wave scheduler). `kind: trace`, `retention: session`. Format per handoff protocol §9.

**Cleanup is an invariant**: every terminal path — success or any escalation stop — ends by running the Wrap-up cleanup (see Steps). `retention: permanent` artifacts (spec.md, plan.md, prd.json) are always preserved.

**Auto commit/PR PROHIBITED**: never invoke `git-commit`, `github-pr`, `gh pr`, `git commit`, or `git push`. Same rule as `ralph` / `team`.
</Execution_Policy>

<Settings_Reference>
| Flag | Default | Effect |
|------|---------|--------|
| `--lang=<value>` | `plugin.json` `settings.language` (`Korean`) | Output language for reports/summary. |
| `--resume=auto\|fresh` | `auto` | `auto` skips completed phases from existing artifacts; `fresh` restarts at Phase 1. |
| `--no-prompt` | off | Suppress the Phase 0 resume-confirmation `AskUserQuestion` (silent auto-skip). |
| `--exec=ralph\|team` | auto-detect | Force the Phase 3 execution skill. |
| `--threshold=<0.0–1.0>` | deep-interview default (0.2) | Forwarded to Phase 1 ambiguity gate. |
| `--deliberate` | off | Forwarded to Phase 2 `ralplan`. |
| `--max-qa-cycles=<n>` | 5 | Cap Phase 4 iterations. |
| `--full-validation` | off | Add the Phase 5 opt-in advisors (`critic`, `performance-analyst`, `doc-writer`). |
</Settings_Reference>

<Arguments>
Idea description plus any flags above. Examples:
- `/autopilot "Linear webhook 처리 서비스 만들어줘"`
- `/autopilot --exec=team "auth middleware 리팩터"`
- `/autopilot --deliberate --full-validation "결제 검증 모듈 추가"`
</Arguments>

<Steps>
Each phase is declarative: **goal · delegate · input→output · success / fail**. The cross-cutting mechanics (handoff blocks, verdict routing, events logging) follow the single rules in `<Execution_Policy>` and `<Tool_Usage>` — they are not re-spelled per phase.

### Setup (pre-pipeline)
- Parse the idea + flags. Infer a kebab-case `slug` (≤ 40 chars).
- `mkdir -p .dt-handoff/<slug>/artifacts/ask .dt-handoff/<slug>/state`; create `events.jsonl` if absent and append `phase_start`.
- Probe resume artifacts (spec.md / plan.md / prd.json) and confirm the resumption point per the resume/skip rule (unless `--no-prompt`).
- Announce the pipeline in `$LANGUAGE`, marking each phase RUN or SKIPPED.

### Phase 1 — Expansion (`deep-interview`)
- **Goal**: turn the idea into a vetted spec.
- **Delegate**: `Skill("dev-tools:deep-interview", args="<idea> --threshold=<value>")`.
- **Output**: `.dt-handoff/<slug>/spec.md`.
- **Success**: `Status: PASSED`. **Fail**: `EARLY_EXIT` / `HARD_CAP` with high residual ambiguity → ask the user to retry, lower threshold, or abort (`PHASE1_AMBIGUOUS`).
- Skip if `spec.md` already present (resume rule).

### Phase 2 — Planning (`ralplan`)
- **Goal**: derive an approved implementation plan from the spec.
- **Delegate**: `Skill("dev-tools:ralplan", args="--from-spec=.dt-handoff/<slug>/spec.md {--deliberate}")`.
- **Input → Output**: `spec.md` → `.dt-handoff/<slug>/plan.md`.
- **Success**: Status `pending approval`. **Fail**: consensus not reached after 5 iterations → ask accept-best-effort vs restart (`PHASE2_NO_CONSENSUS`).
- Skip if `plan.md` already present (resume rule).

### Phase 3 — Execution (`ralph` | `team`)
- **Goal**: implement the plan to a green, reviewed state.
- **Choose path**: `--exec` if set; else `team` when `plan.md` shows ≥ 3 independent workstreams with no shared files, else `ralph`. Announce the choice + rationale.
- **Delegate**: `Skill("dev-tools:ralph", args="--from-plan=.dt-handoff/<slug>/plan.md")` or the same with `dev-tools:team`.
- **Input → Output**: `plan.md` → `.dt-handoff/<slug>/prd.json` + code changes (+ `progress.txt` / `team-final.md`).
- **Success**: all stories `passes: true`, reviewer `verdict: APPROVE`, post-cleanup regression GREEN. **Fail**: sub-skill escalates or hits cap → stop `PHASE3_BLOCKED` (do not advance).

### Phase 4 — QA (`test-engineer` + `executor` + `verifier`, max `--max-qa-cycles`)
- **Goal**: harden the test suite and confirm clean regression on fresh evidence.
- **Loop** (default 5 cycles):
  1. `test-engineer` audits the changed files (from `prd.json` evidence) for coverage gaps (HIGH/MEDIUM/LOW), flaky tests, pyramid imbalance; authors failing tests for HIGH/MEDIUM gaps and confirms Red.
  2. If new Red tests exist, `executor` makes them green with minimal diff.
  3. `verifier` runs the full BUILD/TEST/LINT/FUNCTIONALITY/TODO/ERROR_FREE protocol and writes findings to `artifacts/ask/verifier-qa-<ISO8601>.md`.
- **Route on `verifier` `verdict`**: `APPROVE` → exit Phase 4. `REVISE` → loop with the failing checks as input. `REJECT` → stop `PHASE4_QA_STUCK`.
- **Fail**: same failing checks persist 3 cycles → stop `PHASE4_QA_STUCK`.

### Phase 5 — Validation (gates + opt-in advisors)
- **Goal**: multi-perspective sign-off on final code.
- **Fire the panel in parallel** (single message, multiple Task calls). Default: the three gates. With `--full-validation`: add the three advisors.
  - Gates: `reviewer` (spec-compliance + severity-rated diff, returns `verdict`), `security-auditor` (AuthN/AuthZ/Secret/Crypto/Injection/SAST/Config), `architect` (SOLID, scalability, integration risk).
  - Advisors (`--full-validation`): `critic` (steelman the case against; returns `verdict`), `performance-analyst` (Hotpath/Complexity/IO/Memory/Cache), `doc-writer` (Missing/Outdated/Inconsistent/Unclear — read-only this invocation).
- Each agent persists findings to `artifacts/ask/<agent>-<ISO8601>.md` and returns an `@handoff-out` block (see `<Tool_Usage>` for the shared directive). Optionally dispatch `verifier` for a final end-to-end check after the panel returns; a `verifier` `verdict` of `REVISE`/`REJECT` counts as a gate failure (Phase 3 re-entry).
- **Combine** per the validation model in `<Execution_Policy>`: any gate failure → return to Phase 3 with the findings (max 2 re-entries, append `phase_retry`); advisors → record only. On clean gates → write `.dt-handoff/<slug>/autopilot-validation.md` consolidating every perspective.

### Wrap-up (post-pipeline)
- Append `phase_complete` to `events.jsonl`.
- Compose the final report in `$LANGUAGE`: phases run/skipped/failed, artifacts with paths, stories total/completed, tests added in QA, combined validation verdict, final regression status.
- **Next steps**: suggest `/git-commit` then `/github-pr` — do NOT invoke them.
- Run cleanup (invariant, every terminal path): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.sh" --slug=<slug>` — removes `retention: session` artifacts, preserves `permanent` ones.
- STOP. No git mutations.
</Steps>

<Tool_Usage>
- **Skill**: `dev-tools:deep-interview` (P1), `dev-tools:ralplan` (P2), `dev-tools:ralph` or `dev-tools:team` (P3). One sub-skill per phase, sequential.
- **Task**: `test-engineer` + `executor` + `verifier` (P4 loop); the Phase 5 panel in parallel (one message). Bare agent names — no plugin prefix.
- **Read**: load `.dt-handoff/<slug>/*.md` and `prd.json` between phases.
- **Write**: `autopilot-validation.md` (P5 consolidation), `events.jsonl` phase-boundary lines, `progress.txt` append.
- **Bash**: `mkdir -p` the artifact root at Setup; run test/build/lint for inter-phase checks; `cleanup.sh --slug=<slug>` at Wrap-up.
- **AskUserQuestion**: confirm the resume point at Setup; ask about retries at a phase-failure decision point.
- **Handoff contract** (single rule — do not re-spell per phase): when dispatching an agent that consumes a persisted artifact, include a `@handoff-in` reference (`kind`, `path`, and `contentHash`/`sizeBytes` per the protocol; inline the body only when `sizeBytes ≤ INLINE_MAX_BYTES`). Consume the returning `@handoff-out` block and route on its `verdict`. The `@handoff-in`/`@handoff-out` shapes, descriptor schema, `verdict` enum, and `INLINE_MAX_BYTES` are defined in the handoff protocol — mirrored in the `scripts/validate.sh` header. Phase 5 panel agents share this directive: "persist findings to `artifacts/ask/<agent>-<ISO8601>.md` with the descriptor frontmatter, then return an `@handoff-out` block; judgment agents set `verdict`, advisory agents set `verdict: null`; doc-writer's findings file is its only Write this invocation."
- Do NOT invoke `git-commit`, `github-pr`, or `linear-tools:enrich-ticket` from inside autopilot.
</Tool_Usage>

<Examples>
**Example 1 — fresh start, full pipeline**:
User: `/autopilot "Linear webhook 처리 서비스 만들어줘"`
Setup: no artifacts → create `.dt-handoff/linear-webhook/`, announce. Phase 1: deep-interview → `spec.md` (PASSED). Phase 2: ralplan → `plan.md` (pending approval); 4 ACs with shared file scope → `ralph`. Phase 3: ralph → 4 stories pass, reviewer APPROVE, regression GREEN. Phase 4: test-engineer finds 2 HIGH gaps → executor greens → verifier `APPROVE`, exit cycle 1. Phase 5 (default gates): reviewer APPROVE, security-auditor clean, architect clean → write `autopilot-validation.md`. Wrap-up: cleanup, "Ready for commit — /git-commit then /github-pr." STOP.

**Example 2 — resume from existing plan**:
User: `/autopilot "auth middleware 리팩터"` → Setup detects yesterday's `plan.md`; AskUserQuestion → "Resume". Phases 1–2 SKIPPED. Phase 3 runs `ralph` from the plan. Phases 4–5 run. Report notes "Phases 1–2 skipped (plan.md from 2026-05-21 reused)."

**Example 3 — phase failure**:
Phase 3 `ralph` hits 3-fail escalation on US-002 → append `phase_fail`, run Wrap-up cleanup, stop `PHASE3_BLOCKED`. Report names the blocking story and the unresolved error. Phases 4–5 not attempted.

**Example 4 — Phase 5 gate re-entry**:
`--full-validation`: critic returns `verdict: REJECT` ("a simpler key-value store would serve the same need"). Append `phase_retry`, return to Phase 3 to evaluate the simpler approach. Re-run Phase 4 (verifier `APPROVE`) and Phase 5 — reviewer + critic both `APPROVE`. Retries: 1/2.

**Example 5 — Phase 4 verifier REVISE**:
Cycle 1: 2 Red tests authored → executor greens → verifier `REVISE` (1 assertion still red in auth.test.ts:88). Loop: executor again with the failing check → verifier `APPROVE`. Phase 4 exits cycle 2.
</Examples>

<Final_Checklist>
- Did Setup create `.dt-handoff/<slug>/`, init `events.jsonl`, probe resume, and announce the pipeline?
- Did phases run STRICTLY sequentially, advancing only on each phase's success criterion?
- Did I append `events.jsonl` at phase boundaries only (not per agent)?
- Phase 3: did I auto-select ralph vs team from plan.md parallelism (unless `--exec`)?
- Phase 4: did `test-engineer` author Red tests, `executor` green them, and `verifier` return `verdict: APPROVE` before exiting? Did it stop on 3 same-error cycles?
- Phase 5: did the gates (reviewer + security-auditor + architect, plus critic under `--full-validation`) fire in parallel, and did I route on `verdict` / severity — never prose?
- Did a gate failure (not an advisory finding) trigger Phase 3 re-entry, capped at 2?
- Did I write `autopilot-validation.md` consolidating all fired perspectives?
- Did Wrap-up cleanup run on every terminal path (success and failure)?
- Did the final report list phase statuses and suggest `/git-commit` + `/github-pr` without invoking them?
- Did I refrain from all git/gh mutations?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
Single source for terminal statuses. Every terminal path runs Wrap-up cleanup (`cleanup.sh --slug=<slug>`) before exiting.
- All phases complete + Phase 5 gates clean + regression GREEN → report and stop.
- `PHASE1_AMBIGUOUS` — deep-interview hits hard cap without reaching threshold.
- `PHASE2_NO_CONSENSUS` — ralplan consensus not reached after 5 iterations.
- `PHASE3_BLOCKED` — ralph/team escalates or hits cap; do not advance to Phase 4.
- `PHASE4_QA_STUCK` — verifier `REJECT`, or same failing checks persist 3 cycles.
- `PHASE5_REJECTED` — a gate keeps failing after 2 Phase 3 re-entries; surface the unresolved findings.
- User says "stop" / "cancel" → stop immediately, record the phase reached in `progress.txt`, run cleanup.
</Escalation_And_Stop_Conditions>

<Advanced>
## Phase Artifact Matrix
| Phase | Sub-skill / Agent | Input | Output | Skip / Exit |
|-------|-------------------|-------|--------|-------------|
| 1 Expansion | `deep-interview` | idea | `spec.md` | spec.md present |
| 2 Planning | `ralplan` | spec.md | `plan.md` | plan.md Status valid |
| 3 Execution | `ralph` \| `team` | plan.md | `prd.json` + code | all-pass + reviewer APPROVE |
| 4 QA | `test-engineer` + `executor` + `verifier` | code + prd.json | new tests + `verifier-qa-*.md` | verifier `APPROVE` |
| 5 Validation | gates: `reviewer`+`security-auditor`+`architect` (opt-in: `critic`+`performance-analyst`+`doc-writer`) | code | `autopilot-validation.md` + per-agent findings | gates clean |

## Phase 5 parallelism note
Phase 5 is the one intra-phase parallel pass in this skill. It is safe because the artifact is final code (not a moving target) and every panel agent is read-only at calling time (doc-writer is gated to read-only by the shared directive). This is NOT a license to parallelize advisor passes elsewhere.

## Resume detail
`--resume=auto` (default) detects the furthest valid artifact and proposes that resumption point; `--no-prompt` applies the highest-fit shortcut silently. `--resume=fresh` ignores existing artifacts and restarts at Phase 1.
</Advanced>
