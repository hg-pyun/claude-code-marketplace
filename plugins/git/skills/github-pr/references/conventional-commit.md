# Conventional Commit Rules (for github-pr)

## PR Title Format
```
<type>(<scope>): <description>
```

## Type (use only standard types)
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc., no behavior change)
- `refactor`: Refactoring (no feature change, not a bug fix)
- `test`: Adding/modifying tests
- `chore`: Build, config, package, and other miscellaneous changes

Select the most appropriate type by comprehensively analyzing the commit history and diff.

## Scope
- Automatically inferred from changed files/directories.
- Example: `src/auth/` changes → `auth`, `components/Button.tsx` changes → `button`
- Omit if no clear scope can be determined or the change scope is broad.

## Description
- **Must be written in $LANGUAGE.**
- Limited to 72 characters or fewer.
- Do not end with a period.
- Summarize the core changes of the entire PR in a single sentence.
