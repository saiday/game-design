# phase3_icons_freeze.py — freeze human-picked icon glyphs (cookbook §7 Phase 3).
# Keys each pick with the exact params the review sheet used (phase3_icon_sheets.keyed_glyph),
# crops tight, writes ../approved/icons/icon_<name>.png (bare glyph — the plate composite
# happens at runtime, style bible §9), flips the manifest entry to approved, and renders a
# halo-check sheet (each glyph on a dark and a light backdrop, style bible §4).
# Run with the ComfyUI venv python from assets/pipeline/.
import json
import os

from PIL import Image, ImageDraw, ImageFont

from phase3_icon_sheets import keyed_glyph

# canonical icon name -> picked candidate stem (human gate pick)
PICKS = {
    "money": "p3_icon_money_s61",
    "bp": "p3_icon_bp_s61",
    "tech": "p3_icon_tech_s61",
    "culture": "p3_icon_culture_s61",
    "happiness": "p3_icon_happiness_s61",
    "debt": "p3_icon_debt2_s61",
    "interest": "p3_icon_interest_s61",
    "power": "p3_icon_power_s61",
}
OUT = "../approved/icons"
MANIFEST = "manifest.jsonl"
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

    lines = []
    with open(MANIFEST) as f:
        for line in f:
            e = json.loads(line)
            for name, stem in PICKS.items():
                if e["id"] == stem:
                    e["status"] = "approved"
                    e["file"] = f"assets/approved/icons/icon_{name}.png"
                    e["post"] = POST
            lines.append(json.dumps(e, ensure_ascii=False))
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"manifest: {len(PICKS)} entries flipped to approved")

    # halo check: every glyph on dark and light (style bible §4)
    cell, pad = 260, 8
    font = ImageFont.load_default(size=14)
    sheet = Image.new("RGB", (cell * len(glyphs), cell * 2 + 24), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for col, (name, g) in enumerate(glyphs.items()):
        t = g.copy()
        t.thumbnail((cell - 2 * pad, cell - 2 * pad), Image.LANCZOS)
        for row, bg in enumerate([(20, 20, 30), (235, 235, 225)]):
            tile = Image.new("RGBA", (cell, cell), bg + (255,))
            tile.alpha_composite(t, ((cell - t.width) // 2, (cell - t.height) // 2))
            sheet.paste(tile.convert("RGB"), (col * cell, row * cell))
        d.text((col * cell + pad, cell * 2 + 4), name, fill=(220, 220, 220), font=font)
    sheet.save("../contact-sheets/phase3_icons_core_halo_check.png")
    print("wrote ../contact-sheets/phase3_icons_core_halo_check.png")


if __name__ == "__main__":
    main()
