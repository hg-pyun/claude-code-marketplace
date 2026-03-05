# Git Commit Command (Conventional Commit, Korean)

## Overview
A command that analyzes git diff to auto-generate a Korean conventional commit message and execute the commit.

## Procedure

### Step 1: Check Changes
1. Run `git status` to check the current state.
2. If there are no staged changes, automatically stage all changes with `git add -A`.
3. If there are no changes at all (clean working tree), inform the user and abort.

### Step 2: Diff Analysis
1. Retrieve the full diff of staged changes with `git diff --cached`.
2. Retrieve the list of changed files and statistics with `git diff --cached --stat`.

### Step 3: Determine Whether to Split the Commit
After analyzing the diff, use the AskUserQuestion tool to ask the user whether to split the commit.

**Information to provide in the question:**
- Show the list of changed files with a brief summary of changes for each file.
- If splitting seems beneficial, include a recommended split plan (files and message summary for each commit) in the option description.

**AskUserQuestion options:**
- **"Commit all at once" (Recommended)**: Create a single commit with all changes.
- **"Split commits"**: Split into multiple commits according to the suggested plan.

**If the user selects "Split commits":**
- Automatically sort commit order considering dependencies and logical sequence (e.g., infrastructure → logic → tests).
- Execute `git add <files>` → `git commit` sequentially for each group.

**If the user selects "Commit all at once":**
- Proceed directly to Step 4.

### Step 4: Generate Commit Message
Generate the commit message according to the following rules.

#### Conventional Commit Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

#### Type (use only standard types)
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc., no behavior change)
- `refactor`: Refactoring (no feature change, not a bug fix)
- `test`: Adding/modifying tests
- `chore`: Build, config, package, and other miscellaneous changes

#### Scope
- Automatically inferred from changed files/directories.
- Example: `src/auth/` changes → `auth`, `components/Button.tsx` changes → `button`
- Omit if no clear scope can be determined.

#### Subject
- **Must be written in Korean.**
- Limited to 72 characters or fewer.
- Do not end with a period.
- Write in descriptive form, not imperative.
- Example: `feat(auth): 로그인 페이지에 소셜 로그인 기능 추가`

#### Body
- **Must be written in Korean.**
- List changes using bullet points (-).
- Each item explains "what" was changed and "why."
- Include a blank line between subject and body.
- Example:
  ```
  - OAuth2 기반 Google, GitHub 소셜 로그인 연동
  - 기존 이메일 로그인과 소셜 계정 자동 연결 처리
  - 소셜 로그인 실패 시 에러 핸들링 추가
  ```

#### Footer
- Include in footer if a BREAKING CHANGE is detected.
- Determine BREAKING CHANGE by comprehensively analyzing the diff contents.
  - Consider public API signature changes, function/method removals, required parameter additions, return type changes, export removals, etc.
- If there is a BREAKING CHANGE, describe the details in the footer.
- Example:
  ```
  feat(api): 사용자 인증 API 응답 형식 변경

  - 기존 flat 구조에서 nested 구조로 응답 형식 변경
  - access_token 필드명을 accessToken으로 변경

  BREAKING CHANGE: 인증 API 응답의 JSON 구조가 변경되어 기존 클라이언트 코드 수정 필요
  ```
- Do not include issue references.

### Step 5: Execute Commit
- Execute `git commit` with the generated message immediately (without user confirmation).
- Do not include a Co-Authored-By header.
- After a successful commit, show the result to the user with `git log --oneline -1`.

## Exclusions
- Merge commits and revert commits are not targets of this command.
- Issue/ticket number references are not included.

## Arguments
This command does not accept `$ARGUMENTS`. It always operates based on the current git state.
