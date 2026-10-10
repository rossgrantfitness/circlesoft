#!/bin/sh
# Rebuild nothing; just re-import and capture all existing red_proto_*.glb.
cd "$(dirname "$0")/../../.." || exit 1
godot --headless --path . --import >/dev/null 2>&1
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
    -s res://tests/visual/capture_red_prototypes.gd 2>&1 | grep -v "leaked\|~Utilities\|ALSA\|Utilities"
