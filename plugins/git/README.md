# git

Git and GitHub workflows for Claude Code. Auto-generates conventional commit messages, creates Pull Requests, and cleans up stacked-PR rebases.

## Usage

| Trigger | Skill / Command | What it does |
|---------|-----------------|--------------|
| `/git-commit`, "커밋해줘", "commit this" | `git-commit` (skill) | Analyzes the staged diff, drafts a conventional-commit message in `$LANGUAGE`, and executes the commit. |
| `/github-pr [--draft]`, "PR 만들어줘", "create a PR" | `github-pr` (skill) | Detects the base branch, pushes if needed, drafts a conventional-commit-style PR title + body in `$LANGUAGE`, creates the PR via GitHub MCP. |
| `/git-rebase-stack [base-or-intent]`, "stack 정리해줘", "rebase the entire feature/auth stack onto main" | `git-rebase-stack` (command) | Detects the stack topology, plans the rebase, executes `git rebase --onto --update-refs`, and optionally pushes. |

## Settings

```json
"settings": { "language": "Korean" }
```

- `language` — the default language for commit subject/body and PR description content. Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.
- `git-rebase-stack` is exempt from `language` and continues to use Korean for guidance/questions/reports, per the marketplace SPEC.

## `core` dependency

This plugin does not directly invoke `core`. If you want severity-rated review of a staged diff before committing, install the `core` plugin and invoke `/code-review` separately.

## Behavior guarantees

- **No `Co-Authored-By` trailer ever.** Both `git-commit` and `git-rebase-stack` block this.
- PR titles use English `type(scope)`; descriptions use `$LANGUAGE`.
- PR body section headers (`## Summary`, `## Changes`) stay English; content uses `$LANGUAGE`.
- The body uses real newline characters, never escaped `\n` literals.
