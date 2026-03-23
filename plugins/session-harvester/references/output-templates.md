# Output Templates

Templates for generating skills, subagents, and hooks from detected patterns.
Used as fallback when craft:skill-creator is not available.

## Skill Template

```markdown
---
name: {{skill-name}}
description: >
  {{description of what this skill does}}.
  TRIGGER when: {{trigger conditions}}.
  DO NOT TRIGGER when: {{negative trigger conditions}}.
---

# {{Skill Title}}

## Overview
{{Brief description of the automated workflow.}}

## Arguments
{{List any arguments the skill accepts, parsed from the user prompt.}}

## Procedure

### Step 1: {{First action}}
{{Instructions for the first step in the workflow.}}

### Step 2: {{Second action}}
{{Instructions for the second step.}}

### Step N: {{Final action}}
{{Instructions for the final step.}}
```

### Variable Substitution Guide

When converting a detected pattern to a skill, replace variable parts with argument references:

| Pattern Variable | Skill Representation |
|-----------------|---------------------|
| File path | Parse from user prompt or accept as argument |
| Search term | Extract from user prompt context |
| Function/class name | Extract from user prompt context |
| Test command | Use project-specific command from package.json or Makefile |

## Subagent Template

```markdown
# {{Agent Name}}

## Purpose
{{Description of what this agent does autonomously.}}

## Available Tools
{{List of tools the agent needs access to.}}

## Workflow

1. {{Step 1 with decision logic}}
2. {{Step 2 — may branch based on results}}
3. {{Retry logic if applicable}}
4. {{Final output or report}}

## Success Criteria
{{How to determine the agent completed successfully.}}

## Error Handling
{{What to do when steps fail — retry, escalate to user, or abort.}}
```

## Hook Template

```bash
#!/bin/sh
# {{Hook Name}} — {{brief description}}
# Triggered by: {{event type}} (e.g., PostToolUse on Edit)

set -e

INPUT="$(cat)"
EVENT="$(printf '%s' "${INPUT}" | jq -r '.hook_event_name // empty')"
TOOL="$(printf '%s' "${INPUT}" | jq -r '.tool_name // empty')"

# --- Filter: only act on specific tool/event ---
case "${TOOL}" in
  {{TargetTool}})
    {{action to perform, e.g., run linter, type checker}}
    ;;
  *)
    exit 0
    ;;
esac
```

### Hook Registration

When generating a hook, also provide the settings.json snippet the user needs to add:

```json
{
  "hooks": {
    "{{EventName}}": [
      {
        "matcher": "{{tool name or empty for all}}",
        "hooks": [
          {
            "type": "command",
            "command": "{{path to hook script}}"
          }
        ]
      }
    ]
  }
}
```
