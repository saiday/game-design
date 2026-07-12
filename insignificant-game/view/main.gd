extends Control
# Insignificant PoC view: one panel per phase (operate / route / battle / opportunity /
# settle / world war / democracy / ending). Chrome is composed at RUNTIME from the frozen
# approved templates + icon glyphs in core/data/asset_paths.gd (style bible §9): NinePatch-style
# styleboxes, glyph-on-plate badges, card frame with live Label text — never baked together.
# The view computes NOTHING — every rule call goes through core/.
# Demo mode (INSIG_DEMO=1): simulates the same click handlers, captures a PNG per phase
# into captures/, prints ASSERT PASS/FAIL lines, then quits (Part B of the loop).

const BG_COLOR := Color(0.10, 0.11, 0.13)
const PANEL_COLOR := Color(0.18, 0.20, 0.24)
const ACCENT_COLOR := Color(0.85, 0.72, 0.35)
const CHROME_SCALE := 0.5   # frozen templates render at half source scale (in-engine scaling, §8)
const STAT_ICON := 28       # inline stat glyph size (px)
const INK_COLOR := Color(0.20, 0.13, 0.08)         # body text on parchment chrome
const INK_ACCENT_COLOR := Color(0.55, 0.16, 0.10)  # accent text on parchment chrome

var _texture_cache: Dictionary = {}

var state: GameState
var nodes: Array[Dictionary] = []
var battle: Battle.BattleField = null
var current_opportunity: StringName = &""
var demo_failures: int = 0

var stats_label: RichTextLabel
var danger_label: RichTextLabel
var phase_title: Label
var event_label: Label
var panels: Dictionary = {}
var operate_actions: VBoxContainer
var route_actions: VBoxContainer
var battle_info: Label
var battle_spend: Label
var battle_hand: VBoxContainer
var battle_buttons: HBoxContainer
var opportunity_label: Label
var opportunity_actions: VBoxContainer
var opportunity_card_art: TextureRect
var opportunity_card_text: Label
var settle_label: Label
var ww_label: Label
var democracy_label: Label
var democracy_actions: VBoxContainer
var ending_label: Label


func _ready() -> void:
	_build_ui()
	_start_run()
	if OS.get_environment("INSIG_DEMO") == "1":
		_run_demo.call_deferred()


# ---------- run flow (shared by clicks and demo) ----------

func _start_run() -> void:
	var seed_value: int = 1
	if OS.get_environment("INSIG_SEED") != "":
		seed_value = int(OS.get_environment("INSIG_SEED"))
	state = GameState.new_run(seed_value)
	Rivals.setup(state)
	Cards.starting_deck(state)
	_begin_generation()


func _begin_generation() -> void:
	var report := Turn.begin_generation(state)
	if report.has("world_war"):
		phase_title.text = "世界大戰"
		var result := Turn.run_world_war(state)
		var camp_line: String = "我方陣營: %s\n敵方陣營: %s" % [
			", ".join(_civ_names(result["player_camp"])), ", ".join(_civ_names(result["enemy_camp"]))]
		ww_label.text = "第 %d 代 — 世界大戰（整代覆寫）\n%s\n勝方: %s\n賠款池: %d\n我方收付: %s" % [
			int(result["generation"]), camp_line,
			"我方" if bool(result["player_won"]) else "敵方",
			int(result["pool"]),
			str((result["payouts"] as Dictionary).get(&"player", -(result["reparations"] as Dictionary).get(&"player", 0)))]
		_show_panel(&"world_war")
	elif report.has("democracy"):
		_refresh_democracy()
		_show_panel(&"democracy")
	else:
		_refresh_operate()
		_show_panel(&"operate")
	_refresh_stats()


func _end_operate() -> void:
	Operations.end_operate_phase(state)
	nodes = Turn.route(state)
	_refresh_route()
	_show_panel(&"route")
	_refresh_stats()


func _enter_node(index: int) -> void:
	var node: Dictionary = nodes[index]
	if node["content"] == &"opportunity":
		current_opportunity = MapNodes.roll_opportunity(state)
		_refresh_opportunity()
		_show_panel(&"opportunity")
	else:
		battle = Battle.start(
			state, node["battle_type"], node.get("rival_id", &""),
			bool(node.get("player_declared", false)), bool(node.get("surprise", false)))
		_refresh_battle()
		_show_panel(&"battle")
	_refresh_stats()


func _resolve_opportunity(choice: StringName) -> void:
	var report := MapNodes.resolve_opportunity(state, current_opportunity, choice)
	event_label.text = "機會: %s → %s" % [current_opportunity, str(report)]
	_settle()


func _battle_play(hand_index: int) -> void:
	Battle.play_card(state, battle, hand_index)
	_refresh_battle()
	_refresh_stats()


func _battle_end_round() -> void:
	Battle.end_round(state, battle)
	if battle.outcome != &"":
		_finish_battle()
	else:
		_refresh_battle()
	_refresh_stats()


func _finish_battle() -> void:
	var report := Battle.finish(state, battle)
	if report.has("reward_card") and state.flags.has(&"pending_reward_card"):
		Cards.add_reward_card(state, state.flags[&"pending_reward_card"])
		state.flags.erase(&"pending_reward_card")
	event_label.text = "戰鬥結束: %s（軍費 %d／戰功 %d）" % [battle.outcome, battle.spent, battle.merit]
	battle = null
	_settle()


func _settle() -> void:
	if Turn.roll_unrest_battle(state):
		if Unrest.use_martial_law(state):
			event_label.text += "｜戒嚴動用：內亂戰閃避"
		elif state.treasury >= Unrest.concession_cost(state):
			Unrest.apply_concession(state)
			event_label.text += "｜讓步：內亂戰取消"
		else:
			battle = Battle.start(state, &"riot")
			_refresh_battle()
			_show_panel(&"battle")
			return
	phase_title.text = "結算"
	var report := Turn.settle(state)
	var economy: Dictionary = report["economy"]
	settle_label.text = "第 %d 代結算\n稅收 +%d｜資本利得 +%d｜利息 −%d\n國庫: %d" % [
		state.generation - 1, int(economy["tax"]), int(economy["capital_gains"]),
		int(economy["interest"]), state.treasury]
	var ending: Dictionary = report["ending"]
	if bool(ending["over"]):
		_show_ending(ending)
	else:
		_show_panel(&"settle")
	_refresh_stats()


func _show_ending(ending: Dictionary) -> void:
	phase_title.text = "結局"
	var head: String = {&"collapse": "政權崩潰", &"total_victory": "提前完全勝利", &"survived": "走到最後（第 %d 名）" % int(ending.get("rank", 0))}[ending["kind"]]
	ending_label.text = "%s\n\n%s" % [head, String(ending["epilogue"])]
	_show_panel(&"ending")


# ---------- panel refresh ----------

func _refresh_stats() -> void:
	stats_label.text = "%s 第 %d 代（%s） %s %d %s %d %s %d %s %d %s %d %s %d" % [
		_stat_img(AssetPaths.icon_era(Era.index(state.generation))), state.generation, Era.of(state.generation),
		_stat_img(AssetPaths.icon(&"population")), state.population,
		_stat_img(AssetPaths.icon(&"happiness")), state.happiness,
		_stat_img(AssetPaths.icon(&"culture")), state.culture,
		_stat_img(AssetPaths.icon(&"tech")), state.tech,
		_stat_img(AssetPaths.icon(&"money")), state.treasury,
		_stat_img(AssetPaths.icon(&"bp")), state.bp]
	var danger := Ending.danger_panel(state)
	danger_label.text = "%s 債務 %d｜%s 利息/代 %d｜%s 內亂權重 %d%%｜%s 人口距崩潰 %d" % [
		_stat_img(AssetPaths.icon(&"debt")), int(danger["debt"]),
		_stat_img(AssetPaths.icon(&"interest")), int(danger["interest_per_gen"]),
		_stat_img(AssetPaths.icon(&"unrest")), int(round(float(danger["unrest_weight"]) * 100.0)),
		_stat_img(AssetPaths.icon(&"population")), state.population - int(danger["collapse_threshold"])]


func _stat_img(path: String) -> String:
	return "[img=%d]%s[/img]" % [STAT_ICON, path]


func _refresh_operate() -> void:
	_clear(operate_actions)
	phase_title.text = "營運相位"
	for step: Array in Sim.BUILD_ORDER:
		if operate_actions.get_child_count() >= 6:
			break
		var kind: StringName = step[0]
		var target: StringName = step[1]
		if kind == &"region" and not state.regions.has(target):
			_add_button(operate_actions, "建區域 %s（%d 錢＋1BP）" % [BuildingData.REGIONS[target]["zh"], Operations.region_cost(state)],
				func() -> void:
					Operations.build_region(state, target)
					_refresh_operate()
					_refresh_stats())
		elif kind == &"building" and not state.buildings.has(target) \
				and state.regions.has(BuildingData.LINES[target]["region"]):
			_add_button(operate_actions, "蓋 %s（%d 錢＋1BP）" % [BuildingData.LINES[target]["zh"], Operations.building_cost(state, target)],
				func() -> void:
					Operations.build_building(state, target)
					_refresh_operate()
					_refresh_stats())
	var open := Policy.available(state)
	if not open.is_empty() and state.bp >= 2:
		var target_policy: StringName = state.policy_in_progress if state.policy_in_progress != &"" else open[0]
		_add_button(operate_actions, "推國策 %s（鎖 1 BP，%d/%d）" % [target_policy, Policy.progress(state, target_policy), int(PolicyNodes.NODES[target_policy]["cost_bp"])],
			func() -> void:
				Policy.invest(state, target_policy, 1)
				_refresh_operate()
				_refresh_stats())
	_add_button(operate_actions, "結束營運相位 → 選路", _end_operate)


func _refresh_route() -> void:
	_clear(route_actions)
	phase_title.text = "選路"
	for i: int in range(nodes.size()):
		var node: Dictionary = nodes[i]
		var face: String = "?"
		var badge: StringName = &"map_unknown"
		if node["kind"] == &"known" or bool(node["face_shown"]):
			if node["content"] == &"battle":
				face = "戰鬥(%s)" % node["battle_type"]
				badge = &"map_battle"
			else:
				face = "機會"
				badge = &""   # no dedicated map-opportunity glyph in the icon set (flagged)
		var index := i
		_add_button(route_actions, "節點 %d：%s／%s" % [i + 1, node["kind"], face],
			func() -> void: _enter_node(index), badge)
	var skip_action := func() -> void:
		MapNodes.skip_node(state)
		_settle()
	_add_button(route_actions, "付錢略過（%d）→ 結算" % MapNodes.skip_cost(state), skip_action, &"map_skip")


func _refresh_battle() -> void:
	phase_title.text = "戰鬥"
	var enemy_lines: Array[String] = []
	for unit: Dictionary in battle.enemy_units:
		enemy_lines.append("敵 %s 攻%d/血%d" % [unit.get("grade", &"?"), int(unit["attack"]), int(unit["hp"])])
	var our_lines: Array[String] = []
	for unit: Dictionary in battle.player_units:
		our_lines.append("我 %s 攻%d/血%d" % [Cards.card(unit["card_id"])["zh"] if unit["card_id"] != &"test" else "單位", int(unit["attack"]), int(unit["hp"])])
	var intel: String = "情報：可見敵方牌池" if battle.intel_visible else "情報：盲打（當代未覆蓋）"
	battle_info.text = "%s 第 %d/%d 回合｜%s\n%s\n%s" % [
		battle.battle_type, battle.round, battle.round_cap, intel,
		"　".join(enemy_lines) if not enemy_lines.is_empty() else "（敵方已清空）",
		"　".join(our_lines) if not our_lines.is_empty() else "（我方未部署）"]
	battle_spend.text = "本場已燒軍費 %d ｜ 預期賠償 %d" % [battle.spent, battle.expected_reward]
	_clear(battle_hand)
	for i: int in range(battle.hand.size()):
		var instance: Cards.CardInstance = battle.hand[i]
		var index := i
		_add_button(battle_hand, "出牌 %s（軍費 %d）" % [Cards.form_name(instance.id, instance.tier), Battle.card_cost(state, battle, instance)],
			func() -> void: _battle_play(index))
	_clear(battle_buttons)
	if Battle.can_defect(state, battle):
		_add_button(battle_buttons, "投誠（免軍費勝）", func() -> void:
			Battle.defect(state, battle)
			_finish_battle())
	_add_button(battle_buttons, "結束回合", _battle_end_round)
	_add_button(battle_buttons, "撤軍（%d 錢，+2 人口）" % (10 * Era.coeff(state.generation)), func() -> void:
		Battle.retreat(state, battle)
		_finish_battle())


func _refresh_opportunity() -> void:
	phase_title.text = "機會事件"
	var entry: Dictionary = OpportunityData.TABLE[current_opportunity]
	opportunity_label.text = "%s" % entry["label"]
	opportunity_card_art.texture = load(AssetPaths.icon_opportunity(current_opportunity)) as Texture2D
	opportunity_card_text.text = String(entry["label"])
	_clear(opportunity_actions)
	for choice: StringName in MapNodes.opportunity_choices(current_opportunity):
		var picked := choice
		_add_button(opportunity_actions, String(picked), func() -> void: _resolve_opportunity(picked))


func _refresh_democracy() -> void:
	phase_title.text = "民主（自動營運）"
	var lines: Array[String] = ["現任：%s" % (CandidateData.CANDIDATES[state.incumbent]["zh"] if state.incumbent != &"" else "—")]
	if state.incumbent != &"":
		lines.append("「%s」" % CandidateData.CANDIDATES[state.incumbent]["copy"])
	lines.append("連任機率 %d%%" % int(round(Democracy.reelection_chance(state) * 100.0)))
	democracy_label.text = "\n".join(lines)
	_clear(democracy_actions)
	for candidate_id: StringName in Democracy.top_three(state):
		var picked := candidate_id
		_add_button(democracy_actions, "金援 %s（50 錢，+10%%）" % CandidateData.CANDIDATES[picked]["zh"],
			func() -> void:
				Democracy.fund(state, picked)
				_refresh_democracy()
				_refresh_stats())
	_add_button(democracy_actions, "看國家自動運轉 → 結算", func() -> void:
		Democracy.generation_step(state)
		_settle())


# ---------- UI scaffolding ----------

func _build_ui() -> void:
	theme = _build_theme()
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24.0
	root.offset_top = 16.0
	root.offset_right = -24.0
	root.offset_bottom = -16.0
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	stats_label = _rich_label(root, 20)
	danger_label = _rich_label(root, 17)
	danger_label.modulate = ACCENT_COLOR
	_divider(root)
	phase_title = _label(root, 30)
	phase_title.add_theme_font_override("font", load(AssetPaths.FONT_BOLD) as FontFile)
	event_label = _label(root, 15)
	panels[&"operate"] = _panel(root)
	operate_actions = _vbox(panels[&"operate"])
	panels[&"route"] = _panel(root)
	route_actions = _vbox(panels[&"route"])
	panels[&"battle"] = _panel(root)
	var battle_box := _vbox(panels[&"battle"])
	battle_info = _panel_label(battle_box, 16)
	battle_spend = _panel_label(battle_box, 18)
	battle_spend.add_theme_color_override("font_color", INK_ACCENT_COLOR)
	battle_hand = VBoxContainer.new()
	battle_box.add_child(battle_hand)
	battle_buttons = HBoxContainer.new()
	battle_box.add_child(battle_buttons)
	panels[&"opportunity"] = _panel(root)
	var opp_split := HBoxContainer.new()
	opp_split.add_theme_constant_override("separation", 28)
	panels[&"opportunity"].add_child(opp_split)
	opp_split.add_child(_build_opportunity_card())
	var opp_box := VBoxContainer.new()
	opp_box.add_theme_constant_override("separation", 6)
	opp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp_split.add_child(opp_box)
	opportunity_label = _panel_label(opp_box, 20)
	opportunity_actions = VBoxContainer.new()
	opp_box.add_child(opportunity_actions)
	panels[&"settle"] = _panel(root)
	var settle_box := _vbox(panels[&"settle"])
	settle_label = _panel_label(settle_box, 18)
	_add_button(settle_box, "進入下一代", _begin_generation)
	panels[&"world_war"] = _panel(root)
	var ww_box := _vbox(panels[&"world_war"])
	ww_label = _panel_label(ww_box, 18)
	_add_button(ww_box, "結算 → 下一代", func() -> void: _settle())
	panels[&"democracy"] = _panel(root)
	var demo_box := _vbox(panels[&"democracy"])
	democracy_label = _panel_label(demo_box, 18)
	democracy_actions = VBoxContainer.new()
	demo_box.add_child(democracy_actions)
	panels[&"ending"] = _panel(root)
	var ending_box := _vbox(panels[&"ending"])
	ending_label = _panel_label(ending_box, 19)
	_add_button(ending_box, "再來一局", func() -> void: _start_run())


# ---------- approved-art chrome helpers (style bible §9; scaled in-engine, never re-baked) ----------

func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load(AssetPaths.FONT_REGULAR) as FontFile
	t.default_font_size = 18
	return t


func _scaled_texture(path: String, scale: float) -> ImageTexture:
	var key := "%s@%f" % [path, scale]
	if not _texture_cache.has(key):
		var image := _image(path)
		image.resize(int(image.get_width() * scale), int(image.get_height() * scale),
			Image.INTERPOLATE_LANCZOS)
		_texture_cache[key] = ImageTexture.create_from_image(image)
	return _texture_cache[key]


func _image(path: String) -> Image:
	var image: Image = (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	return image


func _chrome_stylebox(tpl: Dictionary, modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _scaled_texture(String(tpl["path"]), CHROME_SCALE)
	var margins: Dictionary = tpl["margins"]
	style.texture_margin_left = float(margins["left"]) * CHROME_SCALE
	style.texture_margin_top = float(margins["top"]) * CHROME_SCALE
	style.texture_margin_right = float(margins["right"]) * CHROME_SCALE
	style.texture_margin_bottom = float(margins["bottom"]) * CHROME_SCALE
	style.content_margin_left = style.texture_margin_left * 0.8
	style.content_margin_top = style.texture_margin_top * 0.8
	style.content_margin_right = style.texture_margin_right * 0.8
	style.content_margin_bottom = style.texture_margin_bottom * 0.8
	style.modulate_color = modulate_color
	return style


func _plate_icon(icon_path: String, size: int) -> ImageTexture:
	# glyph composited into the frozen plate's disc rect at runtime (style bible §9)
	var key := "plate:%s@%d" % [icon_path, size]
	if _texture_cache.has(key):
		return _texture_cache[key]
	var plate := _image(String(AssetPaths.UI_ICON_PLATE["path"]))
	var glyph := _image(icon_path)
	var disc: Rect2i = AssetPaths.UI_ICON_PLATE["disc"]
	var fill := float(AssetPaths.UI_ICON_PLATE["glyph_fill"])
	var box := Vector2(disc.size) * fill
	var glyph_scale: float = minf(box.x / glyph.get_width(), box.y / glyph.get_height())
	glyph.resize(int(glyph.get_width() * glyph_scale), int(glyph.get_height() * glyph_scale),
		Image.INTERPOLATE_LANCZOS)
	var at := disc.position + (disc.size - Vector2i(glyph.get_width(), glyph.get_height())) / 2
	plate.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), at)
	plate.resize(int(round(float(size) * plate.get_width() / plate.get_height())), size,
		Image.INTERPOLATE_LANCZOS)
	_texture_cache[key] = ImageTexture.create_from_image(plate)
	return _texture_cache[key]


func _build_opportunity_card() -> Control:
	# live card composition (style bible §9): art UNDER the frame's transparent window,
	# Label text OVER the parchment text panel — three layers, composed here, never baked.
	var frame_size := Vector2(AssetPaths.UI_CARD_FRAME["size"] as Vector2i) * CHROME_SCALE
	var card := Control.new()
	card.custom_minimum_size = frame_size
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var window: Rect2i = AssetPaths.UI_CARD_FRAME["window"]
	opportunity_card_art = TextureRect.new()
	opportunity_card_art.position = Vector2(window.position) * CHROME_SCALE
	opportunity_card_art.size = Vector2(window.size) * CHROME_SCALE
	opportunity_card_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	opportunity_card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(opportunity_card_art)
	var frame := TextureRect.new()
	frame.texture = _scaled_texture(String(AssetPaths.UI_CARD_FRAME["path"]), CHROME_SCALE)
	frame.size = frame_size
	card.add_child(frame)
	var text_panel: Rect2i = AssetPaths.UI_CARD_FRAME["text_panel"]
	opportunity_card_text = Label.new()
	opportunity_card_text.position = Vector2(text_panel.position) * CHROME_SCALE + Vector2(10, 8)
	opportunity_card_text.size = Vector2(text_panel.size) * CHROME_SCALE - Vector2(20, 16)
	opportunity_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	opportunity_card_text.add_theme_color_override("font_color", Color(0.20, 0.13, 0.08))
	opportunity_card_text.add_theme_font_size_override("font_size", 18)
	card.add_child(opportunity_card_text)
	return card


func _divider(parent: Control) -> void:
	var rule := NinePatchRect.new()
	rule.texture = load(String(AssetPaths.UI_DIVIDER["path"])) as Texture2D
	var margins: Dictionary = AssetPaths.UI_DIVIDER["margins"]
	rule.patch_margin_left = int(margins["left"])
	rule.patch_margin_right = int(margins["right"])
	rule.custom_minimum_size = Vector2(0, (AssetPaths.UI_DIVIDER["size"] as Vector2i).y)
	parent.add_child(rule)


func _panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _chrome_stylebox(AssetPaths.UI_PANEL))
	panel.visible = false
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	return panel


func _vbox(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	parent.add_child(box)
	return box


func _label(parent: Control, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _panel_label(parent: Control, size: int) -> Label:
	# labels living INSIDE parchment panels read in ink, not the on-dark default white
	var label := _label(parent, size)
	label.add_theme_color_override("font_color", INK_COLOR)
	return label


func _rich_label(parent: Control, size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", size)
	parent.add_child(label)
	return label


func _add_button(parent: Control, text: String, handler: Callable, icon_id: StringName = &"") -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_stylebox_override("normal", _chrome_stylebox(AssetPaths.UI_BUTTON))
	button.add_theme_stylebox_override("hover", _chrome_stylebox(AssetPaths.UI_BUTTON, Color(1.08, 1.08, 1.02)))
	button.add_theme_stylebox_override("pressed", _chrome_stylebox(AssetPaths.UI_BUTTON, Color(0.78, 0.78, 0.82)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.16, 0.11, 0.07))
	button.add_theme_color_override("font_hover_color", Color(0.10, 0.06, 0.03))
	button.add_theme_color_override("font_pressed_color", Color(0.16, 0.11, 0.07))
	if icon_id != &"":
		button.icon = _plate_icon(AssetPaths.icon(icon_id), 44)
		button.add_theme_constant_override("h_separation", 10)
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func _clear(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _show_panel(name: StringName) -> void:
	for key: StringName in panels.keys():
		(panels[key] as Control).visible = key == name


func _civ_names(camp: Array) -> Array[String]:
	var out: Array[String] = []
	for civ_id: StringName in camp:
		if civ_id == &"player":
			out.append("你")
		else:
			out.append(Rivals.find(state, civ_id).display_name)
	return out


# ---------- Part B demo: simulated clicks + captures + ASSERTs ----------

func _run_demo() -> void:
	var watchdog := get_tree().create_timer(45.0)
	watchdog.timeout.connect(func() -> void:
		print("ASSERT FAIL: demo watchdog expired")
		get_tree().quit(1))
	await _capture(&"operate", "operate panel with action buttons")
	_assert(operate_actions.get_child_count() >= 2, "operate panel offers actions")
	# click the first build action, then end the phase
	(operate_actions.get_child(0) as Button).pressed.emit()
	await _capture(&"operate_after_click", "operate after one build click")
	_assert(state.buildings_built + state.regions.size() >= 1, "click actually built something")
	_end_operate()
	await _capture(&"route", "route panel with node buttons")
	_assert(route_actions.get_child_count() >= 2, "route panel lists nodes + skip")
	(route_actions.get_child(0) as Button).pressed.emit()
	if battle != null:
		await _capture(&"battle", "battle panel")
		_assert(battle_spend.text.contains("軍費"), "spend-vs-reward line visible")
		var guard: int = 0
		while battle != null and battle.outcome == &"" and guard < 20:
			guard += 1
			if battle_hand.get_child_count() > 0:
				(battle_hand.get_child(0) as Button).pressed.emit()
			_battle_end_round()
	else:
		await _capture(&"opportunity", "opportunity panel")
		(opportunity_actions.get_child(0) as Button).pressed.emit()
	if battle != null and panels[&"battle"].visible:
		Battle.retreat(state, battle)   # riot battle fallback so the demo always advances
		_finish_battle()
	await _capture(&"settle", "settle panel")
	_assert(settle_label.text.contains("結算"), "settle summary visible")
	# world war block (jump the clock)
	state.generation = 15
	_begin_generation()
	await _capture(&"world_war", "world war panel")
	_assert(ww_label.text.contains("世界大戰"), "world war summary visible")
	_settle()
	# democracy block
	state.culture = maxi(state.culture, 25)
	Democracy.enter(state, true)
	_begin_generation()
	await _capture(&"democracy", "democracy panel")
	_assert(democracy_label.text.contains("現任"), "democracy incumbent visible")
	# ending block
	state.generation = Era.FINAL_GENERATION + 1
	_show_ending(Ending.check(state))
	await _capture(&"ending", "ending panel")
	_assert(ending_label.text.length() > 20, "epilogue text visible")
	_assert_pixels()
	print("DEMO DONE: %d assert failures" % demo_failures)
	get_tree().quit(0 if demo_failures == 0 else 1)


func _capture(tag: StringName, description: String) -> void:
	_refresh_stats()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "res://captures/w5_%s.png" % tag
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE %s -> %s" % [description, path])
	var visible_panel: StringName = &""
	for key: StringName in panels.keys():
		if (panels[key] as Control).visible:
			visible_panel = key
	_assert(visible_panel == tag or String(tag).begins_with(String(visible_panel)), "panel '%s' is the visible block" % tag)
	_assert(stats_label.text.length() > 10, "stats bar populated")
	_assert(danger_label.text.contains("內亂權重"), "danger panel always on screen")
	var rect := get_viewport_rect()
	_assert(rect.encloses(stats_label.get_global_rect()), "stats bar inside viewport")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("ASSERT PASS: %s" % message)
	else:
		demo_failures += 1
		print("ASSERT FAIL: %s" % message)


func _assert_pixels() -> void:
	# Gamma-tolerant classification (MEMORY.md): sample corners vs panel area.
	var image := get_viewport().get_texture().get_image()
	var corner := image.get_pixel(4, image.get_height() - 4)
	_assert(_closer_to(corner, BG_COLOR, PANEL_COLOR), "background pixel classifies as BG")


func _closer_to(sample: Color, target: Color, other: Color) -> bool:
	return _dist(sample, target) < _dist(sample, other)


func _dist(a: Color, b: Color) -> float:
	return (a.r - b.r) * (a.r - b.r) + (a.g - b.g) * (a.g - b.g) + (a.b - b.b) * (a.b - b.b)
