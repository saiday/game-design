# phase3_unit_sheets.py — Phase 3 unit/fort/enemy lineage review sheets (cookbook §9): one row
# per seed chain, one column per era, raws as generated — the human judges cross-era coherence
# along the row and picks a whole lineage per line. Cells come from phase3_unit_chains.json (the
# era-gated wave state), so re-rolled cells appear under their bumped seeds. Run with the ComfyUI
# venv python from assets/pipeline/ after the last wave. Usage: phase3_unit_sheets.py [line ...]
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

from phase3_units_batch import LINES, START_ERA

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-units")
# CELL >= 640: the human zooms into sheet cells for detail review (cookbook §9)
CELL, LABEL_H, PAD, HDR = 640, 36, 10, 56


def main() -> None:
    with open("phase3_unit_chains.json") as f:
        state = json.load(f)
    font = ImageFont.load_default(size=15)
    title_font = ImageFont.load_default(size=24)
    for line in (sys.argv[1:] or list(state)):
        start = START_ERA.get(line, 1)
        eras = list(range(start, start + len(LINES[line])))
        # rows are the chains the line actually carries (picked lines keep one, re-rolls run three)
        chains = sorted(state[line], key=int)
        sheet = Image.new("RGB", (CELL * len(eras), HDR + (CELL + LABEL_H) * len(chains)), (24, 24, 24))
        ImageDraw.Draw(sheet).text(
            (PAD, 12), f"Phase 3 units [{line}] — era lineage chains, era {eras[0]}..{eras[-1]} left to right",
            fill=(255, 255, 255), font=title_font)
        for row, chain in enumerate(chains):
            for col, era in enumerate(eras):
                entry = state[line][str(chain)].get(str(era))
                cell = Image.new("RGB", (CELL, CELL + LABEL_H), (24, 24, 24))
                d = ImageDraw.Draw(cell)
                if entry is None:
                    label, colour = f"(no era {era} cell)", (150, 150, 150)
                else:
                    stem, label = entry["stem"], entry["stem"]
                    img = Image.open(f"{SRC}/{stem}_00001_.png")
                    img.thumbnail((CELL - 2 * PAD, CELL - 2 * PAD), Image.LANCZOS)
                    cell.paste(img, ((CELL - img.width) // 2, (CELL - img.height) // 2))
                    colour = (220, 220, 220)
                    if entry.get("rejected"):
                        # never let a §8-rejected cell read as a pickable candidate
                        cell.paste(Image.blend(cell.crop((0, 0, CELL, CELL)),
                                               Image.new("RGB", (CELL, CELL), (90, 20, 20)), 0.45), (0, 0))
                        d.rectangle((1, 1, CELL - 2, CELL - 2), outline=(220, 60, 60), width=3)
                        rw = d.textlength("REJECTED — not a candidate", font=font)
                        d.text(((CELL - rw) / 2, CELL / 2), "REJECTED — not a candidate",
                               fill=(255, 190, 190), font=font)
                        label, colour = f"{stem}  [REJECTED]", (255, 120, 120)
                tw = d.textlength(label, font=font)
                d.text(((CELL - tw) / 2, CELL + 2), label, fill=colour, font=font)
                sheet.paste(cell, (CELL * col, HDR + (CELL + LABEL_H) * row))
        out = f"../contact-sheets/phase3_units_{line}.png"
        sheet.save(out)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
