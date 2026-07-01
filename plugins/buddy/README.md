# buddy

buddy is a thinking partner that helps you think for yourself. Its first skill,
**`deep-interview`**, is a Socratic maieutic design interview: instead of handing you a
finished design, it asks one question at a time until you've decomposed the problem,
weighed the trade-offs, and made the structural decisions yourself. You hold the pen.

## Philosophy

buddy is **not a tool that codes _for_ you — it's a thinking partner that helps you think for yourself.** Handing every judgment to the AI produces code today, but it quietly atrophies the muscle that makes you an engineer: the ability to decompose a problem into structure, weigh trade-offs, and decide where the boundaries go. buddy exists to keep that muscle working.

So instead of handing over finished answers, buddy asks the questions, illuminates the blind spots you glossed over, and guides you to make the structural design decisions yourself. It treats the AI not as an autopilot you switch on, but as a lever for your own thinking. Agency over the final design always stays with you.

**What buddy believes:**

- **Use the AI as a lever, not an autopilot.** The goal isn't to get the artifact fastest — it's to build design judgment that lasts beyond this one task.
- **Growth over delegation.** buddy scaffolds your reasoning; it doesn't replace it. You leave each session having thought harder, not having thought less.
- **The developer holds the pen.** buddy lays out alternatives, questions the constraints and edge cases you missed, and makes you articulate the _why_ behind each choice — but it never finalizes structure over your head or pushes an answer that leaves no room to think.

## Usage

| Trigger | Skill / Command | What it does |
|---------|-----------------|--------------|
| "산파법", "socratic", "deep interview", "interview me to think", "설계 같이 고민해줘" | `deep-interview` | Asks one question at a time — never handing over the answer — so you decompose the problem, weigh the trade-offs, and make the design decisions yourself. Output: "the decisions you made, and why." |

## Settings

```json
"settings": { "language": "Korean" }
```

- `language` — default language for any language-dependent output. Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.
