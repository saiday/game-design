class_name CityScene
extends Control
# 營運＝活的城市全景 (design/營運.md §場景呈現, style bible §11). The operate phase's picture IS the
# city: a side-view panorama on the era's own plate, with every built line standing in it at its own
# tier's era form and 政權核心 anchored mid-frame. A build or an upgrade swaps a texture by id and
# the skyline changes under the player — the view restyles nothing and computes nothing.
#
# The camera here stays side-view on purpose: only the battlefield went top-down (ADR-0009).
#
# Commands live in a **collapsible dock, bottom-right** (建設選單是收合式指令盤，不佔畫面主體):
# clicking the panorama or pressing cancel folds it away so the city is the screen. Every control in
# it is focus-navigable, because the game must be playable on a pad.

signal state_changed        # something was spent or built: the HUD is stale
signal operate_finished     # 結束營運相位 → 選路

const GROUND_Y: float = 0.80          # skyline baseline, as a fraction of scene height
const CORE_HEIGHT: float = 260.0      # 政權核心 stands tallest — it is the middle of the town
const LINE_HEIGHT_BASE: float = 130.0
const LINE_HEIGHT_PER_TIER: float = 16.0
const DOCK_WIDTH: float = 620.0
const DOCK_HEIGHT: float = 660.0   # 不佔畫面主體: the city keeps the left two thirds of the frame
const TABS: Array[StringName] = [&"build", &"deck", &"world"]
const TAB_NAMES: Array[String] = ["建設", "部隊", "外交"]

# 一代＝一日 (營運.md): an in-engine grade over the era plate, never separate art per slot.
const DAYLIGHT: Dictionary = {
	&"morning": Color(1.0, 0.94, 0.80, 0.10),
	&"midday": Color(1.0, 1.0, 1.0, 0.0),
	&"dusk": Color(0.95, 0.55, 0.25, 0.22),
	&"night": Color(0.10, 0.14, 0.35, 0.38),
}

var _chrome: Chrome
var _state: GameState
var _backdrop: TextureRect
var _grade: ColorRect
var _skyline: Control
var _dock: PanelContainer
var _dock_tabs: HBoxContainer
var _dock_body: VBoxContainer
var _dock_handle: Button
var _end_phase: Button
var _tab: StringName = &"build"
var _dock_wanted: bool = true     # the player's fold state, remembered across phases
var _commands_on: bool = true     # whether this phase offers commands at all


func setup(chrome: Chrome) -> void:
	_chrome = chrome
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# 點背景收合指令盤 (controller: the cancel button, handled in _unhandled_input)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	add_child(_backdrop)
	_grade = ColorRect.new()
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.color = DAYLIGHT[&"morning"]
	add_child(_grade)
	_skyline = Control.new()
	_skyline.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skyline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_skyline)
	_build_dock()


func set_time_of_day(slot: StringName) -> void:
	_grade.color = DAYLIGHT[slot]


func refresh(state: GameState) -> void:
	_state = state
	_backdrop.texture = _chrome.texture(AssetPaths.background_city(Era.index(state.generation)))
	_draw_skyline()
	_fill_dock()


func dock_open() -> bool:
	return _dock.visible


func set_commands_visible(on: bool) -> void:
	# The dock belongs to the operate phase. Off-phase the panorama stays, the commands don't.
	_commands_on = on
	_dock.visible = on and _dock_wanted
	_dock_handle.visible = on and not _dock_wanted


func end_phase_reachable() -> bool:
	# Not "does it exist" but "can the player see it": it must lie inside the dock's own rect, which
	# is what a scrolled-off button fails. Part B asserts this on the longest action list there is.
	return _end_phase.visible and _dock.get_global_rect().encloses(_end_phase.get_global_rect())


func dock_action_enabled(needle: String) -> bool:
	return _find_enabled_in(_dock_body, needle) != null


func press_dock_action(needle: String = "") -> bool:
	# Part B reaches the dock through this rather than by walking the scene tree, so the demo
	# clicks what a player clicks and never trips over the tab strip or the fold handle.
	return _press_first_in(_dock_body, needle)


func toggle_dock() -> void:
	if not _commands_on:
		return
	_dock_wanted = not _dock_wanted
	set_commands_visible(true)
	if _dock_wanted:
		_focus_first_in(_dock_body)
	else:
		_dock_handle.grab_focus()


func focus_dock() -> void:
	if _dock.visible:
		_focus_first_in(_dock_body)


func skyline_count() -> int:
	return _skyline.get_child_count()


func dock_action_count() -> int:
	return _dock_body.get_child_count()


func open_tab(tab: StringName) -> void:
	_tab = tab
	if _state != null:
		_fill_dock()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel"):
		toggle_dock()
		accept_event()


# --- the panorama ---

func _draw_skyline() -> void:
	# 每條已建線以自身階數的時代形態立於全景中，政權核心居中 (營運.md). Deterministic order:
	# the built lines in table order, split evenly around the core, all standing on one ground line.
	for child: Node in _skyline.get_children():
		_skyline.remove_child(child)
		child.queue_free()
	var built: Array[StringName] = []
	for line_id: StringName in BuildingData.LINES:
		if _state.buildings.has(line_id):
			built.append(line_id)
	var era: int = Era.index(_state.generation)
	@warning_ignore("integer_division")
	var left: int = built.size() / 2
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 10)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The town stands ON the ground line, not on the bottom edge, so the plate's foreground stays
	# visible under it. Anchored as a fraction of the scene, so nothing here reads `size` before
	# the first layout pass has given it one.
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = GROUND_Y
	strip.anchor_bottom = GROUND_Y
	strip.offset_top = -CORE_HEIGHT
	strip.offset_bottom = 0.0
	_skyline.add_child(strip)
	for i: int in range(left):
		strip.add_child(_line_sprite(built[i], int(_state.buildings[built[i]])))
	strip.add_child(_sprite(AssetPaths.building(&"core", era), CORE_HEIGHT))
	for i: int in range(left, built.size()):
		strip.add_child(_line_sprite(built[i], int(_state.buildings[built[i]])))


func _line_sprite(line_id: StringName, tier: int) -> Control:
	# 蓋樓／升級即時反映在畫面上: the tier picks BOTH the era form and how tall it stands.
	return _sprite(AssetPaths.building(line_id, tier),
		LINE_HEIGHT_BASE + LINE_HEIGHT_PER_TIER * float(tier))


func _sprite(path: String, height: float) -> Control:
	var art := TextureRect.new()
	var tex := _chrome.texture(path)
	art.texture = tex
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(height * tex.get_width() / tex.get_height(), height)
	art.size_flags_vertical = Control.SIZE_SHRINK_END
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


# --- the command dock ---

func _build_dock() -> void:
	_dock_handle = _chrome.button("指令盤", toggle_dock)
	_dock_handle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dock_handle.offset_left = -200.0
	_dock_handle.offset_top = -96.0
	_dock_handle.offset_right = -24.0
	_dock_handle.offset_bottom = -24.0
	_dock_handle.visible = false
	add_child(_dock_handle)
	_dock = _chrome.panel()
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dock.offset_left = -DOCK_WIDTH
	_dock.offset_top = -DOCK_HEIGHT
	_dock.offset_right = -20.0
	_dock.offset_bottom = -20.0
	add_child(_dock)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_dock.add_child(box)
	_dock_tabs = HBoxContainer.new()
	_dock_tabs.add_theme_constant_override("separation", 6)
	box.add_child(_dock_tabs)
	for i: int in range(TABS.size()):
		var id: StringName = TABS[i]
		_dock_tabs.add_child(_chrome.button(TAB_NAMES[i], func() -> void: open_tab(id)))
	box.add_child(_chrome.divider())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_dock_body = VBoxContainer.new()
	_dock_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dock_body.add_theme_constant_override("separation", 5)
	scroll.add_child(_dock_body)
	# The phase's primary action is PINNED below the scroll, never inside it: Part B caught it
	# scrolled off the bottom of a full build list, which is the one button that must always be
	# reachable — a player who cannot find it cannot end the generation.
	box.add_child(_chrome.divider())
	_end_phase = _chrome.button("結束營運相位 → 選路", func() -> void: operate_finished.emit())
	box.add_child(_end_phase)


func _fill_dock() -> void:
	for child: Node in _dock_body.get_children():
		_dock_body.remove_child(child)
		child.queue_free()
	for i: int in range(_dock_tabs.get_child_count()):
		var tab_button := _dock_tabs.get_child(i) as Button
		tab_button.modulate = Color(1.15, 1.10, 0.95) if _tab == TABS[i] else Color(0.82, 0.80, 0.78)
	match _tab:
		&"build":
			_fill_build_tab()
		&"deck":
			_fill_deck_tab()
		&"world":
			_fill_world_tab()


func _fill_build_tab() -> void:
	_dock_body.add_child(_chrome.ink_label("BP %d｜國庫 %d" % [_state.bp, _state.treasury], 17, true))
	for region_id: StringName in BuildingData.REGIONS:
		if _state.regions.has(region_id):
			continue
		var target := region_id
		_dock_body.add_child(_chrome.button(
			"開 %s（%d 錢＋1 BP）" % [BuildingData.REGIONS[region_id]["zh"], Operations.region_cost(_state)],
			func() -> void: _act(func() -> void: Operations.build_region(_state, target)),
			StringName("region_" + region_id)))
	for line_id: StringName in BuildingData.LINES:
		var line: Dictionary = BuildingData.LINES[line_id]
		if not _state.regions.has(line["region"]):
			continue
		var target := line_id
		if not _state.buildings.has(line_id):
			_dock_body.add_child(_chrome.button(
				"蓋 %s（%d 錢＋1 BP）" % [line["zh"], Operations.building_cost(_state, line_id)],
				func() -> void: _act(func() -> void: Operations.build_building(_state, target))))
		elif int(_state.buildings[line_id]) < Era.index(_state.generation):
			var tier: int = int(_state.buildings[line_id])
			_dock_body.add_child(_chrome.button(
				"升 %s → %s（%d 錢＋1 BP）" % [line["zh"],
					String((line["names"] as Array)[tier]), Operations.upgrade_cost(_state, line_id)],
				func() -> void: _act(func() -> void: Operations.upgrade_building(_state, target))))
	var open := Policy.available(_state)
	if not open.is_empty():
		var node_id: StringName = _state.policy_in_progress if _state.policy_in_progress != &"" else open[0]
		var spec: Dictionary = PolicyNodes.NODES[node_id]
		var invest := _chrome.button(
			"推 %s（1 BP，%d/%d）" % [spec["zh"], Policy.progress(_state, node_id), int(spec["cost_bp"])],
			func() -> void: _act(func() -> void: Policy.invest(_state, node_id, 1)),
			StringName("policy_" + node_id))
		invest.disabled = _state.bp < 1 or Policy.frozen(_state)
		_dock_body.add_child(invest)


func _fill_deck_tab() -> void:
	# 勳章指派 (D14) and 解散 evaluation both live here: the player reads the roll — grade prefix,
	# 命中／閃避／攻速, medal levels — and decides whether these particular men are worth keeping.
	_dock_body.add_child(_chrome.ink_label(
		"待指派勳章 %d｜牌組 %d 張（下限 %d）" % [_state.medals, _state.deck.size(), Cards.DECK_MINIMUM],
		17, true))
	var disband_cost: int = Cards.DISBAND_COST_BASE * Era.coeff(_state.generation)
	for i: int in range(_state.deck.size()):
		var instance: Cards.CardInstance = _state.deck[i]
		var index := i
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		_dock_body.add_child(row)
		row.add_child(_chrome.ink_label(_card_line(instance), 16))
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		row.add_child(actions)
		var lane: StringName = Cards.lane_stat(instance.id)
		if lane != &"":
			var award := _chrome.button("授勳 → %s" % _stat_name(lane),
				func() -> void: _act(func() -> void: Operations.assign_medal(_state, index)))
			award.disabled = _state.medals < 1
			actions.add_child(award)
		var scrap := _chrome.button("解散（%d 錢，+%d 人口）" % [
			disband_cost, int(Cards.card(instance.id)["disband_pop"])],
			func() -> void: _act(func() -> void: Cards.disband(_state, index)))
		scrap.disabled = _state.deck.size() <= Cards.DECK_MINIMUM
		actions.add_child(scrap)


func _fill_world_tab() -> void:
	# 宣戰 and 心戰 are operate-phase actions (design/對手文明.md), not battle-opening choices.
	_dock_body.add_child(_chrome.ink_label("我方 power %d" % Rivals.player_power(_state), 17, true))
	for rival: Rivals.RivalState in Rivals.living(_state):
		var target: StringName = rival.id
		_dock_body.add_child(_chrome.ink_label("%s｜power %d｜敗 %d" % [
			rival.display_name, int(rival.power), rival.defeats], 16))
		var actions := HBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		_dock_body.add_child(actions)
		var war := _chrome.button("宣戰（1 BP）",
			func() -> void: _act(func() -> void: Rivals.declare_war(_state, target)))
		war.disabled = _state.bp < 1 or _state.pending_war_target != &""
		actions.add_child(war)
		var psy := _chrome.button("心戰（1 BP，需文化領先）",
			func() -> void: _act(func() -> void: Rivals.psyops(_state, target)))
		psy.disabled = _state.psyops_used_this_gen or _state.bp < 1 \
			or _state.culture <= Rivals.culture_of(rival)
		actions.add_child(psy)


func _card_line(instance: Cards.CardInstance) -> String:
	var entry: Dictionary = Cards.card(instance.id)
	var head := "%s　攻%d／血%d　軍費%d" % [Cards.display_name(instance),
		Cards.attack_of(instance), Cards.hp_of(instance),
		Cards.military_cost_of(_state, instance)]
	if not Cards.is_unit(instance.id):
		return "%s　（%s）" % [head, "工事" if entry["class"] == &"fortification" else "技能"]
	return "%s\n　　命中 %.0f／閃避 %.0f／攻速 %.2f%s" % [head,
		Cards.accuracy_of(_state, instance), Cards.dodge_of(_state, instance),
		Cards.speed_of(_state, instance), _medal_suffix(instance)]


func _medal_suffix(instance: Cards.CardInstance) -> String:
	var parts: Array[String] = []
	for stat: StringName in Cards.QUALITY_STATS:
		var level: int = int(instance.levels.get(stat, 0))
		if level > 0:
			parts.append("%s+%d" % [_stat_name(stat), level])
	return ("　勳章 " + ", ".join(parts)) if not parts.is_empty() else ""


func _stat_name(stat: StringName) -> String:
	return {&"accuracy": "命中", &"dodge": "閃避", &"speed": "攻速"}[stat]


func _act(mutate: Callable) -> void:
	mutate.call()
	_draw_skyline()
	_fill_dock()
	state_changed.emit()
	_focus_first_in(_dock_body)


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		toggle_dock()


func _focus_first_in(container: Control) -> bool:
	# Controller support is a standing requirement: after any dock rebuild something focusable must
	# be focused, or a pad-only player is stranded on a screen full of buttons.
	for child: Node in container.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return true
		if child is Control and _focus_first_in(child as Control):
			return true
	return false


func _press_first_in(container: Control, needle: String) -> bool:
	var button := _find_enabled_in(container, needle)
	if button == null:
		return false
	button.pressed.emit()
	return true


func _find_enabled_in(container: Control, needle: String) -> Button:
	for child: Node in container.get_children():
		if child is Button:
			var b := child as Button
			if not b.disabled and (needle == "" or b.text.contains(needle)):
				return b
		if child is Control:
			var deeper := _find_enabled_in(child as Control, needle)
			if deeper != null:
				return deeper
	return null
