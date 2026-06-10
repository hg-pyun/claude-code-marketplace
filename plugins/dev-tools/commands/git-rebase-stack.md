---
description: >
  Clean up stacked branches via `git rebase --onto <base> <commit> --update-refs`
  when the base changes, a middle PR merges or drops, or the whole stack needs to
  re-sync. Auto-detects the stack from the current branch when no argument is given.
  TRIGGER when: user mentions stacked PR rebase, base branch change, stack
  cleanup, or says phrases like "step-1 머지됐어 정리해줘", "stack 정리해줘",
  "리베이스 좀", "git rebase stack", "rebase the entire feature/auth stack onto main".
  DO NOT TRIGGER when: user is doing a single-branch rebase or interactive
  fixup that does not involve stacked PRs.
argument-hint: optional base branch name or natural-language intent
---

<Purpose>
Automatically clean up a stack of branches using `git rebase --onto <base> <old-base> --update-refs` so the whole stack stays consistent when the base changes, a middle PR merges, or branches need re-synced. The single rebase command updates every intermediate ref via `--update-refs`.
</Purpose>

<Use_When>
- The base of a stacked-PR chain has changed and intermediate branches need updating
- A middle PR in the stack merged (or was dropped) and the rest of the stack needs to rebase onto the new tip
- The user wants the entire stack synced to the current default branch
- The user invokes `/git-rebase-stack` with optional natural-language intent
</Use_When>

<Do_Not_Use_When>
- Single-branch rebase (no stack) — use `git rebase` directly
- Interactive rebase or fixup of a single branch
- The user wants to change a GitHub PR's base branch (out of scope)
- The user wants automatic test execution after rebase (out of scope)
</Do_Not_Use_When>

<Why_This_Exists>
Stacked PRs are powerful but error-prone to maintain by hand. `--update-refs` (introduced in git 2.38) updates intermediate branch refs in a single rebase, but only if the invoker knows the right `<old-base>` for `--onto`. This command auto-detects the stack topology from `git log --graph` + branch reflogs, picks the right invocation, and offers backup branches when the stack is complex enough that recovery via `git reflog` alone would be painful.
</Why_This_Exists>

<Execution_Policy>
- All guidance, questions, and reports must be output in Korean (this command is exempt from the `settings.language` mechanism per the marketplace SPEC).
- **NEVER** include a `Co-Authored-By` trailer in any commit. Adding `Co-Authored-By` headers to AI-generated commits is strictly prohibited.
- Execute git operations via `Bash`.
- For GitHub-related lookups, prioritize GitHub MCP; fall back to `gh` CLI on failure.
- Out of scope: changing a PR's base branch on GitHub; running tests after rebase; modifying PR metadata.
</Execution_Policy>

<Arguments>
- `$ARGUMENTS` (optional): natural-language intent.
  - Examples: `develop`, `step-1 was merged, please clean up`, `rebase the entire feature/auth stack onto main`
  - If no arguments are given, the stack is auto-detected from the currently checked-out branch.
  - If a base branch is explicitly named, it overrides the auto-detection result.
</Arguments>

<Steps>
### Step 1: Check working tree state
1. Run `git status`.
2. If uncommitted changes exist, AskUserQuestion with options:
   - Stash temporarily with `git stash` and proceed (auto `git stash pop` after completion)
   - Commit first with `git commit` before proceeding
   - Abort the rebase
3. If clean, proceed.

### Step 2: Detect base branch
1. If `$ARGUMENTS` names a base branch, use that.
2. Otherwise auto-detect:
   - Default branch via `gh api repos/{owner}/{repo} --jq .default_branch` (owner/repo from `git remote get-url origin`).
   - Fall back to `HEAD branch` from `git remote show origin` if detection fails.
   - Final fallback: `main` → `develop` → `master`.
3. Update the base branch to latest with `git fetch origin <base>`.

### Step 3: Analyze stack structure
1. Visualize branches with `git log --oneline --graph --all --decorate`.
2. Retrieve local branches via `git branch --list`.
3. Trace parent-child relationships:
   - `git merge-base <branch-a> <branch-b>` for divergence points.
   - `git log --oneline <base>..<branch>` for per-branch commit ranges.
4. Optionally consult GitHub MCP `list_pull_requests` for PR chain relationships.

**Stack topology:**
- Detect linear chain (A→B→C) vs fork/diamond.
- If fork: AskUserQuestion to confirm independent-path processing or abort.

**Impact scope:**
- Combine stack + `$ARGUMENTS` intent to choose rebase targets.
- Middle PR merged → include all branches after that branch.
- Base updated → include entire stack.

### Step 4: Formulate rebase plan and assess safety
**Low risk** (1-2 branches, few commits): brief summary + immediate execution.

**High risk** (3+ branches, many commits, conflict potential): preview including:
- Current stack structure (branch graph)
- Rebase execution order
- Affected branches + commit counts
- Expected `git rebase --onto` commands

Confirm via AskUserQuestion.

**Rollback preparation:**
- Auto-decide backup branches by stack size/complexity.
- If needed: `git branch <branch-name>-backup-rebase` per branch.
- For simple stacks: rely on `git reflog`-based recovery instructions.

### Step 5: Execute rebase
Route execution by the Step 4 risk assessment:

**Low risk (1–2 branches):** execute inline in the main session via `Bash` — no delegation:
```
git rebase --onto <new-base> <old-base> --update-refs
```
On success proceed to Step 7; on conflict stop and proceed to Step 6 with the conflict output.

**High risk (3+ branches, many commits, conflict potential):** delegate the mechanical rebase execution to `git-master` via Task — the verbose conflict output and retry loop benefit from context isolation:

```
Task(subagent_type="git-master", prompt="""
Execute the rebase plan below. Process branches in the order listed (bottom-up, closest to base first).

@handoff-in
kind: handoff
path: null
sizeBytes: <inline>
note: Execute each rebase in order; surface conflict context if any; do NOT auto-push.

Rebase plan:
- target branch: <target-branch>
- command: git rebase --onto <new-base> <old-base> --update-refs
- backup branches already created: <yes/no and names>
- stop on conflict: return conflict context to caller without resolving ambiguous hunks

Return @handoff-out with status complete (all branches rebased) or failed (unresolvable conflict
or 3-failure limit). Include fresh `git log --oneline --graph --decorate -10` output.
""")
```

git-master runs the git commands and returns results. The command reads `@handoff-out`:
- `status: complete` → proceed to Step 7.
- `status: failed` → surface the conflict context and proceed to Step 6.

### Step 6: Conflict handling
On conflict (inline rebase stopped, or git-master returned `status: failed` with conflict context):
1. Review the conflict context — conflicting files and hunk details, from the inline rebase output or git-master's report.
2. If the conflict is clearly safe to auto-resolve (non-overlapping hunks): the main session decides the resolution and applies it **inline via `Bash`** — `git add <file(s)>` → `git rebase --continue`. Do NOT dispatch a second git-master instance for the continuation.
3. If unsafe or ambiguous:
   - Show conflict details to user.
   - AskUserQuestion: partial application (if succeeded branches are independently valid) vs full abort.

### Step 7: Verify results and report
1. Check final state with `git log --oneline --graph --all --decorate`.
2. Verify each branch lands correctly.
3. Report (auto-detail-level):
   - **Simple:** success + push list.
   - **Complex:** before/after, changed commit counts, skipped commits, per-branch status.
4. If backups created and rebase succeeded, suggest backup cleanup.

### Step 8: Optional push
1. List affected branches that have remote tracking.
2. AskUserQuestion: push all / selective push / no push.
3. On push:
   - Default `--force-with-lease`.
   - On `--force-with-lease` failure: analyze cause, optionally confirm `--force`.
</Steps>

<Tool_Usage>
- `Task(subagent_type="git-master", …)` for high-risk rebase execution only (Step 5, 3+ branches). Pass the rebase plan as an `@handoff-in` block; read `@handoff-out` to route on `status`.
- `Bash` for Steps 1–4 and 6–8 plus low-risk Step 5 execution (working-tree checks, base detection, stack topology, inline rebase, conflict continuation via `git add` + `git rebase --continue`, verification, push). git-master owns the rebase Bash only on the high-risk path; the command owns everything else.
- GitHub MCP (priority) and `gh` CLI (fallback) for PR/repo lookups.
- `AskUserQuestion` at decision points (uncommitted changes, fork ambiguity, high-risk preview, ambiguous conflict resolution, push selection). The command — not git-master — owns all user interaction.
</Tool_Usage>

<Examples>
**Example 1 — middle PR merged (low risk, inline):**
사용자: "step-1 머지됐어 정리해줘"
흐름: clean tree → detect base = `develop` → stack = [step-1, step-2, step-3] → step-1 was merged into develop → low risk (effectively one rebase) → main session runs `git rebase --onto develop step-1 --update-refs` inline → backups not needed → push with `--force-with-lease`.

**Example 2 — base update (high risk, git-master):**
사용자: "전체 스택 develop으로 리베이스"
흐름: stash dirty tree → base = develop → 5-branch chain → preview shown → user confirms → create 5 backup branches → delegate rebase to git-master → git-master returns `status: failed` with one conflict → non-overlapping hunks → main session resolves inline (`git add` → `git rebase --continue`) → report before/after → push all selectively.

**Example 3 — fork structure:**
사용자: "/git-rebase-stack"
흐름: detect fork (two independent paths from common base) → AskUserQuestion: process each path independently or abort → user picks independent → execute each fork separately.
</Examples>

<Final_Checklist>
- Working tree clean (or stashed) before rebase began?
- Base branch correctly detected (or user-specified)?
- Stack topology determined and confirmed with user when ambiguous?
- Backup branches created when complexity warranted?
- Risk-based routing honored (low risk → inline Bash; high risk → git-master; conflict continuation always inline)?
- `--update-refs` used so intermediate branch refs propagate?
- Final report generated; backup cleanup guidance offered?
- No `Co-Authored-By` trailer anywhere?
</Final_Checklist>
