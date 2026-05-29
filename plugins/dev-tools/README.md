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
| `/ralplan` | skill | Consensus planning (planner + architect + performance-analyst + critic). Writes `plan.md`. |
| `/ralph` | skill | PRD-driven sequential execution loop with TDD discipline. |
| `/team` | skill | 5-stage parallel multi-agent orchestration. |
| `/code-review` | skill | Multi-domain severity-rated review (reviewer + security-auditor + doc-writer). |
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
┌────────────────┐   ┌─────────┐   ┌────────────┐   ┌──────────────────┐   ┌────────────┐
│ deep-interview │ → │ ralplan │ → │ ralph      │ → │ test-engineer    │ → │ architect  │
│   spec.md      │   │ plan.md │   │   or team  │   │   + executor     │   │ + critic   │
│                │   │         │   │ prd.json   │   │   + verifier     │   │ + reviewer │
└────────────────┘   └─────────┘   │ + code     │   │  QA (max 5 iter) │   │ Validation │
                                   │ + progress │   └──────────────────┘   └────────────┘
                                   └────────────┘
```

`/autopilot` is the conductor that sequences all five phases in a single invocation and auto-skips phases whose artifacts already exist on disk. Resuming a yesterday's interview takes one command.

**Hard stop at "ready for commit".** Every orchestration skill — `ralph`, `team`, `autopilot` — refuses to commit, push, or open a PR. Those moves are explicit user gestures via `/git-commit` and `/github-pr`. The pipeline puts the change on disk and tells you it's done; you decide what ships.

When to pick what:

| Situation | Skill |
|-----------|-------|
| "I have an idea, take it to ready-for-review" | `/autopilot` |
| "Capture requirements only" | `/deep-interview` |
| "I have a spec, give me a vetted plan" | `/ralplan` |
| "Execute this plan, one story at a time, TDD-strict" | `/ralph` |
| "Execute this plan with parallel workstreams" | `/team` |
| "Just review what I have" | `/code-review` |

---

## Agents

Sixteen specialist agents organized in four lanes. Read-only advisors carry `disallowedTools: Write, Edit`; write-capable agents have no such constraint. Three agents return a machine-readable `verdict` field (`APPROVE` / `ACCEPT_WITH_RESERVATIONS` / `ITERATE` / `REVISE` / `REJECT`) in their `@handoff-out` block: `reviewer`, `critic`, and `verifier`.

### Build / Analysis lane

| Agent | Model | Writes? | Role |
|-------|-------|---------|------|
| `explorer` | haiku | no | Fast file/symbol/pattern lookup with absolute paths and excerpts. |
| `analyst` | opus | no | Requirement decomposition, hidden-constraint surfacing, and ambiguity scoring. |
| `planner` | opus | no | Turns a spec or PRD into a sequenced, dependency-aware execution plan (story breakdown + DAG + acceptance criteria). |
| `architect` | opus | no | System design and trade-off advisor; evaluates interface contracts and recommends structural changes with file:line evidence. Not for bug diagnosis or verification. |
| `debugger` | sonnet | no | Root-cause analysis advisor; diagnoses build/test/runtime failures with a 4-phase RCA protocol and hands off a concrete hypothesis. |
| `tracer` | sonnet | no | Evidence-driven causal tracing; reverse-traces an observed effect to responsible code and ranks competing hypotheses. |
| `executor` | sonnet | yes | Focused code implementation. Small-correct-diff principle, TDD Iron Law enforcement. After 3 fails, escalates to `debugger` (root cause unclear) or `architect` (design wrong). |
| `verifier` | sonnet | no | Completion-verification gate; runs BUILD/TEST/LINT/FUNCTIONALITY/TODO/ERROR_FREE with fresh command output and returns a machine-readable `verdict`. |

### Review lane

| Agent | Model | Writes? | Role |
|-------|-------|---------|------|
| `reviewer` | opus | no | Severity-rated review (CRITICAL/MAJOR/MINOR) of diffs and files; returns machine-readable `verdict`. |
| `security-auditor` | opus | no | AuthN/AuthZ, secrets, crypto, injection, SAST, and config findings with severity + confidence ratings. |
| `performance-analyst` | sonnet | no | Hotpath, complexity, IO/Memory/Cache findings with severity ratings. |

### Domain lane

| Agent | Model | Writes? | Role |
|-------|-------|---------|------|
| `test-engineer` | sonnet | tests only | Red-step authoring, coverage gap analysis, flaky-test diagnosis. TDD Iron Law enforcement. |
| `doc-writer` | sonnet | dual-mode | Doc gap/staleness/consistency analysis in advisor mode; authors directly in autonomous mode. |
| `git-master` | sonnet | yes (git ops only) | Encapsulates git mechanics (status, diff, staging, commit construction, rebase, push) for the git/GitHub skills. Never mutates on its own initiative — only when a user-triggered skill directs it. |
| `code-simplifier` | opus | yes | Behavior-preserving simplification of a bounded changed-file set; re-verifies via `verifier` after cleanup. Used by `ralph` (Step 7.5) and `team` cleanup passes. |

### Coordination lane

| Agent | Model | Writes? | Role |
|-------|-------|---------|------|
| `critic` | opus | no | Adversarial plan critique with explicit verdict (`REJECT` / `REVISE` / `ACCEPT-WITH-RESERVATIONS` / `ACCEPT`). |

Invoke via the Task tool — no plugin prefix:

```
Task(subagent_type="reviewer",      prompt="...")
Task(subagent_type="executor",      prompt="...")
Task(subagent_type="security-auditor", prompt="...")
```

---

## Skills & commands

### Orchestration

#### `/autopilot [--exec=ralph|team] [--skip-phase1] [--skip-phase2] [--deliberate]`

End-to-end 5-phase pipeline from idea to code-ready state. Sequences:

1. **Expansion** — `deep-interview` → `spec.md`
2. **Planning** — `ralplan` → `plan.md` (`pending approval`)
3. **Execution** — `ralph` (sequential) or `team` (parallel) → code + `prd.json` + `progress.txt`
4. **QA** — `test-engineer` + `executor` + `verifier` pass, up to 5 iterations
5. **Validation** — `architect` + `critic` + `reviewer` (+ optional `security-auditor`, `performance-analyst`, `doc-writer`, `verifier`) → `autopilot-validation.md`

Smart-skip: existing `spec.md` skips Phase 1; existing `plan.md` skips Phases 1–2. Stops at "ready for commit".

#### `/deep-interview [topic] [--lang=<value>] [--threshold=<0.0-1.0>] [--max-rounds=<n>]`

Socratic interview with mathematical ambiguity gating (default threshold `0.2`). Per-dimension scoring across **Goal / Constraints / Criteria / Context**. Round 0 establishes topology; subsequent rounds target the weakest dimension. Delegates deep requirement analysis and ambiguity scoring to `analyst`; brownfield codebase mapping to `explorer`; challenge modes (Contrarian / Simplifier / Ontologist) to `critic` at preset round thresholds.

Output: `.dt-handoff/<slug>/spec.md`. Refuses handoff until ambiguity ≤ threshold OR user explicitly opts out.

#### `/ralplan [--interactive] [--deliberate] [--from-spec=<path>]`

Consensus planning via **RALPLAN-DR** structured deliberation (Principles → Drivers → Options → pre-mortem). `planner` authors the draft plan; `architect` and `performance-analyst` review in parallel; `critic` owns the single verdict. Iterates until `APPROVE`, max 5 rounds.

Output: `.dt-handoff/<slug>/plan.md`, always marked `Status: pending approval`. This skill never executes — `ralph` / `team` / `autopilot` are the execution paths.

#### `/ralph [--no-deslop] [--critic=architect|critic] [--from-plan=<path>]`

PRD-driven sequential persistence loop. Reads `.dt-handoff/<slug>/prd.json`, picks the highest-priority story with `passes: false`, drives Red → Green → Refactor via `test-engineer` + `executor`, verifies acceptance criteria with fresh evidence via the `verifier` agent, runs `reviewer` approval, then a `code-simplifier` cleanup pass (Step 7.5), then re-verifies regression with `verifier`.

**TDD Iron Law**: no production code is written without a failing test first. On 3 consecutive story failures: root cause unclear → escalates to `debugger`; design fundamentally wrong → escalates to `architect`. Continues until every story passes.

#### `/team [--max-parallel=<n>] [--no-critic] [--from-plan=<path>]`

Five-stage parallel pipeline: **plan → prd → exec → verify → fix**. `planner` decomposes into independent stories; `executor` and `test-engineer` run in parallel waves; `verifier` gates each stage completion; `reviewer` + `critic` run in Stage 4; `code-simplifier` handles the cleanup pass. Use when the plan has ≥ 3 independent surfaces; otherwise prefer `ralph`.

Stops at "ready for commit". Single-host filesystem only — see [CLAUDE.md → Deployment assumption](./CLAUDE.md#deployment-assumption).

### Review & debugging

#### `/code-review [path]`

Severity-rated review of the current diff (default) or a named file. Dispatches `reviewer` + `security-auditor` + `doc-writer` in parallel and consolidates CRITICAL / MAJOR / MINOR findings with file:line evidence.

When called inside a slug context (e.g. autopilot Phase 5 or `--slug=<slug>`), each advisor also writes a persistent findings file at `.dt-handoff/<slug>/artifacts/ask/<agent>-<ISO8601>.md` with descriptor frontmatter.

#### `/curl-debug <cURL>`

Runs the cURL request and reverse-traces the response back through the codebase using a signal hierarchy: **stack trace > error message > error code > URL path > body shape**. Returns root-cause analysis with file:line citations. No language-dependent artifact.

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
