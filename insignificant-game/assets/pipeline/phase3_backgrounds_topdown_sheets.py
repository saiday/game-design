# phase3_backgrounds_topdown_sheets.py — W14.8 pick-gate sheet for the 7 top-down battle plates
# (cookbook §9). One row per plate, one column per seed, so the human picks one seed per battle
# type. Unlike the unit sheets there is no battle-zoom inset: a plate ships full-frame at 1920x1088
# behind the sprites, so sheet size IS its judging size, only smaller.
#
# Cells are wide (16:9), so the sheet is laid out landscape-per-cell rather than square.
#
# Each row resolves its OWN seeds, rather than every row sharing the batch's current SEEDS. Rounds
# bump seeds by +100 and re-roll only the plates the human sent back, so after one partial round the
# class holds two seed generations at once and a sheet pinned to one list shows empty cells for
# every plate that was left alone. The stem under each cell carries the real seed, so a pick stays
# unambiguous.
# Run with the ComfyUI venv python from assets/pipeline/.
import json
import os

from PIL import Image, ImageDraw, ImageFont

from phase3_backgrounds_topdown_batch import OUT, PLATES, SEEDS, STATE

CELL_W, LABEL_H, PAD, HDR = 860, 34, 8, 58


def latest_seeds(rows: dict) -> list:
    """The newest round rendered for one plate, as seeds in order."""
    seeds = sorted(int(s) for s in rows)
    return [s for s in seeds if s // 100 == seeds[-1] // 100] if seeds else []


def main() -> None:
    with open(STATE) as f:
        state = json.load(f)
    font = ImageFont.load_default(size=15)
    title_font = ImageFont.load_default(size=24)
    cell_h = round(CELL_W * 1088 / 1920)
    plates = [p for p in PLATES if p in state]
    per_row = {p: latest_seeds(state[p]) or SEEDS for p in plates}
    cols = max(len(s) for s in per_row.values())
    sheet = Image.new("RGB", (CELL_W * cols, HDR + (cell_h + LABEL_H) * len(plates)), (24, 24, 24))
    d0 = ImageDraw.Draw(sheet)
    d0.text((PAD, 8), "W14.8 top-down battle plates — one row per battle type, each row showing its "
                      "newest round", fill=(255, 255, 255), font=title_font)
    d0.text((PAD, 36), "pick one seed per row (the seed is under every cell); plates ship full-frame "
                       "behind the sprites, so sheet size is judging size, only smaller",
            fill=(170, 170, 170), font=font)
    for row, plate in enumerate(plates):
        for col in range(cols):
            row_seeds = per_row[plate]
            seed = row_seeds[col] if col < len(row_seeds) else None
            entry = state[plate].get(str(seed)) if seed is not None else None
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
