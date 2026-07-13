# phase3_buildings_freeze.py — freeze human-picked building lineage chains (cookbook §7).
# Keys each sprite (border flood, same params as the icon freeze), crops tight, writes
# ../approved/buildings/building_<line>_era<n>.png, flips the manifest entries to approved, and
# renders a halo-check sheet (dark + light backdrops per sprite, style bible §4).
# Run with the ComfyUI venv python from assets/pipeline/.
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from phase2_freeze import border_seed, flood

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-buildings")
OUT = "../approved/buildings"
MANIFEST = "manifest.jsonl"
POST = {"key": "border-flood", "tolerance": 60, "cropped": True}

# line -> picked wave chain (human gate pick; one whole lineage per line, stems resolved from
# phase3_building_chains.json so re-rolled cells freeze under their bumped seeds)
CHAIN_PICKS: dict[str, int] = {
    "housing": 71,
    "medical": 72,
    "school": 72,
    "astronomy": 73,
    "barracks": 74,
    "arsenal": 73,
    "arts": 73,
    "core": 73,
    "commerce": 73,
    "media": 72,
}

# line -> picked chain stems by era (pre-wave pilot pick; food has no state entry)
PICKS: dict[str, dict[int, str]] = {
    "food": {era: f"p3_bld_food_e{era}_s71" for era in range(1, 7)},
}
with open("phase3_building_chains.json") as _f:
    _state = json.load(_f)
for _line, _chain in CHAIN_PICKS.items():
    PICKS[_line] = {int(e): c["stem"] for e, c in _state[_line][str(_chain)].items()}


def drop_specks(opaque: np.ndarray, min_px: int = 1200) -> np.ndarray:
    """Remove opaque components smaller than min_px (mottled-background residue after the
    flood key). Real floating sprite parts (smoke puffs) are well above the threshold."""
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
    os.makedirs(OUT, exist_ok=True)
    sprites: dict[str, Image.Image] = {}
    for line, chain in PICKS.items():
        for era, stem in sorted(chain.items()):
            name = f"building_{line}_era{era}"
            s = keyed(stem)
            s.save(f"{OUT}/{name}.png")
            sprites[name] = s
            print(f"froze {name}.png {s.width}x{s.height} <- {stem}")

    stems = {stem: f"building_{line}_era{era}"
             for line, chain in PICKS.items() for era, stem in chain.items()}
    lines = []
    with open(MANIFEST) as f:
        for raw in f:
            e = json.loads(raw)
            if e["id"] in stems:
                e["status"] = "approved"
                e["file"] = f"assets/approved/buildings/{stems[e['id']]}.png"
                e["post"] = POST
            lines.append(json.dumps(e, ensure_ascii=False))
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"manifest: {len(stems)} entries flipped to approved")

    # halo check, wrapped 6 per band (dark row + light row per band)
    cell, pad, cols = 300, 8, 6
    font = ImageFont.load_default(size=14)
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
    sheet.save("../contact-sheets/phase3_buildings_halo_check.png")
    print("wrote ../contact-sheets/phase3_buildings_halo_check.png")


if __name__ == "__main__":
    main()
