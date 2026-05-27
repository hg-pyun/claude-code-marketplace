# linear-tools — Plugin Working Guide

Focused Linear ticket workflow plugin. Currently ships one command, `/enrich-ticket`. Repo-wide governance (versioning, author field, 9-section, language) lives in the root [CLAUDE.md](../../CLAUDE.md); this file is the linear-tools working guide.

## Structure
```
plugins/linear-tools/
├── .claude-plugin/plugin.json   # settings.language = Korean
├── commands/enrich-ticket.md    # the one command
├── README.md                    # user-facing tour
└── CLAUDE.md                    # this guide
```
No agents, no skills, no SPEC — by design. This plugin is a thin, MCP-driven command surface.

## Command boundary
Everything here is a **command** (`commands/<name>.md`): one prompt-driven action invoked as `/<name>` or by trigger phrase. Commands MUST follow the **9-section XML house style** (root CLAUDE.md). There is intentionally no agent/skill layer — if a future need is a reusable role or a multi-phase workflow, prefer adding it to `dev-tools` rather than growing this plugin.

## Linear MCP dependency
`/enrich-ticket` **requires** the Linear MCP server (read via `get_issue` / `list_comments`, write via `save_issue`). There is no fallback — without the MCP the command cannot run.
- **Transport note**: the legacy `/sse` transport is deprecated. Use the streamable HTTP endpoint `https://mcp.linear.app/mcp` (migration guide: `https://linear.app/docs/mcp`).
- **String values**: pass real newlines in markdown content to MCP tools, not literal `\n` escapes.

## `enrich-ticket` pattern
A focused, interview-driven enrichment — *not* a full deep-interview (no ambiguity gating). The flow:
1. **Read** the ticket (`get_issue`) + comments (`list_comments`); offer to pull linked Notion/GitHub URLs.
2. **Gap analysis** against the rubric: Goal / Context / Acceptance Criteria / Technical Notes / Out of Scope / Open Questions.
3. **Interview** one question at a time (`AskUserQuestion`) in `$LANGUAGE`, only for missing sections; never re-ask what the ticket already states.
4. **Draft** the body — rubric headers stay English, content in `$LANGUAGE`; omit empty sections.
5. **Write back** via `save_issue` (preserve title unless asked); surface the resulting URL.
Never invent technical detail the user didn't confirm — mark unresolved items in Open Questions instead.

## `$LANGUAGE`
`settings.language` defaults to `Korean`; override per-invocation with `--lang=<value>` (presets Korean/English/Japanese/Chinese; ISO codes `ko`/`en`/`ja`/`zh`; custom strings pass through). Applies to interview prompts **and** the ticket body written to Linear. Section headers stay English.

## Adding a command
1. Author `commands/<name>.md` in the 9-section XML house style; consume `$LANGUAGE` and add a `<Settings_Reference>` block if it emits language-dependent content.
2. Bump `version` in **both** `plugins/linear-tools/.claude-plugin/plugin.json` and the linear-tools entry in `.claude-plugin/marketplace.json` (same value) — `commands/` is a source dir.
3. `bash scripts/validate.sh` — exit `0` is the gate.

## Debugging
| Symptom | Cause / fix |
|---------|-------------|
| Command can't read/write the ticket | Linear MCP not installed or not authenticated; check the endpoint isn't the deprecated `/sse`. |
| Literal `\n` shows up in the Linear body | passed escaped newlines to the MCP — send real newlines. |
| 9-section validate failure | `commands/enrich-ticket.md` is missing one of the nine XML sections. |
| Wrong output language | pass `--lang=<value>`, or check `settings.language` in `plugin.json`. |
