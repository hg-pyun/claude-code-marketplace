# hg-pyun-tools

Unified Claude Code toolkit by hg-pyun. Bundles shared review/exploration/architecture/critique/execution/test agents alongside multi-agent orchestration skills (autopilot/ralplan/ralph/team), git+GitHub workflows, Linear ticket enrichment, deep-interview planning, and cURL debugging in a single installable plugin.

## Purpose

`hg-pyun-tools` is the single-plugin successor to the five-plugin layout (`core`, `debug`, `git`, `linear`, `plan`). All agents, commands, and skills now ship together so consumers install one plugin and get the entire toolkit consistently — no missing-`core` fallback paths, no cross-plugin invocation prefixes.

## Usage

### Install

```shell
/plugin marketplace add hg-pyun/claude-code-marketplace
/plugin install hg-pyun-tools@hg-pyun-plugins
```

### Commands and skills

| Trigger | Type | What it does |
|---------|------|--------------|
| `/git-commit`, "커밋해줘", "commit this" | skill | Analyzes the staged diff, drafts a conventional-commit message in `$LANGUAGE`, executes the commit. Never includes `Co-Authored-By`. |
| `/github-pr [--draft]`, "PR 만들어줘", "create a PR" | skill | Detects the base branch, pushes if needed, drafts a conventional-commit-style PR title + body in `$LANGUAGE`, creates the PR via GitHub MCP. |
| `/git-rebase-stack [base-or-intent]`, "stack 정리해줘" | command | Detects stack topology, plans the rebase, executes `git rebase --onto --update-refs`, optionally pushes. |
| `/enrich-ticket <url> [--lang=<value>]`, "이 티켓 채워줘" | command | Reads a Linear ticket + comments, interviews the user to fill missing rubric sections, writes the enriched body back via Linear MCP. |
| `/deep-interview [topic] [--lang=<value>] [--threshold=<0.0-1.0>] [--max-rounds=<n>]`, "스펙 잡아줘", "deep interview" | skill | Socratic interview with mathematical ambiguity gating (default threshold 0.2). Round 0 topology lock, per-round clarity scoring, challenge agents (Contrarian/Simplifier/Ontologist), brownfield codebase pre-exploration via `explorer`. Produces a spec at `.specs/deep-interview-<slug>.md`. |
| `/curl-debug <cURL>`, "이 curl 500 에러 나는데" | skill | Runs the cURL, reverse-traces from signal (stack trace > error message > error code > URL path > body shape) to source code, reports root cause with file:line evidence. |
| `/code-review`, "코드 리뷰 해줘" | skill | Delegates the current diff (or a named file) to the `reviewer` agent and presents CRITICAL/MAJOR/MINOR findings. |
| `/core-verify`, "검증해줘" | skill | Evidence-based PASS/FAIL on recent changes — identifies the change surface, runs the code, cites file:line evidence. |
| `/ralplan [--interactive] [--deliberate] [--from-spec=<path>]`, "ralplan", "합의 계획 잡아줘" | skill | Consensus planning: drafts an ADR plan, runs Architect → Critic loop (max 5 iter), writes `.specs/<slug>/plan.md` marked `pending approval`. Planning-only — never executes. |
| `/ralph [--no-deslop] [--critic=architect\|critic] [--from-plan=<path>]`, "ralph", "끝까지 가줘" | skill | PRD-driven persistence loop. Reads `.specs/<slug>/prd.json`, drives TDD (test-engineer Red → executor Green) story-by-story, runs reviewer approval + `code-review` cleanup + regression. Stops at "ready for commit" — never auto commits. |
| `/team [--max-parallel=<n>] [--no-critic] [--from-plan=<path>]`, "team", "팀으로 진행" | skill | 5-stage parallel multi-agent orchestration (plan → prd → exec → verify → fix). Decomposes into independent stories, fires executor/test-engineer in parallel waves, runs reviewer + critic in Stage 4. Stops at "ready for commit". |
| `/autopilot [--exec=ralph\|team] [--skip-phase1] [--skip-phase2] [--deliberate]`, "autopilot", "build me X", "만들어줘" | skill | End-to-end 5-phase pipeline. Sequences deep-interview → ralplan → (ralph or team) → test-engineer QA → architect+critic+reviewer Validation. Smart shortcuts skip phases when `.specs/<slug>/` artifacts exist. Stops at "ready for commit". |

### Agents

Other skills (and this plugin's own skills) delegate to the bundled agents via the Task tool:

```
Task(subagent_type="reviewer",      prompt="...")
Task(subagent_type="explorer",      prompt="...")
Task(subagent_type="architect",     prompt="...")
Task(subagent_type="critic",        prompt="...")
Task(subagent_type="executor",      prompt="...")
Task(subagent_type="test-engineer", prompt="...")
```

| Agent | Model | Mutating? | Role |
|-------|-------|-----------|------|
| reviewer | sonnet | no | Severity-rated review (CRITICAL/MAJOR/MINOR) of diffs or files |
| explorer | haiku | no | Fast read-only search for files, symbols, patterns |
| architect | opus | no | Read-only architecture and debugging advisor with file:line evidence; 3-fail escalation target |
| critic | opus | no | Adversarial critique of plans/decisions with steelman counterarguments |
| executor | sonnet | yes | Focused code implementation. Small-correct-diff principle, TDD-first refusal, escalates to architect after 3 fails |
| test-engineer | sonnet | yes (tests only) | TDD enforcement, failing-test authoring, coverage analysis, flaky diagnosis. Iron Law: no production code without a failing test first |

The four advisor agents (`reviewer`, `explorer`, `architect`, `critic`) are READ-ONLY (`disallowedTools: Write, Edit`) and cannot mutate the repo. `executor` and `test-engineer` author code/tests as their core responsibility.

### Multi-agent orchestration

The four orchestration skills compose into a full lifecycle:

```
deep-interview  →  ralplan  →  ralph    →  test-engineer  →  architect+critic+reviewer
   (spec.md)       (plan.md)    (prd.json   (Phase 4 QA)        (Phase 5 Validation)
                                + code +
                                progress.txt)
```

Or, when independent workstreams exist, swap `ralph` for `team` (5-stage parallel pipeline).

`autopilot` is the conductor that wires all of the above into a single invocation with smart-skip logic for resumption. All four skills land their artifacts under `.specs/<slug>/` and explicitly stop at "ready for commit" — commit and PR creation remain user-triggered via `/git-commit` and `/github-pr`.

## Settings

```json
"settings": { "language": "Korean" }
```

- `language` — default language for commit subject/body, PR description content, Linear ticket body, and spec documents.
- Override per-invocation with `--lang=<value>`.
- Presets: Korean, English, Japanese, Chinese. Custom values (e.g., `Spanish`, `Bahasa Indonesia`) are accepted as free text.
- Exempt artifacts: `git-rebase-stack` outputs (always Korean per marketplace SPEC), `curl-debug` reports (conversation-language, no static artifact), agent outputs (calling-session language).

## Behavior guarantees

- **No `Co-Authored-By` trailer ever** in `git-commit` or `git-rebase-stack`.
- PR titles use English `type(scope)`; descriptions use `$LANGUAGE`.
- PR body section headers (`## Summary`, `## Changes`) stay English; content uses `$LANGUAGE`.
- The PR body uses real newline characters, never escaped `\n` literals.
- Linear/spec rubric headers (`## Goal`, `## Acceptance Criteria`, …) stay English; content uses `$LANGUAGE`.
- All bundled SKILL.md / command.md files use the 9-section XML house style.

## Required MCP

- **Linear MCP** — for `/enrich-ticket` (reading and writing tickets).
- **GitHub MCP** (preferred) or `gh` CLI fallback — for `/github-pr` and stack PR lookups.

## License

MIT (inherits from the marketplace root).
