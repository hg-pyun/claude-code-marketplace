#!/bin/sh
# Session Harvester — Event Logger
# Handles: UserPromptSubmit, PreToolUse, PostToolUseFailure
# Reads stdin JSON, applies sed masking, appends to session JSONL log.

set -e

# --- Read stdin ---
INPUT="$(cat)"

# --- Resolve data directory ---
DATA_DIR="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugin-data/session-harvester}"
SESSION_DIR="${DATA_DIR}/sessions"
mkdir -p "${SESSION_DIR}"

# --- Extract common fields ---
SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // empty')"
EVENT_NAME="$(printf '%s' "${INPUT}" | jq -r '.hook_event_name // empty')"

if [ -z "${SESSION_ID}" ] || [ -z "${EVENT_NAME}" ]; then
  exit 0
fi

LOG_FILE="${SESSION_DIR}/${SESSION_ID}.jsonl"
TS="$(date +%s)"

# --- Build log record based on event type ---
RECORD=""

case "${EVENT_NAME}" in
  UserPromptSubmit)
    PROMPT="$(printf '%s' "${INPUT}" | jq -r '.prompt // empty')"
    if [ -z "${PROMPT}" ]; then
      exit 0
    fi
    RECORD="$(jq -n --argjson ts "${TS}" --arg prompt "${PROMPT}" \
      '{"ts": $ts, "event": "prompt", "prompt": $prompt}')"
    ;;

  PreToolUse)
    TOOL_NAME="$(printf '%s' "${INPUT}" | jq -r '.tool_name // empty')"
    TOOL_INPUT="$(printf '%s' "${INPUT}" | jq -c '.tool_input // {}')"
    if [ -z "${TOOL_NAME}" ]; then
      exit 0
    fi
    RECORD="$(jq -n --argjson ts "${TS}" --arg tool "${TOOL_NAME}" --argjson input "${TOOL_INPUT}" \
      '{"ts": $ts, "event": "tool", "tool": $tool, "input": $input}')"
    ;;

  PostToolUseFailure)
    TOOL_NAME="$(printf '%s' "${INPUT}" | jq -r '.tool_name // empty')"
    ERROR="$(printf '%s' "${INPUT}" | jq -r '.error // empty')"
    if [ -z "${TOOL_NAME}" ]; then
      exit 0
    fi
    RECORD="$(jq -n --argjson ts "${TS}" --arg tool "${TOOL_NAME}" --arg error "${ERROR}" \
      '{"ts": $ts, "event": "tool_error", "tool": $tool, "error": $error}')"
    ;;

  *)
    # Unknown event, skip
    exit 0
    ;;
esac

if [ -z "${RECORD}" ]; then
  exit 0
fi

# --- Apply sensitive data masking ---
MASKED="$(printf '%s' "${RECORD}" | sed -E \
  -e 's/sk-[a-zA-Z0-9]{20,}/[REDACTED]/g' \
  -e 's/(api[_-]?key[=:][[:space:]]*)[^",}[:space:]]+/\1[REDACTED]/gi' \
  -e 's/(Bearer[[:space:]]+)[^",}[:space:]]+/\1[REDACTED]/gi' \
  -e 's/(token[=:][[:space:]]*)[^",}[:space:]]+/\1[REDACTED]/gi' \
  -e 's/(password[=:][[:space:]]*)[^",}[:space:]]+/\1[REDACTED]/gi' \
  -e 's/(secret[=:][[:space:]]*)[^",}[:space:]]+/\1[REDACTED]/gi' \
  -e 's/([A-Z_]*(KEY|SECRET|TOKEN|PASSWORD)[=:][[:space:]]*)[^",}[:space:]]+/\1[REDACTED]/gi' \
)"

# --- Append to log file ---
printf '%s\n' "${MASKED}" >> "${LOG_FILE}"
