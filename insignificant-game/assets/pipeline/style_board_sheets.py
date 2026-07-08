# style_board_sheets.py — Phase 1 post-process (cookbook §5/§9): pixelize the picked
# style-board candidates under each master-palette candidate, then assemble one labeled
# contact sheet per style recipe (rows = palettes, cols = subjects).
# Run with the ComfyUI venv python from assets/pipeline/ after style_board_batch.py and
# after filling PICKS from the §8 review of the raw candidates.
import os
import sys

from PIL import Image, ImageDraw, ImageFont

from pixelize import pixelize

OUT_DIR = os.path.expanduser("~/ComfyUI-Shared/output/style-boards")
WORK_DIR = os.path.expanduser("~/imagegen/candidates/style-boards")
SHEET_DIR = "../contact-sheets"

PALETTES = ["endesga-32", "resurrect-64", "apollo"]
SUBJECTS = ["bld1", "bld4", "card", "icon"]
RECIPES = {
    "r1": "SDXL + pixel-art-xl 0.9",
    "r2": "SDXL + PixelArtRedmond 1.0",
    "r3": "Z-Image-Turbo + tarn59 1.0",
    "r4": "Krea-2-Turbo + Moebius 1.0",
}
# Recipes whose sheet gets a top "raw" row (the 1024-class generation before pixelization),
# so the style can be judged both ways. Added for r4: Moebius linework is not pixel art.
RAW_ROW = {"r4"}
GRIDS = {"bld1": (64, 64), "bld4": (64, 64), "card": (96, 128), "icon": (16, 16)}

# (recipe, subject) -> picked candidate stem, best of the fixed-seed sweep per the §8 review.
# r1b/r2b stems = the icon re-roll batch (the first icon framing failed §8 at 16x16 —
# subject too small in frame, re-prompted frame-filling).
PICKS: dict[tuple[str, str], str] = {
    ("r1", "bld1"): "sb_r1_bld1_s41",
    ("r1", "bld4"): "sb_r1_bld4_s44",
    ("r1", "card"): "sb_r1_card_s43",
    ("r1", "icon"): "sb_r1b_icon_s44",
    ("r2", "bld1"): "sb_r2_bld1_s44",
    ("r2", "bld4"): "sb_r2_bld4_s41",
    ("r2", "card"): "sb_r2_card_s43",
    ("r2", "icon"): "sb_r2b_icon_s42",
    ("r3", "bld1"): "sb_r3_bld1_s41",
    ("r3", "bld4"): "sb_r3_bld4_s43",
    ("r3", "card"): "sb_r3_card_s43",
    ("r3", "icon"): "sb_r3_icon_s41",
    # r4 §8 notes: bld1 s41/s42/s44 rejected (fake game-logo badge = text artifact);
    # card s41/s43/s44 rejected (fake artist signature).
    ("r4", "bld1"): "sb_r4_bld1_s43",
    ("r4", "bld4"): "sb_r4_bld4_s43",
    ("r4", "card"): "sb_r4_card_s42",
    ("r4", "icon"): "sb_r4_icon_s42",
}

CELL_W, CELL_H, LABEL_H, PAD = 340, 460, 34, 10


def src_path(stem: str) -> str:
    return f"{OUT_DIR}/{stem}_00001_.png"


def pixelized_path(stem: str, palette: str) -> str:
    return f"{WORK_DIR}/pixelized/{stem}_{palette}.png"


def make_cell(img_path: str, label: str, font: ImageFont.ImageFont,
              resample: Image.Resampling = Image.NEAREST) -> Image.Image:
    cell = Image.new("RGB", (CELL_W, CELL_H + LABEL_H), (24, 24, 24))
    img = Image.open(img_path).convert("RGB")
    scale = max(1, min((CELL_W - 2 * PAD) // img.width, (CELL_H - 2 * PAD) // img.height))
    img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    if img.width > CELL_W - 2 * PAD or img.height > CELL_H - 2 * PAD:  # card art can overflow
        img.thumbnail((CELL_W - 2 * PAD, CELL_H - 2 * PAD), resample)
    cell.paste(img, ((CELL_W - img.width) // 2, (CELL_H - img.height) // 2))
    draw = ImageDraw.Draw(cell)
    tw = draw.textlength(label, font=font)
    draw.text(((CELL_W - tw) / 2, CELL_H + 6), label, fill=(220, 220, 220), font=font)
    return cell


def main() -> None:
    os.makedirs(f"{WORK_DIR}/pixelized", exist_ok=True)
    font = ImageFont.load_default(size=16)
    title_font = ImageFont.load_default(size=24)
    wanted = sys.argv[1:] or list(RECIPES)  # e.g. `style_board_sheets.py r4` rebuilds one sheet
    for recipe in wanted:
        recipe_desc = RECIPES[recipe]
        rows = (["raw"] if recipe in RAW_ROW else []) + PALETTES
        header = 48
        sheet = Image.new("RGB", (CELL_W * len(SUBJECTS), header + (CELL_H + LABEL_H) * len(rows)), (24, 24, 24))
        ImageDraw.Draw(sheet).text((PAD, 12), f"{recipe}: {recipe_desc}  (rows: {' / '.join(rows)})",
                                   fill=(255, 255, 255), font=title_font)
        for row, palette in enumerate(rows):
            for col, subject in enumerate(SUBJECTS):
                stem = PICKS[(recipe, subject)]
                if palette == "raw":
                    cell = make_cell(src_path(stem), f"{stem} · raw 1024-class", font, Image.LANCZOS)
                else:
                    dst = pixelized_path(stem, palette)
                    pixelize(src_path(stem), dst, GRIDS[subject], f"palettes/{palette}.png")
                    label = f"{stem} · {palette} · {GRIDS[subject][0]}x{GRIDS[subject][1]}"
                    cell = make_cell(dst, label, font)
                sheet.paste(cell, (CELL_W * col, header + (CELL_H + LABEL_H) * row))
        out = f"{SHEET_DIR}/phase1_style_board_{recipe}.png"
        sheet.save(out)
        print(f"wrote {out}")


if __name__ == "__main__":
    main()
