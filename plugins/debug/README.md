# debug

API debugging tool for Claude Code. Runs a user-provided cURL, then reverse-traces the response back to the responsible code in the codebase. Produces a root-cause report with file:line evidence and concrete fix suggestions — does not apply fixes.

## Usage

| Trigger | Skill | What it does |
|---------|-------|--------------|
| `/curl-debug <cURL>`, "이 curl 500 에러 나는데 봐줘", "this curl returns 500, help me debug" | `curl-debug` | Executes the cURL, extracts the strongest available signal (stack trace > error message > error code > URL path > body fields > body structure), traces back to source, halts at What/Where/Why, and reports. |

Example: `/curl-debug curl https://httpbin.org/status/500`

## Signal priority (how tracing routes)

| Priority | Signal | Tracing entry point |
|----------|--------|---------------------|
| 1 | Stack trace | Read the file:line directly |
| 2 | Error message | Grep the string in codebase |
| 3 | Error code | Grep for constant/enum definition |
| 4 | URL path | Grep route definition, follow handler chain |
| 5 | Request body fields | Grep schema/type definitions |
| 6 | Response body structure | Grep DTO/serialization |

Plus short-circuit handlers for 401/403, 404, 406/415, and 2xx-with-unexpected-data.

## Settings

None. This plugin does not expose a `settings.language` field — debug reports are written in the conversation language and do not produce ticket-style artifacts.

## `core` dependency (optional)

When `curl-debug` identifies a non-trivial proposed fix, it can optionally delegate severity-rated review to the `core` plugin's `reviewer` agent via:

```
Task(subagent_type="core:reviewer", prompt="<proposed fix>")
```

If `core` is not installed, the skill skips delegation and appends `"core plugin not installed; review delegated locally to the calling session"` to its report. The bug-trace itself works without `core`.

## SPEC

Full design and signal-priority rationale: see [`SPEC.md`](SPEC.md).
