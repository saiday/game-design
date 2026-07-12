# phase3_icon_sheets.py — Phase 3 icon review sheet (cookbook §9): key each glyph candidate,
# composite it into the frozen icon plate's disc rect (style bible §9), and lay out one labeled
# sheet per group, rows = icons, cols = seeds — the human judges the shipped look, not bare
# glyphs. Run with the ComfyUI venv python from assets/pipeline/ after phase3_icons_batch.py.
# Usage: phase3_icon_sheets.py [group ...]; fill REJECTS from the §8 review first.
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from phase2_freeze import border_seed, flood
from phase3_icons_batch import GROUPS, SEEDS

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-icons")
PLATE = Image.open("../approved/ui/ui_icon_plate.png").convert("RGBA")
DISC = (174, 170, 621, 625)  # glyph disc rect (style bible §9)
GLYPH_FILL = 0.78            # glyph height/width as a fraction of the disc

REJECTS: dict[str, str] = {}

# CELL >= 640: the human zooms into sheet cells for detail review (cookbook §9)
CELL_W, CELL_H, LABEL_H, PAD, HDR = 640, 660, 36, 10, 56


def keyed_glyph(stem: str) -> Image.Image:
    rgb = np.asarray(Image.open(f"{SRC}/{stem}_00001_.png").convert("RGB")).astype(np.uint8)
    h, w, _ = rgb.shape
    bg = np.median(np.stack([rgb[3, 3], rgb[3, w - 4], rgb[h - 4, 3], rgb[h - 4, w - 4]]).astype(int), axis=0)
    keyed = flood(np.abs(rgb.astype(int) - bg).sum(axis=2) < 60, border_seed((h, w)))
    alpha = np.where(keyed, 0, 255).astype(np.uint8)
    ys, xs = np.where(alpha > 0)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA").crop(
        (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def composite(stem: str) -> Image.Image:
    glyph = keyed_glyph(stem)
    dx0, dy0, dx1, dy1 = DISC
    box = int((dx1 - dx0) * GLYPH_FILL), int((dy1 - dy0) * GLYPH_FILL)
    glyph.thumbnail(box, Image.LANCZOS)
    out = PLATE.copy()
    out.alpha_composite(glyph, ((dx0 + dx1 - glyph.width) // 2, (dy0 + dy1 - glyph.height) // 2))
    return out


def main() -> None:
    font = ImageFont.load_default(size=16)
    title_font = ImageFont.load_default(size=24)
    for group in (sys.argv[1:] or ["core"]):
        icons = list(GROUPS[group])
        sheet = Image.new("RGB", (CELL_W * len(SEEDS), HDR + (CELL_H + LABEL_H) * len(icons)), (24, 24, 24))
        ImageDraw.Draw(sheet).text((PAD, 12), f"Phase 3 icons [{group}], composited on the frozen plate",
                                   fill=(255, 255, 255), font=title_font)
        for row, icon in enumerate(icons):
            for col, seed in enumerate(SEEDS):
                stem = f"p3_icon_{icon}_s{seed}"
                cell = Image.new("RGB", (CELL_W, CELL_H + LABEL_H), (24, 24, 24))
                d = ImageDraw.Draw(cell)
                if stem in REJECTS:
                    label = f"{stem} · REJECTED §8"
                    d.text((PAD, CELL_H // 2 - 20), REJECTS[stem], fill=(200, 120, 120), font=font)
                else:
                    img = composite(stem)
                    img.thumbnail((CELL_W - 2 * PAD, CELL_H - 2 * PAD), Image.LANCZOS)
                    cell.paste(img, ((CELL_W - img.width) // 2, (CELL_H - img.height) // 2),
                               img)
                    label = stem
                tw = d.textlength(label, font=font)
                d.text(((CELL_W - tw) / 2, CELL_H + 4), label, fill=(220, 220, 220), font=font)
                sheet.paste(cell, (CELL_W * col, HDR + (CELL_H + LABEL_H) * row))
        out = f"../contact-sheets/phase3_icons_{group}.png"
        sheet.save(out)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
