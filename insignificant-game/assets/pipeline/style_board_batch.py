# style_board_batch.py — Phase 1 style boards (cookbook §7): the same 4 subject images
# (food building era1 + era4, infantry card era2, money icon) under 3 style recipes,
# fixed seed sweep 41-44. Jobs are grouped by checkpoint so ComfyUI never thrashes reloads.
# Run with the ComfyUI venv python from assets/pipeline/. Outputs: ComfyUI output dir,
# subfolder style-boards/ (outside the repo per §9).
import subprocess
import sys

SEEDS = [41, 42, 43, 44]
NEG = "blurry, photo, realistic, 3d render, text, watermark, gradient"

# subject key -> (prompt core, width, height)
SUBJECTS = {
    "bld1": ("a primitive tribal farming settlement, single thatched wooden hut, small crop plots, "
             "wooden fence, game building sprite, side view, centered, isolated on a plain light gray background",
             1024, 1024),
    "bld4": ("an industrial era farm, red brick farmhouse with a tall grain silo and a fenced wheat field, "
             "small smokestack, game building sprite, side view, centered, isolated on a plain light gray background",
             1024, 1024),
    "card": ("classical era spear phalanx, bronze armored soldiers with long pikes and round shields "
             "in tight formation, war banners, game card illustration, dramatic composition",
             768, 1024),
    "icon": ("a single gold coin with an embossed crown, game currency icon, bold dark outline, "
             "centered, plain light gray background",
             1024, 1024),
}

# recipe key -> (workflow, prompt prefix, extra comfy_run args)
RECIPES = {
    "r1": ("workflows/sdxl_txt2img.json", "pixel art, ",
           ["--negative", NEG, "--lora", "pixel-art-xl.safetensors", "--lora-strength", "0.9"]),
    "r2": ("workflows/sdxl_txt2img.json", "Pixel Art, PixArFK, ",
           ["--negative", NEG, "--lora", "PixelArtRedmond-Lite64.safetensors", "--lora-strength", "1.0"]),
    "r3": ("workflows/zimage_lora_txt2img.json", "Pixel art style. ",
           ["--lora", "pixel_art_style_z_image_turbo.safetensors", "--lora-strength", "1.0"]),
}


def main() -> None:
    for recipe, (workflow, prefix, extra) in RECIPES.items():  # recipe-major = checkpoint-grouped
        for subject, (core, w, h) in SUBJECTS.items():
            for seed in SEEDS:
                job_id = f"sb_{recipe}_{subject}_s{seed}"
                cmd = [sys.executable, "comfy_run.py", workflow,
                       "--seed", str(seed), "--prompt", prefix + core,
                       "--width", str(w), "--height", str(h),
                       "--prefix", f"style-boards/{job_id}", *extra]
                print(f"=== {job_id}", flush=True)
                subprocess.run(cmd, check=True)


if __name__ == "__main__":
    main()
