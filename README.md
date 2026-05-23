# claude-code-marketplace

> Personal Claude Code plugin marketplace — `hg-pyun-plugins`.

A static GitHub-hosted marketplace shipping a single bundled plugin, **`dev-tools`**, that combines specialist agents, an end-to-end orchestration pipeline, and day-to-day git / GitHub / Linear helpers.

---

## Quickstart

```shell
# 1. Add the marketplace
/plugin marketplace add hg-pyun/claude-code-marketplace

# 2. Install the plugin
/plugin install dev-tools@hg-pyun-plugins

# 3. Pull updates later
/plugin marketplace update
```

That's it. One install path; everything below ships in the same plugin.

---

## What's inside

| Plugin | Description | Docs |
|--------|-------------|------|
| **dev-tools** | Unified toolkit — 9 specialist agents (reviewer / explorer / architect / critic / executor / test-engineer / doc-writer / performance-analyst / security-auditor) and 11 entrypoints across orchestration (`/autopilot`, `/deep-interview`, `/ralplan`, `/ralph`, `/team`), review & debugging (`/code-review`, `/curl-debug`), git & GitHub (`/git-commit`, `/github-pr`, `/git-rebase-stack`), and Linear (`/enrich-ticket`). | [README](plugins/dev-tools/README.md) · [SPEC](plugins/dev-tools/SPEC.md) |

For the marketplace's own architecture, schemas, validation rules, and governance, see **[SPEC.md](SPEC.md)**.

---

## Validation

Run the local validator before every commit or PR:

```shell
bash scripts/validate.sh
```

It runs `claude plugin validate --strict` against every plugin, then checks JSON sanity, plugin count, orphans, version sync between `plugin.json` and `marketplace.json`, the 9-section SKILL.md house style, and the canonical version format. Exit `0` = PASS. See [SPEC.md → Validation](SPEC.md#validation) for the full check list and the opt-in `--descriptors` lane for artifact metadata.

---

## Adding a new plugin

The catalog currently ships one bundled plugin. If a future addition warrants a separate package:

1. Copy `templates/plugin/` to `plugins/<new-name>/` and rename the directory.
2. Edit `plugins/<new-name>/.claude-plugin/plugin.json` — set `name`, `description`, `version`, `author` (object form), and `settings.language` if any output is language-dependent.
3. Author source files following the [9-section XML house style](CLAUDE.md#9-section-skillmd-house-style).
4. Append an entry to `.claude-plugin/marketplace.json` `plugins`; keep alphabetical order via `jq '.plugins |= sort_by(.name)'`.
5. Bump `version` in both `plugin.json` and the matching marketplace.json entry per [CLAUDE.md](CLAUDE.md), and update the validator's expected plugin count.
6. Run `bash scripts/validate.sh`. Exit `0` is the gate.
7. Commit and push.

---

## License

MIT — see [LICENSE](LICENSE).
