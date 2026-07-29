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

SEEDS = [361, 362, 363, 364]  # round 4: +100 per cookbook §4
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
# So every core below is phrased as a REPEATING PATTERN OF IDENTICAL UNITS, with the scale constant
# stated positively per unit. No "expanse", no "seen from directly above" (that names a viewer),
# no lighting condition. Per-type identity still rests on ground material alone.
PLATES = {
    "battle_tax": (
        "an even repeating pattern of short golden wheat stubble tufts standing in dry brown tilled "
        "soil, every tuft the same size and shape as every other, straight parallel plough furrows "
        "of constant width, loose straw scattered evenly between the rows"),
    "battle_field": (
        "an even repeating pattern of short trampled green turf broken by worn patches of bare brown "
        "soil, every worn patch the same size as every other, small tufts of clover and low weeds "
        "spread evenly at a constant spacing"),
    "battle_hidden": (
        "a regular network of dry fissures across dark grey-green scorched ground, every cracked "
        "plate of earth the same size and shape as every other, fine pale ash gathered in the "
        "cracks, a faint pale green luminous glow lying evenly in the fissures"),
    "battle_riot": (
        "a regular grid of close-fitted grey granite cobblestones, every cobble the same size and "
        "shape as every other, laid in even repeating fan-shaped courses, crisp joint lines, soot "
        "smudges and pale scattered ash caught in the joints"),
    "battle_democracy": (
        "a regular grid of large pale marble slabs, every slab the same size and shape as every "
        "other, fine dark joint lines of constant width between them, faint veining in the stone, "
        "a light drift of dead leaves caught evenly along the joints"),
    "battle_civwar": (
        "an even repeating pattern of deep brown mud ruts and boot-churned hollows, every rut the "
        "same width and depth as every other, shallow pools of standing rainwater spread evenly "
        "between them"),
    "battle_worldwar": (
        "an even repeating pattern of shallow shell craters pitting blackened soil, every crater the "
        "same size and shape as every other, grey ash and fine rubble grit spread evenly between "
        "them, faint dull red staining in the soil"),
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
    args = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    state = load_state()
    todo = [(p, s) for p in PLATES for s in SEEDS if not rendered(stem(p, s))]
    print(f"{len(PLATES)} plates x {len(SEEDS)} seeds; {len(todo)} to render "
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
