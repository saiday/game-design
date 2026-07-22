# phase3_card_sheets.py — Phase 3 card-illustration review sheet (cookbook §9) for the human pick
# gate. One row per card subject, one column per generated seed (read from phase3_card_state.json so
# re-rolled cells appear under their bumped seeds, like the backgrounds sheet reads chain state).
# Cells keep the raw's long side >= 640px (§9: the human zooms into sheet cells). Cards are portrait
# 768x1024 dramatic scenes; the frozen frame composites over them in Godot (not baked into the
# sheet). Run with the ComfyUI venv python from assets/pipeline/.
# Usage: phase3_card_sheets.py [pilot|all]   (default: whatever ids are present in the state file)
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

from phase3_cards_batch import PILOT, CARDS, STATE

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-cards")
CELL_W, CELL_H, LABEL_H, PAD, HDR, ROWLBL = 680, 900, 34, 10, 56, 220


def cell_image(stem: str, font) -> Image.Image:
    cell = Image.new("RGB", (CELL_W, CELL_H + LABEL_H), (24, 24, 24))
    path = f"{SRC}/{stem}_00001_.png"
    if os.path.exists(path):
        img = Image.open(path)
        img.thumbnail((CELL_W - 2 * PAD, CELL_H - 2 * PAD), Image.LANCZOS)
        cell.paste(img, ((CELL_W - img.width) // 2, (CELL_H - img.height) // 2))
    d = ImageDraw.Draw(cell)
    tw = d.textlength(stem, font=font)
    d.text(((CELL_W - tw) / 2, CELL_H + 2), stem, fill=(220, 220, 220), font=font)
    return cell


LINES = ["infantry", "archers", "cavalry", "engineers", "elite_forces", "artillery",
         "bomber", "holy_warriors", "privateers", "shield_wall", "anti_air"]


def build_sheet(state: dict, ids: list, title: str, out: str) -> None:
    """One row per subject id, one column per generated seed. Cells >= 640px long side (§9)."""
    ids = [c for c in ids if c in state]
    if not ids:
        print(f"skip {out} (no cells in state)")
        return
    cols = max(len(state[c]) for c in ids)
    font = ImageFont.load_default(size=15)
    row_font = ImageFont.load_default(size=17)
    title_font = ImageFont.load_default(size=24)
    W = ROWLBL + CELL_W * cols
    Hpx = HDR + (CELL_H + LABEL_H) * len(ids)
    sheet = Image.new("RGB", (W, Hpx), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 14), title, fill=(255, 255, 255), font=title_font)
    for row, card_id in enumerate(ids):
        y = HDR + (CELL_H + LABEL_H) * row
        d.text((PAD, y + 12), card_id[len("card_"):], fill=(240, 240, 240), font=row_font)
        for col, seed in enumerate(sorted(state[card_id], key=int)):
            sheet.paste(cell_image(state[card_id][seed]["stem"], font), (ROWLBL + CELL_W * col, y))
    sheet.save(out)
    print(f"wrote {out}  ({W}x{Hpx}, {len(ids)} rows x {cols} cols)")


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "pilot"
    with open(STATE) as f:
        state = json.load(f)
    if mode == "lines":
        # per-line review sheets (like the units lineage sheets) — one committed sheet per line,
        # plus one for the era-neutral skill cards. More reviewable than a single 57-row sheet.
        for line in LINES:
            ids = [c for c in CARDS if c.startswith(f"card_{line}_era")]
            build_sheet(state, ids, f"Phase 3 cards — {line} (pick one seed per row)",
                        f"../contact-sheets/phase3_cards_{line}.png")
        skills = [c for c in CARDS if not any(c.startswith(f"card_{l}_era") for l in LINES)]
        build_sheet(state, skills, "Phase 3 cards — skill cards (pick one seed per row)",
                    "../contact-sheets/phase3_cards_skills.png")
    else:
        ids = PILOT if mode == "pilot" else list(CARDS)
        build_sheet(state, ids, f"Phase 3 cards [{mode}] — one row per subject (pick one seed per row)",
                    f"../contact-sheets/phase3_cards_{mode}.png")


if __name__ == "__main__":
    main()
