# Claude Code Marketplace for personal

Personal Claude Code plugin marketplace.

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

- [git](plugins/git/README.md) - Git workflow automation (commit, PR, stacked PR rebase)
- [linear](plugins/linear/README.md) - Linear ticket enrichment via interview
- [plan](plugins/plan/README.md) - Project planning support (deep interview)

See [SPEC.md](SPEC.md) for directory structure and design decisions.

## Adding a Plugin

1. Create `plugins/<plugin-name>/` directory
2. Add `.claude-plugin/plugin.json` manifest
3. Add plugin source files (commands/, hooks/, agents/, etc.)
4. Add entry to `.claude-plugin/marketplace.json` `plugins` array
5. Bump `version` in both `plugin.json` and `marketplace.json` (see [SPEC.md](SPEC.md#version-management-rules))
6. Validate with `claude plugin validate .` or `/plugin validate .`
7. Commit and push

## License

MIT
