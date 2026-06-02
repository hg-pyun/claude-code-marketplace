# dev-tools — Plugin Maintenance Guide

Unified toolkit: 16 specialist agents (4 lanes: Build/Analysis · Review · Domain · Coordination) + orchestration / review / debugging / git+GitHub skills. Repo-wide governance (versioning, author field, 9-section, language) lives in the root [CLAUDE.md](../../CLAUDE.md); this file covers dev-tools-specific maintenance only.

## Structure
```
plugins/dev-tools/
├── .claude-plugin/plugin.json
├── agents/      # 16 agents across 4 lanes — see agents/*.md for roster and role boundaries
├── commands/    # git-rebase-stack
├── skills/      # autopilot deep-interview interview ralplan ralph team
│                # code-review curl-debug git-commit github-pr install-statusline
├── scripts/     # cleanup.sh (.dt-handoff retention purge), test-cleanup.sh
├── README.md    # user-facing tour
└── CLAUDE.md    # this guide
```

Local hand-off artifact workspace: `.dt-handoff/<slug>/` (gitignored; spec/plan/prd/state/notepads/…).

## Agent / skill / command boundary
- **agent** (`agents/*.md`) — a delegated role invoked via Task (reviewer, executor, …). No 9-section; output uses the calling-session language.
- **skill** (`skills/<name>/SKILL.md`) — a multi-step workflow invoked as `/<name>` or by trigger phrase. MUST follow the 9-section house style.
- **command** (`commands/<name>.md`) — a single prompt-driven action invoked as `/<name>`. MUST follow the 9-section house style.
- Rule of thumb: reusable *role* → agent; multi-phase *workflow* → skill; one focused *action* → command.

## Task(subagent_type) convention
Skills/commands call bundled agents by **bare name** — no plugin prefix, because everything ships in `dev-tools`:
```
Task(subagent_type="reviewer", prompt="…")
Task(subagent_type="executor", prompt="…")
```
(When dispatching agents from the *interactive harness* Task/Agent tool, the runtime may require the `dev-tools:` prefix, e.g. `dev-tools:architect`; inside skill bodies the bare name is canonical.)

## Adding a skill or command
1. Author `skills/<name>/SKILL.md` (or `commands/<name>.md`) in the **9-section XML house style**.
2. If it emits a language-dependent artifact, consume `$LANGUAGE` and add a `<Settings_Reference>` block.
3. Bump `version` in **both** `plugins/dev-tools/.claude-plugin/plugin.json` and the dev-tools entry in `.claude-plugin/marketplace.json` (same value) — `skills/` and `commands/` are source files.
4. `bash scripts/validate.sh` — exit `0` is the gate.

## Hand-off descriptor + `@handoff` + `verdict` contract
See the `scripts/validate.sh` header (machine source of truth + human mirror).

## Retention & cleanup
See `plugins/dev-tools/scripts/cleanup.sh` (invoked as `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.sh"`).

## validate.sh troubleshooting
| Symptom | Cause / fix |
|---------|-------------|
| 9-section check fails | a SKILL.md / command md is missing one of the nine XML sections. README, CLAUDE.md & agents are exempt. |
| version sync failure | plugin.json and the marketplace.json entry disagree, or the format is not `YYYY.MM.DD[.N]`. |
| descriptors lane fails on legacy `.dt-handoff` file | use the default incremental `--descriptors` lane; legacy files are not re-validated unless modified. |

## Deployment assumption
This plugin assumes a **single-host filesystem** (macOS or Linux). NFS is **not supported** for `team` mode locking: `mkdir`-based atomicity is not guaranteed across NFS clients, which can break `team-exec` parallel-wave coordination.
