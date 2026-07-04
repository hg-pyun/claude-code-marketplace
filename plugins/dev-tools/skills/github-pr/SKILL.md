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

<Purpose>
Analyze the current branch's changes and create (or update) a GitHub Pull Request with a conventional-commit-style title and a body written in `$LANGUAGE`. Detects the base branch automatically and pushes the branch when needed.
</Purpose>

<Use_When>
- User asks to create a PR ("PR 만들어줘", "create a PR")
- User signals ready-for-review ("리뷰 보내줘", "send this for review")
- User invokes `/github-pr` slash command
- Branch has commits the user wants captured in a PR
</Use_When>

<Do_Not_Use_When>
- User is reviewing an existing PR (use a review tool or the PR thread)
- User asks PR status questions ("did my PR merge?") — answer directly via `gh pr view`
- User discusses PR workflow conceptually
- Current branch is the default branch (cannot PR main → main)
</Do_Not_Use_When>

<Why_This_Exists>
Writing PR titles + bodies by hand is tedious and inconsistent. This skill drafts a conventional-commit-style title from the commit log, fills in a Summary/Changes body in `$LANGUAGE` from the diff, and uses GitHub MCP to create or update the PR. Base-branch detection via reflog handles stacked PRs and unusual workflows without forcing the user to specify.
</Why_This_Exists>

<Execution_Policy>
- Use GitHub MCP tools for all GitHub operations (PR lookup/creation/update). Fall back to `gh` CLI only if MCP is unavailable. Base-branch detection is git-local first — no network call unless the local paths fail (see Step 2).
- PR title `type(scope)` parts stay English; the description portion is `$LANGUAGE`.
- PR body section headers (`## Summary`, `## Changes`) stay English; section content is `$LANGUAGE`.
- Issue links (`Closes #123`) stay English.
- The body must use real newline characters, never escaped `\n` literals.
- Automatic reviewer/label assignment is not performed.
- Breaking change `!` marker is not automatically added.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: the language setting from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.
</Settings_Reference>

<Arguments>
- `$ARGUMENTS` (optional): pass `--draft` to create a draft PR. `--lang=<value>` is also accepted and may coexist with `--draft` (e.g., `/github-pr --draft --lang=en`).
</Arguments>

<Steps>
### Step 1: Pre-validation & info gathering
**[Parallel]** Execute:
- `git status`
- `git remote get-url origin` → parse `{owner}` and `{repo}`
- `git rev-parse --abbrev-ref HEAD` → current branch name

Validate:
1. If the current branch is the default branch (main/master), abort with an error.
2. If there are uncommitted changes, warn the user but continue.

### Step 2: Detect base branch
**2-1. Get the repository default branch (local-first; network only on failure):**
1. `git symbolic-ref refs/remotes/origin/HEAD --short` → strip the `origin/` prefix. No network round-trip; succeeds on any normally-cloned repo.
2. If that ref is unset, do NOT hit the network yet — proceed to 2-2 first (reflog parent detection resolves the base in most cases without needing the default branch).
3. Network lookup only when step 1 failed AND 2-2 falls through to the default branch: GitHub MCP repository metadata, then `HEAD branch` from `git remote show origin`.
4. Final fallback: `main` → `master`.

**2-2. Detect parent branch & check remote** — **[Parallel]** Execute:
- `git reflog show <current-branch> --format='%gs' | tail -1` → parse parent branch from creation entry
- `git reflog show HEAD --format='%gs' | grep -m1 "checkout: moving from .* to <current-branch>"` → parse HEAD-reflog parent
- `git ls-remote --heads origin <current-branch-name>` → check remote branch existence

**Parent branch detection logic (priority order):**
1. **Branch reflog**: Parse the creation entry (typically `branch: Created from <parent>`).
   - If `<parent>` is a branch name (not "HEAD", not a commit hash) and exists locally or on remote → **use it as base**.
   - If `<parent>` is a branch name but no longer exists → AskUserQuestion to input the base branch manually, with the deleted branch name as context.
2. **HEAD reflog** (when branch reflog says "Created from HEAD" or contains a commit hash):
   - From `checkout: moving from <source> to <current-branch>`, extract `<source>` via `sed 's/checkout: moving from \(.*\) to .*/\1/'`.
   - Verify `<source>` is a valid local branch with `git show-ref --verify --quiet refs/heads/<source>`.
   - If valid → **use it as base**.
3. **User selection** (both reflog approaches fail — reflog expired or detached HEAD):
   - Collect candidates: default branch + any of [develop, development, staging] that exist locally.
   - AskUserQuestion to select base branch, with the default branch pre-selected as the recommended option.
4. **Final fallback:** use the default branch from Step 2-1.

**2-3. Auto-push:**
- If the remote branch doesn't exist (from `git ls-remote`), or `git log @{upstream}..HEAD --oneline` shows unpushed commits → `git push -u origin <current-branch-name>`.
- If push fails, abort with an error message.

### Step 3: Check existing PR
1. Check open PRs from current branch via GitHub MCP `list_pull_requests`.
2. If an open PR exists, output a warning with the existing PR URL and AskUserQuestion whether to update or abort.
3. If the user chooses to update, save the existing PR number for Step 7.

### Step 4: Analyze changes
**[Parallel]** Execute:
1. `git log <base>..HEAD --oneline` → commit history
2. `git diff <base>...HEAD --stat` → changed file statistics
3. `git diff <base>...HEAD` → full diff

> **Large-diff guard:** do not load a huge branch diff wholesale — when `--stat` indicates a large diff (e.g., >400 changed lines or >30 files), skip the full diff and work from `--stat` plus capped per-file excerpts (`git diff <base>...HEAD -- <file> | head -n 80`).

### Step 5: Generate PR title (Conventional Commit Format)
Per `references/conventional-commit.md`. Title `type(scope)` parts stay English; the description portion is written in `$LANGUAGE`.

### Step 6: Generate PR body
**Template search:**
- Search for PR templates with `**/pull_request_template*`.
- If multiple results, prefer `.github/pull_request_template.md`.
- If a template is found, fill its placeholders.

**Default template (when no template exists):**
```markdown
## Summary
<!-- Summarize the core changes of the PR in 1-3 lines -->

## Changes
<!-- List major changes as bullet points -->
-
```

Summary and Changes auto-written **in $LANGUAGE** by analyzing the commit history and diff. Section headers (`## Summary`, `## Changes`) stay English.

**Korean polish pass:** when the body language is Korean, polish the drafted body text with the translation-ese catalog and judgment principles from `${CLAUDE_PLUGIN_ROOT}/skills/doctor-korean-document/SKILL.md` (`<Translation_Catalog>`, `<Judgment_Principles>`, `<Protected_Regions>`) before creating the PR. This applies to the draft text in memory — it is a step of this skill, not a separate invocation of `/doctor-korean-document` (which is file-only). Code spans, identifiers, URLs, and issue links stay untouched.

### Step 7: Create or update PR
1. **If updating an existing PR** (PR number saved in Step 3):
   - Use GitHub MCP `update_pull_request`.
     - `title`: Step 5 title
     - `body`: Step 6 body
2. **If creating a new PR:**
   - Use GitHub MCP `create_pull_request`.
     - `base`: Step 2 base
     - `head`: current branch name
     - `title`: Step 5 title
     - `body`: Step 6 body
     - If `$ARGUMENTS` contains `--draft`, set `draft: true`.
3. Output the created or updated PR URL.

> **Body formatting rule:** the body must contain actual newline characters for line breaks. Never use escaped `\n` string literals — use real line breaks in the string value.
</Steps>

<Tool_Usage>
- **GitHub MCP tools** for all GitHub operations (PR lookup, repo info, PR creation/update). If an MCP call fails, output an error and abort.
- `Bash` for git local commands.
- `AskUserQuestion` for base-branch fallback selection and existing-PR update decision.
</Tool_Usage>

<Examples>
**Example 1 — first PR for the branch:**
User: "PR 만들어줘"
Flow: status/remote/branch in parallel → base = `main` via `git symbolic-ref` (no network) → push branch → no existing PR → title `feat(auth): JWT 만료 정책 추가` → body summary + changes in Korean → create PR → return URL.

**Example 2 — draft PR in English:**
User: "/github-pr --draft --lang=en"
Flow: same flow → title + body in English → `draft: true` → return URL.

**Example 3 — stacked PR:**
User: "리뷰 보내줘" (current branch was created from `feature/step-1`)
Flow: branch reflog says created from `feature/step-1` → use it as base → push if needed → create PR with base = `feature/step-1`.
</Examples>

<Final_Checklist>
- Did I detect the base branch before generating the body — local paths (symbolic-ref, reflog) first, network only on failure?
- For a large diff, did I work from `--stat` + capped per-file excerpts instead of the full diff?
- Did the title use English `type(scope)` + `$LANGUAGE` description?
- Did the body use English headers (`## Summary`, `## Changes`) and `$LANGUAGE` content?
- For a Korean body, did I run the doctor-korean-document polish pass on the draft before creating the PR?
- Did the body use real newlines (not escaped `\n`)?
- Did I return the created/updated PR URL?
</Final_Checklist>
