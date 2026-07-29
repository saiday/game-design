# phase3_projectiles_topdown_sheets.py — W14.8 pick-gate sheet for the 8 flying-weapon sprites.
#
# One row per ammo type, one column per seed. There is no era axis: a projectile sprite is shared
# by every era that fires it (the mapping is in phase3_projectiles_topdown_batch.py's header), so
# unlike the unit sheets there is no cross-era coherence to read along the row. The row is purely
# four candidates for one slot.
#
# The inset is doing more work here than on any other class. A projectile ships at roughly 30px on
# the long side — smaller than a unit's head — and it is in motion, so the player never gets a
# still look at it. A shape that only separates from its neighbours at sheet size has failed.
#
# The insets composite over REAL PLATE CROPS, not flat colour swatches. A flat swatch is a weaker
# test than it looks: it only measures luminance contrast, and a sprite that clears a flat grey can
# still dissolve into cobble joints or crater rims, because what actually hides a 30px sprite is
# busy texture at its own spatial frequency. So each cell is composited over the lightest and the
# darkest plate in the set, which is the real worst case a projectile has to survive.
#
# Run with the ComfyUI venv python from assets/pipeline/.
# Usage: phase3_projectiles_topdown_sheets.py [proj_id ...]
import glob
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from phase3_backgrounds_topdown_batch import OUT as BG_OUT
from phase3_projectiles_topdown_batch import OUT, PROJECTILES, SEEDS, stem

CELL, LABEL_H, PAD, HDR = 520, 34, 10, 62
ROW_LABEL_W = 190
FIELD = 34                      # on-field projectile size, long side in px
PATCH = FIELD + 46              # enough plate around the sprite to judge it against the texture


def grounds() -> list:
    """The lightest and darkest plate actually rendered: the real worst case, both directions."""
    files = sorted(glob.glob(f"{BG_OUT}/p3_bgtd_*_00001_.png"))
    if not files:
        return []
    lums = [(np.asarray(Image.open(f).convert("L")).mean(), f) for f in files]
    lums.sort()
    picks = [("darkest", lums[0][1]), ("lightest", lums[-1][1])]
    out = []
    for tag, f in picks:
        im = Image.open(f).convert("RGB")
        # centre crop, so we judge against the plate's own texture at its native pixel scale
        cx, cy = im.width // 2, im.height // 2
        out.append((f"{tag}: {os.path.basename(f)[:-11]}",
                    im.crop((cx - PATCH // 2, cy - PATCH // 2, cx + PATCH // 2, cy + PATCH // 2))))
    return out


def key(img: Image.Image) -> Image.Image:
    """Drop the plain studio background so the sprite can sit on a plate, as it will in game."""
    a = np.asarray(img.convert("RGB")).astype(int)
    corners = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(corners, axis=0)
    alpha = (np.abs(a - bg).sum(axis=2) > 46).astype(np.uint8) * 255
    out = img.convert("RGBA")
    out.putalpha(Image.fromarray(alpha, "L"))
    return out


def inset(img: Image.Image, plate: Image.Image) -> Image.Image:
    """The projectile at true on-field size over one of the plates it has to cross."""
    s = key(img)
    s.thumbnail((FIELD, FIELD), Image.LANCZOS)
    patch = plate.copy()
    patch.paste(s, ((patch.width - s.width) // 2, (patch.height - s.height) // 2), s)
    ImageDraw.Draw(patch).rectangle((0, 0, patch.width - 1, patch.height - 1), outline=(90, 90, 90))
    return patch


def main() -> None:
    argv = sys.argv[1:]
    seeds = SEEDS
    if argv and argv[0].startswith("--seeds="):
        seeds = [int(s) for s in argv.pop(0).split("=", 1)[1].split(",")]
    ids = argv or list(PROJECTILES)
    font = ImageFont.load_default(size=15)
    row_font = ImageFont.load_default(size=19)
    title_font = ImageFont.load_default(size=24)
    os.makedirs("../contact-sheets", exist_ok=True)

    sheet = Image.new("RGB", (ROW_LABEL_W + CELL * len(seeds),
                              HDR + (CELL + LABEL_H) * len(ids)), (24, 24, 24))
    d0 = ImageDraw.Draw(sheet)
    d0.text((PAD, 8), f"W14.8 top-down projectiles — seed {seeds[0]}..{seeds[-1]} left to right, "
                      f"{len(ids)} ammo types top to bottom", fill=(255, 255, 255), font=title_font)
    grounds_ = grounds()
    d0.text((PAD, 38), "the two small patches in each cell are the sprite at true on-field size "
                       "composited over real plates — " + ", ".join(g[0] for g in grounds_)
                       + "; if it disappears on either, reject it",
            fill=(170, 170, 170), font=font)

    for row, pid in enumerate(ids):
        y = HDR + (CELL + LABEL_H) * row
        d0.text((PAD, y + CELL // 2), pid, fill=(230, 210, 160), font=row_font)
        for col, seed in enumerate(seeds):
            st = stem(pid, seed)
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
                x = CELL - PAD
                for _, plate in reversed(grounds_):
                    ins = inset(img, plate)
                    x -= ins.width
                    cell.paste(ins, (x, CELL - ins.height - PAD))
                    x -= 6
            tw = d.textlength(label, font=font)
            d.text(((CELL - tw) / 2, CELL + 2), label, fill=colour, font=font)
            sheet.paste(cell, (ROW_LABEL_W + CELL * col, y))

    out = "../contact-sheets/phase3_projectiles_topdown.png"
    sheet.save(out)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
