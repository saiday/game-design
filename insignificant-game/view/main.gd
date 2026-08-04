extends Control
# Insignificant view root: owns the run, the HUD, and which scene is on screen.
#
# **Three main scenes** (design/營運.md §場景呈現, style bible §11), each with its own backdrop and
# never a shared one: 營運＝活的城市全景 (CityScene, side-view), 選路＝迷霧地圖 (W15.2), 戰鬥＝依戰鬥
# 類型的專屬戰場 (W15.3, top-down per ADR-0009). The phases that are not scenes — 機會, 結算, 世界
# 大戰, 民主, 結局 — are parchment panels over the city, which is where the player already is.
#
# The view computes NOTHING. Every rule call goes through core/, every texture through
# core/data/asset_paths.gd, and no number on screen is derived here.
#
# Demo mode (INSIG_DEMO=1): drives the same handlers a human clicks, captures a PNG per screen,
# prints ASSERT PASS/FAIL, exits 0/1 (Part B of the loop).

const BG_COLOR := Color(0.10, 0.11, 0.13)   # only ever seen if a backdrop plate fails to load
const HUD_BAND_HEIGHT: float = 168.0        # the scrim the HUD strip and event line read against

# Outcome and opportunity-effect wording. These are view strings for values core reports as ids;
# anything that is a NAME (a battle type, a policy node, a building line) carries its own "zh" in
# the data table instead, because a name belongs to the content and a phrasing belongs to the UI.
const OUTCOME_NAMES: Dictionary = {
	&"win": "勝", &"loss": "敗", &"retreat": "撤軍", &"defected": "敵方投誠",
}
const EFFECT_NAMES: Dictionary = {
	"money": "金錢", "fee": "花費", "population": "人口", "happiness": "幸福",
	"culture": "文化", "treasure": "國寶", "rare_card": "稀有卡",
}

var chrome: Chrome
var state: GameState
var nodes: Array[Dictionary] = []
var battle: Battle.BattleField = null
var pending_reward: Cards.CardInstance = null
var current_opportunity: StringName = &""
var world_war_generation: bool = false   # 整代覆寫: no operate, no route, no unrest roll
var demo_failures: int = 0

var hud: Hud
var city: CityScene
var event_label: Label
var overlay: Control
var panels: Dictionary = {}
var route_actions: VBoxContainer
var battle_info: Label
var battle_spend: Label
var battle_deploy: VBoxContainer
var battle_buttons: HBoxContainer
var opportunity_label: Label
var opportunity_actions: VBoxContainer
var opportunity_card_art: TextureRect
var opportunity_card_text: Label
var settle_label: Label
var reward_label: Label
var reward_card_art: TextureRect
var reward_card_text: Label
var reward_actions: HBoxContainer
var ww_label: Label
var ww_next: Button
var democracy_label: Label
var democracy_actions: VBoxContainer
var ending_label: Label


func _ready() -> void:
	chrome = Chrome.new()
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
	city.set_time_of_day(&"morning")
	city.refresh(state)
	world_war_generation = report.has("world_war")
	if world_war_generation:
		# 整代覆寫: the world war is a played battle on the shared table (W12.5), not a summary.
		battle = WorldWar.start(state)
		_refresh_battle()
		_show_overlay(&"battle")
	elif report.has("democracy"):
		_refresh_democracy()
		_show_overlay(&"democracy")
	else:
		_show_overlay(&"")   # the city IS the operate screen; nothing sits over it
	_refresh_stats()


func _end_operate() -> void:
	Operations.end_operate_phase(state)
	nodes = Turn.route(state)
	city.set_time_of_day(&"midday")
	_refresh_route()
	_show_overlay(&"route")
	_refresh_stats()


func _enter_node(index: int) -> void:
	var node: Dictionary = nodes[index]
	if node["content"] == &"opportunity":
		current_opportunity = MapNodes.roll_opportunity(state)
		_refresh_opportunity()
		_show_overlay(&"opportunity")
	else:
		battle = Battle.start(
			state, node["battle_type"], node.get("rival_id", &""),
			bool(node.get("player_declared", false)), bool(node.get("surprise", false)))
		_refresh_battle()
		_show_overlay(&"battle")
	_refresh_stats()


func _resolve_opportunity(choice: StringName) -> void:
	var report := MapNodes.resolve_opportunity(state, current_opportunity, choice)
	var parts: Array[String] = []
	for key: String in EFFECT_NAMES:
		if not report.has(key):
			continue
		var value: Variant = report[key]
		if value is bool:
			parts.append("%s ×1" % EFFECT_NAMES[key])
		elif int(value) != 0:
			parts.append("%s %+d" % [EFFECT_NAMES[key], int(value)])
	event_label.text = "機會：%s → %s" % [
		OpportunityData.TABLE[current_opportunity]["label"],
		"、".join(parts) if not parts.is_empty() else "無變化"]
	_settle()


func _battle_deploy(available_index: int) -> void:
	Battle.deploy(state, battle, available_index)
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
	# 戰後結算畫面亮出獎勵卡 (戰鬥.md): core rolls it, the player accepts or drops it here.
	# 世界大戰 settles camps and reparations on top of the same battle report.
	var world_war: bool = battle.battle_type == &"world_war"
	var report: Dictionary = WorldWar.finish(state, battle) if world_war \
		else Battle.finish(state, battle)
	event_label.text = "%s結束：%s（軍費 %d／戰功 %d）" % [
		Battle.type_name(battle.battle_type), OUTCOME_NAMES[battle.outcome],
		battle.spent, battle.merit]
	battle = null
	pending_reward = report["reward_instance"]
	if world_war:
		ww_label.text = "第 %d 代 — 世界大戰（整代覆寫）\n我方陣營：%s\n敵方陣營：%s\n勝方：%s\n打了 %d 回合｜賠款池 %d｜我方收付 %s" % [
			int(report["generation"]),
			", ".join(_civ_names(report["player_camp"])), ", ".join(_civ_names(report["enemy_camp"])),
			"我方" if bool(report["player_won"]) else "敵方", int(report["rounds"]), int(report["pool"]),
			str((report["payouts"] as Dictionary).get(&"player",
				-(report["reparations"] as Dictionary).get(&"player", 0)))]
		_show_overlay(&"world_war")
	else:
		_refresh_reward()
		_show_overlay(&"reward")
	_refresh_stats()


func _resolve_reward(accept: bool) -> void:
	if accept:
		Cards.accept_reward(state, pending_reward)
	pending_reward = null
	city.refresh(state)
	_settle()


func _settle() -> void:
	# 世界大戰整代覆寫: no unrest roll on a war generation — the generation was the war.
	if not world_war_generation and Turn.roll_unrest_battle(state):
		if Unrest.use_martial_law(state):
			event_label.text += "｜戒嚴動用：內亂戰閃避"
		elif state.treasury >= Unrest.concession_cost(state):
			Unrest.apply_concession(state)
			event_label.text += "｜讓步：內亂戰取消"
		else:
			battle = Battle.start(state, &"riot")
			_refresh_battle()
			_show_overlay(&"battle")
			return
	world_war_generation = false
	city.set_time_of_day(&"dusk")
	var report := Turn.settle(state)
	var economy: Dictionary = report["economy"]
	settle_label.text = "第 %d 代結算\n稅收 +%d｜資本利得 +%d｜利息 −%d\n國庫 %d" % [
		state.generation - 1, int(economy["tax"]), int(economy["capital_gains"]),
		int(economy["interest"]), state.treasury]
	var ending: Dictionary = report["ending"]
	if bool(ending["over"]):
		_show_ending(ending)
	else:
		_show_overlay(&"settle")
	_refresh_stats()


func _show_ending(ending: Dictionary) -> void:
	city.set_time_of_day(&"night")
	var head: String = {
		&"collapse": "政權崩潰",
		&"total_victory": "提前完全勝利",
		&"survived": "走到最後（第 %d 名）" % int(ending.get("rank", 0)),
	}[ending["kind"]]
	ending_label.text = "%s\n\n%s" % [head, String(ending["epilogue"])]
	_show_overlay(&"ending")


# ---------- refresh ----------

func _refresh_stats() -> void:
	hud.refresh(state)


func _refresh_route() -> void:
	# W15.2 promotes this to its own fog-map scene; until then it is a list over the city.
	_clear(route_actions)
	for i: int in range(nodes.size()):
		var node: Dictionary = nodes[i]
		# 迷霧 hides the CONTENT, never the node: an unknown node is visibly there and unreadable.
		var face: String = "迷霧（看不出是什麼）"
		var badge: StringName = &"map_unknown"
		if node["kind"] == &"known" or bool(node["face_shown"]):
			if node["content"] == &"battle":
				face = Battle.type_name(node["battle_type"])
				badge = &"map_battle"
			else:
				face = "機會事件"
				badge = &"map_opportunity"
		var index := i
		route_actions.add_child(chrome.button("節點 %d：%s" % [i + 1, face],
			func() -> void: _enter_node(index), badge))
	route_actions.add_child(chrome.button("付錢略過（%d）→ 結算" % MapNodes.skip_cost(state),
		func() -> void:
			MapNodes.skip_node(state)
			_settle(),
		&"map_skip"))
	_focus_first(route_actions)


func _refresh_battle() -> void:
	# W15.3 promotes this to the top-down battlefield scene; until then it is the round-boundary
	# console over the city, already on the post-W12 API (no hand: 未出的卡 is the whole deck).
	var enemy_lines: Array[String] = []
	for unit: Dictionary in battle.enemy_units:
		enemy_lines.append("%s 攻%d/血%d" % [_unit_name(unit), int(unit["attack"]), int(unit["hp"])])
	var our_lines: Array[String] = []
	for unit: Dictionary in battle.player_units:
		our_lines.append("%s 攻%d/血%d" % [_unit_name(unit), int(unit["attack"]), int(unit["hp"])])
	var intel: String = "情報：本場波次表可見" if battle.intel_visible else "情報：盲打（當代未覆蓋）"
	var cap: String = "第 %d 回合（無上限）" % battle.round if battle.round_cap == 0 \
		else "第 %d/%d 回合" % [battle.round, battle.round_cap]
	battle_info.text = "%s｜%s｜%s\n敵：%s\n我：%s" % [
		Battle.type_name(battle.battle_type), cap, intel,
		"　".join(enemy_lines) if not enemy_lines.is_empty() else "（已清空）",
		"　".join(our_lines) if not our_lines.is_empty() else "（未部署）"]
	# 本場已燒軍費 vs 預期賠償 全程常駐 (戰鬥.md 核心博弈)
	battle_spend.text = "本場已燒軍費 %d ｜ 預期賠償 %d" % [battle.spent, battle.expected_reward]
	_clear(battle_deploy)
	for i: int in range(battle.available.size()):
		var instance: Cards.CardInstance = battle.available[i]
		var index := i
		var note: String = ""
		if battle.battle_type == &"riot" and Cards.card(instance.id)["class"] == &"mechanical":
			note = "　※鎮壓代價 幸福 −%d" % Battle.RIOT_MECH_HAPPINESS
		battle_deploy.add_child(chrome.button("投入 %s（軍費 %d）%s" % [
			Cards.display_name(instance), Battle.card_cost(state, battle, instance), note],
			func() -> void: _battle_deploy(index)))
	_clear(battle_buttons)
	if Battle.can_defect(state, battle):
		battle_buttons.add_child(chrome.button("投誠（免軍費勝）", func() -> void:
			Battle.defect(state, battle)
			_finish_battle()))
	battle_buttons.add_child(chrome.button("結束回合 → 演出", _battle_end_round))
	battle_buttons.add_child(chrome.button("不再出牌（自願認輸）", func() -> void:
		Battle.concede(battle)
		_battle_end_round()))
	if Battle.can_retreat(battle):
		battle_buttons.add_child(chrome.button("撤軍（%d 錢，+%d 人口）" % [
			Battle.RETREAT_COST_BASE * Era.coeff(state.generation), Battle.RETREAT_POP],
			func() -> void:
				Battle.retreat(state, battle)
				_finish_battle()))
	_focus_first(battle_buttons)


func _refresh_reward() -> void:
	# 「太爛就放棄」的決策瞬間就在這一幕 — the roll's grade and innate three are the whole decision.
	var duplicate: bool = false
	for owned: Cards.CardInstance in state.deck:
		if owned.id == pending_reward.id:
			duplicate = true
			break
	var price: String = "重複卡：收編價 %d 錢" % (Cards.REWARD_DUPLICATE_COST_BASE * Era.coeff(state.generation)) \
		if duplicate else "首見：免費納入"
	var name := Cards.display_name(pending_reward)
	var lines: Array[String] = [name]
	if Cards.is_unit(pending_reward.id):
		lines.append("攻 %d／血 %d" % [Cards.attack_of(pending_reward), Cards.hp_of(pending_reward)])
		lines.append("命中 %.0f／閃避 %.0f／攻速 %.2f" % [
			pending_reward.accuracy, pending_reward.dodge, pending_reward.speed])
	else:
		lines.append("工事／技能：不抽品質三項")
	lines.append("軍費 %d" % Cards.military_cost_of(state, pending_reward))
	lines.append(price)
	reward_label.text = "\n".join(lines)
	reward_card_text.text = name
	reward_card_art.texture = _card_illustration(pending_reward)
	_clear(reward_actions)
	reward_actions.add_child(chrome.button("納入牌組", func() -> void: _resolve_reward(true)))
	reward_actions.add_child(chrome.button("放棄", func() -> void: _resolve_reward(false)))
	_focus_first(reward_actions)


func _refresh_opportunity() -> void:
	var entry: Dictionary = OpportunityData.TABLE[current_opportunity]
	opportunity_label.text = String(entry["label"])
	opportunity_card_art.texture = chrome.texture(AssetPaths.icon_opportunity(current_opportunity))
	opportunity_card_text.text = String(entry["label"])
	_clear(opportunity_actions)
	for choice: StringName in MapNodes.opportunity_choices(current_opportunity):
		var picked := choice
		opportunity_actions.add_child(chrome.button(String(picked),
			func() -> void: _resolve_opportunity(picked)))
	_focus_first(opportunity_actions)


func _refresh_democracy() -> void:
	var lines: Array[String] = ["現任：%s" % (
		CandidateData.CANDIDATES[state.incumbent]["zh"] if state.incumbent != &"" else "—")]
	if state.incumbent != &"":
		lines.append("「%s」" % CandidateData.CANDIDATES[state.incumbent]["copy"])
	lines.append("連任機率 %d%%" % int(round(Democracy.reelection_chance(state) * 100.0)))
	democracy_label.text = "\n".join(lines)
	_clear(democracy_actions)
	for candidate_id: StringName in Democracy.top_three(state):
		var picked := candidate_id
		democracy_actions.add_child(chrome.button("金援 %s（50 錢，+10%%）" % CandidateData.CANDIDATES[picked]["zh"],
			func() -> void:
				Democracy.fund(state, picked)
				_refresh_democracy()
				_refresh_stats(),
			&"fund"))
	democracy_actions.add_child(chrome.button("看國家自動運轉 → 結算", func() -> void:
		Democracy.generation_step(state)
		_settle()))
	_focus_first(democracy_actions)


# ---------- UI scaffolding ----------

func _build_ui() -> void:
	theme = chrome.theme()
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# scene layer (bottom): the city is the standing screen, the other two scenes land in W15.2/3
	city = CityScene.new()
	city.setup(chrome)
	city.state_changed.connect(_refresh_stats)
	city.operate_finished.connect(_end_operate)
	add_child(city)
	# HUD layer: icon+value strip, always on screen, never covered by a panel.
	# It rides a dark scrim because it sits on whatever plate is behind it — Part B caught the
	# danger row (accent gold on a pale sky) at the edge of unreadable over the city panorama.
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_TOP_WIDE)
	scrim.offset_bottom = HUD_BAND_HEIGHT
	scrim.color = Color(0.06, 0.07, 0.09, 0.55)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24.0
	top.offset_top = 14.0
	top.offset_right = -24.0
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	hud = Hud.new()
	hud.setup(chrome)
	top.add_child(hud)
	top.add_child(chrome.divider())
	event_label = Label.new()
	event_label.add_theme_font_size_override("font_size", 16)
	event_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(event_label)
	# overlay layer: the phases that are panels rather than scenes
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 120.0
	overlay.offset_top = 190.0
	overlay.offset_right = -120.0
	overlay.offset_bottom = -120.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_build_panels()
	add_child(hud.build_tooltip())   # last child: the tooltip overhangs everything


func _build_panels() -> void:
	route_actions = _vbox(_panel(&"route", "選路"))
	var battle_box := _vbox(_panel(&"battle", "戰鬥"))
	battle_info = chrome.ink_label("", 16)
	battle_box.add_child(battle_info)
	battle_spend = chrome.ink_label("", 19, true)
	battle_box.add_child(battle_spend)
	battle_deploy = VBoxContainer.new()
	battle_box.add_child(battle_deploy)
	battle_buttons = HBoxContainer.new()
	battle_box.add_child(battle_buttons)
	# 戰後結算畫面亮出獎勵卡 (戰鬥.md): the card is SHOWN, illustration and all — 「太爛就放棄」
	# is a decision about these particular men, so the reveal has to be a card, not a line of text.
	var reward_split := HBoxContainer.new()
	reward_split.add_theme_constant_override("separation", 28)
	_vbox(_panel(&"reward", "戰後獎勵卡")).add_child(reward_split)
	var reward_card := chrome.card_widget()
	reward_card_art = reward_card["art"]
	reward_card_text = reward_card["text"]
	reward_split.add_child(reward_card["root"])
	var reward_box := VBoxContainer.new()
	reward_box.add_theme_constant_override("separation", 8)
	reward_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_split.add_child(reward_box)
	reward_label = chrome.ink_label("", 19)
	reward_box.add_child(reward_label)
	reward_actions = HBoxContainer.new()
	reward_actions.add_theme_constant_override("separation", 8)
	reward_box.add_child(reward_actions)
	var opp_split := HBoxContainer.new()
	opp_split.add_theme_constant_override("separation", 28)
	_vbox(_panel(&"opportunity", "機會事件")).add_child(opp_split)
	var opp_card := chrome.card_widget()
	opportunity_card_art = opp_card["art"]
	opportunity_card_text = opp_card["text"]
	opp_split.add_child(opp_card["root"])
	var opp_box := VBoxContainer.new()
	opp_box.add_theme_constant_override("separation", 6)
	opp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opp_split.add_child(opp_box)
	opportunity_label = chrome.ink_label("", 20)
	opp_box.add_child(opportunity_label)
	opportunity_actions = VBoxContainer.new()
	opp_box.add_child(opportunity_actions)
	var settle_box := _vbox(_panel(&"settle", "結算"))
	settle_label = chrome.ink_label("", 18)
	settle_box.add_child(settle_label)
	settle_box.add_child(chrome.button("進入下一代", _begin_generation))
	var ww_box := _vbox(_panel(&"world_war", "世界大戰"))
	ww_label = chrome.ink_label("", 18)
	ww_box.add_child(ww_label)
	ww_next = chrome.button("戰後獎勵卡 →", func() -> void:
		_refresh_reward()
		_show_overlay(&"reward"))
	ww_box.add_child(ww_next)
	var demo_box := _vbox(_panel(&"democracy", "民主（自動營運）"))
	democracy_label = chrome.ink_label("", 18)
	demo_box.add_child(democracy_label)
	democracy_actions = VBoxContainer.new()
	demo_box.add_child(democracy_actions)
	var ending_box := _vbox(_panel(&"ending", "結局"))
	ending_label = chrome.ink_label("", 19)
	ending_box.add_child(ending_label)
	ending_box.add_child(chrome.button("再來一局", _start_run))


func _panel(id: StringName, title: String) -> VBoxContainer:
	var panel := chrome.panel()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	overlay.add_child(panel)
	panels[id] = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var heading := chrome.ink_label(title, 28)
	heading.add_theme_font_override("font", chrome.bold_font())
	box.add_child(heading)
	return box


func _vbox(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box


func _show_overlay(id: StringName) -> void:
	for key: StringName in panels.keys():
		(panels[key] as Control).visible = key == id
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE if id == &"" else Control.MOUSE_FILTER_STOP
	# The city keeps standing behind every panel (it is the world, not a screen), but its dock is
	# the OPERATE phase's command surface — leaving it live during a battle would offer 蓋樓 mid-fight.
	city.set_commands_visible(id == &"")


func _visible_overlay() -> StringName:
	for key: StringName in panels.keys():
		if (panels[key] as Control).visible:
			return key
	return &""


func _card_illustration(instance: Cards.CardInstance) -> Texture2D:
	# Skills are era-neutral (one illustration); everything else is per era form. The coverage
	# holes are real (砲兵 starts era 3, 私掠 ends before 資訊), so an absent form draws no art
	# rather than crashing on a path the registry never promised.
	if Cards.card(instance.id)["class"] == &"skill":
		if AssetPaths.has_card_skill(instance.id):
			return chrome.texture(AssetPaths.card_skill(instance.id))
		return null
	if AssetPaths.has_card(instance.id, instance.tier):
		return chrome.texture(AssetPaths.card(instance.id, instance.tier))
	return null


func _unit_name(unit: Dictionary) -> String:
	if unit["card_id"] != &"":
		return Cards.form_name(unit["card_id"], Era.index(state.generation))
	return {&"weak": "弱兵", &"medium": "中兵", &"hard": "硬兵"}.get(unit["grade"], "？")


func _civ_names(camp: Array) -> Array[String]:
	var out: Array[String] = []
	for civ_id: StringName in camp:
		out.append("你" if civ_id == &"player" else Rivals.find(state, civ_id).display_name)
	return out


func _clear(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _focus_first(container: Control) -> void:
	for child: Node in container.get_children():
		if child is Button and not (child as Button).disabled:
			(child as Button).grab_focus()
			return


# ---------- Part B demo: simulated clicks + captures + ASSERTs ----------

func _run_demo() -> void:
	var watchdog := get_tree().create_timer(90.0)
	watchdog.timeout.connect(func() -> void:
		print("ASSERT FAIL: demo watchdog expired")
		get_tree().quit(1))
	await _demo_city()
	await _demo_route_and_battle()
	await _demo_settle()
	await _demo_world_war()
	await _demo_democracy()
	await _demo_ending()
	_assert_pixels()
	print("DEMO DONE: %d assert failures" % demo_failures)
	get_tree().quit(0 if demo_failures == 0 else 1)


func _demo_city() -> void:
	# the city IS the operate screen: no panel over it, the dock is the whole command surface
	await _capture(&"city", "operations city panorama with the command dock open")
	_assert(_visible_overlay() == &"", "operate phase shows the city, not a panel")
	_assert(city.dock_open(), "command dock opens with the phase")
	_assert(city.dock_action_count() >= 2, "dock offers build actions")
	var before: int = state.regions.size() + state.buildings_built
	_assert(city.press_dock_action(), "the dock has an enabled action to click")
	_assert(state.regions.size() + state.buildings_built > before, "a dock click actually built something")
	# a seeded spread of era forms, so the skyline capture shows the tier→era-form swap
	state.buildings = {&"housing": 1, &"school": 2, &"debt_office": 3, &"commerce": 4,
		&"bank": 5, &"media": 6}
	city.refresh(state)
	await _capture(&"city_skyline", "city with six built lines at spread era forms")
	_assert(city.skyline_count() >= 1, "skyline drawn")
	_assert(city.end_phase_reachable(), "結束營運相位 stays visible under a full action list")
	# 收合式指令盤: the city must be able to become the whole screen
	city.toggle_dock()
	await _capture(&"city_dock_closed", "dock folded away, city unobstructed")
	_assert(not city.dock_open(), "dock collapses")
	city.toggle_dock()
	_assert(city.dock_open(), "dock reopens")
	# HUD tooltips: hover and controller focus are the same verb
	hud.focus_cell(&"population")
	await _capture(&"hud_tooltip", "HUD tooltip opened by controller focus")
	_assert(hud.tooltip_visible(), "focusing a HUD cell opens its tooltip")
	_assert(hud.tooltip_term() == "人口", "the tooltip names the term the cell shows")
	hud.hide_tip()
	# 勳章 assignment + 解散 evaluation both live in the deck tab
	state.medals += 1
	city.open_tab(&"deck")
	await _capture(&"city_deck", "deck tab: medal assignment and disband evaluation")
	var medals_before: int = state.medals
	_assert(city.press_dock_action("授勳"), "the deck tab offers 授勳 while a medal is banked")
	_assert(state.medals == medals_before - 1, "授勳 spends a medal")
	# 解散 has a floor: the starting deck IS the minimum, so the button must be refused there and
	# offered the moment a reward card lifts the deck above it (卡牌.md 卡牌經濟).
	_assert(state.deck.size() == Cards.DECK_MINIMUM, "the run opens at the deck minimum")
	_assert(not city.dock_action_enabled("解散"), "解散 is refused at the deck minimum")
	Cards.accept_reward(state, Cards.roll_reward(state))
	city.refresh(state)
	var deck_before: int = state.deck.size()
	_assert(city.press_dock_action("解散"), "解散 opens up once the deck clears the minimum")
	_assert(state.deck.size() == deck_before - 1, "解散 removes a card from the deck")
	city.open_tab(&"build")


func _demo_route_and_battle() -> void:
	_end_operate()
	await _capture(&"route", "route panel with node buttons")
	_assert(route_actions.get_child_count() >= 2, "route lists nodes plus the skip exit")
	(route_actions.get_child(0) as Button).pressed.emit()
	if _visible_overlay() == &"battle":
		await _capture(&"battle", "battle round-boundary console")
		_assert(battle_spend.text.contains("軍費"), "spend-vs-reward line visible")
		_assert(battle_deploy.get_child_count() >= 1, "未出的卡 offered at the boundary")
		(battle_deploy.get_child(0) as Button).pressed.emit()
		_assert(battle != null and battle.player_units.size() + battle.player_forts.size() >= 1,
			"deploying puts something on the field")
		var guard: int = 0
		while battle != null and guard < 30:
			guard += 1
			_battle_end_round()
		_assert(battle == null, "the battle reaches an outcome")
		await _capture(&"reward", "post-battle reward card reveal")
		_assert(_visible_overlay() == &"reward", "every battle ends on the reward reveal")
		_assert(reward_card_text.text.length() > 0, "the revealed card names itself on the card")
		_assert(reward_card_art.texture != null, "the revealed card shows its illustration")
		_assert(reward_label.text.contains("納入") or reward_label.text.contains("收編價"),
			"the reveal states what taking it costs")
		(reward_actions.get_child(0) as Button).pressed.emit()
	else:
		await _capture(&"opportunity", "opportunity panel")
		(opportunity_actions.get_child(0) as Button).pressed.emit()


func _demo_settle() -> void:
	if _visible_overlay() == &"battle":
		Battle.retreat(state, battle)   # riot fallback so the demo always advances
		_finish_battle()
		(reward_actions.get_child(0) as Button).pressed.emit()
	await _capture(&"settle", "settle panel at dusk")
	_assert(settle_label.text.contains("結算"), "settle summary visible")


func _demo_world_war() -> void:
	# 整代覆寫: the war is a played battle on the shared table, not a rolled summary (W12.5).
	state.generation = 15
	_begin_generation()
	_assert(_visible_overlay() == &"battle", "a world-war generation opens on the battle table")
	_assert(battle != null and battle.round_cap == 0, "世界大戰 has no round cap")
	await _capture(&"world_war_battle", "world war fought on the shared table")
	_assert(_deploy_button_count() >= 1, "our own cards are offered in the world war")
	var guard: int = 0
	while battle != null and guard < 250:
		guard += 1
		if _deploy_button_count() > 0 and battle.round <= 2:
			(battle_deploy.get_child(0) as Button).pressed.emit()
		else:
			Battle.concede(battle)   # 留卡省軍費 is a legal voluntary concession (D3)
			_battle_end_round()
	_assert(battle == null, "the uncapped war reaches an outcome")
	await _capture(&"world_war", "world war settlement: camps, pool, our payout")
	_assert(ww_label.text.contains("世界大戰"), "world war summary visible")
	_assert(ww_label.text.contains("賠款池"), "the reparations pool is shown")
	ww_next.pressed.emit()
	_assert(_visible_overlay() == &"reward", "the war issues a reward card like any other battle")
	(reward_actions.get_child(0) as Button).pressed.emit()


func _deploy_button_count() -> int:
	return battle_deploy.get_child_count() if battle != null else 0


func _demo_democracy() -> void:
	state.culture = maxi(state.culture, 25)
	Democracy.enter(state, true)
	_begin_generation()
	await _capture(&"democracy", "democracy panel")
	_assert(democracy_label.text.contains("現任"), "democracy incumbent visible")


func _demo_ending() -> void:
	state.generation = Era.FINAL_GENERATION + 1
	_show_ending(Ending.check(state))
	await _capture(&"ending", "ending panel at night")
	_assert(ending_label.text.length() > 20, "epilogue text visible")


func _capture(tag: StringName, description: String) -> void:
	_refresh_stats()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "res://captures/w15_%s.png" % tag
	image.save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE %s -> %s" % [description, path])
	_assert(hud.value_of(&"population").length() > 0, "HUD population cell populated")
	_assert(hud.value_of(&"unrest").ends_with("%"), "danger row always on screen")
	var rect := get_viewport_rect()
	_assert(rect.encloses(hud.get_global_rect()), "HUD strip inside the viewport")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("ASSERT PASS: %s" % message)
	else:
		demo_failures += 1
		print("ASSERT FAIL: %s" % message)


func _assert_pixels() -> void:
	# The W5 version classified the corner against BG_COLOR, which stopped meaning anything the
	# moment a backdrop plate covered the whole screen. What is still worth asserting is that the
	# frame is a PICTURE and not a flat fill: a scene that failed to load its plate, or a panel
	# that painted over everything, both come out uniform.
	var image := get_viewport().get_texture().get_image()
	var seen: Dictionary = {}
	for x: int in range(8, image.get_width() - 8, 97):
		for y: int in range(8, image.get_height() - 8, 89):
			var c := image.get_pixel(x, y)
			seen[Vector3i(int(c.r * 16), int(c.g * 16), int(c.b * 16))] = true
	_assert(seen.size() >= 8, "the final frame is a rendered scene, not a flat fill (%d tones)"
		% seen.size())
