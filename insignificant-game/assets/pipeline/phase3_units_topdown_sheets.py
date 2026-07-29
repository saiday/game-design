# phase3_units_topdown_sheets.py — W14.8 pick-gate sheets (cookbook §9): one row per seed, one
# column per era, so the human judges cross-era coherence along the row and picks per line.
#
# Two differences from phase3_unit_sheets.py, both required by the new camera:
#
#  1. Rows are SEEDS, not lineage chains. The top-down sweep has no img2img lineage (every cell is
#     a txt2img root — the reasoning is in phase3_units_topdown_sweep.py's header), so seed 91's
#     era 1 and era 2 are independent rolls, not a parent and a child. Reading down a column is
#     still how you pick, but reading along a row now checks era-to-era coherence that only the
#     wording is holding together, which is exactly the cost that choice paid.
#  2. Every cell carries a BATTLE-ZOOM INSET: the same sprite scaled to its on-field size on a
#     neutral field patch. review-brief-units-topdown.md makes this the primary readability test,
#     because top-down sprites ship smaller and more crowded than the side-view set did, and a
#     silhouette that only reads at sheet size does not read on the field.
#
# A re-roll round adds a third requirement: the human is not judging the new cells in isolation,
# they are judging whether a re-rolled era still sits in the same line as the eras already
# approved. So when phase3_units_topdown_picks.json has picks for this line, the sheet grows a
# REFERENCE ROW at the top holding those approved cells. Read down a column to pick the seed; read
# along the top row plus your candidate to check the line still coheres across eras.
#
# Run with the ComfyUI venv python from assets/pipeline/.
# Usage: phase3_units_topdown_sheets.py [--seeds 191,192,193,194] [line ...]
import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont

from phase3_units_topdown_batch import LINES, OUT, SEEDS, START_ERA

# CELL >= 640: the human zooms into sheet cells for detail review (cookbook §9)
CELL, LABEL_H, PAD, HDR = 640, 36, 10, 60
FIELD = 104        # on-field sprite size the inset simulates, long side in px
FIELD_BG = (108, 116, 96)   # a neutral field green, so a light sprite is not judged on white


def inset(img: Image.Image) -> Image.Image:
    """The sprite as the player sees it: scaled to field size on a field-coloured patch."""
    s = img.copy()
    s.thumbnail((FIELD, FIELD), Image.LANCZOS)
    patch = Image.new("RGB", (FIELD + 16, FIELD + 16), FIELD_BG)
    patch.paste(s, ((patch.width - s.width) // 2, (patch.height - s.height) // 2))
    ImageDraw.Draw(patch).rectangle((0, 0, patch.width - 1, patch.height - 1), outline=(40, 40, 40))
    return patch


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", help="comma-separated seed override, e.g. a re-roll round's 191,192,193,194")
    ap.add_argument("lines", nargs="*")
    args = ap.parse_args()
    seeds = [int(s) for s in args.seeds.split(",")] if args.seeds else SEEDS

    with open("phase3_unit_topdown_chains.json") as f:
        state = json.load(f)
    picks = {}
    if os.path.exists("phase3_units_topdown_picks.json"):
        with open("phase3_units_topdown_picks.json") as f:
            picks = json.load(f)["picks"]
    font = ImageFont.load_default(size=15)
    title_font = ImageFont.load_default(size=24)
    os.makedirs("../contact-sheets", exist_ok=True)
    for line in (args.lines or [l for l in LINES if l in state]):
        start = START_ERA.get(line, 1)
        eras = list(range(start, start + len(LINES[line])))
        # (seed, is_reference); the reference row carries whatever this line already had approved
        rows = [(None, True)] + [(s, False) for s in seeds] if picks.get(line) else \
               [(s, False) for s in seeds]
        sheet = Image.new("RGB", (CELL * len(eras), HDR + (CELL + LABEL_H) * len(rows)), (24, 24, 24))
        d0 = ImageDraw.Draw(sheet)
        d0.text((PAD, 8), f"W14.8 top-down units [{line}] — era {eras[0]}..{eras[-1]} left to right, "
                          f"seed {seeds[0]}..{seeds[-1]} top to bottom",
                fill=(255, 255, 255), font=title_font)
        d0.text((PAD, 38), "inset bottom-right of each cell = the sprite at on-field size; judge "
                           "silhouette readability there first (review-brief-units-topdown.md)"
                + (" | top row = already-approved picks, for cross-era coherence only"
                   if picks.get(line) else ""),
                fill=(170, 170, 170), font=font)
        for row, (seed, is_ref) in enumerate(rows):
            for col, era in enumerate(eras):
                lookup = picks.get(line, {}).get(str(era)) if is_ref else seed
                entry = (state.get(line, {}).get(str(era), {}).get(str(lookup))
                         if lookup is not None else None)
                cell = Image.new("RGB", (CELL, CELL + LABEL_H), (18, 30, 18) if is_ref else (24, 24, 24))
                d = ImageDraw.Draw(cell)
                if entry is None:
                    label = f"(no r1 pick for era {era})" if is_ref else f"(no era {era} seed {seed})"
                    colour = (150, 150, 150)
                else:
                    label = ("APPROVED r1  " + entry["stem"]) if is_ref else entry["stem"]
                    colour = (150, 230, 150) if is_ref else (220, 220, 220)
                    img = Image.open(f"{OUT}/{entry['stem']}_00001_.png")
                    big = img.copy()
                    big.thumbnail((CELL - 2 * PAD, CELL - 2 * PAD), Image.LANCZOS)
                    cell.paste(big, ((CELL - big.width) // 2, (CELL - big.height) // 2))
                    ins = inset(img)
                    cell.paste(ins, (CELL - ins.width - PAD, CELL - ins.height - PAD))
                tw = d.textlength(label, font=font)
                d.text(((CELL - tw) / 2, CELL + 2), label, fill=colour, font=font)
                sheet.paste(cell, (CELL * col, HDR + (CELL + LABEL_H) * row))
        out = f"../contact-sheets/phase3_units_topdown_{line}.png"
        sheet.save(out)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
