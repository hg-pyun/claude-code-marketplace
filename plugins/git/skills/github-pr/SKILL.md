---
name: github-pr
description: >
  Auto-create or update GitHub Pull Requests with conventional commit-style titles.
  Detects base branch, generates PR title and description from branch commits,
  links related issues, and creates the PR via GitHub API.
  TRIGGER when: user asks to create a PR, open a pull request, push changes for review,
  or send work upstream
  (e.g., "PR 만들어줘", "PR 날려", "풀리퀘 생성해줘", "풀리퀘스트 올려줘",
  "리뷰 보내줘", "리뷰 올려줘", "이거 PR 해줘", "푸시하고 PR 만들어",
  "코드 리뷰 요청해줘", "이 브랜치 올려줘",
  "create a PR", "open a pull request", "send this for review", "push this up for review").
  Also trigger with /github-pr slash command.
  DO NOT TRIGGER when: user is reviewing an existing PR, asking about PR status,
  or discussing PR workflow without intent to create one now.
---

# GitHub PR Skill (Conventional Commit, Korean)

## Overview
A skill that analyzes the current branch's changes and auto-creates a GitHub Pull Request with a Korean conventional commit-style title.

## Settings Reference
- `$LANGUAGE`: The language setting from plugin.json `settings.language`.
  Override with `--lang=<value>` argument.
  Presets: Korean, English, Japanese, Chinese.
  Custom values also accepted (e.g., Spanish, Bahasa Indonesia).

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
- `git reflog show HEAD --format='%gs' | grep -m1 "checkout: moving from .* to <current-branch>"` → parse HEAD-reflog parent
- `git ls-remote --heads origin <current-branch-name>` → check remote branch existence

**Parent branch detection logic (in priority order):**

1. **Branch reflog**: Parse the creation entry (typically `branch: Created from <parent>`).
   - If `<parent>` is a branch name (not "HEAD", not a commit hash) and exists locally or on remote → **use it as base**.
   - If `<parent>` is a branch name but no longer exists → ask the user via AskUserQuestion to input the base branch manually, showing the deleted branch name as context.

2. **HEAD reflog** (when branch reflog says "Created from HEAD" or contains a commit hash):
   - From the HEAD reflog entry `checkout: moving from <source> to <current-branch>`, extract `<source>` using: `echo "<entry>" | sed 's/checkout: moving from \(.*\) to .*/\1/'`
   - Verify `<source>` is a valid local branch: `git show-ref --verify --quiet refs/heads/<source>`
   - If valid → **use it as base**.

3. **User selection** (when both reflog approaches fail — e.g., reflog expired or detached HEAD):
   - Collect candidate branches: [default branch from Step 2-1] + any of [develop, development, staging] that exist locally.
   - Ask the user via AskUserQuestion to select the base branch from the candidate list, with the default branch pre-selected as the recommended option.

4. **Final fallback**: use the default branch from Step 2-1.

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

Generate the PR title according to `references/conventional-commit.md`.

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

- Summary and Changes are auto-written **in $LANGUAGE** by analyzing the commit history and diff.

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
