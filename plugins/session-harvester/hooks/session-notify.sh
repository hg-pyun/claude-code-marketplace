#!/bin/sh
# Session Harvester — Session Start Notifier
# Triggered by: SessionStart hook
# Checks for pending unseen patterns and injects a notification into Claude's context.

set -e

# --- Resolve paths ---
DATA_DIR="${CLAUDE_PLUGIN_DATA:-${HOME}/.claude/plugin-data/session-harvester}"
PATTERNS_FILE="${DATA_DIR}/patterns.jsonl"
PENDING_FILE="${DATA_DIR}/pending_analysis.json"

# --- Check prerequisites ---
if ! command -v jq > /dev/null 2>&1; then
  exit 0
fi

if [ ! -f "${PATTERNS_FILE}" ]; then
  exit 0
fi

# --- Count unseen patterns ---
UNSEEN_COUNT="$(jq -s '[.[] | select(.suggested == false)] | length' "${PATTERNS_FILE}" 2>/dev/null || echo 0)"

if [ "${UNSEEN_COUNT}" -eq 0 ]; then
  exit 0
fi

# --- Build notification text ---
# Get top patterns for preview
TOP_PATTERNS="$(jq -rs '
  [.[] | select(.suggested == false)]
  | sort_by(-.count)
  | .[0:3]
  | map("  - \(.sequence) (\(.count)회 반복)")
  | join("\n")
' "${PATTERNS_FILE}" 2>/dev/null || echo '')"

# Output to stdout — Claude Code injects this into context
cat <<EOF
[Session Harvester] 이전 세션에서 ${UNSEEN_COUNT}개의 반복 작업 패턴이 감지되었습니다.
${TOP_PATTERNS}
\`/harvest\`를 실행하면 상세 분석 리포트를 확인하고, 스킬/서브에이전트/Hook으로 변환할 수 있습니다.
EOF
