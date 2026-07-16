# phase3_backgrounds_freeze.py — freeze the human-picked background plates (cookbook §7/§9).
# Backgrounds are full-frame 1920×1088 plates: no keying, no crop — a straight copy to
# ../approved/backgrounds/<bg_id>.png. Reproducibility rows are appended to manifest.jsonl with
# the prompt/seed/denoise/lineage read from each picked PNG's EMBEDDED workflow metadata (the
# render-time truth), never from the batch script's current wording, which keeps iterating.
# Run with the ComfyUI venv python from assets/pipeline/.
import json
import os
from datetime import date

from PIL import Image

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-backgrounds")
OUT = "../approved/backgrounds"
MANIFEST = "manifest.jsonl"
CHECKPOINT = "krea2_turbo_bf16@78bbf8f4"
LORAS = [["Krea2_Moebius_LoRA", 1.0]]

# human gate picks (2026-07-16): one seed per plate row, city = the whole chain-52 row
PLATE_PICKS: dict[str, int] = {
    "route_map": 51,
    "battle_tax": 53,
    "battle_field": 53,
    "battle_hidden": 52,
    "battle_riot": 57,
    "battle_democracy": 57,
    "battle_civwar": 54,
    "battle_worldwar": 52,
    "title": 51,
    "ending_survive": 52,
    "ending_collapse": 79,
}
CITY_CHAIN = 52


def render_recipe(stem: str) -> dict:
    """Prompt/seed/denoise/lineage as embedded in the picked render itself."""
    wf = json.loads(Image.open(f"{SRC}/{stem}_00001_.png").info["prompt"])
    prompt, seed, denoise, parent = None, None, None, None
    for node in wf.values():
        ct = node.get("class_type")
        if ct == "KSampler":
            seed, denoise = node["inputs"]["seed"], node["inputs"]["denoise"]
        elif ct == "LoadImage":
            parent = node["inputs"]["image"].removesuffix("_00001_.png")
        elif ct == "CLIPTextEncode" and prompt is None:
            prompt = node["inputs"]["text"]
    return {"prompt": prompt, "seed": seed, "denoise": denoise, "parent": parent}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    picks: dict[str, str] = {f"bg_{p}": f"p3_bg_{p}_s{s}" for p, s in PLATE_PICKS.items()}
    with open("phase3_background_chains.json") as f:
        chain = json.load(f)["city"][str(CITY_CHAIN)]
    picks |= {f"bg_city_era{e}": chain[str(e)]["stem"] for e in range(1, 7)}

    rows = []
    for bg_id, stem in picks.items():
        img = Image.open(f"{SRC}/{stem}_00001_.png")
        img.save(f"{OUT}/{bg_id}.png")
        r = render_recipe(stem)
        i2i = r["parent"] is not None
        rows.append({
            "id": stem,
            "file": f"assets/approved/backgrounds/{bg_id}.png",
            "class": "background",
            "subject": bg_id,
            "prompt": r["prompt"],
            "negative": None,
            "seed": r["seed"],
            "checkpoint": CHECKPOINT,
            "loras": LORAS,
            "workflow": "workflows/krea2_lora_img2img.json" if i2i else "workflows/krea2_lora_txt2img.json",
            "lineage": {"parent": r["parent"], "denoise": r["denoise"]} if i2i else None,
            "post": None,
            "status": "approved",
            "date": date.today().isoformat(),
        })
        print(f"froze {bg_id}.png {img.width}x{img.height} <- {stem}"
              + (f" (parent {r['parent']} @ {r['denoise']})" if i2i else ""))

    with open(MANIFEST, "a") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"manifest: {len(rows)} approved background rows appended")


if __name__ == "__main__":
    main()
