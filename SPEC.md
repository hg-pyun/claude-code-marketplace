# Claude Code Marketplace Spec

## Project Overview

**Project name**: claude-code-marketplace
**Marketplace name**: `hg-pyun-plugins`
**Repository**: `hg-pyun/claude-code-marketplace` (Public)
**License**: MIT

A static GitHub repository for the Claude Code plugin marketplace. Personal use today, structured to be shareable with teams or the community later. The catalog underwent a full overhaul on 2026-05-22 that trimmed unused plugins, added a shared `core` plugin, and aligned all retained plugins to a 9-section SKILL.md house style.

## Plugin Catalog (5 plugins after 2026-05-22 overhaul)

| Plugin | Purpose | Key entrypoints |
|--------|---------|-----------------|
| **core** | Shared reviewer, explorer, architect, and critic agents plus verify and code-review skills for cross-plugin orchestration. | `/core-verify`, `/code-review`, `Task(subagent_type="core:<agent>")` |
| **debug** | API debugging — execute a cURL, reverse-trace the response to source code, report root cause with file:line evidence. Optionally delegates non-trivial fix reviews to `core:reviewer`. | `/curl-debug <cURL>` |
| **git** | Git and GitHub workflows — conventional commits in `$LANGUAGE`, PR creation, stacked-PR rebase. Never includes `Co-Authored-By`. | `/git-commit`, `/github-pr [--draft]`, `/git-rebase-stack` |
| **linear** | Linear ticket enrichment — interview the user to fill missing sections (Goal / Context / Acceptance Criteria / Technical Notes / Out of Scope / Open Questions) and save back via Linear MCP. | `/enrich-ticket <url>` |
| **plan** | Lightweight in-depth interview that produces a spec file. Cover Goal / Constraints / Acceptance Criteria / Technical Direction / Open Questions / Out of Scope. | `/deep-interview [topic]` |

## Architecture

### Hybrid model

Workflow-specific assets live in their owning plugin (`git-commit` belongs to `git`; `curl-debug` belongs to `debug`). Cross-cutting agents and shared skills live in a single shared `core` plugin and are invoked across plugins via `Task(subagent_type="core:<agent>", ...)`.

### Cross-plugin invocation contract

```
Task(
  subagent_type="core:reviewer",
  prompt="<diff or content>"
)
```

The subagent_type form is `<plugin-name>:<agent-name>`. `core` is the plugin name; `hg-pyun-plugins` is the marketplace name.

### Missing-`core` fallback

Plugins that delegate to `core` must handle the case where `core` is not installed:

- Detection: Task invocation returns "unknown subagent" or equivalent error.
- Action: perform the operation inline with equivalent behavior.
- Output: append "core plugin not installed; <skill> performed locally" to the summary.

This contract preserves graceful degradation per Spec Constraint #5 below.

## Key Decisions

| Item | Decision | Rationale |
|------|----------|-----------|
| Project type | Static repository (marketplace.json + plugin files) | Minimal structure suitable for personal use |
| Source management | Monorepo (all plugins in this repository) | Consistent management in a single repository |
| Directory structure | Separated by plugin (`plugins/<name>/`) | Simple and intuitive |
| `pluginRoot` | `./plugins` | Simplifies source paths |
| Versioning | `YYYY.MM.DD[.patch]` (CLAUDE.md) | Date-based; the SPEC's earlier `YYYY.MM` text was superseded on 2026-05-22 |
| Templates | `templates/plugin/` scaffold | New plugin starting point |
| Automation | Local `scripts/validate.sh --strict`; no CI workflow | Personal marketplace; CI was an explicit Non-Goal of the 2026-05-22 overhaul |
| Cross-plugin agents | Shared `core` plugin with hybrid invocation pattern | Avoids duplication while preserving plugin-level install independence |
| 9-section SKILL.md | House style; soft-checked by `scripts/validate.sh` | Predictable scaffold; not a universal canonical |

## Directory Structure

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog (core file)
├── plugins/                    # Root directory for all plugins
│   ├── core/                   # Shared agents + skills (added 2026-05-22)
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/
│   │   │   ├── reviewer.md
│   │   │   ├── explorer.md
│   │   │   ├── architect.md
│   │   │   └── critic.md
│   │   ├── skills/
│   │   │   ├── core-verify/SKILL.md
│   │   │   └── code-review/SKILL.md
│   │   ├── README.md
│   │   ├── SPEC.md              # incl. Smoke Test Log
│   │   └── REFERENCES.md        # structural conventions credit
│   ├── debug/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── skills/curl-debug/SKILL.md
│   │   ├── README.md
│   │   └── SPEC.md
│   ├── git/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── commands/git-rebase-stack.md
│   │   ├── skills/git-commit/SKILL.md
│   │   ├── skills/github-pr/SKILL.md
│   │   └── README.md
│   ├── linear/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── commands/enrich-ticket.md
│   │   └── README.md
│   └── plan/
│       ├── .claude-plugin/plugin.json
│       ├── commands/deep-interview.md
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
| `settings.language` | conditional | Required for plugins whose output language is configurable (currently `git`, `linear`, `plan`). See CLAUDE.md `settings.language` Standard. |

## Versioning Rules

Versions follow `YYYY.MM.DD[.patch]` per CLAUDE.md. The marketplace SPEC's pre-overhaul `YYYY.MM[.patch]` notation has been superseded as of 2026-05-22.

- A plugin's `plugin.json` version and the marketplace.json entry version must stay in lock-step.
- The marketplace `metadata.version` bumps only when the catalog (entry set) changes.
- The "Multi-Phase Overhaul Exception" in CLAUDE.md permits deferring intermediate per-phase bumps when a planned overhaul touches many plugins on the same day.

## Validation

`scripts/validate.sh` is the single source of truth for local marketplace health. It performs:

0. JSON sanity of `marketplace.json` (via `jq empty`).
1. Plugin count check (must equal 5 today).
2. Orphan check — every marketplace entry has a directory; every directory has a marketplace entry.
3. Per-plugin version sync between `plugin.json` and `marketplace.json`.
4. Per-plugin `claude plugin validate --strict .` PASS.
5. Soft 9-section presence check (anchored regex, code-block stripped) for every SKILL.md and command md file.
6. Sentinel version rejection — fails if any plugin still has `0.0.0-overhaul-pending`.

Invocation: `bash scripts/validate.sh` (returns 0 on PASS, 1 on any failure). Diagnostic stderr from `claude plugin validate` surfaces directly so failures are inspectable.

CI workflow is intentionally NOT included (explicit Non-Goal of the 2026-05-22 overhaul). Add CI later if the marketplace grows to multi-contributor scale.

## Adding a Plugin

1. Copy `templates/plugin/` to `plugins/<new-name>/` and rename the template directory.
2. Update `plugins/<new-name>/.claude-plugin/plugin.json` — set `name`, `description`, `version`, `author`, optional `settings.language`.
3. Add plugin source files (commands/, skills/, hooks/, agents/, etc.) following the 9-section XML house style for any SKILL.md / command md.
4. Add an entry to `.claude-plugin/marketplace.json` `plugins` array. Keep alphabetical order via `jq '.plugins |= sort_by(.name)'` after insert.
5. Bump `version` in both `plugin.json` and `marketplace.json` per CLAUDE.md.
6. Run `bash scripts/validate.sh`. Exit 0 = PASS.
7. Commit and push.

The template scaffold includes `plugin.json` (with `author` placeholder), `README.md`, an example `SKILL.md` (9-section), and an example `command.md` (frontmatter + 9-section).

## Constraints and Notes

- **Reserved names**: `claude-code-marketplace`, `claude-code-plugins`, `anthropic-marketplace` cannot be used as marketplace names.
- **File references**: plugins cannot reference files outside their own directory using `../` paths (because they are copied to a cache directory during installation).
- **Path traversal**: `..` cannot be included in the source path.
- **Plugin names**: kebab-case, no spaces.
- **`${CLAUDE_PLUGIN_ROOT}`**: used to reference the plugin installation path in hooks and MCP server configurations.

## Plugin Language Setting (Realized State)

The 2026-05-22 overhaul realized the previously-planned language setting. Current state:

### Affected plugins

| Plugin | `settings.language` present | `$LANGUAGE` variable in body | `--lang=<value>` override |
|--------|----------------------------|------------------------------|---------------------------|
| `git` | YES (`"Korean"`) | Yes — `git-commit/SKILL.md`, `github-pr/SKILL.md` (subject/body/PR description) | Yes |
| `linear` | YES (`"Korean"`) | Yes — `enrich-ticket.md` (interview + ticket body) | Yes |
| `plan` | YES (`"Korean"`) | Yes — `deep-interview.md` (interview + spec body) | Yes |
| `debug` | No | n/a (no language-dependent artifact) | n/a |
| `core` | No | n/a (agents return findings in calling-session language) | n/a |

### git plugin language scope

`git-rebase-stack.md` is exempt — its Ground Rules continue to mandate Korean for conversational output. Only `git-commit` and `github-pr` consume `$LANGUAGE`. Within those:

- **git-commit**: subject description and body use `$LANGUAGE`; `type`/`scope`/`BREAKING CHANGE` keyword stay English.
- **github-pr**: PR description portion and body content use `$LANGUAGE`; `type(scope)` and body section headers (`## Summary`, `## Changes`) and `Closes #N` stay English.

### Language presets and custom values

Presets: Korean, English, Japanese, Chinese. ISO 639-1 codes (`ko`, `en`, `ja`, `zh`) are also accepted. Custom values (e.g., `Spanish`, `Bahasa Indonesia`) are passed through as-is.

## Smoke Tests

The `core` plugin's `SPEC.md` "Smoke Test Log" section records manual smoke-test runs of `core` agents/skills and cross-plugin wiring (most notably `debug`'s optional delegation to `core:reviewer`). See `plugins/core/SPEC.md` for the recorded prompts and pass criteria.

## Overhaul History

The 2026-05-22 overhaul (consensus-planned, reviewed) introduced these key changes:

- Removed: `ideate` (empty), `auto-harness`, `craft`, `session-harvester`.
- Added: `core` plugin (4 agents + 2 skills + governance docs).
- Aligned: `git`, `linear`, `plan`, `debug` to 9-section XML house style + `author` field + (where applicable) `settings.language`.
- New governance: `scripts/validate.sh`, `templates/plugin/`, CLAUDE.md Multi-Phase Overhaul Exception, CLAUDE.md `author` requirement, CLAUDE.md `core` invocation convention, CLAUDE.md 9-section House Style.
