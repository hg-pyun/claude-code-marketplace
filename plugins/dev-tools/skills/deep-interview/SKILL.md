---
name: deep-interview
description: >
  Socratic deep interview with mathematical ambiguity gating and challenge
  agents. Surfaces hidden assumptions, scores clarity per dimension
  (Goal/Constraints/Criteria/Context), and refuses to hand off until no blocking
  gap remains (tracked via ambiguity scoring against the threshold). Produces a structured spec at
  `.dt-handoff/<slug>/spec.md` in `$LANGUAGE`. Delegates hidden-constraint
  extraction and gate verification to `analyst` at checkpoints; brownfield
  mapping to `explorer`; challenge modes (Contrarian/Simplifier/Ontologist) to
  `critic`.
  TRIGGER when: user wants thorough requirements gathering before any coding,
  says "스펙 잡아줘", "deep interview", "심층 인터뷰", "ouroboros",
  "socratic", "interview me", "ask me everything", "don't assume", or invokes
  `/deep-interview`. Depth markers ("심층", "ouroboros", "socratic", ambiguity
  scoring) route here, not to the lightweight `interview` sibling.
  DO NOT TRIGGER when: user wants the lightweight conversational flow
  ("가볍게", "빠르게", "quick interview") — route to `interview`; user already
  has a detailed spec (use a review skill),
  is asking conceptually what an interview is, wants a single small change with
  obvious scope, says "just do it / skip the questions", or already has a PRD
  and wants execution.
argument-hint: "[brief idea] [--lang=<value>] [--threshold=<0.0-1.0>] [--max-rounds=<n>]"
---

<Purpose>
Interview the user in `$LANGUAGE` to capture requirements for a new project, feature, or change using Socratic questioning with mathematical ambiguity scoring. Draft a best-guess spec up front from the seed idea (and any brownfield findings) so the user corrects deltas instead of answering every dimension from scratch, then ask one question at a time targeting whichever dimension still has a *blocking* gap, delegate hidden-constraint extraction and gate verification to the `analyst` agent at fixed checkpoints (post-draft, pre-crystallize, scope shift), activate challenge perspective via the `critic` agent (Contrarian/Simplifier/Ontologist modes) at preset thresholds, and refuse to finalize the spec until no blocking gap remains — tracked via per-dimension ambiguity scoring against the threshold (default 0.2) — OR the user explicitly opts out with a warning. Output is a structured spec document at `.dt-handoff/<slug>/spec.md`. This skill does NOT implement code — it produces the spec only.
</Purpose>

<Use_When>
- User wants to capture requirements before any coding starts ("스펙 잡아줘", "plan this out", "deep interview")
- User invokes `/deep-interview` (or pastes `/deep-interview <topic>`)
- User has a rough/vague idea and wants help crystallizing it into a written spec
- User wants mathematically-validated clarity (per-dimension scoring, threshold gate) before committing to execution
- User wants to avoid "that's not what I meant" outcomes from autonomous execution
- Task is complex enough that jumping straight to code would waste cycles on scope discovery
</Use_When>

<Do_Not_Use_When>
- User already has a detailed spec and wants it reviewed — use `code-review` or a review skill
- User asks conceptually what an interview is — answer directly
- The task is a single small change with obvious scope — just do it
- User wants only a quick brainstorm chat without a written artifact
- User says "just do it" / "skip the questions" — respect intent: end the interview, write what you have as a `draft` spec, do not auto-execute
- User already has a PRD/plan file and explicitly asks to execute it — use the requested execution path with that plan
</Do_Not_Use_When>

<Why_This_Exists>
Many feature requests start as a one-line idea. Without structure, an engineer either assumes (and gets it wrong) or burns an hour clarifying conversationally. A plain free-form interview also tends to ask "what do you want?" instead of "what are you assuming?" — so vague answers go unchallenged.

This skill applies Socratic methodology with three mechanical guardrails:
1. **Per-dimension clarity scoring** with a hard threshold gate, so the interview cannot end while a dimension is still vague.
2. **Round 0 topology lock**, so depth-first questioning cannot overfit one component while siblings stay ambiguous.
3. **Challenge modes via `critic`** at preset rounds, so habitual framings (scale, constraints, ontology) get tested instead of accepted.

Inspired by the [Ouroboros project](https://github.com/Q00/ouroboros), which demonstrated that specification quality is the primary bottleneck in AI-assisted development.
</Why_This_Exists>

<Execution_Policy>
- Interview questions and the final spec are written in `$LANGUAGE`.
- Section headers in the spec stay English; content is `$LANGUAGE`.
- Use `AskUserQuestion` — ONE question per turn. Never batch.
- **Draft-first.** Before interrogating, fill every dimension you can reasonably infer from the seed idea + `explorer` findings into a strawman spec draft and present it for correction (Round 1). Only ask about what you genuinely cannot infer or what the user alone must decide. Confirming/correcting a draft is far faster than answering open questions — never ask for anything already derivable from the idea or the codebase.
- Each round names the **target component**, **weakest dimension**, **why now**, and the **current ambiguity score** — as a single context line emitted *before* the `AskUserQuestion` call, NOT crammed into the question text.
- Cover the rubric: Goal / Constraints / Acceptance Criteria / Technical Direction / Context (brownfield) / Open Questions / Out of Scope.
- Detect brownfield vs greenfield **inline** with a single `Glob`/`ls` pass (package files, source dirs) — no agent dispatch. Dispatch the bundled `explorer` agent at most **once**, for brownfield mapping only, **before** asking the user about codebase facts; greenfield interviews dispatch no explorer at all. Cite the discovered file/path/pattern in any confirmation question.
- Score ambiguity **inline every round** using the Step 3e formula — inline scoring is this skill's identity and is never delegated wholesale. Multi-component arithmetic (per-component minimum scores, target rotation) is part of the inline pass, never a dispatch trigger. Dispatch the `analyst` agent only at **checkpoints**: (a) once right after the Round 1 draft correction (hidden-constraint extraction at the point of maximum information), (b) once immediately before crystallization (gate verification), (c) when an answer introduces new scope or contradicts an earlier one. Analyst payloads carry the **delta** (latest Q&A + current score table), never the full accumulated transcript.
- Round 0 topology gate runs **once** before ambiguity scoring; lock the top-level component list before any depth-first questioning.
- Score clarity after every answer; show the score transparently.
- **Gate on blocking gaps, not on chasing decimals.** Keep scoring per dimension (the ambiguity score stays the visible signal), but a dimension only holds the interview open while it has a *blocking* gap — an unknown that would change the spec or send execution the wrong way. Once no blocking gap remains, proceed to the spec even if the score sits slightly above threshold; never spend rounds shaving a non-blocking score (e.g. 0.3→0.2).
- When the locked topology has multiple active components, score each one and rotate question targeting across them.
- Challenge modes are opt-in pressure, not mandatory ceremony: dispatch `critic` only when the interview reaches the relevant round AND a real assumption/complexity/ontology gap remains (Contrarian @ R4, Simplifier @ R6, Ontologist @ R8 when ambiguity > 0.3). Short interviews that hit the threshold early skip them entirely. Each mode is used at most once. Contrarian and Simplifier use the `critic` fast-path (`note: mode=challenge-single` — one most-fragile assumption + one question seed) or may run inline for light interviews; Ontologist and stall reframing always dispatch `critic` in full mode.
- Allow early exit at any round with a transparent warning showing remaining gaps.
- Soft warning at round 10; hard cap at round 20.
- Do not implement code in this skill — produce the spec only.
- Write the final spec to `.dt-handoff/<slug>/spec.md` (create `.dt-handoff/<slug>/` if missing).
- Append control-plane events to `.dt-handoff/<slug>/events.jsonl` for each agent dispatch and return — batched: ONE Bash call after the agent returns computes the artifact `sha256` and appends both events (see `Tool_Usage`). No per-event Bash calls.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: the language setting from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted as free text.
- `--threshold=<0.0-1.0>`: ambiguity threshold for the gate. Default `0.2` (20%). The interview proceeds to spec crystallization once no blocking gap remains (typically ambiguity ≤ threshold).
- `--max-rounds=<n>`: hard cap on interview rounds. Default `20`. Soft warning at `10`.
</Settings_Reference>

<Arguments>
- `$ARGUMENTS`: optional brief idea/topic plus optional flags:
  - `--lang=<value>` — output language override (e.g., `--lang=en`)
  - `--threshold=<0.0-1.0>` — ambiguity threshold override
  - `--max-rounds=<n>` — round cap override
- Examples:
  - `/deep-interview "Linear webhook 처리 서비스"`
  - `/deep-interview "auth refactor" --lang=en --threshold=0.15`
  - `/deep-interview` (bare invocation — first question asks what to spec)
</Arguments>

<Steps>

### Phase 0: Resolve Threshold

Before any user-visible announcement:
1. Parse `--threshold` and `--max-rounds` from `$ARGUMENTS`; fall back to defaults (`0.2`, `20`).
2. Emit exactly this first line in `$LANGUAGE` (English shown below):

```
Deep Interview threshold: <threshold_percent>%  (max rounds: <max_rounds>)
```

This line is required before any other interview content.

### Phase 1: Initialize

1. **Capture the seed idea.**
   - If `$ARGUMENTS` contains a topic, use it.
   - Otherwise `AskUserQuestion`: "오늘 어떤 걸 스펙으로 잡을까요?" (in `$LANGUAGE`).
   - Restate the idea in one sentence to confirm understanding before going further.
2. **Detect brownfield vs greenfield — inline, no dispatch.**
   - Run ONE `Glob`/`ls` pass over the cwd for package/manifest files (`package.json`, `pyproject.toml`, `go.mod`, …) and source directories relevant to the idea.
   - If source files exist AND the idea references modifying/extending something → **brownfield**.
   - Otherwise → **greenfield** — no `explorer` dispatch at all; proceed directly toward Round 0.
3. **For brownfield only**: dispatch `explorer` once to map relevant codebase areas (modules, key files, patterns). Store as `codebase_context`. Use it to avoid re-asking facts the code already reveals. After it returns, log both events to `.dt-handoff/<slug>/events.jsonl` with the single batched Bash call described in `Tool_Usage`:
   ```json
   {"ts":"<dispatch-ISO8601>","producer":"deep-interview","consumer":"explorer","event":"dispatch","kind":"handoff","path":null,"status":"pending","verdict":null}
   {"ts":"<return-ISO8601>","producer":"explorer","consumer":"deep-interview","event":"return","kind":"advisor","path":null,"status":"complete","verdict":null}
   ```
4. **Downshift check.** If detection plus the seed idea reveal a single component with clear scope (and the user used no depth marker — "심층", "ouroboros", "socratic", an explicit threshold), offer once via `AskUserQuestion`: "범위가 명확해 보입니다 — 가벼운 `/interview`로 진행할까요?" On accept, hand off to the `interview` skill; on decline, continue here.
5. **Announce the interview** in `$LANGUAGE`:

```
시작합니다. 먼저 아는 것으로 초안을 채운 뒤, 막는 부분(blocking gap)만 하나씩 짚어가며 진행합니다.

Idea: "<restated idea>"
Project type: greenfield | brownfield
Ambiguity: not scored yet
```

### Phase 2: Round 0 — Topology Enumeration Gate

Run this gate exactly once before any ambiguity scoring.

1. **Enumerate candidate top-level components** from the idea (+ brownfield context):
   - Extract top-level verbs/nouns, workstreams, surfaces, integrations, or deliverables that can succeed or fail independently.
   - Prefer 1–6 components. Group siblings if more.
   - Do not treat fields or sub-features as top-level components unless framed as independent outcomes.
2. **N = 1 fast path — auto-lock.** If enumeration yields exactly one top-level component, skip the topology confirmation question entirely: lock the single-component topology immediately and fold the topology statement into the Round 1 draft — the draft opens by naming the component ("단일 컴포넌트로 보고 있습니다: <name> — <description>"), so the user's draft-correction pass covers it as a correction option. If the correction splits the topology, re-run this gate before continuing. Lock-before-scoring still holds: the auto-lock happens before any ambiguity scoring.
3. **N ≥ 2 — ask one confirmation question** via `AskUserQuestion`:

```
Round 0 | Topology confirmation | Ambiguity: not scored yet

I'm reading this as N top-level component(s):
1. <component_name>: <one-sentence description>
2. ...

Is that topology right? Should any component be added, removed, merged, split, or explicitly deferred?
```

Options should include **Looks right**, **Add/remove/merge**, **Defer one or more**, plus free-text.

4. **Lock topology** for the rest of the interview. Record per-component status (`active` | `deferred`), description, and (later) per-dimension clarity scores. Deferred components are excluded from ambiguity math but remain in the final spec.

### Phase 3: Interview Loop

Repeat until **no blocking gap remains** (`ambiguity ≤ threshold` is the usual corollary) OR user exits early OR hard cap reached.

**Round 1 — Present the draft.** Before any targeted question, present the strawman spec draft built from the seed idea + `explorer` findings + the locked topology: a best-guess Goal, Constraints, Success Criteria, and Technical Direction for each active component (for an N = 1 auto-lock, the draft opens with the topology statement per Phase 2). Ask the user to confirm/correct it in a single pass via `AskUserQuestion` (options such as `대체로 맞음` / `Goal 수정` / `Constraints 수정` / `범위 수정` plus free-text). Score the corrected draft — this one pass typically resolves several dimensions at once and leaves only a few blocking gaps. **Analyst checkpoint (a):** immediately after scoring the corrected draft, dispatch `analyst` once for hidden-constraint extraction — this is the point of maximum information (seed idea + brownfield context + corrected draft); send the delta payload per Step 3c. Then enter the loop below, which targets ONLY the dimensions that still have a *blocking* gap. (This draft-correction pass **counts as Round 1**: the ontology extracted from the corrected draft is the Round 1 baseline for Step 3d, and it is recorded as Round 1 in the transcript — with the draft shown in place of the question.)

**Step 3a — Generate next question.** Identify the active (component, dimension) pair with the LOWEST clarity score. When N > 1 active components are similarly weak, rotate targeting (don't ask twice in a row about the same component). State, in one sentence, why this pair is the bottleneck.

| Dimension | Question style | Example |
|-----------|----------------|---------|
| Goal Clarity | "What exactly happens when…?" | "When you say 'manage tasks', what specific action does a user take first?" |
| Constraint Clarity | "What are the boundaries?" | "Should this work offline, or is connectivity assumed?" |
| Success Criteria | "How do we know it works?" | "If I showed you the finished product, what would make you say 'yes, that's it'?" |
| Context (brownfield) | "How does this fit?" | "I found JWT middleware in `src/auth/`. Extend that path or intentionally diverge?" |
| Scope-fuzzy / ontology | "What IS the core thing here?" | "You named Tasks, Projects, and Workspaces. Which is the core entity, and which are supporting views?" |

Brownfield confirmation questions MUST cite the repo evidence (file path / symbol / pattern) that triggered the question.

**Step 3b — Ask the question** via `AskUserQuestion`.

Emit ONE short context line as plain text **immediately before** the tool call, then put ONLY the question itself in the `question` field — never pack the metadata into the question text (it makes the prompt unreadable).

Context line (plain text, before the tool call):
```
[Round {n} · {target_component} · 모호도 {score}% · {why_now}]
```

`AskUserQuestion` `question` field (the question, nothing else):
```
{question}
```

Set the `header` chip to the targeted dimension (e.g. `Constraints`, `Goal`). Options should be short, scannable, contextually relevant choices plus free-text; put any recommended option first.

**Step 3c — Score the answer (inline every round; `analyst` at checkpoints).** After the user's answer, score the dimensions yourself using the Step 3e formula — every round, for any number of active components. Multi-component arithmetic (per-component minimum scores, rotation targeting) is part of this inline pass and is never by itself a reason to dispatch. Ordinary inline-scored rounds dispatch no agent and log nothing to `events.jsonl`.

Dispatch `analyst` only at these **checkpoints**:
- **(a) Post-draft** — once, immediately after the Round 1 draft correction (hidden-constraint extraction at the point of maximum information).
- **(b) Pre-crystallize** — once, immediately before Phase 5 writes the spec (gate verification; see Phase 5).
- **(c) Scope shift** — when an answer introduces new scope or contradicts an earlier answer.
- *(The 3-round stall rule in `Advanced` is unchanged — a stall reframes via `critic` (Ontologist), not `analyst`.)*

When dispatching, write the **delta** — the latest Q&A (the corrected draft, at checkpoint (a)) plus the current per-component score table — to `.dt-handoff/<slug>/artifacts/ask/analyst-<ISO8601>.md`. Never resend the full accumulated transcript. Dispatch `analyst` with an `@handoff-in` block; delta payloads are small, so when `sizeBytes ≤ 4096` inline the body directly per the contract. As a sequential caller this skill omits `verify: hash`, so `contentHash` is informational — mark it deferred and compute it in the post-return batch:

```
@handoff-in
kind: handoff
path: .dt-handoff/<slug>/artifacts/ask/analyst-<ISO8601>.md
contentHash: sha256:deferred
sizeBytes: <bytes>
note: Delta only (latest Q&A + current score table). Return 0.0–1.0 clarity per dimension (Goal/Constraints/Criteria/Context) for each active component; flag hidden constraints and speculative assumptions.
```

**Batched bookkeeping.** After `analyst` returns, run ONE Bash call that computes the artifact's `sha256` and appends BOTH events to `.dt-handoff/<slug>/events.jsonl` (no separate Bash calls for the hash or each event):
```json
{"ts":"<dispatch-ISO8601>","producer":"deep-interview","consumer":"analyst","event":"dispatch","kind":"handoff","path":".dt-handoff/<slug>/artifacts/ask/analyst-<ISO8601>.md","status":"pending","verdict":null}
{"ts":"<return-ISO8601>","producer":"analyst","consumer":"deep-interview","event":"return","kind":"advisor","path":".dt-handoff/<slug>/artifacts/ask/analyst-<ISO8601>.md","status":"complete","verdict":null}
```

Consume the `@handoff-out` from `analyst`: read the per-dimension **clarity scores** (0.0–1.0, higher = clearer — the same scale as your inline scores; feed them into the Step 3e formula directly, no conversion), the hidden-constraint/assumption list, and the gap list. Use these to update the score table and the weakest-dimension gap shown in Step 3e.

**Mark blocking vs non-blocking.** Whether you scored inline or via `analyst`, tag each unresolved dimension's gap as *blocking* (an unknown that would change the spec or send execution the wrong way — the criterion in `Execution_Policy`) or *non-blocking* (detail that can be safely defaulted or deferred). The count of blocking gaps is the `{k}` reported in Step 3e, and the gate fires only when `{k}` reaches 0 — a merely-low non-blocking score never justifies another round.

**Step 3d — Extract ontology.** Identify key entities (nouns) discussed. For each: name, type (core / supporting / external), fields, relationships. For rounds 2+, compare with the previous round:
- `stable` = same name in both rounds
- `changed` = renamed (same type + >50% field overlap)
- `new` / `removed` accordingly
- `stability_ratio = (stable + changed) / total`

Round 1 has no comparison; set stability_ratio = N/A.

**Step 3e — Report progress** to the user in **exactly three lines**. Drop the weighted-score table — the per-dimension weight/weighted columns are noise during a live interview; the user only needs to know how close we are and where we're headed next. Keep the dimension scores internal (they still drive the gate); surface only the gap.

```
✓ Round {n} 완료 · 모호도 {score}% ({prev_score}→{score}) · 남은 blocking gap {k}개
가장 약한 고리: {weakest_dimension} — {blocking gap, or "blocking 없음"}
다음: {next_focus}
```

When **no blocking gap remains** (usually also `score ≤ threshold`), replace the third line with `남은 blocking gap 없음 — spec으로 정리합니다.` instead of a next target. Do not keep asking just to push a non-blocking score from e.g. 0.25→0.20.

Do NOT print the full clarity table, topology counts, or ontology row each round. The complete per-dimension breakdown is recorded once in the final spec, not repeated every turn. (When > 1 active component is in play, name which component you targeted in the first line, e.g. `✓ Round {n} 완료 · {target_component} · 모호도 {score}%`.)

Ambiguity formula (inline scores and `analyst`-returned clarity scores share the same 0.0–1.0 higher-is-clearer scale — apply directly, no conversion):
- Greenfield: `ambiguity = 1 − (goal × 0.40 + constraints × 0.30 + criteria × 0.30)`
- Brownfield: `ambiguity = 1 − (goal × 0.35 + constraints × 0.25 + criteria × 0.25 + context × 0.15)`

When multiple active components exist, use the **minimum** per-dimension score across components for the displayed score (so one well-understood component cannot mask a fuzzy sibling). This multi-component arithmetic is always performed inline — it is never a reason to dispatch `analyst`. For the *gate*, what matters is whether any component still has a *blocking* gap — target those; do not let a merely-low (non-blocking) score on one sibling spin extra rounds.

**Step 3f — Check soft limits.**
- Any round: allow early exit if user says "enough" / "충분해" / "let's go" — proceed to Phase 5 with a transparent warning.
- Round 10: emit soft warning: "10 rounds reached. Current ambiguity: {score}%. Continue or proceed?"
- Round `--max-rounds` (default 20): hard cap. Proceed to Phase 5 noting the residual ambiguity.

### Phase 4: Challenge Modes via `critic`

Challenge modes are **opt-in**, not automatic. When the interview reaches the relevant round AND a real gap remains, inject an adversarial perspective into the next question. Each mode runs at most once; a short interview that hits the threshold before R4 uses none. Whatever the execution path, preserve the point of a challenge — striking the user's habitual framing — never soften it into a summary.

- **Round 4+ — Contrarian Mode.** Default: dispatch `critic` with `note: mode=challenge-single` (fast-path — returns exactly one most-fragile assumption + one question seed). Prompt focus: "Acting as Contrarian, challenge the user's core assumption in the spec draft. Identify the single assumption most likely to be wrong. The skill will ask the user 'What if the opposite were true?' / 'What if this constraint doesn't actually exist?'"
- **Round 6+ — Simplifier Mode.** Same fast-path (`note: mode=challenge-single`). Prompt focus: "Acting as Simplifier, identify the most removable complexity. The skill will ask the user 'What's the simplest version that would still be valuable?' / 'Which constraints are necessary vs. assumed?'"
- **Round 8+ (only if ambiguity > 0.3) — Ontologist Mode.** ALWAYS dispatch `critic` in full mode (no `challenge-single`, never inline) — ontological reframing needs a perspective from outside the interview context. Prompt: "Acting as Ontologist, examine the tracked entities and reframe the core question. The skill will ask the user 'What IS this, really?' / 'Which entity is core vs. supporting?'"

**Inline alternative (Contrarian/Simplifier only).** For a light interview (single active component, small draft), you MAY run Contrarian or Simplifier inline in the main session instead of dispatching — but only if you produce the same artifact: one named fragile assumption (or one named removable complexity) turned into the next question. Never skip or dilute the challenge because it runs inline. Inline-run challenges dispatch nothing and log nothing.

When dispatching `critic`, write the current spec draft to `.dt-handoff/<slug>/artifacts/ask/critic-<ISO8601>.md` and pass it via `@handoff-in` (with the mode note above; `contentHash` deferred as in Step 3c). Bookkeeping is batched exactly as in Step 3c — after `critic` returns, ONE Bash call computes the artifact's `sha256` and appends both events to `.dt-handoff/<slug>/events.jsonl`:
```json
{"ts":"<dispatch-ISO8601>","producer":"deep-interview","consumer":"critic","event":"dispatch","kind":"handoff","path":".dt-handoff/<slug>/artifacts/ask/critic-<ISO8601>.md","status":"pending","verdict":null}
{"ts":"<return-ISO8601>","producer":"critic","consumer":"deep-interview","event":"return","kind":"advisor","path":".dt-handoff/<slug>/artifacts/ask/critic-<ISO8601>.md","status":"complete","verdict":"<verdict or null>"}
```
(`challenge-single` returns are advisory with no `verdict` — log `null`; full-mode Ontologist returns may carry one.)

After receiving `critic`'s `@handoff-out` (or completing the inline challenge), incorporate the finding into the next interview question. Then return to normal Socratic questioning.

### Phase 5: Crystallize Spec

When no blocking gap remains (ambiguity ≤ threshold) OR hard cap reached OR early exit chosen:

1. **Analyst checkpoint (b) — gate verification** (normal completion only; skipped on EARLY_EXIT / HARD_CAP, where the user has already accepted residual ambiguity). Dispatch `analyst` once with the delta payload (final score table + the last Q&A) to verify no blocking gap was missed and no speculative assumption is left unflagged. If it surfaces a new blocking gap, return to the Phase 3 loop for that gap; otherwise proceed. Batched bookkeeping per Step 3c.
2. **Slugify** the title for the filename.
3. **Create** `.dt-handoff/<slug>/` if missing.
4. **Write** the spec to `.dt-handoff/<slug>/spec.md`. The file MUST open with the hand-off descriptor frontmatter described below before the `# Deep Interview Spec:` heading.
5. **Show** the user the absolute path of the written file.
6. **Log** the final event to `.dt-handoff/<slug>/events.jsonl`:
   ```json
   {"ts":"<ISO8601>","producer":"deep-interview","consumer":null,"event":"complete","kind":"spec","path":".dt-handoff/<slug>/spec.md","status":"<PASSED|EARLY_EXIT|HARD_CAP>","verdict":null}
   ```

**Hand-off descriptor frontmatter** (machine-truth schema in `scripts/validate.sh`; see `DESC_REQUIRED_FIELDS` and enum vars in that file):

```yaml
---
kind: spec
path: .dt-handoff/<slug>/spec.md
contentHash: sha256:<hash of body below>
createdAt: <ISO8601-now>
producer: deep-interview
sizeBytes: <byte count of body below>
retention: permanent
expiresAt: null
status: PASSED        # or EARLY_EXIT | HARD_CAP
---
```

Spec structure (headers stay English; content in `$LANGUAGE`):

```markdown
# Deep Interview Spec: <title>

## Metadata
- Generated: <YYYY-MM-DD>
- Rounds: <count>
- Final Ambiguity: <score>%
- Threshold: <threshold>
- Type: greenfield | brownfield
- Status: PASSED | EARLY_EXIT | HARD_CAP

## Clarity Breakdown
| Dimension            | Gap (or "Clear") |
|----------------------|------------------|
| Goal                 | …                |
| Constraints          | …                |
| Success Criteria     | …                |
| Context (brownfield) | …                |
| **Ambiguity**        | **…%**           |

## Topology
| Component | Status   | Description | Coverage / Deferral Note |
|-----------|----------|-------------|--------------------------|
| …         | active   | …           | …                        |
| …         | deferred | …           | <user-confirmed reason>  |

## Goal
<one-sentence success statement covering every active component>

## Constraints
- …

## Non-Goals
- …

## Acceptance Criteria
- [ ] …

## Technical Direction
- …

## Context (brownfield)
- <relevant codebase findings from explorer>

## Tradeoffs
| Choice | Pros | Cons |
|--------|------|------|
| …      | …    | …    |

## Assumptions Exposed & Resolved
| Assumption | Challenge | Resolution |
|------------|-----------|------------|
| …          | …         | …          |

## Ontology (Key Entities)
| Entity | Type | Fields | Relationships |
|--------|------|--------|---------------|
| …      | …    | …      | …             |

## Ontology Convergence
| Round | Entity Count | New | Changed | Stable | Stability |
|-------|--------------|-----|---------|--------|-----------|
| 1     | …            | …   | -       | -      | N/A       |
| …     | …            | …   | …       | …      | …         |

## Open Questions
- …

## Interview Transcript
<details>
<summary>Full Q&A (<n> rounds)</summary>

### Round 1 (draft presented & corrected)
**Draft:** <one-line summary of the strawman shown>
**Corrections:** <user's deltas, or "대체로 맞음">
**Ambiguity:** …% (Goal: …, Constraints: …, Criteria: …)

### Round 2
**Q:** …
**A:** …
**Ambiguity:** …%
…
</details>
```
</Steps>

<Tool_Usage>
- `AskUserQuestion` for every interview question — one per turn, with contextual options + free-text.
- `Glob`/`ls` (one pass) for inline brownfield/greenfield detection — never dispatch an agent just to detect.
- `Task(subagent_type="explorer", prompt="…")` at most **once**, for brownfield mapping only (run BEFORE asking the user about codebase facts). Greenfield interviews dispatch no explorer. Explorer findings are returned inline (no disk artifact); log both events in the post-return batch.
- `Task(subagent_type="analyst", prompt="…")` at **checkpoints only** — (a) post-draft, (b) pre-crystallize, (c) scope shift/contradiction. Every ordinary round is scored inline (no dispatch, no log). When dispatched: pass a `@handoff-in` block carrying the **delta** (latest Q&A + current score table, never the full transcript); when `sizeBytes ≤ 4096` inline the body directly; `contentHash` is deferred to the post-return batch (sequential caller — no `verify: hash`). Analyst returns 0.0–1.0 clarity per dimension — same scale as inline scoring, no conversion.
- `Task(subagent_type="critic", prompt="…")` **only when a real gap remains** at Round 4 (Contrarian), Round 6 (Simplifier), or Round 8+ (Ontologist, if ambiguity > 0.3), plus the stall rule in `Advanced`. Contrarian/Simplifier use `note: mode=challenge-single` (or run inline for light interviews); Ontologist and stall reframing always dispatch in full mode. Skip entirely if the threshold is met early. Pass a `@handoff-in` block referencing the current spec draft. Consume the `@handoff-out` (`challenge-single` returns are advisory with no `verdict`; full mode may carry one).
- `Bash` only to: create the slug directory if missing (`mkdir -p .dt-handoff/<slug>/artifacts/ask/`), and — ONE batched call per agent dispatch, run after the agent returns — compute the artifact's `sha256` (when an artifact exists) and append both the dispatch and return events to `events.jsonl`. Never issue separate Bash calls for the hash and each event. Example batch:

```bash
HASH=$(shasum -a 256 "$ARTIFACT" | cut -d' ' -f1) && cat >> .dt-handoff/<slug>/events.jsonl <<EOF
{"ts":"<dispatch-ISO8601>","producer":"deep-interview","consumer":"analyst","event":"dispatch",…}
{"ts":"<return-ISO8601>","producer":"analyst","consumer":"deep-interview","event":"return",…}
EOF
```
- `Write` to save the final spec to `.dt-handoff/<slug>/spec.md` and intermediate analyst input artifacts to `.dt-handoff/<slug>/artifacts/ask/`.
- Do NOT delegate execution from this skill. Producing the spec is the terminal step.

**events.jsonl format** (append-only; one JSON object per line):
```jsonl
{"ts":"<ISO8601>","producer":"<sender>","consumer":"<receiver>","event":"dispatch|return|complete","kind":"<kind>","path":"<path or null>","status":"<status>","verdict":"<verdict or null>"}
```
</Tool_Usage>

<Examples>
**Example 1 — fresh greenfield idea:**
User: "스펙 잡아줘 — Linear webhook 처리 서비스"
Flow: Phase 0 emits threshold marker → restate idea → inline `Glob` detection finds no source (greenfield, zero explorer dispatches) → Round 0 topology (Ingestion / Routing / Persistence / Replay confirmed, N=4) → Round 1 draft corrected → `analyst` checkpoint (a) with delta payload (one batched Bash call logs dispatch+return) → 7–10 Korean questions rotating across components, every answer scored inline → Contrarian @ R4 dispatches `critic` with `mode=challenge-single` (batched bookkeeping) → Simplifier @ R6 → ambiguity drops to 18% → `analyst` checkpoint (b) verifies the gate → write `.dt-handoff/linear-webhook/spec.md` → complete event logged → show path.

**Example 2 — brownfield with explorer:**
User: "/deep-interview '인증 미들웨어 리팩터'"
Flow: inline `Glob` detection sees `package.json` + `src/` (brownfield) → single `explorer` dispatch maps the area, finds `src/auth/passport-jwt.ts` (pattern: passport + JWT); both events logged in one batched call → Round 0 topology confirms 2 components (Token issuance / Verification middleware) → Round 1 draft corrected → `analyst` checkpoint (a) → questions cite the discovered file: "I found JWT middleware in `src/auth/passport-jwt.ts`. Should the refactor extend this path or intentionally diverge from it?" → answers scored inline (both components, minimum per-dimension, rotation — all inline) → threshold reached → `analyst` checkpoint (b) → write spec at `.dt-handoff/auth-middleware/spec.md`.

**Example 3 — `--lang=en` with threshold override:**
User: "/deep-interview 'CLI habit tracker' --lang=en --threshold=0.15"
Flow: Phase 0 emits `Deep Interview threshold: 15% (max rounds: 20)` → interview in English → Round 0 enumeration yields N=1 (auto-lock, no topology question; the Round 1 draft opens with the topology statement) → rounds scored inline with `analyst` only at checkpoints (a) and (b) → spec in English at `.dt-handoff/cli-habit-tracker/spec.md`.

**Example 4 — bare invocation:**
User: "/deep-interview"
Flow: AskUserQuestion "오늘 어떤 걸 스펙으로 잡을까요?" → user answers → continue from Phase 1 Step 1.

**Example 5 — early exit with warning (any round):**
User (after round 2, ambiguity 35%): "충분해, 그대로 가자"
Flow: System warns "Current ambiguity 35%, threshold 20%. Remaining gaps: Success Criteria (clarity 0.5 — no measurable signal), Constraints (clarity 0.4 — no deadline)." → AskUserQuestion: [Yes, proceed] / [Ask 2 more questions] / [Cancel] → on "Yes, proceed" → skip `analyst` checkpoint (b) (early exit accepts residual ambiguity) → write spec with `Status: EARLY_EXIT` at `.dt-handoff/<slug>/spec.md`.

**Example 6 — @handoff-in / @handoff-out exchange with analyst (checkpoint (c)):**
The Round 3 answer introduces a new integration surface — a scope shift, so checkpoint (c) fires. The skill writes the **delta** (the Round 3 Q&A + current score table, 800 bytes) to `.dt-handoff/my-feature/artifacts/ask/analyst-2026-06-10T10:00:00Z.md` and dispatches (body inlined since ≤ 4096 bytes; hash deferred):
```
@handoff-in
kind: handoff
path: .dt-handoff/my-feature/artifacts/ask/analyst-2026-06-10T10:00:00Z.md
contentHash: sha256:deferred
sizeBytes: 800
note: Delta only (Round 3 Q&A + current score table). New scope introduced — return 0.0–1.0 clarity per dimension for components A and B; flag hidden constraints.
```
`analyst` returns:
```
@handoff-out
kind: advisor
path: .dt-handoff/my-feature/artifacts/ask/analyst-2026-06-10T10:00:00Z.md
status: complete
contentHash: sha256:def…
sizeBytes: 1820
summary: clarity G 0.7 / C 0.4 / Cr 0.6 / Cx 0.8; 2 hidden constraints, 1 blocking gap (Constraints)
```
The clarity scores are already on the 0.0–1.0 inline scale — the skill feeds them straight into the Step 3e formula (`ambiguity = 1 − weighted clarity`, no conversion), then runs ONE Bash call that computes the artifact's `sha256` and appends both the dispatch and return events to `events.jsonl`, and reports the three-line progress (Step 3e) — surfacing the remaining blocking gap, not a full table.
</Examples>

<Final_Checklist>
- Did Phase 0 emit the threshold marker as the first user-visible line?
- Did I restate the seed idea in one sentence before interviewing?
- Did I present a best-guess draft (Round 1) and let the user correct deltas, instead of interrogating every dimension from scratch?
- Did I detect brownfield/greenfield inline (one `Glob`/`ls` pass) and dispatch `explorer` at most once, for brownfield mapping only, before asking the user about codebase facts?
- Did I offer the `/interview` downshift when the topic resolved to a single component with clear scope (and no depth marker)?
- Did I batch each dispatch's bookkeeping — `sha256` + both events — into ONE post-return Bash call?
- Did Round 0 lock the topology before any ambiguity scoring — auto-locking on N = 1 (topology folded into the Round 1 draft) and asking the confirmation question only for N ≥ 2?
- Did I ask exactly ONE question per turn in `$LANGUAGE`?
- Did I emit the metadata as a single context line BEFORE the `AskUserQuestion` call, keeping the `question` field to the question alone (no pipe-packed header)?
- Did I score every round inline (including multi-component minimums and rotation) and dispatch `analyst` only at checkpoints — (a) post-draft, (b) pre-crystallize, (c) scope shift — with delta payloads, logging events only when actually dispatched?
- Did I gate on remaining *blocking* gaps (not on shaving a non-blocking score toward threshold)?
- Did I honor early exit at any round — transparent warning, one confirmation question, `Status: EARLY_EXIT`?
- Did I keep each round's progress report to the three-line format (no weighted table, no topology/ontology rows)?
- For N > 1 active components, did I rotate targeting instead of drilling one component?
- Did I dispatch `critic` only when a real gap remained (Contrarian @ R4, Simplifier @ R6, Ontologist @ R8 if ambiguity > 0.3) — at most once each, skipping when the threshold was met early — using `mode=challenge-single` for Contrarian/Simplifier (or a faithful inline challenge) and full mode for Ontologist?
- Did I log every critic dispatch/return (and consume its `@handoff-out`) to `events.jsonl` when used?
- Did the final spec cover Topology / Goal / Constraints / Non-Goals / Acceptance Criteria / Technical Direction / Tradeoffs / Open Questions / Ontology / Transcript?
- Did I write the spec to `.dt-handoff/<slug>/spec.md` with the descriptor frontmatter (schema ref: `scripts/validate.sh`)?
- Did I append the `complete` event to `events.jsonl` after writing the spec?
- Did I show the absolute path of the written spec to the user?
- Did I avoid implementing code (this skill is requirements-only)?
</Final_Checklist>

<Advanced>
## Ambiguity Score Interpretation

| Score Range | Meaning | Action |
|-------------|---------|--------|
| 0.0 – 0.1   | Crystal clear | Proceed immediately |
| ≤ threshold (default 0.2) | Clear enough | Crystallize spec |
| 0.2 – 0.4   | Significant gaps | Focus on weakest dimension |
| 0.4 – 0.6   | Very unclear | Consider reframing (Ontologist) |
| > 0.6       | Almost nothing known | Early rounds, keep going |

> **Gate note:** the actual stop condition is *no blocking gap remains*, not the score crossing a line. A score slightly above threshold still crystallizes if nothing blocking is left (see `Execution_Policy`); these ranges are guidance for where to focus, not a hard cutoff.

## Brownfield vs Greenfield Weights

| Dimension          | Greenfield | Brownfield |
|--------------------|-----------|------------|
| Goal Clarity       | 40%       | 35%        |
| Constraint Clarity | 30%       | 25%        |
| Success Criteria   | 30%       | 25%        |
| Context Clarity    | N/A       | 15%        |

Brownfield adds Context Clarity because modifying existing code safely requires understanding the system being changed.

## Challenge Modes (via `critic` agent)

| Mode | Activates | Purpose | `critic` prompt focus |
|------|-----------|---------|----------------------|
| Contrarian | Round 4+ | Challenge assumptions | "What if the opposite were true?" |
| Simplifier | Round 6+ | Remove complexity | "What's the simplest version?" |
| Ontologist | Round 8+ (if ambiguity > 0.3) | Find essence | "What IS this, really?" |

Each mode runs at most once. Contrarian and Simplifier dispatch `critic` with the `note: mode=challenge-single` fast-path (one most-fragile assumption + one question seed) — or run inline in the main session for light interviews, producing the same artifact; Ontologist (and stall reframing) always dispatches `critic` in full mode. The skill receives `critic`'s `@handoff-out` (or the inline result) and translates the finding into the next AskUserQuestion.

## Escalation & Stop Conditions

- Hard cap at 20 rounds (configurable via `--max-rounds`): proceed with current clarity, mark `Status: HARD_CAP`.
- Soft warning at 10 rounds: offer to continue or proceed.
- Early exit (any round): allow with transparent warning if ambiguity > threshold; mark `Status: EARLY_EXIT`.
- User says "stop" / "cancel" / "abort": stop immediately; do not write a spec.
- Ambiguity stalls (same score ±0.05 for 3 rounds): activate Ontologist mode (dispatch `critic` with the Ontologist prompt, full mode — not `challenge-single`) to reframe, even if before round 8.
- All dimensions at 0.9+: skip to spec generation even if not at round minimum.
- `explorer` mapping fails: proceed without `codebase_context`, note the limitation in the spec.
- `analyst` checkpoint dispatch fails: continue with the inline scores (inline scoring is already the per-round default); note the skipped checkpoint in the spec metadata.
</Advanced>
