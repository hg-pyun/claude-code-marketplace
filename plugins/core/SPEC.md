# core — SPEC

## Project Context

`core` is the shared-asset plugin for the `hg-pyun-plugins` marketplace, created during the 2026-05-22 overhaul.

The hybrid architecture decision: workflow-specific plugins (`git`, `linear`, `plan`, `debug`) keep their own logic locally; cross-cutting agents (reviewer, explorer, architect, critic) and shared skills (`core-verify`, `code-review`) live in `core` and are invoked from any plugin via `Task(subagent_type="core:<agent>")`.

## Invocation Contract

### From another skill (preferred)

```
Task(
  subagent_type="core:reviewer",
  prompt="Review this diff for severity-rated issues:\n\n<diff content>"
)
```

The subagent_type format is `<plugin-name>:<agent-name>` per Claude Code's namespace resolution.

### Fallback when `core` is not installed

Each consuming skill in this marketplace MUST handle the case where `core` is unavailable. The conventional fallback is:

```
Detection: Task invocation returns an "unknown subagent" or equivalent error.
Action: perform the operation inline with equivalent behavior.
Output: append "core plugin not installed; <skill> performed locally" to the summary.
```

This contract preserves graceful degradation per the marketplace SPEC.md constraint.

## Smoke Test Log

Append rows here when running smoke tests (per the consensus plan's Phase 5).

| Date | Agent/Skill | Input | Output excerpt | Pass criterion met | Verdict |
|------|-------------|-------|----------------|--------------------|---------|
| _(none yet — fill during Phase 5)_ | | | | | |

### Phase 5 smoke-test prompts (reproducible)

- **reviewer:** `"Review this diff snippet for severity-rated issues:\n\n\`\`\`ts\nfunction divide(a,b){return a/b}\n\`\`\`"` → pass if response contains `CRITICAL|MAJOR|MINOR` AND a file:line-like reference.
- **explorer:** `"Use Glob to list all SKILL.md files under plugins/. Return absolute paths."` → pass if at least one path matches `plugins/.+/SKILL.md`.
- **architect:** `"Briefly state one trade-off of using bash for scripts/validate.sh vs. python."` → pass if response matches `trade-off|tradeoff` AND `pro|con|advantage|disadvantage|vs\.|instead`.
- **critic:** `"Critique this 1-line plan: 'Refactor everything.'"` → pass if response contains `antithesis|counterargument|steelman|instead`.
- **core-verify skill:** invoke `/core-verify` → pass if the skill triggers under its full `core-verify` name and produces PASS/FAIL output.
- **code-review skill:** same diff as reviewer test → pass if skill triggers, response matches `core:reviewer|delegating to reviewer|sub.?agent.*reviewer`, and produces severity-bucketed output.
- **cross-plugin wiring:** `/curl-debug curl https://httpbin.org/status/500` → pass if `core:reviewer` delegation appears in the flow (or `<Tool_Usage>` documents the optional delegation).
- **missing-core fallback:** uninstall `core`, re-invoke `/curl-debug curl https://httpbin.org/status/500` → pass if graceful fallback message ("core plugin not installed; review delegated locally") appears.

## Design Decisions

- **READ-ONLY agents.** All four agents have `disallowedTools: Write, Edit`. They advise and surface findings; they never mutate the repo.
- **No nested sub-plugins.** Originally the spec considered separate `orchestrator` / `meta` plugins; the consensus plan chose a single `core` instead for simplicity.
- **9-section XML house style.** SKILL.md files in `core` follow the hg-pyun-plugins-local 9-section convention. See root `CLAUDE.md` for the section list.
- **Sentinel version during overhaul.** Phase 2 wrote `version: "0.0.0-overhaul-pending"`; Phase 5 supersedes with the final `YYYY.MM.DD[.N]` value.

