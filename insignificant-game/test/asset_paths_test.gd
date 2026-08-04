class_name AssetPathsTest
extends GdUnitTestSuite
# Registry ↔ disk contract: every id AssetPaths promises must resolve to a committed approved
# asset, and the frozen-template geometry must stay inside its texture bounds (style bible §9).


func test_every_icon_asset_exists() -> void:
	for icon_id: StringName in AssetPaths.ICONS:
		assert_bool(FileAccess.file_exists(AssetPaths.icon(icon_id))) \
			.override_failure_message("missing approved icon: %s" % AssetPaths.icon(icon_id)) \
			.is_true()


func test_icon_inventory_is_complete() -> void:
	assert_int(AssetPaths.ICONS.size()).is_equal(75)


func test_canonical_id_helpers_resolve() -> void:
	assert_bool(FileAccess.file_exists(AssetPaths.icon_policy(&"centralization"))).is_true()
	assert_bool(FileAccess.file_exists(AssetPaths.icon_legacy(&"martial_law"))).is_true()
	assert_bool(FileAccess.file_exists(AssetPaths.icon_region(&"finance"))).is_true()
	assert_bool(FileAccess.file_exists(AssetPaths.icon_era(6))).is_true()
	assert_bool(FileAccess.file_exists(AssetPaths.icon_opportunity(&"treasure"))).is_true()


func test_approved_building_lines_exist_per_era() -> void:
	# buildings class is closed: every line's era-form range (min_tier..6) plus the core
	# civilization center is frozen on disk
	for line_id: StringName in BuildingData.LINES:
		for era: int in range(int(BuildingData.LINES[line_id]["min_tier"]), 7):
			assert_bool(AssetPaths.has_building(line_id, era)) \
				.override_failure_message("missing building_%s_era%d" % [line_id, era]).is_true()
	for era: int in range(1, 7):
		assert_bool(AssetPaths.has_building(&"core", era)) \
			.override_failure_message("missing building_core_era%d" % era).is_true()


func test_approved_units_exist_per_coverage() -> void:
	# W14.8 top-down pick gate closed: every (line, era) in UNIT_COVERAGE is frozen on disk
	var total := 0
	for line_id: StringName in AssetPaths.UNIT_COVERAGE:
		for era: int in AssetPaths.UNIT_COVERAGE[line_id]:
			assert_bool(AssetPaths.has_unit(line_id, era)) \
				.override_failure_message("missing unit_%s_era%d" % [line_id, era]).is_true()
			total += 1
	assert_int(total).is_equal(67)


func test_infantry_era4_is_no_longer_a_gap() -> void:
	# the side-view round left this slot unfrozen (§8-rejected render, no sibling chain) and the
	# view placeholdered it; the top-down wording closed it, so no unit slot is placeholdered now
	assert_bool(AssetPaths.has_unit(&"infantry", 4)).is_true()
	assert_bool(AssetPaths.UNIT_COVERAGE[&"infantry"].has(4)).is_true()


func test_anti_air_eras_1_to_3_are_not_assets() -> void:
	# ADR-0006 retired 擋箭棚/箭樓/城防塔 outright — no air exists before 工業, so no anti-air does
	# either. These are absent by ruling, not by a pick gate that could still fill them.
	for era: int in [1, 2, 3]:
		assert_bool(AssetPaths.has_unit(&"anti_air", era)) \
			.override_failure_message("unit_anti_air_era%d should not exist" % era).is_false()
		assert_bool(AssetPaths.UNIT_COVERAGE[&"anti_air"].has(era)).is_false()


func test_approved_projectiles_exist() -> void:
	# the class the top-down camera created: one sprite per ammo type, shared across eras
	for ammo: StringName in AssetPaths.PROJECTILES:
		assert_bool(AssetPaths.has_projectile(ammo)) \
			.override_failure_message("missing proj_%s" % ammo).is_true()
	assert_int(AssetPaths.PROJECTILES.size()).is_equal(8)


func test_approved_scatter_exists_per_variant() -> void:
	# every approved cut is on disk: 19 props over 7 battle types, 53 sprites (inventory.md)
	var props := 0
	var sprites := 0
	for battle_type: StringName in AssetPaths.SCATTER:
		for prop: Dictionary in AssetPaths.SCATTER[battle_type]:
			props += 1
			for v: int in range(1, int(prop["variants"]) + 1):
				assert_bool(AssetPaths.has_scatter(prop["id"], v)) \
					.override_failure_message("missing %s_v%d" % [prop["id"], v]).is_true()
				sprites += 1
	assert_int(props).is_equal(19)
	assert_int(sprites).is_equal(53)


func test_scatter_covers_every_battle_type() -> void:
	# a battle type with no scatter row would draw bare ground (ADR-0009 left the plates empty)
	for battle_type: StringName in Battle.TYPES:
		assert_bool(AssetPaths.SCATTER.has(battle_type)) \
			.override_failure_message("no scatter roster for %s" % battle_type).is_true()


func test_scatter_barrier_profile_is_the_one_the_rules_read() -> void:
	# ADR-0010: the count of neutral cover a battle fields is one per barrier-carrying prop, read
	# off this table and nowhere else (decisions.md W14.9). 隱藏戰's zero is a design fact — that
	# ground gives you nothing to hide behind — so it is asserted, not tolerated.
	var expected := {
		&"tax_battle": 1, &"field_battle": 1, &"hidden_battle": 0, &"riot": 1,
		&"democracy_blood": 1, &"civil_war": 1, &"world_war": 2,
	}
	for battle_type: StringName in expected:
		assert_int(AssetPaths.scatter_barriers(battle_type)) \
			.override_failure_message("barrier count moved for %s" % battle_type) \
			.is_equal(expected[battle_type])
	for battle_type: StringName in AssetPaths.SCATTER:
		for prop: Dictionary in AssetPaths.SCATTER[battle_type]:
			assert_bool([&"none", &"weak", &"medium", &"hard"].has(prop["barrier"])) \
				.override_failure_message("unknown tier on %s" % prop["id"]).is_true()


func test_every_scene_has_its_own_backdrop() -> void:
	# style bible §11: three main scenes, each with its OWN plate and never a shared one — the
	# city panorama per era, the one route map, and a battlefield per battle type.
	for era: int in range(1, 7):
		assert_bool(FileAccess.file_exists(AssetPaths.background_city(era))) \
			.override_failure_message("missing bg_city_era%d" % era).is_true()
	for bg_id: StringName in [&"route_map", &"title", &"ending_survive", &"ending_collapse"]:
		assert_bool(AssetPaths.has_background(bg_id)) \
			.override_failure_message("missing bg_%s" % bg_id).is_true()


func test_battle_plates_cover_every_battle_type() -> void:
	# a battle type with no plate would open on nothing; the 7 types and the 7 plates are the
	# same list by design (design/戰鬥.md 戰鬥類型表 ↔ inventory.md §Backgrounds)
	for battle_type: StringName in Battle.TYPES:
		assert_bool(AssetPaths.BATTLE_PLATES.has(battle_type)) \
			.override_failure_message("no battle plate for %s" % battle_type).is_true()
		assert_bool(FileAccess.file_exists(AssetPaths.background_battle(battle_type))) \
			.override_failure_message("missing plate file for %s" % battle_type).is_true()
	assert_int(AssetPaths.BATTLE_PLATES.size()).is_equal(Battle.TYPES.size())


func test_approved_cards_exist_per_coverage() -> void:
	# cards class pick gate closed: every (line, era) in CARD_COVERAGE is frozen on disk (52 forms)
	var total := 0
	for line_id: StringName in AssetPaths.CARD_COVERAGE:
		for era: int in AssetPaths.CARD_COVERAGE[line_id]:
			assert_bool(AssetPaths.has_card(line_id, era)) \
				.override_failure_message("missing card_%s_era%d" % [line_id, era]).is_true()
			total += 1
	assert_int(total).is_equal(52)


func test_approved_skill_cards_exist() -> void:
	for skill_id: StringName in AssetPaths.CARD_SKILLS:
		assert_bool(AssetPaths.has_card_skill(skill_id)) \
			.override_failure_message("missing card_%s" % skill_id).is_true()
	assert_int(AssetPaths.CARD_SKILLS.size()).is_equal(5)


func test_card_and_unit_infantry_era4_now_agree() -> void:
	# the card was always frozen (authored fresh as a musket line); the sprite caught up in W14.8
	assert_bool(AssetPaths.has_card(&"infantry", 4)).is_true()
	assert_bool(AssetPaths.has_unit(&"infantry", 4)).is_true()


func test_approved_portrait_civs_exist_and_cover_every_rival_class() -> void:
	# portraits class closed: one full-frame portrait per rival class, registry list == RivalData.CLASSES
	for rival_class: StringName in AssetPaths.PORTRAIT_CIVS:
		assert_bool(FileAccess.file_exists(AssetPaths.portrait_civ(rival_class))) \
			.override_failure_message("missing portrait_civ_%s" % rival_class).is_true()
	assert_int(AssetPaths.PORTRAIT_CIVS.size()).is_equal(5)
	for rival_class: StringName in RivalData.CLASSES:
		assert_bool(AssetPaths.has_portrait_civ(rival_class)) \
			.override_failure_message("rival class %s has no portrait" % rival_class).is_true()


func test_approved_portrait_candidates_exist_and_cover_every_candidate() -> void:
	# one full-frame portrait per democracy candidate, registry list == CandidateData.CANDIDATES
	for candidate_id: StringName in AssetPaths.PORTRAIT_CANDIDATES:
		assert_bool(FileAccess.file_exists(AssetPaths.portrait_candidate(candidate_id))) \
			.override_failure_message("missing portrait_candidate_%s" % candidate_id).is_true()
	assert_int(AssetPaths.PORTRAIT_CANDIDATES.size()).is_equal(10)
	for candidate_id: StringName in CandidateData.CANDIDATES:
		assert_bool(AssetPaths.has_portrait_candidate(candidate_id)) \
			.override_failure_message("candidate %s has no portrait" % candidate_id).is_true()


func test_ui_templates_exist() -> void:
	for tpl: Dictionary in [AssetPaths.UI_PANEL, AssetPaths.UI_BUTTON, AssetPaths.UI_CARD_FRAME,
			AssetPaths.UI_ICON_PLATE, AssetPaths.UI_DIVIDER]:
		assert_bool(FileAccess.file_exists(String(tpl["path"]))) \
			.override_failure_message("missing template: %s" % tpl["path"]).is_true()


func test_fonts_exist() -> void:
	assert_bool(FileAccess.file_exists(AssetPaths.FONT_REGULAR)).is_true()
	assert_bool(FileAccess.file_exists(AssetPaths.FONT_BOLD)).is_true()


func test_template_geometry_inside_texture_bounds() -> void:
	var frame_size := AssetPaths.UI_CARD_FRAME["size"] as Vector2i
	var frame_rect := Rect2i(Vector2i.ZERO, frame_size)
	assert_bool(frame_rect.encloses(AssetPaths.UI_CARD_FRAME["window"] as Rect2i)).is_true()
	assert_bool(frame_rect.encloses(AssetPaths.UI_CARD_FRAME["text_panel"] as Rect2i)).is_true()
	var plate_rect := Rect2i(Vector2i.ZERO, AssetPaths.UI_ICON_PLATE["size"] as Vector2i)
	assert_bool(plate_rect.encloses(AssetPaths.UI_ICON_PLATE["disc"] as Rect2i)).is_true()
