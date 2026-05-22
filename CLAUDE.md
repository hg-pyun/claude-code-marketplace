# Claude Code Project Guidelines — claude-code-marketplace

## Plugin Version Management Rules

When modifying, adding, or deleting **source** files under `plugins/<name>/` (commands/, skills/, agents/, hooks/, and `.claude-plugin/plugin.json`), the version **must** be bumped. Doc-only files (`README.md`, `SPEC.md`, `REFERENCES.md`, and other markdown files outside `commands/`, `skills/`, `agents/`, `hooks/`) do not require a version bump — examples: appending an entry to `plugins/core/SPEC.md`'s Smoke Test Log, fixing a typo in a README, or refreshing a REFERENCES.md attribution.

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

### Multi-Phase Overhaul Exception

When a single, planned overhaul touches files across multiple plugins and the
work is committed in multiple phases on the same day, versions may be deferred
to a single bump in the final phase **as long as**:

- The plan is documented (e.g., a planning document in the repository or a tracking issue).
- The intermediate commits clearly note "no version bump per overhaul exception"
  in the commit message.
- The final phase brings every modified plugin's `plugin.json` and
  `marketplace.json` entry into sync at `YYYY.MM.DD[.N]` per the table above.
- The overhaul completes within a single calendar day; carrying the exception
  across day boundaries reverts to the per-file bump rule for any commit on
  subsequent days.

This exception exists so that planned, atomic overhauls do not produce churn
across N intermediate version bumps that are all superseded a few minutes later.

## `author` Field Requirement

Every `plugins/<name>/.claude-plugin/plugin.json` MUST include an `author` field in **object form**:

```json
"author": { "name": "hg-pyun" }
```

String form (`"author": "hg-pyun"`) is rejected by `claude plugin validate --strict` with `expected object, received string`. The object form passes both default and strict validation. Add `email` or other fields to the object as needed.

## Agent Invocation Convention

The `hg-pyun-tools` plugin bundles shared agents (`reviewer`, `explorer`, `architect`, `critic`) and the `code-review` skill alongside its commands. Other skills and commands delegate to the bundled agents via the Task tool:

```
Task(
  subagent_type="reviewer",
  prompt="<diff or content to review>"
)
```

`subagent_type` is the bare agent name — no plugin prefix because everything ships in one plugin. The previous `core:<agent>` form and missing-`core` fallback contract were removed in the 2026-05-22.1 consolidation.

## 9-section SKILL.md House Style

Every `plugins/<plugin>/skills/<skill>/SKILL.md` and `plugins/<plugin>/commands/<command>.md` in this marketplace MUST include all nine XML body sections, in this order:

1. `<Purpose>`
2. `<Use_When>`
3. `<Do_Not_Use_When>`
4. `<Why_This_Exists>`
5. `<Execution_Policy>`
6. `<Steps>`
7. `<Tool_Usage>`
8. `<Examples>`
9. `<Final_Checklist>`

Optional supplemental sections (e.g., `<Settings_Reference>`, `<Arguments>`, `<Escalation_And_Stop_Conditions>`, `<Advanced>`) are allowed. Use the XML tag form (`<Purpose>`), not Markdown headers (`## Purpose`).

`scripts/validate.sh` includes a soft 9-section presence check. README.md files are explicitly excluded from this requirement.

This is an **internal house style** for `hg-pyun-plugins` — we adopt 9-section XML as our predictable scaffold so any new asset author starts from the same structure.

## `settings.language` Standard

Plugins whose output language is configurable (commit messages, PR bodies, ticket content, spec documents) MUST expose `settings.language` in their `plugin.json`:

```json
"settings": {
  "language": "Korean"
}
```

- Default value: `Korean` (backward compatible with existing behavior).
- Override per-invocation: `--lang=<value>` argument.
- Presets: Korean, English, Japanese, Chinese.
- Custom values (e.g., `Spanish`, `Bahasa Indonesia`) are accepted as free text.

Each language-dependent SKILL.md / command.md file references the variable as `$LANGUAGE` and includes a `<Settings_Reference>` block describing the variable and accepted values.

Within `hg-pyun-tools`, exempt artifacts (do not consume `$LANGUAGE`):
- `commands/git-rebase-stack.md` — emits only conversational guidance/questions/reports, which stay in Korean per the marketplace SPEC.
- `skills/curl-debug/SKILL.md` — no language-dependent artifact.
- `skills/code-review/SKILL.md` — returns findings in the calling session's language.
- `agents/*.md` — output uses the calling session's language; no static artifact.
