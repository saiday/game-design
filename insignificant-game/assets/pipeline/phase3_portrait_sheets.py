# phase3_portrait_sheets.py — Phase 3 portrait review sheets (cookbook §9) for the human pick gate.
# One row per portrait subject, one column per generated seed (read from phase3_portrait_state.json).
# Two committed sheets (more reviewable than one 15-row sheet): the 5 rival civilizations and the 10
# democracy candidates. Cells keep the raw's long side >= 640px (§9: the human zooms into cells).
# Portraits are square 1024x1024 busts on plain light gray (keyed to transparent at freeze, not in the
# sheet). Run with the ComfyUI venv python from assets/pipeline/.
# Usage: phase3_portrait_sheets.py [all|civs|candidates|rerolls]   (default: all)
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

from phase3_portraits_batch import PORTRAITS, STATE, REROLLS, REROLL_SEEDS, SEEDS

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-portraits")
CELL, LABEL_H, PAD, HDR, ROWLBL = 700, 34, 10, 56, 260


def cell_image(stem: str, font) -> Image.Image:
    cell = Image.new("RGB", (CELL, CELL + LABEL_H), (24, 24, 24))
    path = f"{SRC}/{stem}_00001_.png"
    if os.path.exists(path):
        img = Image.open(path)
        img.thumbnail((CELL - 2 * PAD, CELL - 2 * PAD), Image.LANCZOS)
        cell.paste(img, ((CELL - img.width) // 2, (CELL - img.height) // 2))
    d = ImageDraw.Draw(cell)
    tw = d.textlength(stem, font=font)
    d.text(((CELL - tw) / 2, CELL + 2), stem, fill=(220, 220, 220), font=font)
    return cell


def build_sheet(state: dict, ids: list, title: str, out: str, only_seeds: set | None = None) -> None:
    """One row per subject id, one column per generated seed. Cells >= 640px long side (§9).
    only_seeds (a set of ints) restricts columns to those seeds. A subject that was §8-re-rolled
    (id in REROLLS) shows ONLY its re-cut seeds (REROLL_SEEDS), never the rejected originals; all
    other subjects show the base SEEDS. So the pick gate only ever sees live candidates."""
    def allowed(pid: str) -> set:
        base = set(REROLL_SEEDS) if pid in REROLLS else set(SEEDS)
        return base if only_seeds is None else base & only_seeds
    def seeds_for(pid: str) -> list:
        return [s for s in sorted(state[pid], key=int) if int(s) in allowed(pid)]
    ids = [p for p in ids if p in state and seeds_for(p)]
    if not ids:
        print(f"skip {out} (no cells in state)")
        return
    cols = max(len(seeds_for(p)) for p in ids)
    font = ImageFont.load_default(size=15)
    row_font = ImageFont.load_default(size=17)
    title_font = ImageFont.load_default(size=24)
    W = ROWLBL + CELL * cols
    Hpx = HDR + (CELL + LABEL_H) * len(ids)
    sheet = Image.new("RGB", (W, Hpx), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    d.text((PAD, 14), title, fill=(255, 255, 255), font=title_font)
    for row, pid in enumerate(ids):
        y = HDR + (CELL + LABEL_H) * row
        d.text((PAD, y + 12), pid[len("portrait_"):], fill=(240, 240, 240), font=row_font)
        for col, seed in enumerate(seeds_for(pid)):
            sheet.paste(cell_image(state[pid][seed]["stem"], font), (ROWLBL + CELL * col, y))
    sheet.save(out)
    print(f"wrote {out}  ({W}x{Hpx}, {len(ids)} rows x {cols} cols)")


CIVS = [p for p in PORTRAITS if p.startswith("portrait_civ_")]
CANDIDATES = [p for p in PORTRAITS if p.startswith("portrait_candidate_")]


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    with open(STATE) as f:
        state = json.load(f)
    if mode in ("all", "civs"):
        build_sheet(state, CIVS, "Phase 3 portraits: rival civilizations (pick one seed per row)",
                    "../contact-sheets/phase3_portraits_civs.png")
    if mode in ("all", "candidates"):
        build_sheet(state, CANDIDATES, "Phase 3 portraits: democracy candidates (pick one seed per row)",
                    "../contact-sheets/phase3_portraits_candidates.png")


if __name__ == "__main__":
    main()
