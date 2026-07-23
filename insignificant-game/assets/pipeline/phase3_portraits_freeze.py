# phase3_portraits_freeze.py — freeze the human-picked portrait busts (cookbook §7).
#
# Portraits ship FULL-FRAME (no keying) — freeze like the CARDS class, NOT the units sprites. Rationale:
# the v2 style-carrying suffix (needed to hold the Moebius look, §14 2026-07-23) renders a soft
# watercolor WASH background, not a flat gray plate, and watercolor's feathered edges hard-key into
# ragged halos (verified: the keyed halo-check left retained wash blobs in corners + ragged shoulders).
# So a straight full-frame copy is correct: the wash reads as an intentional painted-portrait background,
# and leader portraits in this genre are framed illustrations, not free-floating cutouts. The in-engine
# view composites each into a portrait frame / masks it (a future view wave, like the card widget).
# POST=null (no keying). Run with the ComfyUI venv python from assets/pipeline/. Stems come from
# phase3_portrait_state.json, so a re-rolled pick freezes under its bumped seed.
#
# PICK RECORD (human pick gate, 2026-07-23; v2 seed band).
import json
import os

from PIL import Image

from phase3_portraits_batch import PORTRAITS

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-portraits")
OUT = "../approved/portraits"
STATE = "phase3_portrait_state.json"
MANIFEST = "manifest.jsonl"

# portrait_id -> picked seed (human pick gate, 2026-07-23; v2 seed band). Civs all s62;
# candidates per the human's per-subject pass (military_industrial 53→63 and civs 42→62 confirmed).
PICKS: dict[str, int] = {
    "portrait_civ_science_state": 62,
    "portrait_civ_culture_state": 62,
    "portrait_civ_iron_tribe": 62,
    "portrait_civ_vast_state": 62,
    "portrait_civ_slow_burner": 62,
    "portrait_candidate_technocrat": 62,
    "portrait_candidate_culture_revival": 62,
    "portrait_candidate_iron_expansion": 63,
    "portrait_candidate_populist": 63,
    "portrait_candidate_free_market": 63,
    "portrait_candidate_theocratic": 63,
    "portrait_candidate_military_industrial": 63,
    "portrait_candidate_green_pastoral": 63,
    "portrait_candidate_centrist": 62,
    "portrait_candidate_revolutionary": 62,
}


def main() -> None:
    if not PICKS:
        raise SystemExit("PICKS is empty — fill one seed per portrait id from the pick gate first")
    with open(STATE) as f:
        state = json.load(f)
    os.makedirs(OUT, exist_ok=True)

    frozen: dict[str, Image.Image] = {}
    stem_to_name: dict[str, str] = {}
    for portrait_id, seed in sorted(PICKS.items()):
        assert portrait_id in PORTRAITS, f"unknown portrait id {portrait_id}"
        stem = state[portrait_id][str(seed)]["stem"]
        img = Image.open(f"{SRC}/{stem}_00001_.png").convert("RGB")
        assert img.size == (1024, 1024), f"{stem} is {img.size}, expected 1024x1024"
        img.save(f"{OUT}/{portrait_id}.png")
        frozen[portrait_id] = img
        stem_to_name[stem] = portrait_id
        print(f"froze {portrait_id}.png {img.width}x{img.height} <- {stem}")

    # flip picked manifest rows to approved (full-frame copy, no keying → post=null)
    lines, flipped = [], 0
    with open(MANIFEST) as f:
        for raw in f:
            e = json.loads(raw)
            if e["id"] in stem_to_name:
                e["status"] = "approved"
                e["file"] = f"assets/approved/portraits/{stem_to_name[e['id']]}.png"
                e["post"] = None
                flipped += 1
            lines.append(json.dumps(e, ensure_ascii=False))
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"manifest: {flipped} rows flipped to approved ({len(PICKS)} busts frozen)")

    coverage = {
        "civs": sorted(p for p in PICKS if p.startswith("portrait_civ_")),
        "candidates": sorted(p for p in PICKS if p.startswith("portrait_candidate_")),
    }
    json.dump(coverage, open("phase3_portraits_coverage.json", "w"), ensure_ascii=False, indent=1)
    print("wrote phase3_portraits_coverage.json (registry source for AssetPaths portrait lists)")

    # frozen gallery (what ships): 5 cols, thumbnails on a neutral sheet
    cols, cell, pad = 5, 320, 6
    names = sorted(frozen)
    rows = (len(names) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * cell), (30, 30, 34))
    for i, name in enumerate(names):
        t = frozen[name].copy()
        t.thumbnail((cell - 2 * pad, cell - 2 * pad), Image.LANCZOS)
        sheet.paste(t, ((i % cols) * cell + pad, (i // cols) * cell + pad))
    sheet.save("../contact-sheets/phase3_portraits_frozen.png")
    print("wrote ../contact-sheets/phase3_portraits_frozen.png")


if __name__ == "__main__":
    main()
