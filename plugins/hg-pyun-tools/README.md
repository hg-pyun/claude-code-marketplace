# hg-pyun-tools

Unified Claude Code toolkit by hg-pyun. Bundles shared review/exploration/architecture/critique agents alongside git+GitHub workflows, Linear ticket enrichment, deep-interview planning, and cURL debugging in a single installable plugin.

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

### Agents

Other skills (and this plugin's own skills) delegate to the bundled agents via the Task tool:

```
Task(subagent_type="reviewer", prompt="...")
Task(subagent_type="explorer", prompt="...")
Task(subagent_type="architect", prompt="...")
Task(subagent_type="critic",   prompt="...")
```

| Agent | Model | Role |
|-------|-------|------|
| reviewer | sonnet | Severity-rated review (CRITICAL/MAJOR/MINOR) of diffs or files |
| explorer | haiku | Fast read-only search for files, symbols, patterns |
| architect | opus | Read-only architecture and debugging advisor with file:line evidence |
| critic | opus | Adversarial critique of plans/decisions with steelman counterarguments |

All agents are READ-ONLY (`disallowedTools: Write, Edit`) and cannot mutate the repo.

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
