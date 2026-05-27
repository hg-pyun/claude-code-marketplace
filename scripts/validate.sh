#!/usr/bin/env bash
# Local strict validation gate for claude-code-marketplace (hg-pyun-plugins).
# Run: bash scripts/validate.sh                          (default lane; exit 0 = PASS; 1 = failure)
#      bash scripts/validate.sh --descriptors            (descriptors lane only; incremental default)
#      bash scripts/validate.sh --descriptors --all      (full .specs/ traversal)
#      bash scripts/validate.sh --descriptors --target=<path>  (single-file check)
#      bash scripts/validate.sh --descriptors --help     (lane usage)
#
# Default checks (no flag):
#   0. marketplace.json is valid JSON
#   1. Plugin count equals 2
#   2. Orphan check: every entry has a directory; every directory has an entry
#   3. Per-plugin version sync between plugin.json and marketplace.json
#   4. Per-plugin `claude plugin validate --strict .` PASS
#   5. Canonical-version gate (only YYYY.MM.DD[.N] accepted)
#   6. 9-section XML house-style presence on every SKILL.md and command md
#      (anchored regex; fenced code blocks stripped to avoid false positives)
#
# Descriptors lane (--descriptors):
#   - .md files: 8-field OMC descriptor frontmatter + status enum
#   - .json files: `_descriptor` reserved key with same schema
#   - Enums: kind, retention, status
#
# README.md files are excluded from the 9-section check.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
FAILED=0

# ----- Argument parsing (descriptors lane dispatch) --------------------------
DESCRIPTORS_MODE=false
DESCRIPTORS_ALL=false
DESCRIPTORS_TARGET=""
DESCRIPTORS_HELP=false
for arg in "$@"; do
  case "$arg" in
    --descriptors) DESCRIPTORS_MODE=true ;;
    --all)         DESCRIPTORS_ALL=true ;;
    --target=*)    DESCRIPTORS_TARGET="${arg#*=}" ;;
    --help|-h)     DESCRIPTORS_HELP=true ;;
  esac
done

# ----- Descriptors lane helpers ----------------------------------------------
DESC_KIND_ENUM="spec plan prd advisor notepad state handoff trace"
DESC_RETENTION_ENUM="session day permanent"
DESC_STATUS_ENUM="pending approved complete failed cancelled PASSED EARLY_EXIT HARD_CAP"
DESC_REQUIRED_FIELDS="kind path contentHash createdAt producer sizeBytes retention expiresAt status"

_desc_enum_contains() {
  # _desc_enum_contains "<enum-list>" "<value>" → 0 if member, 1 otherwise
  local enum="$1" value="$2" tok
  for tok in $enum; do
    [ "$tok" = "$value" ] && return 0
  done
  return 1
}

_desc_check_md() {
  # _desc_check_md <file> → echoes errors; exit 0 if clean, 1 if any error
  local file="$1" err=0
  # Extract frontmatter block (between first two '---' lines at file start)
  local fm
  fm=$(awk 'BEGIN{n=0} /^---$/{n++; if(n==2) exit; next} n==1{print}' "$file")
  if [ -z "$fm" ]; then
    echo "  $file: missing YAML frontmatter"
    return 1
  fi
  local field val
  for field in $DESC_REQUIRED_FIELDS; do
    val=$(printf '%s\n' "$fm" | awk -v k="$field" -F: '$1==k {sub(/^[ \t]+/, "", $2); print $2; exit}')
    if [ -z "$val" ] && [ "$field" != "expiresAt" ]; then
      echo "  $file: missing required field '$field'"
      err=1
    fi
  done
  local kind retention status
  kind=$(printf '%s\n' "$fm" | awk -F: '$1=="kind" {sub(/^[ \t]+/, "", $2); print $2; exit}')
  retention=$(printf '%s\n' "$fm" | awk -F: '$1=="retention" {sub(/^[ \t]+/, "", $2); print $2; exit}')
  status=$(printf '%s\n' "$fm" | awk -F: '$1=="status" {sub(/^[ \t]+/, "", $2); print $2; exit}')
  if [ -n "$kind" ] && ! _desc_enum_contains "$DESC_KIND_ENUM" "$kind"; then
    echo "  $file: invalid kind '$kind' (expected one of: $DESC_KIND_ENUM)"
    err=1
  fi
  if [ -n "$retention" ] && ! _desc_enum_contains "$DESC_RETENTION_ENUM" "$retention"; then
    echo "  $file: invalid retention '$retention' (expected one of: $DESC_RETENTION_ENUM)"
    err=1
  fi
  if [ -n "$status" ] && ! _desc_enum_contains "$DESC_STATUS_ENUM" "$status"; then
    echo "  $file: invalid status '$status' (expected one of: $DESC_STATUS_ENUM)"
    err=1
  fi
  return $err
}

_desc_check_json() {
  # _desc_check_json <file> → echoes errors; 0 clean, 1 error
  local file="$1" err=0
  if ! jq empty "$file" 2>/dev/null; then
    echo "  $file: invalid JSON"
    return 1
  fi
  if ! jq -e '._descriptor' "$file" >/dev/null 2>&1; then
    echo "  $file: missing _descriptor key"
    return 1
  fi
  local field val
  for field in $DESC_REQUIRED_FIELDS; do
    if [ "$field" = "expiresAt" ]; then continue; fi
    val=$(jq -r --arg f "$field" '._descriptor[$f] // empty' "$file")
    if [ -z "$val" ]; then
      echo "  $file: _descriptor missing required field '$field'"
      err=1
    fi
  done
  local kind retention status
  kind=$(jq -r '._descriptor.kind // empty' "$file")
  retention=$(jq -r '._descriptor.retention // empty' "$file")
  status=$(jq -r '._descriptor.status // empty' "$file")
  if [ -n "$kind" ] && ! _desc_enum_contains "$DESC_KIND_ENUM" "$kind"; then
    echo "  $file: invalid _descriptor.kind '$kind'"
    err=1
  fi
  if [ -n "$retention" ] && ! _desc_enum_contains "$DESC_RETENTION_ENUM" "$retention"; then
    echo "  $file: invalid _descriptor.retention '$retention'"
    err=1
  fi
  if [ -n "$status" ] && ! _desc_enum_contains "$DESC_STATUS_ENUM" "$status"; then
    echo "  $file: invalid _descriptor.status '$status'"
    err=1
  fi
  return $err
}

_desc_pick_targets() {
  # Echo a newline-separated list of files to check
  if [ -n "$DESCRIPTORS_TARGET" ]; then
    echo "$DESCRIPTORS_TARGET"
    return
  fi
  local base
  if [ "$DESCRIPTORS_ALL" = "true" ]; then
    find "$ROOT/.specs" -type f \( -name '*.md' -o -name '*.json' \) 2>/dev/null | grep -v 'research-' || true
    return
  fi
  # Incremental: git merge-base HEAD origin/main, fallback HEAD~1
  base=$(cd "$ROOT" && git merge-base HEAD origin/main 2>/dev/null || git rev-parse HEAD~1 2>/dev/null || echo "")
  if [ -z "$base" ]; then
    return  # no base; nothing to check incrementally
  fi
  cd "$ROOT" && git diff --name-only --diff-filter=AM "$base"..HEAD -- '.specs/**/*.md' '.specs/**/*.json' 2>/dev/null | grep -v 'research-' || true
}

run_descriptors_lane() {
  if [ "$DESCRIPTORS_HELP" = "true" ]; then
    echo "descriptors lane usage:"
    echo "  --descriptors                  incremental default (git merge-base HEAD origin/main, fallback HEAD~1)"
    echo "  --descriptors --all            full .specs/ traversal"
    echo "  --descriptors --target=<path>  single-file check"
    echo ""
    echo "Schema: 8 required fields (kind, path, contentHash, createdAt, producer, sizeBytes, retention, expiresAt) + status."
    echo "Enums: kind={$DESC_KIND_ENUM}, retention={$DESC_RETENTION_ENUM}, status={$DESC_STATUS_ENUM}"
    return 0
  fi
  local targets count=0 errs=0
  targets=$(_desc_pick_targets)
  if [ -z "$targets" ]; then
    echo "descriptors lane: no targets (incremental mode, no .specs/ changes)"
    return 0
  fi
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ ! -f "$f" ] && continue
    count=$((count+1))
    case "$f" in
      *.md)   _desc_check_md "$f" || errs=$((errs+1)) ;;
      *.json) _desc_check_json "$f" || errs=$((errs+1)) ;;
    esac
  done <<< "$targets"
  if [ "$errs" = "0" ]; then
    echo "descriptors lane: PASS ($count file(s) checked)"
    return 0
  fi
  echo "descriptors lane: FAIL ($errs of $count file(s) failed)"
  return 1
}

if [ "$DESCRIPTORS_MODE" = "true" ]; then
  if run_descriptors_lane; then exit 0; else exit 1; fi
fi

# Re-enable strict-exit for the default lane below
set -e

# 0. JSON sanity
jq empty "$MARKETPLACE" 2>/dev/null || { echo "FAIL: $MARKETPLACE is invalid JSON"; exit 1; }

# 1. Plugin count
COUNT=$(jq '.plugins | length' "$MARKETPLACE")
if [ "$COUNT" != "2" ]; then
  echo "FAIL: expected 2 plugins in marketplace, got $COUNT"
  FAILED=1
fi

# 2. Orphan check: every entry has a dir; every dir has an entry
# Read names line-by-line (preserves whitespace, prevents glob expansion)
while IFS= read -r name; do
  [ -z "$name" ] && continue
  if [ ! -d "$ROOT/plugins/$name" ]; then
    echo "FAIL: marketplace entry '$name' has no directory"
    FAILED=1
  fi
done < <(jq -r '.plugins[].name' "$MARKETPLACE")
for dir in "$ROOT"/plugins/*/; do
  name=$(basename "$dir")
  if ! jq -e --arg n "$name" '.plugins[] | select(.name==$n)' "$MARKETPLACE" >/dev/null 2>&1; then
    echo "FAIL: directory '$name' has no marketplace entry"
    FAILED=1
  fi
done

# 3-5. Version sync + sentinel rejection + claude plugin validate --strict per plugin
for dir in "$ROOT"/plugins/*/; do
  pjson="$dir/.claude-plugin/plugin.json"
  if [ ! -f "$pjson" ]; then
    echo "FAIL: missing $pjson"
    FAILED=1
    continue
  fi
  if ! jq empty "$pjson" 2>/dev/null; then
    echo "FAIL: $pjson invalid JSON"
    FAILED=1
    continue
  fi
  name=$(jq -r .name "$pjson")
  ver=$(jq -r .version "$pjson")
  mver=$(jq -r --arg n "$name" '.plugins[] | select(.name==$n) | .version' "$MARKETPLACE")
  if [ "$ver" != "$mver" ]; then
    echo "FAIL: version mismatch $name plugin=$ver market=$mver"
    FAILED=1
  fi
  # Positive allowlist: only YYYY.MM.DD[.N] form is acceptable.
  # Catches any placeholder (e.g., 0.0.0-overhaul-pending, 0.0.0-wip, tbd) rather
  # than only the specific sentinel from one prior overhaul.
  if ! [[ "$ver" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}(\.[0-9]+)?$ ]]; then
    echo "FAIL: $name version '$ver' is not in canonical YYYY.MM.DD[.N] form"
    FAILED=1
  fi
  # claude plugin validate --strict, tolerating ONLY the known-benign
  # "plugin-root CLAUDE.md is not loaded as project context" warning. This repo
  # ships plugins/<name>/CLAUDE.md as an in-repo working guide (loaded via the
  # cwd CLAUDE.md hierarchy while developing here); that --strict warning is
  # about the installed-plugin scenario and is accepted. Any other finding —
  # an extra warning or any error — still fails the gate.
  if pv_out=$( cd "$dir" && claude plugin validate --strict . 2>&1 ); then
    : # strict passed cleanly
  else
    benign=$(printf '%s\n' "$pv_out" | grep -c 'CLAUDE\.md at the plugin root is not loaded' || true)
    warned=$(printf '%s\n' "$pv_out" | grep -oE 'Found [0-9]+ warning' | grep -oE '[0-9]+' | head -1 || true)
    errored=$(printf '%s\n' "$pv_out" | grep -ciE 'Found [0-9]+ error|[0-9]+ error\(s\)' || true)
    if [ "${benign:-0}" -ge 1 ] && [ "${warned:-0}" = "${benign:-0}" ] && [ "${errored:-0}" -eq 0 ]; then
      echo "NOTE: $name — strict OK except the accepted plugin-root CLAUDE.md warning (in-repo working guide)"
    else
      echo "FAIL: claude plugin validate --strict failed for $name (cwd=$dir)"
      printf '%s\n' "$pv_out"
      FAILED=1
    fi
  fi
done

# 6. Anchored 9-section gate (ERROR — contributes to non-zero exit)
SKILL_FILES=()
for f in "$ROOT"/plugins/*/skills/*/SKILL.md "$ROOT"/plugins/*/commands/*.md; do
  [ -f "$f" ] && SKILL_FILES+=("$f")
done

for f in "${SKILL_FILES[@]}"; do
  # Strip fenced code blocks before grep so example XML inside ```...``` does not
  # produce false positives.
  STRIPPED=$(sed '/^```/,/^```/d' "$f")
  for sec in Purpose Use_When Do_Not_Use_When Why_This_Exists Execution_Policy Steps Tool_Usage Examples Final_Checklist; do
    # Anchored at line start; tag must end with > or be followed by attributes/space.
    # Use printf instead of echo to avoid backslash-mangling on some shells.
    if ! printf '%s\n' "$STRIPPED" | grep -qE "^<$sec>($|[ >])"; then
      echo "FAIL: $f missing <$sec>"
      FAILED=1
    fi
  done
done

if [ "$FAILED" = "0" ]; then
  echo "PASS: marketplace + 2 plugins validated"
fi

exit $FAILED
