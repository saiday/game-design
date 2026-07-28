# phase3_units_topdown_sweep.py — W14.8 driver: one seed sweep per cell over the whole
# battlefield roster, top-down (ADR-0009). Sibling of phase3_units_wave.py, with one deliberate
# difference recorded here because it reverses that script's core discipline:
#
#   THERE ARE NO ERA GATES AND NO img2img LINEAGE. Every cell is a txt2img root.
#
# Cookbook §6.1 says to classify each era transition BEFORE the wave and reach for a txt2img root
# when a transition is a category reversal or a silhouette sharing nothing with the target. Under
# the new camera every cell qualifies twice over: no cell has a top-down parent to inherit from
# (the approved set is side-view and is exactly what ADR-0009 discards), and three lines change
# subject category mid-chain anyway (cavalry and anti_air become vehicles at era 5, engineers at
# era 5 only). The top-down exploration already generated all 52 player cells this way and its set
# held together, because under this recipe era coherence comes from the shared form tail and the
# locked recipe rather than from lineage. The cost is stated plainly: era-to-era continuity within
# a line is now carried by wording alone, so the pick gate must be read down each line's row, not
# just across it.
#
# The practical consequence is that the whole roster renders in ONE unattended batch instead of
# six human-gated waves, and the human gets one complete contact sheet per line.
#
# Usage (ComfyUI venv python, from assets/pipeline/ — cookbook §3: the cd must be in the SAME
# shell command, and detach long batches per §4):
#   phase3_units_topdown_sweep.py                 # every missing cell/seed, resumable
#   phase3_units_topdown_sweep.py --lines bomber,privateers   # only these lines
#   phase3_units_topdown_sweep.py --plan          # print what it WOULD render, render nothing
import argparse
import json
import os
import subprocess
import sys

from phase3_units_topdown_batch import (LINES, LORA_ARGS, OUT, SEEDS, START_ERA, T2I, prompt_for)

STATE = "phase3_unit_topdown_chains.json"


def load_state() -> dict:
    if os.path.exists(STATE):
        with open(STATE) as f:
            return json.load(f)
    return {}


def save_state(state: dict) -> None:
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f, indent=1, ensure_ascii=False)
    os.replace(tmp, STATE)  # §4: chain state is clobber-prone; never leave a half-written file


def cells(only: set[str] | None) -> list[tuple[str, int]]:
    out = []
    for line, subs in LINES.items():
        if only and line not in only:
            continue
        start = START_ERA.get(line, 1)
        out.extend((line, start + i) for i in range(len(subs)))
    return out


def stem(line: str, era: int, seed: int) -> str:
    return f"p3_td_{line}_e{era}_s{seed}"


def rendered(s: str) -> bool:
    """Resume guard (§4): a relaunch must be free. ComfyUI suffixes _00001_ on the first write."""
    return os.path.exists(f"{OUT}/{s}_00001_.png")


def gen(state: dict, line: str, era: int, seed: int) -> None:
    s = stem(line, era, seed)
    prompt = prompt_for(line, era)
    cmd = [sys.executable, "comfy_run.py", T2I, "--seed", str(seed), "--prompt", prompt,
           "--prefix", f"phase3-units-topdown/{s}", "--width", "1024", "--height", "1024",
           *LORA_ARGS]
    for attempt in (1, 2):
        print(f"=== {s}" + (" (retry)" if attempt == 2 else ""), flush=True)
        if subprocess.run(cmd).returncode == 0:
            break
    else:
        raise SystemExit(f"{s} failed twice, aborting the sweep")
    state.setdefault(line, {}).setdefault(str(era), {})[str(seed)] = {
        "stem": s, "seed": seed, "prompt": prompt, "root": True,
    }
    save_state(state)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lines", help="comma-separated subset")
    ap.add_argument("--cells", help="comma-separated line:era list, for a re-roll round")
    ap.add_argument("--seeds", help="comma-separated seed override; a re-roll bumps by +100 (§4)")
    ap.add_argument("--plan", action="store_true")
    args = ap.parse_args()
    only = {x.strip() for x in args.lines.split(",")} if args.lines else None
    seeds = [int(x) for x in args.seeds.split(",")] if args.seeds else SEEDS

    os.makedirs(OUT, exist_ok=True)
    state = load_state()
    if args.cells:
        picked = [(c.split(":")[0], int(c.split(":")[1])) for c in args.cells.split(",")]
    else:
        picked = cells(only)
    todo = [(l, e, s) for l, e in picked for s in seeds if not rendered(stem(l, e, s))]
    print(f"{len(picked)} cells x {len(seeds)} seeds; {len(todo)} to render "
          f"(~{len(todo) * 170 / 3600:.1f} h at 170 s/image)", flush=True)
    if args.plan:
        for l, e, s in todo:
            print(f"  {stem(l, e, s)}")
        return
    for i, (l, e, s) in enumerate(todo, 1):
        print(f"--- [{i}/{len(todo)}] {l} era {e} seed {s}", flush=True)
        gen(state, l, e, s)
    print(f"SWEEP DONE: {len(todo)} rendered into {OUT}", flush=True)


if __name__ == "__main__":
    main()
