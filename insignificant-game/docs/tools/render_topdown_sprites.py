#!/usr/bin/env python3
"""Render the exploration demo's top-down sprites from their recorded prompt + seed.

These sprites are EXPLORATORY RAWS for `docs/explore-topdown-motion-demo.html` only. They are
not pipeline assets and never enter `assets/approved/` — see the README beside them.

    python3 docs/tools/render_topdown_sprites.py                     # only the missing ones
    python3 docs/tools/render_topdown_sprites.py --list              # print the table, render nothing
    python3 docs/tools/render_topdown_sprites.py archers_e2          # re-render one, recorded seed
    python3 docs/tools/render_topdown_sprites.py bomber_e4 --seed 404 --probe   # try a new roll

Recipe is the locked one (`assets/pipeline/workflows/krea2_lora_txt2img.json`): Krea-2-Turbo +
Moebius LoRA @1.0, KSampler euler/simple, 8 steps, cfg 1.0, `ConditioningZeroOut`. Needs the
ComfyUI server on 127.0.0.1:8188 (cookbook §14 records the install layout).

Prompt and seed for every sprite live in `topdown_demo_sprites.json`, so the set is
reproducible: same row, same output. A re-roll is a NEW seed, and whoever accepts it must write
the new seed back into that file, or the record stops matching what is on disk.

--probe writes to docs/tools/topdown-probe/ instead of the sprite directory, which is how a
candidate should be reviewed before it replaces a sprite the human already signed off on.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
import urllib.request
import uuid

API = "http://127.0.0.1:8188"
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
TABLE = os.path.join(HERE, "topdown_demo_sprites.json")
WORKFLOW = os.path.join(GAME, "assets", "pipeline", "workflows", "krea2_lora_txt2img.json")
SPRITES = os.path.join(GAME, "assets", "exploration", "topdown-demo")
PROBE = os.path.join(HERE, "topdown-probe")
COMFY_OUT = os.path.expanduser("~/ComfyUI-Shared/output")


def submit(prompt: str, seed: int, prefix: str) -> str:
    with open(WORKFLOW) as f:
        wf = json.load(f)
    sid = next(k for k, v in wf.items() if v["class_type"] == "KSampler")
    wf[sid]["inputs"]["seed"] = seed
    wf[wf[sid]["inputs"]["positive"][0]]["inputs"]["text"] = prompt
    save = next(k for k, v in wf.items() if v["class_type"] == "SaveImage")
    wf[save]["inputs"]["filename_prefix"] = prefix
    body = json.dumps({"prompt": wf, "client_id": str(uuid.uuid4())}).encode()
    req = urllib.request.Request(f"{API}/prompt", data=body,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        return json.load(r)["prompt_id"]


def wait(prompt_id: str) -> list[str]:
    misses = 0
    while True:
        time.sleep(1.5)
        try:
            with urllib.request.urlopen(f"{API}/history/{prompt_id}") as r:
                hist = json.load(r).get(prompt_id)
        except OSError:          # the server has been seen to restart mid-batch
            misses += 1
            if misses > 40:
                raise SystemExit("lost the ComfyUI server while polling")
            time.sleep(4.0)
            continue
        misses = 0
        if not hist:
            continue
        if hist.get("status", {}).get("status_str") == "error":
            raise SystemExit(f"job failed: {json.dumps(hist['status'])[:1500]}")
        if hist.get("outputs"):
            return [os.path.join(COMFY_OUT, img.get("subfolder") or "", img["filename"])
                    for node in hist["outputs"].values() for img in node.get("images", [])]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("keys", nargs="*", help="sprite keys; default = every key with no file yet")
    ap.add_argument("--seed", type=int, help="override the recorded seed (a fresh re-roll)")
    ap.add_argument("--probe", action="store_true",
                    help="write to docs/tools/topdown-probe/ for review, not over the sprites")
    ap.add_argument("--list", action="store_true", help="print the table and exit")
    args = ap.parse_args()

    with open(TABLE) as f:
        rows = {r["key"]: r for r in json.load(f)}

    if args.list:
        print(f"{'key':20}{'seed':>6}  prompt")
        for k, r in rows.items():
            print(f"{k:20}{r['seed']:>6}  {r['prompt'][:88]}...")
        print(f"\n{len(rows)} sprites, seeds "
              f"{sorted({r['seed'] for r in rows.values()})}")
        return

    if args.keys:
        unknown = [k for k in args.keys if k not in rows]
        if unknown:
            sys.exit(f"unknown keys: {unknown}\nrun --list to see them all")
        todo = [rows[k] for k in args.keys]
    else:
        todo = [r for k, r in rows.items() if not os.path.exists(f"{SPRITES}/{k}.png")]
        if not todo:
            print("every sprite is already on disk; name keys explicitly to re-render")
            return

    dest = PROBE if args.probe else SPRITES
    os.makedirs(dest, exist_ok=True)
    print(f"{len(todo)} to render -> {dest}", flush=True)
    t_all = time.time()
    for i, r in enumerate(todo, 1):
        seed = args.seed if args.seed is not None else r["seed"]
        t0 = time.time()
        files = wait(submit(r["prompt"], seed, f"topdown-demo/exp_td_{r['key']}_s{seed}"))
        name = f"{r['key']}_s{seed}.png" if args.probe else f"{r['key']}.png"
        shutil.copyfile(files[0], f"{dest}/{name}")
        print(f"[{i}/{len(todo)}] {name} {time.time() - t0:.1f}s", flush=True)
    print(f"done in {(time.time() - t_all) / 60:.1f} min", flush=True)
    if args.seed is not None and not args.probe:
        print(f"\nNOTE: rendered at seed {args.seed}, which is NOT what "
              f"topdown_demo_sprites.json records. Write it back there if you are keeping these.")
    print("\nnext: python3 docs/tools/build_motion_demo.py   (re-embeds them in the demo)")


if __name__ == "__main__":
    main()
