---
name: code-review
description: Severity-rated review of the current diff or a named file. Delegates to reviewer + security-auditor + doc-writer agents in parallel for multi-domain code review and produces CRITICAL/MAJOR/MINOR findings with file:line evidence. TRIGGER when user says "review my changes", "코드 리뷰 해줘", "/code-review", or asks for severity-rated feedback. DO NOT TRIGGER for general code questions or syntax help.
---

<Purpose>
Produce a severity-rated review of the current diff (or a specified file) using the `reviewer`, `security-auditor`, and `doc-writer` advisors in parallel. Returns CRITICAL/MAJOR/MINOR findings each anchored to file:line, with a summary count across all three domains.
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
Free-form "looks good" reviews consume time without informing decisions. Severity-rated reviews let the user triage: fix CRITICALs now, batch MAJORs, defer MINORs. This skill is the canonical entrypoint for that triage style in the `dev-tools` plugin, and uses the `reviewer`, `security-auditor`, and `doc-writer` advisors in parallel so all callers get consistent multi-domain coverage.
</Why_This_Exists>

<Execution_Policy>
- Always identify the review surface first (diff scope, or named files).
- Delegate to the `reviewer` + `security-auditor` + `doc-writer` agents in parallel — do NOT inline the review logic.
- Output must use the severity bar consistently across invocations.
- **Hand-off persistence (slug context only)**: when a slug context is active (e.g., autopilot invocation or `--slug=<slug>` argument), each advisor's findings MUST also be persisted to `.specs/<slug>/artifacts/ask/<agent>-<ISO8601>.md` with the OMC descriptor frontmatter (kind=advisor, retention=session, status=complete). For free-standing user invocations without a slug, in-session text output is sufficient and no file is written.
</Execution_Policy>

<Steps>
1. **Identify review surface.** Default: `git diff` (staged + unstaged). User can override with a file path argument.
2. **Capture the diff or file content.** Use `git diff --no-color` for diff mode; `Read` for named files.
3. **Delegate to three advisor agents in a single parallel message.** When a slug context is active, append the hand-off output directive (see template below) to each prompt so the agent writes a persistent findings file alongside its in-session reply:
   ```
   [
     Task(subagent_type="reviewer", prompt="Severity-rated review of the diff. Return CRITICAL/MAJOR/MINOR findings with file:line evidence.\n\n<diff content>\n\n<hand-off directive if slug active>"),
     Task(subagent_type="security-auditor", prompt="Security-focused review of the diff using AuthN/AuthZ/Secret/Crypto/Injection/SAST/Config categories. Return Findings with severity/category/location/evidence/recommendation/confidence. Use `no concerns at this confidence` if zero findings.\n\n<diff content>\n\n<hand-off directive if slug active>"),
     Task(subagent_type="doc-writer", prompt="Do not call Write/Edit during this invocation. Return diff-shaped recommendations only. Documentation review of the diff using Missing/Outdated/Inconsistent/Unclear categories. Return Findings with severity/category/location/evidence/recommendation/confidence.\n\n<diff content>\n\n<hand-off directive if slug active>")
   ]
   ```

   **Hand-off directive template** (append to each Task prompt when slug is active):
   ```
   Also persist your findings to `.specs/<slug>/artifacts/ask/<agent>-<ISO8601>.md` with this YAML frontmatter at the top:
   ---
   kind: advisor
   path: .specs/<slug>/artifacts/ask/<agent>-<ISO8601>.md
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
4. **Consolidate findings.** Merge all three advisors' results into a single severity-ranked table:

   | Severity | Category | File:Line | Finding | Advisor |
   |----------|----------|-----------|---------|---------|
   | CRITICAL | ... | ... | ... | reviewer / security-auditor / doc-writer |
   | MAJOR | ... | ... | ... | ... |
   | MINOR | ... | ... | ... | ... |

   Present CRITICALs first, then MAJORs, then MINORs. Include a summary count per severity across all advisors.
5. **Present the result.** If any advisor returns no findings, note it explicitly (e.g., "security-auditor: no concerns at this confidence").
</Steps>

<Tool_Usage>
- Bash for `git diff`/`git status` (no mutations)
- Read for named-file reviews
- Task tool with `subagent_type="reviewer"` for severity-rated code review
- Task tool → `security-auditor` agent for security-focused review
- Task tool → `doc-writer` agent for documentation gap review (read-only: no Write/Edit during invocation)
- All three agents are invoked in a single parallel message (one tool call block)
</Tool_Usage>

<Examples>
**Example 1 — staged diff review:**
User: "review my staged changes"
Steps: `git diff --cached` → delegate to `reviewer` + `security-auditor` + `doc-writer` in parallel → consolidate and present findings.

**Example 2 — named file review:**
User: "code-review src/auth/login.ts"
Steps: Read the file → delegate to `reviewer` + `security-auditor` + `doc-writer` in parallel with file contents → consolidate and present findings.
</Examples>

<Final_Checklist>
- Did I identify the review surface before delegating?
- Did I delegate to `reviewer` + `security-auditor` + `doc-writer` in parallel (not inline)?
- Did the output use the severity bar (CRITICAL/MAJOR/MINOR)?
</Final_Checklist>
