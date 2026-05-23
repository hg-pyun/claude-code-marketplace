#!/usr/bin/env bash
# Cleanup session/day retention artifacts under .specs/<slug>/.
# Run (from the project that owns the .specs/ tree):
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/cleanup.sh" --slug=<slug>           Remove session + expired day files for one slug.
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/cleanup.sh" --all                   Same, but for every slug under .specs/.
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/cleanup.sh" --slug=<slug> --dry-run List targets without removing.
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/cleanup.sh" --help                  Usage.
#
# Skips: retention=permanent (never removed automatically), files lacking a parseable descriptor.
# SPECS_ROOT env var overrides the default .specs/ root (used by tests).
# Default: $PWD/.specs — the caller's working directory, where ralph/team/autopilot
# write their .specs/ tree. Script location is intentionally NOT used to anchor SPECS_ROOT,
# because the plugin is installed under a cache dir unrelated to the user's project.

set -uo pipefail

SPECS_ROOT="${SPECS_ROOT:-$PWD/.specs}"

SLUG=""
ALL=false
DRY_RUN=false
SHOW_HELP=false

for arg in "$@"; do
  case "$arg" in
    --slug=*)  SLUG="${arg#*=}" ;;
    --all)     ALL=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h) SHOW_HELP=true ;;
  esac
done

# Path-traversal guard: slug must be a simple kebab-case identifier (no .. / / etc).
if [ -n "$SLUG" ] && ! [[ "$SLUG" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "cleanup: invalid slug '$SLUG' — must match [a-zA-Z0-9_-]+"
  exit 1
fi

if [ "$SHOW_HELP" = "true" ] || { [ -z "$SLUG" ] && [ "$ALL" != "true" ]; }; then
  cat <<'USAGE'
cleanup.sh usage:
  --slug=<slug>     Process one slug under .specs/.
  --all             Process every slug under .specs/.
  --dry-run         List targets only; do not remove.
  --help            This message.

Behavior: removes files whose descriptor declares retention=session or
retention=day with an expiresAt in the past. Files with retention=permanent
are always preserved. Files without a parseable descriptor are skipped.
USAGE
  [ "$SHOW_HELP" = "true" ] && exit 0
  exit 1
fi

_now_iso() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
NOW_ISO="$(_now_iso)"

# Echo "retention\texpiresAt" for one file (.md or .json). Empty if no descriptor.
_read_descriptor() {
  local file="$1"
  case "$file" in
    *.md)
      local fm
      fm=$(awk 'BEGIN{n=0} /^---$/{n++; if(n==2) exit; next} n==1{print}' "$file" 2>/dev/null)
      [ -z "$fm" ] && return
      local ret exp
      ret=$(printf '%s\n' "$fm" | awk -F: '$1=="retention" {sub(/^[ \t]+/, "", $2); print $2; exit}')
      exp=$(printf '%s\n' "$fm" | awk -F: '$1=="expiresAt" {sub(/^[ \t]+/, "", $2); print $2; exit}')
      printf '%s\t%s\n' "${ret:-}" "${exp:-}"
      ;;
    *.json)
      jq empty "$file" 2>/dev/null || return
      jq -r '"\(._descriptor.retention // "")\t\(._descriptor.expiresAt // "")"' "$file" 2>/dev/null
      ;;
    *.jsonl|*.txt|*.lock)
      # Stream / log / lock files: no descriptor; skip
      ;;
  esac
}

# 0 = remove, 1 = keep
_should_remove() {
  local retention="$1" expires="$2"
  case "$retention" in
    session)
      return 0
      ;;
    day)
      [ -z "$expires" ] && return 1
      [ "$expires" = "null" ] && return 1
      # Lexicographic compare of ISO8601 strings works for chronological order.
      if [[ "$expires" < "$NOW_ISO" ]]; then
        return 0
      fi
      return 1
      ;;
    permanent|"")
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

_process_slug() {
  local slug_dir="$1" removed=0 listed=0
  if [ ! -d "$slug_dir" ]; then
    echo "cleanup: skip — $slug_dir not a directory"
    return
  fi
  local file desc retention expires
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    desc=$(_read_descriptor "$file")
    [ -z "$desc" ] && continue
    retention="${desc%%$'\t'*}"
    expires="${desc##*$'\t'}"
    if _should_remove "$retention" "$expires"; then
      if [ "$DRY_RUN" = "true" ]; then
        echo "  WOULD REMOVE: $file (retention=$retention expiresAt=$expires)"
        listed=$((listed+1))
      else
        rm -f "$file" && removed=$((removed+1))
      fi
    fi
  done < <(find "$slug_dir" -type f \( -name '*.md' -o -name '*.json' \))
  if [ "$DRY_RUN" = "true" ]; then
    echo "cleanup ($slug_dir): $listed file(s) would be removed (dry-run)"
  else
    echo "cleanup ($slug_dir): $removed file(s) removed"
  fi
}

if [ "$ALL" = "true" ]; then
  for d in "$SPECS_ROOT"/*/; do
    [ -d "$d" ] && _process_slug "${d%/}"
  done
else
  _process_slug "$SPECS_ROOT/$SLUG"
fi
