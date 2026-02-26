# GitHub PR Command (Conventional Commit, Korean)

## Overview
A command that analyzes the current branch's changes and auto-creates a GitHub Pull Request with a Korean conventional commit-style title.

## Arguments
- `$ARGUMENTS`: Optional. Pass the `--draft` flag to create a draft PR.

## Tool Priority
- For GitHub-related tasks (PR lookup, repo info, etc.), **prioritize GitHub MCP tools**.
- Fall back to `gh` CLI only if MCP tools fail or are unavailable.
- **Exception: PR creation** prioritizes `gh pr create` CLI. (MCP tools have an issue where newlines in multiline body are rendered as literal `\n`.)
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
   - If an open PR exists, **output a warning with the existing PR URL** and confirm with the user via AskUserQuestion whether to continue.

### Step 2: Detect Default Branch

1. Check the repository's default branch with `gh api repos/{owner}/{repo} --jq .default_branch`.
   - `{owner}` and `{repo}` are extracted from the output of `git remote get-url origin`.
2. Fall back to the `HEAD branch` output from `git remote show origin` if detection fails.
3. If all methods fail, fall back in order: `main` → `master`.

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

1. Create the PR using `gh pr create` CLI.
   - The body must be passed using a HEREDOC (`<<'EOF'`). (Do not use MCP tools as they have an issue where newlines in multiline body are rendered as literal `\n`.)
   - Example:
     ```
     gh pr create --title "title" --body "$(cat <<'EOF'
     ## Summary
     content...

     ## Changes
     - change 1
     EOF
     )"
     ```
   - `--base`: Default branch detected in Step 2
   - `--head`: Current branch name
   - If `$ARGUMENTS` contains `--draft`, add the `--draft` flag.
2. Output the created PR URL to the user.

## Exclusions
- Breaking change '!' marker is not automatically added.
- Automatic reviewer and label assignment is not performed.
- User confirmation (preview) before PR creation is not performed.
