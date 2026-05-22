# Claude Code Marketplace for personal

Personal Claude Code plugin marketplace (`hg-pyun-plugins`). After the 2026-05-22 consolidation, this marketplace ships a single unified plugin (`hg-pyun-tools`) bundling all agents, commands, and skills.

## Usage

### Add marketplace

```shell
/plugin marketplace add hg-pyun/claude-code-marketplace
```

### Install the plugin

```shell
/plugin install hg-pyun-tools@hg-pyun-plugins
```

### Update marketplace

```shell
/plugin marketplace update
```

## Plugin

- [hg-pyun-tools](plugins/hg-pyun-tools/README.md) — Unified toolkit: shared `reviewer`/`explorer`/`architect`/`critic` agents + `/git-commit`, `/github-pr`, `/git-rebase-stack`, `/enrich-ticket`, `/deep-interview`, `/curl-debug`, `/code-review`.

See [SPEC.md](SPEC.md) for architecture, directory structure, and design decisions.

## Adding a Plugin

The marketplace today contains a single bundled plugin. If a future addition warrants a separate package:

1. Copy `templates/plugin/` to `plugins/<plugin-name>/` and rename the template directory.
2. Update `plugins/<plugin-name>/.claude-plugin/plugin.json` — set `name`, `description`, `version`, `author`, optional `settings.language`.
3. Add plugin source files (commands/, skills/, hooks/, agents/) following the 9-section XML house style for any SKILL.md / command.md.
4. Add an entry to `.claude-plugin/marketplace.json` `plugins` array; keep alphabetical order via `jq '.plugins |= sort_by(.name)'` after insert.
5. Bump `version` in both `plugin.json` and `marketplace.json` per [CLAUDE.md](CLAUDE.md), and update the validator's expected plugin count.
6. Run `bash scripts/validate.sh`. Exit 0 = PASS.
7. Commit and push.

## Validation

Run the local validator before committing or opening a PR:

```shell
bash scripts/validate.sh
```

It runs `claude plugin validate --strict` on every plugin, checks JSON sanity, plugin count, orphans, version sync between `plugin.json` and `marketplace.json`, and the 9-section SKILL.md house style. See [SPEC.md](SPEC.md#validation) for details.

## License

MIT
