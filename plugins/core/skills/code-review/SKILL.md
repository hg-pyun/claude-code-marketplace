---
name: code-review
description: Severity-rated review of the current diff or a named file. Delegates to the core:reviewer agent and produces CRITICAL/MAJOR/MINOR findings with file:line evidence. TRIGGER when user says "review my changes", "코드 리뷰 해줘", "/code-review", or asks for severity-rated feedback. DO NOT TRIGGER for general code questions or syntax help.
---

<Purpose>
Produce a severity-rated review of the current diff (or a specified file) using the `core:reviewer` agent. Returns CRITICAL/MAJOR/MINOR findings each anchored to file:line, with a summary count.
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
Free-form "looks good" reviews consume time without informing decisions. Severity-rated reviews let the user triage: fix CRITICALs now, batch MAJORs, defer MINORs. This skill is the canonical entrypoint for that triage style in the hg-pyun-plugins marketplace, and uses `core:reviewer` so all callers get the same behavior.
</Why_This_Exists>

<Execution_Policy>
- Always identify the review surface first (diff scope, or named files).
- Delegate to `core:reviewer` agent — do NOT inline the review logic.
- Fallback: if `core` plugin is not installed, fall back to a local review with the same output structure, and note the missing-core condition in the summary.
- Output must use the severity bar consistently across invocations.
</Execution_Policy>

<Steps>
1. **Identify review surface.** Default: `git diff` (staged + unstaged). User can override with a file path argument.
2. **Capture the diff or file content.** Use `git diff --no-color` for diff mode; `Read` for named files.
3. **Delegate to core:reviewer via Task tool:**
   ```
   Task(
     subagent_type="core:reviewer",
     prompt="Review the following diff. Return severity-rated findings (CRITICAL/MAJOR/MINOR), each with file:line evidence.\n\n<diff content>"
   )
   ```
4. **Fallback when core is not installed.** If the Task invocation returns an "unknown subagent" or equivalent error, perform the review inline with the same output structure and append a note: "core plugin not installed; review performed locally."
5. **Present the result.** Use the reviewer's Output_Format verbatim.
</Steps>

<Tool_Usage>
- Bash for `git diff`/`git status` (no mutations)
- Read for named-file reviews
- Task tool with `subagent_type="core:reviewer"` for delegation
</Tool_Usage>

<Examples>
**Example 1 — staged diff review:**
User: "review my staged changes"
Steps: `git diff --cached` → delegate to `core:reviewer` → present findings.

**Example 2 — named file review:**
User: "code-review src/auth/login.ts"
Steps: Read the file → delegate to `core:reviewer` with file contents → present findings.

**Example 3 — fallback path:**
core plugin not installed → Task call errors → inline reviewer behavior → append "core plugin not installed; review performed locally." to summary.
</Examples>

<Final_Checklist>
- Did I identify the review surface before delegating?
- Did I delegate to `core:reviewer` (not inline) when core is available?
- Did the output use the severity bar (CRITICAL/MAJOR/MINOR)?
- If core missing, did I run fallback and note it in summary?
</Final_Checklist>
