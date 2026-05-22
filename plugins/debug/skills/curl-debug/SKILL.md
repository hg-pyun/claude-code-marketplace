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
- Halt as soon as you can answer What / Where / Why.
- Never apply fixes — present fix options for the user to choose from.
- For non-trivial proposed fixes, optionally delegate to `core:reviewer` for severity-rated review (see Step 4).
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
Follow signals through the codebase in the determined order. **Stream each step as you go** — do not batch into a final report.

**Tracing principles:**
- **URL path search:** start with the most distinctive segment (`orders` > `api`). Generalize path params (numbers, UUIDs) to wildcards. Combine with HTTP method for precision.
- **Error message search:** split into meaningful fragments. If an error code exists, search for the enum/constant definition first.
- **Body fields → schema:** find type definitions and check mismatches between schema and actual values sent.
- **Stack trace:** skip framework-internal frames; start at the first user-code frame.
- **Route → handler chain:** follow imports/requires to trace the function-call chain.

**Parallel tracing:** use the Agent tool for parallel exploration **only** when signals 1–3 are all absent and the URL path (signal 4) is the sole entry point:
- **Agent A:** URL path → router → handler → service chain
- **Agent B:** Request body field names → model/schema tracing

Otherwise, trace sequentially.

**Halt condition:** stop tracing and proceed to Step 4 when you can answer **all three**:
1. **What** went wrong (technical cause)
2. **Where** it happens (file:line)
3. **Why** it happens (root cause)

If any of the three is unanswered, continue to the next signal priority. If all signals are exhausted without completing the three answers → present the best analysis you have and AskUserQuestion for additional info (server logs, framework details, etc.).

### Step 4: Report & follow-up
**Output structure:**
1. **Request/Response summary** — method, URL, status code, response time, key error info
2. **Code trace path** — actual path traced in `file:line → functionName` format
3. **Bug cause** — what, where, why (the halt condition's three answers)
4. **Fix suggestions** — concrete code change options. Each with file:line, the change, and trade-offs. **Do not apply fixes directly.**

**Optional core delegation (cross-plugin wiring):** when the trace identifies a non-trivial code change and the user would benefit from a second opinion before acting, delegate severity-rated review of the proposed fix to `core` via:

```
Task(
  subagent_type="core:reviewer",
  prompt="Review the following proposed fix for severity-rated issues:\n\n${PROPOSED_FIX_DIFF_OR_SNIPPET}"
)
```

**Fallback when `core` is not installed:** if the Task invocation returns an "unknown subagent" or equivalent error, skip the delegation and append a note to the report: "core plugin not installed; review delegated locally to the calling session." Detection: an explicit error matching `unknown subagent` or similar in the Task result.

The cross-plugin delegation is optional — only invoke when the proposed fix is non-trivial and a review pass would be valuable.

**Follow-up actions** (AskUserQuestion, situationally relevant):
- **Retry with modified parameters** (always): accept changed values, re-run from Step 1
- **View fix details** (when multiple fix options exist): show detailed code changes for a selected option
- **Explore more code** (always): expand the call chain (callers/callees)
- **Delegate review to core:reviewer** (when a non-trivial fix is proposed and `core` is installed)
- **Provide expected response** (when 2xx and no expected value given): enable diff analysis
- **Provide server logs** (when signals 1–3 all failed): request log path/content
- **Retry with fresh token** (on 401/403): re-run with updated auth credentials
- **Retry with modified headers** (on 406/415): adjust Content-Type, Accept, etc.
- **Done** (always)
</Steps>

<Tool_Usage>
- `Bash` for executing the cURL and any follow-up shell commands
- `Grep` + `Read` for codebase tracing
- `Task(subagent_type="core:reviewer", ...)` (optional) when a proposed fix benefits from severity-rated review (see Step 4 cross-plugin delegation)
- `AskUserQuestion` at decision points (network retry, short-circuit cases, missing info, follow-up actions)
</Tool_Usage>

<Examples>
**Example 1 — 500 with stack trace:**
User pastes a cURL that returns `500 Internal Server Error` with a stack trace pointing to `src/services/billing.ts:204`.
Flow: Step 1 runs cURL → response has stack trace (signal 1) → Read `src/services/billing.ts:200-220` → find division by zero on line 204 → report What/Where/Why → propose 2 fix options.

**Example 2 — 404 short-circuit:**
User: "/curl-debug curl https://api.example.com/v2/orders/123"
Flow: Step 1 runs → 404 → short-circuit: check route registration → grep `'/v2/orders'` → find handler registered as `/v1/orders` → report mismatch → suggest registering v2 alias.

**Example 3 — non-trivial fix + core delegation:**
User pastes a cURL that returns wrong data on a complex endpoint.
Flow: Step 1-3 identify a 30-line refactor needed in `src/handlers/order.ts` → Step 4 produces fix suggestion → propose delegating review to `core:reviewer` via Task → reviewer returns severity-rated findings → user picks fix to apply.

**Example 4 — missing-core fallback:**
Same as Example 3 but `core` plugin not installed → Task invocation returns "unknown subagent" → skill skips delegation, appends fallback note → user reviews fix manually.
</Examples>

<Final_Checklist>
- Did I actually run the cURL?
- Did I follow signal priority (highest available signal first)?
- Did I stop at the halt condition (What / Where / Why all answered)?
- Did I avoid applying fixes (present options only)?
- For non-trivial fixes: did I consider delegating to `core:reviewer` and honor the fallback when `core` is missing?
- Did I cite file:line in the report?
</Final_Checklist>
