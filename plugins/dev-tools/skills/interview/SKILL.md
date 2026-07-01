---
name: interview
description: >
  Interactive requirements-clarification interview that turns a vague request into a
  pipeline-ready spec. Delegates to the `analyst` agent to surface ambiguities, hidden
  assumptions, and gaps, then resolves each with the user via `AskUserQuestion` — offering
  concrete candidate answers (with a marked default where one clearly fits) and batching
  independent clarifications into one call — and writes a clarified `spec.md` that
  `/autopilot` and `/ralplan` can consume. TRIGGER when the user has a fuzzy
  idea/spec/request and wants the ambiguity resolved into clear requirements — "clarify
  this", "ask me what you need to build this", "interview me to nail down requirements",
  "이거 애매한데 질문해서 정리해줘", "요구사항 명확히 해줘", "모호한 부분 짚어서 스펙으로 만들어줘",
  "/interview". DO NOT TRIGGER when the request is already unambiguous (go straight to
  /ralplan or /autopilot), when the user wants to reach their OWN design decisions by being
  questioned without being handed answers (use buddy:socratic-interview), or when they just
  want it built ("그냥 만들어줘", "just build it").
---

<Purpose>
Turn a vague idea, feature request, or rough spec into a **clarified, actionable spec** by: (1) delegating to the `analyst` agent to surface ambiguities, hidden assumptions, and gaps with per-dimension clarity scoring, then (2) resolving each open point interactively via `AskUserQuestion` — concrete candidate answers, a marked default where one clearly fits, and independent clarifications batched into a single call. The output is a `spec.md` (Goal / Requirements / Constraints / Acceptance Criteria / resolved assumptions / open questions) that `/autopilot` Phase 1 and `/ralplan` consume directly. Unlike a Socratic thinking-partner, this skill's job is to **resolve** ambiguity into an artifact, not to keep the decision open.
</Purpose>

<Use_When>
- The user brings a fuzzy idea/feature/spec and wants the ambiguity pinned down into concrete requirements before planning or building.
- Before `/autopilot` or `/ralplan`, when the request is too ambiguous for the non-interactive Phase 1 intake (which stops `PHASE1_AMBIGUOUS`) — run this first to produce the `spec.md` it will reuse.
- `analyst` or `/autopilot` Phase 1 reported ambiguity above threshold and you want to close the gaps interactively rather than rewrite the idea by hand.
- The user would rather be asked targeted questions with candidate answers than free-write a full spec.
- Trigger phrases (EN): "clarify this", "ask me what you need to build this", "interview me to nail down the requirements", "/interview".
- Trigger phrases (KO): "이거 애매한데 질문해서 정리해줘", "요구사항 명확히 해줘", "모호한 부분 짚어서 스펙으로 만들어줘".
</Use_When>

<Do_Not_Use_When>
- The request is already unambiguous — skip clarification and go straight to `/ralplan` or `/autopilot`.
- The user wants to reach their OWN design decisions by being questioned, without being handed candidate answers or a finished spec — that is `buddy:socratic-interview` (it keeps the pen in their hand; this skill resolves the ambiguity *for* them and emits an artifact).
- The user just wants it built now ("그냥 만들어줘", "just build it") — go to `/autopilot` or `/ralph`.
- It is a simple factual lookup (an API signature, how a library behaves) — answer directly.
- A vetted plan already exists and only execution remains — use `/ralph` or `/team`.
</Do_Not_Use_When>

<Why_This_Exists>
The orchestration pipeline's Phase 1 intake is deliberately non-interactive: `analyst` scores the idea's ambiguity and, if it is above `--threshold`, `/autopilot` stops `PHASE1_AMBIGUOUS` and asks for a clearer idea or a pre-written `spec.md` — it will **not** interview in-loop. That leaves a gap: someone has to turn the fuzzy idea into that clearer spec. This skill is that step. It reuses the same `analyst` decomposition the pipeline already trusts, but adds the interactive resolution loop autopilot intentionally omits — asking the user to settle each ambiguity via `AskUserQuestion` with concrete options — and emits the exact `spec.md` the pipeline consumes. It is the front door to the pipeline for anything that starts vague. (For sharpening your *own* thinking without being handed answers, that is a different goal — see `buddy:socratic-interview`.)
</Why_This_Exists>

<Execution_Policy>
- **Always run the `analyst` decomposition first** — do NOT hand-roll the ambiguity analysis. `analyst` is the sanctioned engine for requirement decomposition, assumption classification (Stated/Inferred/Speculative), clarity scoring, and gap-with-clarifying-question output.
- **Resolve open points via `AskUserQuestion`.** Give each question 2–4 concrete candidate answers grounded in `analyst`'s assumptions/gaps and the codebase — the user picks rather than free-writing a spec.
- **A marked default is allowed here.** Unlike `buddy:socratic-interview`, this skill exists to *resolve* ambiguity, so it MAY mark a sensible default `(Recommended)` (place it first) where one clearly fits — e.g. an assumption `analyst` labeled `Inferred` with an obvious conventional default. Never fabricate a default where the choice is genuinely open; leave those to the user.
- **Batch independent clarifications** into a single `AskUserQuestion` call (up to 4 questions). Sequence questions only when a later one genuinely depends on an earlier answer — then ask the blocking one first and re-carve the next from the answer.
- **Trust "Other" as the escape hatch.** `AskUserQuestion` always offers free-text "Other"; do not fabricate a "none of these" option.
- **Prioritize by leverage.** Resolve the ambiguities that most reduce aggregate ambiguity first (lowest-clarity dimensions, gaps blocking the most requirement units). Do NOT ask about points already settled by `$ARGUMENTS` or the codebase.
- **Fold every answer into the spec** as a concrete requirement, constraint, or acceptance criterion; record which prior assumption or gap it resolved.
- **Stop at the gate.** Stop when residual ambiguity is low (mirror the pipeline gate: `1 − weighted clarity` ≤ `--threshold`, default `0.2`) or when the user chooses to stop. Never force completion.
- **Read-only on the user's code.** Read to ground the questions; never modify source. The only sanctioned write is the clarified `spec.md`.
- Conduct the interview (question + option text) and write the spec in `$LANGUAGE`; structural headers (`## Goal`, `## Requirements`, `## Constraints`, `## Acceptance Criteria`) stay English per repo convention — only their content is translated.
- **Output placement**: slug context (`--slug=<slug>` or an active hand-off slug) → write `.dt-handoff/<slug>/spec.md` with descriptor frontmatter and tell the user it is ready for `/autopilot` / `/ralplan`. Free-standing (no slug) → present the spec inline; write a file only if the user names a path or accepts a derived slug (confirm once). Never auto-commit or open a PR.
</Execution_Policy>

<Arguments>
- `$ARGUMENTS`: the request to clarify — an idea, feature, rough spec, or a path to one — and the seed material for the `analyst` pass and the first questions. If omitted, take the most recent request in the conversation.
- `--slug=<slug>`: write the clarified spec to `.dt-handoff/<slug>/spec.md` (pipeline hand-off). Without it, the skill runs free-standing and presents the spec inline.
- `--threshold=<0.0–1.0>`: residual-ambiguity stop gate (default `0.2`), matching `/autopilot`'s Phase 1 gate.
- `--lang=<value>`: override `$LANGUAGE` for this invocation.
</Arguments>

<Settings_Reference>
- `$LANGUAGE`: `settings.language` from `plugin.json` (default `Korean`). Override per-invocation with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese (ISO 639-1 `ko`/`en`/`ja`/`zh` accepted; custom strings passed through). Governs the interview dialogue (question + option text) and the clarified spec's content. Structural section headers (`## Goal`, `## Requirements`, `## Constraints`, `## Acceptance Criteria`) stay English; only their content is translated.
</Settings_Reference>

<Steps>
1. **Intake & ground.** Take the request from `$ARGUMENTS` (or the latest conversation request). If it references files or a codebase, use Read/Grep/Glob (read-only) to ground the upcoming questions in reality. Resolve `--slug`, `--threshold`, and `--lang`.
2. **Surface ambiguity via `analyst`.** Dispatch `Task(subagent_type="analyst", …)` with the request. Ask for the standard output: requirement decomposition (R-NN), assumptions labeled Stated/Inferred/Speculative, per-dimension + aggregate clarity scores, and gaps each paired with a clarifying question. Inline the request in the prompt when it is ≤ 4096 bytes; otherwise write it under `.dt-handoff/<slug>/` and pass an `@handoff-in` pointer. Slug context → have `analyst` persist to `.dt-handoff/<slug>/artifacts/ask/analyst-<ISO8601>.md` and return an `@handoff-out` block; free-standing → have it return the decomposition in-session (no file), mirroring `code-review`'s free-standing convention.
3. **Prioritize the open points.** From `analyst`'s gaps + Speculative/Inferred assumptions + lowest-clarity dimensions, order the clarifications by how much each reduces aggregate ambiguity. Drop any point already settled by `$ARGUMENTS` or the codebase.
4. **Resolve via `AskUserQuestion` (batched).** For each independent group (up to 4 questions per call), pose the clarifying question with 2–4 concrete candidate answers built from `analyst`'s assumptions and the codebase; mark one `(Recommended)` only where a default clearly fits; rely on "Other" for anything off-menu. Sequence only genuinely dependent questions, re-carving each from the prior answer.
5. **Fold answers into the spec.** Turn each answer into a concrete requirement / constraint / acceptance criterion, noting the assumption or gap it resolved. Update the working clarity picture.
6. **Re-check the gate.** If residual ambiguity is still above `--threshold` and material open points remain, run another round (Step 4). Optionally re-dispatch `analyst` on the revised spec once to confirm the aggregate clarity rose above the gate. Stop when at/under threshold or when the user stops.
7. **Emit the clarified spec (`$LANGUAGE`).** Compose it under English headers: `## Goal`, `## Requirements` (each traceable to a resolved point), `## Constraints`, `## Acceptance Criteria`, `## Resolved Assumptions`, `## Open Questions` (anything left deliberately unresolved). Slug context → write `.dt-handoff/<slug>/spec.md` with the descriptor frontmatter below, then tell the user it is ready for `/autopilot` or `/ralplan`. Free-standing → present inline; offer to persist to a path or a derived slug (confirm once) — never write silently.

   Descriptor frontmatter for a written `spec.md`:
   ```
   ---
   kind: spec
   path: .dt-handoff/<slug>/spec.md
   contentHash: sha256:<sha256 of the body below, excluding this block>
   createdAt: <ISO8601-now>
   producer: interview
   sizeBytes: <byte count of the body below>
   retention: permanent
   expiresAt: null
   status: complete
   ---
   ```
   Compute `contentHash` (sha256 of the body bytes) and `sizeBytes` (byte length of the body) at write time. (Schema source of truth: the `scripts/validate.sh` header.)
8. **Close.** Report aggregate clarity before → after and where the spec landed (path or inline). Never auto-commit, push, or open a PR.
</Steps>

<Tool_Usage>
- **Task → `analyst`** — the sanctioned engine for the ambiguity map (decomposition, assumption classification, clarity scoring, gaps + clarifying questions). Always dispatched in Step 2; do NOT inline the analysis. Bare name, no plugin prefix. The `@handoff-in` / `@handoff-out` contract is documented in `agents/analyst.md` and the `scripts/validate.sh` header — pass an `@handoff-in` pointer only when the request exceeds the 4096-byte inline threshold.
- **AskUserQuestion** — the resolution mechanic. 2–4 concrete candidate answers per question; independent questions batched (≤ 4 per call); a marked `(Recommended)` default only where one clearly fits; the built-in "Other" as escape hatch. Do not fabricate a "none of these" option, and do not batch genuinely dependent questions.
- **Read / Grep / Glob** — read-only grounding of questions and candidate answers in the user's docs/codebase before asking.
- **Bash** — light read-only context (e.g., `git log`) plus the single sanctioned write of `spec.md` (slug context or a user-named path) via heredoc/redirect restricted to `.dt-handoff/<slug>/**` (or the named path). No other disk writes.
- **Write** — only to emit the clarified `spec.md` to the resolved path. Never modify the user's source; never auto-commit or open a PR.
</Tool_Usage>

<Examples>
**Example 1 — vague idea, free-standing (inline spec):**
User: "/interview I want to add search to the app." → Step 2 dispatches `analyst`, which returns gaps (what is searched? full-text or filter? latency budget? auth-scoped results?) and aggregate clarity 0.45. Step 4 batches the independent ones into one `AskUserQuestion` call: "What does search cover?" (options: content / metadata / both), "Match style?" (substring `(Recommended)` / full-text / fuzzy), "Results scoped to the current user?" (yes `(Recommended)` / no). The user picks, "Other"s the latency answer. Step 7 presents the clarified spec inline (no slug given) and offers to save it.

**Example 2 — slug context feeding the pipeline (writes spec.md):**
User: "/interview --slug=checkout-rework rework the checkout flow". → `analyst` persists its decomposition to `.dt-handoff/checkout-rework/artifacts/ask/analyst-<ISO8601>.md`; two `AskUserQuestion` rounds resolve the gaps; aggregate clarity rises 0.5 → 0.85 (> 1 − 0.2 gate). Step 7 writes `.dt-handoff/checkout-rework/spec.md` with descriptor frontmatter (`kind: spec`, `producer: interview`, `retention: permanent`, `status: complete`) and reports: "spec ready — run `/autopilot --resume=auto` or `/ralplan --from-spec=.dt-handoff/checkout-rework/spec.md`."

**Example 3 — routing away (wrong skill):**
User: "interview me so I figure out the design myself — don't give me answers." → This is the thinking-partner goal, not ambiguity-resolution. Defer: "That's `buddy:socratic-interview` — it poses one question at a time and keeps every decision yours. This skill instead proposes candidate answers and writes a spec. Want me to hand off?"
</Examples>

<Final_Checklist>
- Did I run the `analyst` decomposition first (Step 2) rather than hand-rolling the ambiguity analysis?
- Did I resolve open points via `AskUserQuestion` with concrete candidate answers, batching independent ones (≤ 4 per call) and sequencing only genuinely dependent ones?
- Did I mark `(Recommended)` only where a default clearly fit, and rely on "Other" instead of a fabricated "none of these"?
- Did I prioritize by leverage and skip points already settled by `$ARGUMENTS`/the codebase?
- Did I fold every answer into a concrete requirement/constraint/criterion and stop at/under `--threshold` (or on user stop) without forcing completion?
- Did I emit the spec with English structural headers and `$LANGUAGE` content — writing `spec.md` (+ descriptor) in slug context, inline (no silent write) free-standing?
- Did I keep the user's source read-only and avoid any auto-commit/PR?
</Final_Checklist>
</content>
</invoke>
