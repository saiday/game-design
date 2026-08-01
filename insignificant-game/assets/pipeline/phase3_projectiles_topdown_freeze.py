# phase3_projectiles_topdown_freeze.py — freeze the 8 human-picked flying weapons (W14.8).
#
# Same post-process as the unit freeze (border flood key, speck drop, tight crop) into a NEW
# directory, ../approved/projectiles/proj_<ammo>.png. New because the class is new: side-view
# battle art never needed a projectile, and seen from above an attack IS a thing crossing the gap
# between two stations, with a hit/miss event per attack in the timeline and nothing to draw.
# Nothing here supersedes anything, so unlike the unit freeze this script only ever appends.
#
# These sprites have no era. One per ammo type, shared by every era that fires it, so the registry
# they feed is a flat id list rather than a line -> eras coverage table.
#
# The speck floor is much lower than the unit freeze's. A projectile is a few dozen pixels at field
# size and several are small, single, compact objects; the 1200 px floor tuned for figure groups
# would delete a whole arrow. Nothing here has detached parts to preserve either, so the floor only
# has to beat keying residue.
#
# Run with the ComfyUI venv python from assets/pipeline/.
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from phase2_freeze import border_seed, flood
from phase3_units_freeze import drop_specks

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-projectiles-topdown")
OUT = "../approved/projectiles"
PICKS = "phase3_projectiles_topdown_picks.json"
STATE = "phase3_projectile_topdown_state.json"
MANIFEST = "manifest.jsonl"
CHECKPOINT = "krea2_turbo_bf16@78bbf8f4"
LORAS = [["Krea2_Moebius_LoRA", 1.0]]
SPECK_MIN_PX = 120
POST = {"key": "border-flood", "tolerance": 60, "cropped": True, "speck_min_px": SPECK_MIN_PX}

# NO ENCLOSED-POCKET PASS HERE, deliberately, and this is the opposite call from the one the unit
# freeze makes — so the reason is measured rather than asserted. That pass cuts background-coloured
# pixels the border flood cannot reach, which on units removes the hole inside a bow or a sling. Run
# over these eight it removes almost nothing and breaks one sprite: arrow and bolt shed ~3k px each
# (invisible at the size these are read), bullet, cannonball, shell and stone shed 0-40, missile
# sheds 50 because its fin gaps are shaded rather than flat — and proj_bomb loses 12k px out of its
# own body, because a grey bomb lit from above has highlights within tolerance of a grey plate. It
# ships as a hole punched through the bomb, invisible on the light sheet and black on a dark plate.
# The class simply has no closed loops to fix: these are compact single objects seen from above.
POCKET_TOL = None


def render_recipe(stem: str) -> dict:
    wf = json.loads(Image.open(f"{SRC}/{stem}_00001_.png").info["prompt"])
    prompt, seed, denoise, parent = None, None, None, None
    for node in wf.values():
        ct = node.get("class_type")
        if ct == "KSampler":
            seed, denoise = node["inputs"]["seed"], node["inputs"]["denoise"]
        elif ct == "LoadImage":
            parent = node["inputs"]["image"].removesuffix("_00001_.png")
        elif ct == "CLIPTextEncode" and prompt is None:
            prompt = node["inputs"]["text"]
    return {"prompt": prompt, "seed": seed, "denoise": denoise, "parent": parent}


def keyed(stem: str) -> Image.Image:
    rgb = np.asarray(Image.open(f"{SRC}/{stem}_00001_.png").convert("RGB")).astype(np.uint8)
    h, w, _ = rgb.shape
    corners = np.stack([rgb[3, 3], rgb[3, w - 4], rgb[h - 4, 3], rgb[h - 4, w - 4]]).astype(int)
    bg = np.median(corners, axis=0)
    dist = np.abs(rgb.astype(int) - bg).sum(axis=2)
    opaque = drop_specks(~flood(dist < 60, border_seed((h, w))), SPECK_MIN_PX)
    if POCKET_TOL is not None:
        opaque &= ~(dist < POCKET_TOL)
    alpha = np.where(opaque, 255, 0).astype(np.uint8)
    ys, xs = np.where(alpha > 0)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA").crop(
        (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    with open(PICKS) as f:
        picks = json.load(f)["picks"]
    with open(STATE) as f:
        state = json.load(f)

    sprites: dict[str, Image.Image] = {}
    rows_new = []
    for ammo, seed in sorted(picks.items()):
        stem = state[ammo][str(seed)]["stem"]
        s = keyed(stem)
        s.save(f"{OUT}/{ammo}.png")
        sprites[ammo] = s
        rows_new.append({"id": stem, "file": f"assets/approved/projectiles/{ammo}.png",
                         "class": "projectile-topdown", "subject": ammo,
                         **render_recipe(stem), "checkpoint": CHECKPOINT, "loras": LORAS,
                         "workflow": "workflows/krea2_lora_txt2img.json", "post": POST,
                         "status": "approved", "camera": "top-down (ADR-0009)"})
        print(f"froze {ammo}.png {s.width}x{s.height} <- {stem}")

    new_ids = {r["id"] for r in rows_new}
    rows_out = []
    with open(MANIFEST) as f:
        for raw in f:
            e = json.loads(raw)
            if e["id"] not in new_ids:          # re-run: the fresh row below replaces it
                rows_out.append(e)
    rows_out += rows_new
    with open(MANIFEST, "w") as f:
        f.write("\n".join(json.dumps(e, ensure_ascii=False) for e in rows_out) + "\n")
    print(f"manifest: +{len(rows_new)} approved rows")

    json.dump(sorted(picks), open("phase3_projectiles_topdown_coverage.json", "w"),
              ensure_ascii=False, indent=1)
    print("wrote phase3_projectiles_topdown_coverage.json (registry source for AssetPaths.PROJECTILES)")

    # Halo check, plus the check that actually matters for this class: these sprites are read at
    # FIELD SIZE, where a projectile is a few dozen pixels and reads by silhouette and colour alone.
    # So each ammo type gets a full-size pair on dark and light AND a battle-zoom pair beside it.
    cell, zoom, pad = 260, 64, 8
    font = ImageFont.load_default(size=13)
    sheet = Image.new("RGB", ((cell + zoom + pad) * len(sprites), cell * 2 + 26), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for col, (ammo, sprite) in enumerate(sprites.items()):
        big = sprite.copy()
        big.thumbnail((cell - 2 * pad, cell - 2 * pad), Image.LANCZOS)
        small = sprite.copy()
        small.thumbnail((zoom, zoom), Image.LANCZOS)
        x = col * (cell + zoom + pad)
        for row, bgc in enumerate([(20, 20, 30), (235, 235, 225)]):
            tile = Image.new("RGBA", (cell + zoom + pad, cell), bgc + (255,))
            tile.alpha_composite(big, ((cell - big.width) // 2, (cell - big.height) // 2))
            tile.alpha_composite(small, (cell + pad // 2, (cell - small.height) // 2))
            sheet.paste(tile.convert("RGB"), (x, row * cell))
        d.text((x + pad, cell * 2 + 6), ammo, fill=(220, 220, 220), font=font)
    sheet.save("../contact-sheets/phase3_projectiles_topdown_halo_check.png")
    print("wrote ../contact-sheets/phase3_projectiles_topdown_halo_check.png "
          "(full size + battle zoom, on dark and light)")


if __name__ == "__main__":
    main()
