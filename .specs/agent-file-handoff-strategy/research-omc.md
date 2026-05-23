---
name: research-omc
description: Survey of yeachan-heo/oh-my-claudecode patterns for inter-agent file hand-off (Phase 1 context)
producer: autopilot-phase0-research
createdAt: 2026-05-23
---

# OMC Hand-off Pattern Survey

Source: https://github.com/yeachan-heo/oh-my-claudecode
Method: WebFetch on raw.githubusercontent.com (gh unauthenticated)
Files surveyed: docs/ARCHITECTURE.md, docs/REFERENCE.md, skills/autopilot/SKILL.md, skills/ralph/SKILL.md, skills/team/SKILL.md, skills/deep-interview/SKILL.md

## 1. Directory conventions (control-plane vs data-plane)

- `.omc/state/` (control plane)
  - `autopilot-state.json`, `ralph-state.json`, `ultrawork-state.json`, `ultraqa-state.json`
  - `sessions/{sessionId}/<mode>.json` — **session overlay wins over flat files**
  - `team/<team-name>/events.jsonl` + `workers/<name>/status.json`
- `.omc/specs/<slug>.md` — durable goal artifacts (deep-interview output)
- `.omc/plans/<slug>.md` — approved plans (`ralplan-*.md`, `consensus-*.md`, `autopilot-impl.md`)
- `.omc/autopilot/spec.md` — Phase 0 expansion output (skill-scoped)
- `.omc/notepads/<plan-name>/` — fixed-name files: `learnings.md`, `decisions.md`, `issues.md`, `problems.md`
- `.omc/notepad.md`, `.omc/project-memory.json` — persistent cross-session memory
- `.omc/prompts/`, `.omc/research/`, `.omc/logs/`, `.omc/artifacts/ask/`

Two roots supported: project-local `.omc/` (default) or global `$OMC_STATE_DIR/{project-id}/` (project-id = git-remote-URL hash).

## 2. File naming conventions

- Slug-scoped: `<role>/<slug>.md` (kebab-case, derived from idea/title, not from UUID)
- Mode-scoped: `<mode>-state.json` (one per orchestration skill)
- Session-overlay: `.omc/state/sessions/<session-id>/<mode>.json`
- Plan-scoped: `.omc/notepads/<plan-name>/{learnings,decisions,issues,problems}.md`
- Advisor artifacts: `.omc/artifacts/ask/<provider>-<slug>-<timestamp>.md`
- Numeric task IDs: `tasks/<team>/1.json`, `2.json`

## 3. Hand-off contracts (schemas)

### Artifact descriptor
Used in queue/status records instead of inline payloads when payload exceeds threshold:
```json
{
  "kind": "plan|prompt|result|trace",
  "path": ".omc/...",
  "contentHash": "sha256:...",
  "createdAt": "ISO8601",
  "producer": "agent-or-skill-name",
  "sizeBytes": 0,
  "retention": "session|day|permanent",
  "expiresAt": "ISO8601"
}
```

### PRD story (`prd.json`)
```json
{
  "id": "US-001",
  "title": "Add flag detection helpers",
  "acceptanceCriteria": ["Legacy --no-prd is stripped", "TS compiles"],
  "passes": false
}
```
Selection rule: "highest-priority with `passes:false`"

### Task envelope (`tasks/<team>/N.json`)
```json
{
  "id": "1",
  "subject": "Fix type errors",
  "activeForm": "Fixing auth type errors",
  "owner": "worker-1",
  "status": "pending|in_progress|completed|failed",
  "blocks": [],
  "blockedBy": ["1"],
  "metadata": { "_internal": false }
}
```

### State write contract
```
state_write(mode, current_phase, state={
  stage_history: "team-plan:T1,team-prd:T2,…"
})
```

### Spec markdown sections (deep-interview)
Required sections: Metadata / Clarity Breakdown / Topology / Goal / Constraints / Non-Goals / Acceptance Criteria / Assumptions Exposed & Resolved / Technical Context / Ontology / Ontology Convergence / Interview Transcript

### Persistence tags
- `<remember>…</remember>` (7-day)
- `<remember priority>…</remember>` (permanent)

## 4. Phase boundaries & "ready" markers

- Explicit status fields: spec.md and plan.md use `pending → approved`; task logs `in-progress → done`; reviews `pending → approved|rejected`
- Stage history string in state.json — comma-separated `phase:taskId` pairs
- Terminal states: `complete`, `failed`, `cancelled`
- Existence-based skip rules: if `.omc/plans/ralplan-*.md` or `consensus-*.md` exists, autopilot skips Phase 0+1; if `.omc/specs/deep-interview-*.md` exists, skips analyst expansion
- Locks: `tasks/<team>/.lock` file lock for concurrent task-file writes
- Fresh-evidence rule: verification evidence must be within 5 minutes; `passes:true` requires re-running checks
- Event log: append-only `events.jsonl` is V2 source of truth instead of polled `done.json`

## 5. Persistent state files

- `.omc/project-memory.json` — notes + directives
- `.omc/notepad.md` — working memo, survives compaction
- `.omc/state/sessions/<sessionId>/<mode>.json` — session-scoped wins over legacy flat files
- Team `events.jsonl` + per-worker `status.json` heartbeats

## 6. Anti-patterns explicitly called out

- OMC integrations should NOT mutate hidden Claude Code goal storage directly — always materialise an OMC artifact instead
- Never paste large payloads inline — use descriptors when over threshold
- Never self-approve in the same active context — separate writer and reviewer passes
- Auto-generated PRDs with generic criteria ("Implementation is complete") must be replaced with task-specific criteria before execution
- Don't treat reviewer approval as a stopping checkpoint ("polite-stop anti-pattern") — continue to deslop + regression in the same turn
- Team shutdown only clears `.omc/state/team/{teamName}` — never sibling teams
- Session-scoped state always wins over legacy flat files

## 7. Current `hg-pyun-tools` state (for gap analysis)

Already adopted (per recent commit `60ef377` and current `CLAUDE.md`):
- `.specs/<slug>/spec.md`, `.specs/<slug>/plan.md`, `.specs/<slug>/prd.json` directory layout
- 9-section SKILL.md house style (XML body)
- `settings.language` + `$LANGUAGE` convention
- `subagent_type` bare-name agent invocation

Not yet adopted (candidate hand-off patterns to design):
- Artifact descriptor schema for large payloads
- Session overlay state files
- Typed status enums on cross-skill artifacts
- Append-only event log for team-mode coordination
- Lock files for concurrent writes
- Fresh-evidence timestamp rule
- Persistent notepad / project-memory for cross-session continuity
- Hand-off contract between agents within a single skill invocation (currently informal via Task prompt)

## 8. Source paths for follow-up

Upstream:
- docs/ARCHITECTURE.md
- docs/REFERENCE.md
- docs/SYNC-SYSTEM.md
- docs/DELEGATION-ENFORCER.md
- skills/autopilot/SKILL.md
- skills/ralph/SKILL.md
- skills/team/SKILL.md
- skills/deep-interview/SKILL.md

Local (current repo):
- /Users/reactiver/my-projects/claude-code-marketplace/CLAUDE.md
- /Users/reactiver/my-projects/claude-code-marketplace/plugins/hg-pyun-tools/agents/
- /Users/reactiver/my-projects/claude-code-marketplace/plugins/hg-pyun-tools/skills/
