# phase3_portraits_batch.py — Phase 3 class 4b: portraits (cookbook §7), the 15-portrait scope in
# inventory.md "Portraits". Portraits are txt2img character busts isolated on plain light gray (style
# bible §3 portrait row, 1024×1024). txt2img seed sweep, NOT an img2img era lineage (one portrait per
# rival class / candidate faction, the stable identity while per-run names rotate). Because they are
# isolated on a plain ground they FREEZE like units/buildings (border-flood key to transparent).
#
# v2 RE-DIRECTION (human feedback 2026-07-23): v1 (seeds 51-56) read as "too blatantly expressed,
# crude" — heavy-handed tropes (wolf-pelt warlord, comedy-mask muse, Soviet general, arms-spread
# populist). v2 re-authors ALL 15 as understated, dignified LEADER portraits (official campaign /
# editorial press-portrait register): everyone reads as a leader with distinct presence and expression,
# personality carried by bearing/wardrobe/gaze rather than literal props. The 5 rival civs take the
# human's exact per-civ demographic + wardrobe + expression spec; the 10 candidates are re-rolled as
# understated campaign portraits with deliberate demographic diversity across gender/ethnicity/age.
# v1 stays in state/manifest for the record (git aa3729a); v2 runs on a fresh seed band so the pick
# sheet shows only v2. NO pilot per the standing "go for full batch" directive.
#
# §14 rules carried over: positive-slot only; no lettering on any surface; watch fake artist signatures
# + invented/real insignia (the v1 §8 finding — named insignia-carriers + historical fine-art subjects
# pull REAL markings at cfg 1, which is exactly what the understated-modern register avoids); parody
# world = NO allusion to a specific real country.
#
# Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_portraits_batch.py one <id> <seed>   # single probe
#   phase3_portraits_batch.py all               # every subject in PORTRAITS × SEEDS (resume-guarded)
#   phase3_portraits_batch.py redo <id> <seed>  # re-roll one portrait with a new (bumped) seed
import json
import os
import subprocess
import sys

SEEDS = [61, 62, 63]                       # v2 re-direction seed band (v1 51-56 retired, see header)
W, H = 1024, 1024                          # style bible §3 portrait size
T2I = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
# style bible §3 framing suffix. The bare "character portrait" tail let the "campaign portrait /
# head of state" wording pull PHOTOREAL (v2 probe s61) — the same photoreal pull backgrounds hit on
# landscapes (§14 2026-07-14), fixed there by a style-carrying tail. Same lever here: name the medium
# (hand-painted watercolor+ink illustration, flat colors, clean line work) so the Moebius look wins
# back the formal-portrait composition. Framing suffix is a tunable working baseline (§3); recipe
# (checkpoint/LoRA/cfg) unchanged.
SUFFIX = ", hand-painted character portrait, watercolor and ink illustration, soft flat colors, clean line work, bust, centered, plain light gray background"
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-portraits")
STATE = "phase3_portrait_state.json"

# id -> subject core (no suffix). v2: understated dignified leaders, not tropes.
PORTRAITS = {
    # --- 5 rival civilizations (design/對手文明.md) — human's exact per-civ demographic direction;
    # each is a modern head-of-state with distinct presence, NOT the retired fantasy archetype ---
    "portrait_civ_science_state": "an East Asian man in his fifties, a distinguished head of state, neatly and tastefully dressed in a crisp charcoal suit and tie, well-groomed short hair, a stern composed serious expression, dignified formal presence, looking directly at the viewer",
    "portrait_civ_culture_state": "a White man in his fifties, a cultured head of state in a sharply tailored midnight-blue suit with tasteful accessories, a silk pocket square and a small lapel pin, silver-streaked hair, a gentle warm gracious expression, refined dignified presence, looking at the viewer",
    "portrait_civ_iron_tribe": "a Southeast Asian man in his forties, a hardened national leader in plain utilitarian civilian attire, a simple dark buttoned field shirt, close-cropped black hair, sharp piercing intense eyes, a stern unsmiling resolute expression, austere presence, looking directly at the viewer",
    "portrait_civ_vast_state": "a White woman in her fifties, a stately head of state, plus-sized and full-figured, wearing loose flowing elegant robes in rich muted tones, styled hair, an aristocratic composed air, a serene confident dignified expression, regal bearing, looking at the viewer",
    "portrait_civ_slow_burner": "a Black man in his fifties, a national leader in a plain slightly ill-fitting brown formal suit with high-waisted trousers, no accessories, understated and modest, an unhurried calm reserved expression, a quiet unremarkable presence, looking at the viewer",

    # --- 10 democracy candidates (design/民主.md) — understated campaign/press portraits, platform
    # carried by subtle bearing not props; deliberate demographic diversity across gender/ethnicity/age ---
    "portrait_candidate_technocrat": "an East Asian woman in her forties, a composed policy candidate in a minimalist dark blazer, thin rimless glasses, neat hair, a cool precise analytical expression, understated professional presence, a formal campaign portrait, looking directly at the viewer",
    "portrait_candidate_culture_revival": "a White man in his fifties with silver hair, a cultured candidate in an elegant soft tailored jacket and a tastefully patterned scarf, a warm refined gracious smile, understated artistic sophistication, a formal campaign portrait, looking at the viewer",
    "portrait_candidate_iron_expansion": "a Latino man in his fifties, close-cropped greying hair, a stern strongman candidate in a severe plain dark suit and tie, a hard set jaw and a cold steady unsmiling stare, austere authoritative presence, a formal campaign portrait, looking directly at the viewer",
    "portrait_candidate_populist": "a Black woman in her forties, a warm approachable candidate in a bright welcoming blazer, a broad genuine friendly smile, kind open eyes, an inviting people-person presence, a formal campaign portrait, looking at the viewer",
    "portrait_candidate_free_market": "a White man in his forties, a polished business candidate in a sharp navy suit and tie, slicked-back hair, a confident easy salesman's smile, a self-assured prosperous presence, a formal campaign portrait, looking at the viewer",
    "portrait_candidate_theocratic": "a South Asian man in his sixties with a neat grey beard, a grave traditional candidate in a modest dark high-collared formal coat, a solemn devout calm expression, a dignified conservative presence, a formal campaign portrait, looking at the viewer",
    "portrait_candidate_military_industrial": "a White woman in her fifties, a shrewd defense-industry candidate in a sharp steel-grey power suit, hair pinned back, a measured calculating half-smile and hard appraising eyes, a formidable executive presence, a formal campaign portrait, looking at the viewer",
    "portrait_candidate_green_pastoral": "a White man in his thirties, an earnest grassroots candidate in a soft natural-fibre earth-toned jacket over an open collar, tousled hair, a gentle sincere warm expression, an approachable down-to-earth presence, a formal campaign portrait, looking at the viewer",
    "portrait_candidate_centrist": "a South Asian man in his forties, a moderate candidate in a plain neat mid-grey suit and tie, tidy hair, a calm balanced measured neutral expression, an unremarkable steady presence, a formal campaign portrait, looking at the viewer",
    "portrait_candidate_revolutionary": "a young mixed-race woman in her late twenties, a fiery reformist candidate in a plain rough worker's jacket over a simple shirt, dark hair pulled back, intense burning conviction in her eyes and a determined set mouth, a charged charismatic presence, a formal campaign portrait, looking directly at the viewer",
}

# v1 §8 re-roll block retired by the v2 re-direction (all subjects re-authored). Kept empty so the
# sheet builder (which imports these) falls back to SEEDS for every subject.
REROLL_SEEDS: list[int] = []
REROLLS: dict[str, str] = {}


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


def gen_portrait(state: dict, portrait_id: str, seed: int, resume: bool = False,
                 core_override: str | None = None) -> None:
    core = core_override if core_override is not None else PORTRAITS[portrait_id]
    stem = f"p3_{portrait_id[len('portrait_'):]}_s{seed}"
    if resume and os.path.exists(f"{OUT}/{stem}_00001_.png"):
        print(f"=== {stem} (exists, skipped)", flush=True)
        return
    prompt = core + SUFFIX
    run(stem, [sys.executable, "comfy_run.py", T2I,
               "--seed", str(seed), "--prompt", prompt,
               "--width", str(W), "--height", str(H),
               "--prefix", f"phase3-portraits/{stem}", *LORA_ARGS])
    state.setdefault(portrait_id, {})[str(seed)] = {"stem": stem, "seed": seed, "prompt": prompt}
    save_state(state)


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    state = load_state()
    if mode in ("one", "redo"):
        gen_portrait(state, sys.argv[2], int(sys.argv[3]))
    elif mode == "all":
        for portrait_id in PORTRAITS:
            for seed in SEEDS:
                gen_portrait(state, portrait_id, seed, resume=True)
    else:
        raise SystemExit(f"unknown mode {mode}")
    print("BATCH_DONE", flush=True)


if __name__ == "__main__":
    main()
