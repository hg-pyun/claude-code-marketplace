# buddy

A scaffold plugin. Entrypoints (skills / commands) are not yet authored — the
`skills/EXAMPLE/` and `commands/EXAMPLE.md` files are house-style placeholders to
replace with real entrypoints.

## Usage

_No real entrypoints yet._ Author the first skill/command in the 9-section XML house
style (see the root [`CLAUDE.md`](../../CLAUDE.md)), then document it here.

| Trigger | Skill / Command | What it does |
|---------|-----------------|--------------|
| _(none yet)_ | — | — |

## Settings

```json
"settings": { "language": "Korean" }
```

- `language` — default language for any language-dependent output. Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.

> If the first real entrypoint produces no language-dependent artifact, delete the
> `settings` block from both this README and `.claude-plugin/plugin.json`.
