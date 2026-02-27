# GitHub PR Command (Conventional Commit, Korean)

## Overview
A command that analyzes the current branch's changes and auto-creates a GitHub Pull Request with a Korean conventional commit-style title.

## Arguments
- `$ARGUMENTS`: Optional. Pass the `--draft` flag to create a draft PR.

## Tools
- Use **GitHub MCP tools** for all GitHub operations (PR lookup, repo info, PR creation/update). If an MCP call fails, output an error message and abort.
- Execute git local commands (`git status`, `git log`, `git diff`, etc.) via Bash.

## Procedure

### Step 1: Pre-validation & Info Gathering

**[Parallel]** Execute the following commands simultaneously:
- `git status`
- `git remote get-url origin` → parse `{owner}` and `{repo}`
- `git rev-parse --abbrev-ref HEAD` → current branch name

Then validate:
1. If the current branch is the default branch (main/master), abort with an error.
2. **If there are uncommitted changes**, output a warning to the user but continue.

### Step 2: Detect Base Branch

#### 2-1. Get the Repository Default Branch (priority order)
1. GitHub MCP — retrieve repository metadata to obtain the default branch.
2. Parse `HEAD branch` from `git remote show origin`.
3. Final fallback: `main` → `master`.

#### 2-2. Detect Parent Branch & Check Remote

**[Parallel]** Execute the following simultaneously:
- `git reflog show <current-branch> --format='%gs' | tail -1` → parse parent branch from creation entry
- `git ls-remote --heads origin <current-branch-name>` → check remote branch existence

**Parent branch logic:**
1. Parse the reflog creation entry (typically `branch: Created from <parent>`).
2. If a parent branch is found and exists locally or on the remote → use it as base.
3. If a parent branch is found but no longer exists → ask the user via AskUserQuestion to input the base branch manually, showing the deleted branch name as context.
4. If reflog parsing fails (no "Created from" entry, or reflog expired) → use the default branch from Step 2-1.

#### 2-3. Auto-push
- If the remote branch doesn't exist (from the `git ls-remote` result above), or if there are unpushed local commits per `git log @{upstream}..HEAD --oneline`, execute `git push -u origin <current-branch-name>`.
- If the push fails, output an error message and abort.

### Step 3: Check Existing PR

1. Check whether there is already an open PR from the current branch using GitHub MCP `list_pull_requests`.
2. If an open PR exists, **output a warning with the existing PR URL** and confirm with the user via AskUserQuestion whether to update the existing PR or abort.
3. If the user chooses to update, save the existing PR number for use in Step 7.

### Step 4: Analyze Changes

**[Parallel]** Execute the following commands simultaneously:
1. `git log <base>..HEAD --oneline` → commit history
2. `git diff <base>...HEAD --stat` → changed file statistics
3. `git diff <base>...HEAD` → full diff

### Step 5: Generate PR Title (Conventional Commit Format)

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

### Step 6: Generate PR Body

#### Template Search
- Search for PR templates using a single glob pattern: `**/pull_request_template*`
- If multiple results are found, prefer `.github/pull_request_template.md`.
- If a template is found, fill in the content following the template's format.

#### Default Template (when no template exists in the repo)
```markdown
## Summary
<!-- Summarize the core changes of the PR in 1-3 lines -->

## Changes
<!-- List major changes as bullet points -->
-
```

- Summary and Changes are auto-written **in Korean** by analyzing the commit history and diff.

### Step 7: Create or Update PR

1. **If updating an existing PR** (PR number saved in Step 3):
   - Update the PR using GitHub MCP `update_pull_request`.
     - `title`: PR title generated in Step 5
     - `body`: PR body generated in Step 6
2. **If creating a new PR**:
   - Create the PR using GitHub MCP `create_pull_request`.
     - `base`: Base branch determined in Step 2
     - `head`: Current branch name
     - `title`: PR title generated in Step 5
     - `body`: PR body generated in Step 6
     - If `$ARGUMENTS` contains `--draft`, set `draft: true`.
3. Output the created or updated PR URL to the user.

> **Body formatting rule:** The body must contain actual newline characters for line breaks. Never use escaped `\n` string literals — use real line breaks in the string value.

## Exclusions
- Breaking change '!' marker is not automatically added.
- Automatic reviewer and label assignment is not performed.
- User confirmation (preview) before PR creation is not performed.
