# phase3_units_manifest_sync.py — append unit/fort/enemy lineage rows to manifest.jsonl
# (cookbook §7/§9), the pre-pick-gate candidate record for the units class. One row per era cell
# in phase3_unit_chains.json; the prompt/seed/denoise/parent come from each PNG's EMBEDDED workflow
# metadata (the render-time truth), never the batch script's current wording, which keeps iterating
# (same rule as phase3_backgrounds_freeze.py). Clean cells are status "candidate" (the human picks
# one whole lineage per line from the contact sheets); §8-rejected cells are status "rejected" with
# their reason, so the record is complete and a rejected cell can never be mistaken for pickable.
# Idempotent: re-running replaces every existing unit-candidate row rather than duplicating.
# Run with the ComfyUI venv python from assets/pipeline/ after the last wave + all §8 review.
import json
import os
from datetime import date

from PIL import Image

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-units")
STATE = "phase3_unit_chains.json"
MANIFEST = "manifest.jsonl"
CHECKPOINT = "krea2_turbo_bf16@78bbf8f4"
LORAS = [["Krea2_Moebius_LoRA", 1.0]]
CLASS = "unit-candidate"


def render_recipe(stem: str) -> dict:
    """Prompt/seed/denoise/parent as embedded in the render itself."""
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
    with open(STATE) as f:
        state = json.load(f)
    today = date.today().isoformat()

    rows = []
    for line in sorted(state):
        for chain in sorted(state[line], key=int):
            for era in sorted(state[line][chain], key=int):
                cell = state[line][chain][era]
                stem = cell["stem"]
                r = render_recipe(stem)
                i2i = r["parent"] is not None
                rejected = bool(cell.get("rejected"))
                row = {
                    "id": stem,
                    "file": f"~/ComfyUI-Shared/output/phase3-units/{stem}_00001_.png",
                    "class": CLASS,
                    "subject": f"{line}_era{era}",
                    "chain": int(chain),
                    "prompt": r["prompt"],
                    "negative": None,
                    "seed": r["seed"],
                    "checkpoint": CHECKPOINT,
                    "loras": LORAS,
                    "workflow": "workflows/krea2_lora_img2img.json" if i2i
                                else "workflows/krea2_lora_txt2img.json",
                    "lineage": {"parent": r["parent"], "denoise": r["denoise"]} if i2i else None,
                    "root": True if cell.get("root") else None,  # txt2img lineage seam at era > start
                    "post": None,  # keyed/cropped only at the post-pick freeze step, like buildings
                    "status": "rejected" if rejected else "candidate",
                    "reject_reason": cell.get("reject_reason") if rejected else None,
                    "date": today,
                }
                rows.append(row)

    # idempotent: drop any prior unit-candidate rows, keep everything else, then append fresh
    kept = [l for l in open(MANIFEST) if l.strip()
            and json.loads(l).get("class") != CLASS]
    with open(MANIFEST, "w") as f:
        for l in kept:
            f.write(l if l.endswith("\n") else l + "\n")
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    clean = sum(1 for r in rows if r["status"] == "candidate")
    roots = sum(1 for r in rows if r["root"])
    print(f"manifest: {len(rows)} unit rows ({clean} candidate, {len(rows) - clean} rejected, "
          f"{roots} txt2img roots); {len(kept)} non-unit rows preserved")


if __name__ == "__main__":
    main()
