# phase3_cards_manifest_sync.py — append candidate rows to manifest.jsonl for every card raw
# recorded in phase3_card_state.json that isn't already tracked (cookbook §9 provenance: an asset
# you can't regenerate is a dead end). Idempotent: existing ids are skipped, so it is safe to re-run
# after each re-roll round. Candidate rows point at the raw output path outside the repo; a future
# phase3_cards_freeze.py flips a picked row to approved and copies it into approved/cards/.
# Run with any python (stdlib only) from assets/pipeline/.
import json
import os

from phase3_cards_batch import STATE

SRC = "~/ComfyUI-Shared/output/phase3-cards"
MANIFEST = "manifest.jsonl"
DATE = "2026-07-23"


def existing_ids() -> set[str]:
    ids = set()
    if os.path.exists(MANIFEST):
        with open(MANIFEST) as f:
            for line in f:
                line = line.strip()
                if line:
                    ids.add(json.loads(line)["id"])
    return ids


def main() -> None:
    with open(STATE) as f:
        state = json.load(f)
    have = existing_ids()
    rows = []
    for card_id, seeds in state.items():
        for seed, rec in seeds.items():
            stem = rec["stem"]
            if stem in have:
                continue
            rows.append({
                "id": stem,
                "file": f"{SRC}/{stem}_00001_.png",
                "class": "card-candidate",
                "subject": card_id[len("card_"):],
                "prompt": rec["prompt"],
                "negative": None,
                "seed": int(seed),
                "checkpoint": "krea2_turbo_bf16@78bbf8f4",
                "loras": [["Krea2_Moebius_LoRA", 1.0]],
                "workflow": "workflows/krea2_lora_txt2img.json",
                "lineage": None,
                "root": None,
                "post": None,
                "status": "candidate",
                "reject_reason": None,
                "date": DATE,
            })
    if not rows:
        print("manifest already in sync (no new candidate rows)")
        return
    with open(MANIFEST, "a") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"appended {len(rows)} candidate rows to {MANIFEST}")


if __name__ == "__main__":
    main()
