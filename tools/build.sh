#!/bin/bash
# Builds the playable demo for Windows and Mac into builds/ (git-ignored):
#   builds/windows/LightsLeftOn.exe   (one file, data packed inside)
#   builds/mac/LightsLeftOn.zip       (unsigned .app inside; ad-hoc signed)
# Runs the headless tests first and stops if any fail. Needs `godot` on the PATH and the export
# templates (tools/get_export_templates.sh installs them).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="$ROOT/game"
GODOT="${GODOT:-godot}"

echo "== 1/4 Export templates"
"$ROOT/tools/get_export_templates.sh"

echo "== 2/4 Importing assets"
"$GODOT" --headless --path "$GAME" --import --quit >/dev/null 2>&1 || true

echo "== 3/4 Running the tests"
if ! "$GODOT" --headless --path "$GAME" -s res://tests/run_all.gd; then
  echo "TESTS FAILED. No build was made." >&2
  exit 1
fi

echo "== 4/4 Exporting"
mkdir -p "$ROOT/builds/windows" "$ROOT/builds/mac"
rm -f "$ROOT/builds/windows/LightsLeftOn.exe" "$ROOT/builds/mac/LightsLeftOn.zip"
"$GODOT" --headless --path "$GAME" --export-release "Windows Desktop" "$ROOT/builds/windows/LightsLeftOn.exe"
"$GODOT" --headless --path "$GAME" --export-release "macOS" "$ROOT/builds/mac/LightsLeftOn.zip"

echo
echo "Built:"
for f in "$ROOT/builds/windows/LightsLeftOn.exe" "$ROOT/builds/mac/LightsLeftOn.zip"; do
  if [ ! -s "$f" ]; then
    echo "MISSING: $f" >&2
    exit 1
  fi
  ls -lh "$f" | awk '{print $5 "  " $9}'
done
