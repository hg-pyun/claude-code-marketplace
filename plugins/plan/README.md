# plan

A lightweight project-planning command for Claude Code. Conducts an in-depth interview and writes a spec file.

## Usage

| Trigger | Command | What it does |
|---------|---------|--------------|
| `/deep-interview [topic] [--lang=<value>]`, "스펙 잡아줘", "deep interview" | `deep-interview` | Asks one question at a time across the rubric (Goal / Constraints / Acceptance Criteria / Technical Direction / Open Questions / Out of Scope), writes the final spec to `.specs/deep-interview-<slug>.md`. |

Example: `/deep-interview "Linear webhook 처리 서비스" --lang=ko`

## Settings

```json
"settings": { "language": "Korean" }
```

- `language` — the default language for interview questions and the generated spec document. Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.

## Output

Spec files are written to `.specs/deep-interview-<slug>.md` in the project root. The directory is created if it does not exist. Filenames are slugified from the spec title.

## `core` dependency

None direct. After a spec is written you can optionally invoke `/code-review` or `core:critic` against the spec for a pressure-test pass.
