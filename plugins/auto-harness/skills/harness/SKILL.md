---
name: harness
description: >-
  GAN-inspired Planner → Generator → Evaluator harness for autonomous fullstack app development.
  Separates code generation from evaluation with real browser testing via MCP (Playwright/Chrome DevTools).
  TRIGGER when: user wants to build a fullstack app from scratch, scaffold a new project with iterative QA,
  create a complete application autonomously, or add significant features to an existing project using
  a structured harness workflow (e.g., "풀스택 앱 만들어줘", "앱 처음부터 만들어", "하네스로 개발해줘",
  "build me a fullstack app", "create an app from scratch", "forge this app", "/harness").
  DO NOT TRIGGER when: user wants a simple code change, single file edit, quick bug fix, or is asking
  about harness concepts without intent to build.
---

# Auto-Harness: Autonomous Fullstack Development

A 3-agent harness system inspired by [Anthropic's harness design philosophy](https://www.anthropic.com/engineering/harness-design-long-running-apps).
Separates generation from evaluation to iteratively build high-quality fullstack applications.

## Core Philosophy

1. **Self-evaluation is unreliable** — A separate Evaluator with a skeptic persona provides honest feedback
2. **Sprint Contracts** — Generator and Evaluator agree on "done" conditions before implementation
3. **Context preservation** — Structured handoff artifacts maintain coherence across long sessions
4. **Scaffolding expires** — Complexity auto-adjusts; simple tasks skip unnecessary harness layers
5. **External feedback drives improvement** — Concrete evaluator critiques beat self-assessment

---

## Orchestration Flow

```
User Input → Planner → [Sprint 1] → Generator → Evaluator → (pass?) → [Sprint 2] → ...
                                         ↓ (fail, max 5 retries)
                                    Generator (retry with feedback)
                                         ↓
                                    Evaluator (re-evaluate)
                                         ↓ (max exceeded)
                                    User intervention
```

### Step 0: Receive User Input

The user provides a natural language description of what they want to build. This can be as brief as one sentence.

Arguments: `$ARGUMENTS` — Optional. The user's project description. If empty, ask via AskUserQuestion.

### Step 1: Run Planner

Spawn a **Planner subagent** using `agents/planner.md`.

**Input**: User's description + existing project context (if any)
**Output**: `.harness/plan.md` containing:
- Product spec and architecture
- Sprint breakdown
- Dynamic evaluation criteria (weighted toward model-weak areas)
- Complexity assessment (lightweight / medium / full harness)
- Dev server run command

The Planner will use AskUserQuestion to fill gaps in the user's description. It must NOT over-specify implementation details — that's the Generator's job.

**Complexity gate**: If the Planner determines the task is lightweight (single sprint, few files), skip to a simplified flow: Generator → single Evaluator pass → done.

### Step 2: Sprint Loop

For each sprint defined in `plan.md`:

#### 2a. Generator Phase

Spawn a **Generator subagent** using `agents/generator.md`.

**Input**: `.harness/plan.md` + current sprint scope + previous handoff (if any)
**Output**:
- `.harness/sprint-N/contract.md` — Sprint contract with done conditions
- Implemented code
- Dev server running in background

The Generator:
1. Reads the plan and any previous handoff artifact
2. Writes a sprint contract defining done conditions and verification methods
3. Implements the sprint's features
4. Starts the dev server (using the run command from plan.md)
5. Self-checks before handing off to Evaluator

#### 2b. Evaluator Phase

Spawn an **Evaluator subagent** using `agents/evaluator.md`.

**Input**: `.harness/sprint-N/contract.md` + `.harness/plan.md` (evaluation criteria) + dev server URL
**Output**: `.harness/sprint-N/evaluation.md` containing:
- Score (X/10)
- Per-feature PASS/FAIL with evidence
- Screenshot visual assessment
- Recommendation: `refine` or `pivot`
- Specific feedback for Generator

The Evaluator:
1. Reads the sprint contract's done conditions
2. Uses MCP tools (Playwright/Chrome DevTools) to interact with the running app
3. Takes screenshots for visual evaluation
4. Tests each done condition with real browser interactions
5. Grades against the plan's evaluation criteria (with weighted scoring)
6. Writes structured feedback to evaluation.md

#### 2c. Iteration Decision

Read `.harness/sprint-N/evaluation.md`:

- **Score >= threshold (7/10)**: Sprint passes. Generate handoff artifact → next sprint.
- **Score < threshold, iterations < 5**: Feed evaluation.md back to Generator for retry.
  - If 2 consecutive score drops detected → trigger early termination, ask user.
- **Score < threshold, iterations >= 5**: Ask user via AskUserQuestion whether to continue, skip, or abort.

#### 2d. Handoff

After a sprint passes, generate `.harness/sprint-N/handoff.md`:
- Completed features (verified)
- Key technical decisions made
- Evaluation summary (score + key feedback)
- Changed files list
- Code structure overview
- Next sprint scope

### Step 3: Completion

After all sprints complete:
1. Ensure dev server is stopped
2. **Delete `.harness/` directory** (auto-cleanup)
3. Present final summary to user: what was built, key decisions, any remaining notes

---

## .harness/ Directory Structure

```
.harness/
├── plan.md                      # Product spec, architecture, sprints, eval criteria
├── config.json                  # Runtime config (max_iterations, complexity_mode)
├── sprint-1/
│   ├── contract.md              # Done conditions, verification methods
│   ├── evaluation.md            # Evaluator feedback, scores, screenshots
│   └── handoff.md               # Context handoff to next sprint
├── sprint-2/
│   └── ...
└── ...
```

---

## Agent Files

All agent instructions are in `agents/`:

- `planner.md` — Expands user input into product spec + architecture + sprint plan
- `generator.md` — Implements code sprint-by-sprint with contract negotiation
- `evaluator.md` — Tests running app via MCP with skeptic persona

---

## Key Design Decisions

### Evaluator Tuning (Critical)
Claude defaults to lenient self-evaluation. We combat this with:
1. **Skeptic persona** — Evaluator is instructed to be a "ruthlessly honest QA expert"
2. **Evidence-required testing** — Every PASS claim must have a corresponding MCP tool call as proof
3. **Weighted criteria** — Criteria where the model is naturally weak get higher weight

### Tech Stack Agnostic
The Planner autonomously selects the best tech stack for each project. No hardcoded defaults.
For existing projects, it detects and follows the existing stack.

### Existing Project Support
When run in a directory with existing code, the Planner analyzes the codebase first and plans features that integrate with what's already there.
