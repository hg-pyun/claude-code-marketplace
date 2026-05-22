#!/usr/bin/env bash
# Local strict validation gate for claude-code-marketplace (hg-pyun-plugins).
# Run: bash scripts/validate.sh   (exit 0 = PASS; 1 = any failure)
#
# Checks:
#   0. marketplace.json is valid JSON
#   1. Plugin count equals 1
#   2. Orphan check: every entry has a directory; every directory has an entry
#   3. Per-plugin version sync between plugin.json and marketplace.json
#   4. Per-plugin `claude plugin validate --strict .` PASS
#   5. Canonical-version gate (only YYYY.MM.DD[.N] accepted)
#   6. 9-section XML house-style presence on every SKILL.md and command md
#      (anchored regex; fenced code blocks stripped to avoid false positives)
#
# README.md files are excluded from the 9-section check.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE="$ROOT/.claude-plugin/marketplace.json"
FAILED=0

# 0. JSON sanity
jq empty "$MARKETPLACE" 2>/dev/null || { echo "FAIL: $MARKETPLACE is invalid JSON"; exit 1; }

# 1. Plugin count
COUNT=$(jq '.plugins | length' "$MARKETPLACE")
if [ "$COUNT" != "1" ]; then
  echo "FAIL: expected 1 plugin in marketplace, got $COUNT"
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
  if ! ( cd "$dir" && claude plugin validate --strict . ); then
    echo "FAIL: claude plugin validate --strict failed for $name (cwd=$dir)"
    FAILED=1
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
  echo "PASS: marketplace + 1 plugin validated"
fi

exit $FAILED
