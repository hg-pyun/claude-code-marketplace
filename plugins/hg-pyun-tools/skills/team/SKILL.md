---
name: team
description: 5-stage parallel multi-agent orchestration. Decomposes a task into stories (team-plan), extracts acceptance criteria (team-prd), executes stories in parallel via executor/test-engineer (team-exec), verifies via reviewer/critic (team-verify), and fixes defects with bounded iteration (team-fix). Auto commit/PR PROHIBITED — same boundary as ralph. TRIGGER on "/team", "team", "팀으로 진행". DO NOT TRIGGER for single-story tasks.
---

<Purpose>
Coordinate parallel multi-agent execution through a 5-stage pipeline: plan → prd → exec → verify → fix. The main session acts as the lead, decomposing the task into independent stories, dispatching workers in parallel where dependencies allow, verifying results, and fixing defects with bounded iteration. Output is changes-on-disk + handoff documents + a status report — commit and PR creation are explicitly left to the user.

`team` differs from `ralph`: ralph is sequential single-track persistence with a strong TDD-per-story discipline; team is parallel multi-track decomposition optimized for tasks where multiple independent surfaces can be worked on at once.
</Purpose>

<Use_When>
- The task naturally decomposes into ≥ 3 independent stories that can run in parallel (different files, no shared state, no ordering dependency).
- User says "/team", "team", "팀으로 진행", "parallel agents".
- A plan (`.specs/<slug>/plan.md`) explicitly identifies workstreams that can run concurrently.
- `autopilot` Phase 3 (Execution) chooses team over ralph because the plan has high parallelism.
- A large refactor touches multiple modules and each module can be handled independently.
</Use_When>

<Do_Not_Use_When>
- The task has a strict sequential dependency chain (each story unblocks the next) — use `ralph`.
- The task is a single story or a single bug fix — delegate to `executor` directly.
- The task is requirements capture — use `deep-interview`.
- The task is consensus planning — use `ralplan`.
- The user wants automatic commit/PR — refuse; team stops at "ready for commit".
- Total story count is ≥ 20 — split into multiple ralplan sessions first.
</Do_Not_Use_When>

<Why_This_Exists>
Tasks that decompose into independent surfaces waste wall-clock time when executed sequentially. A 6-story refactor where each story touches a different module can finish in roughly the duration of the longest story, not the sum. The team pipeline makes that parallelism explicit and safe by enforcing stage boundaries: every story is decomposed before any is implemented, every implementation is verified before any is shipped, and the verify→fix loop is bounded so it cannot grind forever.

Handoff documents between stages exist because lead context must transfer cleanly across phase boundaries. Without them, the lead either re-derives decisions every stage or carries stale assumptions across phases. Writing one short markdown file per stage keeps the lead honest and the trail auditable.

The stage-aware worker routing (executor for impl, test-engineer for test, architect for design pressure) exists because a one-size-fits-all worker either over-skills cheap tasks or under-skills complex ones.

Auto commit/PR prohibition matches `ralph`'s boundary: the marketplace's commit/PR skills are user-triggered tools, not automated chain links.
</Why_This_Exists>

<Execution_Policy>
**Output language**: handoff documents, story descriptions, progress entries use `$LANGUAGE`. JSON field names stay English; field values use `$LANGUAGE`.

**TDD Iron Law (non-negotiable)**:
- Every story that adds production behavior MUST have a Red test authored by `test-engineer` BEFORE `executor` runs.
- The Red step is sequential within a story even though stories themselves run in parallel.

**Auto commit/PR PROHIBITED**:
- Same rule as `ralph`. Never invoke `git-commit`, `github-pr`, `gh pr`, `git commit`, `git push`.
- Final report includes a "Next steps" suggestion line only.

**Parallel execution rules**:
- Stage 3 (team-exec): independent stories' Green/Refactor steps MAY run in parallel by firing multiple `executor` Task calls in a single message.
- Within a story: Red → Green → Refactor is sequential.
- Stages themselves are sequential globally (plan completes → prd completes → exec completes → verify → fix loop).
- Stage 4 verify: `reviewer` and `critic` MAY be invoked in parallel since they evaluate the same artifact independently. (This is the one exception to the "no parallel reviewers" rule used elsewhere — for team, the parallel verify saves wall-clock and the two outputs are independently scored.)

**Story decomposition rules**:
- Each story must be completable by ONE worker in ≤ 1 hour of agent time.
- Stories must declare `dependsOn` if any predecessor is required; the lead respects these for scheduling.
- Stories must not overlap in file scope unless explicitly marked `serial` and given an ordering.
- Max stories per team run: 20 (soft warning at 10, hard cap at 20). Split larger work into multiple sessions.

**Worker pool**:
- `executor` — impl, refactor, infra stories.
- `test-engineer` — test authoring, coverage gaps, flaky diagnosis.
- `architect` — design pressure for stories tagged `design-heavy`; also the 3-fail escalation target.
- `reviewer` — Stage 4 standard verification.
- `critic` — Stage 4 adversarial verification.
- `explorer` — Stage 1 (plan) discovery only; not used in exec.

**Verify → Fix loop bound**:
- Max 3 verify→fix iterations. After 3, escalate unresolved defects to `architect` and stop with status `BLOCKED_AFTER_VERIFY`.

**Handoff documents**:
- After each stage transition, the lead writes `.specs/<slug>/team-<stage>.md` capturing: decisions made, rejected alternatives, identified risks, remaining work.
- The lead reads the previous handoff BEFORE spawning the next stage's workers.

**Native vs fallback tools**:
- Prefer native multi-agent tools (`TeamCreate`, `TaskCreate`, `SendMessage`) when available — load them via ToolSearch before Stage 3.
- Fallback: if native tools are unavailable, workers write directly to `.specs/<slug>/prd.json` to report completion, and the lead polls the file via Read between stage steps.

**Hand-off descriptor frontmatter** (team-*.md handoff docs):
Every `team-<stage>.md` written by the lead MUST open with this OMC descriptor frontmatter before the heading. See `plugins/hg-pyun-tools/SPEC.md` for the full schema.

```yaml
---
kind: handoff
path: .specs/<slug>/team-<stage>.md
contentHash: sha256:<hash of body below>
createdAt: <ISO8601-now>
producer: team
sizeBytes: <byte count of body below>
retention: permanent
expiresAt: null
status: complete
---
```

**mkdir-based lock helper** (for concurrent writes to `state/team.json`, `prd.json`, `events.jsonl`):
The lead and any parallel worker that writes to a shared file MUST acquire a lock before opening for write and release it after the write completes. Lock primitive: directory creation (`mkdir <target>.lock/`) is atomic on single-host filesystems. NFS is out-of-scope.

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

**events.jsonl writer** (team mode only; under lock):
Stage 3 / Stage 5 may append one JSON line per coordination event. Acquire the events.jsonl lock first, then append, then release. Each line is a self-contained JSON object with `event`, `ts`, `actor`, `payload`. The file is session/day retention; do not commit it.
</Execution_Policy>

<Settings_Reference>
- `$LANGUAGE`: from `plugin.json` `settings.language` (default `Korean`). Override with `--lang=<value>`.
- `--from-plan=<path>`: consume an existing `.specs/<slug>/plan.md` as input.
- `--max-parallel=<n>`: cap concurrent `executor` calls (default: 5). Useful to throttle in cost-sensitive sessions.
- `--no-critic`: skip the `critic` half of Stage 4; rely on `reviewer` alone. Default: both run.
- `--no-deslop`: skip the post-verify cleanup pass (analogous to ralph's flag). Default: cleanup runs.
</Settings_Reference>

<Arguments>
Task description plus flags:
- `--from-plan=<path>` — explicit plan input
- `--max-parallel=<n>` — concurrent worker cap (default 5)
- `--no-critic` — skip critic in Stage 4
- `--no-deslop` — skip Stage 4.5 cleanup
- `--lang=<value>` — output language override
Examples:
- `/team "Linear webhook 처리 서비스 6개 모듈 동시 구현"`
- `/team --from-plan=.specs/auth-refactor/plan.md --max-parallel=3`
</Arguments>

<Steps>

### Stage 1: team-plan (Decomposition)
1. **Read input**: load `.specs/<slug>/plan.md` if `--from-plan`, else infer from the task description and the most recent `.specs/<slug>/plan.md`.
2. **Delegate scope discovery to explorer**:
   ```
   Task(
     subagent_type="explorer",
     prompt="Map the surfaces involved in: <task description>.
     List files, modules, and integration points likely to be touched."
   )
   ```
3. **Delegate decomposition to architect**:
   ```
   Task(
     subagent_type="architect",
     prompt="Decompose the task into independent stories suitable for parallel execution.
     For each: id, description, layer (test/impl/refactor/infra), dependsOn[], file scope, risk.
     Plan: <plan.md content>
     Discovery: <explorer output>"
   )
   ```
4. **Write `.specs/<slug>/team-plan.md`** (handoff doc) with: decomposition, rejected alternatives, dependency DAG, risk list, parallelism budget.

### Stage 2: team-prd (Acceptance Criteria)
5. **Lead reads `team-plan.md`** and authors `.specs/<slug>/prd.json` directly. Each story gets:
   - `id`, `description`, `priority`, `layer`, `tags`, `dependsOn[]`, `fileScope[]`
   - `acceptanceCriteria[]` — testable, file-anchored where possible
   - `assignTo` — worker type (`executor` / `test-engineer` / `architect`)
   - `passes: false`, `completedAt: null`, `evidence: null`
6. **Refine generic criteria** (same as ralph Step 1.3): replace placeholder ACs with task-specific testable ones.
7. **Write `.specs/<slug>/team-prd.md`** handoff: count, dependency DAG visualization, AC quality notes.

### Stage 3: team-exec (Parallel Execution)
8. **Build a wave schedule** from the dependency DAG:
   - Wave 1 = all stories with empty `dependsOn`.
   - Wave N+1 = stories whose deps are all completed in waves 1..N.
9. **For each wave**:
   a. **TDD Red step** — fire `test-engineer` Tasks in parallel for all stories with `layer != refactor` and no existing Red test:
      ```
      [
        Task(subagent_type="test-engineer", prompt="...story US-001..."),
        Task(subagent_type="test-engineer", prompt="...story US-003..."),
        ...
      ]
      ```
      All in ONE message. Cap by `--max-parallel`.
   b. **Wait for all Red outputs**. Update `prd.json` with red-test paths.
   c. **Green step** — fire `executor` Tasks in parallel:
      ```
      [
        Task(subagent_type="executor", prompt="...story US-001 Green..."),
        Task(subagent_type="executor", prompt="...story US-003 Green..."),
      ]
      ```
   d. **Wait for all Green outputs**. Each executor reports back with files changed + fresh test output.
   e. **Verify each story's AC** with fresh evidence (lead reads test/build output for each).
   f. **Update `prd.json`** for stories that passed.
10. **After all waves**: confirm every story `passes: true`. If any failed, route to Stage 5 (fix) for those stories only; don't return to Stage 3 wholesale.
11. **Write `.specs/<slug>/team-exec.md`** handoff: completed stories, parallelism realized, any single-story escalations, files changed.

### Stage 4: team-verify (Review)
12. **Build the verify prompt**: aggregate all changed files across stories, the full `prd.json`, the dependency graph.
13. **Fire parallel verify** (unless `--no-critic`):
    ```
    [
      Task(subagent_type="reviewer", prompt="Severity-rated review of <changed file list> against <prd.json AC>"),
      Task(subagent_type="critic",   prompt="Adversarial pressure test of the implementation; principle-option consistency, missed alternatives, residual risk")
    ]
    ```
14. **Combine verdicts**:
    - Both APPROVE → proceed to Stage 4.5.
    - Either REQUEST CHANGES / REJECT / ITERATE → collect findings, mark affected stories `passes: false`, route to Stage 5.
15. **Write `.specs/<slug>/team-verify.md`** handoff: combined findings list, severity counts, decisions about which stories return to fix.

### Stage 4.5: team-cleanup (skip if `--no-deslop`)
16. **Invoke** `Skill("hg-pyun-tools:code-review", args="--scope=<changed files>")`.
17. **Apply ONLY findings inside the changed-file set**. Same scope boundary as ralph Step 7.5.
18. **Re-run regression** (full test/build/lint on changed files). If it fails, roll back the offending cleanup edit and retry up to 2x. If still failing, mark cleanup pass as best-effort and proceed.

### Stage 5: team-fix (Bounded Iteration)
19. **For each story flagged by Stage 4**: reset `passes: false` with the finding ID attached.
20. **Fire targeted fix Tasks in parallel**:
    ```
    [
      Task(subagent_type="executor", prompt="Address reviewer finding REV-003 on story US-002. Finding: ..."),
      Task(subagent_type="executor", prompt="Address critic finding CRIT-001 on story US-005. Finding: ..."),
    ]
    ```
21. **Return to Stage 4** for re-verification of the fixed stories only.
22. **Cap at 3 verify→fix iterations**. After 3, escalate unresolved findings to `architect` and stop with status `BLOCKED_AFTER_VERIFY`.

### Stage 6: Report and Stop
23. **Compose final report** in `$LANGUAGE`:
    - Stories total / completed / blocked
    - Parallelism achieved (avg concurrent workers, peak wave size)
    - Files changed (count + list)
    - Verify verdict (reviewer + critic, combined)
    - Cleanup pass status
    - Final regression: PASS
    - **Next steps**: "Run `/git-commit` to commit" + "Run `/github-pr` to open PR" — do NOT invoke.
24. **Write `.specs/<slug>/team-final.md`** with the complete trail.
25. **STOP**. Do not invoke any git mutation.

### Handoff Document Schema (all stages share)

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
- **Read**: load plan.md, prior handoff docs, source files for AC verification, worker outputs.
- **Write/Edit**: handoff docs (`team-*.md`), `prd.json` story updates, `progress.txt` appendices.
- **Bash**: run tests / build / lint / typecheck for AC verification. NO `git commit`, `git push`, `gh pr`.
- **Task**: workers per stage routing (`explorer` for plan discovery, `architect` for decomposition + 3-fail escalation, `test-engineer` for Red, `executor` for Green/Refactor/Fix, `reviewer` + `critic` for Stage 4 verify).
- **Skill**: invoke `hg-pyun-tools:code-review` for Stage 4.5 cleanup.
- **ToolSearch**: load `TeamCreate` / `TaskCreate` / `SendMessage` schemas before Stage 3 if planning to use native multi-agent tools (otherwise fallback to direct `prd.json` write).
- **TodoWrite**: track wave-by-wave progress in-session.
- Do NOT invoke `git-commit`, `github-pr`, `ralph`, `autopilot`, `ralplan` from inside team.
</Tool_Usage>

<Examples>
**Example 1 — 6-module refactor with full parallelism**:
User: "/team --from-plan=.specs/auth-refactor/plan.md"
Flow:
- Stage 1: explorer maps 6 auth-related modules → architect decomposes into 6 independent stories (no shared file scope).
- Stage 2: prd.json has 6 stories, all `dependsOn: []`, layer mix (4 impl + 2 test).
- Stage 3: Wave 1 fires 6 test-engineer Tasks in parallel (Red), then 6 executor Tasks in parallel (Green) → all green.
- Stage 4: reviewer + critic in parallel → both APPROVE.
- Stage 4.5: code-review skill → 2 minor cleanup edits applied.
- Stage 4.6: regression PASS.
- Stage 6: report "6 stories, ~6x parallelism, ready for commit. Suggest /git-commit and /github-pr." STOP.

**Example 2 — partial fix loop**:
Stage 4 reviewer flags US-002 and US-005 with MAJOR findings. Stage 5 fires 2 targeted executor Tasks in parallel → re-verify Stage 4 → both APPROVE. Total verify→fix iterations: 1/3. Proceed to Stage 4.5.

**Example 3 — over-budget**:
User: "/team 'rewrite the entire backend'"
Flow: Stage 1 explorer + architect decomposition returns 35 stories.
Lead: refuses to proceed (over the 20 hard cap). Reports back: "Story count 35 exceeds team's hard cap of 20. Recommend running `/ralplan` to split into 2-3 phases, each fed into separate team sessions."
STOP without entering Stage 2.

**Example 4 — verify deadlock**:
Stage 4 → Stage 5 loop runs 3x. Critic still rejects on iteration 3 (residual risk concern).
Action: stop with status `BLOCKED_AFTER_VERIFY`. Escalate the unresolved finding to architect. Final report includes the architect's recommendation. Do not auto-commit anything.
</Examples>

<Final_Checklist>
- Did Stage 1 produce a decomposition with explicit `dependsOn[]` and file scope per story?
- Did Stage 2 refine generic AC into task-specific testable ones?
- Did Stage 3 fire parallel Tasks in a single message per wave (not sequential)?
- Did every impl story go through Red (test-engineer) → Green (executor)?
- Did Stage 4 run reviewer + critic in parallel (unless `--no-critic`)?
- Did Stage 4.5 invoke `code-review` skill scoped to changed files (unless `--no-deslop`)?
- Did the post-cleanup regression pass?
- Did I respect the 3-iteration cap on verify→fix?
- Did I refrain from running git/gh mutations?
- Did the final report include a "Next steps: /git-commit + /github-pr" suggestion (not invocation)?
- Did handoff docs exist for every stage transition?
</Final_Checklist>

<Escalation_And_Stop_Conditions>
- All stories `passes: true` + reviewer + critic APPROVE + cleanup done + regression GREEN → report and stop.
- Story count > 20 → refuse; route to `ralplan` for splitting.
- User says "stop", "cancel", "abort" → stop immediately; update final handoff with `USER_HALTED`.
- 3 verify→fix iterations without convergence → escalate unresolved findings to `architect`; stop with `BLOCKED_AFTER_VERIFY`.
- Any single story fails 3 consecutive worker attempts → escalate that story's root cause to `architect`; mark blocked; continue other stories.
- Cleanup pass introduces 2 consecutive regression failures → roll back cleanup, mark Stage 4.5 best-effort, proceed.
- Native multi-agent tools (`TeamCreate` etc.) load but error during use → fall back to direct `prd.json` polling; do not block the run.
</Escalation_And_Stop_Conditions>

<Advanced>
## Dependency Graph Visualization
The lead may emit a simple ASCII DAG in `team-prd.md`:
```
[US-001] ──┐
            ├─→ [US-003] ──→ [US-006]
[US-002] ──┘
[US-004]            (parallel, no deps)
[US-005]            (parallel, no deps)
```
This makes the wave schedule obvious and helps the user spot wrong dependencies.

## Native Multi-Agent Tool Integration
When `TeamCreate` + `TaskCreate` + `SendMessage` are available:
- Stage 1 creates the team (`TeamCreate` with role config from `assignTo`).
- Stage 2 creates `TaskCreate` entries per story.
- Stage 3 dispatches; workers `SendMessage` back to the lead.
- Stage 6 `TeamDelete` for cleanup.

When NOT available (fallback):
- Workers write to `.specs/<slug>/prd.json` directly to mark `passes: true`.
- The lead polls the file via Read between waves.
- No team registration; workers are stateless one-shot Task calls.

## Parallelism Budget
`--max-parallel=N` (default 5) caps the number of concurrent `executor` calls per Task batch. Higher = faster but more expensive. Lower = serialized waves but predictable cost. The lead should batch Tasks to fit under the cap; if a wave has more stories than the cap, split the wave into sub-batches (sequential within a wave, parallel within a sub-batch).

## Distinguishing team vs ralph
- Use `team` when ≥ 3 stories can run truly independently (different files, different layers, no ordering).
- Use `ralph` when the work is a chain: each story depends on the previous, or all stories touch a small shared module.
- A mixed task may need both: `ralplan` decomposes; `team` runs the parallel parts; the lead falls back to `ralph` for the serial tail.
</Advanced>
