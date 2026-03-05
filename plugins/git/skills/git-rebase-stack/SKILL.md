# Git Rebase Stack Command (Stacked PR Cleanup)

## Overview
A command that automatically cleans up stacked branches using `git rebase --onto <base> <commit> --update-refs` in situations such as base branch changes, middle PR merges/drops, and full stack synchronization during stacked PR workflows.

## Arguments
- `$ARGUMENTS`: Optional. Pass intent in natural language.
  - Examples: `develop`, `step-1 was merged, please clean up`, `rebase the entire feature/auth stack onto main`
  - If no arguments are given, the stack is automatically detected based on the currently checked-out branch.
  - If a base branch is explicitly specified, it overrides the auto-detection result.

## Core Command

```bash
# Core command for stack rebase
git rebase --onto <new-base> <old-base> --update-refs

# Example: After step-1 is merged into develop, rebase step-2 and subsequent stack onto develop
git rebase --onto develop step-1 --update-refs
```

The `--update-refs` flag automatically updates all intermediate branch refs within the stack during the rebase process.

## Procedure

### Step 1: Check Working Directory State

1. Check the current state with `git status`.
2. If there are uncommitted changes, use AskUserQuestion to provide the following options:
   - Temporarily save with `git stash` and proceed with rebase (auto `git stash pop` after completion)
   - Commit first with `git commit` before proceeding
   - Abort the rebase
3. If a clean working tree is confirmed, proceed to the next step.

### Step 2: Detect Base Branch

1. If a base branch is explicitly specified in `$ARGUMENTS`, use that branch.
2. If not specified, auto-detect:
   - Check the repository's default branch with `gh api repos/{owner}/{repo} --jq .default_branch`.
     - `{owner}` and `{repo}` are extracted from the output of `git remote get-url origin`.
   - Fall back to the `HEAD branch` output from `git remote show origin` if detection fails.
   - If all methods fail, fall back in order: `main` → `develop` → `master`.
3. Update the base branch to the latest state with `git fetch origin <base>`.

### Step 3: Analyze Stack Structure

Determine the stack structure based on Git topology.

1. Visually analyze branch relationships with `git log --oneline --graph --all --decorate`.
2. Retrieve the local branch list with `git branch --list`.
3. Trace parent-child relationships based on the current branch:
   - Check branch divergence points with `git merge-base <branch-a> <branch-b>`.
   - Determine the commit range for each branch with `git log --oneline <base>..<branch>`.
4. If needed, reference PR chain relationships using GitHub MCP `list_pull_requests` to adjust stack ordering.

**Stack topology determination:**
- Analyze whether the structure is a linear chain (A→B→C) or a fork/diamond structure.
- If a fork structure is detected, determine whether each path can be processed independently. If not possible, explain the situation to the user and confirm the approach via AskUserQuestion.

**Impact scope determination:**
- Automatically determine which branches to include as rebase targets by combining the stack structure with the intent from `$ARGUMENTS`.
- Example: If a middle PR was merged → include all branches after that branch as targets
- Example: If the base was updated → include the entire stack as targets

### Step 4: Formulate Rebase Plan and Assess Safety

Assess risk by considering rebase targets, number of commits, stack depth, conflict potential, etc.

**If risk is assessed as low** (e.g., 1-2 branches, few commits, low conflict potential):
- Output a brief summary and execute immediately.

**If risk is assessed as high** (e.g., 3+ branches, many commits, conflict potential):
- Show the user a preview including:
  - Current stack structure (branch graph)
  - Rebase execution order
  - List of affected branches and number of commits for each
  - Expected `git rebase --onto` commands
- Confirm whether to proceed via AskUserQuestion.

**Rollback preparation:**
- Automatically determine whether to create backup branches based on stack size and complexity.
- If backup is deemed necessary, create backups in the format `git branch <branch-name>-backup-rebase` for each branch.
- For simple stacks, substitute with `git reflog`-based recovery instructions.

### Step 5: Execute Rebase

1. Process branches in order starting from the bottom of the stack (closest to base).
2. Check out the target branch:
   ```bash
   git checkout <target-branch>
   ```
3. Execute the rebase:
   ```bash
   git rebase --onto <new-base> <old-base> --update-refs
   ```
4. Since `--update-refs` automatically updates intermediate branch refs within the stack, a single rebase command cleans up the entire stack.

### Step 6: Conflict Handling

If a conflict occurs during rebase:

1. Analyze the conflicting files and their contents.
2. Attempt automatic resolution:
   - Determine the semantically correct resolution through diff analysis.
   - If automatic resolution is possible, resolve, then `git add <file>` → `git rebase --continue`.
3. If automatic resolution is not possible:
   - Show the conflict contents to the user.
   - Considering the status of remaining branches in the stack, determine whether to abort entirely or apply partially:
     - If already-succeeded branches are independently valid, suggest partial application.
     - If dependencies are strong, recommend a full abort.
   - Provide options to the user via AskUserQuestion.

### Step 7: Verify Results and Report

After rebase completion:

1. Check the final stack state with `git log --oneline --graph --all --decorate`.
2. Verify that each branch is in the correct position.
3. Automatically determine the level of detail for the report:
   - **Simple case**: Success message + list of branches that need pushing
   - **Complex case**: Before/after comparison, number of changed commits, skipped commits, status of each branch
4. If backup branches were created and the rebase succeeded, provide guidance on cleaning up backup branches.

### Step 8: Optional Push

1. Show the list of branches among those affected by the rebase that have been previously pushed to remote.
2. Confirm push via AskUserQuestion:
   - Push all
   - Selective push (choose by branch)
   - Do not push
3. If push is selected, automatically determine whether to use `--force-with-lease` or `--force` based on the situation:
   - Use `--force-with-lease` by default.
   - If `--force-with-lease` fails, analyze the cause to determine whether `--force` should be used, and confirm with the user if necessary.

## Ground Rules
- All guidance, questions, and reports must be output in **Korean**.
- Do not include `Co-Authored-By` headers.
- Execute git local commands (`git status`, `git log`, `git rebase`, etc.) via Bash.
- For GitHub-related information retrieval, prioritize GitHub MCP tools, falling back to `gh` CLI on failure.

## Exclusions
- Changing the base branch of a GitHub PR is outside the scope of this command.
- Automatic test execution after rebase is not performed.
- Changes to PR metadata such as reviewers and labels are not performed.
