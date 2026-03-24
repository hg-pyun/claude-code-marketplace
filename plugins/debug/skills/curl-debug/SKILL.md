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

# cURL Debug

Execute a cURL, then reverse-trace from the response to the root cause in the codebase by following the strongest signal first.

## Arguments

`$ARGUMENTS`: Raw cURL string. If the user pasted a cURL in conversation, use that.

## Procedure

### Step 1: Execute

Run the user's cURL via Bash and capture the response.

Append these flags to the original cURL, skipping any that are already present:
- `-s` (suppress progress bar)
- `-w '\n%{http_code}\n%{time_total}'` (capture status code + response time)
- `-i` (capture response headers)

Print the result. For long responses, summarize the key parts.

**On network error**: Present likely causes (server down, DNS failure, etc.) and use AskUserQuestion to ask whether to retry. Proceed with URL-path-based code tracing regardless — the code exists even if the server is down.

### Step 2: Analyze & Route

Extract signals from the response and determine the tracing order.

#### Short-Circuit Check

If any of these conditions match, skip the normal signal-priority flow:

- **401/403**: Before tracing code, use AskUserQuestion to suggest refreshing the token and retrying. Most 401/403s are expired tokens, not code bugs. If the retry still fails, trace the auth middleware.
- **404**: Check route registration only. Do not trace into handlers or services — the request never reached them. Focus on *why* it didn't match: missing registration, typo, route ordering, middleware blocking.
- **2xx + user reports unexpected data**: Use AskUserQuestion to ask for the expected response. With no error signals, the diff between actual and expected is the only lead.
- **406/415**: Compare request headers against the server's parser/middleware configuration.

#### Signal Priority

If no short-circuit applies, extract signals from the response and follow them in this order:

| Priority | Signal | How to detect | Tracing entry point |
|----------|--------|---------------|-------------------|
| **1** | Stack trace | file:line info in response body | Read the file:line directly |
| **2** | Error message | Specific string in error/message/detail fields | Grep the string in codebase |
| **3** | Error code | Value in code/error_code/type fields | Grep for constant/enum definition |
| **4** | URL path | Always available | Grep for route definition → follow handler chain |
| **5** | Request body field names | Field names from JSON body | Grep for schema/type definitions |
| **6** | Response body structure | Field structure of the response | Grep for DTO/serialization code |

Start from the highest-priority signal that exists.

### Step 3: Trace

Follow signals through the codebase in the determined order. **Stream each step as you go** — do not batch results into a final report.

#### Tracing Principles

- **URL path search**: Start with the most distinctive segment (`orders` > `api`). Generalize path params (numbers, UUIDs) to wildcards. Combine with HTTP method for precision.
- **Error message search**: Split into meaningful fragments. If an error code exists, search for the enum/constant definition first.
- **Body fields → schema**: Find type definitions and check for mismatches between the schema and the actual values sent.
- **Stack trace**: Skip framework-internal frames and start at the first user-code frame.
- **Route → handler chain**: Follow imports/requires to trace the function call chain.

#### Parallel Tracing

Use the Agent tool for parallel exploration **only** when signals 1–3 are all absent and the URL path (signal 4) is the sole entry point:
- **Agent A**: URL path → router → handler → service chain
- **Agent B**: Request body field names → model/schema tracing

Otherwise, trace sequentially.

#### Halt Condition

Stop tracing and proceed to Step 4 when you can answer **all three**:

1. **What** went wrong (technical cause of the symptom)
2. **Where** it happens (file:line)
3. **Why** it happens (root cause)

If any of the three is unanswered, continue to the next signal priority.

If all signals are exhausted without completing the three answers → present the best analysis with what you have, then use AskUserQuestion to request additional info (server logs, framework details, etc.).

### Step 4: Report & Follow-Up

#### Output Structure

1. **Request/Response summary** — method, URL, status code, response time, key error info
2. **Code trace path** — the actual path traced, in `file:line → functionName` format
3. **Bug cause** — what, where, why (answers to the halt condition)
4. **Fix suggestions** — concrete code change options. Each option includes file:line, the change, and trade-offs. **Do not apply fixes directly.**

#### Follow-Up Actions

Use AskUserQuestion to offer situationally relevant options. Only include options that apply to the current situation:

- **Retry with modified parameters** (always): Accept changed values, re-run from Step 1
- **View fix details** (when multiple fix options exist): Show detailed code changes for a selected option
- **Explore more code** (always): Expand the call chain (callers/callees)
- **Provide expected response** (when 2xx and no expected value given): Enable diff analysis for further tracing
- **Provide server logs** (when signals 1–3 all failed): Request log path/content from user
- **Retry with fresh token** (on 401/403): Re-run with updated auth credentials
- **Retry with modified headers** (on 406/415): Adjust Content-Type, Accept, etc. and re-run
- **Done** (always)
