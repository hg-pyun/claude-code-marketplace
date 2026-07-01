# buddy — Plugin Maintenance Guide

This file covers maintenance of the `buddy` plugin.
Repo-wide governance (versioning, `author` field, 9-section house style, `settings.language`) lives in the root [`CLAUDE.md`](../../CLAUDE.md).
How agents, skills, and commands *operate* is self-documented in their own source files — read those directly.

## Structure

```
plugins/buddy/
├── .claude-plugin/plugin.json
├── skills/EXAMPLE/    # placeholder skill scaffold — replace with real entrypoint
├── commands/EXAMPLE.md  # placeholder command scaffold — replace with real entrypoint
├── README.md         # end-user guide
└── CLAUDE.md         # this file
```

## Agent / skill / command boundary

This plugin is a **scaffold** — no real entrypoints yet. The `skills/EXAMPLE/` and
`commands/EXAMPLE.md` files are placeholders in the 9-section house style; replace or
delete them when authoring the first real skill/command.

## Adding a skill or command

1. Create the file in the appropriate directory (`skills/<name>/SKILL.md` or `commands/<name>.md`).
2. Author it in the **9-section XML house style** — all nine sections required in order:
   `<Purpose>` · `<Use_When>` · `<Do_Not_Use_When>` · `<Why_This_Exists>` · `<Execution_Policy>` · `<Steps>` · `<Tool_Usage>` · `<Examples>` · `<Final_Checklist>`.
3. **Bump the version** in BOTH locations to the same value (see root CLAUDE.md §Plugin Version Management):
   - `plugins/<plugin-name>/.claude-plugin/plugin.json` → `version`
   - `.claude-plugin/marketplace.json` → matching plugin entry's `version`
4. Run `bash scripts/validate.sh` from the repo root — exit `0` is the gate before committing.

## Debugging

No plugin-specific failure modes yet. Common repo-wide issues (version sync, author
field, 9-section) are covered in the root CLAUDE.md §Quick troubleshooting.
