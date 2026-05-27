# claude-code-marketplace — Project Guidelines

## 30-second picture
- **What this is**: `hg-pyun-plugins`, a personal Claude Code plugin marketplace (static GitHub repo, MIT). It ships **2 plugins**:
  - `dev-tools` — 9 specialist agents + orchestration / review / debugging / git+GitHub skills.
  - `linear-tools` — focused Linear ticket workflow (`/enrich-ticket`).
- **Where things live**: plugin source under `plugins/<name>/`; the marketplace catalog in `.claude-plugin/marketplace.json`; the local health gate `scripts/validate.sh`; the new-plugin scaffold in `templates/plugin/`.
- **Where to go next**:
  - Working *inside* a plugin → that plugin's `plugins/<name>/CLAUDE.md` (auto-loaded; the detailed working guide).
  - Installing / using as an end user → `README.md` (root) and `plugins/<name>/README.md`.
  - Governance, conventions, schemas, validation → **this file** (the single repo-wide spec surface; there is no separate `SPEC.md`).

## Directory layout
```
claude-code-marketplace/
├── .claude-plugin/marketplace.json   # Catalog (2 entries)
├── plugins/
│   ├── dev-tools/                    # agents/ commands/ skills/ scripts/ README.md CLAUDE.md
│   │   └── .claude-plugin/plugin.json
│   └── linear-tools/                 # commands/ README.md CLAUDE.md
│       └── .claude-plugin/plugin.json
├── scripts/
│   ├── validate.sh                   # Marketplace health gate (default + --descriptors lanes)
│   └── test-validate-descriptors.sh  # Red test for the descriptors lane
├── templates/plugin/                 # Scaffold for new plugins
├── CLAUDE.md   ← this file            # Governance + conventions + reference
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
| Work inside a plugin | open that plugin's `CLAUDE.md` |

---

# Authoring rules

## Plugin Version Management
When modifying, adding, or deleting **source** files under `plugins/<name>/` — i.e. `commands/`, `skills/`, `agents/`, `hooks/`, and `.claude-plugin/plugin.json` — the version **must** be bumped. Doc-only files (`README.md`, `CLAUDE.md`, `REFERENCES.md`, and other markdown outside those source dirs) do **not** require a bump (e.g. a README typo fix, or refreshing a REFERENCES.md attribution).

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
Every `plugins/<plugin>/skills/<skill>/SKILL.md` and `plugins/<plugin>/commands/<command>.md` MUST include all nine XML body sections, in order: `<Purpose>` · `<Use_When>` · `<Do_Not_Use_When>` · `<Why_This_Exists>` · `<Execution_Policy>` · `<Steps>` · `<Tool_Usage>` · `<Examples>` · `<Final_Checklist>`. Optional supplements (`<Settings_Reference>`, `<Arguments>`, …) are allowed. Use the XML tag form, not Markdown headers. `README.md` and `CLAUDE.md` are exempt. `scripts/validate.sh` runs a soft presence check.

## Agent invocation convention
`dev-tools` bundles shared agents (`reviewer`, `explorer`, `architect`, `critic`, `executor`, `test-engineer`, `doc-writer`, `performance-analyst`, `security-auditor`). Skills and commands delegate via the Task tool with the **bare agent name** — no plugin prefix, because everything ships in one plugin:
```
Task(subagent_type="reviewer", prompt="…")
```
The prior `core:<agent>` form and missing-`core` fallback contract were removed in the 2026-05-22.1 consolidation.

## `settings.language` standard
Plugins whose output language is configurable (commit messages, PR bodies, ticket content, spec docs) MUST expose `settings.language` in `plugin.json`:
```json
"settings": { "language": "Korean" }
```
Default `Korean`; per-invocation override `--lang=<value>`. Presets: Korean, English, Japanese, Chinese (ISO 639-1 `ko`/`en`/`ja`/`zh` accepted; custom strings passed through). Language-dependent assets reference the variable as `$LANGUAGE` and carry a `<Settings_Reference>` block.

**Per-asset `$LANGUAGE` use:**
| Plugin | Asset | `$LANGUAGE` use |
|--------|-------|-----------------|
| dev-tools | `skills/git-commit`, `skills/github-pr`, `skills/deep-interview` | commit subject/body · PR body · interview + spec body |
| dev-tools | `commands/git-rebase-stack` | exempt — always Korean per SPEC |
| dev-tools | `skills/curl-debug`, `skills/code-review`, `agents/*` | exempt — calling-session language, no static artifact |
| linear-tools | `commands/enrich-ticket` | interview prompts + Linear body |

---

# Reference

## Architecture
`dev-tools` bundles related tools used together (agents + orchestration + git/GitHub). `linear-tools` is separate because the Linear-MCP workflow is a distinct concern with a different MCP dependency — bundling it would force every `dev-tools` user to carry that surface. Each plugin is independently installable and versioned; there is no cross-plugin dependency.

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

**Default lane** — `bash scripts/validate.sh` runs: (0) `marketplace.json` valid JSON; (1) plugin count == 2; (2) orphan check (entry↔directory); (3) per-plugin version sync; (4) `claude plugin validate --strict .` per plugin; (5) canonical version format; (6) soft 9-section presence on every `SKILL.md` / command md (README & CLAUDE.md excluded). Exit `0` = PASS.

**Descriptors lane** (opt-in; artifact hand-off descriptor schema — see `plugins/dev-tools/CLAUDE.md`):
```shell
bash scripts/validate.sh --descriptors                  # incremental (default)
bash scripts/validate.sh --descriptors --all            # full .specs/ traversal
bash scripts/validate.sh --descriptors --target=<path>  # single file
```

## Adding a plugin
1. Copy `templates/plugin/` to `plugins/<new-name>/`; rename.
2. Edit `.claude-plugin/plugin.json` — `name`, `description`, `version`, `author` (object), optional `settings.language`. Add a `CLAUDE.md` per the per-plugin pattern.
3. Author source files in the 9-section XML house style (README & CLAUDE.md exempt).
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
| 9-section check fails | the SKILL.md / command md is missing one of the nine XML sections (README & CLAUDE.md are exempt). |
| descriptors lane fails on a legacy artifact | use the default `--descriptors` (incremental) lane; legacy `.specs` files aren't re-validated unless modified. |
