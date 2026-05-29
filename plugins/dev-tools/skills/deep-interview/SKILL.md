---
name: deep-interview
description: >
  Socratic deep interview with mathematical ambiguity gating and challenge
  agents. Surfaces hidden assumptions, scores clarity per dimension
  (Goal/Constraints/Criteria/Context), and refuses to hand off until ambiguity
  drops below the configured threshold. Produces a structured spec at
  `.dt-handoff/<slug>/spec.md` in `$LANGUAGE`. Delegates deep requirements /
  hidden-constraint / ambiguity analysis to `analyst`; brownfield mapping to
  `explorer`; challenge modes (Contrarian/Simplifier/Ontologist) to `critic`.
  TRIGGER when: user wants thorough requirements gathering before any coding,
  says "스펙 잡아줘", "deep interview", "심층 인터뷰", "ouroboros",
  "socratic", "interview me", "ask me everything", "don't assume", or invokes
  `/deep-interview`.
  DO NOT TRIGGER when: user already has a detailed spec (use a review skill),
  is asking conceptually what an interview is, wants a single small change with
  obvious scope, says "just do it / skip the questions", or already has a PRD
  and wants execution.
argument-hint: "[brief idea] [--lang=<value>] [--threshold=<0.0-1.0>] [--max-rounds=<n>]"
---

<Purpose>
Interview the user in `$LANGUAGE` to capture requirements for a new project, feature, or change using Socratic questioning with mathematical ambiguity scoring. Ask one question at a time, target the weakest clarity dimension each round, delegate deep requirements / hidden-constraint / ambiguity analysis to the `analyst` agent, activate challenge perspective via the `critic` agent (Contrarian/Simplifier/Ontologist modes) at preset thresholds, and refuse to finalize the spec until ambiguity ≤ threshold (default 0.2) OR the user explicitly opts out with a warning. Output is a structured spec document at `.dt-handoff/<slug>/spec.md`. This skill does NOT implement code — it produces the spec only.
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
- Each round names the **target component**, **weakest dimension**, **why now**, and the **current ambiguity score** — as a single context line emitted *before* the `AskUserQuestion` call, NOT crammed into the question text.
- Cover the rubric: Goal / Constraints / Acceptance Criteria / Technical Direction / Context (brownfield) / Open Questions / Out of Scope.
- Run the bundled `explorer` agent for brownfield codebase facts **before** asking the user about them. Cite the discovered file/path/pattern in any confirmation question.
- Keep the interview lightweight by default. Score ambiguity **inline** (using the Step 3e formula) for simple topics. Dispatch the `analyst` agent for the heavy analytical pass **only when** ambiguity > 0.4 OR there are ≥ 2 active components — i.e. when scoring is genuinely hard. Note inline-mode scoring in the spec metadata.
- Round 0 topology gate runs **once** before ambiguity scoring; lock the top-level component list before any depth-first questioning.
- Score clarity after every answer; show the score transparently.
- When the locked topology has multiple active components, score each one and rotate question targeting across them.
- Challenge modes are opt-in pressure, not mandatory ceremony: dispatch `critic` only when the interview reaches the relevant round AND a real assumption/complexity/ontology gap remains (Contrarian @ R4, Simplifier @ R6, Ontologist @ R8 when ambiguity > 0.3). Short interviews that hit the threshold early skip them entirely. Each mode is used at most once.
- Allow early exit at round 3+ with a transparent warning showing remaining gaps.
- Soft warning at round 10; hard cap at round 20.
- Do not implement code in this skill — produce the spec only.
- Write the final spec to `.dt-handoff/<slug>/spec.md` (create `.dt-handoff/<slug>/` if missing).
- Append a control-plane event to `.dt-handoff/<slug>/events.jsonl` on each agent dispatch and return.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: the language setting from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`. Presets: Korean, English, Japanese, Chinese. Custom values accepted as free text.
- `--threshold=<0.0-1.0>`: ambiguity threshold for the gate. Default `0.2` (20%). The interview proceeds to spec crystallization once ambiguity ≤ threshold.
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
2. **Detect brownfield vs greenfield.**
   - Run the `explorer` agent to check whether the cwd has existing source code, package files, or git history relevant to the idea.
   - Log the dispatch event to `.dt-handoff/<slug>/events.jsonl`:
     ```json
     {"ts":"<ISO8601>","producer":"deep-interview","consumer":"explorer","event":"dispatch","kind":"handoff","path":null,"status":"pending","verdict":null}
     ```
   - If source files exist AND the idea references modifying/extending something → **brownfield**.
   - Otherwise → **greenfield**.
   - Log the return event:
     ```json
     {"ts":"<ISO8601>","producer":"explorer","consumer":"deep-interview","event":"return","kind":"advisor","path":null,"status":"complete","verdict":null}
     ```
3. **For brownfield**: ask `explorer` to map relevant codebase areas (modules, key files, patterns). Store as `codebase_context`. Use it to avoid re-asking facts the code already reveals.
4. **Announce the interview** in `$LANGUAGE`:

```
시작합니다. 한 번에 하나씩 질문하면서 모호함이 <threshold_percent>% 이하로 떨어질 때까지 진행합니다.

Idea: "<restated idea>"
Project type: greenfield | brownfield
Current ambiguity: 100% (not scored yet)
```

### Phase 2: Round 0 — Topology Enumeration Gate

Run this gate exactly once before any ambiguity scoring.

1. **Enumerate candidate top-level components** from the idea (+ brownfield context):
   - Extract top-level verbs/nouns, workstreams, surfaces, integrations, or deliverables that can succeed or fail independently.
   - Prefer 1–6 components. Group siblings if more.
   - Do not treat fields or sub-features as top-level components unless framed as independent outcomes.
2. **Ask one confirmation question** via `AskUserQuestion`:

```
Round 0 | Topology confirmation | Ambiguity: not scored yet

I'm reading this as N top-level component(s):
1. <component_name>: <one-sentence description>
2. ...

Is that topology right? Should any component be added, removed, merged, split, or explicitly deferred?
```

Options should include **Looks right**, **Add/remove/merge**, **Defer one or more**, plus free-text.

3. **Lock topology** for the rest of the interview. Record per-component status (`active` | `deferred`), description, and (later) per-dimension clarity scores. Deferred components are excluded from ambiguity math but remain in the final spec.

### Phase 3: Interview Loop

Repeat until `ambiguity ≤ threshold` OR user exits early OR hard cap reached.

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

**Step 3c — Score the answer (inline by default; `analyst` when hard).** After the user's answer, decide how to score:

- **Inline (default):** for simple topics — ambiguity ≤ 0.4 AND a single active component — score the dimensions yourself using the Step 3e formula. No agent dispatch, no `events.jsonl` entry. This keeps short interviews fast.
- **Dispatch `analyst`:** only when ambiguity > 0.4 OR there are ≥ 2 active components (scoring is genuinely hard / needs hidden-constraint extraction).

When dispatching, write the current idea summary + accumulated answers to `.dt-handoff/<slug>/artifacts/ask/analyst-<ISO8601>.md`, then dispatch `analyst` with an `@handoff-in` block:

```
@handoff-in
kind: handoff
path: .dt-handoff/<slug>/artifacts/ask/analyst-<ISO8601>.md
contentHash: sha256:<hash>
sizeBytes: <bytes>
note: Score ambiguity dimensions for each active component based on the latest answer. Flag any hidden constraints or speculative assumptions.
```

Log the dispatch and return events to `.dt-handoff/<slug>/events.jsonl` (only when `analyst` was actually dispatched — inline-scored rounds log nothing):
```json
{"ts":"<ISO8601>","producer":"deep-interview","consumer":"analyst","event":"dispatch","kind":"handoff","path":".dt-handoff/<slug>/artifacts/ask/analyst-<ISO8601>.md","status":"pending","verdict":null}
```
```json
{"ts":"<ISO8601>","producer":"analyst","consumer":"deep-interview","event":"return","kind":"advisor","path":".dt-handoff/<slug>/artifacts/ask/analyst-<ISO8601>.md","status":"complete","verdict":null}
```

Consume the `@handoff-out` from `analyst`: read the per-dimension ambiguity scores (Goal / Constraints / Criteria / Context), the assumption list, and the gap list. Use these to compute the ambiguity score and the weakest-dimension gap shown in Step 3e.

**Step 3d — Extract ontology.** Identify key entities (nouns) discussed. For each: name, type (core / supporting / external), fields, relationships. For rounds 2+, compare with the previous round:
- `stable` = same name in both rounds
- `changed` = renamed (same type + >50% field overlap)
- `new` / `removed` accordingly
- `stability_ratio = (stable + changed) / total`

Round 1 has no comparison; set stability_ratio = N/A.

**Step 3e — Report progress** to the user in **exactly three lines**. Drop the weighted-score table — the per-dimension weight/weighted columns are noise during a live interview; the user only needs to know how close we are and where we're headed next. Keep the dimension scores internal (they still drive the gate); surface only the gap.

```
✓ Round {n} 완료 · 모호도 {score}% ({prev_score}→{score})
가장 약한 고리: {weakest_dimension} — {gap}
다음: {next_focus}
```

When `score ≤ threshold`, replace the third line with `임계치 도달 — spec으로 정리합니다.` instead of a next target.

Do NOT print the full clarity table, topology counts, or ontology row each round. The complete per-dimension breakdown is recorded once in the final spec, not repeated every turn. (When > 1 active component is in play, name which component you targeted in the first line, e.g. `✓ Round {n} 완료 · {target_component} · 모호도 {score}%`.)

Ambiguity formula (applied to inline scores, or to `analyst`-returned scores when dispatched):
- Greenfield: `ambiguity = 1 − (goal × 0.40 + constraints × 0.30 + criteria × 0.30)`
- Brownfield: `ambiguity = 1 − (goal × 0.35 + constraints × 0.25 + criteria × 0.25 + context × 0.15)`

When multiple active components exist, use the **minimum** per-dimension score across components (so one well-understood component cannot mask a fuzzy sibling).

**Step 3f — Check soft limits.**
- Round 3+: allow early exit if user says "enough" / "충분해" / "let's go" — proceed to Phase 5 with a transparent warning.
- Round 10: emit soft warning: "10 rounds reached. Current ambiguity: {score}%. Continue or proceed?"
- Round `--max-rounds` (default 20): hard cap. Proceed to Phase 5 noting the residual ambiguity.

### Phase 4: Challenge Modes via `critic`

Challenge modes are **opt-in**, not automatic. When the interview reaches the relevant round AND a real gap remains, dispatch `critic` with a focused mode prompt to inject an adversarial perspective into the next question. Each mode is dispatched at most once; a short interview that hits the threshold before R4 uses none. Write the current spec draft to `.dt-handoff/<slug>/artifacts/ask/critic-<ISO8601>.md` and pass it via `@handoff-in`.

Log each critic dispatch and return to `.dt-handoff/<slug>/events.jsonl`:
```json
{"ts":"<ISO8601>","producer":"deep-interview","consumer":"critic","event":"dispatch","kind":"handoff","path":".dt-handoff/<slug>/artifacts/ask/critic-<ISO8601>.md","status":"pending","verdict":null}
```
```json
{"ts":"<ISO8601>","producer":"critic","consumer":"deep-interview","event":"return","kind":"advisor","path":".dt-handoff/<slug>/artifacts/ask/critic-<ISO8601>.md","status":"complete","verdict":"<verdict>"}
```

- **Round 4+ — Contrarian Mode.** Prompt `critic`: "Acting as Contrarian, challenge the user's core assumption in the spec draft. Identify the single assumption most likely to be wrong. The skill will ask the user 'What if the opposite were true?' / 'What if this constraint doesn't actually exist?'"
- **Round 6+ — Simplifier Mode.** Prompt `critic`: "Acting as Simplifier, identify the most removable complexity. The skill will ask the user 'What's the simplest version that would still be valuable?' / 'Which constraints are necessary vs. assumed?'"
- **Round 8+ (only if ambiguity > 0.3) — Ontologist Mode.** Prompt `critic`: "Acting as Ontologist, examine the tracked entities and reframe the core question. The skill will ask the user 'What IS this, really?' / 'Which entity is core vs. supporting?'"

After receiving `critic`'s `@handoff-out`, incorporate its findings into the next interview question. Then return to normal Socratic questioning.

### Phase 5: Crystallize Spec

When ambiguity ≤ threshold OR hard cap reached OR early exit chosen:

1. **Slugify** the title for the filename.
2. **Create** `.dt-handoff/<slug>/` if missing.
3. **Write** the spec to `.dt-handoff/<slug>/spec.md`. The file MUST open with the hand-off descriptor frontmatter described below before the `# Deep Interview Spec:` heading.
4. **Show** the user the absolute path of the written file.
5. **Log** the final event to `.dt-handoff/<slug>/events.jsonl`:
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

### Round 1
**Q:** …
**A:** …
**Ambiguity:** …% (Goal: …, Constraints: …, Criteria: …)

### Round 2
…
</details>
```
</Steps>

<Tool_Usage>
- `AskUserQuestion` for every interview question — one per turn, with contextual options + free-text.
- `Task(subagent_type="explorer", prompt="…")` for brownfield codebase exploration (run BEFORE asking the user about codebase facts). Explorer findings are returned inline (no disk artifact); log dispatch/return events.
- `Task(subagent_type="analyst", prompt="…")` **conditionally** — only when ambiguity > 0.4 OR ≥ 2 active components. Otherwise score inline (no dispatch). When dispatched: pass a `@handoff-in` block referencing the accumulated answers artifact; when `sizeBytes ≤ 4096` inline the body directly; log dispatch/return events. Inline-scored rounds log nothing.
- `Task(subagent_type="critic", prompt="…")` **only when a real gap remains** at Round 4 (Contrarian), Round 6 (Simplifier), or Round 8+ (Ontologist, if ambiguity > 0.3). Skip entirely if the threshold is met early. Pass a `@handoff-in` block referencing the current spec draft. Consume `@handoff-out` verdict. Log dispatch/return events.
- `Bash` only to: create the slug directory if missing (`mkdir -p .dt-handoff/<slug>/artifacts/ask/ .dt-handoff/<slug>/`), compute `sha256` hashes, and append events to `events.jsonl`.
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
Flow: Phase 0 emits threshold marker → restate idea → `explorer` dispatch/return logged → Round 0 topology (Ingestion / Routing / Persistence / Replay confirmed) → 7–10 Korean questions rotating across components → each answer dispatches `analyst` (dispatch/return logged) for scoring → Contrarian @ R4 dispatches `critic` (dispatch/return logged) → Simplifier @ R6 → ambiguity drops to 18% → write `.dt-handoff/linear-webhook/spec.md` → complete event logged → show path.

**Example 2 — brownfield with explorer:**
User: "/deep-interview '인증 미들웨어 리팩터'"
Flow: `explorer` finds `src/auth/passport-jwt.ts` (pattern: passport + JWT), logs return event → Round 0 topology confirms 2 components (Token issuance / Verification middleware) → Question cites the discovered file: "I found JWT middleware in `src/auth/passport-jwt.ts`. Should the refactor extend this path or intentionally diverge from it?" → each answer triggers `analyst` dispatch → continue until threshold → write spec at `.dt-handoff/auth-middleware/spec.md`.

**Example 3 — `--lang=en` with threshold override:**
User: "/deep-interview 'CLI habit tracker' --lang=en --threshold=0.15"
Flow: Phase 0 emits `Deep Interview threshold: 15% (max rounds: 20)` → interview in English → `analyst` dispatched per round → spec in English at `.dt-handoff/cli-habit-tracker/spec.md`.

**Example 4 — bare invocation:**
User: "/deep-interview"
Flow: AskUserQuestion "오늘 어떤 걸 스펙으로 잡을까요?" → user answers → continue from Phase 1 Step 1.

**Example 5 — early exit with warning:**
User (after round 5, ambiguity 35%): "충분해, 그대로 가자"
Flow: System warns "Current ambiguity 35%, threshold 20%. Remaining gaps: Success Criteria (0.5 — no measurable signal), Constraints (0.6 — no deadline)." → AskUserQuestion: [Yes, proceed] / [Ask 2 more questions] / [Cancel] → on "Yes, proceed" → write spec with `Status: EARLY_EXIT` at `.dt-handoff/<slug>/spec.md`.

**Example 6 — @handoff-in / @handoff-out exchange with analyst:**
After Round 3 answer, skill writes 2,400 bytes of accumulated Q&A to `.dt-handoff/my-feature/artifacts/ask/analyst-2026-05-27T10:00:00Z.md` and dispatches:
```
@handoff-in
kind: handoff
path: .dt-handoff/my-feature/artifacts/ask/analyst-2026-05-27T10:00:00Z.md
contentHash: sha256:abc…
sizeBytes: 2400
note: Score Goal/Constraints/Criteria/Context dimensions for components A and B based on answers so far.
```
`analyst` returns:
```
@handoff-out
kind: advisor
path: .dt-handoff/my-feature/artifacts/ask/analyst-2026-05-27T10:00:00Z.md
status: complete
contentHash: sha256:def…
sizeBytes: 1820
summary: 5 req units, 3 gaps, aggregate ambiguity 2.1 (clarify before planning)
```
Skill reads the scores from that file, computes weighted ambiguity, and displays the Round 3 clarity table.
</Examples>

<Final_Checklist>
- Did Phase 0 emit the threshold marker as the first user-visible line?
- Did I restate the seed idea in one sentence before interviewing?
- Did I run `explorer` for brownfield before asking the user about codebase facts?
- Did I log explorer dispatch and return events to `events.jsonl`?
- Did Round 0 lock the topology before any ambiguity scoring?
- Did I ask exactly ONE question per turn in `$LANGUAGE`?
- Did I emit the metadata as a single context line BEFORE the `AskUserQuestion` call, keeping the `question` field to the question alone (no pipe-packed header)?
- Did I score inline by default and dispatch `analyst` only when ambiguity > 0.4 OR ≥ 2 active components — logging events only when actually dispatched?
- Did I keep each round's progress report to the three-line format (no weighted table, no topology/ontology rows)?
- For N > 1 active components, did I rotate targeting instead of drilling one component?
- Did I dispatch `critic` only when a real gap remained (Contrarian @ R4, Simplifier @ R6, Ontologist @ R8 if ambiguity > 0.3) — at most once each, skipping when the threshold was met early?
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

Each mode is dispatched to `critic` exactly once. The skill receives `critic`'s `@handoff-out` and translates the finding into the next AskUserQuestion.

## Escalation & Stop Conditions

- Hard cap at 20 rounds (configurable via `--max-rounds`): proceed with current clarity, mark `Status: HARD_CAP`.
- Soft warning at 10 rounds: offer to continue or proceed.
- Early exit (round 3+): allow with transparent warning if ambiguity > threshold; mark `Status: EARLY_EXIT`.
- User says "stop" / "cancel" / "abort": stop immediately; do not write a spec.
- Ambiguity stalls (same score ±0.05 for 3 rounds): activate Ontologist mode (dispatch `critic` with Ontologist prompt) to reframe, even if before round 8.
- All dimensions at 0.9+: skip to spec generation even if not at round minimum.
- `explorer` exploration fails: proceed as greenfield, note the limitation in the spec.
- `analyst` dispatch fails: fall back to inline ambiguity scoring using the scoring formula in Step 3e; note the degraded mode in the spec metadata.
</Advanced>
