---
name: core-verify
description: Evidence-based verification of recent changes via the core plugin. Use after any non-trivial change to confirm the change actually does what it should, not just that tests pass. TRIGGER when user says "verify with core", "core 검증", invokes /core-verify, or asks "did my change actually work?". DO NOT TRIGGER for unrelated work or when the user wants a different verifier they already have installed.
---

<Purpose>
Run an evidence-based PASS/FAIL check on the most recent changes in the repository. Instead of trusting test output alone, this skill identifies what the change was supposed to do and confirms it actually does that by running the code, observing behavior, and citing file:line evidence.
</Purpose>

<Use_When>
- A change has just landed (committed or staged) and the user wants confirmation it works
- The user says "verify with core", "core 검증", "/core-verify", or asks "did my change work?" in a hg-pyun-plugins context
- Tests pass but the user wants real-world behavior evidence
</Use_When>

<Do_Not_Use_When>
- The user has another verifier installed (from a different plugin or marketplace) and explicitly named it
- No changes have been made yet — there is nothing to verify
- The user is asking conceptually what verification means — answer conversationally
</Do_Not_Use_When>

<Why_This_Exists>
Type checks and test suites verify correctness of code, not correctness of features. "Tests pass" is necessary but not sufficient. A change that wires the wrong endpoint, ships the wrong copy, or breaks a UI flow can still pass tests. This skill is the explicit step where someone (the user, with this skill's help) actually runs the code and looks at the result before declaring success.
</Why_This_Exists>

<Execution_Policy>
- Always identify the change surface before verifying — what files moved, what was added.
- Verification must produce file:line evidence, not just "looks good."
- If the change is UI/frontend, browser observation is required.
- If verification cannot be performed automatically (e.g., requires production data), say so explicitly rather than declaring PASS.
</Execution_Policy>

<Steps>
1. **Identify change surface.** Run `git status` and `git diff --stat HEAD` (or against a base branch the user names). List the changed files with one-line per-file purpose.
2. **State the intended behavior.** Either the user provided it, or you infer it from the diff. State it explicitly so PASS/FAIL has a target.
3. **Run the code.** Use the appropriate run path (dev server, CLI invocation, unit test) per the change type.
4. **Observe and cite evidence.** Capture output, screenshots (if UI), or response bodies (if API). Cite `file:line` for each evidence point.
5. **Issue verdict.** PASS / FAIL / INCONCLUSIVE with one sentence per evidence point.
</Steps>

<Tool_Usage>
- Bash for git operations and running the code
- Read for inspecting changed files
- chrome-devtools MCP (or equivalent) for UI verification
- Optionally delegate to `core:reviewer` via Task tool when severity-rated review of the change is also desired
</Tool_Usage>

<Examples>
**Example 1 — backend API change:**
Input: user added a `/health` endpoint.
Steps: `git diff HEAD~ -- src/routes/health.ts` → start server → `curl localhost:3000/health` → observe `{"status":"ok"}` → PASS with response cited.

**Example 2 — UI button rename:**
Input: button text changed from "Submit" to "Send".
Steps: identify file → run dev server → open browser to the page → screenshot → confirm text → PASS.

**Example 3 — INCONCLUSIVE:**
Input: change requires production billing data.
Steps: identify change → state intended behavior → cannot run in local env without billing keys → INCONCLUSIVE with reason cited; suggest staging environment.
</Examples>

<Final_Checklist>
- Did I identify the change surface before verifying?
- Did I state the intended behavior in one sentence?
- Did I actually run the code (not just read it)?
- Does every PASS claim have file:line or output evidence?
- If INCONCLUSIVE, did I explain what data/environment is missing?
</Final_Checklist>
