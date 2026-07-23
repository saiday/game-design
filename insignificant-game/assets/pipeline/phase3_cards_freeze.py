# phase3_cards_freeze.py — freeze the human-picked card illustrations (cookbook §7).
# Cards are full-frame 768×1024 txt2img dramatic scenes: NO keying, NO crop baked in — a straight
# copy to ../approved/cards/card_<subject>.png, exactly like the backgrounds freeze. The frozen
# card frame (ui_card_frame.png) composites OVER the illustration at runtime and its window rect
# crops the bottom band (where the model's fake signatures land) — so the crop is a presentation
# concern handled in-engine, and the approved asset stays the whole illustration.
# The pick of record is PICKS in phase3_cards_batch.py (one seed per subject, 57/57). This flips the
# picked manifest rows to approved (units-freeze pattern; no duplicate ids) and renders an in-frame
# mock sheet — the honest verification for this class: it shows what actually ships after the window
# crop (subject centred, signatures gone, no framing breach). Run with the ComfyUI venv python from
# assets/pipeline/.
import json
import os
import re

from PIL import Image

from phase3_cards_batch import PICKS

SRC = os.path.expanduser("~/ComfyUI-Shared/output/phase3-cards")
OUT = "../approved/cards"
MANIFEST = "manifest.jsonl"
FRAME = "../approved/ui/ui_card_frame.png"
WINDOW = (134, 108, 356, 421)   # AssetPaths.UI_CARD_FRAME window (x, y, w, h)
ERA_RE = re.compile(r"^(.+)_era(\d+)$")


def cover_fit(illo: Image.Image, w: int, h: int) -> Image.Image:
    """Scale to COVER a w×h box (fill, crop overflow), centred — the runtime frame-window fit."""
    scale = max(w / illo.width, h / illo.height)
    r = illo.resize((round(illo.width * scale), round(illo.height * scale)), Image.LANCZOS)
    left, top = (r.width - w) // 2, (r.height - h) // 2
    return r.crop((left, top, left + w, top + h))


def in_frame(illo: Image.Image, frame: Image.Image) -> Image.Image:
    """Composite the illustration UNDER the frame, cover-fit into the transparent window."""
    x, y, w, h = WINDOW
    canvas = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    canvas.paste(cover_fit(illo, w, h), (x, y))
    canvas.alpha_composite(frame)
    return canvas


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    # subject -> (asset name, source stem)
    plan: dict[str, tuple[str, str]] = {}
    for card_id, seed in PICKS.items():
        subject = card_id[len("card_"):]
        plan[subject] = (f"card_{subject}", f"p3_card_{subject}_s{seed}")

    stem_to_name: dict[str, str] = {}
    frozen: list[str] = []
    for subject, (name, stem) in sorted(plan.items()):
        src = f"{SRC}/{stem}_00001_.png"
        img = Image.open(src)
        if img.size != (768, 1024):
            raise SystemExit(f"{stem}: unexpected size {img.size}, expected 768x1024")
        img.save(f"{OUT}/{name}.png")
        stem_to_name[stem] = name
        frozen.append(name)
        print(f"froze {name}.png {img.width}x{img.height} <- {stem}")

    # flip picked manifest rows to approved (in place; non-picked candidates stay candidate)
    lines = []
    flipped = 0
    with open(MANIFEST) as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            e = json.loads(raw)
            if e["id"] in stem_to_name:
                e["status"] = "approved"
                e["file"] = f"assets/approved/cards/{stem_to_name[e['id']]}.png"
                e["post"] = None   # full-frame copy, no keying/crop baked in
                flipped += 1
            lines.append(json.dumps(e, ensure_ascii=False))
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"manifest: {flipped} rows flipped to approved ({len(plan)} cards frozen)")

    # coverage json (registry source for AssetPaths.CARD_COVERAGE + CARD_SKILLS)
    coverage: dict[str, list[int]] = {}
    skills: list[str] = []
    for subject in plan:
        m = ERA_RE.match(subject)
        if m:
            coverage.setdefault(m.group(1), []).append(int(m.group(2)))
        else:
            skills.append(subject)
    coverage = {k: sorted(v) for k, v in sorted(coverage.items())}
    json.dump({"lines": coverage, "skills": sorted(skills)},
              open("phase3_cards_coverage.json", "w"), ensure_ascii=False, indent=1)
    print(f"wrote phase3_cards_coverage.json ({len(coverage)} lines, {len(skills)} skill cards)")

    # in-frame mock sheet: every frozen card composited under the real frame, cover-fit into the
    # window (what ships). This is the freeze verification artifact for the card class.
    frame = Image.open(FRAME).convert("RGBA")
    cell_w, cell_h, pad, cols = frame.width, frame.height, 16, 7
    tw, th = cell_w // 2, cell_h // 2   # half-scale tiles keep the sheet a sane size
    rows_n = (len(frozen) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + pad) + pad, rows_n * (th + pad) + pad), (28, 28, 32))
    for i, name in enumerate(frozen):
        illo = Image.open(f"{OUT}/{name}.png").convert("RGB")
        tile = in_frame(illo, frame).convert("RGB").resize((tw, th), Image.LANCZOS)
        col, row = i % cols, i // cols
        sheet.paste(tile, (pad + col * (tw + pad), pad + row * (th + pad)))
    mock = "../contact-sheets/phase3_cards_inframe_freeze.png"
    sheet.save(mock)
    print(f"wrote {mock}  ({len(frozen)} cards in-frame)")


if __name__ == "__main__":
    main()
