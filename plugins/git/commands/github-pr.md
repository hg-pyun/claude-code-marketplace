# GitHub PR Command (Conventional Commit, Korean)

## Overview
A command that analyzes the current branch's changes and auto-creates a GitHub Pull Request with a Korean conventional commit-style title.

## Arguments
- `$ARGUMENTS`: Optional. Pass the `--draft` flag to create a draft PR.

## Tool Priority
- For GitHub-related tasks (PR lookup, repo info, PR creation, etc.), **prioritize GitHub MCP tools**.
- Fall back to `gh` CLI only if MCP tools fail or are unavailable.
- Execute git local commands (`git status`, `git log`, `git diff`, etc.) via Bash.

## Procedure

### Step 1: Pre-validation

1. Check the current state with `git status`.
2. If the current branch is the default branch (main/master), abort with an error.
3. **If there are uncommitted changes**, output a warning to the user but continue.
4. Check whether the current branch has been pushed to the remote.
   - Check remote branch existence with `git ls-remote --heads origin <current-branch-name>`.
   - If the remote branch doesn't exist, or if there are unpushed local commits per `git log @{upstream}..HEAD --oneline`, execute `git push -u origin <current-branch-name>` to auto-push.
   - If the push fails, output an error message and abort.
5. Check whether there is already an open PR from the current branch using GitHub MCP `list_pull_requests`.
   - If an open PR exists, **output a warning with the existing PR URL** and confirm with the user via AskUserQuestion whether to update the existing PR or abort.
   - If the user chooses to update, save the existing PR number for use in Step 6.

### Step 2: Detect Base Branch

#### 2-1. Extract Repository Info
- Parse `{owner}` and `{repo}` from `git remote get-url origin`.

#### 2-2. Get the Repository Default Branch (priority order)
1. GitHub MCP — retrieve repository metadata to obtain the default branch.
2. `gh api repos/{owner}/{repo} --jq .default_branch`
3. Parse `HEAD branch` from `git remote show origin`.
4. Final fallback: `main` → `master`.

#### 2-3. Detect the Actual Parent Branch
The current branch may not have been forked from the default branch (e.g., stacked PRs, `develop`-based workflows). Detect the true parent as follows:

1. List candidate base branches:
   - The default branch from 2-2.
   - Run `git branch -r` and collect remote tracking branches, excluding `HEAD` and the current branch itself.
2. For each candidate, compute the fork point:
   ```
   merge_base=$(git merge-base <candidate> HEAD)
   distance=$(git rev-list --count $merge_base..HEAD)
   ```
3. The candidate with the **smallest distance** (fewest commits from merge-base to HEAD) is the most likely parent branch.
   - If multiple candidates share the same smallest distance, prefer the default branch.

#### 2-4. Determine Final Base
- If the detected parent differs from the default branch and the distance is **strictly less** than the distance to the default branch, use the detected parent as base.
- Otherwise, use the default branch.

### Step 3: Analyze Changes

1. Retrieve the commit history with `git log <base>..HEAD --oneline`.
2. Retrieve changed file statistics with `git diff <base>...HEAD --stat`.
3. Retrieve the full diff with `git diff <base>...HEAD`.

### Step 4: Generate PR Title (Conventional Commit Format)

```
<type>(<scope>): <Korean description>
```

#### Type (use only standard types)
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc., no behavior change)
- `refactor`: Refactoring (no feature change, not a bug fix)
- `test`: Adding/modifying tests
- `chore`: Build, config, package, and other miscellaneous changes

Select the most appropriate type by comprehensively analyzing the commit history and diff.

#### Scope
- Automatically inferred from changed files/directories.
- Example: `src/auth/` changes → `auth`, `components/Button.tsx` changes → `button`
- Omit if no clear scope can be determined or the change scope is broad.

#### Description
- **Must be written in Korean.**
- Limited to 72 characters or fewer.
- Do not end with a period.
- Summarize the core changes of the entire PR in a single sentence.

### Step 5: Generate PR Body

#### Template Search
1. Search for PR templates in the repository:
   - `.github/pull_request_template.md`
   - Files within `.github/PULL_REQUEST_TEMPLATE/` directory
   - `pull_request_template.md` (root)
2. If a template is found, fill in the content following the template's format.

#### Default Template (when no template exists in the repo)
```markdown
## Summary
<!-- Summarize the core changes of the PR in 1-3 lines -->

## Changes
<!-- List major changes as bullet points -->
-
```

- Summary and Changes are auto-written **in Korean** by analyzing the commit history and diff.

#### Issue Linking
- Automatically extract issue number patterns from the branch name.
  - Supported patterns: `feature/123-description`, `fix/GH-456`, `issue-789`, `PROJ-123`, etc.
- If an issue number is found, add `Closes #123` or the corresponding issue reference at the bottom of the body.

### Step 6: Create PR

1. **If updating an existing PR** (PR number saved in Step 1):
   - Update the PR using GitHub MCP `update_pull_request`.
     - `title`: PR title generated in Step 4
     - `body`: PR body generated in Step 5. **The body must be a properly formatted multiline markdown string with actual newline characters (not literal `\n`).** Ensure all section headers, blank lines between sections, and bullet point line breaks are preserved exactly as authored.
   - Fall back to `gh pr edit` CLI if MCP fails.
2. **If creating a new PR**:
   - Create the PR using GitHub MCP `create_pull_request`.
     - `base`: Base branch determined in Step 2
     - `head`: Current branch name
     - `title`: PR title generated in Step 4
     - `body`: PR body generated in Step 5. **The body must be a properly formatted multiline markdown string with actual newline characters (not literal `\n`).** Ensure all section headers, blank lines between sections, and bullet point line breaks are preserved exactly as authored.
     - If `$ARGUMENTS` contains `--draft`, set `draft: true`.
   - Fall back to `gh pr create` CLI if MCP fails.
3. Output the created or updated PR URL to the user.

## Exclusions
- Breaking change '!' marker is not automatically added.
- Automatic reviewer and label assignment is not performed.
- User confirmation (preview) before PR creation is not performed.
