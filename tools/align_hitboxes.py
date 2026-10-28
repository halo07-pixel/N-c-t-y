#!/usr/bin/env python3
"""Pulls each move's hitbox to where the rig's weapon tip is in the strike pose, so what you
see is what hits. Reads the `REACH` lines printed by tools/rig_reach.gd.

    godot --headless --path . -s tools/rig_reach.gd | python3 tools/align_hitboxes.py [--write]

Without --write it only reports. The far edge of the box (in the swing direction) is moved to
TIP_MARGIN past the tip when it is off by more than the tolerance; the near edge stays put.
"""
import re
import sys

TIP_MARGIN = 3.0
MAX_SHORT = 5.0   # hitbox may reach this far past the blade
MIN_SHORT = -1.0  # ... and the blade may poke this far out of the box
MIN_SIZE = (10.0, 8.0)
SLOT_DIRECTION = {
    "ground_neutral": "neutral", "ground_forward": "forward", "ground_up": "up", "ground_down": "down",
    "air_neutral": "neutral", "air_forward": "forward", "air_up": "up", "air_down": "down",
}


def parse_vec(text):
    a, b = re.search(r"\(([^,]+),([^)]+)\)", text).groups()
    return float(a), float(b)


def fmt(value):
    return ("%.1f" % value).rstrip("0").rstrip(".")


def aligned(box, tip, direction):
    x0, y0, x1, y1 = box
    tx, ty = tip
    if direction == "up":
        gap = ty - y0
        if not (MIN_SHORT <= gap <= MAX_SHORT):
            y0 = ty - TIP_MARGIN
        x0, x1 = min(x0, tx - 2), max(x1, tx + 2)
    elif direction == "down":
        gap = y1 - ty
        if not (MIN_SHORT <= gap <= MAX_SHORT):
            y1 = ty + TIP_MARGIN
        x0, x1 = min(x0, tx - 2), max(x1, tx + 2)
        if tx > x1 - 0.5:
            x1 = tx + TIP_MARGIN
    else:
        gap = x1 - tx
        if not (MIN_SHORT <= gap <= MAX_SHORT):
            x1 = tx + TIP_MARGIN
        y0, y1 = min(y0, ty - 2), max(y1, ty + 2)
    if x1 - x0 < MIN_SIZE[0]:
        x1 = x0 + MIN_SIZE[0]
    if y1 - y0 < MIN_SIZE[1]:
        y1 = y0 + MIN_SIZE[1]
    return x0, y0, x1, y1


def main():
    write = "--write" in sys.argv
    tips = {}
    for line in sys.stdin:
        if line.startswith("REACH "):
            _, character, slot, x, y = line.split()
            tips[(character, slot)] = (float(x), float(y))
    for (character, slot), tip in tips.items():
        path = "resources/movesets/%s_moveset.tres" % character
        text = open(path, encoding="utf-8").read()
        pattern = re.compile(r'(\[sub_resource type="Resource" id="M_%s"\].*?)(?=\n\[|\Z)' % slot, re.S)
        match = pattern.search(text)
        block = match.group(1)
        size = parse_vec(re.search(r"hitbox_size = (Vector2\([^)]*\))", block).group(1))
        offset = parse_vec(re.search(r"hitbox_offset = (Vector2\([^)]*\))", block).group(1))
        box = (offset[0] - size[0] / 2, offset[1] - size[1] / 2, offset[0] + size[0] / 2, offset[1] + size[1] / 2)
        new = aligned(box, tip, SLOT_DIRECTION[slot])
        if all(abs(a - b) < 0.05 for a, b in zip(box, new)):
            continue
        new_size = (new[2] - new[0], new[3] - new[1])
        new_offset = ((new[0] + new[2]) / 2, (new[1] + new[3]) / 2)
        print("%-10s %-15s size %s -> (%s, %s)  offset %s -> (%s, %s)" % (
            character, slot, size, fmt(new_size[0]), fmt(new_size[1]), offset, fmt(new_offset[0]), fmt(new_offset[1])))
        if write:
            block2 = re.sub(r"hitbox_size = Vector2\([^)]*\)", "hitbox_size = Vector2(%s, %s)" % (fmt(new_size[0]), fmt(new_size[1])), block)
            block2 = re.sub(r"hitbox_offset = Vector2\([^)]*\)", "hitbox_offset = Vector2(%s, %s)" % (fmt(new_offset[0]), fmt(new_offset[1])), block2)
            text = text.replace(block, block2)
            open(path, "w", encoding="utf-8").write(text)


main()
