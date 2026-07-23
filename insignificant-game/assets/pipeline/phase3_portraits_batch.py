# phase3_portraits_batch.py — Phase 3 class 4b: portraits (cookbook §7), the 15-portrait scope in
# inventory.md "Portraits". Portraits are txt2img character busts isolated on plain light gray (style
# bible §3 portrait row: `character portrait, bust, centered, plain light gray background`, 1024×1024)
# — so this is a txt2img seed sweep like the cards/backgrounds classes, NOT an img2img era lineage
# (portraits do not evolve per era: one portrait per rival class / per candidate faction, the stable
# identity while per-run display names rotate — inventory.md naming note). Because they are isolated
# on a plain ground they FREEZE like units/buildings (border-flood key to transparent), not like the
# full-frame cards — the freeze script handles that; this file only generates candidates.
#
# NO PILOT (human directive 2026-07-23: "go for full batch"): the style bible recipe is locked and the
# figure recipe is already proven on units + cards, so the direction gate the cards class ran is
# skipped — straight to the full 15-subject sweep, then §8 review + contact sheets + pick gate.
#
# SUBJECTS are authored from the design docs, not invented: the 5 rival classes from design/對手文明.md
# (性格 column + 命名邏輯) and the 10 democracy factions from design/民主.md (行動文案 column). Ids match
# core/data/rivals.gd CLASSES and core/data/candidates.gd CANDIDATES exactly. Each portrait embodies the
# CLASS/faction personality at a glance (design rule: 直白諷刺、一眼看得出性格), never a named leader.
#
# §14 rules carried over from the units/cards classes:
#   - positive-slot only: name the desired object, never a banned one (prohibitions backfire at cfg 1).
#   - no lettering on any surface (banners/badges/medals occupy the surface with a plain colour or an
#     image emblem, never text).
#   - watch fake artist signatures (the card/portrait §5 artifact class) and invented logo badges.
#   - parody world rule (design/對手文明.md 命名邏輯): satirical archetype, NO allusion to a specific real
#     country — insignia are invented/generic (radiant sun, coiled dragon, wolf pelt) or "plain unmarked".
#   - mutual distinguishability (§8): each bust gets a distinct silhouette / costume / prop / expression.
#
# Usage (ComfyUI venv python, from assets/pipeline/):
#   phase3_portraits_batch.py one <id> <seed>   # single probe
#   phase3_portraits_batch.py all               # every subject in PORTRAITS × SEEDS (resume-guarded)
#   phase3_portraits_batch.py redo <id> <seed>  # re-roll one portrait with a new (bumped) seed
import json
import os
import subprocess
import sys

SEEDS = [51, 52, 53]                       # fresh txt2img seed band for this class
W, H = 1024, 1024                          # style bible §3 portrait size
T2I = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
# style bible §3 locked framing suffix for the portrait class. "game unit sprite" / "game card
# illustration" both carried the Moebius look on figure subjects, so the isolated-bust suffix is
# expected to as well; the first cells confirm it (if any render photoreal, extend the tail and log
# in cookbook §14 — the framing suffix is a working baseline, the recipe itself is locked).
SUFFIX = ", character portrait, bust, centered, plain light gray background"
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-portraits")
STATE = "phase3_portrait_state.json"

# id -> subject core (no suffix).
PORTRAITS = {
    # --- 5 rival civilizations (design/對手文明.md): the stable class identity, drawn as an archetypal
    # figurehead embodying the 性格, styled from the 命名邏輯 (no real-country allusion) ---
    # 科學邦 (科技): 格物致知 / 曆法與觀測 — the scholar-inventor.
    "portrait_civ_science_state": "an elderly scholar-inventor in a high-collared indigo robe, round wire-rimmed spectacles pushed up his nose, a neatly trimmed white beard, holding up a small brass mechanical orrery of interlocking gears and tiny orbiting spheres, a rolled schematic tucked under one arm, a keen precise thoughtful gaze",
    # 文化國 (文化/心戰): 繆思女神 / 風雅 / 百戲 — the elegant muse-patron of the arts.
    "portrait_civ_culture_state": "an elegant muse-like patron of the arts in flowing pastel silk robes and a golden laurel wreath crowning loose curls, holding a delicate theatrical comedy mask in one hand and a small curved lyre in the other, an ornate embroidered sash across the chest, a serene refined half-smile",
    # 鐵血部 (軍事): 狼旗汗國 / 鍛造與鐵器 — the steppe warlord.
    "portrait_civ_iron_tribe": "a fierce steppe warlord in fur-trimmed lamellar iron armour and a wolf-pelt helmet with the wolf's head over the brow, a scarred weathered face and a thick black moustache, a heavy fur cloak clasped at one shoulder, a gauntleted fist gripping the hilt of a curved sabre, a hard defiant glare",
    # 廣土邦 (人口): 大河流域 / 人口即力量 / 幅員遼闊 — the vast benevolent emperor of teeming river lands.
    "portrait_civ_vast_state": "a broad heavyset emperor in many layers of richly embroidered river-blue and gold robes, a wide calm benevolent moon face with a long thin drooping moustache, a tall jewelled headdress, both hands folded serenely over a rounded belly, an air of vast unhurried abundance",
    # 慢熱國 (晚期爆發): 臥龍待時 / 蟄伏過冬 / 睡醒就爆發 — the drowsy sage hiding banked power.
    "portrait_civ_slow_burner": "a drowsy long-bearded sage in plain earth-toned robes, heavy-lidded half-closed eyes mid-yawn, shoulders slouched and relaxed, a faint coiled dragon embroidered on one shoulder, a sleepy unbothered expression that hides banked power",

    # --- 10 democracy candidate factions (design/民主.md 行動文案): political-archetype busts, each
    # readable as its platform at a glance (推論可學習: the face tells you the policy) ---
    # 科技官僚派: 擴編實驗室、補貼工程師、削減慶典.
    "portrait_candidate_technocrat": "a stern bureaucrat-engineer in a white lab coat over a buttoned grey shirt, thick square black spectacles, a row of coloured pens in the chest pocket, holding a clipboard flat against his chest, a humourless efficient expression",
    # 文化復興派: 修復古蹟、資助劇團、外派文化使節.
    "portrait_candidate_culture_revival": "a flamboyant arts patron in a plum velvet jacket and a loosely tied silk cravat, a soft beret tilted over flowing hair, one hand raised in a theatrical flourish holding a slim paintbrush, an expressive romantic look",
    # 鐵血擴張派: 擴充部隊、尋求衝突、媒體噤聲.
    "portrait_candidate_iron_expansion": "a hard-jawed militarist leader in a dark decorated dress uniform with a stiff high collar and rows of plain unmarked medals, a peaked officer's cap, a clenched aggressive glare",
    # 民粹安撫派: 發放補貼、舉辦慶典、凍結徵稅.
    "portrait_candidate_populist": "a beaming crowd-pleasing populist with rolled-up shirtsleeves and an open collar, arms spread wide in a welcoming gesture, a huge warm grin, a bright festive rosette pinned to the chest",
    # 商業自由派: 開放市場、簽貿易協定、鬆綁管制.
    "portrait_candidate_free_market": "a slick businessman in a sharp pinstriped suit with slicked-back hair, a confident salesman's smile, one hand extended forward for a handshake, a single gold coin balanced on the other open palm",
    # 神權守舊派: 重建大教堂、恢復祈禱日、審查出版 (invented non-denominational vestment).
    "portrait_candidate_theocratic": "a solemn high priest in ornate gold-trimmed ceremonial robes and a tall ceremonial headdress, hands clasped in devotion at the chest, a plain radiant-sun emblem embroidered on the vestment, a stern pious severity",
    # 軍工複合派: 增購軍備、擴大軍演、補貼兵工廠 (half-industrialist, half-general).
    "portrait_candidate_military_industrial": "a shrewd arms-industry magnate in a business suit with military epaulettes on the shoulders, holding up a small grey scale model of a rocket, an industrial hard hat tucked under one arm, a calculating grin",
    # 田園環保派: 限制開發、擴建公園、裁減軍費.
    "portrait_candidate_green_pastoral": "a gentle eco-idealist in homespun earth-toned linen clothes and a wide straw hat, cradling a small potted green sapling in both hands, a few leaves tucked at the collar, a calm wholesome smile",
    # 中庸技術官僚: 均衡預算、逐項檢討、小步改革 (deliberately unremarkable middle).
    "portrait_candidate_centrist": "a moderate mild-mannered official in a plain neutral-grey suit and a neatly combed side part, a balanced measured expression, holding a small set of balance scales perfectly level in one hand, utterly composed and unremarkable",
    # 革命激進派: 清洗舊勢力、動員群眾、沒收資產.
    "portrait_candidate_revolutionary": "a fiery revolutionary agitator in a rough worker's jacket and a flat cap, a bandana knotted at the neck, one clenched fist thrust upward, wild intense eyes and an open shouting mouth, a plain red banner hanging behind",
}


# --- §8 re-roll round (2026-07-23) --------------------------------------------------------------
# Three subjects §8-rejected on the first sweep, all one root cause: named insignia-carriers and
# historical fine-art subject matter pull REAL insignia / real-art-style + fake signatures at cfg 1
# (no negative lever). Fix = move to a plain modern register and drop the trigger nouns (medals,
# military epaulettes, velvet-painter), the register that rendered technocrat/free_market/centrist
# clean. Re-cut cores below; re-rolled on a fresh seed band so originals stay in state for the record.
REROLL_SEEDS = [54, 55, 56]
REROLLS = {
    # was photoreal oil-portrait + fake artist signatures (velvet/beret/cravat = "old master")
    # -> modern arts-advocate politician, cartoon register, no painting-of-a-painter framing.
    "portrait_candidate_culture_revival": "an arts-advocate politician in a colourful modern blazer over a bright patterned open-collar shirt, a silk pocket square, one hand raised in an expressive theatrical flourish holding a slim paintbrush, wavy hair, a warm cultured enthusiastic smile",
    # "rows of medals" grew real Soviet insignia (hammer-and-sickle, red stars) -> strip every
    # insignia-carrier: folded arms occupy the chest, only plain shoulder boards + a plain sash remain.
    "portrait_candidate_iron_expansion": "a hard-jawed militarist politician in a plain dark high-collared uniform jacket with plain gold shoulder boards and a single plain diagonal sash, a peaked cap with a small plain round badge, both arms folded across the chest, a hard aggressive glare",
    # "military epaulettes" pulled Soviet general collar-tabs -> drop the uniform entirely; the rocket
    # + hard hat already carry the arms-industry archetype in a plain business suit.
    "portrait_candidate_military_industrial": "a shrewd arms-industry magnate in a plain dark business suit and tie, holding up a small grey scale model of a rocket in one hand, a yellow industrial hard hat tucked under the other arm, slicked hair, a calculating grin",
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
    elif mode == "rerolls":
        for portrait_id, core in REROLLS.items():
            for seed in REROLL_SEEDS:
                gen_portrait(state, portrait_id, seed, resume=True, core_override=core)
    else:
        raise SystemExit(f"unknown mode {mode}")
    print("BATCH_DONE", flush=True)


if __name__ == "__main__":
    main()
