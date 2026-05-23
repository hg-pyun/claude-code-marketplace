---
description: >
  Given a Linear ticket URL, fill in missing ticket information by analyzing
  the title/description/comments/linked issues and conducting a deep interview
  with the user. Writes the enriched content back to the Linear ticket in $LANGUAGE.
  TRIGGER when: user shares a Linear ticket URL and asks to enrich, complete,
  fill in, or interview-fill the ticket (e.g., "이 티켓 채워줘", "linear 티켓
  보완해줘", "ENG-123 enrich", "enrich this ticket").
  DO NOT TRIGGER when: user is reading an existing ticket, asking ticket status,
  or discussing Linear workflow conceptually.
argument-hint: Linear ticket URL [--lang=<value>]
---

<Purpose>
Take a Linear ticket URL, read existing title/description/comments/linked issues, identify what is missing, conduct a focused interview, then update the ticket with structured, complete content in `$LANGUAGE`.
</Purpose>

<Use_When>
- User shares a Linear ticket URL and wants it enriched ("이 티켓 채워줘", "enrich this ticket")
- A ticket has a one-line title but no detail and the user wants help structuring it
- The user invokes `/enrich-ticket <url>`
- A new ticket needs acceptance criteria, technical detail, or context the original creator did not provide
</Use_When>

<Do_Not_Use_When>
- User wants to read a ticket — use Linear MCP `get_issue` directly
- User wants to create a brand-new ticket from scratch with no existing reference — use a different flow
- User is asking conceptual Linear questions
- The ticket is already complete (description, acceptance criteria, technical notes all present)
</Do_Not_Use_When>

<Why_This_Exists>
Many Linear tickets ship as "fix the login bug" — true but unactionable. A focused interview (technical implementation, UI/UX considerations, tradeoffs, edge cases) produces a ticket that a downstream engineer can act on without rediscovering context. The skill writes results back to the source of truth (Linear), not to a side document, so the next person reading the ticket sees the complete version.
</Why_This_Exists>

<Execution_Policy>
- Interview questions and ticket content written to Linear are both written in `$LANGUAGE`.
- Use `AskUserQuestion` for the interview — one question at a time, never batched.
- Continue until the ticket has enough detail that an engineer could start work without further clarification.
- Use Linear MCP for reading and writing the ticket; do not paste content into chat as a substitute.
- Do not invent technical details the user did not confirm; if a question is unresolved, mark it explicitly in the ticket body.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: the language setting from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted.
</Settings_Reference>

<Arguments>
- `$ARGUMENTS`: the Linear ticket URL (required), plus optional `--lang=<value>`.
  - Example: `/enrich-ticket https://linear.app/acme/issue/ENG-123 --lang=en`
  - URL and `--lang` flag may coexist in any order.
</Arguments>

<Steps>
### Step 1: Read the ticket
1. Parse the Linear URL from `$ARGUMENTS` to extract `team` and `issue-id`.
2. Use Linear MCP `get_issue` to load title, description, current status, assignee, labels.
3. Use Linear MCP `list_comments` to load discussion thread.
4. If the description references other tickets or external URLs (e.g., Notion, GitHub PR), AskUserQuestion whether to incorporate their context too.

### Step 2: Identify gaps
Compare the ticket against a baseline "complete ticket" rubric:
- **Goal** — one-sentence statement of what success looks like
- **Context** — why this matters now
- **Acceptance criteria** — testable list
- **Technical notes** — implementation hints, constraints, dependencies
- **Out of scope** — what this ticket is NOT
- **Open questions** — explicitly unresolved items

List the missing sections internally.

### Step 3: Interview to fill the gaps
For each missing section, ask focused questions via `AskUserQuestion`. Rules:
- One question at a time. Build on previous answers.
- Questions in `$LANGUAGE`.
- Reuse existing ticket context — do not re-ask what the description already states.
- Cover technical implementation, UI/UX considerations, tradeoffs, edge cases, concerns — anything an engineer would need.
- Stop interviewing when the rubric is sufficiently filled OR the user says "enough" / "이 정도면 됐어".

### Step 4: Draft the enriched ticket body
Compose the new ticket description in `$LANGUAGE` using this template (section headers stay English):

```markdown
## Goal
<!-- one sentence -->

## Context
<!-- why this matters now -->

## Acceptance Criteria
- [ ] ...

## Technical Notes
- ...

## Out of Scope
- ...

## Open Questions
- ...
```

Empty sections may be omitted if not relevant.

### Step 5: Update the Linear ticket
Use Linear MCP `save_issue` to update the description. Preserve the original title unless the user explicitly asked to change it. Show the user the resulting Linear URL to confirm the update landed.
</Steps>

<Tool_Usage>
- **Linear MCP** tools: `get_issue`, `list_comments`, `save_issue`. Read first, write last.
- `AskUserQuestion` for the interview — one question per turn.
- Optionally `WebFetch` if the user provided a Notion / GitHub URL to incorporate.
</Tool_Usage>

<Examples>
**Example 1 — bare-bones ticket:**
User: "ENG-123 채워줘"
Flow: read ticket (title only) → identify all 6 sections missing → 5-7 interview questions in Korean → draft 6-section body in Korean → `save_issue` → show URL.

**Example 2 — partial ticket:**
User: "linear 티켓 보완해줘 https://linear.app/acme/issue/ENG-456"
Flow: ticket has Goal + Context but no Acceptance Criteria → 3 questions covering AC, edge cases, scope boundary → update only the missing sections in Korean → `save_issue`.

**Example 3 — `--lang=en`:**
User: "/enrich-ticket https://linear.app/acme/issue/ENG-789 --lang=en"
Flow: interview questions in English; ticket body written in English with English section headers.
</Examples>

<Final_Checklist>
- Did I read the existing ticket and comments before interviewing?
- Did I ask questions one at a time in `$LANGUAGE`?
- Does the final ticket include the relevant rubric sections (Goal / Context / Acceptance Criteria / Technical Notes / Out of Scope / Open Questions)?
- Did I `save_issue` and surface the resulting URL to the user?
- Did I avoid inventing details the user did not confirm?
</Final_Checklist>
