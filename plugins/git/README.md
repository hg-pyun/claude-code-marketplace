# git

Git workflow automation plugin. Analyzes the diff of staged changes to auto-generate Korean conventional commit messages, create PRs, and handle stacked PR rebase.

## Commands

| Command | Description |
|---------|-------------|
| `git-commit` | Analyzes git diff → auto-generates Korean conventional commit message and executes the commit |
| `github-pr` | Analyzes current branch changes → auto-creates a GitHub PR with a Korean conventional commit-style title |
| `git-rebase-stack` | Automatically cleans up stacked branches using `git rebase --onto --update-refs` |

## Usage Examples

### git-commit
`/commit` — If there are no staged changes, automatically stages everything, then analyzes the diff to generate a commit message. Suggests splitting the commit if changes should logically be separated.

### github-pr
`/pr` — Analyzes the current branch's commit history and diff to create a PR. Automatically pushes unpushed branches and extracts issue numbers from the branch name for linking.
`/pr --draft` — Creates a draft PR.

### git-rebase-stack
`/rebase-stack` — Automatically detects the stack based on the current branch and executes the rebase.
`/rebase-stack step-1 was merged, please clean up` — Pass intent in natural language, and the stack topology will be analyzed to execute the appropriate rebase.
