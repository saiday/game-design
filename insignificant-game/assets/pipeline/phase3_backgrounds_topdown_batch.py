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
# Per-type identity therefore rests on GROUND MATERIAL, COLOUR AND LIGHT alone — wheat stubble,
# turf, cracked ash, cobbles, marble, mud, crater black. That narrows style bible §11's claim that
# the backdrop is "the first thing that tells the player which battle this is": it still is, but it
# says so with a surface rather than with scenery.
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

SEEDS = [161, 162, 163, 164]  # round 2: +100 per cookbook §4
W, H = 1920, 1088
T2I = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-backgrounds-topdown")
STATE = "phase3_background_topdown_state.json"

# The route map's tail (proven top-down on a hand-painted landscape) plus the two clauses that
# stop the model reinstating a horizon, which is the failure this camera invites.
STYLE = (", hand-painted game background art, watercolor and ink illustration, soft flat colors, "
         "clean line work, top-down view seen from directly overhead, flat ground filling the "
         "entire frame edge to edge, no sky and no horizon")

PLATES = {
    "battle_tax": (
        "a flat expanse of harvested farmland ground seen from directly above, even rows of short "
        "golden wheat stubble over dry brown tilled soil, fine parallel plough furrows running "
        "across the whole surface, a scattering of loose straw, uniform warm morning light"),
    "battle_field": (
        "a flat expanse of open grassland seen from directly above, short trampled green turf with "
        "worn patches of bare brown soil showing through, small tufts of clover and low weeds "
        "spread evenly across the whole surface, uniform midday light"),
    "battle_hidden": (
        "a flat expanse of scorched cracked earth seen from directly above, a dense network of dry "
        "fissures across dark grey-green ground, a faint pale green luminous haze lying evenly over "
        "the whole surface, fine pale ash gathered in the cracks, uniform cold light"),
    "battle_riot": (
        "a flat expanse of city street paving seen from directly above, close-fitted grey granite "
        "cobblestones in even fan-shaped courses across the whole surface, soot smudges and pale "
        "scattered ash between the stones, damp patches darkening the stone, uniform overcast light"),
    "battle_democracy": (
        "a flat expanse of monumental plaza paving seen from directly above, large pale marble slabs "
        "in a regular grid with fine dark joint lines across the whole surface, faint veining in the "
        "stone and a light drift of dead leaves caught along the joints, uniform cold early morning "
        "light"),
    "battle_civwar": (
        "a flat expanse of churned battle-torn ground seen from directly above, deep brown mud "
        "worked into overlapping ruts and boot-churned hollows across the whole surface, shallow "
        "pools of standing rainwater reflecting grey, uniform storm light"),
    "battle_worldwar": (
        "a flat expanse of scorched cratered earth seen from directly above, blackened soil pitted "
        "with shallow overlapping shell craters across the whole surface, grey ash and fine rubble "
        "grit spread evenly between them, uniform dark red-tinted light"),
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
