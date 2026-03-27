#!/bin/sh
# Session Harvester — Structural Pattern Analyzer
# Triggered by: SessionEnd hook
# Reads session log, extracts tool sequences, detects patterns,
# saves pattern summaries, and deletes the original log.

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

TODAY="$(date +%Y-%m-%d)"
CUTOFF="$(date -v-90d +%Y-%m-%d 2>/dev/null || date -d '90 days ago' +%Y-%m-%d 2>/dev/null || echo '')"

# --- Helper: atomic write — validates jq succeeded before replacing ---
atomic_mv() {
  _src="$1" _dst="$2"
  if [ $? -eq 0 ] && [ -f "${_src}" ]; then
    mv "${_src}" "${_dst}"
  else
    rm -f "${_src}"
  fi
}

# --- Helper: hash with fallback ---
hash_seq() {
  _h="$(printf '%s' "$1" | shasum -a 256 2>/dev/null | cut -d' ' -f1)" && [ -n "${_h}" ] && printf '%s' "${_h}" && return
  _h="$(printf '%s' "$1" | sha256sum 2>/dev/null | cut -d' ' -f1)" && [ -n "${_h}" ] && printf '%s' "${_h}" && return
  printf '%s' "$1" | base64 2>/dev/null | tr -d '\n='
}

# --- Count tool calls ---
TOOL_COUNT="$(jq -s '[.[] | select(.event == "tool")] | length' "${LOG_FILE}" 2>/dev/null)" || TOOL_COUNT=0
if [ -z "${TOOL_COUNT}" ] || [ "${TOOL_COUNT}" -lt 5 ] 2>/dev/null; then
  # Short session: skip analysis, clean up, run expiry only
  rm -f "${LOG_FILE}"
  if [ -n "${CUTOFF}" ] && [ -f "${PATTERNS_FILE}" ]; then
    TEMP_FILE="${PATTERNS_FILE}.tmp.$$"
    jq -c "select(.last_seen >= \"${CUTOFF}\")" "${PATTERNS_FILE}" > "${TEMP_FILE}" 2>/dev/null \
      && mv "${TEMP_FILE}" "${PATTERNS_FILE}" \
      || rm -f "${TEMP_FILE}"
  fi
  exit 0
fi

# --- Step 1: Extract tool sequences ---
# Build sequences by splitting on "prompt" events (each prompt starts a new task unit).
# Tools between prompts form a sequence, abbreviated to first character.
SEQUENCES="$(jq -s '
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
          (.tool[:1] // "?") + "!"
        else
          .tool[:1] // "?"
        end
      )
      | join("-")
    )
  | map(select(length > 0))
' "${LOG_FILE}" 2>/dev/null)" || SEQUENCES="[]"

# --- Step 2: Count sequence frequencies (pure jq — no AWK/sort/uniq) ---
FREQ_JSON="$(printf '%s' "${SEQUENCES}" | jq '
  group_by(.)
  | map({sequence: .[0], count: length})
  | sort_by(-.count)
  | .[0:20]
' 2>/dev/null)" || FREQ_JSON="[]"

# --- Step 3: Extract file patterns ---
FILE_PATHS="$(jq -r '
  select(.event == "tool")
  | .input
  | (.file_path // .path // empty)
' "${LOG_FILE}" 2>/dev/null | sort -u)" || FILE_PATHS=""

# Abstract file paths to glob patterns: /path/to/file.ts → /path/to/*.ts
GLOB_PATTERNS=""
if [ -n "${FILE_PATHS}" ]; then
  GLOB_PATTERNS="$(printf '%s\n' "${FILE_PATHS}" \
    | sed -E 's|(.*/)[^/]+(\.[a-zA-Z]+)$|\1*\2|' \
    | sort -u \
    | head -10)"
fi

# --- Step 4: Detect retry loops (tool_error followed by same tool) ---
RETRY_LOOPS="$(jq -s '
  . as $arr
  | [range(1; ($arr | length))]
  | map(
      select(
        $arr[. - 1].event == "tool_error"
        and $arr[.].event == "tool"
        and $arr[. - 1].tool == $arr[.].tool
      )
      | $arr[.].tool
    )
  | group_by(.)
  | map({tool: .[0], count: length})
  | sort_by(-.count)
' "${LOG_FILE}" 2>/dev/null)" || RETRY_LOOPS="[]"

# --- Step 5: Extract sample prompts ---
SAMPLE_PROMPTS="$(jq -s '[.[] | select(.event == "prompt") | .prompt] | .[0:5]' "${LOG_FILE}" 2>/dev/null)" || SAMPLE_PROMPTS="[]"

# --- Step 6: Build pending analysis result ---
if [ -n "${GLOB_PATTERNS}" ]; then
  GLOB_JSON="$(printf '%s\n' "${GLOB_PATTERNS}" | jq -R 'select(length > 0)' | jq -s '.' 2>/dev/null)" || GLOB_JSON="[]"
else
  GLOB_JSON="[]"
fi

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
  }' > "${PENDING_FILE}" 2>/dev/null

# --- Step 7: Update cumulative patterns ---
touch "${PATTERNS_FILE}"

printf '%s' "${FREQ_JSON}" | jq -c '.[] | select(.count >= 2)' 2>/dev/null | while IFS= read -r SEQ_ENTRY; do
  SEQ="$(printf '%s' "${SEQ_ENTRY}" | jq -r '.sequence')"
  COUNT="$(printf '%s' "${SEQ_ENTRY}" | jq -r '.count')"
  SEQ_HASH="$(hash_seq "${SEQ}")"

  if [ -z "${SEQ_HASH}" ]; then
    continue
  fi

  # Check if pattern already exists
  EXISTING="$(jq -c "select(.id == \"${SEQ_HASH}\")" "${PATTERNS_FILE}" 2>/dev/null | head -1)"

  if [ -n "${EXISTING}" ]; then
    # Update existing: increment count, update last_seen
    OLD_COUNT="$(printf '%s' "${EXISTING}" | jq -r '.count')"
    NEW_COUNT=$((OLD_COUNT + COUNT))
    TEMP_PAT="${PATTERNS_FILE}.tmp.$$"
    if jq -c "if .id == \"${SEQ_HASH}\" then .count = ${NEW_COUNT} | .last_seen = \"${TODAY}\" else . end" \
      "${PATTERNS_FILE}" > "${TEMP_PAT}" 2>/dev/null; then
      mv "${TEMP_PAT}" "${PATTERNS_FILE}"
    else
      rm -f "${TEMP_PAT}"
    fi
  else
    # Create new pattern entry
    FIRST_PROMPT="$(printf '%s' "${SAMPLE_PROMPTS}" | jq -r '.[0] // ""' 2>/dev/null)"
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
      }' >> "${PATTERNS_FILE}" 2>/dev/null
  fi
done

# --- Step 8: Expire old patterns ---
if [ -n "${CUTOFF}" ] && [ -f "${PATTERNS_FILE}" ]; then
  TEMP_PAT="${PATTERNS_FILE}.tmp.$$"
  if jq -c "select(.last_seen >= \"${CUTOFF}\")" "${PATTERNS_FILE}" > "${TEMP_PAT}" 2>/dev/null; then
    mv "${TEMP_PAT}" "${PATTERNS_FILE}"
  else
    rm -f "${TEMP_PAT}"
  fi
fi

# --- Step 9: Delete original session log ---
rm -f "${LOG_FILE}"
