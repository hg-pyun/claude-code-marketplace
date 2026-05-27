# REPLACE-WITH-PLUGIN-NAME

<!-- One-paragraph description of the plugin. -->

## Usage

<!-- Table of skills/commands and triggers. -->

| Trigger | Skill / Command | What it does |
|---------|-----------------|--------------|
| `/example`, "example 트리거" | `example` | <one sentence> |

## Settings

<!--
  `settings.language` is REQUIRED only for plugins whose output language is
  configurable (e.g., commit messages, PR bodies, ticket content, spec docs).
  If your plugin produces NO language-dependent artifact (e.g., a pure debug
  tool, a shared-agents-only plugin), DELETE the `settings` block from both
  this README and `.claude-plugin/plugin.json`. See the root CLAUDE.md
  "settings.language standard" for the exemption list.
-->

```json
"settings": { "language": "Korean" }
```

- `language` — default language for any language-dependent output. Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.

## Agent invocations

<!--
  This marketplace ships as a single unified plugin (`dev-tools`). Skills
  and commands invoke bundled agents with the BARE agent name — no plugin
  prefix:

      Task(subagent_type="reviewer", prompt="…")

  The prior `core:<agent>` form and the missing-`core` fallback contract were
  removed in the 2026-05-22.1 consolidation. If your new plugin needs an agent
  that lives in `dev-tools`, just reference it by its bare name. List the
  agents you invoke here, e.g.:

  - `reviewer` — for severity-rated diff review
  - `executor` — for multi-file code edits
-->

## Examples

<!-- 1-3 representative invocations and what they do. -->

- `/example` — <what happens>
- `/example arg --lang=en` — <what happens with override>
