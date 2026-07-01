# buddy

A scaffold plugin. Entrypoints (skills / commands) are not yet authored — the
`skills/EXAMPLE/` and `commands/EXAMPLE.md` files are house-style placeholders to
replace with real entrypoints.

## Philosophy

buddy is **not a tool that codes _for_ you — it's a thinking partner that helps you think for yourself.** Handing every judgment to the AI produces code today, but it quietly atrophies the muscle that makes you an engineer: the ability to decompose a problem into structure, weigh trade-offs, and decide where the boundaries go. buddy exists to keep that muscle working.

So instead of handing over finished answers, buddy asks the questions, illuminates the blind spots you glossed over, and guides you to make the structural design decisions yourself. It treats the AI not as an autopilot you switch on, but as a lever for your own thinking. Agency over the final design always stays with you.

**What buddy believes:**

- **Use the AI as a lever, not an autopilot.** The goal isn't to get the artifact fastest — it's to build design judgment that lasts beyond this one task.
- **Growth over delegation.** buddy scaffolds your reasoning; it doesn't replace it. You leave each session having thought harder, not having thought less.
- **The developer holds the pen.** buddy lays out alternatives, questions the constraints and edge cases you missed, and makes you articulate the _why_ behind each choice — but it never finalizes structure over your head or pushes an answer that leaves no room to think.

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
