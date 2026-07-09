# phase2_templates_batch.py — Phase 2 template candidates (cookbook §6-§7): the five frozen
# structural assets from inventory.md "UI templates", generated under the locked style bible
# (Krea-2-Turbo + Moebius LoRA @1.0, subject-only prompts, no negative lever), fixed seed sweep.
# Run with the ComfyUI venv python from assets/pipeline/. Outputs: ComfyUI output dir,
# subfolder phase2-templates/ (outside the repo per §9).
import subprocess
import sys

SEEDS = [51, 52, 53, 54]
WORKFLOW = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]

# template key -> (subject-only prompt, width, height)  — style bible §3 discipline:
# no style prefix, no trigger word, no art-style descriptors.
TEMPLATES = {
    "card_frame": ("game card frame, ornate symmetrical border surrounding a large empty "
                   "rectangular picture window in the upper half and an empty text panel in the "
                   "lower half, centered, isolated on a plain light gray background",
                   768, 1024),
    "panel": ("game UI panel frame, rectangular border with decorative corner ornaments and a "
              "plain empty center, centered, isolated on a plain light gray background",
              1024, 1024),
    "button": ("game UI button, wide rounded rectangular blank button face with a decorative "
               "outlined rim, centered, isolated on a plain light gray background",
               1024, 512),
    "icon_plate": ("game icon base plate, round emblem backplate with a decorative rim and a "
                   "plain empty center, centered, isolated on a plain light gray background",
                   1024, 1024),
    # v2 prompt: the human rejected the first sweep's dividers as too fancy (center emblems)
    "divider": ("game UI divider, a single long thin plain horizontal rule with small subtle "
                "flourishes at both ends only, isolated on a plain light gray background",
                1024, 256),
}


def main() -> None:
    wanted = sys.argv[1:] or list(TEMPLATES)  # e.g. `phase2_templates_batch.py card_frame`
    for template in wanted:
        prompt, w, h = TEMPLATES[template]
        for seed in SEEDS:
            job_id = f"p2_{template}_s{seed}"
            cmd = [sys.executable, "comfy_run.py", WORKFLOW,
                   "--seed", str(seed), "--prompt", prompt,
                   "--width", str(w), "--height", str(h),
                   "--prefix", f"phase2-templates/{job_id}", *LORA_ARGS]
            for attempt in (1, 2):  # one retry: a server restart kills the in-flight job
                print(f"=== {job_id}" + (" (retry)" if attempt == 2 else ""), flush=True)
                if subprocess.run(cmd).returncode == 0:
                    break
            else:
                raise SystemExit(f"{job_id} failed twice, aborting the batch")


if __name__ == "__main__":
    main()
