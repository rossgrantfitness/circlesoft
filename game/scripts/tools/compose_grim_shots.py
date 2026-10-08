"""Puts the raw grim look-test captures side by side for Ross (docs/screenshots/grim_*.png).

Inputs: the pictures game/tests/visual/capture_grim_look.gd and capture_grim_red.gd wrote into one folder
(<shot>_<profile>.png and red_<grade>_<old|grim>_<view>.png). Output: labelled comparison sheets.

Run (Pillow only, no Blender):
    python3 game/scripts/tools/compose_grim_shots.py <raw_dir> <out_dir>
The game picture sits at (64, 36)-(1216, 684) inside the 1280x720 window (the rest is black bars); only that
part is kept.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

GAME_BOX = (64, 36, 1216, 684)
GAP = 12
LABEL_H = 44
BACK = (14, 14, 18)
TEXT = (232, 228, 214)


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:                       # older Pillow
        return ImageFont.load_default()


def game_part(path):
    return Image.open(path).convert("RGB").crop(GAME_BOX)


def labelled(images, labels, size=28):
    w, h = images[0].size
    sheet = Image.new("RGB", (w * len(images) + GAP * (len(images) - 1), h + LABEL_H), BACK)
    draw = ImageDraw.Draw(sheet)
    for i, (image, label) in enumerate(zip(images, labels)):
        x = i * (w + GAP)
        sheet.paste(image, (x, LABEL_H))
        draw.text((x + 12, 8), label, fill=TEXT, font=font(size))
    return sheet


def side_by_side(raw, name, out, title_a="CLASSIC (toy-box, as approved)", title_b="GRIM (look test)", suffix=""):
    a = game_part(os.path.join(raw, "%s_classic%s.png" % (name, suffix)))
    b = game_part(os.path.join(raw, "%s_grim%s.png" % (name, suffix)))
    return labelled([a, b], [title_a, title_b])


def red_zoom(raw, grade, model, view, zoom=1):
    image = Image.open(os.path.join(raw, "red_%s_%s_%s.png" % (grade, model, view))).convert("RGB")
    return image.resize((image.width // 2 * zoom, image.height // 2 * zoom), Image.NEAREST)


def red_sheet(raw, out):
    rows = []
    for grade, title in (("classic", "THE MODELS ALONE (no screen grade)"), ("grim", "UNDER THE GRIM GRADE (look-test scenes use the grim Red; the old Red is here only to compare)")):
        images, labels = [], []
        for view, view_name in (("front", "front"), ("34", "3/4")):
            for model, model_name in (("old", "OLD Red"), ("grim", "GRIM Red")):
                images.append(red_zoom(raw, grade, model, view))
                labels.append("%s, %s" % (model_name, view_name))
        rows.append((title, labelled(images, labels, 24)))
    # in game scale: Red cut out of the real room shots (same spot, same camera), zoomed 3x
    crops, crop_labels = [], []
    for profile, label in (("classic", "OLD Red in the square"), ("grim", "GRIM Red in the square")):
        shot = Image.open(os.path.join(raw, "square_east_%s.png" % profile)).convert("RGB")
        box = (640 - 110, 330 - 75, 640 + 110, 330 + 125)
        crops.append(shot.crop(box).resize((660, 600), Image.NEAREST))
        crop_labels.append(label + " (in-game camera, 3x)")
    rows.append(("IN-GAME SCALE", labelled(crops, crop_labels, 24)))
    width = max(r[1].width for r in rows)
    height = sum(r[1].height + LABEL_H for r in rows) + GAP * (len(rows) + 1)
    sheet = Image.new("RGB", (width + 2 * GAP, height), BACK)
    draw = ImageDraw.Draw(sheet)
    y = GAP
    for title, block in rows:
        draw.text((GAP, y + 6), title, fill=TEXT, font=font(30))
        y += LABEL_H
        sheet.paste(block, (GAP, y))
        y += block.height + GAP
    sheet.save(out)


def main():
    raw, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    side_by_side(raw, "square", out).save(os.path.join(out, "grim_square_compare.png"))
    side_by_side(raw, "square", out, suffix="_wide").save(os.path.join(out, "grim_square_wide_compare.png"))
    side_by_side(raw, "square_east", out).save(os.path.join(out, "grim_square_gate_compare.png"))
    side_by_side(raw, "checkpoint", out).save(os.path.join(out, "grim_checkpoint_compare.png"))
    side_by_side(raw, "checkpoint", out, suffix="_wide").save(os.path.join(out, "grim_checkpoint_wide_compare.png"))
    game_part(os.path.join(raw, "checkpoint_grim.png")).save(os.path.join(out, "grim_checkpoint.png"))
    side_by_side(raw, "battle", out).save(os.path.join(out, "grim_battle_compare.png"))
    red_sheet(raw, os.path.join(out, "grim_red_compare.png"))
    print("wrote the grim_*.png sheets in", out)


if __name__ == "__main__":
    main()
