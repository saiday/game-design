# phase3_scatter_topdown_freeze.py — freeze the human-picked neutral field scatter (W14.8).
#
# Border flood key, speck drop, tight crop into a NEW directory, ../approved/scatter/<id>.png. New
# because the class is new: bare top-down plates need ground dressing that is not plate paint
# (phase3_scatter_topdown_batch.py's header). Nothing here supersedes anything, so like the
# projectile freeze this script only ever appends to the manifest.
#
# Scatter has no era and no facing. Its sprites are shared by every era that fights on that battle
# type and the view may rotate them freely, so the registry it feeds is grouped by BATTLE TYPE
# rather than by era coverage.
#
# ONE PROP CAN SHIP SEVERAL SPRITES. The human approved most rows as "use all seeds", so a prop is
# a list of interchangeable variants (`<id>_v1.png` .. `<id>_vN.png`) rather than one file: the view
# scatters the same prop repeatedly and four cuts of a rubble heap stop that reading as tiling. A
# single-seed row is just a one-variant list, so the registry never has to branch.
#
# THE BARRIER TIER IS A RULE VALUE, NOT ART METADATA (ADR-0010). A barrier-carrying prop is a 盾陣
# that belongs to nobody: it absorbs ranged fire aimed at the unit sheltering behind it (weak 1-2
# shots, medium 2-3, hard 3-5) and is destroyed, never repaired, when its budget runs out. The core
# reads how many barriers a battle type fields off this table and nowhere else (decisions.md W14.9),
# so an edit to a `barrier` value in the picks file is a game change, not a re-render.
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
#
# MEASURED, and it stays off. Across the 53 approved sprites the pass finds almost nothing: 44 lose
# under 0.1% of their body, for the reason predicted above — heaps and spills have no enclosed loops
# for background to be trapped inside. The one sprite it would visibly change is the one it would
# ruin: `scat_democracy_rubble_v1` is white marble chips and loses 81,976 px, 15.9% of itself, the
# same failure as `proj_bomb`. Nothing else gains enough to pay for that, so the border flood is the
# whole key for this class.
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


def variants(picks: dict) -> list:
    """(pid, battle_type, barrier, variant_index, seed) for every sprite the gate approved."""
    out = []
    for pid, pick in sorted(picks.items()):
        for i, seed in enumerate(pick["seeds"], start=1):
            out.append((pid, SCATTER[pid][0], pick["barrier"], i, seed))
    return out


def measure(picks: dict, state: dict) -> None:
    """What the enclosed-pocket pass would cost each sprite, in px and as a share of its body."""
    print(f"{'sprite':32} {'body px':>9} {'pocket loss @25':>16} {'share':>7}")
    for pid, _, _, i, seed in variants(picks):
        _, dist, opaque = opaque_mask(state[pid][str(seed)]["stem"])
        body = int(opaque.sum())
        lost = int((opaque & (dist < 25)).sum())
        print(f"{f'{pid}_v{i}':32} {body:9d} {lost:16d} {lost / max(body, 1):6.1%}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--measure", action="store_true")
    args = ap.parse_args()

    with open(PICKS) as f:
        gate = json.load(f)
    picks, dropped = gate["picks"], gate.get("dropped", {})
    with open(STATE) as f:
        state = json.load(f)
    unknown = set(picks) - set(SCATTER)
    if unknown:
        raise SystemExit(f"picks name props the batch does not define: {sorted(unknown)}")
    ungated = set(SCATTER) - set(picks) - set(dropped)
    if ungated:
        raise SystemExit(f"rendered props neither picked nor dropped: {sorted(ungated)}")
    if args.measure:
        measure(picks, state)
        return

    os.makedirs(OUT, exist_ok=True)
    sprites, rows_new = {}, []
    for pid, battle_type, barrier, i, seed in variants(picks):
        stem = state[pid][str(seed)]["stem"]
        name = f"{pid}_v{i}"
        s = keyed(stem)
        s.save(f"{OUT}/{name}.png")
        sprites[name] = (battle_type, s)
        rows_new.append({"id": stem, "file": f"assets/approved/scatter/{name}.png",
                         "class": "scatter-topdown", "subject": pid, "variant": i,
                         "battle_type": battle_type, "barrier": barrier,
                         **render_recipe(stem), "checkpoint": CHECKPOINT, "loras": LORAS,
                         "workflow": "workflows/krea2_lora_txt2img.json", "post": POST,
                         "status": "approved", "camera": "top-down (ADR-0009)",
                         "role": "neutral cover (ADR-0010): a barrier-carrying prop absorbs ranged "
                                 "fire for whoever shelters behind it and is destroyed, never "
                                 "repaired; barrier=none props are ground dressing"})
        print(f"froze {name}.png {s.width}x{s.height} <- {stem} [{barrier}]")
    for pid, why in sorted(dropped.items()):
        print(f"dropped {pid}: {why}")

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

    # The registry source, and also the rule source: `barriers` is the count of neutral cover the
    # core fields on this ground (decisions.md W14.9), which is why it is computed here from the
    # approved set rather than typed anywhere by hand.
    coverage: dict = {}
    for pid, battle_type, barrier, i, _ in variants(picks):
        props = coverage.setdefault(battle_type, {"props": [], "barriers": 0})["props"]
        if not props or props[-1]["id"] != pid:
            props.append({"id": pid, "barrier": barrier, "variants": []})
            if barrier != "none":
                coverage[battle_type]["barriers"] += 1
        props[-1]["variants"].append(f"{pid}_v{i}.png")
    with open("phase3_scatter_topdown_coverage.json", "w") as f:
        json.dump(coverage, f, ensure_ascii=False, indent=1)
    print("wrote phase3_scatter_topdown_coverage.json (registry source for AssetPaths.SCATTER; "
          "barrier counts per battle type: "
          + ", ".join(f"{t}={c['barriers']}" for t, c in sorted(coverage.items())) + ")")

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
