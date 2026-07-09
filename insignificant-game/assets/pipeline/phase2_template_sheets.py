# phase2_template_sheets.py — Phase 2 contact sheet (cookbook §9): all §8-passing template
# candidates on one labeled sheet, rows = templates, cols = seeds. No post-process (pixelization
# retired 2026-07-09); cells show the raw generations, LANCZOS-thumbnailed.
# Run with the ComfyUI venv python from assets/pipeline/ after phase2_templates_batch.py and
# after filling REJECTS from the §8 review of the raws.
import os

from PIL import Image, ImageDraw, ImageFont

from phase2_templates_batch import SEEDS, TEMPLATES

OUT_DIR = os.path.expanduser("~/ComfyUI-Shared/output/phase2-templates")
SHEET = "../contact-sheets/phase2_templates.png"

# stems that failed the §8 review (rejected cells render as a labeled reject notice so the
# human sees the full sweep without the artifact candidates).
REJECTS: dict[str, str] = {}

CELL_W, CELL_H, LABEL_H, PAD = 380, 420, 34, 10


def make_cell(stem: str, font: ImageFont.ImageFont) -> Image.Image:
    cell = Image.new("RGB", (CELL_W, CELL_H + LABEL_H), (24, 24, 24))
    draw = ImageDraw.Draw(cell)
    if stem in REJECTS:
        label = f"{stem} · REJECTED §8"
        draw.text((PAD, CELL_H // 2 - 20), REJECTS[stem], fill=(200, 120, 120), font=font)
    else:
        img = Image.open(f"{OUT_DIR}/{stem}_00001_.png").convert("RGB")
        img.thumbnail((CELL_W - 2 * PAD, CELL_H - 2 * PAD), Image.LANCZOS)
        cell.paste(img, ((CELL_W - img.width) // 2, (CELL_H - img.height) // 2))
        label = stem
    tw = draw.textlength(label, font=font)
    draw.text(((CELL_W - tw) / 2, CELL_H + 6), label, fill=(220, 220, 220), font=font)
    return cell


def main() -> None:
    font = ImageFont.load_default(size=16)
    title_font = ImageFont.load_default(size=24)
    header = 48
    sheet = Image.new("RGB", (CELL_W * len(SEEDS), header + (CELL_H + LABEL_H) * len(TEMPLATES)),
                      (24, 24, 24))
    ImageDraw.Draw(sheet).text(
        (PAD, 12), "Phase 2 templates: Krea-2-Turbo + Moebius 1.0, raw (rows: "
        + " / ".join(TEMPLATES) + ")", fill=(255, 255, 255), font=title_font)
    for row, template in enumerate(TEMPLATES):
        for col, seed in enumerate(SEEDS):
            cell = make_cell(f"p2_{template}_s{seed}", font)
            sheet.paste(cell, (CELL_W * col, header + (CELL_H + LABEL_H) * row))
    sheet.save(SHEET)
    print(f"wrote {SHEET}")


if __name__ == "__main__":
    main()
