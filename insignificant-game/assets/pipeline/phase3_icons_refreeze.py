# phase3_icons_refreeze.py — freeze the 44px-expressiveness re-picks (cookbook §14: population /
# era3 / bp failed the HUD-size review; map_opportunity is new for the route scene's 世界地圖 fog
# upgrade). Same freeze mechanics as phase3_icons_freeze.py; additionally flips the replaced
# approved entries to rejected and points their files back at the raw candidates.
# Run with the ComfyUI venv python from assets/pipeline/.
import json
import os

from PIL import Image, ImageDraw, ImageFont

from phase3_icon_sheets import keyed_glyph

# canonical icon name -> picked candidate stem (human gate picks)
PICKS = {
    "population": "p3_icon_population4_s81",
    "era3": "p3_icon_era3v3_s82",
    "bp": "p3_icon_bp2_s83",
    "map_opportunity": "p3_icon_map_opportunity_s81",
}
# previously approved stem -> the pick that replaces it
REPLACED = {
    "p3_icon_population3_s62": "p3_icon_population4_s81",
    "p3_icon_era3v2_s62": "p3_icon_era3v3_s82",
    "p3_icon_bp_s61": "p3_icon_bp2_s83",
}
REJECT_REASON = "failed the 44px HUD expressiveness review (cookbook §14); replaced by {new}"
OUT = "../approved/icons"
MANIFEST = "manifest.jsonl"
RAW = "~/ComfyUI-Shared/output/phase3-icons"
POST = {"key": "border-flood", "tolerance": 60, "cropped": True,
        "note": "same keying as the review sheet (phase3_icon_sheets.keyed_glyph)"}


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    glyphs: dict[str, Image.Image] = {}
    for name, stem in PICKS.items():
        g = keyed_glyph(stem)
        g.save(f"{OUT}/icon_{name}.png")
        glyphs[name] = g
        print(f"froze icon_{name}.png {g.width}x{g.height} <- {stem}")

    stem_to_name = {stem: name for name, stem in PICKS.items()}
    lines = []
    flipped = rejected = 0
    with open(MANIFEST) as f:
        for line in f:
            e = json.loads(line)
            if e["id"] in stem_to_name:
                e["status"] = "approved"
                e["file"] = f"assets/approved/icons/icon_{stem_to_name[e['id']]}.png"
                e["post"] = POST
                flipped += 1
            elif e["id"] in REPLACED:
                e["status"] = "rejected"
                e["reject_reason"] = REJECT_REASON.format(new=REPLACED[e["id"]])
                e["file"] = f"{RAW}/{e['id']}_00001_.png"
                rejected += 1
            lines.append(json.dumps(e, ensure_ascii=False))
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"manifest: {flipped} flipped to approved, {rejected} replaced entries rejected")

    # halo check: each re-pick on dark and light (style bible §4)
    cell, pad = 260, 8
    font = ImageFont.load_default(size=14)
    names = list(glyphs)
    sheet = Image.new("RGB", (cell * len(names), cell * 2 + 24), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for col, name in enumerate(names):
        t = glyphs[name].copy()
        t.thumbnail((cell - 2 * pad, cell - 2 * pad), Image.LANCZOS)
        for row, bg in enumerate([(20, 20, 30), (235, 235, 225)]):
            tile = Image.new("RGBA", (cell, cell), bg + (255,))
            tile.alpha_composite(t, ((cell - t.width) // 2, (cell - t.height) // 2))
            sheet.paste(tile.convert("RGB"), (col * cell, row * cell))
        d.text((col * cell + pad, cell * 2 + 4), name, fill=(220, 220, 220), font=font)
    sheet.save("../contact-sheets/phase3_icons_halo_repicks.png")
    print("wrote ../contact-sheets/phase3_icons_halo_repicks.png")


if __name__ == "__main__":
    main()
