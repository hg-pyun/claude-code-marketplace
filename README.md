# Claude Code Marketplace for personal

Personal Claude Code plugin marketplace (`hg-pyun-plugins`).

## Usage

### Add marketplace

```shell
/plugin marketplace add hg-pyun/claude-code-marketplace
```

### Install a plugin

```shell
/plugin install <plugin-name>@hg-pyun-plugins
```

### Update marketplace

```shell
/plugin marketplace update
```

## Plugins

- [core](plugins/core/README.md) — Shared reviewer, explorer, architect, and critic agents plus verify and code-review skills for cross-plugin orchestration
- [debug](plugins/debug/README.md) — API debugging tools — execute cURL requests and reverse-trace bugs through the codebase
- [git](plugins/git/README.md) — Git and GitHub workflows (conventional commit, PR, stacked-PR rebase)
- [linear](plugins/linear/README.md) — Linear ticket enrichment via interview
- [plan](plugins/plan/README.md) — Lightweight project-planning interview (`/deep-interview`)

See [SPEC.md](SPEC.md) for architecture, directory structure, and design decisions.

## Adding a Plugin

1. Copy `templates/plugin/` to `plugins/<plugin-name>/` and rename the template directory.
2. Update `plugins/<plugin-name>/.claude-plugin/plugin.json` — set `name`, `description`, `version`, `author`, optional `settings.language`.
3. Add plugin source files (commands/, skills/, hooks/, agents/, etc.) following the 9-section XML house style for any SKILL.md / command md.
4. Add an entry to `.claude-plugin/marketplace.json` `plugins` array. Keep alphabetical order via `jq '.plugins |= sort_by(.name)'` after insert.
5. Bump `version` in both `plugin.json` and `marketplace.json` per [CLAUDE.md](CLAUDE.md).
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
