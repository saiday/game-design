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

# canonical icon name -> picked candidate stem (human gate picks; variant suffixes in the stem
# collapse to the canonical name). All 75 icons picked (population/era3/bp re-picked at the 44px
# expressiveness gate and map_opportunity added — see phase3_icons_refreeze.py).
PICKS = {
    "legacy_religious_dogma": "p3_icon_legacy_religious_dogma2_s62",
    "legacy_democratic_spirit": "p3_icon_legacy_democratic_spirit2_s62",
    "era3": "p3_icon_era3v3_s82",
    "era6": "p3_icon_era6v3_s61",
    "money": "p3_icon_money_s61",
    "population": "p3_icon_population4_s81",
    "unrest": "p3_icon_unrest2_s61",
    "bp": "p3_icon_bp2_s83",
    "tech": "p3_icon_tech_s61",
    "culture": "p3_icon_culture_s61",
    "happiness": "p3_icon_happiness_s61",
    "debt": "p3_icon_debt2_s61",
    "interest": "p3_icon_interest_s61",
    "power": "p3_icon_power_s61",
    "attack": "p3_icon_attack_s61",
    "hp": "p3_icon_hp_s61",
    "military_cost": "p3_icon_military_cost_s61",
    "class_personnel": "p3_icon_class_personnel_s61",
    "class_mechanical": "p3_icon_class_mechanical_s61",
    "class_fortification": "p3_icon_class_fortification_s61",
    "class_skill": "p3_icon_class_skill_s62",
    "region_livelihood": "p3_icon_region_livelihood_s62",
    "region_academic": "p3_icon_region_academic_s62",
    "region_military": "p3_icon_region_military_s62",
    "region_culture": "p3_icon_region_culture_s62",
    "region_finance": "p3_icon_region_finance_s62",
    "theme_power": "p3_icon_theme_power_s61",
    "theme_tech": "p3_icon_theme_tech_s61",
    "theme_culture": "p3_icon_theme_culture_s61",
    "theme_religion": "p3_icon_theme_religion_s61",
    "theme_exploration": "p3_icon_theme_exploration_s61",
    "theme_recon": "p3_icon_theme_recon_s61",
    "policy_centralization": "p3_icon_policy_centralization_s61",
    "policy_bureaucracy": "p3_icon_policy_bureaucracy_s61",
    "policy_secret_police": "p3_icon_policy_secret_police_s63",
    "policy_cultural_revolution": "p3_icon_policy_cultural_revolution2_s61",
    "policy_enlightened_absolutism": "p3_icon_policy_enlightened_absolutism_s61",
    "policy_writing_calendar": "p3_icon_policy_writing_calendar_s61",
    "policy_secularization": "p3_icon_policy_secularization_s61",
    "policy_patent_system": "p3_icon_policy_patent_system_s61",
    "policy_moon_race": "p3_icon_policy_moon_race_s61",
    "policy_space_station": "p3_icon_policy_space_station_s63",
    "policy_ancestor_worship": "p3_icon_policy_ancestor_worship_s62",
    "policy_state_religion": "p3_icon_policy_state_religion_s63",
    "policy_theocracy": "p3_icon_policy_theocracy_s63",
    "policy_holy_war": "p3_icon_policy_holy_war_s61",
    "policy_hundred_schools": "p3_icon_policy_hundred_schools_s61",
    "policy_mass_media": "p3_icon_policy_mass_media_s61",
    "policy_cultural_export": "p3_icon_policy_cultural_export_s61",
    "policy_great_voyage": "p3_icon_policy_great_voyage_s61",
    "policy_world_map": "p3_icon_policy_world_map_s61",
    "policy_world_expo": "p3_icon_policy_world_expo2_s61",
    "policy_scout_camp": "p3_icon_policy_scout_camp_s61",
    "policy_political_marriage": "p3_icon_policy_political_marriage_s61",
    "policy_intelligence_agency": "p3_icon_policy_intelligence_agency2_s63",
    "policy_satellite_surveillance": "p3_icon_policy_satellite_surveillance_s61",
    "legacy_rational_spirit": "p3_icon_legacy_rational_spirit_s62",
    "legacy_critical_spirit": "p3_icon_legacy_critical_spirit_s62",
    "legacy_rock_spirit": "p3_icon_legacy_rock_spirit_s62",
    "legacy_melting_pot": "p3_icon_legacy_melting_pot_s63",
    "legacy_martial_law": "p3_icon_legacy_martial_law_s62",
    "map_battle": "p3_icon_map_battle_s61",
    "map_opportunity": "p3_icon_map_opportunity_s81",
    "map_unknown": "p3_icon_map_unknown_s61",
    "map_war": "p3_icon_map_war_s62",
    "map_skip": "p3_icon_map_skip_s61",
    "opp_merchant": "p3_icon_opp_merchant_s61",
    "opp_refugee": "p3_icon_opp_refugee_s61",
    "opp_disaster": "p3_icon_opp_disaster_s61",
    "opp_treasure": "p3_icon_opp_treasure_s61",
    "era1": "p3_icon_era1_s62",
    "era2": "p3_icon_era2_s62",
    "era4": "p3_icon_era4_s62",
    "era5": "p3_icon_era5_s63",
    "fund": "p3_icon_fund_s61",
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

    # halo check: every glyph on dark and light (style bible §4), wrapped COLS per band
    cell, pad, cols = 260, 8, 10
    font = ImageFont.load_default(size=14)
    names = list(glyphs)
    bands = [names[i:i + cols] for i in range(0, len(names), cols)]
    band_h = cell * 2 + 24
    sheet = Image.new("RGB", (cell * cols, band_h * len(bands)), (24, 24, 24))
    d = ImageDraw.Draw(sheet)
    for b, band in enumerate(bands):
        for col, name in enumerate(band):
            t = glyphs[name].copy()
            t.thumbnail((cell - 2 * pad, cell - 2 * pad), Image.LANCZOS)
            for row, bg in enumerate([(20, 20, 30), (235, 235, 225)]):
                tile = Image.new("RGBA", (cell, cell), bg + (255,))
                tile.alpha_composite(t, ((cell - t.width) // 2, (cell - t.height) // 2))
                sheet.paste(tile.convert("RGB"), (col * cell, b * band_h + row * cell))
            d.text((col * cell + pad, b * band_h + cell * 2 + 4), name, fill=(220, 220, 220), font=font)
    sheet.save("../contact-sheets/phase3_icons_halo_check.png")
    print("wrote ../contact-sheets/phase3_icons_halo_check.png")


if __name__ == "__main__":
    main()
