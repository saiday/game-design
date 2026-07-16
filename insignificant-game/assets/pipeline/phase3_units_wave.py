# phase3_units_wave.py — era-gated unit/fort/enemy generation (cookbook §7), same machinery as
# phase3_buildings_wave.py: artifacts propagate down img2img lineage chains (§14 2026-07-12), so
# each era wave is §8-reviewed before it seeds the next. State lives in phase3_unit_chains.json:
# line -> chain (base seed) -> era -> {"stem": ..., "seed": ..., "prompt": ...}; a re-roll
# overwrites its cell with a bumped seed and downstream eras then chain from it.
# Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_units_wave.py <era>                          # fill era cells for all active lines
#   phase3_units_wave.py <era> --redo line:chain:seed   # re-roll listed cells, then regrid
import json
import os
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

from phase3_units_batch import (DENOISE, I2I, LINES, LORA_ARGS, OUT, SEEDS, START_ERA, T2I,
                                suffix_for)

STATE = "phase3_unit_chains.json"
# lines already human-picked and frozen; waves skip them
FROZEN: set[str] = set()


def load_state() -> dict:
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {}


def save_state(state: dict) -> None:
    with open(STATE, "w") as f:
        json.dump(state, f, indent=1, ensure_ascii=False)


def active(era: int) -> list[str]:
    return [line for line, subs in LINES.items() if line not in FROZEN
            and START_ERA.get(line, 1) <= era < START_ERA.get(line, 1) + len(subs)]


def gen_cell(state: dict, line: str, chain: int, era: int, seed: int) -> None:
    start = START_ERA.get(line, 1)
    core = LINES[line][era - start]
    prompt = core + suffix_for(line)
    stem = f"p3_unit_{line}_e{era}_s{seed}"
    cmd = [sys.executable, "comfy_run.py",
           "--seed", str(seed), "--prompt", prompt,
           "--prefix", f"phase3-units/{stem}", *LORA_ARGS]
    if era == start:
        cmd[2:2] = [T2I]
        cmd += ["--width", "1024", "--height", "1024"]
    else:
        src_stem = state[line][str(chain)][str(era - 1)]["stem"]
        cmd[2:2] = [I2I]
        cmd += ["--image", f"{OUT}/{src_stem}_00001_.png", "--denoise", str(DENOISE)]
    for attempt in (1, 2):
        print(f"=== {stem}" + (" (retry)" if attempt == 2 else ""), flush=True)
        if subprocess.run(cmd).returncode == 0:
            break
    else:
        raise SystemExit(f"{stem} failed twice, aborting the wave")
    state.setdefault(line, {}).setdefault(str(chain), {})[str(era)] = {
        "stem": stem, "seed": seed, "prompt": prompt}
    save_state(state)


def grid(state: dict, era: int) -> None:
    lines = active(era)
    cell = 330
    font = ImageFont.load_default(size=15)
    sheet = Image.new("RGB", (cell * len(SEEDS), (cell + 26) * len(lines)), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for r, line in enumerate(lines):
        for c, chain in enumerate(SEEDS):
            stem = state[line][str(chain)][str(era)]["stem"]
            img = Image.open(f"{OUT}/{stem}_00001_.png")
            img.thumbnail((cell - 8, cell - 8), Image.LANCZOS)
            sheet.paste(img, (c * cell + 4, r * (cell + 26) + 4))
        d.text((4, r * (cell + 26) + cell + 4),
               f"{line}  chains {' / '.join(str(s) for s in SEEDS)}", fill=(220, 220, 220), font=font)
    out = f"{OUT}/review_e{era}.png"
    sheet.save(out)
    print(f"review grid: {out}")


def main() -> None:
    era = int(sys.argv[1])
    state = load_state()
    if "--redo" in sys.argv:
        for spec in sys.argv[sys.argv.index("--redo") + 1:]:
            line, chain, seed = spec.split(":")
            gen_cell(state, line, int(chain), era, int(seed))
    else:
        for line in active(era):
            for chain in SEEDS:
                if str(era) in state.get(line, {}).get(str(chain), {}):
                    continue
                gen_cell(state, line, chain, era, chain)
    grid(state, era)


if __name__ == "__main__":
    main()
