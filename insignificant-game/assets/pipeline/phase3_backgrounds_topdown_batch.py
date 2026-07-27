# phase3_backgrounds_topdown_batch.py — W14.8 top-down re-render of the 7 battle backdrop plates
# (ADR-0009). The other 10 plates in inventory.md Backgrounds are untouched: the city panorama
# stays a side-view valley by design (style bible §11) and the route map was already top-down.
#
# This is NOT a suffix swap. The approved battle plates are landscapes — horizon, distant hills,
# sky, "wide empty ground across the middle" — and a camera looking straight down has none of
# those. Each subject is rewritten as a GROUND PLANE: terrain filling the frame edge to edge, the
# scene's identity carried by ground texture and by props read from above, no sky and no horizon.
# The per-type backdrop is what tells the player which battle this is (style bible §11), so the
# identity cues (wheat plots, monolith stones, barricades, trenches, ash craters) are kept from the
# approved wording verbatim wherever a top-down view can still show them.
#
# Two rules carried forward unchanged from the side-view round, both §14-standing:
#  - Landscape subjects REQUIRE the style-carrying suffix or they render photoreal (cookbook §8.4).
#    The tail here is the route map's proven `top-down view` variant, not the panoramic one.
#  - Plates keep an EMPTY middle band: unit sprites composite there in engine and the plate never
#    draws them. Under this camera "middle ground" means the middle of the field, so the empty band
#    runs vertically down the centre where the two cover chains meet.
#
# The riot / democracy / civwar plates keep their hard-won anti-signage wording (no shopfront
# fascias, no venue noun that invites a crowd, no decorated shield faces) — those defects are
# properties of the subject, not of the camera, and the fixes cost three rounds each.
#
# Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_backgrounds_topdown_batch.py            # every missing plate/seed, resumable
#   phase3_backgrounds_topdown_batch.py --plan
import argparse
import json
import os
import subprocess
import sys

SEEDS = [61, 62, 63, 64]
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
        "open farmland seen from directly above, golden wheat plots in neat rectangles and round "
        "hay bales, a low wooden fence running along one side, cart ruts in brown earth, a wide "
        "band of bare flat dirt running down the middle of the field"),
    "battle_field": (
        "open countryside seen from directly above, rolling grass meadow with the round crowns of "
        "sparse trees and their shadows, patches of heather and bare soil, a wide band of trampled "
        "flat grass running down the middle of the field"),
    "battle_hidden": (
        "a scorched clearing seen from directly above, tall alien monolith stones casting long "
        "shadows across cracked ground, faint glowing mist pooling in the hollows, the bare crowns "
        "of twisted leafless trees around the edges, a wide band of flat empty ground running down "
        "the middle"),
    # riot: the residential street keeps its v3 shape — plain houses, no shopfronts, because
    # fascias are unfixable sign carriers at plate scale. From above the street IS the field, so
    # the empty band is the roadway between the barricades.
    "battle_riot": (
        "a narrow city street seen from directly above, the pitched roofs of plain stone houses "
        "along both sides, makeshift barricades of overturned carts, crates and sandbags across "
        "the roadway, cloth banners each painted with a single large red fist emblem lying flat, "
        "thin smoke drifting over the cobblestones, a wide band of empty cobblestone roadway "
        "running down the middle"),
    # democracy: keep the v3 vacancy cue and the renamed venue — "public square" invites the
    # public, and from above a plaza is nothing but open paving for a crowd to fill.
    "battle_democracy": (
        "a vast abandoned monumental plaza seen from directly above in the cold light of early "
        "morning, a circular marble fountain and the roofs of stone colonnades along the edges, "
        "cloth banners each painted with a single large golden balance scale emblem lying flat on "
        "the paving, a toppled bronze statue lying beside the fountain, scattered dead leaves "
        "drifting over the stones, a wide band of flat empty paving running down the middle"),
    # civwar: shield faces stay occupied by materials, never by a device (§8 real-world emblem).
    "battle_civwar": (
        "a vast war plain seen from directly above, scarred with long trenches and earthworks "
        "cutting across the ground, broken siege engines and scattered plain round wooden shields "
        "with iron bosses, tall poles each bearing a single plain crossed-swords banner, churned "
        "brown mud and standing water in the trench lines, a wide band of flat open ground running "
        "down the middle"),
    "battle_worldwar": (
        "a scorched battlefield seen from directly above, cratered black earth and drifting ash, "
        "the collapsed footprints of burning ruins and shattered walls, rubble scattered in dark "
        "fans around each crater, a wide band of flat cratered ground running down the middle"),
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
