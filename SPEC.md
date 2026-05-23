# Marketplace Spec — `hg-pyun-plugins`

Architecture, schemas, conventions, and validation rules for the **`claude-code-marketplace`** repository.

For the user-facing entry, see [README.md](README.md). For per-file governance (versioning, author field, language settings, house style), see [CLAUDE.md](CLAUDE.md).

---

## Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Directory structure](#directory-structure)
- [`marketplace.json` schema](#marketplacejson-schema)
- [`plugin.json` schema](#pluginjson-schema)
- [Versioning](#versioning)
- [Validation](#validation)
- [Adding a plugin](#adding-a-plugin)
- [Constraints](#constraints)
- [Plugin language setting](#plugin-language-setting)
- [Consolidation history](#consolidation-history)

---

## Overview

| Field | Value |
|-------|-------|
| Repository | `hg-pyun/claude-code-marketplace` (public) |
| Marketplace name | `hg-pyun-plugins` |
| License | MIT |
| Plugin count | 1 (`dev-tools`) |
| Versioning | `YYYY.MM.DD[.patch]` |
| Automation | Local `scripts/validate.sh`; no CI workflow |

A static GitHub repository serving the Claude Code plugin marketplace protocol. Personal use today, structured to be shareable later.

---

## Architecture

### Single-plugin model

All assets live inside `plugins/dev-tools/`. Skills and commands invoke bundled agents via the Task tool with the **bare agent name** — no plugin prefix, because everything ships together:

```text
Task(subagent_type="reviewer", prompt="…")
Task(subagent_type="executor", prompt="…")
```

The prior `core:<agent>` invocation form and the "missing-`core` fallback" contract were removed in the 2026-05-22.1 consolidation. They are not needed inside a single plugin.

### Why single-plugin

| Concern | Multi-plugin | Single-plugin (current) |
|---------|--------------|-------------------------|
| Install paths | 5 separate installs to get the full toolkit | 1 install |
| Cross-plugin wiring | Required `core:` prefix + fallback shim | Bare agent names |
| Version drift | 5 versions to keep in lock-step | 1 version |
| Discoverability | Users had to know which sub-plugin owned which agent | Flat catalog |

The bundle trades the option of installing a subset for a dramatically simpler invocation contract. Given this is a personal marketplace with cohesive toolchain semantics, the bundle wins.

---

## Directory structure

```
claude-code-marketplace/
├── .claude-plugin/
│   └── marketplace.json        # Marketplace catalog (1 entry)
├── plugins/
│   └── dev-tools/          # Unified plugin
│       ├── .claude-plugin/plugin.json
│       ├── agents/             # reviewer, explorer, architect, critic, executor,
│       │                       # test-engineer, doc-writer, performance-analyst,
│       │                       # security-auditor
│       ├── commands/           # enrich-ticket, git-rebase-stack
│       ├── skills/             # autopilot, deep-interview, ralplan, ralph, team,
│       │                       # code-review, curl-debug, git-commit, github-pr
│       ├── scripts/            # cleanup.sh (.specs/<slug>/ retention purge)
│       │                       # test-cleanup.sh (red test)
│       ├── README.md
│       └── SPEC.md
├── scripts/
│   ├── validate.sh                    # Marketplace-level strict validation gate
│   └── test-validate-descriptors.sh   # Red test for validate.sh --descriptors lane
├── templates/
│   └── plugin/                 # Scaffold for new plugins
├── CLAUDE.md                   # Per-file governance + invocation conventions
├── LICENSE                     # MIT
├── README.md                   # Marketplace entry doc
└── SPEC.md                     # This document
```

---

## `marketplace.json` schema

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
      "description": "<one-line>",
      "version": "YYYY.MM.DD[.patch]",
      "keywords": ["..."]
    }
  ]
}
```

### Plugin entry fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Y | Plugin identifier (kebab-case). |
| `source` | Y | Path to the plugin directory (`./plugins/<name>` format). No `..` allowed. |
| `description` | Y | One-line description. |
| `version` | Y | `YYYY.MM.DD[.patch]` — **must match** `plugins/<name>/.claude-plugin/plugin.json`. |
| `keywords` | N | Search keywords. |

`metadata.version` bumps only when the catalog itself changes (entry added, removed, or renamed). Per-plugin file edits do not require a metadata bump.

---

## `plugin.json` schema

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
| `name` | Y | Must match the `marketplace.json` entry. |
| `description` | Y | One-line description. |
| `version` | Y | Format per [CLAUDE.md](CLAUDE.md); must match the marketplace.json entry. |
| `author` | Y | **Object form only** — `{ "name": "…" }`. String form is rejected by `claude plugin validate --strict`. |
| `settings.language` | conditional | Required when the plugin ships language-dependent artifacts. `dev-tools` sets `Korean` for `git-commit`, `github-pr`, `enrich-ticket`, `deep-interview`. |

---

## Versioning

Format: `YYYY.MM.DD[.patch]`.

A plugin's `plugin.json` version and its `marketplace.json` entry version must stay in lock-step. The exception is the documented **multi-phase overhaul** rule in [CLAUDE.md](CLAUDE.md), which permits deferred version bumps for planned same-day refactors.

| Current version | Today's date | Next version |
|-----------------|--------------|--------------|
| Earlier than today | — | `YYYY.MM.DD` |
| `YYYY.MM.DD` | Same as today | `YYYY.MM.DD.1` |
| `YYYY.MM.DD.N` | Same as today | `YYYY.MM.DD.(N+1)` |

---

## Validation

`scripts/validate.sh` is the single source of truth for local marketplace health.

### Default lane

```shell
bash scripts/validate.sh
```

Runs all of:

0. `marketplace.json` is valid JSON (`jq empty`).
1. Plugin count equals 1 (`dev-tools`).
2. Orphan check — every `marketplace.json` entry has a directory; every directory has an entry.
3. Per-plugin version sync between `plugin.json` and `marketplace.json`.
4. Per-plugin `claude plugin validate --strict .` PASS (diagnostic stderr surfaces directly).
5. Canonical version format gate — fails on anything not `YYYY.MM.DD[.N]`.
6. Soft 9-section presence check on every `SKILL.md` and command md (anchored regex; fenced code blocks stripped). `README.md` is excluded.

Exit `0` = PASS, `1` = any failure.

### Descriptors lane

Opt-in lane for the artifact hand-off descriptor schema (see [plugin SPEC](plugins/dev-tools/SPEC.md)):

```shell
bash scripts/validate.sh --descriptors                   # incremental (default)
bash scripts/validate.sh --descriptors --all             # full .specs/ traversal
bash scripts/validate.sh --descriptors --target=<path>   # single-file check
bash scripts/validate.sh --descriptors --help
```

The descriptor lane is separate so existing CI flows don't break.

---

## Adding a plugin

If a future addition warrants a separate package:

1. Copy `templates/plugin/` to `plugins/<new-name>/` and rename the directory.
2. Edit `plugins/<new-name>/.claude-plugin/plugin.json` — set `name`, `description`, `version`, `author` (object form), optional `settings.language`.
3. Author source files following the 9-section XML house style. README.md is exempt.
4. Append an entry to `.claude-plugin/marketplace.json` `plugins`; keep alphabetical order:

   ```shell
   jq '.plugins |= sort_by(.name)' .claude-plugin/marketplace.json | sponge .claude-plugin/marketplace.json
   ```

5. Bump `version` in both `plugin.json` and the matching marketplace.json entry per [CLAUDE.md](CLAUDE.md); update the validator's expected plugin count in `scripts/validate.sh`.
6. Run `bash scripts/validate.sh`. Exit `0` is the gate.
7. Commit and push.

---

## Constraints

- **Reserved marketplace names**: `claude-code-marketplace`, `claude-code-plugins`, `anthropic-marketplace`. Cannot be used as a marketplace name.
- **No `..` in `source`**: path traversal is rejected. Plugins also cannot reference files outside their own directory at runtime, because installation copies them to a cache directory.
- **Plugin names**: kebab-case, no spaces.
- **`${CLAUDE_PLUGIN_ROOT}`**: use this to reference the plugin installation path inside hooks and MCP server configs.

---

## Plugin language setting

`dev-tools` exposes `settings.language` (default `Korean`). Consumed by:

| Asset | `$LANGUAGE` use | `--lang=<value>` override |
|-------|----------------|---------------------------|
| `skills/git-commit/SKILL.md` | Commit subject + body | Yes |
| `skills/github-pr/SKILL.md` | PR body content | Yes |
| `commands/enrich-ticket.md` | Interview prompts + Linear body | Yes |
| `skills/deep-interview/SKILL.md` | Interview prompts + spec body | Yes |
| `commands/git-rebase-stack.md` | n/a — always Korean per marketplace SPEC | n/a |
| `skills/curl-debug/SKILL.md` | n/a — no static artifact | n/a |
| `skills/code-review/SKILL.md` | n/a — calling-session language | n/a |
| `agents/*.md` | n/a — calling-session language | n/a |

**Presets**: Korean, English, Japanese, Chinese. ISO 639-1 codes (`ko`, `en`, `ja`, `zh`) are also accepted. Custom values (e.g. `Spanish`, `Bahasa Indonesia`) are passed through verbatim.

---

## Consolidation history

| Date | Change |
|------|--------|
| **2026-05-22** | Marketplace overhaul — removed unused plugins, introduced the shared `core` plugin, adopted the 9-section XML house style across every SKILL.md / command md. |
| **2026-05-22.1** | Consolidation — merged the 5-plugin layout (`core`, `debug`, `git`, `linear`, `plan`) into a single unified `dev-tools`. The `core:<agent>` prefix was retired across all skills, and the missing-`core` fallback contract was removed from `code-review` and `curl-debug`. Marketplace `metadata.version` bumped from `2026.05.22` → `2026.05.22.1`. |
| **2026-05-23** | Introduced the artifact hand-off descriptor schema (`kind` / `path` / `contentHash` / `createdAt` / `producer` / `sizeBytes` / `retention` / `expiresAt` / `status`), the `--descriptors` validation lane, and the `.specs/<slug>/` storage layout with `state/`, `artifacts/ask/`, `notepads/`, and `events.jsonl`. Cleanup script for session / day retention added. |
