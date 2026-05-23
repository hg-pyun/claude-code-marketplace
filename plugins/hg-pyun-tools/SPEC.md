# hg-pyun-tools SPEC

## Artifact Hand-off Descriptor Schema (OMC parity)

Every hand-off artifact written by `deep-interview`, `ralplan`, `ralph`, `team`, `autopilot`, or `code-review` carries a **descriptor** with these 9 fields. Location depends on file type:

- `.md` files (spec.md, plan.md, team-*.md, notepads/*.md, artifacts/ask/*.md): YAML frontmatter between the leading `---` markers.
- `.json` files (prd.json, state/*.json): reserved top-level key `_descriptor`.

### Required fields

| Field         | Type                  | Example                            | Notes                                                |
|---------------|-----------------------|------------------------------------|------------------------------------------------------|
| `kind`        | enum                  | `spec`                             | One of: `spec`, `plan`, `prd`, `advisor`, `notepad`, `state`, `handoff`, `trace` |
| `path`        | string                | `.specs/<slug>/spec.md`            | Absolute or cwd-relative                             |
| `contentHash` | string                | `sha256:abc123...`                 | SHA-256 of the content excluding the descriptor block |
| `createdAt`   | ISO8601               | `2026-05-23T11:30:00Z`             | UTC                                                  |
| `producer`    | string                | `deep-interview` or `architect`    | Skill or agent name; format is consistent            |
| `sizeBytes`   | integer               | `12345`                            | Byte length of the artifact content                  |
| `retention`   | enum                  | `permanent`                        | One of: `session`, `day`, `permanent`                |
| `expiresAt`   | ISO8601 or null       | `2026-05-24T11:30:00Z` or `null`   | `null` when `retention` is `permanent`               |
| `status`      | enum                  | `PASSED`                           | One of: `pending`, `approved`, `complete`, `failed`, `cancelled`, `PASSED`, `EARLY_EXIT`, `HARD_CAP` |

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

### Validation

The descriptor lane lives in `scripts/validate.sh`:

```bash
bash scripts/validate.sh --descriptors                     # incremental (git merge-base HEAD origin/main; fallback HEAD~1)
bash scripts/validate.sh --descriptors --all               # full .specs/ traversal
bash scripts/validate.sh --descriptors --target=<path>     # single-file
bash scripts/validate.sh --descriptors --help              # usage
```

The default lane (no flag) runs the marketplace structure checks unchanged.

### Legacy artifact exemption

`.specs/<slug>/spec.md`, `plan.md`, `prd.json` files that predate the descriptor schema introduction (2026-05-23) may be missing one or more of `contentHash`, `sizeBytes`, `expiresAt`. The `--descriptors --all` lane will flag these as failures. AC-8 of the hand-off plan covers their continued usability via graceful read in the consumer skills (descriptor parser returns `null` instead of erroring). For CI, use the default `--descriptors` (incremental) lane, which only checks files changed in the current diff — legacy files are not re-validated unless they are modified.

## Storage Layout Convention

Every spec slug uses a single root directory and four standard sub-locations:

```
.specs/<slug>/
├── spec.md              # deep-interview output (descriptor frontmatter; retention permanent)
├── plan.md              # ralplan output (descriptor frontmatter; retention permanent)
├── prd.json             # ralph/team internal (_descriptor key; retention permanent)
├── progress.txt         # ralph trace log (no descriptor; trace kind)
├── state/               # control plane (autopilot.json, ralph.json, team.json, events-meta.json)
├── artifacts/ask/       # advisor output files: <agent>-<ISO8601>.md (retention session)
├── notepads/            # ralph cross-iteration memory: learnings/decisions/issues/problems.md
└── events.jsonl         # team mode only: append-only event log
```

Existing readers of `spec.md` / `plan.md` / `prd.json` continue to work — descriptor frontmatter is harmlessly ignored by standard markdown parsers, and the JSON `_descriptor` key is a top-level sibling that does not collide with other story or state fields.

## Deployment Assumption

This plugin assumes a single-host filesystem (macOS / Linux). NFS deployment is **not supported** for `team` mode locking: `mkdir`-based atomicity is not guaranteed across NFS clients.

## Smoke Test Log

| Date       | Slug                          | Note                                                                                  |
|------------|-------------------------------|---------------------------------------------------------------------------------------|
| 2026-05-23 | agent-file-handoff-strategy   | Initial introduction of descriptor schema + storage layout + cleanup lifecycle (US-1) |
