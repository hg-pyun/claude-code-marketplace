#!/usr/bin/env bash
# install-statusline — install the canonical ccstatusline-based Claude Code status line.
# Merges the statusLine block into a target settings.json (preserving every other key)
# and writes the ccstatusline widget layout to ~/.config/ccstatusline/settings.json.
# Existing files are backed up to <file>.bak.<timestamp> before being changed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$SCRIPT_DIR/assets"

SCOPE="user"        # user | project
DRY_RUN="false"

for arg in "$@"; do
  case "$arg" in
    --scope=user)    SCOPE="user" ;;
    --scope=project) SCOPE="project" ;;
    --dry-run)       DRY_RUN="true" ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: python3 is required (used for safe JSON merge)" >&2
  exit 1
fi

case "$SCOPE" in
  user)    SETTINGS_PATH="$HOME/.claude/settings.json" ;;
  project) SETTINGS_PATH="$(pwd)/.claude/settings.json" ;;
esac
CCS_CONFIG_PATH="$HOME/.config/ccstatusline/settings.json"

TS="$(date +%Y%m%d-%H%M%S)"
backup() { [ -f "$1" ] && cp "$1" "$1.bak.$TS" && echo "  backup → $1.bak.$TS"; }

echo "==> install-statusline (scope=$SCOPE, dry-run=$DRY_RUN)"

# 1. Ensure ccstatusline is installed.
if command -v ccstatusline >/dev/null 2>&1; then
  echo "==> ccstatusline already installed: $(command -v ccstatusline)"
else
  echo "==> ccstatusline not found"
  if [ "$DRY_RUN" = "true" ]; then
    echo "  (dry-run) would run: npm install -g ccstatusline"
  elif command -v npm >/dev/null 2>&1; then
    echo "  installing via: npm install -g ccstatusline"
    npm install -g ccstatusline
  else
    echo "  warning: npm not found — install ccstatusline manually (npm i -g ccstatusline)" >&2
  fi
fi

# 2. Merge the statusLine block into the target settings.json.
echo "==> settings.json: $SETTINGS_PATH"
if [ "$DRY_RUN" = "true" ]; then
  echo "  (dry-run) would merge statusLine block, preserving all other keys"
else
  mkdir -p "$(dirname "$SETTINGS_PATH")"
  backup "$SETTINGS_PATH"
  STATUSLINE_ASSET="$ASSETS/statusline.settings.json" \
  TARGET="$SETTINGS_PATH" \
  python3 - <<'PY'
import json, os
target = os.environ["TARGET"]
with open(os.environ["STATUSLINE_ASSET"]) as f:
    block = json.load(f)
data = {}
if os.path.exists(target):
    with open(target) as f:
        content = f.read().strip()
        if content:
            data = json.loads(content)
data["statusLine"] = block
with open(target, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("  statusLine block written (other keys preserved)")
PY
fi

# 3. Write the ccstatusline widget layout.
echo "==> ccstatusline layout: $CCS_CONFIG_PATH"
if [ "$DRY_RUN" = "true" ]; then
  echo "  (dry-run) would write widget layout (existing file backed up first)"
else
  mkdir -p "$(dirname "$CCS_CONFIG_PATH")"
  backup "$CCS_CONFIG_PATH"
  cp "$ASSETS/ccstatusline.settings.json" "$CCS_CONFIG_PATH"
  echo "  widget layout written"
fi

echo "==> done. Restart Claude Code (or wait for the next refresh) to see the status line."
