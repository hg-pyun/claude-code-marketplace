# Claude Code Marketplace Spec

## Project Overview

**Project name**: claude-code-marketplace
**Marketplace name**: `hg-pyun-plugins`
**Repository**: `hg-pyun/claude-code-marketplace` (Public)
**License**: MIT

A static GitHub repository for the Claude Code plugin marketplace. Personal use today, structured to be shareable with teams or the community later. After the 2026-05-22 consolidation the catalog ships a single unified plugin (`hg-pyun-tools`) that bundles the assets that previously lived in five separate plugins.

## Plugin Catalog (1 unified plugin)

| Plugin | Purpose | Key entrypoints |
|--------|---------|-----------------|
| **hg-pyun-tools** | Unified toolkit — shared `reviewer`/`explorer`/`architect`/`critic` agents plus git+GitHub workflows, Linear ticket enrichment, deep-interview planning, cURL debugging, and code review/verify skills. | `/git-commit`, `/github-pr [--draft]`, `/git-rebase-stack`, `/enrich-ticket <url>`, `/deep-interview [topic]`, `/curl-debug <cURL>`, `/code-review`, `/core-verify`, `Task(subagent_type="reviewer"|"explorer"|"architect"|"critic")` |

## Architecture

### Single-plugin model

All assets live inside `plugins/hg-pyun-tools/`. Skills and commands invoke the bundled agents via `Task(subagent_type="<agent>", ...)` without a plugin prefix because everything ships together. The previous "missing-`core` fallback" contract is no longer needed and has been removed from all artifacts.

### Agent invocation contract

```
Task(
  subagent_type="reviewer",
  prompt="<diff or content>"
)
```

`subagent_type` is the bare agent name (`reviewer`, `explorer`, `architect`, `critic`). The marketplace name (`hg-pyun-plugins`) and plugin name (`hg-pyun-tools`) are container labels, not part of the invocation form.

## Key Decisions

| Item | Decision | Rationale |
|------|----------|-----------|
| Project type | Static repository (marketplace.json + plugin files) | Minimal structure suitable for personal use |
| Source management | Monorepo (all plugin assets in this repository) | Consistent management in a single repository |
| Directory structure | Single bundled plugin under `plugins/hg-pyun-tools/` | One install path, no cross-plugin wiring |
| `pluginRoot` | `./plugins` | Simplifies source paths |
| Versioning | `YYYY.MM.DD[.patch]` (CLAUDE.md) | Date-based |
| Templates | `templates/plugin/` scaffold | Starting point if the catalog grows again |
| Automation | Local `scripts/validate.sh --strict`; no CI workflow | Personal marketplace |
| 9-section SKILL.md | House style; soft-checked by `scripts/validate.sh` | Predictable scaffold |

## Directory Structure

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog (1 entry)
├── plugins/                    # Root directory for plugins
│   └── hg-pyun-tools/          # Unified plugin
│       ├── .claude-plugin/plugin.json
│       ├── agents/
│       │   ├── reviewer.md
│       │   ├── explorer.md
│       │   ├── architect.md
│       │   └── critic.md
│       ├── commands/
│       │   ├── git-rebase-stack.md
│       │   ├── enrich-ticket.md
│       │   └── deep-interview.md
│       ├── skills/
│       │   ├── code-review/SKILL.md
│       │   ├── core-verify/SKILL.md
│       │   ├── git-commit/SKILL.md
│       │   ├── git-commit/references/conventional-commit.md
│       │   ├── github-pr/SKILL.md
│       │   ├── github-pr/references/conventional-commit.md
│       │   └── curl-debug/SKILL.md
│       └── README.md
├── scripts/
│   └── validate.sh             # Strict local validation gate
├── templates/
│   └── plugin/                 # Scaffold for new plugins
├── CLAUDE.md                   # Per-file governance + invocation conventions
├── LICENSE                     # MIT
├── README.md                   # Project description and usage
└── SPEC.md                     # This document
```

## `marketplace.json` Schema

```json
{
  "name": "hg-pyun-plugins",
  "owner": { "name": "hg-pyun" },
  "metadata": {
    "description": "Personal Claude Code plugin marketplace by hg-pyun",
    "version": "YYYY.MM.DD[.patch]",
    "pluginRoot": "./plugins"
  },
  "plugins": [
    {
      "name": "<plugin-name>",
      "source": "./plugins/<plugin-name>",
      "description": "<one-line description>",
      "version": "YYYY.MM.DD[.patch]",
      "keywords": ["..."]
    }
  ]
}
```

### Plugin entry fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Y | Plugin identifier (kebab-case) |
| `source` | Y | Plugin directory path (`./plugins/<name>` format) |
| `description` | Y | Plugin description |
| `version` | Y | `YYYY.MM.DD[.patch]` (see CLAUDE.md) — must match `plugins/<name>/.claude-plugin/plugin.json` |
| `keywords` | N | Array of search keywords |

The marketplace `metadata.version` bumps when the catalog itself changes (entry added, removed, or renamed). Per-plugin file edits do not require a metadata bump.

## `plugin.json` Schema (per-plugin)

```json
{
  "name": "<plugin-name>",
  "description": "<one-line>",
  "version": "YYYY.MM.DD[.patch]",
  "author": { "name": "hg-pyun" },
  "settings": {
    "language": "Korean"
  }
}
```

### Fields

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Y | Must match the marketplace.json entry |
| `description` | Y | One-line description |
| `version` | Y | Format per CLAUDE.md; must match marketplace.json entry version |
| `author` | Y | **Object form** `{ "name": "..." }`. String form is rejected by `claude plugin validate --strict`. |
| `settings.language` | conditional | Required for plugins whose output language is configurable. `hg-pyun-tools` sets `Korean` because it ships language-dependent artifacts (`git-commit`, `github-pr`, `enrich-ticket`, `deep-interview`). |

## Versioning Rules

Versions follow `YYYY.MM.DD[.patch]` per CLAUDE.md.

- A plugin's `plugin.json` version and the marketplace.json entry version must stay in lock-step.
- The marketplace `metadata.version` bumps only when the catalog (entry set) changes.

## Validation

`scripts/validate.sh` is the single source of truth for local marketplace health. It performs:

0. JSON sanity of `marketplace.json` (via `jq empty`).
1. Plugin count check (must equal 1 today — `hg-pyun-tools`).
2. Orphan check — every marketplace entry has a directory; every directory has a marketplace entry.
3. Per-plugin version sync between `plugin.json` and `marketplace.json`.
4. Per-plugin `claude plugin validate --strict .` PASS.
5. Soft 9-section presence check (anchored regex, code-block stripped) for every SKILL.md and command md file.
6. Canonical-version gate — fails if any plugin version is not in `YYYY.MM.DD[.N]` form.

Invocation: `bash scripts/validate.sh` (returns 0 on PASS, 1 on any failure). Diagnostic stderr from `claude plugin validate` surfaces directly so failures are inspectable.

## Adding a Plugin

The marketplace today contains a single bundled plugin. If a future addition warrants a separate package:

1. Copy `templates/plugin/` to `plugins/<new-name>/` and rename the template directory.
2. Update `plugins/<new-name>/.claude-plugin/plugin.json` — set `name`, `description`, `version`, `author`, optional `settings.language`.
3. Add plugin source files following the 9-section XML house style.
4. Add an entry to `.claude-plugin/marketplace.json` `plugins` array (alphabetical via `jq '.plugins |= sort_by(.name)'`).
5. Bump `version` in both `plugin.json` and `marketplace.json` per CLAUDE.md, and update the validator's expected plugin count.
6. Run `bash scripts/validate.sh`. Exit 0 = PASS.
7. Commit and push.

## Constraints and Notes

- **Reserved names**: `claude-code-marketplace`, `claude-code-plugins`, `anthropic-marketplace` cannot be used as marketplace names.
- **File references**: plugins cannot reference files outside their own directory using `../` paths (because they are copied to a cache directory during installation).
- **Path traversal**: `..` cannot be included in the source path.
- **Plugin names**: kebab-case, no spaces.
- **`${CLAUDE_PLUGIN_ROOT}`**: used to reference the plugin installation path in hooks and MCP server configurations.

## Plugin Language Setting

`hg-pyun-tools` exposes `settings.language` (default `Korean`). It is consumed by:

| Asset | `$LANGUAGE` usage | `--lang=<value>` override |
|-------|------------------|---------------------------|
| `skills/git-commit/SKILL.md` | Subject + body of the commit message | Yes |
| `skills/github-pr/SKILL.md` | PR description content + body content | Yes |
| `commands/enrich-ticket.md` | Interview questions + Linear ticket body | Yes |
| `commands/deep-interview.md` | Interview questions + spec document body | Yes |
| `commands/git-rebase-stack.md` | n/a — always Korean per marketplace SPEC | n/a |
| `skills/curl-debug/SKILL.md` | n/a — no language-dependent artifact | n/a |
| `skills/code-review/SKILL.md`, `skills/core-verify/SKILL.md` | n/a — output uses the calling session's language | n/a |
| `agents/*.md` | n/a — output uses the calling session's language | n/a |

### Language presets and custom values

Presets: Korean, English, Japanese, Chinese. ISO 639-1 codes (`ko`, `en`, `ja`, `zh`) are also accepted. Custom values (e.g., `Spanish`, `Bahasa Indonesia`) are passed through as-is.

## Consolidation History

The 2026-05-22.1 consolidation merged the prior five-plugin catalog (`core`, `debug`, `git`, `linear`, `plan`) into a single unified `hg-pyun-tools` plugin. Notable effects:

- One install path instead of five — `/plugin install hg-pyun-tools@hg-pyun-plugins`.
- `core:<agent>` invocation prefix removed across all skills and commands — agents are invoked as `subagent_type="<agent>"`.
- Missing-`core` fallback contract removed from `code-review`, `core-verify`, and `curl-debug` (no longer applicable inside a single bundled plugin).
- Marketplace metadata version bumped from `2026.05.22` → `2026.05.22.1` to reflect the catalog change.

The 2026-05-22 overhaul that preceded this consolidation (removal of unused plugins, addition of the shared `core` plugin, 9-section house style) remains the source of the current per-asset structure.
