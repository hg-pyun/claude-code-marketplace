# dev-tools — Plugin Working Guide

Unified toolkit: 9 specialist agents + orchestration / review / debugging / git+GitHub skills. Repo-wide governance (versioning, author field, 9-section, language) lives in the root [CLAUDE.md](../../CLAUDE.md); this file is the dev-tools working guide.

## Structure
```
plugins/dev-tools/
├── .claude-plugin/plugin.json
├── agents/      # reviewer explorer architect critic executor test-engineer
│                # doc-writer performance-analyst security-auditor
├── commands/    # git-rebase-stack
├── skills/      # autopilot deep-interview ralplan ralph team
│                # code-review curl-debug git-commit github-pr
├── scripts/     # cleanup.sh (.specs retention purge), test-cleanup.sh
├── README.md    # user-facing tour
└── CLAUDE.md    # this guide
```

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

## validate.sh troubleshooting
| Symptom | Cause / fix |
|---------|-------------|
| 9-section check fails | a SKILL.md / command md is missing one of the nine XML sections. README & CLAUDE.md are exempt. |
| version sync failure | plugin.json and the marketplace.json entry disagree, or the format isn't `YYYY.MM.DD[.N]`. |
| descriptors lane fails on legacy `.specs` file | use the default incremental `--descriptors` lane; legacy files aren't re-validated unless modified. |

## Artifact hand-off descriptor schema
> **Human mirror.** The *enforced* field list is `DESC_REQUIRED_FIELDS` in `scripts/validate.sh` (and the enums there) — that script is the machine source of truth. This section is its human-readable mirror; keep the two in sync.
> **Do not rename this heading.** `skills/team`, `skills/deep-interview`, `skills/ralplan`, and `skills/ralph` anchor to `#artifact-hand-off-descriptor-schema`.

Every hand-off artifact written by `deep-interview`, `ralplan`, `ralph`, `team`, `autopilot`, or `code-review` carries a **9-field descriptor**. Location by file type:
- `.md` (`spec.md`, `plan.md`, `team-*.md`, `notepads/*.md`, `artifacts/ask/*.md`) — YAML frontmatter between leading `---` markers.
- `.json` (`prd.json`, `state/*.json`) — reserved top-level `_descriptor` key.

| Field | Type | Notes |
|-------|------|-------|
| `kind` | enum | `spec`·`plan`·`prd`·`advisor`·`notepad`·`state`·`handoff`·`trace` |
| `path` | string | absolute or cwd-relative |
| `contentHash` | string | `sha256:…` of content **excluding** the descriptor block |
| `createdAt` | ISO 8601 | UTC |
| `producer` | string | skill or agent name |
| `sizeBytes` | integer | byte length of artifact content |
| `retention` | enum | `session`·`day`·`permanent` |
| `expiresAt` | ISO 8601 \| null | `null` when `retention=permanent` |
| `status` | enum | `pending`·`approved`·`complete`·`failed`·`cancelled`·`PASSED`·`EARLY_EXIT`·`HARD_CAP` |

**Storage** — each slug owns `.specs/<slug>/`: `spec.md` (deep-interview), `plan.md` (ralplan), `prd.json` (ralph/team), `progress.txt` (trace), `state/`, `artifacts/ask/` (advisor, session), `notepads/` (ralph memory), `events.jsonl` (team). Stage summaries: `team-final.md`, `autopilot-validation.md`.

**Legacy exemption** — pre-2026-05-23 `spec.md`/`plan.md`/`prd.json` may lack `contentHash`/`sizeBytes`/`expiresAt`; the default incremental `--descriptors` lane skips unmodified files, and consumer skills parse missing fields as `null` rather than erroring.

## Retention & cleanup
`plugins/dev-tools/scripts/cleanup.sh` (invoked as `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.sh"`) keys off the `retention` field:

| Retention | For | Purge trigger |
|-----------|-----|---------------|
| `session` | advisor findings, ephemeral handoffs | end of session / `expiresAt` |
| `day` | daily QA / validation summaries | `expiresAt` (24h) |
| `permanent` | `spec.md`, `plan.md`, `prd.json`, notepads | never (defensive short-circuit) |

Cleanup is opt-in and idempotent.

## Deployment assumption
This plugin assumes a **single-host filesystem** (macOS or Linux). NFS is **not supported** for `team` mode locking: `mkdir`-based atomicity is not guaranteed across NFS clients, which can break `team-exec` parallel-wave coordination.
