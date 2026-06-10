---
name: curl-debug
description: >
  Execute a cURL command and trace the response back through the codebase to
  find the root cause of bugs. Use this skill to debug API issues by running
  the actual request and reverse-tracing from the response to the responsible
  code. TRIGGER when: user shares a cURL command along with a question about
  a bug, error, or unexpected behavior (e.g., "이 curl 요청이 500 에러가
  나는데 왜 그런지 봐줘", "curl로 보내면 잘못된 데이터가 오는데",
  "이 API가 왜 이렇게 응답하는지 코드에서 찾아줘", "이 요청 디버깅 좀
  해줘", "this curl returns 500, help me debug", "why does this API return
  wrong data"). Also trigger with /curl-debug slash command. DO NOT TRIGGER
  when: user is just asking to execute a cURL without debugging intent,
  discussing cURL syntax, or sharing cURL for documentation purposes.
---

<Purpose>
Run a user-provided cURL, capture the response, and reverse-trace from the response signal (stack trace, error message, status code, body shape) to the responsible code path. Returns a root-cause report with file:line evidence and concrete fix suggestions. Does NOT apply fixes.
</Purpose>

<Use_When>
- User shares a cURL command alongside a bug question ("이 요청 500 나는데 왜?", "this curl returns 500, help me debug")
- User invokes `/curl-debug <cURL>`
- A failing API request needs to be traced back to source code
- User wants a structured trace from observable symptom to root cause
</Use_When>

<Do_Not_Use_When>
- User just wants to execute a cURL without debugging intent — run it directly
- User is asking about cURL syntax conceptually
- User is sharing cURL for documentation purposes
- No cURL is provided and the user wants pure codebase exploration — use other tools
</Do_Not_Use_When>

<Why_This_Exists>
Tracing an API bug from "this curl returns 500" to "this exact line in this exact file" is a high-frequency activity that benefits from a deterministic flow. Without a structured procedure, callers waste time grepping random strings. This skill applies signal priority (stack trace > error message > error code > URL path > body fields > response structure) so the strongest available signal is followed first, and stops as soon as What/Where/Why are answered.
</Why_This_Exists>

<Execution_Policy>
- Always run the user's actual cURL — do not skip Step 1 unless the network is unreachable.
- Trace by signal priority (table below). Stream each step as you go.
- Route Step 3 by signal grade: grade-1 signals (stack trace with direct file:line, or the 404 short-circuit) are traced inline by the main session via `Read`/`Grep`; weaker, indirect signals with real competing hypotheses delegate to the `tracer` agent.
- Halt as soon as you can answer What / Where / Why.
- Never apply fixes — present fix options for the user to choose from.
- For non-trivial proposed fixes, optionally delegate to the `reviewer` agent for severity-rated review (see Step 4).
</Execution_Policy>

<Arguments>
- `$ARGUMENTS`: raw cURL string. If the user pasted a cURL in conversation, use that.
</Arguments>

<Steps>
### Step 1: Execute
Run the user's cURL via `Bash` and capture the response. Append these flags to the original cURL (skipping any already present):
- `-s` (suppress progress bar)
- `-w '\n%{http_code}\n%{time_total}'` (status code + response time)
- `-i` (include response headers)

Print the result. For long responses, summarize the key parts.

**On network error:** present likely causes (server down, DNS failure, etc.) and AskUserQuestion whether to retry. Proceed with URL-path-based code tracing regardless — the code exists even if the server is down.

### Step 2: Analyze & route
Extract signals from the response and determine the tracing order.

**Short-circuit checks** (apply first):
- **401/403**: AskUserQuestion to suggest refreshing the token and retrying. Most 401/403s are expired tokens. If retry still fails, trace the auth middleware.
- **404**: Check route registration only. Do not trace handlers/services — the request never reached them. Focus on *why* it didn't match: missing registration, typo, route ordering, middleware blocking.
- **2xx + user reports unexpected data**: AskUserQuestion for the expected response. With no error signals, the diff between actual and expected is the only lead.
- **406/415**: Compare request headers against the server's parser/middleware configuration.

**Signal priority** (when no short-circuit applies):

| Priority | Signal | How to detect | Tracing entry point |
|----------|--------|---------------|---------------------|
| 1 | Stack trace | file:line info in response body | Read the file:line directly |
| 2 | Error message | Specific string in error/message/detail fields | Grep the string in codebase |
| 3 | Error code | Value in code/error_code/type fields | Grep for constant/enum definition |
| 4 | URL path | Always available | Grep for route definition → follow handler chain |
| 5 | Request body field names | Field names from JSON body | Grep for schema/type definitions |
| 6 | Response body structure | Field structure of the response | Grep for DTO/serialization code |

Start from the highest-priority signal that exists.

### Step 3: Trace
Route the trace by signal grade:

**Grade 1 — trace inline (no dispatch).** When the response contains a stack trace pointing directly at file:line (signal priority 1), or the 404 short-circuit from Step 2 applies, the main session traces immediately with `Read`/`Grep`: read the indicated file:line, or grep the route registration. There is one obvious entry point and no competing hypotheses — dispatching an agent would only add latency. If the inline trace stalls (the direct signal turns out to be misleading), fall through to the tracer path below.

**Grade 2 or lower — delegate to the `tracer` agent.** When only indirect signals exist (error message/code, URL path, body field names, response structure) and competing hypotheses are real, delegate the reverse-trace. Pass the cURL response body, status code, response headers, and the signals extracted in Step 2 as an `@handoff-in` block. Tracer applies the same signal-priority order, enumerates competing hypotheses, scores each with supporting and refuting evidence, and returns a ranked evidence chain with the full trace path (effect → intermediate evidence → file:line).

```
Task(
  subagent_type="tracer",
  prompt="""
Reverse-trace the following HTTP response to the responsible code path.

@handoff-in
kind: handoff
path: .dt-handoff/<slug>/artifacts/ask/curl-debug-<ISO8601>.md
contentHash: sha256:<…>
sizeBytes: <…>
note: <1-line description of the effect — e.g., "HTTP 500 with stack trace; trace to responsible code">

<inline the response body, status code, headers, and extracted signals here when sizeBytes ≤ 4096; otherwise write them to the path above and reference by pointer only>
"""
)
```

On the tracer path, consume the tracer's output: read the ranked hypothesis table and the trace chain (effect → file:line). The top-ranked hypothesis and its file:line evidence become the input to Step 4.

**Halt condition (inline or tracer):** stop when you can answer **all three**:
1. **What** went wrong (technical cause)
2. **Where** it happens (file:line)
3. **Why** it happens (root cause)

If tracer cannot answer all three (sets `status: failed` in its `@handoff-out`), present the partial trace and AskUserQuestion for additional info (server logs, framework details, etc.).

### Step 4: Report & follow-up
**Output structure:**
1. **Request/Response summary** — method, URL, status code, response time, key error info
2. **Code trace path** — actual path traced in `file:line → functionName` format
3. **Bug cause** — what, where, why (the halt condition's three answers)
4. **Fix suggestions** — concrete code change options. Each with file:line, the change, and trade-offs. **Do not apply fixes directly.**

**Optional reviewer delegation:** when the trace identifies a non-trivial code change and the user would benefit from a second opinion before acting, delegate severity-rated review of the proposed fix via:

```
Task(
  subagent_type="reviewer",
  prompt="Review the following proposed fix for severity-rated issues:\n\n${PROPOSED_FIX_DIFF_OR_SNIPPET}"
)
```

This delegation is optional — only invoke when the proposed fix is non-trivial and a review pass would be valuable.

**Follow-up options (prose, not a menu):** close the report with a short prose paragraph offering the situationally relevant next steps — the user replies in natural language. Do NOT raise an AskUserQuestion menu here. Mention only the options that apply:
- Retry with modified parameters (re-run from Step 1 with changed values)
- View detailed code changes for a fix option (when multiple fix options exist)
- Explore more of the call chain (callers/callees)
- Delegate review of a proposed fix to the `reviewer` agent (when a non-trivial fix is proposed)
- Provide the expected response (when 2xx and no expected value given — enables diff analysis)
- Provide server logs (when signals 1–3 all failed)
- Retry with a fresh token (on 401/403) or modified headers (on 406/415)
</Steps>

<Tool_Usage>
- `Bash` for executing the cURL and any follow-up shell commands
- `Read`/`Grep` for inline tracing of grade-1 signals (direct stack-trace file:line, 404 route-registration check) — no agent dispatch
- `Task(subagent_type="tracer", ...)` — Step 3 tracing mechanism for grade-2-or-lower signals; pass the cURL response + extracted signals via `@handoff-in`; consume the returned trace chain and ranked hypotheses
- `Task(subagent_type="reviewer", ...)` (optional) when a proposed fix benefits from severity-rated review (see Step 4)
- `AskUserQuestion` at decision points (network retry, short-circuit cases, missing info) — NOT for end-of-report follow-ups, which are offered in prose
</Tool_Usage>

<Examples>
**Example 1 — 500 with stack trace (grade 1, inline):**
User pastes a cURL that returns `500 Internal Server Error` with a stack trace pointing to `src/services/billing.ts:204`.
Flow: Step 1 runs cURL → response has stack trace (signal 1, grade 1) → no tracer dispatch → Read `src/services/billing.ts:200-220` → find division by zero on line 204 → report What/Where/Why → propose 2 fix options, follow-ups offered in prose.

**Example 2 — 404 short-circuit (inline):**
User: "/curl-debug curl https://api.example.com/v2/orders/123"
Flow: Step 1 runs → 404 → short-circuit: check route registration inline → grep `'/v2/orders'` → find handler registered as `/v1/orders` → report mismatch → suggest registering v2 alias.

**Example 3 — indirect signals + reviewer delegation (tracer path):**
User pastes a cURL that returns wrong data on a complex endpoint (2xx, no stack trace — grade-2 signals with competing hypotheses).
Flow: Step 1-2 extract indirect signals → Step 3 dispatches `tracer`, which returns a ranked hypothesis table pointing to a 30-line refactor needed in `src/handlers/order.ts` → Step 4 produces fix suggestion → propose delegating review to the `reviewer` agent via Task → reviewer returns severity-rated findings → user picks fix to apply.
</Examples>

<Final_Checklist>
- Did I actually run the cURL?
- Did I follow signal priority (highest available signal first)?
- Did I route Step 3 by signal grade (inline Read/Grep for grade-1/404; tracer dispatch otherwise)?
- Did I stop at the halt condition (What / Where / Why all answered)?
- Did I avoid applying fixes (present options only)?
- Did I offer follow-ups as prose at the end of the report (no AskUserQuestion menu)?
- For non-trivial fixes: did I consider delegating to the `reviewer` agent?
- Did I cite file:line in the report?
</Final_Checklist>
