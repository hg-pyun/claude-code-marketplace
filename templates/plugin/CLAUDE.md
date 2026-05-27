# <plugin-name> — Plugin Maintenance Guide

<!--
  Scope: this file is the MAINTENANCE guide for this plugin.
  It is auto-loaded when Claude works inside this plugin directory.

  What belongs here:
    - Plugin directory structure (structure map).
    - Which asset kinds this plugin ships and where they live (boundary note).
    - How to add a skill / command with the version-bump reminder.
    - Plugin-specific debugging / validate notes.

  What does NOT belong here:
    - Repo-wide governance (versioning rules, author field, 9-section house style,
      settings.language standard, validate.sh usage) — that lives in the root CLAUDE.md.
    - How this plugin's agents / skills / commands *operate* — that is self-documented
      in each source file (agents/<name>.md, skills/<name>/SKILL.md, commands/<name>.md).
      Do NOT duplicate operation detail here.
-->

This file covers maintenance of the `<plugin-name>` plugin.
Repo-wide governance (versioning, `author` field, 9-section house style, `settings.language`) lives in the root [`CLAUDE.md`](../../CLAUDE.md).
How agents, skills, and commands *operate* is self-documented in their own source files — read those directly.

## Structure

```
plugins/<plugin-name>/
├── .claude-plugin/plugin.json
├── agents/           # (if applicable) shared specialist agents
├── skills/           # orchestration / workflow skills
├── commands/         # single-command entrypoints
├── README.md         # end-user guide
└── CLAUDE.md         # this file
```

<!-- Replace the tree above with the actual layout for this plugin. -->

## Agent / skill / command boundary

<!-- One-line summary of what this plugin ships:
     - agents/<name>.md  — shared roles invoked by bare name from skills
     - skills/<name>/    — multi-step workflow skills
     - commands/<name>.md — single-invocation commands
     Add or remove rows to match what this plugin actually ships. -->

## Adding a skill or command

1. Create the file in the appropriate directory (`skills/<name>/SKILL.md` or `commands/<name>.md`).
2. Author it in the **9-section XML house style** — all nine sections required in order:
   `<Purpose>` · `<Use_When>` · `<Do_Not_Use_When>` · `<Why_This_Exists>` · `<Execution_Policy>` · `<Steps>` · `<Tool_Usage>` · `<Examples>` · `<Final_Checklist>`.
3. **Bump the version** in BOTH locations to the same value (see root CLAUDE.md §Plugin Version Management):
   - `plugins/<plugin-name>/.claude-plugin/plugin.json` → `version`
   - `.claude-plugin/marketplace.json` → matching plugin entry's `version`
4. Run `bash scripts/validate.sh` from the repo root — exit `0` is the gate before committing.

## Debugging

<!-- Plugin-specific failure modes and their fixes.
     Common repo-wide issues (version sync, author field, 9-section) are covered
     in the root CLAUDE.md §Quick troubleshooting. -->
