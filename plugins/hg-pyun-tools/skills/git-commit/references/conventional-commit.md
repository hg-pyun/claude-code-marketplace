# Conventional Commit Rules (for git-commit)

## Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

## Type (use only standard types)
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc., no behavior change)
- `refactor`: Refactoring (no feature change, not a bug fix)
- `test`: Adding/modifying tests
- `chore`: Build, config, package, and other miscellaneous changes

## Scope
- Automatically inferred from changed files/directories.
- Example: `src/auth/` changes → `auth`, `components/Button.tsx` changes → `button`
- Omit if no clear scope can be determined.

## Subject
- **Must be written in $LANGUAGE.**
- Limited to 72 characters or fewer.
- Do not end with a period.
- Write in descriptive form, not imperative.
- Example: `feat(auth): 로그인 페이지에 소셜 로그인 기능 추가`

## Body
- **Must be written in $LANGUAGE.**
- List changes using bullet points (-).
- Each item explains "what" was changed and "why."
- Include a blank line between subject and body.
- Example:
  ```
  - OAuth2 기반 Google, GitHub 소셜 로그인 연동
  - 기존 이메일 로그인과 소셜 계정 자동 연결 처리
  - 소셜 로그인 실패 시 에러 핸들링 추가
  ```

## Footer
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
