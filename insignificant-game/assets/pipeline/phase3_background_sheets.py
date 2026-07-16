# phase3_background_sheets.py — Phase 3 backgrounds review sheets (cookbook §9) for the human
# pick gate. Two sheets: the city era lineage (one row per seed chain, one column per era, cells
# from phase3_background_chains.json so re-rolled cells appear under their bumped seeds — the
# human picks ONE whole chain for cross-era coherence) and the plate grid (one row per txt2img
# plate, one column per §8-passing candidate seed — the human picks one seed per plate).
# CANDIDATES lists only §8-clean seeds; update it as review rounds close. Cells stay >= 640px
# wide (§9: the human zooms into sheet cells). Run with the ComfyUI venv python from
# assets/pipeline/. Usage: phase3_background_sheets.py [city|plates ...]
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

from phase3_backgrounds_batch import PLATES, SEEDS

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-backgrounds")
CELL_W, CELL_H, LABEL_H, PAD, HDR = 960, 552, 36, 10, 56

# §8-passing candidate seeds per plate (default trio unless a re-roll round replaced it).
CANDIDATES = {
    "route_map": [51, 52, 53],
    "battle_tax": [51, 52, 53],
    "battle_field": [51, 52, 53],
    "battle_hidden": [51, 52, 53],
    "battle_riot": [56, 57, 58],       # v3 residential-street wording (v1/v2 fascia rejects)
    "battle_democracy": [57, 58, 59],  # v3 abandoned-plaza wording (v1/v2 pedestrian rejects)
    "battle_civwar": [54, 55, 56],     # v2 occupied-shield wording (v1 emblem/signature rejects)
    "battle_worldwar": [51, 52, 53],
    "title": [51, 75, 97],             # v4 corner-occupied wording (v2/v3 signature rejects)
    "ending_survive": [52, 53, 92],    # v2 hilltop-meadow wording (v1 overlook-figure rejects)
    "ending_collapse": [79, 80, 81],   # v2 obelisk/ivy wording (v1 cross, inscription, glyph rejects)
}


def cell_image(stem: str, font) -> Image.Image:
    cell = Image.new("RGB", (CELL_W, CELL_H + LABEL_H), (24, 24, 24))
    img = Image.open(f"{SRC}/{stem}_00001_.png")
    img.thumbnail((CELL_W - 2 * PAD, CELL_H - 2 * PAD), Image.LANCZOS)
    cell.paste(img, ((CELL_W - img.width) // 2, (CELL_H - img.height) // 2))
    d = ImageDraw.Draw(cell)
    tw = d.textlength(stem, font=font)
    d.text(((CELL_W - tw) / 2, CELL_H + 2), stem, fill=(220, 220, 220), font=font)
    return cell


def main() -> None:
    targets = sys.argv[1:] or ["city", "plates"]
    font = ImageFont.load_default(size=15)
    title_font = ImageFont.load_default(size=24)
    if "city" in targets:
        with open("phase3_background_chains.json") as f:
            state = json.load(f)
        eras = [1, 2, 3, 4, 5, 6]
        sheet = Image.new("RGB", (CELL_W * len(eras), HDR + (CELL_H + LABEL_H) * len(SEEDS)), (24, 24, 24))
        ImageDraw.Draw(sheet).text(
            (PAD, 12), "Phase 3 backgrounds [city] — era lineage chains, era 1..6 left to right (pick ONE row)",
            fill=(255, 255, 255), font=title_font)
        for row, chain in enumerate(SEEDS):
            for col, era in enumerate(eras):
                stem = state["city"][str(chain)][str(era)]["stem"]
                sheet.paste(cell_image(stem, font), (CELL_W * col, HDR + (CELL_H + LABEL_H) * row))
        out = "../contact-sheets/phase3_backgrounds_city.png"
        sheet.save(out)
        print(f"wrote {out}")
    if "plates" in targets:
        cols = max(len(v) for v in CANDIDATES.values())
        sheet = Image.new("RGB", (CELL_W * cols, HDR + (CELL_H + LABEL_H) * len(CANDIDATES)), (24, 24, 24))
        ImageDraw.Draw(sheet).text(
            (PAD, 12), "Phase 3 backgrounds — plate candidates (pick one seed per row)",
            fill=(255, 255, 255), font=title_font)
        for row, (plate_id, seeds) in enumerate(CANDIDATES.items()):
            assert plate_id in PLATES, plate_id
            for col, seed in enumerate(seeds):
                stem = f"p3_bg_{plate_id}_s{seed}"
                sheet.paste(cell_image(stem, font), (CELL_W * col, HDR + (CELL_H + LABEL_H) * row))
        out = "../contact-sheets/phase3_backgrounds_plates.png"
        sheet.save(out)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
