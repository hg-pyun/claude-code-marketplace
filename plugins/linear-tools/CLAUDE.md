# linear-tools — Maintenance Guide

Focused Linear ticket workflow plugin. Currently ships one command, `/enrich-ticket`. Repo-wide governance (versioning, author field, 9-section, language) lives in the root [CLAUDE.md](../../CLAUDE.md); this file covers per-plugin maintenance only.

## Structure
```
plugins/linear-tools/
├── .claude-plugin/plugin.json   # settings.language = Korean
├── commands/enrich-ticket.md    # the one command (self-documenting)
├── README.md                    # user-facing tour
└── CLAUDE.md                    # this guide
```
No agents, no skills, no SPEC — by design. This plugin is a thin, MCP-driven command surface.

## Command boundary
Everything here is a **command** (`commands/<name>.md`): one prompt-driven action invoked as `/<name>` or by trigger phrase. Commands MUST follow the **9-section XML house style** (root CLAUDE.md). There is intentionally no agent/skill layer — if a future need is a reusable role or a multi-phase workflow, prefer adding it to `dev-tools` rather than growing this plugin.

## Linear MCP dependency
`/enrich-ticket` requires the Linear MCP server at `https://mcp.linear.app/mcp` — without it the command cannot run.

## `$LANGUAGE`
`settings.language` defaults to `Korean`; override per-invocation with `--lang=<value>`. The command carries its own `<Settings_Reference>` block.

## Enrichment flow
The enrichment flow is documented in `commands/enrich-ticket.md`; the user-facing tour is in `README.md`.

## Adding a command
1. Author `commands/<name>.md` in the 9-section XML house style; consume `$LANGUAGE` and add a `<Settings_Reference>` block if it emits language-dependent content.
2. Bump `version` in **both** `plugins/linear-tools/.claude-plugin/plugin.json` and the linear-tools entry in `.claude-plugin/marketplace.json` (same value) — `commands/` is a source dir.
3. `bash scripts/validate.sh` — exit `0` is the gate.

## Debugging
| Symptom | Cause / fix |
|---------|-------------|
| Command can't read/write the ticket | Linear MCP not installed or not authenticated; confirm endpoint is `https://mcp.linear.app/mcp`. |
| Literal `\n` shows up in the Linear body | passed escaped newlines to the MCP — send real newlines. |
| 9-section validate failure | `commands/enrich-ticket.md` is missing one of the nine XML sections. |
| Wrong output language | pass `--lang=<value>`, or check `settings.language` in `plugin.json`. |
