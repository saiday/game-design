# phase3_projectiles_topdown_batch.py — W14.8: the 8 flying-weapon sprites (`proj_<ammo>`).
#
# This class did not exist before. It is a genuine hole the camera opened: side-view battle art
# never needed it, so inventory.md's v1 scope has no projectile row and core/data/asset_paths.gd
# has no registry entry. Seen from above, an attack IS a thing crossing the gap between two
# stations, and the timeline replayer has a `hit` / `miss` event per attack with nothing to draw.
# The top-down exploration rendered 8 of these for exactly that reason
# (docs/tools/topdown_demo_sprites.json) but they were demo-only raws; these are the pipeline run.
#
# They have NO ERA of their own. One sprite per ammo type, shared by every era that fires it, per
# the mapping in assets/exploration/topdown-demo/README.md and inventory.md:
#   stone      archers e1, artillery e3      arrow    archers e2
#   bolt       archers e3                    bullet   archers e4/e5, infantry e4-e6, enemy tiers
#   cannonball artillery e4                  shell    artillery e5/e6
#   missile    archers e6, anti_air e5       bomb     bomber e4-e6
#
# Framing: the projectile points RIGHT like every player sprite and is mirrored for the enemy side
# (mirror-safety is signed off for this recipe, review-brief-units-topdown.md). Two exceptions are
# deliberate and must not be "fixed": a cannonball and a stone are spheres with no heading, so they
# carry no orientation clause, and a bomb is seen falling nose-down rather than travelling flat.
#
# Sprites are small on screen, so the §8 pass that matters is the battle-zoom one: at field size a
# projectile is a few dozen pixels and reads by silhouette and colour alone.
#
# Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_projectiles_topdown_batch.py            # every missing cell/seed, resumable
#   phase3_projectiles_topdown_batch.py --plan
import argparse
import json
import os
import subprocess
import sys

SEEDS = [91, 92, 93, 94]
W = H = 1024
T2I = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-projectiles-topdown")
STATE = "phase3_projectile_topdown_state.json"

_FORM = "a simplified chunky shape with minimal surface detail"
_OVER = "game projectile sprite, seen from directly above"
_ISO = "centered, isolated on a plain light gray background"
_RIGHT = "pointing toward the right edge of the frame"

# id -> subject core. Suffix is folded in per entry because the two spheres and the bomb differ.
PROJECTILES = {
    "proj_stone":      f"a single small round throwing stone, a plain grey rock, {_FORM}, {_OVER}, {_ISO}",
    "proj_arrow":      f"a single arrow with a sharp iron head and three feather fletchings, {_FORM}, {_OVER}, {_RIGHT}, {_ISO}",
    "proj_bolt":       f"a single short crossbow bolt with an iron head and stubby vanes, {_FORM}, {_OVER}, {_RIGHT}, {_ISO}",
    # Round 1 drew the whole cartridge, brass case included, for both bullet and shell — and a case
    # never leaves the gun. It also made the two near-identical at field size despite belonging to
    # different unit lines. Round 2 draws only the part that actually flies and separates them by
    # hue: bullet warm brass/yellow, shell red. (Which colour goes to which was my call: red reads
    # as the heavier ordnance, and live artillery rounds are commonly banded red.)
    "proj_bullet":     f"a single pointed rifle bullet in flight, a smooth warm brass-yellow "
                       f"jacketed ogive narrowing to a sharp tip at the front and squared off "
                       f"into a plain flat base at the rear, {_FORM}, {_OVER}, {_RIGHT}, {_ISO}",
    "proj_cannonball": f"a single solid black iron cannonball, a plain sphere, {_FORM}, {_OVER}, {_ISO}",
    "proj_shell":      f"a single artillery shell in flight, a long dark red steel projectile "
                       f"body with a pointed nose fuze at the front, a bright red painted band "
                       f"around its waist and a plain flat driving band at the rear, {_FORM}, "
                       f"{_OVER}, {_RIGHT}, {_ISO}",
    "proj_missile":    f"a single small guided missile with a pointed nose and four tail fins, {_FORM}, {_OVER}, {_RIGHT}, {_ISO}",
    # a falling bomb is the one subject whose heading is DOWN the screen, not across it
    "proj_bomb":       f"a single aerial bomb with a rounded nose and four tail fins, {_FORM}, "
                       f"game projectile sprite, seen from a steep high angle from above, its nose "
                       f"pointing down toward the bottom of the frame, {_ISO}",
}


def load_state() -> dict:
    return json.load(open(STATE)) if os.path.exists(STATE) else {}


def save_state(s: dict) -> None:
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(s, f, indent=1, ensure_ascii=False)
    os.replace(tmp, STATE)


def stem(pid: str, seed: int) -> str:
    return f"p3_td_{pid}_s{seed}"


def rendered(s: str) -> bool:
    return os.path.exists(f"{OUT}/{s}_00001_.png")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--plan", action="store_true")
    ap.add_argument("--ids", help="comma-separated subset, e.g. proj_shell,proj_bullet")
    ap.add_argument("--seeds", help="comma-separated seed override for a re-roll round")
    args = ap.parse_args()
    ids = args.ids.split(",") if args.ids else list(PROJECTILES)
    seeds = [int(s) for s in args.seeds.split(",")] if args.seeds else SEEDS

    os.makedirs(OUT, exist_ok=True)
    state = load_state()
    todo = [(p, s) for p in ids for s in seeds if not rendered(stem(p, s))]
    print(f"{len(ids)} projectiles x {len(seeds)} seeds; {len(todo)} to render "
          f"(~{len(todo) * 170 / 3600:.1f} h)", flush=True)
    if args.plan:
        for p, s in todo:
            print(f"  {stem(p, s)}\n     {PROJECTILES[p]}")
        return
    for i, (p, s) in enumerate(todo, 1):
        st = stem(p, s)
        cmd = [sys.executable, "comfy_run.py", T2I, "--seed", str(s), "--prompt", PROJECTILES[p],
               "--prefix", f"phase3-projectiles-topdown/{st}",
               "--width", str(W), "--height", str(H), *LORA_ARGS]
        for attempt in (1, 2):
            print(f"--- [{i}/{len(todo)}] {st}" + (" (retry)" if attempt == 2 else ""), flush=True)
            if subprocess.run(cmd).returncode == 0:
                break
        else:
            raise SystemExit(f"{st} failed twice, aborting")
        state.setdefault(p, {})[str(s)] = {"stem": st, "seed": s, "prompt": PROJECTILES[p]}
        save_state(state)
    print(f"PROJECTILE SWEEP DONE: {len(todo)} rendered into {OUT}", flush=True)


if __name__ == "__main__":
    main()
