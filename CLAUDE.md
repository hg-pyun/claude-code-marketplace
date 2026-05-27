# claude-code-marketplace — Maintainer Guide

> **Scope.** This file is the maintainer's guide to **the repository** (`hg-pyun-plugins`): the catalog, versioning, validation, and the repo-wide authoring conventions a maintainer enforces. It is **not** a manual for how the plugins *operate* — that is self-documented in each plugin's source (`plugins/<name>/agents/*.md`, `skills/*/SKILL.md`) and the artifact hand-off contract in `scripts/validate.sh`. Keep plugin-operation detail out of this file.

## 30-second picture
- **What this is**: `hg-pyun-plugins`, a personal Claude Code plugin marketplace (static GitHub repo, MIT). It ships **2 plugins**:
  - `dev-tools` — 16 specialist agents (4 lanes: Build/Analysis · Review · Domain · Coordination) + orchestration / review / debugging / git+GitHub skills.
  - `linear-tools` — focused Linear ticket workflow (`/enrich-ticket`).
- **Where things live**: plugin source under `plugins/<name>/`; the catalog in `.claude-plugin/marketplace.json`; the local health gate `scripts/validate.sh`; the new-plugin scaffold in `templates/plugin/`; the local cross-skill hand-off workspace `.dt-handoff/<slug>/` (gitignored).
- **Where to go next**:
  - Maintaining the repo (add / version / validate a plugin, catalog edits) → **this file**.
  - How an agent or skill *works* → its own source file (`agents/<name>.md`, `skills/<name>/SKILL.md`) — they are self-documenting.
  - The artifact hand-off contract (descriptor fields, enums, `@handoff` blocks, `verdict`) → the header of `scripts/validate.sh` (machine source of truth + human mirror).
  - Per-plugin maintenance notes → that plugin's `plugins/<name>/CLAUDE.md` (thin).
  - Installing / using as an end user → `README.md` (root) and `plugins/<name>/README.md`.

## Directory layout
```
claude-code-marketplace/
├── .claude-plugin/marketplace.json   # Catalog (2 entries)
├── plugins/
│   ├── dev-tools/                    # agents/ (16) commands/ skills/ scripts/ README.md CLAUDE.md
│   │   └── .claude-plugin/plugin.json
│   └── linear-tools/                 # commands/ README.md CLAUDE.md
│       └── .claude-plugin/plugin.json
├── scripts/
│   ├── validate.sh                   # Health gate (default + --descriptors lanes); header = hand-off contract mirror
│   └── test-validate-descriptors.sh  # Red test for the descriptors lane
├── templates/plugin/                 # Scaffold for new plugins
├── .dt-handoff/<slug>/               # Local hand-off artifact workspace (gitignored; spec/plan/prd/…)
├── CLAUDE.md   ← this file            # Repository maintainer guide
├── README.md                         # Marketplace entry doc (external)
└── LICENSE
```

## Workflows index
| Task | Where |
|------|-------|
| Add a new plugin | [Adding a plugin](#adding-a-plugin) below |
| Bump a version | [Plugin Version Management](#plugin-version-management) below |
| Validate the repo | `bash scripts/validate.sh` → [Validation](#validation) below |
| Commit / open a PR | `/git-commit`, `/github-pr` (dev-tools skills) |
| Understand how a plugin works | open that plugin's source (`agents/*.md`, `skills/*/SKILL.md`) |
| Per-plugin maintenance notes | open that plugin's `CLAUDE.md` (thin) |

---

# Authoring rules (repo-wide)

These are the conventions a maintainer enforces on every plugin. They are repo governance — *not* plugin operation.

## Plugin Version Management
When modifying, adding, or deleting **source** files under `plugins/<name>/` — i.e. `commands/`, `skills/`, `agents/`, `hooks/`, and `.claude-plugin/plugin.json` — the version **must** be bumped. Doc-only files (`README.md`, `CLAUDE.md`, and other markdown outside those source dirs) do **not** require a bump (e.g. a README typo fix).

**Bump both locations to the same value:**
1. `plugins/<name>/.claude-plugin/plugin.json` → `version`
2. `.claude-plugin/marketplace.json` → the matching plugin entry's `version`

**Version format** `YYYY.MM.DD[.patch]`, determined by the current date:

| Current version | Condition | New version |
|-----------------|-----------|-------------|
| Earlier than today | — | `YYYY.MM.DD` |
| `YYYY.MM.DD` (today) | same day | `YYYY.MM.DD.1` |
| `YYYY.MM.DD.N` (today) | same day | `YYYY.MM.DD.(N+1)` |

**Pre-commit checklist**: plugin.json bumped? marketplace.json entry bumped to match? both values identical?

**Multi-phase overhaul exception**: a single planned overhaul touching multiple plugins, committed in multiple phases on the **same calendar day**, may defer to one final-phase bump — *if* the plan is documented, intermediate commits note "no version bump per overhaul exception", and the final phase syncs every modified plugin's `plugin.json` and `marketplace.json` entry. Crossing a day boundary reverts to the per-file rule.

## `author` field
Every `plugins/<name>/.claude-plugin/plugin.json` MUST set `author` in **object form**:
```json
"author": { "name": "hg-pyun" }
```
String form (`"author": "hg-pyun"`) is rejected by `claude plugin validate --strict` (`expected object, received string`). Add `email` etc. to the object as needed.

## 9-section house style
Every `plugins/<plugin>/skills/<skill>/SKILL.md` and `plugins/<plugin>/commands/<command>.md` MUST include all nine XML body sections, in order: `<Purpose>` · `<Use_When>` · `<Do_Not_Use_When>` · `<Why_This_Exists>` · `<Execution_Policy>` · `<Steps>` · `<Tool_Usage>` · `<Examples>` · `<Final_Checklist>`. Optional supplements (`<Settings_Reference>`, `<Arguments>`, …) are allowed. Use the XML tag form, not Markdown headers. `README.md` and `CLAUDE.md` are exempt; **agents** (`agents/*.md`) are exempt too (they use a richer self-documented section set). `scripts/validate.sh` runs a soft presence check on SKILL.md / command md only.

## `settings.language` standard
Plugins whose output language is configurable (commit messages, PR bodies, ticket content, spec docs) MUST expose `settings.language` in `plugin.json`:
```json
"settings": { "language": "Korean" }
```
Default `Korean`; per-invocation override `--lang=<value>`. Presets: Korean, English, Japanese, Chinese (ISO 639-1 `ko`/`en`/`ja`/`zh` accepted; custom strings passed through). Each language-dependent asset references the variable as `$LANGUAGE` and carries its own `<Settings_Reference>` block — consult the asset's source for which fields it governs. (Agents emit in the calling-session language and have no static artifact, so they are exempt.)

## Plugin internals (not documented here)
Agents are bundled in `dev-tools` and invoked by **bare name** from skills/commands — `Task(subagent_type="reviewer", …)` — with no plugin prefix, because everything ships in one plugin. The agent roster, lane structure, role boundaries, model routing, and the skill↔agent hand-off contract (descriptor, `@handoff-in`/`@handoff-out`, `verdict`) are self-documented in `plugins/dev-tools/agents/*.md`, `plugins/dev-tools/skills/*/SKILL.md`, and the `scripts/validate.sh` header. This file deliberately does not duplicate them.

---

# Reference

## Architecture
`dev-tools` bundles related tools used together (agents + orchestration + git/GitHub). `linear-tools` is separate because the Linear-MCP workflow is a distinct concern with a different MCP dependency — bundling it would force every `dev-tools` user to carry that surface. Each plugin is independently installable and versioned; there is no cross-plugin dependency. *(Use this when deciding where a new tool belongs: a reusable role/workflow that fits the dev toolkit → `dev-tools`; a distinct external-dependency concern → its own plugin.)*

## `marketplace.json` schema
Catalog with `name`, `owner.name`, `metadata` (`description`, `version`, `pluginRoot: ./plugins`), and a `plugins` array. Entry fields:

| Field | Req | Description |
|-------|-----|-------------|
| `name` | Y | Plugin identifier (kebab-case). |
| `source` | Y | `./plugins/<name>`. No `..`. |
| `description` | Y | One line. |
| `version` | Y | `YYYY.MM.DD[.patch]`; **must match** the plugin's `plugin.json`. |
| `keywords` | N | Search keywords. |

`metadata.version` bumps only when the catalog itself changes (entry added/removed/renamed) — not for per-plugin file edits.

## `plugin.json` schema
| Field | Req | Notes |
|-------|-----|-------|
| `name` | Y | Matches the marketplace entry. |
| `description` | Y | One line. |
| `version` | Y | Format above; matches the marketplace entry. |
| `author` | Y | Object form only (`{ "name": "…" }`). |
| `settings.language` | cond. | Required when the plugin ships language-dependent artifacts. |

## Validation
`scripts/validate.sh` is the single source of truth for local marketplace health.

**Default lane** — `bash scripts/validate.sh` runs: (0) `marketplace.json` valid JSON; (1) plugin count == 2; (2) orphan check (entry↔directory); (3) per-plugin version sync; (4) `claude plugin validate --strict .` per plugin; (5) canonical version format; (6) soft 9-section presence on every `SKILL.md` / command md (README, CLAUDE.md & agents excluded). Exit `0` = PASS.

**Descriptors lane** (opt-in; validates hand-off artifact descriptors — the schema lives in the `scripts/validate.sh` header):
```shell
bash scripts/validate.sh --descriptors                  # incremental (default)
bash scripts/validate.sh --descriptors --all            # full .dt-handoff/ traversal
bash scripts/validate.sh --descriptors --target=<path>  # single file
```

## Adding a plugin
1. Copy `templates/plugin/` to `plugins/<new-name>/`; rename.
2. Edit `.claude-plugin/plugin.json` — `name`, `description`, `version`, `author` (object), optional `settings.language`. Add a thin `CLAUDE.md` per the per-plugin pattern.
3. Author source files in the 9-section XML house style (README & CLAUDE.md & agents exempt).
4. Append an entry to `.claude-plugin/marketplace.json` `plugins`, keep it sorted:
   `jq '.plugins |= sort_by(.name)' .claude-plugin/marketplace.json | sponge …`
5. Bump `version` in both `plugin.json` and the marketplace entry; update the expected plugin count in `scripts/validate.sh`.
6. `bash scripts/validate.sh` — exit `0` is the gate. Then commit.

## Constraints
- Reserved marketplace names: `claude-code-marketplace`, `claude-code-plugins`, `anthropic-marketplace`.
- No `..` in `source`; plugins cannot reference files outside their own dir at runtime (install copies to a cache dir).
- Plugin names: kebab-case, no spaces.
- Use `${CLAUDE_PLUGIN_ROOT}` to reference the install path inside hooks / MCP configs.

## Quick troubleshooting
| Symptom | Fix |
|---------|-----|
| `validate.sh` fails on version | plugin.json and marketplace.json entry must match, format `YYYY.MM.DD[.N]`. |
| `expected object, received string` | `author` must be object form. |
| 9-section check fails | the SKILL.md / command md is missing one of the nine XML sections (README, CLAUDE.md & agents are exempt). |
| descriptors lane fails on a legacy artifact | use the default `--descriptors` (incremental) lane; legacy `.dt-handoff` files aren't re-validated unless modified. |
