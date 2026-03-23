---
name: harvest
description: >
  Analyze repeated workflow patterns from previous sessions and generate reusable
  skills, subagents, or hooks. TRIGGER when: user asks to review session patterns,
  create skills from repeated work, harvest workflows, or automate repetitive tasks
  (harvest, 수확, 패턴 분석, 반복 작업 스킬화, 워크플로우 자동화, 세션 분석).
  DO NOT TRIGGER when: user is creating a skill from scratch without session data,
  or asking about general skill concepts.
---

# Session Harvest Skill

Analyze accumulated session patterns and help the user convert repeated workflows
into reusable skills, subagents, or hooks.

## Data Sources

Two files contain the analysis data:

1. **`$CLAUDE_PLUGIN_DATA/pending_analysis.json`** — Structural analysis from the last session
   - `sequences`: tool call sequence frequencies (e.g., `G-R-E-B` = Grep→Read→Edit→Bash)
   - `file_patterns`: glob patterns of files accessed
   - `retry_loops`: tools that failed and were retried
   - `sample_prompts`: user prompts from the session

2. **`$CLAUDE_PLUGIN_DATA/patterns.jsonl`** — Cumulative pattern summaries across sessions
   - Each line is a JSON object with `id`, `sequence`, `intent`, `count`, `suggested`
   - `suggested: false` means the pattern hasn't been shown to the user yet

Read both files at the start of every invocation.

## Procedure

### Step 1: Load and Analyze Data

1. Read `$CLAUDE_PLUGIN_DATA/pending_analysis.json` for the latest session data.
2. Read `$CLAUDE_PLUGIN_DATA/patterns.jsonl` for cumulative patterns.
3. Combine and perform semantic analysis:
   - **Cluster similar prompts**: Group user prompts by intent (e.g., "add API endpoint", "fix test failure"). Use the sample prompts to infer what the user was trying to accomplish.
   - **Merge similar sequences**: Sequences like `G-R-E-B` and `G-R-E-E-B` that serve the same intent should be grouped together.
   - **Identify variables**: For each pattern, determine which parts are fixed (the workflow structure) and which are variable (file paths, function names, search terms).
   - **Detect file scope**: Combine file_patterns with the workflow to understand what kind of files this workflow targets.
   - **Check for retry loops**: Patterns with retry_loops suggest error-handling workflows that might benefit from a subagent.

### Step 2: Classify and Recommend

For each detected pattern, recommend an output type:

| Criteria | Recommendation |
|----------|---------------|
| Linear sequence, 3 or fewer tool steps, single prompt template | **Skill** |
| Branching/retry logic, multi-file work, 5+ steps | **Subagent** |
| Event-driven pattern (e.g., always runs Bash after Edit) | **Hook** |

### Step 3: Check for Duplicates

Scan existing skills in these locations:
- `.claude/skills/` (project-local)
- `~/.claude/skills/` (global)
- Any installed plugin skill directories

For each detected pattern, check if a similar skill already exists. If so, suggest **merging** the new pattern into the existing skill rather than creating a new one.

### Step 4: Present Report

Display a report in this format:

```
Session Harvester Report

발견된 반복 패턴: N개

1. [Intent description]
   반복: X회 (Y개 세션 누적) | 구조: Tool1 -> Tool2 -> Tool3
   변수: [list of parameterized variables]
   대상: [file glob pattern]
   추천: Skill/Subagent/Hook | 유사 기존 스킬: [name or 없음]

2. ...
```

Use the AskUserQuestion tool to let the user select which patterns to convert.
Offer options: individual pattern numbers, "all", or "skip".
Also ask the user for each selected pattern:
- Confirm or override the recommended type (Skill/Subagent/Hook)
- Choose save location: project-local (`.claude/`) or global (`~/.claude/`)

### Step 5: Generate via craft:skill-creator

For each selected pattern, delegate to `craft:skill-creator` with this context:

```
I need to create a [Skill/Subagent/Hook] based on a detected workflow pattern.

Workflow:
- Intent: [what the user was trying to do]
- Tool sequence: [e.g., Grep → Read → Edit → Bash]
- Variables: [parameterized parts]
- Target files: [glob pattern]
- Sample prompts that triggered this workflow:
  1. [prompt 1]
  2. [prompt 2]

Please create a [skill/subagent/hook] that automates this workflow.
Save to: [chosen path]
```

If craft:skill-creator is not available (craft plugin not installed):
1. Generate a basic SKILL.md using the template from `references/output-templates.md`
2. Write it to the chosen location
3. Display a message recommending the craft plugin for eval and optimization

### Step 6: Update Pattern Status

After generation is complete, update the patterns in `$CLAUDE_PLUGIN_DATA/patterns.jsonl`:
- Set `suggested: true` for all patterns that were presented to the user
- Update the `intent` field with the LLM-inferred intent description

To update patterns.jsonl, read the file, modify the relevant entries, and write back.

## Settings Reference

- `$CLAUDE_PLUGIN_DATA`: Plugin persistent data directory
- Settings from `plugin.json`:
  - `min_repeat_threshold`: Minimum repetitions to be considered a pattern (default: 2)
  - `max_suggestions`: Maximum patterns to show per report (default: 5)
  - `default_save_location`: `"ask"`, `"local"`, or `"global"`

## Edge Cases

- **No patterns found**: If both data sources are empty or all patterns are already `suggested: true`, inform the user that no new patterns were detected and suggest they continue working normally.
- **Only cumulative patterns**: If pending_analysis.json is missing but patterns.jsonl has unseen entries, analyze and present those.
- **Merge conflicts**: If a user selects merging with an existing skill, read the existing SKILL.md first, then present a proposed diff before applying.
