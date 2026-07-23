# phase3_portraits_freeze.py — freeze the human-picked portrait busts (cookbook §7).
# Portraits are isolated on plain light gray, so they freeze like units/buildings (border-flood key to
# transparent, tight crop) — NOT like the full-frame cards. Keys each picked bust, crops tight, writes
# ../approved/portraits/<portrait_id>.png, flips the picked manifest rows to approved, writes the
# registry-source coverage json, and renders a halo-check sheet (dark + light backdrop per bust, style
# bible §4). Run with the ComfyUI venv python from assets/pipeline/. Stems come from
# phase3_portrait_state.json, so a re-rolled pick freezes under its bumped seed.
#
# PICK RECORD (human pick gate): fill PICKS with one seed per portrait id after the human replies to
# the two contact sheets (phase3_portraits_civs.png / phase3_portraits_candidates.png). Until then this
# script is a no-op guarded by the empty-PICKS check.
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from phase2_freeze import border_seed, flood
from phase3_portraits_batch import PORTRAITS

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-portraits")
OUT = "../approved/portraits"
STATE = "phase3_portrait_state.json"
MANIFEST = "manifest.jsonl"
POST = {"key": "border-flood", "tolerance": 60, "cropped": True}
SPECK_MIN_PX = 1500   # busts have no legitimate detached parts; drop any mottled-bg residue

# portrait_id -> picked seed (filled at the human pick gate)
PICKS: dict[str, int] = {}


def drop_specks(opaque: np.ndarray, min_px: int = SPECK_MIN_PX) -> np.ndarray:
    left = opaque.copy()
    keep = np.zeros_like(opaque)
    while left.any():
        ys, xs = np.nonzero(left)
        seed = np.zeros_like(opaque)
        seed[ys[0], xs[0]] = True
        comp = flood(left, seed)
        if comp.sum() >= min_px:
            keep |= comp
        left &= ~comp
    return keep


def keyed(stem: str) -> Image.Image:
    rgb = np.asarray(Image.open(f"{SRC}/{stem}_00001_.png").convert("RGB")).astype(np.uint8)
    h, w, _ = rgb.shape
    bg = np.median(np.stack([rgb[3, 3], rgb[3, w - 4], rgb[h - 4, 3], rgb[h - 4, w - 4]]).astype(int), axis=0)
    mask = flood(np.abs(rgb.astype(int) - bg).sum(axis=2) < 60, border_seed((h, w)))
    opaque = drop_specks(~mask)
    alpha = np.where(opaque, 255, 0).astype(np.uint8)
    ys, xs = np.where(alpha > 0)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA").crop(
        (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def main() -> None:
    if not PICKS:
        raise SystemExit("PICKS is empty — fill one seed per portrait id from the pick gate first")
    with open(STATE) as f:
        state = json.load(f)
    os.makedirs(OUT, exist_ok=True)

    sprites: dict[str, Image.Image] = {}
    stem_to_name: dict[str, str] = {}
    for portrait_id, seed in sorted(PICKS.items()):
        assert portrait_id in PORTRAITS, f"unknown portrait id {portrait_id}"
        stem = state[portrait_id][str(seed)]["stem"]
        s = keyed(stem)
        s.save(f"{OUT}/{portrait_id}.png")
        sprites[portrait_id] = s
        stem_to_name[stem] = portrait_id
        print(f"froze {portrait_id}.png {s.width}x{s.height} <- {stem}")

    # flip picked manifest rows to approved
    lines, flipped = [], 0
    with open(MANIFEST) as f:
        for raw in f:
            e = json.loads(raw)
            if e["id"] in stem_to_name:
                e["status"] = "approved"
                e["file"] = f"assets/approved/portraits/{stem_to_name[e['id']]}.png"
                e["post"] = POST
                flipped += 1
            lines.append(json.dumps(e, ensure_ascii=False))
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"manifest: {flipped} rows flipped to approved ({len(PICKS)} busts frozen)")

    coverage = {
        "civs": sorted(p for p in PICKS if p.startswith("portrait_civ_")),
        "candidates": sorted(p for p in PICKS if p.startswith("portrait_candidate_")),
    }
    json.dump(coverage, open("phase3_portraits_coverage.json", "w"), ensure_ascii=False, indent=1)
    print("wrote phase3_portraits_coverage.json (registry source for AssetPaths portrait lists)")

    # halo check: dark row + light row per bust
    cell, pad, cols = 320, 8, 5
    font = ImageFont.load_default(size=13)
    names = list(sprites)
    bands = [names[i:i + cols] for i in range(0, len(names), cols)]
    band_h = cell * 2 + 24
    sheet = Image.new("RGB", (cell * cols, band_h * len(bands)), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for b, band in enumerate(bands):
        for col, name in enumerate(band):
            t = sprites[name].copy()
            t.thumbnail((cell - 2 * pad, cell - 2 * pad), Image.LANCZOS)
            for row, bgc in enumerate([(20, 20, 30), (235, 235, 225)]):
                tile = Image.new("RGBA", (cell, cell), bgc + (255,))
                tile.alpha_composite(t, ((cell - t.width) // 2, (cell - t.height) // 2))
                sheet.paste(tile.convert("RGB"), (col * cell, b * band_h + row * cell))
            d.text((col * cell + pad, b * band_h + cell * 2 + 4), name, fill=(220, 220, 220), font=font)
    sheet.save("../contact-sheets/phase3_portraits_halo_check.png")
    print("wrote ../contact-sheets/phase3_portraits_halo_check.png")


if __name__ == "__main__":
    main()
