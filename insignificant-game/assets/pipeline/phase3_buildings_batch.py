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

# line -> [era1..era6 subject cores] (era forms: 營運 建築線總表)
LINES = {
    "food": [
        "a small tribal homestead settlement, thatched huts among planted crop fields",       # 屯墾區
        "a classical farmstead, stone farmhouse with fenced crop fields and grain sacks",     # 農莊
        "a manor farm, large manor farmhouse over plowed field strips",                       # 莊園農地
        "an industrial farm, red barn with a tall grain silo and wheat fields",               # 農場
        "a mechanized farm, huge steel grain silos, a tractor and machine sheds",             # 機械化農場
        "a vertical farm tower, stacked glass greenhouse floors glowing with plants",         # 垂直農場
    ],
}


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
