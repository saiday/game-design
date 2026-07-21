# phase3_cards_batch.py — Phase 3 class 3: card illustrations (cookbook §7), the 57-card scope
# in inventory.md "Card illustrations". Cards are txt2img DRAMATIC SCENE compositions (the Phase 1
# anchor style-refs/sb_r4_card_s42.png is a dense spear-phalanx battle scene, not an isolated
# sprite) — so this is a txt2img seed sweep like the backgrounds plates, NOT the units/buildings
# img2img era lineage. The frozen card frame composites OVER the illustration in Godot (style
# bible §9 content window); the illustration is a full rectangular scene, no keying (like
# backgrounds). Subject cores for the 52 unit/fort card forms are LIFTED from the already-approved
# unit manifest prompts (same subject, same era-appropriate objects the units class already made
# §8-clean) and reframed from "three identical figures isolated on gray" to a dramatic hero-forward
# scene; the 5 era-neutral skill cards are fresh conceptual subjects.
#
# PILOT-FIRST (cookbook discipline; Prompt 3 "cards go to review in smaller batches"): this file
# ships the pilot slice populated — one full evolving line (infantry era1-6, directly comparable to
# the anchor) + two skill cards (a conceptual/humorous test). The remaining 49 subjects get authored
# after the human's composition/direction pick on the pilot contact sheet, then the full sweep runs
# via mode `all`.
#
# Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_cards_batch.py one <id> <seed>     # single probe (style-carry check)
#   phase3_cards_batch.py pilot               # the pilot slice (PILOT ids) × SEEDS, resume-guarded
#   phase3_cards_batch.py all                 # every subject in CARDS × SEEDS (post-pilot full sweep)
#   phase3_cards_batch.py redo <id> <seed>    # re-roll one card with a new (bumped) seed
import json
import os
import subprocess
import sys

SEEDS = [41, 42, 43]                       # anchored on the proven Phase 1 card seed (s42)
W, H = 768, 1024                           # style bible §3 card size (portrait content window)
T2I = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
# style bible §3 locked framing suffix for the card class. Backgrounds proved a bare landscape
# needs an explicit style-carrying tail (§14 2026-07-14); the `one` probe below verifies whether
# "game card illustration" already carries the Moebius look on figure subjects (units' "game unit
# sprite" suffix did). If the probe renders photoreal, extend this tail and log in cookbook §14 —
# the framing suffix is a working baseline, the recipe itself is locked.
SUFFIX = ", game card illustration, dramatic composition"
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-cards")
STATE = "phase3_card_state.json"

# id -> subject core (no suffix). Unit/fort forms reframed from the approved unit prompts:
# identity + era-appropriate objects preserved, isolation framing dropped, a lead figure forward
# with ranks behind in a battlefield setting for the "dramatic composition" the anchor establishes.
# §14 rules carried over from the units/backgrounds classes: no lettering on banners (occupy cloth
# with a plain colour or an emblem, never text); watch fake artist signatures (the card-specific
# §5 artifact class — the anchor itself has one bottom-right); positive slots only (never name a
# banned object).
CARDS = {
    # --- pilot: infantry (步兵團) era 1-6, cores from approved unit_infantry_* (era4 is the sprite
    # gap, written fresh as 線列步兵 musket line) ---
    "card_infantry_era1": "a tribal warrior in fur and hide charging forward swinging a heavy wooden club, red war-paint stripes on his arms, more club-warriors surging in a loose pack behind him, a windswept open steppe under a dramatic sky",
    "card_infantry_era2": "a spearman in a bronze helmet with a red horsehair crest leading a tight phalanx, round shields locked and long spears levelled forward, a plain crimson war banner raised behind them, a dramatic battlefield sky",
    "card_infantry_era3": "a foot soldier in chainmail and an open helmet raising his sword mid-stride, a pressing wall of shielded swordsmen behind him, dust and a dramatic overcast sky over a medieval battlefield",
    "card_infantry_era4": "a line-infantry soldier in a tall shako and a long buttoned coat levelling his musket with a fixed bayonet, a firing line of identically uniformed musketeers behind him, drifting powder smoke under a dramatic sky",
    "card_infantry_era5": "a soldier in an olive-drab uniform and a steel helmet advancing with his rifle raised, more helmeted riflemen pushing forward behind him, a war-torn field under a dramatic smoky sky",
    "card_infantry_era6": "a soldier in a bulky powered-armour suit with glowing infrared visor slits and oversized metal gauntlets striding forward, more armoured troopers advancing behind him, a futuristic battlefield under a dramatic sky",
    # --- pilot: skill cards (technicolour conceptual subjects, no unit parent, era-neutral) ---
    # 軍歌: two-turn +1 attack morale buff -> a martial anthem / morale surge.
    "card_war_song": "ranks of soldiers marching shoulder to shoulder singing with mouths open and fists raised, one of them blowing a great brass war horn, plain crimson banners without any lettering held high, a triumphant dramatic sky",
    # 這些破洞不影響功能: the joke card (out-turn card-cost -1) -> battered gear that "still works".
    "card_holes_dont_matter": "a grinning ragged soldier proudly holding up a battle-tattered shield riddled with holes, his patched dented armour full of gaps, a confident carefree shrug, a dramatic battlefield sky behind him",
}

# The pilot slice actually run this session (mode `pilot`). The rest of CARDS is populated after
# the direction gate.
PILOT = [
    "card_infantry_era1", "card_infantry_era2", "card_infantry_era3",
    "card_infantry_era4", "card_infantry_era5", "card_infantry_era6",
    "card_war_song", "card_holes_dont_matter",
]


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


def gen_card(state: dict, card_id: str, seed: int, resume: bool = False) -> None:
    core = CARDS[card_id]
    stem = f"p3_card_{card_id[len('card_'):]}_s{seed}"
    if resume and os.path.exists(f"{OUT}/{stem}_00001_.png"):
        print(f"=== {stem} (exists, skipped)", flush=True)
        return
    prompt = core + SUFFIX
    run(stem, [sys.executable, "comfy_run.py", T2I,
               "--seed", str(seed), "--prompt", prompt,
               "--width", str(W), "--height", str(H),
               "--prefix", f"phase3-cards/{stem}", *LORA_ARGS])
    state.setdefault(card_id, {})[str(seed)] = {"stem": stem, "seed": seed, "prompt": prompt}
    save_state(state)


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "pilot"
    state = load_state()
    if mode == "one":
        gen_card(state, sys.argv[2], int(sys.argv[3]))
    elif mode == "redo":
        gen_card(state, sys.argv[2], int(sys.argv[3]))
    elif mode in ("pilot", "all"):
        ids = PILOT if mode == "pilot" else list(CARDS)
        for card_id in ids:
            for seed in SEEDS:
                gen_card(state, card_id, seed, resume=True)
    else:
        raise SystemExit(f"unknown mode {mode}")
    print("BATCH_DONE", flush=True)


if __name__ == "__main__":
    main()
