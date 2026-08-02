# phase3_scatter_topdown_sheets.py — W14.8 pick-gate sheets for the neutral field scatter.
#
# ONE SHEET PER BATTLE TYPE, not one for the class. Scatter is derived per type
# (phase3_backgrounds_topdown_picks.json is the brief), so the question the human answers is "does
# this prop look like it came off THIS ground", and that question is only answerable with the type's
# three props and its own plate in front of you at once. A 21-row class sheet would put the wheat
# field's sheaf next to the crater field's debris, which is a comparison nobody needs to make.
#
# Each cell is the candidate at sheet size, plus an inset of the same sprite at true on-field size
# composited over ITS OWN approved plate — the only test that matters for this class. Scatter's job
# is to break up a bare plate; a prop that vanishes into its own ground does nothing, and a prop
# that pops off it looks like a sticker. Both failures are invisible against the studio grey the
# render came back on and obvious in the inset.
#
# The plate crop is the APPROVED seed from phase3_backgrounds_topdown_picks.json, not whatever
# rendered last, so the inset is the real pairing that will ship.
#
# Run with the ComfyUI venv python from assets/pipeline/.
# Usage: phase3_scatter_topdown_sheets.py [battle_type ...]
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from phase3_backgrounds_topdown_batch import OUT as BG_OUT
from phase3_backgrounds_topdown_batch import stem as bg_stem
from phase3_scatter_topdown_batch import OUT, SCATTER, SEEDS, stem

CELL, LABEL_H, PAD, HDR = 520, 34, 10, 66
ROW_LABEL_W = 250
BG_PICKS = "phase3_backgrounds_topdown_picks.json"
# On-field long side in px at 1920x1080. Scatter reads smaller than a unit by design — it is ground
# dressing, and a prop that competes with a station for attention is the wrong size whatever it
# looks like. Exact numbers are the view's to set in W15; this is close enough to gate on.
FIELD = 90
PATCH = FIELD + 90              # enough plate around the prop to judge it against the texture


def plate_of(battle_type: str) -> Image.Image | None:
    """The approved plate for this battle type, centre-cropped at native pixel scale."""
    with open(BG_PICKS) as f:
        seed = json.load(f)["picks"][battle_type]
    path = f"{BG_OUT}/{bg_stem(battle_type, seed)}_00001_.png"
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert("RGB")
    cx, cy = im.width // 2, im.height // 2
    return im.crop((cx - PATCH // 2, cy - PATCH // 2, cx + PATCH // 2, cy + PATCH // 2))


def key(img: Image.Image) -> Image.Image:
    """Drop the studio background so the prop can sit on a plate, as it will in game."""
    a = np.asarray(img.convert("RGB")).astype(int)
    corners = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(corners, axis=0)
    alpha = (np.abs(a - bg).sum(axis=2) > 46).astype(np.uint8) * 255
    out = img.convert("RGBA")
    out.putalpha(Image.fromarray(alpha, "L"))
    return out


def inset(img: Image.Image, plate: Image.Image) -> Image.Image:
    s = key(img)
    ys, xs = np.where(np.asarray(s)[:, :, 3] > 0)
    if len(xs):
        s = s.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    s.thumbnail((FIELD, FIELD), Image.LANCZOS)
    patch = plate.copy()
    patch.paste(s, ((patch.width - s.width) // 2, (patch.height - s.height) // 2), s)
    ImageDraw.Draw(patch).rectangle((0, 0, patch.width - 1, patch.height - 1), outline=(90, 90, 90))
    return patch


def latest_seeds(pid: str) -> list:
    """The newest round rendered for this prop (rounds bump by +100, §4, and re-roll only the cells
    the human sent back — so resolve per row or a sheet can only ever show part of the roster)."""
    seen = sorted(int(f.rsplit("_s", 1)[1].split("_")[0])
                  for f in glob.glob(f"{OUT}/{stem(pid, 0)[:-1]}*_00001_.png"))
    return [s for s in seen if s // 100 == seen[-1] // 100] if seen else []


def sheet_for(battle_type: str) -> None:
    ids = [p for p, (t, _) in SCATTER.items() if t == battle_type]
    per_row = {pid: latest_seeds(pid) or SEEDS for pid in ids}
    seeds = max(per_row.values(), key=len)
    font = ImageFont.load_default(size=15)
    row_font = ImageFont.load_default(size=19)
    title_font = ImageFont.load_default(size=24)
    plate = plate_of(battle_type)

    sheet = Image.new("RGB", (ROW_LABEL_W + CELL * len(seeds),
                              HDR + (CELL + LABEL_H) * len(ids)), (24, 24, 24))
    d0 = ImageDraw.Draw(sheet)
    d0.text((PAD, 8), f"W14.8 field scatter: {battle_type}, {len(ids)} props top to bottom, each "
                      f"row showing its NEWEST round (the seed is on every cell)",
            fill=(255, 255, 255), font=title_font)
    d0.text((PAD, 40), "the patch in each cell is the prop at true on-field size on this battle's "
                       "own approved plate; reject it if it vanishes into the ground or looks "
                       "stuck on top of it"
                       + ("" if plate else "  [plate missing, no inset]"),
            fill=(170, 170, 170), font=font)

    for row, pid in enumerate(ids):
        y = HDR + (CELL + LABEL_H) * row
        d0.text((PAD, y + CELL // 2), pid.removeprefix("scat_"), fill=(230, 210, 160), font=row_font)
        for col, _ in enumerate(seeds):
            row_seeds = per_row[pid]
            if col >= len(row_seeds):
                continue
            st = stem(pid, row_seeds[col])
            path = f"{OUT}/{st}_00001_.png"
            cell = Image.new("RGB", (CELL, CELL + LABEL_H), (24, 24, 24))
            d = ImageDraw.Draw(cell)
            if not os.path.exists(path):
                label, colour = f"(no {st})", (150, 150, 150)
            else:
                label, colour = st, (220, 220, 220)
                img = Image.open(path)
                big = img.copy()
                big.thumbnail((CELL - 2 * PAD, CELL - 2 * PAD), Image.LANCZOS)
                cell.paste(big, ((CELL - big.width) // 2, (CELL - big.height) // 2))
                if plate:
                    ins = inset(img, plate)
                    cell.paste(ins, (CELL - ins.width - PAD, CELL - ins.height - PAD))
            tw = d.textlength(label, font=font)
            d.text(((CELL - tw) / 2, CELL + 2), label, fill=colour, font=font)
            sheet.paste(cell, (ROW_LABEL_W + CELL * col, y))

    out = f"../contact-sheets/phase3_scatter_topdown_{battle_type}.png"
    sheet.save(out)
    print(f"wrote {out}")


def main() -> None:
    types = sys.argv[1:] or sorted({t for t, _ in SCATTER.values()})
    os.makedirs("../contact-sheets", exist_ok=True)
    for t in types:
        sheet_for(t)


if __name__ == "__main__":
    main()
