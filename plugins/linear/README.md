# linear

Linear workflow plugin for Claude Code. Fills in missing Linear ticket information through a focused interview, then writes the enriched content back to the ticket in `$LANGUAGE`.

## Usage

| Trigger | Command | What it does |
|---------|---------|--------------|
| `/enrich-ticket <url> [--lang=<value>]`, "이 티켓 채워줘", "enrich this ticket" | `enrich-ticket` | Reads the ticket and comments, identifies missing sections (Goal / Context / Acceptance Criteria / Technical Notes / Out of Scope / Open Questions), interviews the user one question at a time, then saves the enriched body to Linear. |

Example: `/enrich-ticket https://linear.app/acme/issue/ENG-123 --lang=en`

## Settings

```json
"settings": { "language": "Korean" }
```

- `language` — the default language for interview questions and the ticket body written back to Linear. Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.

## `core` dependency

None direct. The `core` plugin's `reviewer`/`architect` agents can be invoked separately if the user wants the enriched ticket reviewed before saving.

## Required MCP

- **Linear MCP** for reading and writing tickets. This plugin does not paste enriched content into chat as a substitute for a real ticket update.
