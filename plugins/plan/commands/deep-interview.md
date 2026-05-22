---
description: >
  Conduct an in-depth interview to capture a project specification, then write
  the spec to a file. Ask questions one at a time about technical implementation,
  UI/UX, concerns, and tradeoffs, and continue until the spec is detailed enough
  to act on.
  TRIGGER when: user wants to capture requirements before coding, says "스펙 잡아줘",
  "deep interview", "심층 인터뷰", "plan: 스펙 정리", or invokes /deep-interview.
  DO NOT TRIGGER when: user already has a spec they want reviewed (use a review
  skill), is asking conceptually what an interview is, or wants a single small
  change with obvious scope — just do it directly.
argument-hint: "[brief idea or topic] [--lang=<value>]"
---

<Purpose>
Interview the user in `$LANGUAGE` to capture requirements for a new project, feature, or change. Produce a structured spec document at the end.
</Purpose>

<Use_When>
- User wants to capture requirements before any coding starts ("스펙 잡아줘", "plan this out")
- User invokes `/deep-interview` (or `/plan:deep-interview`)
- User has a rough idea and wants help structuring it into a spec
- User wants a focused interview that produces a written spec file
</Use_When>

<Do_Not_Use_When>
- User already has a spec and wants it reviewed — use a review skill
- User asks conceptually what an interview is — answer directly
- The task is a single small change with obvious scope — just do it
- User wants only a quick brainstorm chat without a written artifact
</Do_Not_Use_When>

<Why_This_Exists>
Many feature requests start as a one-line idea. Without a structured interview, an engineer either makes assumptions (and gets it wrong) or burns an hour clarifying things conversationally. This command produces a written spec in 10-20 minutes of focused Q&A so the work that follows starts from a shared understanding instead of guesswork.
</Why_This_Exists>

<Execution_Policy>
- Interview questions and the final spec are written in `$LANGUAGE`.
- Use `AskUserQuestion` — one question at a time. Build on previous answers.
- Cover the standard rubric: Goal / Constraints / Acceptance Criteria / Technical Direction / Open Questions / Out of Scope.
- Continue until the spec rubric is sufficiently filled OR the user says "enough" / "충분해" / "이 정도면 됐어".
- Write the final spec to `.specs/deep-interview-<slug>.md` (preferred) or a user-specified path if given.
- Do not implement code in this skill — produce the spec only.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: the language setting from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.
</Settings_Reference>

<Arguments>
- `$ARGUMENTS`: optional brief idea or topic + optional `--lang=<value>`.
  - Example: `/deep-interview "Linear webhook 처리 서비스" --lang=ko`
  - If empty, the first question asks the user what they want to spec.
</Arguments>

<Steps>
### Step 1: Capture the seed idea
1. If `$ARGUMENTS` contains a topic, use it as the seed.
2. If empty, AskUserQuestion: "What do you want to spec out today?" (in `$LANGUAGE`).
3. Restate the idea in one sentence to confirm understanding before going further.

### Step 2: Interview against the rubric
For each rubric section that is not yet clear, ask focused questions via `AskUserQuestion`. Cover at minimum:
- **Goal** — one-sentence success statement
- **Constraints** — non-goals, hard limits, deadlines, dependencies
- **Acceptance Criteria** — testable items
- **Technical Direction** — language/framework/architecture preferences if any
- **UI/UX** (if applicable) — flows, screens, copy decisions
- **Tradeoffs** — what is being given up for what gain
- **Open Questions** — explicitly unresolved items

Rules:
- One question per turn. Reuse previous answers — do not re-ask.
- Questions are concrete and not obvious (e.g., not "what is your goal?" — instead "When a user opens the app and sees this feature for the first time, what's the very first thing they do?").
- Stop when the rubric is filled or the user says "enough".

### Step 3: Draft the spec
Compose the spec document in `$LANGUAGE` using this structure (section headers stay English):

```markdown
# Spec: <title>

## Generated
<YYYY-MM-DD>

## Goal
<one sentence>

## Constraints
- ...

## Non-Goals
- ...

## Acceptance Criteria
- [ ] ...

## Technical Direction
- ...

## UI/UX (if applicable)
- ...

## Tradeoffs
| Choice | Pros | Cons |
|--------|------|------|
| ... | ... | ... |

## Open Questions
- ...

## Transcript (optional)
<details>
<summary>Interview Q&A</summary>
...
</details>
```

### Step 4: Write the spec to a file
1. Slugify the title for the filename.
2. Write to `.specs/deep-interview-<slug>.md` (create `.specs/` if missing).
3. Show the user the absolute path of the written file.
</Steps>

<Tool_Usage>
- `AskUserQuestion` for each interview question.
- `Write` to save the final spec file.
- `Bash` only to create the `.specs/` directory if needed.
</Tool_Usage>

<Examples>
**Example 1 — fresh idea:**
User: "스펙 잡아줘 — Linear webhook 처리 서비스"
Flow: restate idea → 7-10 interview questions in Korean → draft spec → write to `.specs/deep-interview-linear-webhook.md` → show path.

**Example 2 — bare invocation:**
User: "/deep-interview"
Flow: AskUserQuestion "오늘 어떤 걸 스펙으로 잡을까요?" → user answers → continue from Step 2.

**Example 3 — `--lang=en`:**
User: "/deep-interview 'auth refactor' --lang=en"
Flow: interview in English → spec in English → file written.
</Examples>

<Final_Checklist>
- Did I restate the seed idea in one sentence before interviewing?
- Did I ask one question at a time in `$LANGUAGE`?
- Does the spec cover Goal / Constraints / Acceptance Criteria / Technical Direction / Open Questions / Out of Scope?
- Did I write the spec to `.specs/deep-interview-<slug>.md` and show the path?
</Final_Checklist>
