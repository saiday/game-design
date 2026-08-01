# phase3_units_topdown_freeze.py — freeze the human-picked top-down unit/fort/enemy roster
# (W14.8, ADR-0009). Sibling of phase3_units_freeze.py, which froze the side-view set this one
# replaces; the differences are all consequences of the camera change and are noted below.
#
# Same post-process as every sprite class: border flood key, speck drop, tight crop, write
# ../approved/units/unit_<line>_era<n>.png. The top-down set REPLACES the side-view files at the
# SAME paths, so this script overwrites 66 of them, deletes the 3 that lost their subject, and adds
# the one the side-view round never got (infantry era 4).
#
# Three things this script does that the side-view freeze did not:
#
#  1. NO LINEAGE, SO NO CHAIN PICK. Every top-down cell is a txt2img root (phase3_units_topdown_
#     sweep.py explains why), so the pick is one seed per cell rather than one chain per line, and
#     it is read from phase3_units_topdown_picks.json — the committed record of the human gate.
#  2. BARRIER ROTATION. Every 盾陣 sprite must ship running top to bottom, across the lane. The
#     render axis is an outcome, not something the prompt can ask for (naming it tapered three
#     rounds of walls), so it is measured per approved sprite and recorded in the picks file's
#     `barrier_render_axis`. Cells that landed off-axis by a clean right angle are turned here, once,
#     losslessly; anything that landed diagonal was re-rolled instead of turned, because an
#     arbitrary angle resamples the sprite and rotates its shading with it. After this script there
#     is no per-asset rotation left for the view to apply.
#  3. SUPERSESSION. The side-view rows in manifest.jsonl cannot stay `approved` once their files are
#     overwritten — asset_paths.gd's header promises that only status=approved assets appear in the
#     registry, and 76 rows describing art that no longer exists would make that false. The
#     vocabulary gains two values (decisions.md W14.8): `superseded` + `superseded_by` for a row
#     whose asset was replaced, and `retired` + `retired_reason` for one whose subject is gone.
#
# Run with the ComfyUI venv python from assets/pipeline/.
import json
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from phase2_freeze import border_seed, flood
from phase3_units_freeze import drop_specks

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-units-topdown")
OUT = "../approved/units"
PICKS = "phase3_units_topdown_picks.json"
STATE = "phase3_unit_topdown_chains.json"
MANIFEST = "manifest.jsonl"
CHECKPOINT = "krea2_turbo_bf16@78bbf8f4"
LORAS = [["Krea2_Moebius_LoRA", 1.0]]
POST = {"key": "border-flood", "tolerance": 60, "cropped": True}

# ADR-0006 retired 擋箭棚/箭樓/城防塔 outright: no air exists before 工業, so no anti-air does
# either, and core/data/cards.gd agrees. These three were never re-rendered, and their side-view
# files are deleted rather than replaced — the art inventory was the stale artifact, not the corpus.
RETIRED = {("anti_air", 1), ("anti_air", 2), ("anti_air", 3)}
RETIRED_REASON = "ADR-0006 retired the era 1-3 anti-air forms; the card has no such form to draw"

# ENCLOSED-POCKET TOLERANCE. A border flood cannot reach background that the subject encloses — the
# hole inside a drawn bow, the gap between a sling strap and the fist holding it, the space between
# missiles on a rail — so that background stays opaque and ships as a pale grey blob that is
# invisible on the light contact sheet and glaring on a dark battle plate. 60 of the 67 top-down
# cells enclose some, far more than the side-view set did: seen from above, a bow, a sling and a
# weapon rack all become closed loops that side-on views left open at the frame edge.
#
# So background-coloured pixels are cut whether or not the border can reach them — but at a MUCH
# tighter colour tolerance than the flood's 60. That gap is the whole trick. Trapped background is
# flat and exactly the plate colour, while pale SUBJECT material is shaded and reads a little off
# it, so 25 removes the pockets and keeps the white missiles on anti_air_e5 and the sanctioned white
# hull disc. Verified by rendering the alternatives: at 60 the same pass eats into the missiles.
POCKET_TOL = 25


def render_recipe(stem: str) -> dict:
    """Prompt/seed/denoise/parent as embedded in the render itself — render-time truth, never the
    batch script's current wording, which keeps iterating past what a picked seed rendered with."""
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
    opaque = drop_specks(~flood(dist < 60, border_seed((h, w))))
    opaque &= ~(dist < POCKET_TOL)          # background the subject encloses; see POCKET_TOL
    alpha = np.where(opaque, 255, 0).astype(np.uint8)
    ys, xs = np.where(alpha > 0)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA").crop(
        (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))


def turned(sprite: Image.Image, deg: int, name: str) -> Image.Image:
    """Right angles only, and only where the picks file asked for one. Anything else is a bug in
    the pick record rather than something to resample here: a non-right angle would rotate the
    sprite's shading along with its axis, which is why such a cell is re-rolled instead."""
    if deg % 360 == 0:
        return sprite
    if deg % 90:
        raise SystemExit(f"{name}: freeze_rotation_deg={deg} is not a right angle — re-roll the "
                         f"cell onto its axis instead of resampling it here")
    return sprite.rotate(deg, expand=True)


def build_plan(picks: dict, state: dict) -> dict:
    """(line, era) -> (stem, rotation). Exactly the picked cells, nothing inferred."""
    axis = picks.get("barrier_render_axis", {})
    plan: dict[tuple[str, int], tuple[str, int]] = {}
    for line, eras in picks["picks"].items():
        for era_s, seed in eras.items():
            era = int(era_s)
            cell = state[line][era_s][str(seed)]
            rot = 0
            if line == "shield_wall":
                entry = axis.get(era_s, {})
                if entry.get("seed") != seed:
                    raise SystemExit(f"shield_wall e{era}: picks say seed {seed} but "
                                     f"barrier_render_axis says {entry.get('seed')} — the axis "
                                     f"measurement belongs to a different render, so re-measure "
                                     f"before freezing")
                rot = int(entry.get("freeze_rotation_deg", 0))
            plan[(line, era)] = (cell["stem"], rot)
    return plan


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    with open(PICKS) as f:
        picks = json.load(f)
    with open(STATE) as f:
        state = json.load(f)
    if picks.get("awaiting_seed_pick"):
        raise SystemExit(f"awaiting_seed_pick is not empty: {picks['awaiting_seed_pick']} — "
                         f"every cell needs a named seed before the set can freeze")
    plan = build_plan(picks, state)

    # A cell with no pick and no retirement leaves its SIDE-VIEW file sitting at the path this
    # script writes to, so the shipped set would silently mix two cameras — the one defect ADR-0009
    # exists to remove, and the one hardest to see, because every other sprite around it is right.
    # Freezing a partial roster is still the correct thing to allow (a single re-rolling cell should
    # not hold 65 finished ones hostage), so this reports and continues rather than aborting.
    stale = []
    for line, eras in state.items():
        for era_s in eras:
            era = int(era_s)
            name = f"unit_{line}_era{era}"
            if (line, era) in plan or (line, era) in RETIRED:
                continue
            if os.path.exists(f"{OUT}/{name}.png"):
                stale.append(name)
    if stale:
        print(f"WARNING: {len(stale)} cell(s) have no pick yet, so their SIDE-VIEW file survives "
              f"and the shipped set mixes cameras until they land: {', '.join(stale)}")

    sprites: dict[str, Image.Image] = {}
    superseded: dict[str, str] = {}          # old manifest id -> new asset id
    coverage: dict[str, list[int]] = {}
    rows_new = []
    for (line, era), (stem, rot) in sorted(plan.items()):
        name = f"unit_{line}_era{era}"
        s = turned(keyed(stem), rot, name)
        s.save(f"{OUT}/{name}.png")
        sprites[name] = s
        coverage.setdefault(line, []).append(era)
        rows_new.append({"id": stem, "file": f"assets/approved/units/{name}.png",
                         "class": "unit-topdown", "subject": name,
                         **render_recipe(stem), "checkpoint": CHECKPOINT, "loras": LORAS,
                         "workflow": "workflows/krea2_lora_txt2img.json", "post": POST,
                         "status": "approved", "camera": "top-down (ADR-0009)",
                         **({"rotated_deg": rot} if rot else {})})
        print(f"froze {name}.png {s.width}x{s.height} <- {stem}" + (f" (turned {rot} deg)" if rot else ""))

    for line, era in sorted(RETIRED):
        stale = f"{OUT}/unit_{line}_era{era}.png"
        for path in (stale, stale + ".import"):
            if os.path.exists(path):
                os.remove(path)
                print(f"deleted {os.path.basename(path)} (retired, no replacement)")

    # Manifest: append the new approved rows, and stop the side-view rows they replace from
    # claiming to be the shipped art. A superseded row keeps every reproducibility field it had.
    new_ids = {r["id"] for r in rows_new}
    by_subject = {r["subject"]: r["id"] for r in rows_new}
    rows_out, marked, retired = [], 0, 0
    with open(MANIFEST) as f:
        for raw in f:
            e = json.loads(raw)
            if e["id"] in new_ids:
                continue                      # re-run: the fresh row below replaces it
            file = e.get("file") or ""
            if e.get("status") == "approved" and file.startswith("assets/approved/units/"):
                subject = os.path.basename(file).removesuffix(".png")
                line_era = subject.removeprefix("unit_").rsplit("_era", 1)
                if len(line_era) == 2 and (line_era[0], int(line_era[1])) in RETIRED:
                    e["status"], e["retired_reason"] = "retired", RETIRED_REASON
                    retired += 1
                elif subject in by_subject:
                    e["status"], e["superseded_by"] = "superseded", by_subject[subject]
                    superseded[e["id"]] = subject
                    marked += 1
            rows_out.append(e)
    rows_out += rows_new
    with open(MANIFEST, "w") as f:
        f.write("\n".join(json.dumps(e, ensure_ascii=False) for e in rows_out) + "\n")
    print(f"manifest: +{len(rows_new)} approved rows, {marked} superseded, {retired} retired")

    json.dump({k: sorted(v) for k, v in coverage.items()},
              open("phase3_units_topdown_coverage.json", "w"), ensure_ascii=False, indent=1)
    print("wrote phase3_units_topdown_coverage.json (registry source for AssetPaths.UNIT_COVERAGE)")

    # halo check: every sprite on a dark and a light backdrop (style bible §4). Top-down sprites
    # sit on ground plates that run from near-black crater soil to pale marble, so a halo that
    # hid on one plate would show on another.
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
    sheet.save("../contact-sheets/phase3_units_topdown_halo_check.png")
    print("wrote ../contact-sheets/phase3_units_topdown_halo_check.png")


if __name__ == "__main__":
    main()
