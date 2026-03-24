# Claude Code Project Guidelines

## Plugin Version Management Rules

When modifying, adding, or deleting files under `plugins/<name>/` (excluding README.md), the version **must** be bumped.

### Update Targets (both locations simultaneously)

1. `plugins/<name>/.claude-plugin/plugin.json` → `version`
2. `.claude-plugin/marketplace.json` → `version` of the corresponding plugin

Both values must always be identical.

### Version Determination Logic

Format: `YYYY.MM.DD[.patch]` — determined based on the current date.

| Current Version | Condition | New Version |
|-----------------|-----------|-------------|
| Not today | — | `YYYY.MM.DD` |
| `YYYY.MM.DD` | Same as today | `YYYY.MM.DD.1` |
| `YYYY.MM.DD.N` | Same as today | `YYYY.MM.DD.(N+1)` |

### Pre-commit Checklist

Before creating a commit that changes plugin files, verify:

- [ ] Has the version in plugin.json been bumped?
- [ ] Has the corresponding plugin version in marketplace.json been bumped to match?
- [ ] Do both version values match?
