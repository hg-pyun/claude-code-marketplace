# claude-code-marketplace

> Personal Claude Code plugin marketplace — `hg-pyun-plugins`.

A static GitHub-hosted marketplace with three plugins: **`buddy`** (a Socratic "thinking partner" — its `/deep-interview` draws out your own design decisions), **`dev-tools`** (multi-agent orchestration, code review, git/GitHub, debugging), and **`linear-tools`** (Linear ticket enrichment via MCP).

---

## Quickstart

```shell
# 1. Add the marketplace
/plugin marketplace add hg-pyun/claude-code-marketplace

# 2. Install plugins (pick what you need)
/plugin install buddy@hg-pyun-plugins
/plugin install dev-tools@hg-pyun-plugins
/plugin install linear-tools@hg-pyun-plugins

# 3. Pull updates later
/plugin marketplace update
```

Install only the plugins you need; each is independently versioned.

---

## What's inside

| Plugin | Description | Docs |
|--------|-------------|------|
| **buddy** | A Socratic "thinking partner" — `/deep-interview` asks one question at a time so you make the design decisions yourself. | [README](plugins/buddy/README.md) |
| **dev-tools** | Multi-agent dev toolkit — 16 specialist agents and 10 entrypoints: orchestration (`/autopilot`, `/ralplan`, `/ralph`, `/team`), review & debugging (`/code-review`, `/curl-debug`), git & GitHub (`/git-commit`, `/github-pr`, `/git-rebase-stack`), setup (`/install-statusline`). | [README](plugins/dev-tools/README.md) · [CLAUDE](plugins/dev-tools/CLAUDE.md) |
| **linear-tools** | Interview-driven Linear ticket enrichment — `/enrich-ticket` writes a structured ticket body back via the Linear MCP. | [README](plugins/linear-tools/README.md) |

For the marketplace's own architecture, schemas, validation rules, and governance, see **[CLAUDE.md](CLAUDE.md)**.

---

## Validation

Run the local validator before every commit or PR:

```shell
bash scripts/validate.sh
```

It runs `claude plugin validate --strict` against every plugin, then checks JSON sanity, plugin count, orphans, version sync between `plugin.json` and `marketplace.json`, the 9-section SKILL.md house style, and the canonical version format. Exit `0` = PASS. See [CLAUDE.md → Validation](CLAUDE.md#validation) for the full check list and the opt-in `--descriptors` lane for artifact metadata.

---

## Adding a new plugin

The catalog currently ships three plugins. To add another:

1. Copy `templates/plugin/` to `plugins/<new-name>/` and rename the directory.
2. Edit `plugins/<new-name>/.claude-plugin/plugin.json` — set `name`, `description`, `version`, `author` (object form), and `settings.language` if any output is language-dependent.
3. Replace the scaffold's placeholder `commands/EXAMPLE.md` / `skills/EXAMPLE/SKILL.md` with your real entrypoints, authored in the [9-section XML house style](CLAUDE.md#9-section-house-style).
4. Append an entry to `.claude-plugin/marketplace.json` `plugins`; keep alphabetical order via `jq '.plugins |= sort_by(.name)'`.
5. Bump `version` in both `plugin.json` and the matching marketplace.json entry per [CLAUDE.md](CLAUDE.md), and update the validator's expected plugin count.
6. Run `bash scripts/validate.sh`. Exit `0` is the gate.
7. Commit and push.

---

## License

MIT — see [LICENSE](LICENSE).
