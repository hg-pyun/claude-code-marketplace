#!/usr/bin/env bash
# Red test for US-4: plugins/dev-tools/scripts/cleanup.sh.
# Exercises: --slug, --all, --dry-run; retention session/day removed, permanent preserved.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CLEANUP="$HERE/cleanup.sh"
TMP="$(mktemp -d)"
trap "rm -rf '$TMP'" EXIT

PASSED=0
FAILED=0

pass() { echo "  PASS: $1"; PASSED=$((PASSED+1)); }
fail() { echo "  FAIL: $1"; FAILED=$((FAILED+1)); }

# Fixture: a fake .dt-handoff root with one slug containing mixed retention files.
mkdir -p "$TMP/.dt-handoff/test-slug/artifacts/ask" "$TMP/.dt-handoff/test-slug/state" "$TMP/.dt-handoff/test-slug/notepads"

# session-retention advisor file (should be removed)
cat > "$TMP/.dt-handoff/test-slug/artifacts/ask/architect-2026-05-23T00-00-00.md" <<'EOF'
---
kind: advisor
path: artifacts/ask/architect-2026-05-23T00-00-00.md
contentHash: sha256:aa
createdAt: 2026-05-23T00:00:00Z
producer: architect
sizeBytes: 50
retention: session
expiresAt: null
status: complete
---
findings
EOF

# permanent spec.md (should be preserved)
cat > "$TMP/.dt-handoff/test-slug/spec.md" <<'EOF'
---
kind: spec
path: spec.md
contentHash: sha256:bb
createdAt: 2026-05-23T00:00:00Z
producer: analyst
sizeBytes: 50
retention: permanent
expiresAt: null
status: PASSED
---
spec body
EOF

# day-retention state.json with expired expiresAt (should be removed)
cat > "$TMP/.dt-handoff/test-slug/state/ralph.json" <<'EOF'
{
  "_descriptor": {
    "kind": "state",
    "path": "state/ralph.json",
    "contentHash": "sha256:cc",
    "createdAt": "2026-05-20T00:00:00Z",
    "producer": "ralph",
    "sizeBytes": 30,
    "retention": "day",
    "expiresAt": "2026-05-21T00:00:00Z",
    "status": "complete"
  }
}
EOF

# day-retention with future expiresAt (should be preserved)
cat > "$TMP/.dt-handoff/test-slug/state/team.json" <<'EOF'
{
  "_descriptor": {
    "kind": "state",
    "path": "state/team.json",
    "contentHash": "sha256:dd",
    "createdAt": "2026-05-23T00:00:00Z",
    "producer": "team",
    "sizeBytes": 30,
    "retention": "day",
    "expiresAt": "2099-01-01T00:00:00Z",
    "status": "complete"
  }
}
EOF

echo "Test 1: cleanup.sh exists and recognizes --help"
out=$(bash "$CLEANUP" --help 2>&1) || true
if echo "$out" | grep -qE 'slug|all|dry-run'; then
  pass "Test 1 — script recognized"
else
  fail "Test 1 — cleanup.sh not implemented or missing flags (out: ${out:0:200})"
fi

echo "Test 2: --dry-run --slug=test-slug lists session/expired but does NOT remove"
out=$(HANDOFF_ROOT="$TMP/.dt-handoff" bash "$CLEANUP" --slug=test-slug --dry-run 2>&1) || true
if [ -f "$TMP/.dt-handoff/test-slug/artifacts/ask/architect-2026-05-23T00-00-00.md" ] \
   && [ -f "$TMP/.dt-handoff/test-slug/state/ralph.json" ] \
   && echo "$out" | grep -q 'architect-2026-05-23' \
   && echo "$out" | grep -q 'ralph.json'; then
  pass "Test 2 — dry-run lists targets without removing"
else
  fail "Test 2 — dry-run misbehaved (out: ${out:0:300})"
fi

echo "Test 3: --slug=test-slug removes retention:session + expired retention:day"
HANDOFF_ROOT="$TMP/.dt-handoff" bash "$CLEANUP" --slug=test-slug >/dev/null 2>&1 || true
if [ ! -f "$TMP/.dt-handoff/test-slug/artifacts/ask/architect-2026-05-23T00-00-00.md" ] \
   && [ ! -f "$TMP/.dt-handoff/test-slug/state/ralph.json" ]; then
  pass "Test 3 — session/expired removed"
else
  fail "Test 3 — session or expired file remains"
fi

echo "Test 4: permanent (spec.md) and future-day (team.json) preserved"
if [ -f "$TMP/.dt-handoff/test-slug/spec.md" ] && [ -f "$TMP/.dt-handoff/test-slug/state/team.json" ]; then
  pass "Test 4 — permanent + future-day preserved"
else
  fail "Test 4 — permanent or future-day was incorrectly removed"
fi

echo ""
echo "Summary: $PASSED passed / $FAILED failed"
exit $FAILED
