# phase3_buildings_batch.py — Phase 3 class 2: building sprites (cookbook §7), era lineage via
# img2img (cookbook §6): era 1 is txt2img under style bible §2-§3; each later era is img2img
# from the SAME chain's previous era at DENOISE, so one seed = one coherent 6-era chain and the
# human picks a whole lineage. Subjects follow 營運 建築線總表 era forms (inventory.md ids).
# Usage: phase3_buildings_batch.py <line> (e.g. food); run with the ComfyUI venv python from
# assets/pipeline/.
import os
import subprocess
import sys

SEEDS = [71, 72, 73, 74]
DENOISE = 0.55
T2I = "workflows/krea2_lora_txt2img.json"
I2I = "workflows/krea2_lora_img2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
SUFFIX = ", game building sprite, side view, centered, isolated on a plain light gray background"
OUT = os.path.expanduser("~/ComfyUI-Shared/output/phase3-buildings")

# line -> [subject cores, one per era from the line's start era] (era forms: 營運 建築線總表 /
# inventory.md). Subject rules from the pilot + icon sweep (§14): every flat surface is occupied
# or absent (no blank signs), flag-prone subjects get an explicit plain pennant, religion carries
# the golden-tree motif, and each subject keeps an inherently colored element.
LINES = {
    "food": [
        "a small tribal homestead settlement, thatched huts among planted crop fields",       # 屯墾區
        "a classical farmstead, stone farmhouse with fenced crop fields and grain sacks",     # 農莊
        "a manor farm, large manor farmhouse over plowed field strips",                       # 莊園農地
        "an industrial farm, red barn with a tall grain silo and wheat fields",               # 農場
        "a mechanized farm, huge steel grain silos, a tractor and machine sheds",             # 機械化農場
        "a vertical farm tower, stacked glass greenhouse floors glowing with plants",         # 垂直農場
    ],
    "housing": [
        "a small thatched mud hut dwelling with a cooking fire",                              # 茅屋
        "a modest timber and stone cottage dwelling with a small vegetable yard",             # 民居
        "a row of connected stone townhouses along a narrow lane",                            # 街坊
        "a brick apartment building with many chimneys and hanging laundry lines",            # 公寓
        "a large concrete public housing block with rows of balconies",                       # 國宅
        "a smart residential tower with curved glass balconies and rooftop garden lights",    # 智慧住宅
    ],
    "medical": [
        "an open herbalist shed with drying herb bundles and clay pots",                      # 藥草棚
        "a small clinic house with a large mortar and pestle by the door",                    # 醫館
        "a monastery infirmary with an arched ward hall and a small bell tower",              # 修道院醫院
        "a public hospital building with a columned entrance and tall windows",               # 公立醫院
        "a modern medical center with a glass atrium and an ambulance bay",                   # 醫療中心
        "a futuristic gene clinic with a DNA double-helix sculpture and glowing lab pods",    # 基因診所
    ],
    "school": [
        "an open-air learning hut hung with knotted rope cords",                              # 結繩學堂
        "a classical academy with a colonnaded courtyard and olive trees",                    # 學院
        "a monastery scriptorium with arched windows and stacked manuscripts",                # 修道院抄本
        "a university hall with a bell tower and grand stone steps",                          # 大學
        "a research center with modernist concrete wings and a radar dish on the roof",       # 研究中心
        "a national laboratory with a domed accelerator hall and glowing blue conduits",      # 國家實驗室
    ],
    "astronomy": [
        "a stone stargazing platform with standing stones and a fire bowl",                   # 觀星台
        "a classical observatory tower with a bronze armillary sphere on top",                # 天文台
        "a calendar institute hall with a large carved sun-and-moon stone dial",              # 曆法院
        "an observatory with a copper dome and a long brass telescope through the roof slit", # 觀測站
        "a space program launch facility with a red and white rocket on a gantry pad",        # 太空計畫
        "a deep space exploration array of giant radio dish antennas",                        # 深空探測
    ],
    "barracks": [
        "a dirt training ground with wooden practice dummies and a weapon rack",              # 校場
        "a military camp of ordered tents behind a wooden palisade",                          # 軍營
        "a knight order keep, a stone hall with plain red banners and a stable",              # 騎士團部
        "a conscription office building with a drill yard and stacked supply barrels",        # 徵兵所
        "a military base with bunkers, a watchtower and camouflage nets",                     # 軍事基地
        "a drone squadron hangar with quadcopter drones parked on a launch deck",             # 無人機聯隊
    ],
    "arsenal": [
        "a blacksmith forge shed with an anvil and glowing orange coals",                     # 打鐵舖
        "a weapons workshop with spears and round shields racked outside",                    # 兵器坊
        "a foundry with a stone furnace pouring glowing molten metal",                        # 鑄造所
        "an arms factory with smokestacks and cannon barrels stacked in the yard",            # 兵工廠
        "a military industrial complex with assembly hangars and tank hulls on a line",       # 軍工複合體
        "a defense technology park of sleek angular buildings with a railgun prototype",      # 國防科技園
    ],
    "arts": [
        "a bonfire plaza ringed with carved totem poles and drums",                           # 篝火廣場
        "a classical temple theater with a semicircular stone stage",                         # 神廟劇院
        "a grand cathedral with a circular rose window, its spires topped with golden tree emblems",  # 大教堂
        "an opera house with a gilded arched facade and red velvet banners",                  # 歌劇院
        "an arts center with sweeping curved white walls and a colorful abstract sculpture",  # 藝術中心
        "a media center tower with glowing color-gradient light panels",                      # 媒體中心
    ],
    "media": [
        "a storyteller's raised wooden platform with a cloth canopy and log benches",         # 說書人
        "a poetry society pavilion by a pond with hanging paper lanterns",                    # 詩社
        "a printing workshop with a wooden printing press and blank drying paper sheets",     # 印刷坊
        "a press house with giant paper rolls and a loading dock",                            # 報社
        "a broadcast station with a tall red and white radio mast and satellite dishes",      # 廣播電視
        "a social network campus with a giant glowing speech-bubble sculpture at the entrance",  # 社群平台
    ],
    "commerce": [
        "an open market of wooden stalls with fruit baskets and striped cloth awnings",       # 市集
        "a trading house with amphorae, crates and a balance scale at the door",              # 商行
        "a merchant guild hall with a carved golden coin emblem above the door",              # 商會
        "a commercial arcade building with glass canopies and striped awnings",               # 商業中心
        "a grand department store with tiered floors and golden display windows",             # 百貨集團
        "an e-commerce logistics hub with conveyor ramps and delivery drones carrying parcels",  # 電商平台
    ],
    "bank": [
        "a money changer stall with strings of coins and a locked wooden chest",              # 錢莊
        "a stone vault house with a heavy barred iron door",                                  # 金庫
        "a private bank townhouse with barred windows and a golden coin emblem above the door",  # 私有銀行
        "a central bank with a grand columned facade and heavy bronze doors",                 # 中央銀行
        "an investment bank tower of dark glass with a golden bull statue at the entrance",   # 投資銀行
        "a stock exchange hall with glowing rising-chart light strips across its facade",     # 證券市場
    ],
    "debt_office": [
        "a treasury debt office, a stern stone hall with ledger books and chained strongboxes",  # 國債司 (era 3)
        "a national debt bureau with a columned facade and a large bronze ledger emblem",     # 國債局
        "a treasury bond department building with filing wings and a coin-stack monument",    # 財政部公債署
        "a sovereign wealth fund tower with a golden globe sculpture at its base",            # 主權基金
    ],
    "core": [
        "a tribal center longhouse with a great carved totem and a gathering fire",           # 部落中心
        "a town center hall with a bell tower and a market square well",                      # 城鎮中心
        "a lord's manor estate, a fortified great house with plain golden banners",           # 領主莊園
        "a city hall with a domed tower, stone staircase and a plain red pennant",            # 市政廳
        "a central government complex with a wide colonnade, a dome and plain golden pennants",  # 中央政府
        "a presidential palace with a grand dome, formal gardens and a fountain",             # 總統府
    ],
}

# lines that unlock later start their chain at this era (txt2img root there)
START_ERA = {"debt_office": 3}


def run(job_id: str, cmd: list[str]) -> None:
    for attempt in (1, 2):
        print(f"=== {job_id}" + (" (retry)" if attempt == 2 else ""), flush=True)
        if subprocess.run(cmd).returncode == 0:
            return
    raise SystemExit(f"{job_id} failed twice, aborting the batch")


def main() -> None:
    for line in (sys.argv[1:] or ["food"]):
        subjects = LINES[line]
        for seed in SEEDS:
            for era, core in enumerate(subjects, start=1):
                job_id = f"p3_bld_{line}_e{era}_s{seed}"
                cmd = [sys.executable, "comfy_run.py",
                       "--seed", str(seed), "--prompt", core + SUFFIX,
                       "--prefix", f"phase3-buildings/{job_id}", *LORA_ARGS]
                if era == 1:
                    cmd[2:2] = [T2I]
                    cmd += ["--width", "1024", "--height", "1024"]
                else:
                    src = f"{OUT}/p3_bld_{line}_e{era - 1}_s{seed}_00001_.png"
                    cmd[2:2] = [I2I]
                    cmd += ["--image", src, "--denoise", str(DENOISE)]
                run(job_id, cmd)


if __name__ == "__main__":
    main()
