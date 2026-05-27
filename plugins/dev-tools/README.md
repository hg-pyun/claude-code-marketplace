# dev-tools

> Personal multi-agent orchestration plugin for Claude Code — built and maintained by **hg-pyun**.

A single bundled plugin that combines specialist **agents**, a full-lifecycle **orchestration pipeline**, and day-to-day **git / GitHub** helpers. Install once, get the entire toolkit.

---

## Contents

- [Install](#install)
- [At-a-glance](#at-a-glance)
- [Orchestration lifecycle](#orchestration-lifecycle)
- [Agents](#agents)
- [Skills & commands](#skills--commands)
- [`.specs/<slug>/` artifact layout](#specsslug-artifact-layout)
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
| `/ralplan` | skill | Consensus planning (Architect + Performance-analyst + Critic). Writes `plan.md`. |
| `/ralph` | skill | PRD-driven sequential execution loop with TDD discipline. |
| `/team` | skill | 5-stage parallel multi-agent orchestration. |
| `/code-review` | skill | Multi-domain severity-rated review (reviewer + security-auditor + doc-writer). |
| `/git-commit` | skill | Conventional-commit message + commit, in `$LANGUAGE`. |
| `/github-pr` | skill | Conventional-commit-style PR title + body, in `$LANGUAGE`. |
| `/git-rebase-stack` | command | Stacked-PR rebase via `git rebase --onto … --update-refs`. |
| `/curl-debug` | skill | Run a cURL, reverse-trace failures to source. |

Korean trigger phrases (e.g. `"커밋해줘"`, `"PR 만들어줘"`, `"끝까지 가줘"`) work in addition to the slash commands; see each skill's frontmatter for the full list.

---

## Orchestration lifecycle

The four orchestration skills form a single, resumable lifecycle:

```
┌────────────────┐   ┌─────────┐   ┌────────────┐   ┌───────────────┐   ┌────────────┐
│ deep-interview │ → │ ralplan │ → │ ralph      │ → │ test-engineer │ → │ architect  │
│   spec.md      │   │ plan.md │   │   or team  │   │   QA pass     │   │ + critic   │
│                │   │         │   │ prd.json   │   │  (max 5 iter) │   │ + reviewer │
└────────────────┘   └─────────┘   │ + code     │   └───────────────┘   │ Validation │
                                   │ + progress │                       └────────────┘
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

Nine specialist agents. Six are read-only **advisors** (`disallowedTools: Write, Edit`); two **author code** (`executor`, `test-engineer`); one is **dual-mode** (`doc-writer`, advisor by default, autonomous when invoked directly).

| Agent | Model | Writes? | Role |
|-------|-------|---------|------|
| `reviewer` | sonnet | no | Severity-rated review (CRITICAL/MAJOR/MINOR) of diffs and files. |
| `explorer` | haiku | no | Fast file/symbol/pattern lookup with absolute paths and excerpts. |
| `architect` | opus | no | Root-cause diagnosis + architectural recommendations with file:line evidence. 3-fail escalation target. |
| `critic` | opus | no | Adversarial plan critique with explicit verdict (`REJECT` / `REVISE` / `ACCEPT-WITH-RESERVATIONS` / `ACCEPT`). |
| `executor` | sonnet | yes | Focused code implementation. Small-correct-diff principle, TDD-first refusal. |
| `test-engineer` | sonnet | tests only | Red-step authoring, coverage gap analysis, flaky-test diagnosis. TDD Iron Law enforcement. |
| `doc-writer` | sonnet | dual-mode | Doc gap/staleness/consistency analysis. Authors directly in autonomous mode. |
| `performance-analyst` | sonnet | no | Hotpath, complexity, IO/Memory/Cache findings with severity ratings. |
| `security-auditor` | opus | no | AuthN/AuthZ, secrets, crypto, injection, SAST, config findings with severity + confidence. |

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
4. **QA** — `test-engineer` pass, up to 5 iterations
5. **Validation** — `architect` + `critic` + `reviewer` (+ optional `security-auditor`, `performance-analyst`, `doc-writer`) → `autopilot-validation.md`

Smart-skip: existing `spec.md` skips Phase 1; existing `plan.md` skips Phases 1–2. Stops at "ready for commit".

#### `/deep-interview [topic] [--lang=<value>] [--threshold=<0.0-1.0>] [--max-rounds=<n>]`

Socratic interview with mathematical ambiguity gating (default threshold `0.2`). Per-dimension scoring across **Goal / Constraints / Criteria / Context**. Round 0 establishes topology; subsequent rounds target the weakest dimension. Challenge agents (Contrarian / Simplifier / Ontologist) activate at preset thresholds. Brownfield codebases get a pre-interview `explorer` pass.

Output: `.specs/<slug>/spec.md`. Refuses handoff until ambiguity ≤ threshold OR user explicitly opts out.

#### `/ralplan [--interactive] [--deliberate] [--from-spec=<path>]`

Consensus planning via **RALPLAN-DR** structured deliberation (Principles → Drivers → Options → pre-mortem). Architect and performance-analyst run in parallel; Critic owns the single verdict. Iterates until `APPROVE`, max 5 rounds.

Output: `.specs/<slug>/plan.md`, always marked `Status: pending approval`. This skill never executes — `ralph` / `team` / `autopilot` are the execution paths.

#### `/ralph [--no-deslop] [--critic=architect|critic] [--from-plan=<path>]`

PRD-driven sequential persistence loop. Reads `.specs/<slug>/prd.json`, picks the highest-priority story with `passes: false`, drives Red → Green → Refactor via `test-engineer` + `executor`, verifies acceptance criteria with fresh evidence, runs reviewer approval, then a `code-review` cleanup pass, then re-verifies regression.

**TDD Iron Law**: no production code is written without a failing test first. Continues until every story passes.

#### `/team [--max-parallel=<n>] [--no-critic] [--from-plan=<path>]`

Five-stage parallel pipeline: **plan → prd → exec → verify → fix**. Decomposes into independent stories, fires `executor` and `test-engineer` in parallel waves, then runs `reviewer` + `critic` in Stage 4. Use when the plan has ≥ 3 independent surfaces; otherwise prefer `ralph`.

Stops at "ready for commit". Single-host filesystem only — see [CLAUDE.md → Deployment assumption](./CLAUDE.md#deployment-assumption).

### Review & debugging

#### `/code-review [path]`

Severity-rated review of the current diff (default) or a named file. Dispatches `reviewer` + `security-auditor` + `doc-writer` in parallel and consolidates CRITICAL / MAJOR / MINOR findings with file:line evidence.

When called inside a slug context (e.g. autopilot Phase 5 or `--slug=<slug>`), each advisor also writes a persistent findings file at `.specs/<slug>/artifacts/ask/<agent>-<ISO8601>.md` with descriptor frontmatter.

#### `/curl-debug <cURL>`

Runs the cURL request and reverse-traces the response back through the codebase using a signal hierarchy: **stack trace > error message > error code > URL path > body shape**. Returns root-cause analysis with file:line citations. No language-dependent artifact.

### Git & GitHub

#### `/git-commit`

Analyzes staged + unstaged changes, suggests splitting when warranted, drafts a conventional-commit message in `$LANGUAGE`, executes the commit. **Never** appends a `Co-Authored-By` trailer.

#### `/github-pr [--draft]`

Detects the base branch, pushes the current branch if needed, drafts a conventional-commit-style title (English) with a body in `$LANGUAGE`, and creates the PR via GitHub MCP (or `gh` CLI fallback). Real newlines, never escaped `\n`.

#### `/git-rebase-stack [base-or-intent]`

Auto-detects the stack topology from the current branch and runs `git rebase --onto <base> <commit> --update-refs`. Use after the base branch moves, a middle PR merges, or the whole stack needs re-syncing. Output is always Korean per the marketplace SPEC.

---

## `.specs/<slug>/` artifact layout

Every orchestration skill writes under a single slug directory:

```
.specs/<slug>/
├── spec.md              # deep-interview output (descriptor frontmatter; permanent)
├── plan.md              # ralplan output (descriptor frontmatter; permanent)
├── prd.json             # ralph/team internal (_descriptor key; permanent)
├── progress.txt         # ralph/team trace log (no descriptor; trace kind)
├── state/               # control plane: autopilot.json, ralph.json, team.json
├── artifacts/ask/       # advisor output: <agent>-<ISO8601>.md (session retention)
├── notepads/            # ralph cross-iteration memory (learnings/decisions/issues/problems)
├── events.jsonl         # team mode only: append-only event log
├── team-final.md        # team Stage 5 summary
└── autopilot-validation.md  # autopilot Phase 5 consolidated verdicts
```

See [CLAUDE.md](./CLAUDE.md#artifact-hand-off-descriptor-schema) for the **Artifact Hand-off Descriptor Schema** that every spec / plan / prd file carries.

### Migrating legacy `.specs/` files

If you have spec files from an earlier version stored flat (`.specs/MY_SLUG.md`), move them into the per-slug layout before re-running `/autopilot`:

```sh
mkdir -p .specs/MY_SLUG
mv .specs/MY_SLUG.md .specs/MY_SLUG/spec.md
```

`autopilot` keys Phase 1 skip on `.specs/<slug>/spec.md`; missing the new path forces an interview re-run.

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

**Exempt** (always conversation-language or always Korean): `git-rebase-stack`, `curl-debug`, `code-review`, all agents.

**Presets**: Korean, English, Japanese, Chinese. ISO 639-1 codes (`ko`, `en`, `ja`, `zh`) are accepted. Custom strings (`Spanish`, `Bahasa Indonesia`) are passed through verbatim.

---

## Behavior guarantees

- **No `Co-Authored-By` trailer** is ever added by `/git-commit` or `/git-rebase-stack`.
- **PR titles use English** `type(scope): subject`; the body uses `$LANGUAGE`.
- **Structural headers** in PRs, specs, plans, and Linear tickets (`## Summary`, `## Goal`, `## Acceptance Criteria`, …) **stay English**; only their content is translated.
- **Real newlines** in PR bodies — never escaped `\n` literals.
- **Orchestration skills never auto-commit** — they hand back control at "ready for commit".
- **Every SKILL.md / command.md** uses the [9-section XML house style](../../CLAUDE.md#9-section-house-style).

---

## MCP requirements

| MCP | Required by | Fallback |
|-----|-------------|----------|
| **GitHub** | `/github-pr`, stack PR lookups in `/git-rebase-stack` | `gh` CLI |

---

## License

MIT — inherited from the marketplace root.
