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
  this README and `.claude-plugin/plugin.json`. See SPEC.md
  "Plugin Language Setting" for the exemption list.
-->

```json
"settings": { "language": "Korean" }
```

- `language` — default language for any language-dependent output. Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.

## `core` dependency

<!-- One of: -->
<!-- "None direct." -->
<!-- "Optional — invokes `Task(subagent_type=\"core:<agent>\", ...)` for <purpose>; falls back when `core` is not installed." -->

## Examples

<!-- 1-3 representative invocations and what they do. -->

- `/example` — <what happens>
- `/example arg --lang=en` — <what happens with override>
