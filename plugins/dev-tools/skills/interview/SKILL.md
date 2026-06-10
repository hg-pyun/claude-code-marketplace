---
name: interview
description: >
  Lightweight in-depth interview. Asks non-obvious, probing questions one at a
  time via AskUserQuestion — covering technical implementation, UI & UX,
  concerns, and tradeoffs — and continues until coverage is complete, then
  writes a structured spec to `.dt-handoff/<slug>/spec.md` in `$LANGUAGE`. No
  ambiguity scoring, no challenge agents, no agent dispatch — the fast,
  conversational sibling of `deep-interview`.
  TRIGGER when: user wants a quick but thorough requirements interview before
  coding, says "인터뷰 해줘", "인터뷰", "가볍게 인터뷰", "스펙 인터뷰",
  "interview me", "quick interview", "lightweight interview", or invokes
  `/interview`. Also the downshift target when `deep-interview` detects a
  single-component, clear-scope topic and offers the lighter path
  ("가볍게/빠르게" → here; "심층/ouroboros/socratic/ambiguity scoring" →
  `deep-interview`).
  DO NOT TRIGGER when: user wants the heavy mathematically-gated flow ("deep
  interview", "심층 인터뷰", "ouroboros", "socratic", ambiguity scoring) — route
  to `deep-interview`; user already has a detailed spec/PRD (use a review or
  execution skill); the task is a single small change with obvious scope; or the
  user says "just do it / skip the questions".
argument-hint: "[topic or file path] [--lang=<value>] [--max-rounds=<n>]"
---

<Purpose>
Interview the user in `$LANGUAGE` to capture requirements for a feature, change, or idea using focused, non-obvious questions asked ONE at a time via `AskUserQuestion`. Cover four dimensions deliberately — Technical Implementation, UI & UX, Concerns & Risks, and Tradeoffs — plus Goal and Scope, and keep going until every relevant dimension is covered or the user opts out. Output is a single structured spec at `.dt-handoff/<slug>/spec.md`. This skill does NOT implement code, does NOT score ambiguity, and does NOT dispatch other agents — it is the fast, conversational counterpart to `deep-interview`.
</Purpose>

<Use_When>
- User wants a thorough-but-quick requirements interview before any coding ("인터뷰 해줘", "interview me", "스펙 인터뷰")
- User invokes `/interview` (optionally with a topic or a file path)
- User has a rough idea and wants it crystallized into a written spec without the ceremony of ambiguity gating
- User explicitly wants the lightweight path rather than the full `deep-interview` flow
- The task has enough open questions that jumping straight to code would waste cycles, but does not need per-dimension clarity math
</Use_When>

<Do_Not_Use_When>
- User wants the mathematically-gated, challenge-agent flow ("deep interview", "심층 인터뷰", "ouroboros", "socratic", ambiguity threshold) — route to `deep-interview`
- User already has a detailed spec/PRD and wants it reviewed or executed — use a review or execution skill
- The task is a single small change with obvious scope — just do it
- User says "just do it" / "skip the questions" — respect intent: end the interview, write what you have as a `draft` spec, do not auto-execute
- User wants only a free-form brainstorm chat with no written artifact
</Do_Not_Use_When>

<Why_This_Exists>
`deep-interview` is powerful but heavy: it locks topology, scores ambiguity per dimension, gates on a numeric threshold, and dispatches `analyst`/`critic`/`explorer`. That rigor is overkill for the common case — a clear-headed user who just needs to be asked the *right* non-obvious questions and have the answers captured.

This skill keeps the valuable core of an interview — asking one sharp question at a time, probing the parts people skip — and drops all the machinery. No scoring, no gate, no agents, no `events.jsonl`. The only completion signal is coverage of the four dimensions plus Goal/Scope, judged conversationally. It is the tool to reach for when you want a spec in ten minutes, not a graded specification process.
</Why_This_Exists>

<Execution_Policy>
- Interview questions and the final spec are written in `$LANGUAGE`. Section headers in the spec stay English; content is `$LANGUAGE`.
- Use `AskUserQuestion` — ONE question per turn. Never batch multiple questions into one call.
- Every question must be non-obvious: probe implementation detail, edge cases, failure modes, and unstated assumptions — not "what do you want?". If the answer is already derivable from the topic or the codebase, do not ask it.
- Emit ONE short context line as plain text immediately before each `AskUserQuestion` call: `[Round {n} · {dimension}]`. Put ONLY the question in the `question` field.
- Cover all of: Goal · Scope/Non-Goals · Technical Implementation · UI & UX · Concerns & Risks · Tradeoffs. Skip a dimension only when it is genuinely not applicable (e.g. a headless CLI tool has no UI & UX) and note the skip in the spec.
- Do NOT score ambiguity, lock topology, or dispatch any agent. This is the lightweight path; if rigorous gating is wanted, defer to `deep-interview`.
- Allow early exit at any round when the user says "충분해" / "enough" / "그만" / "let's go" — proceed to spec with `Status: draft`.
- Soft cap at `--max-rounds` (default 12): when reached, summarize remaining gaps and ask whether to continue or wrap up.
- Do not implement code in this skill — produce the spec only.
- Write the final spec to `.dt-handoff/<slug>/spec.md` (create the directory if missing), with the hand-off descriptor frontmatter below.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: the language setting from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese (ISO 639-1 `ko`/`en`/`ja`/`zh` accepted). Custom values passed through as free text. Governs both the interview questions and the spec body.
- `--max-rounds=<n>`: soft cap on interview rounds. Default `12`.
</Settings_Reference>

<Arguments>
- `$ARGUMENTS`: optional topic, OR a file path to read the topic from, plus optional flags:
  - `--lang=<value>` — output language override (e.g., `--lang=en`)
  - `--max-rounds=<n>` — soft round-cap override
- If `$ARGUMENTS` resolves to an existing file path, read it and treat its contents as the interview topic/seed.
- Examples:
  - `/interview "Slack 알림 봇"`
  - `/interview ./notes/idea.md --lang=en`
  - `/interview` (bare invocation — first question asks what to interview about)
</Arguments>

<Steps>

### Step 1: Capture the topic
1. Parse `--lang` and `--max-rounds` from `$ARGUMENTS` (defaults: `$LANGUAGE`, `12`).
2. Determine the seed topic:
   - If the remaining `$ARGUMENTS` is an existing file path, `Read` it and use its contents.
   - Else if it contains free text, use that text.
   - Else `AskUserQuestion` in `$LANGUAGE`: "어떤 주제로 인터뷰를 진행할까요?"
3. Restate the topic in one sentence to confirm understanding, then announce the interview in `$LANGUAGE`:

```
가볍게 인터뷰를 시작합니다. 한 번에 하나씩, 핵심을 찌르는 질문을 드릴게요. (최대 {max_rounds}라운드)

Topic: "<restated topic>"
```

### Step 2: Interview loop
Repeat until all applicable dimensions are covered OR the user exits early OR the soft cap is reached.

**Step 2a — Pick the next dimension.** Cycle through the dimensions below, targeting whichever is least covered so far. Do not ask two questions in a row on the same dimension unless the previous answer opened a sharp follow-up.

| Dimension | What to probe | Example question |
|-----------|---------------|------------------|
| Goal | the precise outcome and the *why* | "이 기능이 없으면 사용자가 지금 어떤 우회 방법을 쓰고 있나요?" |
| Scope / Non-Goals | the boundary, what's explicitly out | "이번 버전에서 일부러 빼고 싶은 건 무엇인가요?" |
| Technical Implementation | data flow, integration points, state, failure handling | "이 데이터는 어디서 와서 어디에 저장되고, 중간에 실패하면 어떻게 복구하나요?" |
| UI & UX | the user's first action, error states, empty/edge states | "처음 진입했을 때 화면에 아무 데이터도 없으면 무엇을 보여줄까요?" |
| Concerns & Risks | the part most likely to break, scale/security/perf worries | "이 설계에서 가장 불안한 부분 하나만 꼽는다면요?" |
| Tradeoffs | alternatives considered, what was rejected and why | "고려했다가 접은 다른 접근이 있나요? 왜 접었나요?" |

**Step 2b — Ask.** Emit the context line `[Round {n} · {dimension}]` as plain text, then call `AskUserQuestion` with only the question in the `question` field. Set the `header` chip to the dimension. Provide short, scannable, contextually-relevant options plus free-text; put any recommended option first.

**Step 2c — Absorb & follow up.** Record the answer. If it exposes a sharper non-obvious gap, ask one focused follow-up next round; otherwise rotate to the least-covered dimension.

**Step 2d — Check limits.**
- Early exit at any round on "충분해" / "enough" / "그만" / "let's go" → go to Step 3 with `Status: draft`.
- Soft cap (`--max-rounds`, default 12): summarize remaining gaps in `$LANGUAGE` and `AskUserQuestion` whether to continue or wrap up.
- User says "stop" / "취소" / "cancel": stop immediately; do not write a spec.

### Step 3: Write the spec
1. **Slugify** the topic for the filename.
2. **Create** `.dt-handoff/<slug>/` if missing (`mkdir -p`).
3. **Compute** the body's `sha256` and byte count for the descriptor.
4. **Write** the spec to `.dt-handoff/<slug>/spec.md` with the descriptor frontmatter, then the body.
5. **Show** the user the absolute path of the written file.

**Hand-off descriptor frontmatter** (machine-truth schema in `scripts/validate.sh`; see `DESC_REQUIRED_FIELDS` and enum vars):

```yaml
---
kind: spec
path: .dt-handoff/<slug>/spec.md
contentHash: sha256:<hash of body below>
createdAt: <ISO8601-now>
producer: interview
sizeBytes: <byte count of body below>
retention: permanent
expiresAt: null
status: complete        # or draft when ended via early exit
---
```

Spec structure (headers stay English; content in `$LANGUAGE`):

```markdown
# Interview Spec: <title>

## Metadata
- Generated: <YYYY-MM-DD>
- Rounds: <count>
- Source: <topic text | file path>
- Status: complete | draft

## Goal
<one-sentence success statement>

## Scope
- …

## Non-Goals
- …

## Technical Implementation
- …

## UI & UX
- …            (or "N/A — <reason>")

## Concerns & Risks
- …

## Tradeoffs
| Choice | Alternative considered | Why this one |
|--------|------------------------|--------------|
| …      | …                      | …            |

## Open Questions
- …

## Interview Transcript
<details>
<summary>Full Q&A (<n> rounds)</summary>

### Round 1 · <dimension>
**Q:** …
**A:** …

### Round 2 · <dimension>
…
</details>
```
</Steps>

<Tool_Usage>
- `AskUserQuestion` for every interview question — one per turn, with contextual options + free-text.
- `Read` to load the topic when `$ARGUMENTS` is a file path.
- `Bash` only to: create the slug directory (`mkdir -p .dt-handoff/<slug>/`) and compute the `sha256` hash + byte count for the descriptor.
- `Write` to save the final spec to `.dt-handoff/<slug>/spec.md`.
- Do NOT dispatch `analyst`, `critic`, `explorer`, or any other agent — that machinery belongs to `deep-interview`. Do NOT append `events.jsonl` entries (this lightweight skill has no control-plane events).
- Do NOT implement code or delegate execution — producing the spec is the terminal step.
</Tool_Usage>

<Examples>
**Example 1 — free-text topic:**
User: "/interview Slack 알림 봇"
Flow: restate topic → announce (max 12 rounds) → Round 1 Goal ("지금은 알림을 어떻게 받고 있나요?") → Round 2 Technical ("어떤 이벤트가 트리거이고 어디로 보내나요?") → Round 3 UI&UX → Round 4 Concerns → Round 5 Tradeoffs → coverage complete → write `.dt-handoff/slack-notify-bot/spec.md` (Status: complete) → show path.

**Example 2 — topic from a file:**
User: "/interview ./notes/idea.md"
Flow: `Read` `./notes/idea.md` → restate → interview rotating across dimensions, skipping UI & UX for a headless tool (noted as N/A) → write spec.

**Example 3 — early exit:**
User (after round 4): "충분해, 그대로 가자"
Flow: stop interviewing → write spec with `Status: draft`, remaining dimensions captured as Open Questions → show path.

**Example 4 — `--lang=en`:**
User: "/interview 'CLI habit tracker' --lang=en"
Flow: interview and spec written in English → `.dt-handoff/cli-habit-tracker/spec.md`.

**Example 5 — bare invocation:**
User: "/interview"
Flow: `AskUserQuestion` "어떤 주제로 인터뷰를 진행할까요?" → user answers → continue from Step 1.

**Example 6 — wrong fit, route away:**
User: "심층 인터뷰로 스펙 빡세게 잡아줘"
Flow: this is the heavy flow — do not run; suggest `/deep-interview` instead.
</Examples>

<Final_Checklist>
- Did I capture the topic (free text or file) and restate it in one sentence before interviewing?
- Did I ask exactly ONE non-obvious question per turn in `$LANGUAGE`, with the metadata in a plain context line (not packed into the `question` field)?
- Did I rotate across Goal / Scope / Technical / UI & UX / Concerns / Tradeoffs, skipping only genuinely-inapplicable dimensions (and noting the skip)?
- Did I avoid scoring ambiguity, locking topology, and dispatching any agent (that is `deep-interview`'s job)?
- Did I honor early exit / soft cap / cancel correctly?
- Does the spec cover Goal / Scope / Non-Goals / Technical Implementation / UI & UX / Concerns & Risks / Tradeoffs / Open Questions / Transcript?
- Did I write the spec to `.dt-handoff/<slug>/spec.md` with valid descriptor frontmatter (`producer: interview`, `status: complete|draft`)?
- Did I show the absolute path of the written spec?
- Did I avoid implementing code (this skill is requirements-only)?
</Final_Checklist>
