# dev-tools — Internal Spec

Internal contracts for the **artifact lifecycle** that every orchestration skill in this plugin shares: where files live, what metadata they carry, when they expire, and how the validator enforces all of it.

For the **user-facing tour** (install, commands, lifecycle diagram, settings), see [README.md](./README.md).

---

## Contents

- [Storage layout](#storage-layout)
- [Artifact hand-off descriptor schema](#artifact-hand-off-descriptor-schema)
- [Descriptor validation lanes](#descriptor-validation-lanes)
- [Retention & cleanup](#retention--cleanup)
- [Deployment assumption](#deployment-assumption)
- [Smoke test log](#smoke-test-log)

---

## Storage layout

Every slug owns a single directory under `.specs/`. All orchestration skills write into a fixed sub-layout:

```
.specs/<slug>/
├── spec.md              # deep-interview output       (descriptor frontmatter; retention=permanent)
├── plan.md              # ralplan output              (descriptor frontmatter; retention=permanent)
├── prd.json             # ralph / team internal       (_descriptor top-level key; retention=permanent)
├── progress.txt         # ralph trace log             (no descriptor; kind=trace)
├── state/               # control plane               (autopilot.json, ralph.json, team.json, events-meta.json)
├── artifacts/ask/       # advisor output files        (<agent>-<ISO8601>.md, retention=session)
├── notepads/            # ralph cross-iteration mem.  (learnings.md, decisions.md, issues.md, problems.md)
└── events.jsonl         # team mode only              (append-only event log)
```

Stage-specific files written at the end of a run:

- `team-final.md` — `team` Stage 5 parallel execution summary
- `autopilot-validation.md` — `autopilot` Phase 5 consolidated 6-advisor verdicts

Existing consumers of `spec.md`, `plan.md`, and `prd.json` continue to work because descriptor metadata is **non-intrusive**: YAML frontmatter is harmlessly ignored by standard markdown parsers, and the JSON `_descriptor` key is a top-level sibling that does not collide with other fields.

---

## Artifact hand-off descriptor schema

Every hand-off artifact written by `deep-interview`, `ralplan`, `ralph`, `team`, `autopilot`, or `code-review` carries a **9-field descriptor**. The location depends on file type:

- `.md` files (`spec.md`, `plan.md`, `team-*.md`, `notepads/*.md`, `artifacts/ask/*.md`) — YAML frontmatter between the leading `---` markers.
- `.json` files (`prd.json`, `state/*.json`) — reserved top-level `_descriptor` key.

### Required fields

| Field         | Type            | Example                         | Notes |
|---------------|-----------------|---------------------------------|-------|
| `kind`        | enum            | `spec`                          | `spec` · `plan` · `prd` · `advisor` · `notepad` · `state` · `handoff` · `trace` |
| `path`        | string          | `.specs/<slug>/spec.md`         | Absolute or cwd-relative. |
| `contentHash` | string          | `sha256:abc123...`              | SHA-256 of the content **excluding** the descriptor block. |
| `createdAt`   | ISO 8601        | `2026-05-23T11:30:00Z`          | UTC. |
| `producer`    | string          | `deep-interview`                | Skill or agent name. |
| `sizeBytes`   | integer         | `12345`                         | Byte length of the artifact content. |
| `retention`   | enum            | `permanent`                     | `session` · `day` · `permanent` |
| `expiresAt`   | ISO 8601 \| null | `2026-05-24T11:30:00Z`          | `null` when `retention = permanent`. |
| `status`      | enum            | `PASSED`                        | `pending` · `approved` · `complete` · `failed` · `cancelled` · `PASSED` · `EARLY_EXIT` · `HARD_CAP` |

### `.md` example (YAML frontmatter)

```yaml
---
kind: spec
path: .specs/<slug>/spec.md
contentHash: sha256:abc123...
createdAt: 2026-05-23T11:30:00Z
producer: deep-interview
sizeBytes: 12345
retention: permanent
expiresAt: null
status: PASSED
---

# Deep Interview Spec: ...
```

### `.json` example (`_descriptor` key)

```json
{
  "_descriptor": {
    "kind": "prd",
    "path": ".specs/<slug>/prd.json",
    "contentHash": "sha256:abc123...",
    "createdAt": "2026-05-23T11:30:00Z",
    "producer": "ralph",
    "sizeBytes": 12345,
    "retention": "permanent",
    "expiresAt": null,
    "status": "pending"
  },
  "stories": [ ... ]
}
```

---

## Descriptor validation lanes

The descriptor lane lives in the marketplace validator (`scripts/validate.sh`):

```bash
bash scripts/validate.sh --descriptors                   # incremental (git merge-base HEAD origin/main; fallback HEAD~1)
bash scripts/validate.sh --descriptors --all             # full .specs/ traversal
bash scripts/validate.sh --descriptors --target=<path>   # single-file check
bash scripts/validate.sh --descriptors --help            # lane usage
```

The default lane (no flag) runs the marketplace structure checks unchanged. The descriptor lane is opt-in so existing CI flows don't break.

### Legacy artifact exemption

`.specs/<slug>/spec.md`, `plan.md`, `prd.json` files that predate the descriptor schema (introduced 2026-05-23) may be missing one or more of `contentHash`, `sizeBytes`, `expiresAt`. The `--descriptors --all` lane will flag these as failures; consumer skills handle them gracefully via a descriptor parser that returns `null` instead of erroring (AC-8 of the hand-off plan).

For CI, prefer the default `--descriptors` (incremental) lane, which only checks files changed in the current diff — legacy files are not re-validated unless modified.

---

## Retention & cleanup

Three retention classes drive the cleanup script (`plugins/dev-tools/scripts/cleanup.sh`, invoked at runtime as `bash "${CLAUDE_PLUGIN_ROOT}/scripts/cleanup.sh"`):

| Retention | Used for | Cleanup trigger |
|-----------|----------|-----------------|
| `session` | Advisor findings in `artifacts/ask/`, ephemeral handoffs | End of session or `expiresAt` |
| `day` | Daily QA / validation summaries | `expiresAt` (24h after `createdAt`) |
| `permanent` | `spec.md`, `plan.md`, `prd.json`, notepads | Never auto-purged |

Cleanup is opt-in and idempotent — re-running it after partial deletion is safe. Permanent artifacts are never touched even when `expiresAt` is present (defensive: `retention=permanent` short-circuits the check).

---

## Deployment assumption

This plugin assumes a **single-host filesystem** (macOS or Linux). NFS deployment is **not supported** for `team` mode locking: `mkdir`-based atomicity is not guaranteed across NFS clients, which can break the parallel-wave coordination in `team-exec`.

---

## Smoke test log

| Date       | Slug                          | Note |
|------------|-------------------------------|------|
| 2026-05-23 | agent-file-handoff-strategy   | Initial introduction of descriptor schema + storage layout + cleanup lifecycle (US-1). |
