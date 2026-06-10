---
name: code-review
description: Severity-rated review of the current diff or a named file. Always delegates to the reviewer agent, and routes security-auditor + doc-writer onto the panel when the diff touches their surface (full panel in slug context), producing CRITICAL/MAJOR/MINOR findings with file:line evidence. TRIGGER when user says "review my changes", "코드 리뷰 해줘", "/code-review", or asks for severity-rated feedback. DO NOT TRIGGER for general code questions or syntax help.
---

<Purpose>
Produce a severity-rated review of the current diff (or a specified file) using the `reviewer` advisor plus diff-routed `security-auditor` and `doc-writer` advisors in parallel. Returns CRITICAL/MAJOR/MINOR findings each anchored to file:line, with a summary count across the dispatched domains.
</Purpose>

<Use_When>
- User asks for code review of staged/unstaged changes
- User says "review my changes", "/code-review", "코드 리뷰 해줘", "이거 리뷰"
- User wants severity-rated feedback rather than free-form impression
- Before opening a PR, when the user wants a self-review pass
</Use_When>

<Do_Not_Use_When>
- User asks a syntax question — answer directly
- User wants explanation of existing code, not review
- User wants to apply fixes, not surface findings — use direct edit
</Do_Not_Use_When>

<Why_This_Exists>
Free-form "looks good" reviews consume time without informing decisions. Severity-rated reviews let the user triage: fix CRITICALs now, batch MAJORs, defer MINORs. This skill is the canonical entrypoint for that triage style in the `dev-tools` plugin. The `reviewer` advisor is always dispatched (review stays a separate pass); `security-auditor` and `doc-writer` join the panel only when the diff actually touches their surface, so small diffs are not taxed with irrelevant advisor passes.
</Why_This_Exists>

<Execution_Policy>
- Always identify the review surface first (diff scope, or named files).
- Always dispatch the `reviewer` agent — review is a separate pass; do NOT inline the review logic.
- Route the other two advisors by what the diff actually touches, using the `git diff --stat` output from Step 1 as the gate:
  - `security-auditor`: dispatch only when the diff touches a security surface (auth/crypto/session code, input handling, serialization, config or secret files) **or** the diff is large (>150 changed lines).
  - `doc-writer`: dispatch only when the diff touches `*.md` files **or** changes a public API signature, option, or config schema.
  - A config-schema change that is also security-sensitive (auth, secrets, permissions config) trips BOTH gates — dispatch `security-auditor` and `doc-writer` together.
  - For every advisor not dispatched, note it in the output as one line: `<agent>: skipped (no <surface> in diff)`.
- **Slug-context exception**: when a slug context is active (hand-off persistence path), always dispatch the full three-advisor panel — no routing gate — so persisted artifacts keep consistent multi-domain coverage.
- When `security-auditor` is on the panel, append to the reviewer's dispatch prompt: "security-auditor is on this panel — skip the Security checklist category and focus on logic/quality/spec-compliance". (`reviewer.md` itself is unchanged — a standalone reviewer invocation runs its full checklist.)
- Output must use the severity bar consistently across invocations.
- **Hand-off persistence (slug context only)**: when a slug context is active (e.g., autopilot invocation or `--slug=<slug>` argument), each advisor's findings MUST also be persisted to `.dt-handoff/<slug>/artifacts/ask/<agent>-<ISO8601>.md` with the descriptor frontmatter (kind=advisor, retention=session, status=complete; schema: `scripts/validate.sh`). For free-standing user invocations without a slug, in-session text output is sufficient and no file is written.
</Execution_Policy>

<Steps>
1. **Identify review surface.** Default: `git diff` (staged + unstaged). User can override with a file path argument. Run `git diff --stat` as well — its file list and changed-line count are the routing-gate input for Step 3. (For named-file mode, apply the same surface heuristics to the file path and content instead.)
2. **Capture the diff or file content.** Use `git diff --no-color` for diff mode; `Read` for named files.
3. **Assemble the advisor panel, then delegate in a single parallel message.** `reviewer` is always on the panel; include `security-auditor` and/or `doc-writer` only when the routing gate in `<Execution_Policy>` selects them (slug context → always full panel). When `security-auditor` is included, append the panel note to the reviewer prompt as shown. When a slug context is active, append the hand-off output directive (see template below) to each prompt so the agent writes a persistent findings file alongside its in-session reply. The example below shows the full panel — drop the entries the gate skipped:
   ```
   [
     Task(subagent_type="reviewer", prompt="Severity-rated review of the diff. Return CRITICAL/MAJOR/MINOR findings with file:line evidence.\n\n<if security-auditor on panel: security-auditor is on this panel — skip the Security checklist category and focus on logic/quality/spec-compliance>\n\n<diff content>\n\n<hand-off directive if slug active>"),
     Task(subagent_type="security-auditor", prompt="Security-focused review of the diff using AuthN/AuthZ/Secret/Crypto/Injection/SAST/Config categories. Return Findings with severity/category/location/evidence/recommendation/confidence. Use `no concerns at this confidence` if zero findings.\n\n<diff content>\n\n<hand-off directive if slug active>"),
     Task(subagent_type="doc-writer", prompt="Do not call Write/Edit during this invocation. Return diff-shaped recommendations only. Documentation review of the diff using Missing/Outdated/Inconsistent/Unclear categories. Return Findings with severity/category/location/evidence/recommendation/confidence.\n\n<diff content>\n\n<hand-off directive if slug active>")
   ]
   ```

   **Hand-off directive template** (append to each Task prompt when slug is active):
   ```
   Also persist your findings to `.dt-handoff/<slug>/artifacts/ask/<agent>-<ISO8601>.md` with this YAML frontmatter at the top:
   ---
   kind: advisor
   path: .dt-handoff/<slug>/artifacts/ask/<agent>-<ISO8601>.md
   contentHash: sha256:<sha256 of the body content below, excluding this frontmatter block>
   createdAt: <ISO8601-now>
   producer: <agent-name>
   sizeBytes: <byte count of the body content below>
   retention: session
   expiresAt: null
   status: complete
   ---
   followed by the same findings body as the in-session reply. The writing agent is responsible for computing `contentHash` (sha256 of the body bytes) and `sizeBytes` (byte length of the body) at write time.
   ```
4. **Consolidate findings.** Merge all dispatched advisors' results into a single severity-ranked table:

   | Severity | Category | File:Line | Finding | Advisor |
   |----------|----------|-----------|---------|---------|
   | CRITICAL | ... | ... | ... | reviewer / security-auditor / doc-writer |
   | MAJOR | ... | ... | ... | ... |
   | MINOR | ... | ... | ... | ... |

   Present CRITICALs first, then MAJORs, then MINORs. Include a summary count per severity across all dispatched advisors.
5. **Present the result.** If any advisor returns no findings, note it explicitly (e.g., "security-auditor: no concerns at this confidence"). If any advisor was skipped by the routing gate, list it with one line (e.g., "doc-writer: skipped (no docs surface in diff)").
</Steps>

<Tool_Usage>
- Bash for `git diff`/`git status` (no mutations); `git diff --stat` doubles as the advisor routing gate
- Read for named-file reviews
- Task tool with `subagent_type="reviewer"` for severity-rated code review — always dispatched
- Task tool → `security-auditor` agent for security-focused review — only when the routing gate selects it (security surface or large diff; always in slug context)
- Task tool → `doc-writer` agent for documentation gap review (read-only: no Write/Edit during invocation) — only when the routing gate selects it (docs/API surface; always in slug context)
- All dispatched agents are invoked in a single parallel message (one tool call block)
</Tool_Usage>

<Examples>
**Example 1 — small logic-only diff (advisors skipped):**
User: "review my staged changes" (40-line diff in pure business logic, no docs, no security surface)
Steps: `git diff --cached` + `--stat` → gate selects `reviewer` only → consolidate → present findings plus "security-auditor: skipped (no security surface in diff)" and "doc-writer: skipped (no docs surface in diff)".

**Example 2 — auth-touching named file (panel widened):**
User: "code-review src/auth/login.ts"
Steps: Read the file → path/content hit the security surface → dispatch `reviewer` (with the panel note: skip the Security category) + `security-auditor` in parallel → consolidate → present findings plus "doc-writer: skipped (no docs surface in diff)".

**Example 3 — slug context (full panel):**
Autopilot invokes code-review with `--slug=checkout-rework`.
Steps: gate bypassed → `reviewer` + `security-auditor` + `doc-writer` in parallel, each with the hand-off directive → findings persisted to `.dt-handoff/checkout-rework/artifacts/ask/` → consolidate and present.
</Examples>

<Final_Checklist>
- Did I identify the review surface (including `git diff --stat`) before delegating?
- Did I dispatch `reviewer` (not inline), and route `security-auditor`/`doc-writer` by the gate — full panel when a slug context is active?
- Did I note every skipped advisor with a one-line "skipped (no <surface> in diff)"?
- If `security-auditor` was on the panel, did the reviewer prompt tell it to skip the Security category?
- Did the output use the severity bar (CRITICAL/MAJOR/MINOR)?
</Final_Checklist>
