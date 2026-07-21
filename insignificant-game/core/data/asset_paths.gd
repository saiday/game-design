class_name AssetPaths
extends RefCounted
# Approved-art registry (assets/pipeline/style-bible.md §9-§10 + assets/pipeline/manifest.jsonl).
# Pure data: id -> res:// path strings plus the frozen-template geometry measured at freeze time.
# Only manifest status=approved assets appear here; the view loads textures, core never does.
# Icon asset ids mirror assets/approved/icons/icon_<id>.png; canonical code ids (architecture.md)
# map through the icon_* helpers (policy &"centralization" -> icon asset &"policy_centralization").

const ICON_DIR: String = "res://assets/approved/icons"
const BUILDING_DIR: String = "res://assets/approved/buildings"
const UNIT_DIR: String = "res://assets/approved/units"
const UI_DIR: String = "res://assets/approved/ui"

# all 75 approved icon asset ids (inventory.md "UI icons")
const ICONS: Array[StringName] = [
	&"money", &"population", &"bp", &"tech", &"culture", &"happiness", &"debt", &"interest",
	&"unrest", &"power",
	&"attack", &"hp", &"military_cost",
	&"class_personnel", &"class_mechanical", &"class_fortification", &"class_skill",
	&"region_livelihood", &"region_academic", &"region_military", &"region_culture",
	&"region_finance",
	&"theme_power", &"theme_tech", &"theme_culture", &"theme_religion", &"theme_exploration",
	&"theme_recon",
	&"policy_centralization", &"policy_bureaucracy", &"policy_secret_police",
	&"policy_cultural_revolution", &"policy_enlightened_absolutism", &"policy_writing_calendar",
	&"policy_secularization", &"policy_patent_system", &"policy_moon_race",
	&"policy_space_station", &"policy_ancestor_worship", &"policy_state_religion",
	&"policy_theocracy", &"policy_holy_war", &"policy_hundred_schools", &"policy_mass_media",
	&"policy_cultural_export", &"policy_great_voyage", &"policy_world_map", &"policy_world_expo",
	&"policy_scout_camp", &"policy_political_marriage", &"policy_intelligence_agency",
	&"policy_satellite_surveillance",
	&"legacy_religious_dogma", &"legacy_rational_spirit", &"legacy_critical_spirit",
	&"legacy_rock_spirit", &"legacy_democratic_spirit", &"legacy_melting_pot",
	&"legacy_martial_law",
	&"map_battle", &"map_unknown", &"map_war", &"map_skip", &"map_opportunity",
	&"opp_merchant", &"opp_refugee", &"opp_disaster", &"opp_treasure",
	&"era1", &"era2", &"era3", &"era4", &"era5", &"era6",
	&"fund",
]

# Approved unit / enemy sprites: line -> eras frozen (line-pick gate 2026-07-21; the lineage
# picks live in assets/pipeline/phase3_units_freeze.py). infantry omits era 4 — a known gap: the
# era-4 render was §8-rejected with no sibling chain, so the view placeholders that one slot.
const UNIT_COVERAGE: Dictionary = {
	&"anti_air": [1, 2, 3, 4, 5, 6],
	&"archers": [1, 2, 3, 4, 5, 6],
	&"artillery": [3, 4, 5, 6],
	&"bomber": [4, 5, 6],
	&"cavalry": [1, 2, 3, 4, 5, 6],
	&"elite_forces": [2, 3, 4, 5, 6],
	&"enemy_hard": [1, 2, 3, 4, 5, 6],
	&"enemy_mid": [1, 2, 3, 4, 5, 6],
	&"enemy_weak": [1, 2, 3, 4, 5, 6],
	&"engineers": [1, 2, 3, 4, 5, 6],
	&"holy_warriors": [4],
	&"infantry": [1, 2, 3, 5, 6],
	&"privateers": [3, 4, 5],
	&"shield_wall": [1, 2, 3, 4, 5, 6],
}

# frozen UI templates (style bible §9): geometry is in each PNG's own pixels; scale in-engine.
const UI_PANEL: Dictionary = {
	"path": UI_DIR + "/ui_panel.png",
	"margins": {"left": 87, "top": 83, "right": 88, "bottom": 83},
	"min_size": Vector2i(178, 169),
}
const UI_BUTTON: Dictionary = {
	"path": UI_DIR + "/ui_button.png",
	"margins": {"left": 89, "top": 66, "right": 89, "bottom": 69},
	"min_size": Vector2i(181, 138),
}
const UI_CARD_FRAME: Dictionary = {
	"path": UI_DIR + "/ui_card_frame.png",
	"size": Vector2i(624, 920),
	"window": Rect2i(134, 108, 356, 421),      # transparent; illustration composites underneath
	"text_panel": Rect2i(77, 603, 468, 225),   # opaque parchment; Label text on top
}
const UI_ICON_PLATE: Dictionary = {
	"path": UI_DIR + "/ui_icon_plate.png",
	"size": Vector2i(788, 806),
	"disc": Rect2i(174, 170, 447, 455),        # glyphs composite inside it
	"glyph_fill": 0.78,                        # glyph extent as a fraction of the disc
}
const UI_DIVIDER: Dictionary = {
	"path": UI_DIR + "/ui_divider.png",
	"size": Vector2i(884, 24),
	"margins": {"left": 21, "right": 22},      # 3-slice: stretch the middle run only
}

const FONT_REGULAR: String = "res://assets/fonts/NotoSansTC-Regular.subset.otf"
const FONT_BOLD: String = "res://assets/fonts/NotoSansTC-Bold.subset.otf"


static func icon(icon_id: StringName) -> String:
	return "%s/icon_%s.png" % [ICON_DIR, icon_id]


static func icon_policy(node_id: StringName) -> String:
	return icon(StringName("policy_" + node_id))


static func icon_legacy(legacy_id: StringName) -> String:
	return icon(StringName("legacy_" + legacy_id))


static func icon_region(region_id: StringName) -> String:
	return icon(StringName("region_" + region_id))


static func icon_era(era: int) -> String:
	return icon(StringName("era%d" % era))


static func icon_opportunity(opp_id: StringName) -> String:
	# OpportunityData id -> icon asset id (the icon set names 國寶 "treasure")
	var asset_id: StringName = &"treasure" if opp_id == &"national_treasure" else opp_id
	return icon(StringName("opp_" + asset_id))


static func building(line: StringName, era: int) -> String:
	return "%s/building_%s_era%d.png" % [BUILDING_DIR, line, era]


static func has_building(line: StringName, era: int) -> bool:
	return FileAccess.file_exists(building(line, era))


static func unit(line: StringName, era: int) -> String:
	return "%s/unit_%s_era%d.png" % [UNIT_DIR, line, era]


static func has_unit(line: StringName, era: int) -> bool:
	return FileAccess.file_exists(unit(line, era))
