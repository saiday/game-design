# phase3_backgrounds_topdown_freeze.py — freeze the 7 human-picked top-down battle plates
# (W14.8, ADR-0009), replacing the side-view bg_battle_* plates at the same paths.
#
# Modelled on phase3_backgrounds_freeze.py and identical in mechanism: a plate is a full-frame
# 1920x1088 image, so there is no keying and no crop, only a straight copy to
# ../approved/backgrounds/bg_<battle>.png plus a manifest row whose recipe is read from the picked
# PNG's embedded workflow metadata.
#
# Two differences from that script, both from the camera:
#
#  1. It touches ONLY the 7 battle plates. The other 10 backgrounds are unchanged by ADR-0009 —
#     the city panorama stays a side-view valley by design (style bible §11) and the route map was
#     already top-down — so they keep their approved files and their approved manifest rows.
#  2. It supersedes. The side-view battle rows cannot stay `approved` once their files are
#     overwritten; they get status `superseded` and a `superseded_by` pointing at the new render
#     (decisions.md W14.8, same vocabulary the unit freeze introduced).
#
# WHAT THIS SCRIPT DELIBERATELY DOES NOT CHECK, and why it is written down instead of retried: a
# battle plate must be FLAT (under ADR-0009 a station's screen position is just its lane slot, so
# two equal-sized units stand at the top and bottom of the same field, and on a receding plate one
# of them stands on cobbles smaller than its boots). That is the defect the whole plate round
# existed to kill, so an automatic freeze-time gate for it is the obvious thing to add — and it
# does not work. A top/bottom detail-energy ratio was measured across the approved set and the
# round-2 set that was rejected FOR receding: the approved plates cluster at 0.90-1.07, but the
# rejected ones land at 0.70, 0.95, 1.14 and 1.52, straddling the good band from both sides. No
# threshold separates them. This is the second time the proxy has been tried here (the first is
# recorded in the scratch platecheck tool: it "flagged a plate that was visibly flat and missed one
# that visibly receded"), so it is now a finding rather than an open idea.
#
# The number is still printed, because a plate that drifts far from the approved cluster is worth a
# second look. It is information, never a verdict. What settles recession is the human eye on the
# top and bottom 200px bands compared at equal scale, which is the gate the picks already passed.
#
# Run with the ComfyUI venv python from assets/pipeline/.
import json
import os

import numpy as np
from PIL import Image

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-backgrounds-topdown")
OUT = "../approved/backgrounds"
PICKS = "phase3_backgrounds_topdown_picks.json"
MANIFEST = "manifest.jsonl"
CHECKPOINT = "krea2_turbo_bf16@78bbf8f4"
LORAS = [["Krea2_Moebius_LoRA", 1.0]]
BAND = 200          # px sampled at the top and bottom of the frame
APPROVED_BAND = (0.89, 1.08)   # where the 7 approved plates measured; reported, never enforced.
                               # A hair wider than the measured 0.90-1.07 so the two plates that
                               # DEFINE the ends of the range don't flag themselves every run.


def render_recipe(stem: str) -> dict:
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


def recession(img: Image.Image) -> float:
    """Top-band detail energy over bottom-band. Reported only — see the header for why this cannot
    gate: measured against the set that was rejected for receding, it does not separate them."""
    g = np.asarray(img.convert("L")).astype(float)
    top, bot = g[:BAND], g[-BAND:]
    energy = lambda b: float(np.mean(np.abs(np.diff(b, axis=0))) + np.mean(np.abs(np.diff(b, axis=1))))
    e_top, e_bot = energy(top), energy(bot)
    return e_top / e_bot if e_bot else float("inf")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    with open(PICKS) as f:
        picks = json.load(f)["picks"]

    rows_new, by_subject = [], {}
    for battle, seed in sorted(picks.items()):
        stem = f"p3_bgtd_{battle}_s{seed}"
        img = Image.open(f"{SRC}/{stem}_00001_.png")
        ratio = recession(img)
        drift = "" if APPROVED_BAND[0] <= ratio <= APPROVED_BAND[1] else "  <- outside the approved cluster, look at it"
        bg_id = f"bg_{battle}"
        img.convert("RGB").save(f"{OUT}/{bg_id}.png")
        by_subject[bg_id] = stem
        rows_new.append({"id": stem, "file": f"assets/approved/backgrounds/{bg_id}.png",
                         "class": "background-topdown", "subject": bg_id,
                         **render_recipe(stem), "checkpoint": CHECKPOINT, "loras": LORAS,
                         "workflow": "workflows/krea2_lora_txt2img.json",
                         "post": {"key": None, "cropped": False},
                         "status": "approved", "camera": "top-down (ADR-0009)"})
        print(f"froze {bg_id}.png {img.width}x{img.height} <- {stem}  (band ratio {ratio:.2f}){drift}")

    new_ids = {r["id"] for r in rows_new}
    rows_out, marked = [], 0
    with open(MANIFEST) as f:
        for raw in f:
            e = json.loads(raw)
            if e["id"] in new_ids:              # re-run: the fresh row below replaces it
                continue
            file = e.get("file") or ""
            if e.get("status") == "approved" and file.startswith("assets/approved/backgrounds/"):
                subject = os.path.basename(file).removesuffix(".png")
                if subject in by_subject:
                    e["status"], e["superseded_by"] = "superseded", by_subject[subject]
                    marked += 1
            rows_out.append(e)
    rows_out += rows_new
    with open(MANIFEST, "w") as f:
        f.write("\n".join(json.dumps(e, ensure_ascii=False) for e in rows_out) + "\n")
    print(f"manifest: +{len(rows_new)} approved rows, {marked} superseded "
          f"(the 10 non-battle plates are untouched)")


if __name__ == "__main__":
    main()
