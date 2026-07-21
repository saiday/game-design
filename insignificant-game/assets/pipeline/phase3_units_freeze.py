# phase3_units_freeze.py — freeze the human-picked unit/enemy lineages (cookbook §7).
# Keys each sprite (border flood, same recipe as the icon/building freeze), crops tight, writes
# ../approved/units/unit_<line>_era<n>.png, flips the picked manifest rows to approved, and renders
# a halo-check sheet (dark + light backdrops per sprite, style bible §4). Run with the ComfyUI venv
# python from assets/pipeline/. Stems come from phase3_unit_chains.json (render-time truth), so a
# re-rolled cell freezes under its bumped seed.
#
# PICK RECORD (human line-pick gate, 2026-07-21). The gate takes one lineage per line; three cells
# diverge to a sibling chain by explicit human ruling, and one render is a §8-reject accepted as-is:
#   bomber 82 | elite_forces 81 (era6 -> 82) | enemy_hard 83 (era5 -> 82) | enemy_mid 83 |
#   enemy_weak 83 | engineers 82 (era5 seed 8245 is REJECTED, accepted) | privateers 81
#   single-chain lines freeze their only lineage. infantry_era4 is a known GAP (era4 render
#   §8-rejected, no sibling chain) -> left unfrozen; the view fills the slot with a placeholder.
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from phase2_freeze import border_seed, flood

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-units")
OUT = "../approved/units"
STATE = "phase3_unit_chains.json"
MANIFEST = "manifest.jsonl"
POST = {"key": "border-flood", "tolerance": 60, "cropped": True}
SPECK_MIN_PX = 1200   # keep floating sprite parts (falling bombs, arrows); drop mottled-bg residue

SINGLE = ["anti_air", "archers", "artillery", "cavalry", "holy_warriors", "infantry", "shield_wall"]
MULTI = {                       # line -> (default chain, {era: override chain})
    "bomber":       ("82", {}),
    "elite_forces": ("81", {6: "82"}),
    "enemy_hard":   ("83", {5: "82"}),
    "enemy_mid":    ("83", {}),
    "enemy_weak":   ("83", {}),
    "engineers":    ("82", {}),
    "privateers":   ("81", {}),
}
GAP = {("infantry", 4)}         # known gaps: not frozen, view placeholders the slot


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


def build_plan(state: dict) -> dict:
    """(line, era) -> stem, for exactly the picked cells."""
    plan: dict[tuple[str, int], str] = {}
    for line in SINGLE:
        chain = next(iter(state[line]))            # single-chain lines carry one lineage
        for era_s, cell in state[line][chain].items():
            era = int(era_s)
            if (line, era) in GAP:
                continue
            plan[(line, era)] = cell["stem"]
    for line, (default, overrides) in MULTI.items():
        for era_s in state[line][default]:         # eras the line spans (default chain has them all)
            era = int(era_s)
            chain = overrides.get(era, default)
            plan[(line, era)] = state[line][chain][str(era)]["stem"]
    return plan


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    with open(STATE) as f:
        state = json.load(f)
    plan = build_plan(state)

    sprites: dict[str, Image.Image] = {}
    stem_to_name: dict[str, str] = {}
    coverage: dict[str, list[int]] = {}
    for (line, era), stem in sorted(plan.items()):
        name = f"unit_{line}_era{era}"
        s = keyed(stem)
        s.save(f"{OUT}/{name}.png")
        sprites[name] = s
        stem_to_name[stem] = name
        coverage.setdefault(line, []).append(era)
        print(f"froze {name}.png {s.width}x{s.height} <- {stem}")

    # flip picked manifest rows to approved (incl. the one accepted §8-reject)
    lines = []
    flipped = 0
    with open(MANIFEST) as f:
        for raw in f:
            e = json.loads(raw)
            if e["id"] in stem_to_name:
                e["status"] = "approved"
                e["file"] = f"assets/approved/units/{stem_to_name[e['id']]}.png"
                e["post"] = POST
                flipped += 1
            lines.append(json.dumps(e, ensure_ascii=False))
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"manifest: {flipped} rows flipped to approved ({len(plan)} sprites frozen)")

    json.dump({k: sorted(v) for k, v in coverage.items()},
              open("phase3_units_coverage.json", "w"), ensure_ascii=False, indent=1)
    print("wrote phase3_units_coverage.json (registry source for AssetPaths.UNIT_COVERAGE)")

    # halo check: 6 per band, dark row + light row per band
    cell, pad, cols = 300, 8, 6
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
    sheet.save("../contact-sheets/phase3_units_halo_check.png")
    print("wrote ../contact-sheets/phase3_units_halo_check.png")


if __name__ == "__main__":
    main()
