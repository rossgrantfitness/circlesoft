#!/bin/bash
# Installs Godot 4 (headless-capable) in Claude Code cloud sessions,
# so agents can open the project and run the automated tests.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

GODOT_VERSION="4.5.1-stable"
BIN_DIR="$HOME/.local/bin"
GODOT_BIN="$BIN_DIR/godot"

if [ -x "$GODOT_BIN" ] && "$GODOT_BIN" --version 2>/dev/null | grep -q "^${GODOT_VERSION%-stable}"; then
  echo "Godot $GODOT_VERSION already installed."
else
  mkdir -p "$BIN_DIR"
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  curl -fsSL --retry 4 --retry-delay 2 -o "$TMP_DIR/godot.zip" "$URL"
  python3 -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "$TMP_DIR/godot.zip" "$TMP_DIR"
  install -m 755 "$TMP_DIR/Godot_v${GODOT_VERSION}_linux.x86_64" "$GODOT_BIN"
  echo "Installed Godot $GODOT_VERSION."
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Build Godot's import cache once so headless runs start clean.
"$GODOT_BIN" --headless --path "$CLAUDE_PROJECT_DIR/game" --import --quit >/dev/null 2>&1 || true
