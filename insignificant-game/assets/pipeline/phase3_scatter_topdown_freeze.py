# phase3_scatter_topdown_freeze.py — freeze the human-picked neutral field scatter (W14.8).
#
# Border flood key, speck drop, tight crop into a NEW directory, ../approved/scatter/<id>.png. New
# because the class is new: bare top-down plates need ground dressing that is not plate paint
# (phase3_scatter_topdown_batch.py's header). Nothing here supersedes anything, so like the
# projectile freeze this script only ever appends to the manifest.
#
# Scatter has no era and no facing. One sprite per id, shared by every era that fights on that
# battle type, and the view may rotate it freely — so the registry it feeds is grouped by BATTLE
# TYPE rather than by era coverage.
#
# THE SPECK FLOOR IS THE LOW ONE, AND FOR A REASON UNIQUE TO THIS CLASS. Every other class treats a
# detached blob as keying residue: a unit's 1200 px floor deletes it, a projectile's 120 px floor
# only has to beat noise because those subjects are single compact objects. Half the scatter cores
# deliberately ASK for detached parts — "a few strays lying loose around it", "a few strays around
# it", "part buried in ash" — because a heap with nothing spilled out of it reads as placed rather
# than dropped. Those strays are the subject, not residue, so the floor sits just above noise.
#
# Run with the ComfyUI venv python from assets/pipeline/.
#   phase3_scatter_topdown_freeze.py             # freeze every picked prop
#   phase3_scatter_topdown_freeze.py --measure   # per-sprite cost of the enclosed-pocket pass
import argparse
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from phase2_freeze import border_seed, flood
from phase3_units_freeze import drop_specks
from phase3_backgrounds_topdown_batch import OUT as BG_OUT
from phase3_backgrounds_topdown_batch import stem as bg_stem
from phase3_scatter_topdown_batch import OUT as SRC
from phase3_scatter_topdown_batch import SCATTER

PICKS = "phase3_scatter_topdown_picks.json"
BG_PICKS = "phase3_backgrounds_topdown_picks.json"
STATE = "phase3_scatter_topdown_state.json"
OUT = "../approved/scatter"
MANIFEST = "manifest.jsonl"
CHECKPOINT = "krea2_turbo_bf16@78bbf8f4"
LORAS = [["Krea2_Moebius_LoRA", 1.0]]
SPECK_MIN_PX = 150
FLOOD_TOL = 60

# The enclosed-pocket pass (the unit freeze's §8 fix: cut background-coloured pixels the border
# flood cannot reach, at a much tighter tolerance than the flood's) is OFF here, and --measure is
# what settles it rather than assertion. Two things make this class the wrong place for it. Scatter
# subjects are heaps, spills and marks — they have no closed loops for background to be trapped
# inside, which is the entire defect that pass exists to remove. And several cores are deliberately
# pale and low-contrast against studio grey (white marble chips, white ash, pale dry wood, grey
# field stones), which is exactly the material the pass eats: `proj_bomb` lost 12k px of its own
# body the same way. Re-run --measure and re-read this comment before switching it on.
POCKET_TOL = None
POST = {"key": "border-flood", "tolerance": FLOOD_TOL, "cropped": True,
        "speck_min_px": SPECK_MIN_PX}


def render_recipe(stem: str) -> dict:
    wf = json.loads(Image.open(f"{SRC}/{stem}_00001_.png").info["prompt"])
    prompt, seed, denoise = None, None, None
    for node in wf.values():
        ct = node.get("class_type")
        if ct == "KSampler":
            seed, denoise = node["inputs"]["seed"], node["inputs"]["denoise"]
        elif ct == "CLIPTextEncode" and prompt is None:
            prompt = node["inputs"]["text"]
    return {"prompt": prompt, "seed": seed, "denoise": denoise}


def opaque_mask(stem: str) -> tuple:
    rgb = np.asarray(Image.open(f"{SRC}/{stem}_00001_.png").convert("RGB")).astype(np.uint8)
    h, w, _ = rgb.shape
    corners = np.stack([rgb[3, 3], rgb[3, w - 4], rgb[h - 4, 3], rgb[h - 4, w - 4]]).astype(int)
    bg = np.median(corners, axis=0)
    dist = np.abs(rgb.astype(int) - bg).sum(axis=2)
    opaque = drop_specks(~flood(dist < FLOOD_TOL, border_seed((h, w))), SPECK_MIN_PX)
    return rgb, dist, opaque


def keyed(stem: str) -> Image.Image:
    rgb, dist, opaque = opaque_mask(stem)
    if POCKET_TOL is not None:
        opaque &= ~(dist < POCKET_TOL)
    alpha = np.where(opaque, 255, 0).astype(np.uint8)
    ys, xs = np.where(alpha > 0)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA").crop(
        (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def plate_patch(battle_type: str, size: int) -> Image.Image | None:
    with open(BG_PICKS) as f:
        seed = json.load(f)["picks"][battle_type]
    path = f"{BG_OUT}/{bg_stem(battle_type, seed)}_00001_.png"
    if not os.path.exists(path):
        return None
    im = Image.open(path).convert("RGB")
    cx, cy = im.width // 2, im.height // 2
    return im.crop((cx - size // 2, cy - size // 2, cx + size // 2, cy + size // 2))


def measure(picks: dict, state: dict) -> None:
    """What the enclosed-pocket pass would cost each sprite, in px and as a share of its body."""
    print(f"{'id':28} {'body px':>9} {'pocket loss @25':>16} {'share':>7}")
    for pid, seed in sorted(picks.items()):
        _, dist, opaque = opaque_mask(state[pid][str(seed)]["stem"])
        body = int(opaque.sum())
        lost = int((opaque & (dist < 25)).sum())
        print(f"{pid:28} {body:9d} {lost:16d} {lost / max(body, 1):6.1%}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--measure", action="store_true")
    args = ap.parse_args()

    with open(PICKS) as f:
        picks = json.load(f)["picks"]
    with open(STATE) as f:
        state = json.load(f)
    unknown = set(picks) - set(SCATTER)
    if unknown:
        raise SystemExit(f"picks name props the batch does not define: {sorted(unknown)}")
    if args.measure:
        measure(picks, state)
        return

    os.makedirs(OUT, exist_ok=True)
    sprites, rows_new = {}, []
    for pid, seed in sorted(picks.items()):
        battle_type = SCATTER[pid][0]
        stem = state[pid][str(seed)]["stem"]
        s = keyed(stem)
        s.save(f"{OUT}/{pid}.png")
        sprites[pid] = (battle_type, s)
        rows_new.append({"id": stem, "file": f"assets/approved/scatter/{pid}.png",
                         "class": "scatter-topdown", "subject": pid, "battle_type": battle_type,
                         **render_recipe(stem), "checkpoint": CHECKPOINT, "loras": LORAS,
                         "workflow": "workflows/krea2_lora_txt2img.json", "post": POST,
                         "status": "approved", "camera": "top-down (ADR-0009)",
                         "role": "decoration only — no blocking, no cover, no rule reads it "
                                 "(decisions.md W14.8)"})
        print(f"froze {pid}.png {s.width}x{s.height} <- {stem}")

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

    coverage = {}
    for pid, (battle_type, _) in sorted(sprites.items()):
        coverage.setdefault(battle_type, []).append(pid)
    with open("phase3_scatter_topdown_coverage.json", "w") as f:
        json.dump(coverage, f, ensure_ascii=False, indent=1)
    print("wrote phase3_scatter_topdown_coverage.json (registry source for AssetPaths.SCATTER)")

    # Halo check on the only background that matters for this class: each prop's own plate, at the
    # size it ships. A prop is dressing for one ground and is never drawn on any other.
    cell, pad, field = 300, 8, 90
    font = ImageFont.load_default(size=13)
    by_type: dict[str, list] = {}
    for pid, (battle_type, s) in sprites.items():
        by_type.setdefault(battle_type, []).append((pid, s))
    cols = max(len(v) for v in by_type.values())
    sheet = Image.new("RGB", (cell * cols, (cell + 22) * len(by_type)), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for row, (battle_type, props) in enumerate(sorted(by_type.items())):
        patch = plate_patch(battle_type, cell)
        y = (cell + 22) * row
        for col, (pid, s) in enumerate(sorted(props)):
            tile = (patch.copy() if patch else Image.new("RGB", (cell, cell), (60, 60, 60)))
            big = s.copy()
            big.thumbnail((cell - 2 * pad, cell - 2 * pad), Image.LANCZOS)
            small = s.copy()
            small.thumbnail((field, field), Image.LANCZOS)
            tile.paste(big, ((cell - big.width) // 2, (cell - big.height) // 2), big)
            tile.paste(small, (cell - small.width - pad, cell - small.height - pad), small)
            sheet.paste(tile, (cell * col, y))
            d.text((cell * col + pad, y + cell + 4), pid.removeprefix("scat_"),
                   fill=(220, 220, 220), font=font)
    sheet.save("../contact-sheets/phase3_scatter_topdown_halo_check.png")
    print("wrote ../contact-sheets/phase3_scatter_topdown_halo_check.png "
          "(each prop on its own plate, sheet size + on-field size)")


if __name__ == "__main__":
    main()
