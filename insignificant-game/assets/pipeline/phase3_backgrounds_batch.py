# phase3_backgrounds_batch.py — Phase 3 class 4: background plates (cookbook §7), the 17-plate
# scope in inventory.md Backgrounds (three-scene model: style bible §11, corpus 場景呈現 sections).
# City era plates are an img2img lineage like buildings (one seed = one coherent 6-era valley;
# era-gated per the §14 propagation rule); every other plate is txt2img. Landscape subjects
# REQUIRE the style-carrying suffix (§14) or they render photoreal; map subjects swap the view
# tail. Plates carry an EMPTY middle ground: city sprites / unit sprites composite there in
# engine, the plate never draws them. Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_backgrounds_batch.py plates                    # all txt2img plates (city era 1 + 11 others) × seeds
#   phase3_backgrounds_batch.py city_era <n>              # img2img wave: era n from each chain's era n-1
#   phase3_backgrounds_batch.py city_era <n> --redo chain:seed   # re-roll listed city cells
#   phase3_backgrounds_batch.py redo <plate_id> <seed>    # re-roll one txt2img plate with a new seed
import json
import os
import subprocess
import sys

SEEDS = [51, 52, 53]
W, H = 1920, 1088
DENOISE = 0.55
T2I = "workflows/krea2_lora_txt2img.json"
I2I = "workflows/krea2_lora_img2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
STYLE = ", hand-painted game background art, watercolor and ink illustration, soft flat colors, clean line work, wide panoramic side view"
MAPSTYLE = ", hand-painted game map art, watercolor and ink illustration, soft flat colors, clean line work, top-down view"
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-backgrounds")
STATE = "phase3_background_chains.json"

# City era plates (bg_city_era1..6): the SAME valley across all six eras — only the land
# develops (wild -> tilled -> terraced -> plowed -> paved -> manicured); the middle ground
# stays an empty meadow for the composited city strip, and time-of-day is an engine grade so
# every plate is day-lit. No buildings in the plate (they are the sprites class).
CITY = {
    1: "a vast untamed grassland valley, wildflower meadows and scattered ancient trees, a thin winding river, a wide flat empty meadow across the middle ground, distant blue mountain ranges, soft morning sky with drifting clouds",
    2: "a vast grassland valley with small tilled plots and dirt footpaths on the far flanks, a thin winding river crossed by a wooden footbridge, a wide flat empty meadow across the middle ground, distant blue mountain ranges, soft morning sky",
    3: "a vast valley with terraced crop fields and tended orchards on the far flanks, hedgerows and a stone footbridge over the winding river, a wide flat empty meadow across the middle ground, distant blue mountain ranges, soft morning sky",
    4: "a vast valley with broad plowed field strips and wooden fences on the far flanks, a packed earth road with cart ruts and a stone bridge over the river, a wide flat empty meadow across the middle ground, distant blue mountains under a pale hazy sky",
    5: "a vast valley with neat green cropland squares and trimmed hedges on the far flanks, a straight paved road and a steel bridge over the river, a wide flat empty meadow across the middle ground, distant blue mountains, clear bright sky",
    6: "a vast valley with manicured parkland and geometric garden fields on the far flanks, a sleek white bridge over the clean winding river, a wide flat empty meadow across the middle ground, distant blue mountains, luminous clear sky",
}

# Remaining plates (txt2img). Subject rules already §14-standing: battle plates keep a wide
# empty middle ground (both unit lines composite there); every cloth/sign surface is occupied
# by a single named emblem or absent; no profession nouns; era-appropriate props only. The
# route_map / battle_field / battle_riot subjects are the mock-proven wordings, kept verbatim.
PLATES = {
    "route_map": (
        "an aged parchment map of a small river valley region, a walled town at the center, winding roads to nearby villages, a forest, a mountain pass and a river ford, small ink landmarks, empty parchment margins",
        MAPSTYLE),
    "battle_tax": (
        "an open farmland skirmish field, golden wheat plots and hay bales behind a low wooden fence, a wide flat empty dirt field across the middle ground, distant farm hills, clear morning sky",
        STYLE),
    "battle_field": (
        "an open countryside battlefield, rolling grass meadows with sparse trees and distant blue hills, wide empty ground across the middle, clear midday sky",
        STYLE),
    "battle_hidden": (
        "an eerie scorched clearing under a pale green-tinted sky, tall alien monolith stones leaning at odd angles, faint glowing mist hugging the ground, twisted leafless trees at the edges, wide flat empty ground across the middle",
        STYLE),
    "battle_riot": (
        "a city street blocked by makeshift barricades of overturned carts, crates and sandbags, cloth banners each painted with a single large red fist emblem, thin smoke rising, empty cobblestone ground in the foreground",
        STYLE),
    "battle_democracy": (
        "a grand public square with a marble fountain and stone colonnades, cloth banners each painted with a single large golden balance scale emblem, a toppled bronze statue lying by the fountain, wide flat empty paving across the middle ground, overcast sky",
        STYLE),
    "battle_civwar": (
        "a vast open war plain scarred with trenches and earthworks, broken siege engines and scattered round shields, tall poles each bearing a single plain crossed-swords banner, wide flat empty ground across the middle, dramatic storm clouds",
        STYLE),
    "battle_worldwar": (
        "a scorched world battlefield under a dark red sky, burning ruins and shattered walls on the far horizon, cratered black earth and drifting ash, wide flat empty ground across the middle",
        STYLE),
    "title": (
        "a tiny walled settlement with warm lantern lights nestled in an immense river valley, dwarfed by towering mountain ranges under a vast twilight sky with early stars, a large open sky above",
        STYLE),
    "ending_survive": (
        "a golden sunrise flooding a prosperous river valley seen from a high hilltop, terraced fields and warm rooftops below, birds crossing a large open glowing sky",
        STYLE),
    "ending_collapse": (
        "crumbling abandoned stone ruins overgrown with vines under a grey overcast sky, a toppled monument and broken walls, cold mist drifting through, muted faded colors, a large open sky above",
        STYLE),
}


def load_state() -> dict:
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {}


def save_state(state: dict) -> None:
    with open(STATE, "w") as f:
        json.dump(state, f, indent=1, ensure_ascii=False)


def run(stem: str, cmd: list[str]) -> None:
    for attempt in (1, 2):
        print(f"=== {stem}" + (" (retry)" if attempt == 2 else ""), flush=True)
        if subprocess.run(cmd).returncode == 0:
            return
    raise SystemExit(f"{stem} failed twice, aborting the batch")


def gen_plate(plate_id: str, seed: int) -> None:
    core, suffix = PLATES[plate_id]
    stem = f"p3_bg_{plate_id}_s{seed}"
    run(stem, [sys.executable, "comfy_run.py", T2I,
               "--seed", str(seed), "--prompt", core + suffix,
               "--width", str(W), "--height", str(H),
               "--prefix", f"phase3-backgrounds/{stem}", *LORA_ARGS])


def gen_city_cell(state: dict, chain: int, era: int, seed: int) -> None:
    stem = f"p3_bg_city_era{era}_s{seed}"
    cmd = [sys.executable, "comfy_run.py",
           "--seed", str(seed), "--prompt", CITY[era] + STYLE,
           "--prefix", f"phase3-backgrounds/{stem}", *LORA_ARGS]
    if era == 1:
        cmd[2:2] = [T2I]
        cmd += ["--width", str(W), "--height", str(H)]
    else:
        src_stem = state["city"][str(chain)][str(era - 1)]["stem"]
        cmd[2:2] = [I2I]
        cmd += ["--image", f"{OUT}/{src_stem}_00001_.png", "--denoise", str(DENOISE)]
    run(stem, cmd)
    state.setdefault("city", {}).setdefault(str(chain), {})[str(era)] = {
        "stem": stem, "seed": seed, "prompt": CITY[era] + STYLE}
    save_state(state)


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "plates"
    state = load_state()
    if mode == "plates":
        for seed in SEEDS:
            gen_city_cell(state, seed, 1, seed)
        for plate_id in PLATES:
            for seed in SEEDS:
                gen_plate(plate_id, seed)
    elif mode == "city_era":
        era = int(sys.argv[2])
        if "--redo" in sys.argv:
            for spec in sys.argv[sys.argv.index("--redo") + 1:]:
                chain, seed = spec.split(":")
                gen_city_cell(state, int(chain), era, int(seed))
        else:
            for chain in SEEDS:
                if str(era) in state.get("city", {}).get(str(chain), {}):
                    continue
                gen_city_cell(state, chain, era, chain)
    elif mode == "redo":
        gen_plate(sys.argv[2], int(sys.argv[3]))
    else:
        raise SystemExit(f"unknown mode {mode}")
    print("BATCH_DONE", flush=True)


if __name__ == "__main__":
    main()
