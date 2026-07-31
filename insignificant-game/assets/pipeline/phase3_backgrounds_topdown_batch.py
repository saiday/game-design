# phase3_backgrounds_topdown_batch.py — W14.8 top-down re-render of the 7 battle backdrop plates
# (ADR-0009). The other 10 plates in inventory.md Backgrounds are untouched: the city panorama
# stays a side-view valley by design (style bible §11) and the route map was already top-down.
#
# A battle plate is FLAT GROUND AND NOTHING ELSE. Round 1 rewrote each landscape as a ground plane
# but kept the scene's props — trees, fences, hay bales, barricades, colonnades, trenches, siege
# wreckage — and the human rejected all 7. Units move and fight across this surface, and a prop
# baked into the plate is an obstacle the engine cannot move, cannot occlude and cannot let a
# sprite stand behind. **Anything a unit could collide with is a separate field object, never
# plate paint.** 盾陣 is the worked example: it is already its own sprite (fort_shield_wall_*),
# placed by 自動佈陣, not scenery.
#
# Per-type identity therefore rests on GROUND MATERIAL AND COLOUR alone — wheat stubble, turf,
# cracked ash, cobbles, marble, mud, crater black. Light is not a lever here: naming a lighting
# condition is one of the things that summons a photographed scene (see the register note below).
# That narrows style bible §11's claim that the backdrop is "the first thing that tells the player
# which battle this is": it still is, but it says so with a surface rather than with scenery.
#
# Two rules carried forward, both §14-standing:
#  - Landscape subjects REQUIRE the style-carrying suffix or they render photoreal (cookbook §8.4).
#    The tail here is the route map's proven `top-down view` variant, not the panoramic one.
#  - Do NOT pin emptiness with denial words ("empty", "deserted", "no objects"). §8.3 rung 1: a
#    denial leaves the surface unnamed, and unnamed surfaces breed occupants. Occupy the whole
#    frame by describing the ground material densely instead, which is what every prompt below
#    does. The word "battlefield" is avoided for the same reason — it summons armies and wreckage.
#
# Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_backgrounds_topdown_batch.py            # every missing plate/seed, resumable
#   phase3_backgrounds_topdown_batch.py --plan
import argparse
import json
import os
import subprocess
import sys

SEEDS = [561, 562, 563, 564]  # round 6: civwar only, the material fix (+100 per cookbook §4)
W, H = 1920, 1088
T2I = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-backgrounds-topdown")
STATE = "phase3_background_topdown_state.json"

# Round 2 killed the props but not the CAMERA. Every plate came back as a ground plane receding
# away from a tilted viewer: features at the bottom of the frame render 3-5x larger than the same
# features at the top (verified by cropping the top and bottom 200px of a plate and comparing them
# at equal scale — cobbles, wheat and marble slabs all halve in size up the frame). That is fatal
# here for a reason the side-view set never had: under ADR-0009 a station's screen position is just
# its lane slot, so two units of equal size stand at the top and bottom of the same field. On a
# receding plate one of them stands on cobbles smaller than its boots and the other on cobbles
# bigger than its body, and the plate silently reintroduces the depth the camera exists to remove.
#
# "seen from directly overhead" plus "no sky and no horizon" was not enough: it removes the horizon
# while leaving the ground plane tilted, which is exactly what shipped. The lever that works is to
# stop asking for a SCENE at all and ask for a TEXTURE — a flat material swatch has no viewer
# position to recede from. Hence "seamless tileable ground texture", "photographed flat", and the
# scale constant stated positively (every feature the same size everywhere) rather than as a denial
# of perspective, per §8.3 rung 1.
STYLE = (", hand-painted game background art, watercolor and ink illustration, soft flat colors, "
         "clean line work, a flat seamless tileable ground texture swatch laid out square to the "
         "frame and photographed flat from straight above, orthographic, every feature of the "
         "surface drawn at exactly the same size in every part of the image, even flat lighting "
         "across the whole swatch, no sky and no horizon")

# REGISTER, not vocabulary. Rounds 1-3 all rewrote these cores as "a flat expanse of X seen from
# directly above ... under uniform Y light" and all three came back as a ground plane receding from
# a tilted viewer. A 2x2 probe isolated why:
#
#                      wide 1920x1088      square 1088x1088
#   cobbles, as prose  RECEDES             flat
#   checkerboard       flat                 -
#
# Neither variable does it alone. A wide frame is fine if you ask for a PATTERN; material prose is
# fine if you ask for it SQUARE. The failure is the pair: a wide frame plus scene language reads as
# a landscape photograph, and the model supplies a viewer standing in it. "Expanse" implies extent
# away from someone, and naming a lighting condition ("uniform overcast light") is what a
# photograph has, not what a texture has. A follow-up probe held the shipped wide frame and only
# changed register — "a regular grid of cobbles, every cobble the same size as every other" — and
# came back flat at 1920x1088.
#
# So every core below is phrased as a PATTERN, not a scene. No "expanse", no "seen from directly
# above" (that names a viewer), no lighting condition. Per-type identity still rests on ground
# material alone.
#
# Three more probes at the same seed and frame refined that, and two of them contradict what the
# first fix assumed:
#
#  1. THE PER-CORE SCALE-CONSTANCY CLAUSE IS REDUNDANT. Deleting "every rut the same width as every
#     other" from two cores left both flat. The STYLE tail already carries a scale sentence, and the
#     pattern register does the rest, so the per-core clause only ever cost variety. It is gone from
#     every core that was re-rolled; `riot` and `hidden` keep theirs because they rendered well and a
#     working cell is not a place to test a theory.
#  2. VARIATION HAS TO BE STATED POSITIVELY for a material that is irregular in life. "An even
#     repeating pattern of mud ruts" is a contradiction, and the model resolves it by inventing a
#     tiling — a lattice of identical quilted lozenges. "Ruts of many different lengths, widths and
#     depths running in every direction and crossing over one another" renders irregular AND flat.
#     This is §8.3 rung 1 again, applied to sameness rather than to absence: occupy the slot with
#     the variety you want instead of deleting the word that forced uniformity.
#  3. A SET OF LONG STRAIGHT PARALLEL LINES IS A PERSPECTIVE TRIGGER BY ITSELF. `battle_tax` was the
#     last plate still receding, and the cause was naming plough furrows. Restating them against the
#     frame ("crossing the frame from side to side at a constant spacing") did not help — that render
#     converged harder than the one it was meant to fix. Removing the furrows and occupying their
#     space with soil detail rendered flat, and the model still supplies implied planting rows, at
#     constant scale. So do not name a long-line feature (furrow, lane, rail, seam, row) in a flat
#     texture core at all; describe the material and let the rows emerge.
PLATES = {
    # the probe-verified wording: no furrows named, their space occupied by soil detail
    "battle_tax": (
        "a close-packed field of short golden wheat stubble tufts of many different sizes and "
        "thicknesses standing in crumbled dry brown tilled soil, clods of turned earth and loose "
        "straw scattered evenly among the tufts"),
    "battle_field": (
        "a close-packed field of short trampled green turf broken by worn bare patches of many "
        "different sizes and shapes, small tufts of clover and low weeds scattered unevenly among "
        "them, thin pale dust scuffed across the bare soil"),
    "battle_hidden": (
        "a regular network of dry fissures across dark grey-green scorched ground, every cracked "
        "plate of earth the same size and shape as every other, fine pale ash gathered in the "
        "cracks, a faint pale green luminous glow lying evenly in the fissures"),
    "battle_riot": (
        "a regular grid of close-fitted grey granite cobblestones, every cobble the same size and "
        "shape as every other, laid in even repeating fan-shaped courses, crisp joint lines, soot "
        "smudges and pale scattered ash caught in the joints"),
    "battle_democracy": (
        "a close-packed pavement of large pale marble slabs of several different sizes laid in an "
        "irregular running bond, fine dark joint lines between them, faint veining and chipped "
        "corners varying from slab to slab, a light drift of dead leaves caught along the joints"),
    # Structure was never this plate's problem after the register fix — MATERIAL was. "Ruts and
    # hollows crossing over one another" is a cellular-network instruction, and a cellular network of
    # pale cells with dark boundaries is cracked earth, which is battle_hidden's material and makes
    # the two plates confusable. Identity here rests on ground material alone, so the network phrase
    # is gone and the material words carry it: wet not dry, dark not pale, water named as a feature.
    "battle_civwar": (
        "a close-packed field of wet dark brown churned mud in many different tones, shallow puddles "
        "of standing rainwater lying in the deeper hollows, trodden straw and torn grass pressed "
        "into the surface"),
    # probe-verified: the clause dropped and nothing else, which is what gave the craters back their
    # variety in size, shape and spacing
    "battle_worldwar": (
        "an even repeating pattern of shallow shell craters pitting blackened soil, grey ash and fine "
        "rubble grit spread evenly between them, faint dull red staining in the soil"),
}


def load_state() -> dict:
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(s: dict) -> None:
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(s, f, indent=1, ensure_ascii=False)
    os.replace(tmp, STATE)


def stem(plate: str, seed: int) -> str:
    return f"p3_bgtd_{plate}_s{seed}"


def rendered(s: str) -> bool:
    return os.path.exists(f"{OUT}/{s}_00001_.png")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", action="store_true")
    ap.add_argument("--ids", help="comma-separated subset; a round that re-rolls only some plates "
                                  "must name them, or the ones that already rendered well get "
                                  "re-rolled too")
    args = ap.parse_args()
    ids = args.ids.split(",") if args.ids else list(PLATES)

    os.makedirs(OUT, exist_ok=True)
    state = load_state()
    todo = [(p, s) for p in ids for s in SEEDS if not rendered(stem(p, s))]
    print(f"{len(ids)} plates x {len(SEEDS)} seeds; {len(todo)} to render "
          f"(~{len(todo) * 300 / 3600:.1f} h at 1920x1088)", flush=True)
    if args.plan:
        for p, s in todo:
            print(f"  {stem(p, s)}\n     {PLATES[p] + STYLE}")
        return
    for i, (p, s) in enumerate(todo, 1):
        st = stem(p, s)
        prompt = PLATES[p] + STYLE
        cmd = [sys.executable, "comfy_run.py", T2I, "--seed", str(s), "--prompt", prompt,
               "--prefix", f"phase3-backgrounds-topdown/{st}",
               "--width", str(W), "--height", str(H), *LORA_ARGS]
        for attempt in (1, 2):
            print(f"--- [{i}/{len(todo)}] {st}" + (" (retry)" if attempt == 2 else ""), flush=True)
            if subprocess.run(cmd).returncode == 0:
                break
        else:
            raise SystemExit(f"{st} failed twice, aborting")
        state.setdefault(p, {})[str(s)] = {"stem": st, "seed": s, "prompt": prompt}
        save_state(state)
    print(f"BACKDROP SWEEP DONE: {len(todo)} rendered into {OUT}", flush=True)


if __name__ == "__main__":
    main()
