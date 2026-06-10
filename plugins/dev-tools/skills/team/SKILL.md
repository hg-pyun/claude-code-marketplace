---
name: team
description: 5-stage parallel multi-agent orchestration. Decomposes a task into stories (team-plan via planner+architect), extracts acceptance criteria (team-prd), executes stories in parallel via test-engineer/executor waves with per-stage verifier gates (team-exec), verifies via reviewer/critic (team-verify), and fixes defects with bounded iteration (team-fix). Cleanup via code-simplifier (skip with --no-deslop). Handoffs at .dt-handoff/<slug>/. Auto commit/PR PROHIBITED — same boundary as ralph. TRIGGER on "/team", "team", "팀으로 진행". DO NOT TRIGGER for single-story tasks.
---

<Purpose>
Coordinate parallel multi-agent execution through a 5-stage pipeline: plan → prd → exec → verify → fix (+ Stage 4.5 cleanup, Stage 6 report). The main session acts as the lead — decomposing the task into independent stories, dispatching workers in parallel where dependencies allow, verifying results, and fixing defects with bounded iteration. Output is changes-on-disk + handoff documents + a status report; commit and PR creation are left to the user.

`team` differs from `ralph`: ralph is sequential single-track persistence with strong TDD-per-story discipline; team is parallel multi-track decomposition for tasks where multiple independent surfaces can be worked on at once.
</Purpose>

<Use_When>
- The task naturally decomposes into ≥ 3 independent stories that can run in parallel (different files, no shared state, no ordering dependency).
- User says "/team", "team", "팀으로 진행", "parallel agents".
- A plan (`.dt-handoff/<slug>/plan.md`) explicitly identifies workstreams that can run concurrently.
- `autopilot` Phase 3 chooses team over ralph because the plan has high parallelism.
- A large refactor touches multiple modules, each handled independently.
</Use_When>

<Do_Not_Use_When>
- The task has a strict sequential dependency chain (each story unblocks the next) — use `ralph`.
- The task is a single story or single bug fix — delegate to `executor` directly.
- The task is requirements capture — use `deep-interview`.
- The task is consensus planning — use `ralplan`.
- The user wants automatic commit/PR — refuse; team stops at "ready for commit".
- Total story count is ≥ 20 — split into multiple ralplan sessions first.
</Do_Not_Use_When>

<Why_This_Exists>
Tasks that decompose into independent surfaces waste wall-clock time when run sequentially. A 6-story refactor where each story touches a different module finishes in roughly the duration of the longest story, not the sum. The pipeline makes that parallelism explicit and safe by enforcing stage boundaries: every story is decomposed before any is implemented, every implementation is verified before any is shipped, and the verify→fix loop is bounded so it cannot grind forever.

Handoff documents between stages exist because lead context must transfer cleanly across phase boundaries; without them the lead re-derives decisions every stage or carries stale assumptions across phases. One short markdown file per stage keeps the lead honest and the trail auditable.

Stage-aware worker routing (planner decomposes, executor implements, test-engineer tests, architect reviews design, verifier gates completion, code-simplifier cleans up) avoids a one-size-fits-all worker that either over-skills cheap tasks or under-skills complex ones. A dedicated `verifier` gate removes self-approval: the agent that produced the work is never the one that confirms it is done.
</Why_This_Exists>

<Execution_Policy>
**Output language**: handoff docs, story descriptions, progress entries use `$LANGUAGE`. JSON field names stay English; field values use `$LANGUAGE`.

**TDD Iron Law (non-negotiable)**: every story that adds production behavior MUST have a Red test authored by `test-engineer` BEFORE `executor` runs. The Red step is sequential within a story, even though stories run in parallel.

**Parallel execution rules**:
- Stages are sequential globally (plan → prd → exec → verify → fix loop). Within a story, Red → Green → Refactor is sequential.
- Stage 3 (team-exec): independent stories' Red/Green steps run in parallel — fire N Task calls in ONE message per wave, capped by `--max-parallel`.
- Stage 4 verify: `reviewer` and `critic` run in parallel — the one documented exception to the "no parallel reviewers" rule, justified because they score the same final artifact independently and it saves wall-clock. `--no-critic` skips critic.
- `verifier` runs once per **stage**, NOT per wave: one call after all Stage 3 waves, one call after each Stage 5 fix round.

**Story decomposition rules**:
- Each story completable by ONE worker in ≤ 1 hour of agent time.
- Stories declare `dependsOn[]` if a predecessor is required; the lead respects these for scheduling.
- Stories must not overlap in file scope unless marked `serial` with an explicit ordering.
- Max stories: 20 (soft warning at 10, hard cap at 20). Over 20 → refuse (see `<Escalation_And_Stop_Conditions>`).

**Verdict routing** (machine-readable; single source — Stages 3/4/5 reference this): after every `reviewer`, `critic`, or `verifier` call, read the `verdict` field from the agent's `@handoff-out` block (NEVER prose keyword matching):
- `APPROVE` / `ACCEPT_WITH_RESERVATIONS` → proceed to the next stage.
- `ITERATE` / `REVISE` / `REJECT` → collect the `path` findings, mark affected stories `passes: false`, route to Stage 5 (or escalate if the loop is exhausted).

**Verify → Fix loop bound**: max 3 verify→fix iterations. After 3, escalate unresolved defects to `architect` and stop `BLOCKED_AFTER_VERIFY` (see `<Escalation_And_Stop_Conditions>`).

**Native vs fallback tools**: prefer native multi-agent tools (`TeamCreate`, `TaskCreate`, `SendMessage`) when available — load them via ToolSearch before Stage 3. Fallback: if unavailable, workers write completion directly to `.dt-handoff/<slug>/prd.json` and the lead polls the file via Read between stage steps.

**Auto commit/PR PROHIBITED**: same rule as `ralph`. Never invoke `git-commit`, `github-pr`, `gh pr`, `git commit`, `git push`. The final report includes a "Next steps" suggestion line only.

**Concurrent-write lock (mkdir helper)** — any writer (lead or parallel worker) touching a shared file (`state/team.json`, `prd.json`, `events.jsonl`) MUST acquire a lock before opening for write and release it after. Lock primitive: directory creation (`mkdir <target>.lock/`) is atomic on single-host filesystems. NFS is out-of-scope (see Deployment assumption in `plugins/dev-tools/CLAUDE.md`).

```bash
# acquire
attempts=0; delay_ms=100; max=10
while ! mkdir "<target>.lock" 2>/dev/null; do
  attempts=$((attempts+1))
  [ $attempts -ge $max ] && { echo "lock acquire timeout"; exit 1; }
  # multiplicative jitter: delay * random(0.8, 1.2)
  jittered=$(( delay_ms * (80 + RANDOM % 41) / 100 ))
  sleep "$(awk -v ms=$jittered 'BEGIN{print ms/1000}')"
  delay_ms=$(( delay_ms * 2 ))
  [ $delay_ms -gt 2000 ] && delay_ms=2000
done
echo "$$ $(date -u +%FT%TZ)" > "<target>.lock/owner.txt"
# ... do the write ...
# release
rm -f "<target>.lock/owner.txt" && rmdir "<target>.lock"
```

If acquire times out (max 10 retries, initial 100 ms, cap 2 s, multiplicative jitter ±20%), the worker MUST report up to the lead instead of overwriting; the lead serializes the critical section in the main session.

**events.jsonl logging** (single schema definition; team KEEPS per-dispatch frequency under the lock — this is legitimate wave coordination): Stage 3 / Stage 5 append one JSON line per coordination event (dispatch and return). Acquire the events.jsonl lock first, then append, then release. File: `.dt-handoff/<slug>/events.jsonl`, `kind: trace`, `retention: session`. Each line conforms to the §9 handoff-protocol schema:

```jsonl
{"ts":"<ISO8601>","producer":"team","consumer":"test-engineer","event":"dispatch","kind":"handoff","path":".dt-handoff/<slug>/prd.json","status":"pending","verdict":null}
{"ts":"<ISO8601>","producer":"verifier","consumer":"team","event":"return","kind":"advisor","path":".dt-handoff/<slug>/artifacts/ask/verifier-<ISO8601>.md","status":"complete","verdict":"APPROVE"}
```

Fields: `ts` (ISO8601 UTC), `producer`, `consumer`, `event` (`dispatch`|`return`), `kind`, `path`, `status`, `verdict` (null unless a judgment agent). Stage steps say "append dispatch/return events" — they do not re-inline this schema.

**Handoff descriptor frontmatter** (team-*.md docs): every `team-<stage>.md` the lead writes MUST open with this 9-field OMC descriptor before the heading. Machine-authoritative schema: `scripts/validate.sh` (Descriptors lane header).

```yaml
---
kind: handoff
path: .dt-handoff/<slug>/team-<stage>.md
contentHash: sha256:<hash of body below>
createdAt: <ISO8601-now>
producer: team
sizeBytes: <byte count of body below>
retention: permanent
expiresAt: null
status: complete
---
```
</Execution_Policy>

<Settings_Reference>
| Flag | Default | Effect |
|------|---------|--------|
| `--lang=<value>` | `plugin.json` `settings.language` (`Korean`) | Output language for handoff docs / reports. |
| `--from-plan=<path>` | infer | Consume an existing `.dt-handoff/<slug>/plan.md` as input. |
| `--max-parallel=<n>` | 5 | Cap concurrent `executor` calls per Task batch; throttles cost-sensitive sessions. |
| `--no-critic` | off (both run) | Skip the `critic` half of Stage 4; rely on `reviewer` alone. |
| `--no-deslop` | off (cleanup runs) | Skip the Stage 4.5 code-simplifier cleanup pass. |
</Settings_Reference>

<Arguments>
Task description plus flags above. Examples:
- `/team "Linear webhook 처리 서비스 6개 모듈 동시 구현"`
- `/team --from-plan=.dt-handoff/auth-refactor/plan.md --max-parallel=3`
- `/team --no-critic --no-deslop "config 모듈 4개 병렬 리네임"`
</Arguments>

<Steps>
Each stage is declarative: **goal · delegate · input→output · success / fail**. Cross-cutting mechanics (lock, events logging, handoff blocks, verdict routing) follow the single rules in `<Execution_Policy>` and `<Tool_Usage>` — they are not re-spelled per stage. When dispatching an agent, steps name only the artifact **kind + path** to hand in; the `@handoff-in` mechanics live in `<Tool_Usage>`. The shared handoff doc schema is defined once at the end of this section.

### Stage 1: team-plan (Decomposition)
- **Goal**: turn the task into a dependency-ordered set of independent stories.
- **Input**: load `.dt-handoff/<slug>/plan.md` if `--from-plan`, else infer from the task description + the most recent `plan.md`.
- **Delegate `explorer`** (hand in: the task description): map the surfaces involved — files, modules, integration points likely touched.
- **Delegate `planner`** (hand in: `kind: plan` @ `plan.md`, plus the explorer summary): decompose into independent stories suitable for parallel execution. Each story: `id`, `description`, `layer` (test/impl/refactor/infra), `dependsOn[]`, `fileScope[]`, `risk`, testable acceptance criteria. Planner returns structured plan content; the lead writes it to disk.
- **Delegate `architect`** (hand in: `kind: advisor` @ the planner findings file) for any stories tagged `design-heavy`: flag interface concerns; consume the verdict to adjust story scope if needed.
- **Output**: write `.dt-handoff/<slug>/team-plan.md` (decomposition, rejected alternatives, dependency DAG, risk list, parallelism budget). Append dispatch/return events.

### Stage 2: team-prd (Acceptance Criteria)
- **Goal**: convert the plan into a machine-checkable `prd.json`.
- **Delegate**: none — the lead authors directly after reading `team-plan.md`.
- **Output**: `.dt-handoff/<slug>/prd.json`. Each story carries `id`, `description`, `priority`, `layer`, `tags`, `dependsOn[]`, `fileScope[]`, `acceptanceCriteria[]` (testable, file-anchored where possible), `assignTo` (`executor` / `test-engineer` / `architect`), `passes: false`, `completedAt: null`, `evidence: null`. Refine any generic/placeholder ACs into task-specific testable ones (same as ralph Step 1.3). Then write `.dt-handoff/<slug>/team-prd.md` (count, DAG visualization, AC quality notes).

### Stage 3: team-exec (Parallel Execution)
- **Goal**: drive every story Red → Green in dependency-ordered waves, then gate the whole stage once.
- **Build the wave schedule** from the dependency DAG (topological sort):
  - Wave 1 = all stories with empty `dependsOn`.
  - Wave N+1 = stories whose deps are all completed in waves 1..N.
  - **Cycle detection**: if no topological sort exists, STOP and report the cycle before proceeding.
- **For each wave** (cap concurrency by `--max-parallel`; split oversized waves into sequential sub-batches):
  - **Red** — fire `test-engineer` Tasks in parallel (ONE message) for all stories with `layer != refactor` and no existing Red test. Hand in: `kind: prd` @ `prd.json` + the story note. Append dispatch events.
  - Wait for all Red outputs, consume each `@handoff-out`, record red-test paths in `prd.json`, append return events.
  - **Green** — fire `executor` Tasks in parallel (ONE message). Hand in: `kind: prd` @ `prd.json` + the red-test path. Append dispatch events.
  - Wait for all Green outputs, consume each `@handoff-out`, update `prd.json` for stories reporting `status: complete`, append return events.
- **Per-stage verifier gate** (after ALL waves, NOT per wave): fire ONE `verifier` Task covering all changed files. Hand in: `kind: prd` @ `prd.json` + the changed-file list. Route on its `verdict` per `<Execution_Policy>`: APPROVE/ACCEPT_WITH_RESERVATIONS → Stage 4; REVISE/REJECT → route failing stories straight to Stage 5 (do not enter Stage 4 until verifier approves). Append the return event.
- **Output**: write `.dt-handoff/<slug>/team-exec.md` (completed stories, parallelism realized, verifier verdict, single-story escalations, files changed).

### Stage 4: team-verify (Review)
- **Goal**: independent multi-perspective review of the changed file set against the PRD.
- **Delegate `reviewer` + `critic` in parallel** (ONE message, unless `--no-critic` skips critic). Hand in to both: `kind: prd` @ `prd.json` + the changed-file list. `reviewer` = severity-rated review against ACs; `critic` = adversarial pressure test (principle-option consistency, missed alternatives, residual risk).
- **Route on verdicts** per `<Execution_Policy>`: all APPROVE/ACCEPT_WITH_RESERVATIONS → Stage 4.5; any ITERATE/REVISE/REJECT → collect findings from each agent's `path`, mark affected stories `passes: false`, route to Stage 5.
- **Output**: write `.dt-handoff/<slug>/team-verify.md` (combined findings, verdict values, severity counts, which stories return to fix). Append reviewer/critic return events.

### Stage 4.5: team-cleanup (skip if `--no-deslop`)
- **Goal**: behavior-preserving simplification scoped to the changed file set.
- **Delegate `code-simplifier`** (hand in: `kind: handoff` @ `team-exec.md` + the changed-file scope): apply ONLY findings inside the changed-file set (same scope boundary as ralph Step 7.5).
- **Success / fail**: consume `@handoff-out`, then re-run regression (full test/build/lint on changed files). If regression fails, roll back the offending cleanup edit and retry up to 2x; if still failing, mark cleanup best-effort and proceed.

### Stage 5: team-fix (Bounded Iteration)
- **Goal**: resolve Stage 4 (or Stage 3 verifier) findings, gate, and re-verify — within the 3-iteration bound.
- For each flagged story, reset `passes: false` with the finding ID and source agent attached.
- **Delegate `executor` Tasks in parallel** (ONE message), one per finding. Hand in: `kind: advisor` @ the relevant findings file + a one-line finding summary (e.g. "Finding REV-003 on US-002"). Append dispatch events.
- **Per-stage verifier gate** (after all fix executors complete): fire ONE `verifier` Task. Hand in: `kind: prd` @ `prd.json` + the fixed-story list. Consume the `verdict`; append the return event.
- **Re-verify**: return to Stage 4 for re-verification of the fixed stories only (reviewer + critic).
- **Bound**: cap at 3 verify→fix iterations. After 3, escalate unresolved findings to `architect` and stop `BLOCKED_AFTER_VERIFY`.

### Stage 6: Report and Stop
- **Compose the final report** in `$LANGUAGE`: stories total/completed/blocked; parallelism achieved (avg concurrent workers, peak wave size); files changed (count + list); Stage 3 verifier verdict; Stage 4 combined verdict (reviewer + critic); cleanup pass status; final regression PASS.
- **Next steps**: suggest "Run `/git-commit` to commit" + "Run `/github-pr` to open PR" — do NOT invoke.
- Write `.dt-handoff/<slug>/team-final.md` with the complete trail (descriptor `kind: handoff`, `retention: permanent`).
- **STOP**. No git mutations.

### Handoff Document Schema (all team-*.md stages share)
```markdown
# Team Stage <N>: <stage-name>

## Inputs
- ... (what was read)
## Decisions
- ... (what was chosen)
## Rejected Alternatives
- ... (and why)
## Risks Identified
- ... (and proposed mitigations)
## Outputs
- ... (what file/state changed)
## Remaining Work
- ... (what the next stage will pick up)
```
</Steps>

<Tool_Usage>
- **Read**: load plan.md, prior handoff docs, source files for AC verification, `@handoff-out` findings at each agent's `path`.
- **Write/Edit**: handoff docs (`team-*.md`), `prd.json` story updates, `progress.txt` appendices.
- **Bash**: run tests / build / lint / typecheck for AC verification; acquire the mkdir lock before any shared-file write and append to `events.jsonl` under it; regression in Stage 4.5. NO `git commit`, `git push`, `gh pr`.
- **Task** (bare agent names, no plugin prefix — single roster): `explorer` (Stage 1 discovery), `planner` (Stage 1 decomposition + DAG + ACs), `architect` (Stage 1 design review for `design-heavy` stories; also the 3-fail escalation target), `test-engineer` (Red), `executor` (Green/Refactor/Fix), `verifier` (Stage 3 and Stage 5 completion gates), `reviewer` + `critic` (Stage 4), `code-simplifier` (Stage 4.5 cleanup). This is the complete worker pool.
- **ToolSearch**: load `TeamCreate` / `TaskCreate` / `SendMessage` schemas before Stage 3 if using native multi-agent tools (else fall back to direct `prd.json` write + poll).
- **TodoWrite**: track wave-by-wave progress in-session.
- **Handoff contract** (single rule — do not re-spell per stage): when dispatching an agent that consumes a persisted artifact, include a `@handoff-in` reference block — `kind`, `path`, and `contentHash`/`sizeBytes` per the protocol; inline the body only when `sizeBytes ≤ INLINE_MAX_BYTES`. Because team runs parallel waves that can mutate shared artifacts, set `verify: hash` on every `@handoff-in` dispatched to a worker — agents verify `contentHash` only when that field is present (sequential skills omit it). List multiple `@handoff-in` blocks for multiple inputs; drop dynamic lists (e.g. changed-file sets) into a small `kind: handoff` manifest rather than inline prose. Consume the returning `@handoff-out` block and route on its `verdict`. The `@handoff-in`/`@handoff-out` shapes, descriptor schema, `verdict` enum, and `INLINE_MAX_BYTES` are defined in the handoff protocol (§6/§7), mirrored in the `scripts/validate.sh` header.
- Do NOT invoke `git-commit`, `github-pr`, `ralph`, `autopilot`, `ralplan` from inside team.
</Tool_Usage>

<Examples>
**Example 1 — 6-module refactor, full parallelism**:
User: `/team --from-plan=.dt-handoff/auth-refactor/plan.md`. Stage 1: explorer maps 6 modules → planner decomposes into 6 independent stories (`dependsOn: []`, falsifiable ACs) → architect reviews 1 design-heavy story, no changes. Stage 2: prd.json has 6 stories (4 impl + 2 test). Stage 3: Wave 1 fires 6 test-engineer Tasks in parallel (Red), then 6 executor Tasks in parallel (Green) → all Green; verifier gate `APPROVE`; events.jsonl appended throughout under lock. Stage 4: reviewer + critic in parallel → both `APPROVE`. Stage 4.5: code-simplifier → 2 minor edits → regression PASS. Stage 6: "6 stories, ~6x parallelism, ready for commit. Suggest /git-commit and /github-pr." STOP.

**Example 2 — partial fix loop with verdict routing**:
Stage 4 reviewer `verdict: REVISE` (findings at `artifacts/ask/reviewer-<ts>.md`); critic `APPROVE`. Lead reads the reviewer findings, Stage 5 fires 2 targeted executor Tasks handing in the reviewer findings file, verifier gate `APPROVE`, return to Stage 4 → both APPROVE. Iterations: 1/3. Proceed to Stage 4.5.

**Example 3 — over-budget refuse**:
User: `/team 'rewrite the entire backend'`. Stage 1 planner returns 35 stories → exceeds the 20 hard cap. Lead refuses without entering Stage 2: "Story count 35 exceeds team's hard cap of 20. Run `/ralplan` to split into 2-3 phases, each fed into a separate team session." STOP.

**Example 4 — verify deadlock**:
Stage 4 → Stage 5 loop runs 3x; critic still `verdict: REJECT` on iteration 3 (residual-risk concern). Stop `BLOCKED_AFTER_VERIFY`, escalate the unresolved finding to architect, include the architect recommendation in the report. No auto-commit.

**Example 5 — Stage 3 verifier blocks progression**:
After all waves, verifier `verdict: REVISE` (2 stories have failing tests). Lead routes those 2 stories to Stage 5 immediately (skip Stage 4 until verifier approves). After fix, verifier `APPROVE` → proceed to Stage 4.

**Example 6 — dependency cycle**:
Stage 3 wave derivation finds US-002 → US-004 → US-002. No topological sort exists → STOP and report the cycle before dispatching any worker.
</Examples>

<Final_Checklist>
- Did Stage 1 dispatch `explorer` for discovery AND `planner` for decomposition (not architect directly), and route `design-heavy` stories to `architect`?
- Did `planner` return stories with explicit `dependsOn[]`, `fileScope[]`, and falsifiable ACs? Did Stage 2 refine generic ACs into testable ones?
- Did Stage 3 derive waves from the DAG, detect cycles, and fire parallel Tasks in a single message per wave (not sequential)?
- Did every impl story go through Red (test-engineer) → Green (executor)?
- Did the lead append dispatch/return events to `events.jsonl` under the mkdir lock throughout?
- Did Stage 3 end with ONE `verifier` gate (covering all stories, not per-wave), and Stage 5 with a `verifier` gate after each fix round?
- Did Stage 4 run reviewer + critic in parallel (unless `--no-critic`)?
- Did the lead route on `@handoff-out` `verdict` fields (never prose keyword matching)?
- Did Stage 4.5 dispatch `code-simplifier` scoped to changed files (unless `--no-deslop`), and did post-cleanup regression pass?
- Did I respect the 3-iteration verify→fix cap, and refrain from all git/gh mutations?
- Did handoff docs exist for every stage transition with 9-field descriptor frontmatter, all paths under `.dt-handoff/<slug>/`?
- Did the final report include a "Next steps: /git-commit + /github-pr" suggestion (not invocation)?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
Single source for terminal statuses.
- All stories `passes: true` + Stage 3 verifier APPROVE + reviewer + critic APPROVE + cleanup done + regression GREEN → report and stop.
- Story count > 20 → refuse; route to `ralplan` for splitting.
- Dependency cycle (no topological sort in Stage 3) → stop and report the cycle before dispatching workers.
- User says "stop", "cancel", "abort" → stop immediately; update the final handoff with `USER_HALTED`.
- 3 verify→fix iterations without convergence → escalate unresolved findings to `architect`; stop `BLOCKED_AFTER_VERIFY`.
- Any single story fails 3 consecutive worker attempts → escalate that story's root cause to `architect`; mark blocked; continue other stories.
- Cleanup pass introduces 2 consecutive regression failures → roll back cleanup, mark Stage 4.5 best-effort, proceed.
- Lock acquire timeout → the worker reports up to the lead; the lead serializes the critical section (does not overwrite).
- Native multi-agent tools load but error during use → fall back to direct `prd.json` polling; do not block the run.
</Escalation_And_Stop_Conditions>

<Advanced>
## Dependency Graph Visualization
The lead may emit a simple ASCII DAG in `team-prd.md` to make the wave schedule obvious and surface wrong dependencies:
```
[US-001] ──┐
            ├─→ [US-003] ──→ [US-006]
[US-002] ──┘
[US-004]            (parallel, no deps)
[US-005]            (parallel, no deps)
```

## Native Multi-Agent Tool Integration
When `TeamCreate` + `TaskCreate` + `SendMessage` are available: Stage 1 `TeamCreate` (roles from `assignTo`), Stage 2 `TaskCreate` per story, Stage 3 dispatch with workers `SendMessage`-ing back to the lead, Stage 6 `TeamDelete`. When NOT available (fallback): workers write `passes: true` to `prd.json` directly, the lead polls via Read between waves, no team registration (stateless one-shot Task calls).

## Parallelism Budget
`--max-parallel=N` (default 5) caps concurrent `executor` calls per Task batch. Higher = faster but costlier; lower = serialized waves with predictable cost. If a wave has more stories than the cap, split it into sequential sub-batches (parallel within each sub-batch).

## Distinguishing team vs ralph
Use `team` when ≥ 3 stories run truly independently (different files, layers, no ordering). Use `ralph` when the work is a chain (each story depends on the previous) or all stories touch a small shared module. A mixed task may need both: `ralplan` decomposes, `team` runs the parallel parts, the lead falls back to `ralph` for the serial tail.

## planner vs architect in Stage 1
`planner` owns story decomposition: DAG construction, AC authoring, file scoping, wave derivation. `architect` is called in Stage 1 only for `design-heavy` stories — interface shape, technology choices, ambiguous boundaries the planner flagged as open. Do not skip `planner` and go directly to `architect` for decomposition; that conflates sequencing with design.
</Advanced>
</content>
</invoke>
