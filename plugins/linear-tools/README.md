# linear-tools

> Interview-driven Linear ticket enrichment for Claude Code.

A focused plugin shipping one command, `/enrich-ticket`: it runs a guided interview and writes a structured ticket body back to Linear via the Linear MCP.

---

## Install

```shell
/plugin marketplace add hg-pyun/claude-code-marketplace
/plugin install linear-tools@hg-pyun-plugins
```

---

## Commands

| Entrypoint | Type | One-liner |
|------------|------|-----------|
| `/enrich-ticket` | command | Linear ticket interview-fill in `$LANGUAGE`. |

### `/enrich-ticket <url> [--lang=<value>]`

Reads a Linear ticket plus its comments and linked issues, conducts a guided interview to fill the missing rubric sections (Goal / Context / Acceptance Criteria / Technical Notes / Out of Scope / Open Questions), and writes the enriched body back via the Linear MCP. Rubric headers stay English; content uses `$LANGUAGE`.

Korean trigger phrases (e.g. `"이 티켓 채워줘"`, `"linear 티켓 보완해줘"`) work in addition to the slash command.

---

## Settings

```json
"settings": { "language": "Korean" }
```

| Variable | Default | Override |
|----------|---------|----------|
| `$LANGUAGE` | `Korean` | `--lang=<value>` per invocation |

Presets: Korean, English, Japanese, Chinese. ISO 639-1 codes (`ko`, `en`, `ja`, `zh`) are accepted. Custom strings (`Spanish`, `Bahasa Indonesia`) are passed through verbatim.

Structural section headers (`## Goal`, `## Acceptance Criteria`, …) stay English; only their content is translated.

---

## Requirements

| MCP | Required by | Fallback |
|-----|-------------|----------|
| **Linear** | `/enrich-ticket` | none — Linear MCP is required |

Install and authenticate the Linear MCP server before invoking `/enrich-ticket`.

---

## License

MIT — inherited from the marketplace root.
