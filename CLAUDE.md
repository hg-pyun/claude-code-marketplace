# Claude Code Project Guidelines

## Plugin Version Management Rules

When modifying, adding, or deleting files under `plugins/<name>/` (excluding README.md), the version **must** be bumped.

### Update Targets (both locations simultaneously)

1. `plugins/<name>/.claude-plugin/plugin.json` → `version`
2. `.claude-plugin/marketplace.json` → `version` of the corresponding plugin

Both values must always be identical.

### Version Determination Logic

Format: `YYYY.MM[.patch]` — determined based on the current date.

| Current Version | Condition | New Version |
|-----------------|-----------|-------------|
| Not the current month | — | `YYYY.MM` |
| `YYYY.MM` | Same as current month | `YYYY.MM.1` |
| `YYYY.MM.N` | Same as current month | `YYYY.MM.(N+1)` |

### Pre-commit Checklist

Before creating a commit that changes plugin files, verify:

- [ ] Has the version in plugin.json been bumped?
- [ ] Has the corresponding plugin version in marketplace.json been bumped to match?
- [ ] Do both version values match?
