#!/bin/bash
# Installs the Godot export templates the builds need (Windows x86_64 + macOS only), if missing.
# Safe to run again: it does nothing when the templates are already there.
# Downloads the 1.4 GB official template bundle to a scratch folder, extracts just the files we
# use, and deletes the download. Run it on build days, not at session start.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.5.1-stable}"
TEMPLATE_DIR_NAME="${GODOT_VERSION/-/.}"            # 4.5.1-stable -> 4.5.1.stable
if [ -n "${GODOT_TEMPLATES_DIR:-}" ]; then
  DEST="$GODOT_TEMPLATES_DIR"
elif [ "$(uname)" = "Darwin" ]; then
  DEST="$HOME/Library/Application Support/Godot/export_templates/$TEMPLATE_DIR_NAME"
else
  DEST="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$TEMPLATE_DIR_NAME"
fi
WANTED=(version.txt windows_release_x86_64.exe windows_debug_x86_64.exe macos.zip)

missing=0
for f in "${WANTED[@]}"; do
  [ -s "$DEST/$f" ] || missing=1
done
if [ "$missing" -eq 0 ]; then
  echo "Export templates already installed in $DEST"
  exit 0
fi

URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
echo "Downloading export templates (about 1.4 GB) ..."
curl -fL --retry 4 --retry-delay 2 -o "$TMP_DIR/templates.tpz" "$URL"
mkdir -p "$DEST"
python3 - "$TMP_DIR/templates.tpz" "$DEST" "${WANTED[@]}" <<'PY'
import sys, zipfile, os
archive, dest, *wanted = sys.argv[1:]
with zipfile.ZipFile(archive) as z:
    names = {os.path.basename(n): n for n in z.namelist() if not n.endswith("/")}
    for want in wanted:
        if want not in names:
            sys.exit("template file not found in the bundle: " + want)
        with z.open(names[want]) as src, open(os.path.join(dest, want), "wb") as out:
            while True:
                chunk = src.read(1 << 20)
                if not chunk:
                    break
                out.write(chunk)
        print("extracted", want)
PY
echo "Export templates installed in $DEST"
