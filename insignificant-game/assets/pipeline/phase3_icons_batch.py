# phase3_icons_batch.py — Phase 3 class 1: UI icon glyphs (cookbook §7), generated under the
# locked style bible §2-§3 and reviewed composited into the frozen plate (style bible §9).
# Groups follow inventory.md "UI icons"; run one group per invocation, e.g.
# `phase3_icons_batch.py core`. Glyph subjects below are proposals — the human judges them on
# the contact sheet like any candidate. Run with the ComfyUI venv python from assets/pipeline/.
import subprocess
import sys

SEEDS = [61, 62, 63]
WORKFLOW = "workflows/krea2_lora_txt2img.json"
LORA_ARGS = ["--lora", "Krea2_Moebius_LoRA.safetensors", "--lora-strength", "1.0"]
SUFFIX = ", bold dark outline, centered, plain light gray background"

# group -> {icon id suffix: subject core (style bible §3 icon row; suffix appended)}
GROUPS = {
    "core": {
        "money": "a single gold coin with an embossed crown, game currency icon",
        "population": "two standing villagers side by side, game population icon",
        "bp": "a wooden mallet crossed with a stone chisel, game build points icon",
        "tech": "a large brass cogwheel, game technology icon",
        "culture": "a classical golden lyre, game culture icon",
        "happiness": "a radiant smiling sun, game happiness icon",
        "debt": "a stack of gold coins with a jagged crack through it, game debt icon",
        # debt alternates: v1 renders as a plain coin stack (reads as wealth, collides with money)
        "debt2": "a single gold coin broken in two halves with a jagged crack between them, game debt icon",
        "debt3": "a leather money pouch turned inside out, empty and drooping, game debt icon",
        "interest": "an hourglass filled with falling gold coins, game interest icon",
        "unrest": "a raised clenched fist, game unrest icon",
        "power": "a shield emblazoned with a five-pointed star, game power icon",
    },
    "battle": {
        "attack": "a single sharp sword pointing upward, game attack icon",
        "hp": "a bold heart shape, game health icon",
        "military_cost": "a gold coin stamped with a crossed-swords mark, game military cost icon",
    },
    # further inventory groups (card classes, regions, policy, legacies, map, opportunities,
    # eras, democracy) get their glyph proposals when their batch is scheduled.
}


def main() -> None:
    wanted = sys.argv[1:] or ["core"]
    for group in wanted:
        for icon, core in GROUPS[group].items():
            for seed in SEEDS:
                job_id = f"p3_icon_{icon}_s{seed}"
                cmd = [sys.executable, "comfy_run.py", WORKFLOW,
                       "--seed", str(seed), "--prompt", core + SUFFIX,
                       "--width", "1024", "--height", "1024",
                       "--prefix", f"phase3-icons/{job_id}", *LORA_ARGS]
                for attempt in (1, 2):
                    print(f"=== {job_id}" + (" (retry)" if attempt == 2 else ""), flush=True)
                    if subprocess.run(cmd).returncode == 0:
                        break
                else:
                    raise SystemExit(f"{job_id} failed twice, aborting the batch")


if __name__ == "__main__":
    main()
