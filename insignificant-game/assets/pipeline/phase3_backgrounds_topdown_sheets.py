# phase3_backgrounds_topdown_sheets.py — W14.8 pick-gate sheet for the 7 top-down battle plates
# (cookbook §9). One row per plate, one column per seed, so the human picks one seed per battle
# type. Unlike the unit sheets there is no battle-zoom inset: a plate ships full-frame at 1920x1088
# behind the sprites, so sheet size IS its judging size, only smaller.
#
# Cells are wide (16:9), so the sheet is laid out landscape-per-cell rather than square.
# Run with the ComfyUI venv python from assets/pipeline/.
import json
import os

from PIL import Image, ImageDraw, ImageFont

from phase3_backgrounds_topdown_batch import OUT, PLATES, SEEDS, STATE

CELL_W, LABEL_H, PAD, HDR = 860, 34, 8, 58


def main() -> None:
    with open(STATE) as f:
        state = json.load(f)
    font = ImageFont.load_default(size=15)
    title_font = ImageFont.load_default(size=24)
    cell_h = round(CELL_W * 1088 / 1920)
    plates = [p for p in PLATES if p in state]
    sheet = Image.new("RGB", (CELL_W * len(SEEDS), HDR + (cell_h + LABEL_H) * len(plates)), (24, 24, 24))
    d0 = ImageDraw.Draw(sheet)
    d0.text((PAD, 8), "W14.8 top-down battle plates — one row per battle type, seeds left to right",
            fill=(255, 255, 255), font=title_font)
    d0.text((PAD, 36), "pick one seed per row; plates ship full-frame behind the sprites, so judge "
                       "the empty middle band as much as the scenery", fill=(170, 170, 170), font=font)
    for row, plate in enumerate(plates):
        for col, seed in enumerate(SEEDS):
            entry = state[plate].get(str(seed))
            cell = Image.new("RGB", (CELL_W, cell_h + LABEL_H), (24, 24, 24))
            d = ImageDraw.Draw(cell)
            if entry is None:
                label, colour = f"(no {plate} seed {seed})", (150, 150, 150)
            else:
                label, colour = entry["stem"], (220, 220, 220)
                img = Image.open(f"{OUT}/{entry['stem']}_00001_.png")
                img.thumbnail((CELL_W - 2 * PAD, cell_h - 2 * PAD), Image.LANCZOS)
                cell.paste(img, ((CELL_W - img.width) // 2, (cell_h - img.height) // 2))
            tw = d.textlength(label, font=font)
            d.text(((CELL_W - tw) / 2, cell_h + 2), label, fill=colour, font=font)
            sheet.paste(cell, (CELL_W * col, HDR + (cell_h + LABEL_H) * row))
    out = "../contact-sheets/phase3_backgrounds_topdown.png"
    sheet.save(out)
    print(f"wrote {out}  ({sheet.width}x{sheet.height})")


if __name__ == "__main__":
    main()
