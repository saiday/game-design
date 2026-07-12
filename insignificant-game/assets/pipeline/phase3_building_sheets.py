# phase3_building_sheets.py — Phase 3 building lineage review sheet (cookbook §9): one row per
# seed chain, one column per era, raws as generated — the human judges cross-era coherence along
# the row and picks a whole lineage. Run with the ComfyUI venv python from assets/pipeline/
# after phase3_buildings_batch.py. Usage: phase3_building_sheets.py [line ...]
import os
import sys

from PIL import Image, ImageDraw, ImageFont

from phase3_buildings_batch import LINES, SEEDS

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-buildings")
CELL, LABEL_H, PAD, HDR = 340, 30, 8, 48


def main() -> None:
    font = ImageFont.load_default(size=15)
    title_font = ImageFont.load_default(size=24)
    for line in (sys.argv[1:] or ["food"]):
        eras = len(LINES[line])
        sheet = Image.new("RGB", (CELL * eras, HDR + (CELL + LABEL_H) * len(SEEDS)), (24, 24, 24))
        ImageDraw.Draw(sheet).text((PAD, 12), f"Phase 3 buildings [{line}] — era lineage chains, era 1..{eras} left to right",
                                   fill=(255, 255, 255), font=title_font)
        for row, seed in enumerate(SEEDS):
            for col in range(1, eras + 1):
                stem = f"p3_bld_{line}_e{col}_s{seed}"
                cell = Image.new("RGB", (CELL, CELL + LABEL_H), (24, 24, 24))
                img = Image.open(f"{SRC}/{stem}_00001_.png")
                img.thumbnail((CELL - 2 * PAD, CELL - 2 * PAD), Image.LANCZOS)
                cell.paste(img, ((CELL - img.width) // 2, (CELL - img.height) // 2))
                d = ImageDraw.Draw(cell)
                label = stem
                tw = d.textlength(label, font=font)
                d.text(((CELL - tw) / 2, CELL + 2), label, fill=(220, 220, 220), font=font)
                sheet.paste(cell, (CELL * (col - 1), HDR + (CELL + LABEL_H) * row))
        out = f"../contact-sheets/phase3_buildings_{line}.png"
        sheet.save(out)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
