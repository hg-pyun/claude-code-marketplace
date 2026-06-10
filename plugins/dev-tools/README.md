# dev-tools

> Multi-agent dev toolkit for Claude Code.

One plugin bundling 16 specialist **agents** (4 lanes), a full-lifecycle **orchestration pipeline**, and everyday **git / GitHub** helpers — install once, get the whole toolkit.

---

## Contents

- [Install](#install)
- [At-a-glance](#at-a-glance)
- [Orchestration lifecycle](#orchestration-lifecycle)
- [Agents](#agents)
- [Skills & commands](#skills--commands)
- [`.dt-handoff/<slug>/` artifact layout](#dt-handoffslug-artifact-layout)
- [Settings & language](#settings--language)
- [Behavior guarantees](#behavior-guarantees)
- [MCP requirements](#mcp-requirements)
- [License](#license)

---

## Install

```shell
/plugin marketplace add hg-pyun/claude-code-marketplace
/plugin install dev-tools@hg-pyun-plugins
```

Within `dev-tools` there is no `core` sub-plugin and no cross-plugin invocation prefix — every skill, command, and agent lives inside this plugin and is addressed by its bare name.

---

## At-a-glance

| Entrypoint | Type | One-liner |
|------------|------|-----------|
| `/autopilot` | skill | End-to-end pipeline: interview → plan → execute → QA → validate. |
| `/deep-interview` | skill | Socratic interview with ambiguity scoring. Writes `spec.md`. |
| `/interview` | skill | Lightweight in-depth interview (no scoring/agents). Writes `spec.md`. |
| `/ralplan` | skill | Candidate-panel consensus: `architect`×N generate distinct approaches, a separated `critic` attacks each, a distinct `critic` synthesizes a ranked ADR. Writes `plan.md`. |
| `/ralph` | skill | PRD-driven execution loop with TDD discipline; independent stories run as pipelined waves. |
| `/team` | skill | 5-stage parallel multi-agent orchestration. |
| `/code-review` | skill | Multi-domain severity-rated review (`reviewer` always; `security-auditor` / `doc-writer` join when the diff touches their surface). |
| `/git-commit` | skill | Conventional-commit message + commit, in `$LANGUAGE`. |
| `/github-pr` | skill | Conventional-commit-style PR title + body, in `$LANGUAGE`. |
| `/git-rebase-stack` | command | Stacked-PR rebase via `git rebase --onto … --update-refs`. |
| `/curl-debug` | skill | Run a cURL, reverse-trace failures to source. |
| `/install-statusline` | skill | Install the canonical ccstatusline status line (binary + settings + widget layout). |

Korean trigger phrases (e.g. `"커밋해줘"`, `"PR 만들어줘"`, `"끝까지 가줘"`) work in addition to the slash commands; see each skill's frontmatter for the full list.

---

## Orchestration lifecycle

The four orchestration skills form a single, resumable lifecycle:

```
Phase 1  Expansion    deep-interview   → spec.md
Phase 2  Planning      ralplan          → plan.md  (Status: pending approval)
Phase 3  Execution     ralph | team     → prd.json + code + progress
Phase 4  QA gate       test-engineer + executor + verifier   (≤ 5 cycles)
Phase 5  Validation    reviewer + security-auditor + architect   (default gates)
                       └─ --full-validation adds critic + performance-analyst + doc-writer
```

`/autopilot` is the conductor that sequences all five phases in one invocation and, under `--resume=auto` (default), auto-skips phases whose artifacts already exist on disk — resuming yesterday's interview takes one command.

**Hard stop at "ready for commit".** Every orchestration skill — `ralph`, `team`, `autopilot` — refuses to commit, push, or open a PR. Those moves are explicit user gestures via `/git-commit` and `/github-pr`. The pipeline puts the change on disk and tells you it's done; you decide what ships.

When to pick what:

| Situation | Skill |
|-----------|-------|
| "I have an idea, take it to ready-for-review" | `/autopilot` |
| "Capture requirements — heavy, ambiguity-gated" | `/deep-interview` |
| "Capture requirements — fast, conversational" | `/interview` |
| "I have a spec, give me a vetted plan" | `/ralplan` |
| "Execute this plan, one story at a time, TDD-strict" | `/ralph` |
| "Execute this plan with parallel workstreams" | `/team` |
| "Just review what I have" | `/code-review` |

---

## Agents

Sixteen specialist agents organized in four lanes. Read-only advisors carry `disallowedTools: Write, Edit`; write-capable agents have no such constraint. Three agents return a machine-readable `verdict` field (`APPROVE` / `ACCEPT_WITH_RESERVATIONS` / `ITERATE` / `REVISE` / `REJECT`) in their `@handoff-out` block: `reviewer`, `critic`, and `verifier`.

Model column: `inherit (session)` means no `model` pin in the agent frontmatter — the agent runs on the calling session's model, so judgment-heavy agents always track the best model the user has chosen. Explicit pins (`sonnet`, `haiku`) are deliberate cost downgrades for mechanical or high-volume roles.

### Build / Analysis lane

| Agent | Model | Writes? | Role |
|-------|-------|---------|------|
| `explorer` | haiku | no | Fast file/symbol/pattern lookup with absolute paths and excerpts. |
| `analyst` | inherit (session) | no | Requirement decomposition, hidden-constraint surfacing, and ambiguity scoring. |
| `planner` | inherit (session) | no | Turns a spec or PRD into a sequenced, dependency-aware execution plan (story breakdown + DAG + acceptance criteria). |
| `architect` | inherit (session) | no | System design and trade-off advisor; evaluates interface contracts and recommends structural changes with file:line evidence. Not for bug diagnosis or verification. |
| `debugger` | sonnet | no | Root-cause analysis advisor; diagnoses build/test/runtime failures with a 4-phase RCA protocol and hands off a concrete hypothesis. |
| `tracer` | sonnet | no | Evidence-driven causal tracing; reverse-traces an observed effect to responsible code and ranks competing hypotheses. |
| `executor` | sonnet | yes | Focused code implementation. Small-correct-diff principle, TDD Iron Law enforcement. After 3 fails, escalates to `debugger` (root cause unclear) or `architect` (design wrong). |
| `verifier` | sonnet | no | Completion-verification gate; runs BUILD/TEST/LINT/FUNCTIONALITY/TODO/ERROR_FREE with fresh command output and returns a machine-readable `verdict`. Sonnet pin is deliberate — it is the highest-volume gate and largely mechanical command execution. Callers can scope a dispatch to a check subset via `note: scope=<CHECKS>`; unlisted checks are recorded `N/A — deferred to batch gate`. |

### Review lane

| Agent | Model | Writes? | Role |
|-------|-------|---------|------|
| `reviewer` | inherit (session) | no | Severity-rated review (CRITICAL/MAJOR/MINOR) of diffs and files; returns machine-readable `verdict`. |
| `security-auditor` | inherit (session) | no | AuthN/AuthZ, secrets, crypto, injection, SAST, and config findings with severity + confidence ratings. |
| `performance-analyst` | sonnet | no | Hotpath, complexity, IO/Memory/Cache findings with severity ratings. |

### Domain lane

| Agent | Model | Writes? | Role |
|-------|-------|---------|------|
| `test-engineer` | sonnet | tests only | Red-step authoring, coverage gap analysis, flaky-test diagnosis. TDD Iron Law enforcement. |
| `doc-writer` | sonnet | dual-mode | Doc gap/staleness/consistency analysis in advisor mode; authors directly in autonomous mode. |
| `git-master` | sonnet | yes (git ops only) | Encapsulates git mechanics (status, diff, staging, rebase, history traversal) for the `git-rebase-stack` command's high-risk path; `git-commit` / `github-pr` are intentionally inline. Never mutates on its own initiative — only when a user-triggered skill directs it. |
| `code-simplifier` | sonnet | yes | Behavior-preserving simplification of a bounded changed-file set; re-verifies with scoped tests after cleanup (the orchestrating skill's verifier gate performs the full re-check). Used by `ralph` (Step 7.5) and `team` cleanup passes. |

### Coordination lane

| Agent | Model | Writes? | Role |
|-------|-------|---------|------|
| `critic` | inherit (session) | no | Adversarial plan critique with explicit verdict (`REJECT` / `REVISE` / `ACCEPT_WITH_RESERVATIONS` / `APPROVE`). |

Invoke via the Task tool — no plugin prefix:

```
Task(subagent_type="reviewer",      prompt="...")
Task(subagent_type="executor",      prompt="...")
Task(subagent_type="security-auditor", prompt="...")
```

---

## Skills & commands

### Orchestration

#### `/autopilot [--exec=ralph|team] [--resume=auto|fresh] [--no-prompt] [--deliberate] [--full-validation] [--max-qa-cycles=<n>] [--threshold=<0.0-1.0>]`

End-to-end 5-phase pipeline from idea to code-ready state. Sequences:

1. **Expansion** — `deep-interview` → `spec.md`
2. **Planning** — `ralplan` → `plan.md` (`pending approval`)
3. **Execution** — `ralph` (story waves; tail gates deferred to Phases 4–5 via `--approver=defer --regression=defer`) or `team` (parallel stages) → code + `prd.json` + `progress.txt`; routed on the plan's `Parallel workstreams` metadata
4. **QA** — full `verifier` regression always; `test-engineer` coverage audit runs in cycle 1 only for team/resume/HIGH-tier provenance (otherwise it joins the Phase 5 panel read-only); up to `--max-qa-cycles` (default 5), with an early stop after 3 cycles of the same failing checks
5. **Validation** — default gates `reviewer` + `security-auditor` + `architect`; `--full-validation` adds `critic` (gate) plus `performance-analyst` + `doc-writer` advisors and the optional end-to-end `verifier` (fired in the same parallel batch) → `autopilot-validation.md`. Gate failures with ≤ 3 non-architectural findings take a targeted-fix path (executor + scoped verifier + re-fire failed gates only) instead of full Phase 3 re-entry

Smart-skip: existing `spec.md` skips Phase 1; existing `plan.md` skips Phases 1–2. Skip is governed by `--resume` (default `auto`): the detected resumption point is confirmed once via `AskUserQuestion` unless `--no-prompt`; `--resume=fresh` restarts at Phase 1. Stops at "ready for commit".

#### `/deep-interview [topic] [--lang=<value>] [--threshold=<0.0-1.0>] [--max-rounds=<n>]`

Socratic interview with mathematical ambiguity gating (default threshold `0.2`). Per-dimension scoring across **Goal / Constraints / Criteria / Context** runs inline every round; `analyst` is dispatched only at checkpoints (post-draft, pre-crystallize, scope shifts, stalls) with delta payloads. Round 0 establishes topology (auto-locked when a single component is detected); subsequent rounds target the weakest dimension. Brownfield codebase mapping goes to `explorer` (brownfield only — detection is inline); challenge modes (Contrarian / Simplifier / Ontologist) use the `critic` single-finding fast-path at preset round thresholds. Early exit is allowed at any round.

Output: `.dt-handoff/<slug>/spec.md`. Refuses handoff until ambiguity ≤ threshold OR user explicitly opts out.

#### `/interview [topic or file path] [--lang=<value>] [--max-rounds=<n>]`

Lightweight, conversational counterpart to `deep-interview`. Asks non-obvious questions one at a time across **Goal / Scope / Technical Implementation / UI & UX / Concerns & Risks / Tradeoffs** — no ambiguity scoring, no topology lock, no agent dispatch. Accepts a free-text topic or a file path. Continues until the dimensions are covered or the user opts out (soft cap 12 rounds).

Output: `.dt-handoff/<slug>/spec.md` (`Status: complete` or `draft` on early exit).

#### `/ralplan [--tier=LOW|MEDIUM|HIGH] [--interactive] [--deliberate] [--from-spec=<path>] [--lang=<value>]`

Candidate-panel consensus engine. Phase 0 risk triage sets panel width N (`LOW=1` / `MEDIUM=2` / `HIGH=3`, hard cap 4) and attack depth (1 lens per candidate LOW/MEDIUM, 2 HIGH). `architect ×N` generate genuinely distinct candidates (orthogonal framing lenses, mutually blind); the MEDIUM/HIGH `architect` evaluation pass (HIGH also `performance-analyst ×N`) and the **separated** `critic` attacks fire as one parallel wave (author ≠ attacker by dispatch topology); a **distinct** synthesizing `critic` ranks the survivors into one ADR and records `Parallel workstreams` metadata for downstream routing. Routing is on the synthesizer's machine `verdict`; the iteration cap is tier-proportional (`LOW=1` / `MEDIUM=2` / `HIGH=3`, all-invalidated HIGH `+1`). `--deliberate` is an alias for `--tier=HIGH`, retained for backward compatibility.

Output: `.dt-handoff/<slug>/plan.md`, always marked `Status: pending approval`. This skill never executes — `ralph` / `team` / `autopilot` are the execution paths.

#### `/ralph [--no-deslop] [--critic=architect|critic] [--from-plan=<path>] [--max-parallel=<k>] [--approver=defer] [--regression=defer]`

PRD-driven persistence loop. Reads `.dt-handoff/<slug>/prd.json` (acceptance criteria clustered into stories by file scope and test surface), selects a ready set of independent stories (file-scope disjoint, up to `--max-parallel`, default 3), and pipelines Red → Green per story via `test-engineer` + `executor` — each story's acceptance criteria verified with scoped fresh evidence (`note: scope=TEST,FUNCTIONALITY`). A single batch tail follows: `reviewer` approval (incremental on re-entry, 3-cycle cap), `code-simplifier` cleanup (Step 7.5), and a full-protocol regression `verifier`. The `defer` flags hand the tail gates to a calling pipeline (autopilot) to eliminate back-to-back duplicate gates — never use them standalone.

**TDD Iron Law**: no production code is written without a failing test first. On 3 consecutive story failures: root cause unclear → escalates to `debugger`; design fundamentally wrong → escalates to `architect`. Continues until every story passes.

#### `/team [--max-parallel=<n>] [--no-critic] [--from-plan=<path>]`

Five-stage parallel pipeline: **plan → prd → exec → verify → fix**. `planner` decomposes into independent stories; `executor` and `test-engineer` run in parallel waves; `verifier` gates each stage completion; `reviewer` + `critic` run in Stage 4; `code-simplifier` handles the cleanup pass. Use when the plan has ≥ 3 independent surfaces; otherwise prefer `ralph`.

Stops at "ready for commit". Single-host filesystem only — see [CLAUDE.md → Deployment assumption](./CLAUDE.md#deployment-assumption).

### Review & debugging

#### `/code-review [path]`

Severity-rated review of the current diff (default) or a named file. Dispatches `reviewer` always; `security-auditor` joins when the diff touches a security surface (auth/crypto/session, input handling, serialization, config/secrets) or exceeds 150 changed lines; `doc-writer` joins when docs or public API surfaces change. Skipped advisors are noted in the output; slug-context invocations keep the full panel. Findings are consolidated as CRITICAL / MAJOR / MINOR with file:line evidence.

When called inside a slug context (e.g. autopilot Phase 5 or `--slug=<slug>`), each advisor also writes a persistent findings file at `.dt-handoff/<slug>/artifacts/ask/<agent>-<ISO8601>.md` with descriptor frontmatter.

#### `/curl-debug <cURL>`

Runs the cURL request and reverse-traces the response back through the codebase using a signal hierarchy: **stack trace > error message > error code > URL path > body shape**. Direct signals (a stack trace naming file:line, or a 404 route lookup) are traced inline; weaker signals dispatch `tracer`. Returns root-cause analysis with file:line citations. No language-dependent artifact.

### Setup

#### `/install-statusline [--scope=user|project] [--dry-run]`

Installs the canonical `ccstatusline`-based status line in one step. Ships two config snapshots as assets — the `statusLine` wiring block and the full widget layout (model · thinking-effort · skills · git-branch · context% · session-clock + usage rows) — and applies all three pieces: installs the `ccstatusline` binary via npm if missing, merges the `statusLine` block into the target `settings.json` (user-level by default; **all other keys preserved**), and writes the widget layout to `~/.config/ccstatusline/settings.json`. Existing files are backed up to `<file>.bak.<timestamp>` first. Use `--dry-run` to preview without changes. No language-dependent artifact.

### Git & GitHub

#### `/git-commit`

Analyzes staged + unstaged changes, suggests splitting when warranted, drafts a conventional-commit message in `$LANGUAGE`, executes the commit. Delegates git mechanics to the `git-master` agent. **Never** appends a `Co-Authored-By` trailer.

#### `/github-pr [--draft]`

Detects the base branch, pushes the current branch if needed, drafts a conventional-commit-style title (English) with a body in `$LANGUAGE`, and creates the PR via GitHub MCP (or `gh` CLI fallback). Delegates git mechanics to `git-master`. Real newlines, never escaped `\n`.

#### `/git-rebase-stack [base-or-intent]`

Auto-detects the stack topology from the current branch and runs `git rebase --onto <base> <commit> --update-refs`. Use after the base branch moves, a middle PR merges, or the whole stack needs re-syncing. Output is always Korean per the marketplace SPEC.

---

## `.dt-handoff/<slug>/` artifact layout

Every orchestration skill writes under a single slug directory inside the **local `.dt-handoff/` workspace** (gitignored). This replaced the former `.specs/<slug>/` layout in the post-overhaul rewrite.

```
.dt-handoff/<slug>/
├── spec.md              # deep-interview output (descriptor frontmatter; permanent)
├── plan.md              # ralplan output (descriptor frontmatter; permanent)
├── prd.json             # ralph/team internal (_descriptor key; permanent)
├── progress.txt         # ralph/team trace log (no descriptor; trace kind)
├── state/               # control plane: autopilot.json, ralph.json, team.json
├── artifacts/ask/       # advisor output: <agent>-<ISO8601>.md (session retention)
├── notepads/            # ralph cross-iteration memory (learnings/decisions/issues/problems)
├── events.jsonl         # append-only event log (every agent dispatch + return)
├── team-final.md        # team Stage 5 summary
└── autopilot-validation.md  # autopilot Phase 5 consolidated verdicts
```

**Hand-off contract**: every artifact that crosses a skill→agent or agent→skill boundary carries a 9-field descriptor (frontmatter for `.md`, `_descriptor` key for `.json`). Skills pass `@handoff-in` blocks to agents; agents return `@handoff-out` blocks (including the optional `verdict` field for judgment agents). The `scripts/validate.sh` header is the machine source of truth for the descriptor schema and enum values; the descriptors lane (`bash scripts/validate.sh --descriptors`) enforces it.

### Migrating from `.specs/<slug>/`

If you have artifacts from a pre-overhaul run stored under `.specs/<slug>/`, move them into the new layout before re-running any orchestration skill:

```sh
mkdir -p .dt-handoff/MY_SLUG
mv .specs/MY_SLUG/* .dt-handoff/MY_SLUG/
```

All orchestration skills key their smart-skip logic on `.dt-handoff/<slug>/spec.md` and `.dt-handoff/<slug>/plan.md`; missing those paths forces a re-run of the corresponding phase.

---

## Settings & language

```json
"settings": { "language": "Korean" }
```

`$LANGUAGE` controls the content of any language-dependent artifact:

| Asset | Uses `$LANGUAGE` for | Per-call override |
|-------|---------------------|-------------------|
| `git-commit` | Commit subject + body | `--lang=<value>` |
| `github-pr` | PR description body | `--lang=<value>` |
| `deep-interview` | Interview prompts + spec body | `--lang=<value>` |
| `interview` | Interview questions + spec body | `--lang=<value>` |

**Exempt** (always conversation-language or always Korean): `git-rebase-stack`, `curl-debug`, `code-review`, `install-statusline`, all agents.

**Presets**: Korean, English, Japanese, Chinese. ISO 639-1 codes (`ko`, `en`, `ja`, `zh`) are accepted. Custom strings (`Spanish`, `Bahasa Indonesia`) are passed through verbatim.

---

## Behavior guarantees

- **No `Co-Authored-By` trailer** is ever added by `/git-commit` or `/git-rebase-stack`.
- **PR titles use English** `type(scope): subject`; the body uses `$LANGUAGE`.
- **Structural headers** in PRs, specs, plans, and Linear tickets (`## Summary`, `## Goal`, `## Acceptance Criteria`, …) **stay English**; only their content is translated.
- **Real newlines** in PR bodies — never escaped `\n` literals.
- **Orchestration skills never auto-commit** — they hand back control at "ready for commit".
- **Verdict routing is machine-readable** — `reviewer`, `critic`, and `verifier` return a `verdict` field in their `@handoff-out` block; skills route on that enum value, not prose keyword matching.
- **Every SKILL.md / command.md** uses the [9-section XML house style](../../CLAUDE.md#9-section-house-style).

---

## MCP requirements

| MCP | Required by | Fallback |
|-----|-------------|----------|
| **GitHub** | `/github-pr`, stack PR lookups in `/git-rebase-stack` | `gh` CLI |

---

## License

MIT — inherited from the marketplace root.
