#!/usr/bin/env bash
# Red test for US-1: validate.sh --descriptors lane.
# Exercises: invalid frontmatter exits 1, valid exits 0, --all flag, existing 9-section lane unchanged.
# Run: bash scripts/test-validate-descriptors.sh   (exit 0 = PASS; 1 = FAIL)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap "rm -rf '$TMP'" EXIT

FAILED=0
PASSED=0

pass() { echo "  PASS: $1"; PASSED=$((PASSED+1)); }
fail() { echo "  FAIL: $1"; FAILED=$((FAILED+1)); }

echo "Test 1: validate.sh --descriptors flag exists and returns valid exit code"
out=$(bash "$ROOT/scripts/validate.sh" --descriptors --help 2>&1) || true
if echo "$out" | grep -qE 'descriptors|--all|incremental'; then
  pass "Test 1 — flag recognized"
else
  fail "Test 1 — --descriptors flag not implemented (out: ${out:0:200})"
fi

echo "Test 2: valid descriptor sample exits 0"
mkdir -p "$TMP/specs/sample"
cat > "$TMP/specs/sample/spec.md" <<'EOF'
---
kind: spec
path: .dt-handoff/sample/spec.md
contentHash: sha256:abc123
createdAt: 2026-05-23T00:00:00Z
producer: analyst
sizeBytes: 100
retention: permanent
expiresAt: null
status: PASSED
---
# Sample
EOF
if bash "$ROOT/scripts/validate.sh" --descriptors --target="$TMP/specs/sample/spec.md" >/dev/null 2>&1; then
  pass "Test 2 — valid frontmatter accepted"
else
  fail "Test 2 — valid frontmatter rejected (should pass)"
fi

echo "Test 3: invalid descriptor sample (missing required field) exits 1"
cat > "$TMP/specs/sample/bad.md" <<'EOF'
---
kind: spec
path: .dt-handoff/sample/bad.md
status: PASSED
---
# Missing required fields
EOF
if bash "$ROOT/scripts/validate.sh" --descriptors --target="$TMP/specs/sample/bad.md" >/dev/null 2>&1; then
  fail "Test 3 — invalid frontmatter accepted (should fail)"
else
  pass "Test 3 — invalid frontmatter rejected"
fi

echo "Test 4: invalid status enum value exits 1"
cat > "$TMP/specs/sample/badstatus.md" <<'EOF'
---
kind: spec
path: .dt-handoff/sample/badstatus.md
contentHash: sha256:abc123
createdAt: 2026-05-23T00:00:00Z
producer: analyst
sizeBytes: 100
retention: permanent
expiresAt: null
status: INVALID_ENUM_VALUE
---
EOF
if bash "$ROOT/scripts/validate.sh" --descriptors --target="$TMP/specs/sample/badstatus.md" >/dev/null 2>&1; then
  fail "Test 4 — bad status enum accepted (should fail)"
else
  pass "Test 4 — bad status enum rejected"
fi

echo "Test 5: JSON file with _descriptor key validates"
cat > "$TMP/specs/sample/prd.json" <<'EOF'
{
  "_descriptor": {
    "kind": "prd",
    "path": ".dt-handoff/sample/prd.json",
    "contentHash": "sha256:abc123",
    "createdAt": "2026-05-23T00:00:00Z",
    "producer": "ralph",
    "sizeBytes": 200,
    "retention": "permanent",
    "expiresAt": null,
    "status": "pending"
  },
  "stories": []
}
EOF
if bash "$ROOT/scripts/validate.sh" --descriptors --target="$TMP/specs/sample/prd.json" >/dev/null 2>&1; then
  pass "Test 5 — JSON _descriptor accepted"
else
  fail "Test 5 — JSON _descriptor rejected (should pass)"
fi

echo "Test 6: existing 9-section lane unchanged (no --descriptors flag)"
# Just confirm regular invocation still exits 0 on the current repo
if bash "$ROOT/scripts/validate.sh" >/dev/null 2>&1; then
  pass "Test 6 — existing lane unchanged"
else
  fail "Test 6 — existing lane broken (regression)"
fi

echo ""
echo "Summary: $PASSED passed / $FAILED failed"
exit $FAILED
