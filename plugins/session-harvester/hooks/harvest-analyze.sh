#!/bin/sh
# Session Harvester — Structural Pattern Analyzer
# Triggered by: SessionEnd hook
# Reads session log, extracts tool sequences, detects patterns,
# saves pattern summaries, and deletes the original log.

set -e

# --- Read stdin ---
INPUT="$(cat)"

# --- Resolve paths ---
DATA_DIR="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugin-data/session-harvester}"
SESSION_DIR="${DATA_DIR}/sessions"
PATTERNS_FILE="${DATA_DIR}/patterns.jsonl"
PENDING_FILE="${DATA_DIR}/pending_analysis.json"

# --- Check jq availability ---
if ! command -v jq > /dev/null 2>&1; then
  exit 0
fi

# --- Extract session ID ---
SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // empty')"
if [ -z "${SESSION_ID}" ]; then
  exit 0
fi

LOG_FILE="${SESSION_DIR}/${SESSION_ID}.jsonl"
if [ ! -f "${LOG_FILE}" ]; then
  exit 0
fi

# --- Count tool calls ---
TOOL_COUNT="$(jq -s '[.[] | select(.event == "tool")] | length' "${LOG_FILE}")"
if [ "${TOOL_COUNT}" -lt 5 ]; then
  # Short session: skip analysis, clean up, run expiry only
  rm -f "${LOG_FILE}"
  if [ -f "${PATTERNS_FILE}" ]; then
    CUTOFF="$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d 2>/dev/null || echo '')"
    if [ -n "${CUTOFF}" ]; then
      TEMP_FILE="${PATTERNS_FILE}.tmp"
      jq -c "select(.last_seen >= \"${CUTOFF}\")" "${PATTERNS_FILE}" > "${TEMP_FILE}" 2>/dev/null || true
      mv "${TEMP_FILE}" "${PATTERNS_FILE}"
    fi
  fi
  exit 0
fi

# --- Step 1: Extract tool sequences ---
# Build sequences by splitting on "prompt" events (each prompt starts a new task unit).
# Tools between prompts form a sequence.
SEQUENCES="$(jq -s '
  # Split events into groups by prompt boundaries
  reduce .[] as $e (
    {groups: [[]], current: 0};
    if $e.event == "prompt" then
      .current += 1 | .groups[.current] = []
    elif $e.event == "tool" or $e.event == "tool_error" then
      .groups[.current] += [$e]
    else .
    end
  )
  | .groups
  | map(select(length > 0))
  | map(
      map(
        if .event == "tool_error" then
          (.tool | split("") | .[0:1] | .[0] // "?") + "!"
        else
          .tool | split("") | .[0:1] | .[0] // "?"
        end
      )
      | join("-")
    )
  | map(select(length > 0))
' "${LOG_FILE}")"

# --- Step 2: Count sequence frequencies ---
FREQ="$(printf '%s' "${SEQUENCES}" | jq -r '.[]' | sort | uniq -c | sort -rn | head -20)"

# --- Step 3: Extract file patterns ---
FILE_PATHS="$(jq -r '
  select(.event == "tool")
  | .input
  | (.file_path // .path // empty)
' "${LOG_FILE}" | sort -u)"

# Abstract file paths to glob patterns: replace specific filenames with *
GLOB_PATTERNS=""
if [ -n "${FILE_PATHS}" ]; then
  GLOB_PATTERNS="$(printf '%s\n' "${FILE_PATHS}" \
    | sed -E 's|/[^/]+\.[a-zA-Z]+$|/*&|; s|/\*/.*/|/*/|' \
    | sed -E 's|(.*/)[^/]+(\.[a-zA-Z]+)$|\1*\2|' \
    | sort -u \
    | head -10)"
fi

# --- Step 4: Detect retry loops (tool_error followed by same tool) ---
RETRY_LOOPS="$(jq -s '
  [range(1; length)]
  | map(
      select(
        .[$INPUT[. - 1]].event == "tool_error"
        and .[$INPUT[.]].event == "tool"
        and .[$INPUT[. - 1]].tool == .[$INPUT[.]].tool
      )
      | $INPUT[.].tool
    )
  | group_by(.)
  | map({tool: .[0], count: length})
  | sort_by(-.count)
' "${LOG_FILE}" 2>/dev/null || echo '[]')"

# --- Step 5: Extract sample prompts ---
SAMPLE_PROMPTS="$(jq -s '[.[] | select(.event == "prompt") | .prompt] | .[0:5]' "${LOG_FILE}")"

# --- Step 6: Build pending analysis result ---
TODAY="$(date +%Y-%m-%d)"

# Parse frequency data into JSON
FREQ_JSON="$(printf '%s' "${FREQ}" | awk '{count=$1; $1=""; seq=substr($0,2); printf "{\"sequence\":\"%s\",\"count\":%d}\n", seq, count}' | jq -s '.')"

# Build glob patterns JSON
GLOB_JSON="$(printf '%s\n' "${GLOB_PATTERNS}" | jq -R '.' | jq -s '.')"

jq -n \
  --arg session_id "${SESSION_ID}" \
  --arg date "${TODAY}" \
  --argjson tool_count "${TOOL_COUNT}" \
  --argjson sequences "${FREQ_JSON}" \
  --argjson file_patterns "${GLOB_JSON}" \
  --argjson retry_loops "${RETRY_LOOPS}" \
  --argjson sample_prompts "${SAMPLE_PROMPTS}" \
  '{
    session_id: $session_id,
    date: $date,
    tool_count: $tool_count,
    sequences: $sequences,
    file_patterns: $file_patterns,
    retry_loops: $retry_loops,
    sample_prompts: $sample_prompts
  }' > "${PENDING_FILE}"

# --- Step 7: Update cumulative patterns ---
# For each sequence with count >= min_repeat_threshold (default 2),
# upsert into patterns.jsonl
touch "${PATTERNS_FILE}"

printf '%s' "${FREQ_JSON}" | jq -c '.[] | select(.count >= 2)' | while IFS= read -r SEQ_ENTRY; do
  SEQ="$(printf '%s' "${SEQ_ENTRY}" | jq -r '.sequence')"
  COUNT="$(printf '%s' "${SEQ_ENTRY}" | jq -r '.count')"
  SEQ_HASH="$(printf '%s' "${SEQ}" | shasum -a 256 | cut -d' ' -f1)"

  # Check if pattern already exists
  EXISTING="$(jq -c "select(.id == \"${SEQ_HASH}\")" "${PATTERNS_FILE}" 2>/dev/null | head -1)"

  if [ -n "${EXISTING}" ]; then
    # Update existing: increment count, update last_seen
    OLD_COUNT="$(printf '%s' "${EXISTING}" | jq -r '.count')"
    NEW_COUNT=$((OLD_COUNT + COUNT))
    TEMP_PAT="${PATTERNS_FILE}.tmp"
    jq -c "if .id == \"${SEQ_HASH}\" then .count = ${NEW_COUNT} | .last_seen = \"${TODAY}\" else . end" \
      "${PATTERNS_FILE}" > "${TEMP_PAT}"
    mv "${TEMP_PAT}" "${PATTERNS_FILE}"
  else
    # Create new pattern entry
    FIRST_PROMPT="$(printf '%s' "${SAMPLE_PROMPTS}" | jq -r '.[0] // ""')"
    FIRST_GLOB="$(printf '%s\n' "${GLOB_PATTERNS}" | head -1)"
    jq -n -c \
      --arg id "${SEQ_HASH}" \
      --arg sequence "${SEQ}" \
      --arg intent "" \
      --arg file_pattern "${FIRST_GLOB}" \
      --arg sample "${FIRST_PROMPT}" \
      --argjson count "${COUNT}" \
      --arg first_seen "${TODAY}" \
      --arg last_seen "${TODAY}" \
      '{
        id: $id,
        sequence: $sequence,
        intent: $intent,
        file_pattern: $file_pattern,
        sample_prompts: [$sample],
        count: $count,
        first_seen: $first_seen,
        last_seen: $last_seen,
        suggested: false
      }' >> "${PATTERNS_FILE}"
  fi
done

# --- Step 8: Expire old patterns ---
CUTOFF="$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d 2>/dev/null || echo '')"
if [ -n "${CUTOFF}" ] && [ -f "${PATTERNS_FILE}" ]; then
  TEMP_PAT="${PATTERNS_FILE}.tmp"
  jq -c "select(.last_seen >= \"${CUTOFF}\")" "${PATTERNS_FILE}" > "${TEMP_PAT}" 2>/dev/null || true
  mv "${TEMP_PAT}" "${PATTERNS_FILE}"
fi

# --- Step 9: Delete original session log ---
rm -f "${LOG_FILE}"
