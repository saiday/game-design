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
	# units class line-pick gate closed: every (line, era) in UNIT_COVERAGE is frozen on disk
	var total := 0
	for line_id: StringName in AssetPaths.UNIT_COVERAGE:
		for era: int in AssetPaths.UNIT_COVERAGE[line_id]:
			assert_bool(AssetPaths.has_unit(line_id, era)) \
				.override_failure_message("missing unit_%s_era%d" % [line_id, era]).is_true()
			total += 1
	assert_int(total).is_equal(69)


func test_infantry_era4_is_the_known_gap() -> void:
	# era-4 infantry render was §8-rejected with no sibling chain; the slot is intentionally unfrozen
	assert_bool(AssetPaths.has_unit(&"infantry", 4)).is_false()
	assert_bool(AssetPaths.UNIT_COVERAGE[&"infantry"].has(4)).is_false()


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


func test_card_infantry_era4_exists_unlike_the_unit_gap() -> void:
	# the infantry card was authored fresh (musket line), so era 4 IS frozen — unlike the unit sprite
	assert_bool(AssetPaths.has_card(&"infantry", 4)).is_true()


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
