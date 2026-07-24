class_name Battle
extends RefCounted
# 戰鬥 (design/戰鬥.md): single battlefield, auto-deploy by combat attribute, enemy arrives
# in SCHEDULED WAVES rolled per battle, each 回合 is a fixed tick window in which units act
# on their own attack speed (no simultaneous resolution), and core emits the round's whole
# event timeline before the view animates anything (docs/plan-battle-model-rewrite.md D1-D6).
# 出牌的唯一限制是軍費: no hand, no draw, any unplayed card any round, treasury may go
# negative and never blocks a play (D1/D3). Defeat is symmetric exhaustion: field empty AND
# nothing left to commit (D3). Survivors persist across waves, both sides (D4).
# Only player units carry the quality three + growth; every enemy (正規軍 and 非正規軍)
# fights at the engine defaults below (WW3).
# 鎮壓的手段有代價: a riot in which any 機械型部隊卡 was played ends with 幸福 −15,
# win or lose, once per battle.
#
# Design gaps decided here (docs/decisions.md, W12): 正規軍 wave composition greedy
# strongest-first; mutual simultaneous exhaustion = player 敗北; siege/air prefer standing
# fortifications; retreat still issues the reward card (only cancelled battles don't).

const TICKS_PER_ROUND: int = 100        # calibration knob (plan: open items)
const RETREAT_COST_BASE: int = 10
const RETREAT_POP: int = 2
const FORT_LIMIT: int = 2               # 工事卡同場上限 (CardsData.FORT_FIELD_LIMIT mirror)
const RIOT_MECH_HAPPINESS: int = 15     # 鎮壓的手段有代價 (design/戰鬥.md)

# Engine defaults every enemy fights at (戰鬥.md 對手兩型; calibration knobs).
const ENEMY_ACCURACY: float = 100.0
const ENEMY_DODGE: float = 0.0
const ENEMY_SPEED: float = 1.0

# 非正規軍 anonymous tiers: 弱＝攻1/血2、中＝攻2/血4、硬＝攻3/血6 (×時代係數). 首領＝硬級.
const GRADE_STATS: Dictionary = {&"weak": [1, 2], &"medium": [2, 4], &"hard": [3, 6]}

# battle_type -> round cap, money reward, wave schedule (v1 基準; rolled at start within
# each wave's round window on the &"battle" track — 開戰前情報 reveals the roll).
# civil_war waves carry budget shares of 總實力 ≈ P×0.5 instead of fixed grades (對手文明).
const TYPES: Dictionary = {
	&"tax_battle": {"round_cap": 6, "reward_per_coeff": 15,
		"waves": [{"window": [1, 1], "grades": [&"weak", &"weak"], "siege": false}]},
	&"field_battle": {"round_cap": 8, "reward_per_coeff": 25,
		"waves": [{"window": [1, 1], "grades": [&"medium", &"weak"], "siege": false},
			{"window": [3, 4], "grades": [&"medium"], "siege": false}]},
	&"hidden_battle": {"round_cap": 8, "reward_per_coeff": 45,
		"waves": [{"window": [1, 1], "grades": [&"hard"], "siege": true},
			{"window": [3, 4], "grades": [&"hard"], "siege": true}]},
	&"riot": {"round_cap": 8, "reward_per_coeff": 0,
		"waves": [{"window": [1, 1], "grades": [&"medium"], "siege": false},
			{"window": [3, 4], "grades": [&"medium"], "siege": false}]},
	&"democracy_blood": {"round_cap": 8, "reward_per_coeff": 0,
		"waves": [{"window": [1, 1], "grades": [&"hard", &"medium"], "siege": false},
			{"window": [4, 5], "grades": [&"hard"], "siege": false}]},
	&"civil_war": {"round_cap": 10, "reward_per_coeff": 0,
		"waves": [{"window": [1, 1], "share": 0.40},
			{"window": [4, 5], "share": 0.35},
			{"window": [7, 8], "share": 0.25}]},
}

# Intel qualification ladder (國策 偵查線): era ids covered per completed node.
const INTEL_COVERAGE: Dictionary = {
	&"scout_camp": [&"tribal", &"classical"],
	&"political_marriage": [&"faith", &"industrial"],
	&"intelligence_agency": [&"modern"],
	&"satellite_surveillance": [&"information"],
}


class BattleField:
	extends RefCounted
	var battle_type: StringName
	var rival_id: StringName = &""
	var player_declared: bool = false     # 聖戰 bonuses apply only to wars YOU declared
	var round: int = 1
	var round_cap: int = 8
	var outcome: StringName = &""         # &"win"|&"loss"|&"retreat"|&"defected" ("" = ongoing)
	var waves: Array[Dictionary] = []     # rolled schedule: {round, units} sorted by round
	var next_wave: int = 0
	var player_units: Array[Dictionary] = []
	var enemy_units: Array[Dictionary] = []
	var player_forts: Array[Dictionary] = []
	var enemy_forts: Array[Dictionary] = []
	var available: Array = []             # unplayed CardInstances (每張卡每場只出一次)
	var conceded: bool = false            # 還有未出卡但選擇不出 (voluntary exhaustion)
	var spent: int = 0                    # 本場已燒軍費 (UI shows vs expected_reward)
	var expected_reward: int = 0
	var merit: int = 0                    # 戰功: Σ strength of units we cleared
	var plunder: int = 0
	var attack_buff_rounds: int = 0       # 軍歌
	var cost_discount_rounds: int = 0     # 這些破洞不影響功能
	var love_and_peace_armed: bool = false
	var intel_visible: bool = false       # pre-battle: the rolled wave schedule is visible
	var see_deployment: bool = false      # 衛星監控 per-boundary preview (view concern)
	var mechanical_played: bool = false   # any 機械型部隊卡 fielded (riot 幸福 cost)
	var psyops_active: bool = false       # 文化國心戰: accuracy debuff (magnitude wired W13)
	var last_timeline: Array[Dictionary] = []   # the previous round's full event list


# --- setup ---

static func intel_covers(state: GameState) -> bool:
	# 偵查是資格線: current era must be covered, or you fight blind.
	var era_id: StringName = Era.of(state.generation)
	for node_id: StringName in INTEL_COVERAGE.keys():
		if state.policies.has(node_id) and (INTEL_COVERAGE[node_id] as Array).has(era_id):
			return true
	return false


static func start(state: GameState, battle_type: StringName, rival_id: StringName = &"", player_declared: bool = false, surprise: bool = false) -> BattleField:
	var battle := BattleField.new()
	battle.battle_type = battle_type
	battle.rival_id = rival_id
	battle.player_declared = player_declared
	battle.round_cap = int(TYPES[battle_type]["round_cap"])
	var coeff: int = Era.coeff(state.generation)
	battle.expected_reward = int(TYPES[battle_type]["reward_per_coeff"]) * coeff
	if battle_type == &"civil_war":
		var rival := Rivals.find(state, rival_id)
		battle.expected_reward = int(rival.power * 2.0)
		if player_declared and state.policies.has(&"holy_war"):
			battle.expected_reward = int(battle.expected_reward * 1.5)
	_roll_waves(state, battle)
	battle.intel_visible = intel_covers(state) and not (battle_type == &"hidden_battle" and surprise)
	battle.see_deployment = state.policies.has(&"satellite_surveillance")
	battle.available = state.deck.duplicate()
	if bool(state.flags.get(&"enemy_psyops_next_battle", false)):
		battle.psyops_active = true   # D16: 命中率減益 (magnitude lands with W13 rewiring)
		state.flags.erase(&"enemy_psyops_next_battle")
	_arrive_waves(battle)   # wave 1 (敵方開場單位 became wave 1)
	return battle


static func defection_gate(state: GameState) -> int:
	var mult: int = 5 if state.policies.has(&"cultural_export") else 8
	return mult * Era.index(state.generation)


static func can_defect(state: GameState, battle: BattleField) -> bool:
	# 投誠 only fits small-scale narrative battles (一般地圖戰), opening only (round 1).
	return battle.battle_type == &"field_battle" and battle.round == 1 \
		and state.culture >= defection_gate(state)


static func defect(state: GameState, battle: BattleField) -> Dictionary:
	if not can_defect(state, battle):
		return {"ok": false, "reason": &"cannot_defect"}
	battle.outcome = &"defected"
	return {"ok": true, "reason": &""}


# --- player actions (all at the round boundary; no input during playback, D6) ---

static func card_cost(state: GameState, battle: BattleField, instance: Cards.CardInstance) -> int:
	var cost: int = Cards.military_cost_of(state, instance)
	if battle.cost_discount_rounds > 0:
		cost -= 1
	return maxi(cost, 0)


static func deploy(state: GameState, battle: BattleField, available_index: int) -> Dictionary:
	# 軍費 is the ONLY gate and it never blocks (D1/D3): treasury just goes negative.
	if battle.outcome != &"":
		return {"ok": false, "reason": &"battle_over"}
	var instance: Cards.CardInstance = battle.available[available_index]
	var entry: Dictionary = Cards.card(instance.id)
	# a damaged (待修) fort still occupies its field slot — count all fielded forts
	if entry["class"] == &"fortification" and battle.player_forts.size() >= FORT_LIMIT:
		return {"ok": false, "reason": &"fort_limit"}
	var cost: int = card_cost(state, battle, instance)
	state.treasury -= cost   # 軍費可扣到負
	battle.spent += cost
	battle.available.remove_at(available_index)
	if entry["class"] == &"mechanical":
		battle.mechanical_played = true
	match entry["class"]:
		&"fortification":
			battle.player_forts.append(_fort_from_card(instance))
		&"skill":
			_cast_skill(state, battle, instance)
			if bool(entry["destroyed_on_use"]):
				Cards.destroy_permanently(state, instance.id)
			# 用後消耗: non-policy skills just don't return this battle
		_:
			battle.player_units.append(_unit_from_card(state, instance))
	return {"ok": true, "reason": &"", "cost": cost}


static func concede(battle: BattleField) -> void:
	# 還有未出卡但選擇不出 — a legal voluntary concession; consequence identical to 判輸 (D3).
	battle.conceded = true


static func retreat(state: GameState, battle: BattleField) -> Dictionary:
	# 隨時可退: 10×係數, 永久 +2 人口; spent stays sunk. Disabled types are enforced by the
	# caller/UI (riot, democracy_blood, world war — 戰鬥.md 撤軍).
	var cost: int = RETREAT_COST_BASE * Era.coeff(state.generation)
	state.treasury -= cost
	state.population += RETREAT_POP
	battle.outcome = &"retreat"
	return {"cost": cost, "population": RETREAT_POP}


# --- round resolution: one fixed tick window, full timeline before any animation (D6) ---

static func end_round(state: GameState, battle: BattleField) -> Dictionary:
	if battle.outcome != &"":
		return {"outcome": battle.outcome, "events": []}
	var events: Array[Dictionary] = []
	_repair_forts(battle, events)
	_refresh_player_stats(state, battle)
	# 爛仗時候才宣揚愛與和平: after round 5, destroy one non-leader enemy.
	if battle.love_and_peace_armed and battle.round >= 5:
		_destroy_one_non_leader(battle, events, 0)
		battle.love_and_peace_armed = false
	_resolve_window(state, battle, events)
	var kills: int = _sweep_dead(battle.enemy_units)
	var losses: int = _sweep_dead(battle.player_units)
	_check_exhaustion(battle)
	if battle.outcome == &"" and battle.round >= battle.round_cap:
		battle.outcome = &"loss"   # 判輸＝耗盡, same consequence (D3)
	if battle.outcome == &"":
		battle.round += 1
		_arrive_waves(battle)      # next wave stacks on the remnant (D4)
		if battle.attack_buff_rounds > 0:
			battle.attack_buff_rounds -= 1
		if battle.cost_discount_rounds > 0:
			battle.cost_discount_rounds -= 1
	battle.last_timeline = events
	return {"round": battle.round, "events": events, "kills": kills, "losses": losses,
			"outcome": battle.outcome}


static func finish(state: GameState, battle: BattleField) -> Dictionary:
	# Apply the outcome's economy/system consequences. Turn/sim calls this once per battle.
	var report: Dictionary = {
		"battle_type": battle.battle_type, "outcome": battle.outcome,
		"spent": battle.spent, "merit": battle.merit,
	}
	var won: bool = battle.outcome == &"win" or battle.outcome == &"defected"
	if battle.plunder > 0:
		state.treasury += battle.plunder
		report["plunder"] = battle.plunder
	match battle.battle_type:
		&"tax_battle", &"field_battle", &"hidden_battle":
			if won:
				state.treasury += battle.expected_reward
				report["reward"] = battle.expected_reward
		&"riot":
			if battle.mechanical_played:
				# 對自己人民出動戰爭機器，人民記得 — applies on every outcome.
				Happiness.adjust(state, -RIOT_MECH_HAPPINESS)
				report["suppression_happiness"] = -RIOT_MECH_HAPPINESS
			if battle.outcome == &"loss" or battle.outcome == &"retreat":
				report["riot_loss"] = Unrest.apply_riot_loss(state)
		&"democracy_blood":
			if battle.outcome == &"loss" or battle.outcome == &"retreat":
				state.flags[&"forced_democracy"] = true
				report["forced_democracy"] = true
		&"civil_war":
			if won:
				state.treasury += battle.expected_reward
				report["reward"] = battle.expected_reward
				report["war"] = Rivals.record_civil_war(state, battle.rival_id, true)
			else:
				var rival := Rivals.find(state, battle.rival_id)
				rival.power *= 1.05   # 判輸: 對手 power +5%
				report["war"] = Rivals.record_civil_war(state, battle.rival_id, false)
	# 戰後獎勵卡: 每場戰鬥結束必發, 勝敗皆然、七種類型皆然 (rolled + revealed; the caller
	# accepts via Cards.accept_reward or drops it — 卡牌.md 卡牌經濟).
	report["reward_instance"] = Cards.roll_reward(state)
	return report


# --- internals: waves ---

static func _roll_waves(state: GameState, battle: BattleField) -> void:
	# 波次的時點在開戰時於表列回合區間內抽定 (&"battle" track); 開戰前情報 reveals this roll.
	var coeff: int = Era.coeff(state.generation)
	var spec_waves: Array = TYPES[battle.battle_type]["waves"]
	for spec: Dictionary in spec_waves:
		var window: Array = spec["window"]
		var arrival: int = state.rng.randi_range(&"battle", int(window[0]), int(window[1]))
		var units: Array[Dictionary] = []
		if spec.has("share"):
			units = _regular_army_wave(state, battle, float(spec["share"]))
		else:
			for grade: StringName in (spec["grades"] as Array):
				units.append(_irregular_unit(state, grade, coeff, bool(spec["siege"])))
		if not units.is_empty():
			battle.waves.append({"round": arrival, "units": units})
	battle.waves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["round"]) < int(b["round"]))
	if battle.waves.is_empty():
		# tiny civil-war rival: still field one weakest regular in wave 1
		var weakest := _cheapest_regular_type(state)
		battle.waves.append({"round": 1,
			"units": [_regular_unit(state, battle, weakest)] as Array[Dictionary]})


static func _arrive_waves(battle: BattleField) -> void:
	while battle.next_wave < battle.waves.size() \
			and int(battle.waves[battle.next_wave]["round"]) <= battle.round:
		for unit: Dictionary in (battle.waves[battle.next_wave]["units"] as Array):
			battle.enemy_units.append(unit)
		battle.next_wave += 1


static func _irregular_unit(state: GameState, grade: StringName, coeff: int, siege: bool) -> Dictionary:
	# 非正規軍: anonymous tiers, 預設近戰列; 帶攻城 units sit in the ranged row (戰鬥.md).
	var stats: Array = GRADE_STATS[grade]
	return {
		"card_id": &"", "grade": grade, "regular": false, "faction": &"enemy",
		"attack": Difficulty.scale_enemy_stat(state, int(stats[0]) * coeff),
		"hp": Difficulty.scale_enemy_stat(state, int(stats[1]) * coeff),
		"strength": (int(stats[0]) + int(stats[1])) * coeff,
		"row": &"ranged" if siege else &"melee",
		"flags": ([&"siege"] if siege else []) as Array,
		"accuracy": ENEMY_ACCURACY, "dodge": ENEMY_DODGE, "speed": ENEMY_SPEED,
		"progress": 0.0, "instance": null,
	}


static func _regular_army_wave(state: GameState, battle: BattleField, share: float) -> Array[Dictionary]:
	# 正規軍 (對手文明): rival power × 0.5 × share becomes real-roster units at baseline
	# stats. Composition gap decided greedy strongest-first (docs/decisions.md, W12);
	# 國策限定 and support (no_attack) types stay out of the conversion roster.
	var rival := Rivals.find(state, battle.rival_id)
	var budget: float = rival.power * 0.5 * share
	var units: Array[Dictionary] = []
	for card_id: StringName in _regular_roster_desc(state):
		var strength: float = float(_type_strength(state, card_id))
		while budget >= strength:
			budget -= strength
			units.append(_regular_unit(state, battle, card_id))
	return units


static func _regular_roster_desc(state: GameState) -> Array[StringName]:
	# Unit types formed this era, strongest first (ties: catalog order).
	var idx: int = Era.index(state.generation)
	var roster: Array[StringName] = []
	for card_id: StringName in CardsData.CARDS.keys():
		var entry: Dictionary = CardsData.CARDS[card_id]
		if not Cards.is_unit(card_id) or entry["source_kind"] == &"policy":
			continue
		if (entry["flags"] as Array).has(&"no_attack") or not Cards.has_form(card_id, idx):
			continue
		roster.append(card_id)
	roster.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _type_strength(state, a) > _type_strength(state, b))
	return roster


static func _cheapest_regular_type(state: GameState) -> StringName:
	var roster := _regular_roster_desc(state)
	if roster.is_empty():
		return &"infantry"
	return roster[roster.size() - 1]


static func _type_strength(state: GameState, card_id: StringName) -> int:
	var entry: Dictionary = CardsData.CARDS[card_id]
	return (int(entry["attack"]) + int(entry["hp"])) * Era.coeff(state.generation)


static func _regular_unit(state: GameState, battle: BattleField, card_id: StringName) -> Dictionary:
	# Real roster type at era-baseline 攻/血, engine-default三值, no roll/growth (WW3).
	var entry: Dictionary = CardsData.CARDS[card_id]
	var coeff: int = Era.coeff(state.generation)
	var attack: int = Difficulty.scale_enemy_stat(state, int(entry["attack"]) * coeff)
	if battle.rival_id != &"":
		var rival := Rivals.find(state, battle.rival_id)
		# 被心戰過的對手: 攻擊力照累計折扣打折 (−10%/次, 7折封頂)
		attack = maxi(int(round(float(attack) * Rivals.attack_multiplier(rival))), 1)
	return {
		"card_id": card_id, "grade": &"", "regular": true, "faction": &"enemy",
		"attack": attack,
		"hp": Difficulty.scale_enemy_stat(state, int(entry["hp"]) * coeff),
		"strength": _type_strength(state, card_id),
		"row": entry["row"], "flags": (entry["flags"] as Array).duplicate(),
		"accuracy": ENEMY_ACCURACY, "dodge": ENEMY_DODGE, "speed": ENEMY_SPEED,
		"progress": 0.0, "instance": null,
	}


# --- internals: units, forts, skills ---

static func _unit_from_card(state: GameState, instance: Cards.CardInstance) -> Dictionary:
	var entry: Dictionary = Cards.card(instance.id)
	return {
		"card_id": instance.id, "grade": &"", "regular": false, "faction": &"player",
		"attack": Cards.attack_of(instance), "hp": Cards.hp_of(instance),
		"strength": Cards.attack_of(instance) + Cards.hp_of(instance),
		"row": entry["row"], "flags": (entry["flags"] as Array).duplicate(),
		"accuracy": Cards.accuracy_of(state, instance),
		"dodge": Cards.dodge_of(state, instance),
		"speed": Cards.speed_of(state, instance),
		"progress": 0.0, "instance": instance,
	}


static func _refresh_player_stats(state: GameState, battle: BattleField) -> void:
	# Growth effects land 自下一回合生效 (D13): re-snapshot the quality three at every
	# boundary so mid-battle medals (W13) apply from the next window automatically.
	for unit: Dictionary in battle.player_units:
		var instance: Cards.CardInstance = unit["instance"]
		if instance == null:
			continue
		unit["accuracy"] = Cards.accuracy_of(state, instance)
		unit["dodge"] = Cards.dodge_of(state, instance)
		unit["speed"] = Cards.speed_of(state, instance)


static func _fort_from_card(instance: Cards.CardInstance) -> Dictionary:
	var entry: Dictionary = Cards.card(instance.id)
	return {"card_id": instance.id, "flags": (entry["flags"] as Array).duplicate(),
			"damaged": false, "damaged_round": 0}


static func _repair_forts(battle: BattleField, events: Array[Dictionary]) -> void:
	# 工兵團在場時: absorbed forts turn damaged instead of consumed; engineers repair one
	# fortification per round starting the round AFTER it was damaged (戰鬥.md 工事卡).
	if not _has_engineer(battle.player_units):
		return
	for fort: Dictionary in battle.player_forts:
		if bool(fort["damaged"]) and int(fort["damaged_round"]) < battle.round:
			fort["damaged"] = false
			events.append({"tick": 0, "type": &"repair", "card_id": fort["card_id"]})
			return   # one per round


static func _has_engineer(units: Array[Dictionary]) -> bool:
	for unit: Dictionary in units:
		if int(unit["hp"]) > 0 and (unit["flags"] as Array).has(&"repairs_fortifications"):
			return true
	return false


static func _cast_skill(state: GameState, battle: BattleField, instance: Cards.CardInstance) -> void:
	var flags: Array = Cards.card(instance.id)["flags"]
	if flags.has(&"attack_buff_2_rounds"):
		battle.attack_buff_rounds = 2   # applied at fire time to every friendly unit
	elif flags.has(&"cost_discount_2_rounds"):
		battle.cost_discount_rounds = 2
	elif flags.has(&"destroy_non_leader_after_round_5"):
		battle.love_and_peace_armed = true
	elif flags.has(&"destroy_non_leader"):
		var events: Array[Dictionary] = []
		_destroy_one_non_leader(battle, events, 0)
		battle.last_timeline.append_array(events)
	elif flags.has(&"convert_non_leader"):
		for i: int in range(battle.enemy_units.size()):
			var enemy: Dictionary = battle.enemy_units[i]
			if _is_non_leader(enemy):
				battle.enemy_units.remove_at(i)
				enemy["faction"] = &"player"
				enemy["row"] = &"melee"
				battle.player_units.append(enemy)
				break


static func _is_non_leader(unit: Dictionary) -> bool:
	# 首領＝硬級; non-leader skills touch only weak/medium 非正規軍, never 正規軍 (卡牌.md).
	return not bool(unit["regular"]) and unit["grade"] != &"hard" and int(unit["hp"]) > 0


static func _destroy_one_non_leader(battle: BattleField, events: Array[Dictionary], tick: int) -> void:
	for unit: Dictionary in battle.enemy_units:
		if _is_non_leader(unit):
			unit["hp"] = 0
			battle.merit += int(unit["strength"])
			events.append({"tick": tick, "type": &"death", "victim": _unit_label(unit),
					"by": &"skill", "faction": &"enemy"})
			return


# --- internals: the tick window ---

static func _resolve_window(state: GameState, battle: BattleField, events: Array[Dictionary]) -> void:
	# Units act on their own attack speed via per-unit accumulators that carry across
	# rounds (speed 0.6 = an attack roughly every 1.67 windows). Within a tick, player
	# units fire before enemy units, each side in deploy order — fixed order is part of
	# the determinism contract (docs/implementation-notes.md).
	for tick: int in range(1, TICKS_PER_ROUND + 1):
		for unit: Dictionary in battle.player_units:
			_accumulate_and_fire(state, battle, unit, tick, events)
		for unit: Dictionary in battle.enemy_units:
			_accumulate_and_fire(state, battle, unit, tick, events)


static func _accumulate_and_fire(state: GameState, battle: BattleField, unit: Dictionary, tick: int, events: Array[Dictionary]) -> void:
	if int(unit["hp"]) <= 0 or float(unit["speed"]) <= 0.0:
		return   # the dead don't fire: 快的先打，先打的活下來 (D6)
	if (unit["flags"] as Array).has(&"no_attack") or int(unit["attack"]) <= 0:
		return
	unit["progress"] = float(unit["progress"]) + float(unit["speed"]) / float(TICKS_PER_ROUND)
	while float(unit["progress"]) >= 1.0 and int(unit["hp"]) > 0:
		unit["progress"] = float(unit["progress"]) - 1.0
		_fire(state, battle, unit, tick, events)


static func _fire(state: GameState, battle: BattleField, attacker: Dictionary, tick: int, events: Array[Dictionary]) -> void:
	var player_side: bool = attacker["faction"] == &"player"
	var defenders: Array[Dictionary] = battle.enemy_units if player_side else battle.player_units
	var defender_forts: Array[Dictionary] = battle.enemy_forts if player_side else battle.player_forts
	var flags: Array = attacker["flags"]
	var kind: StringName = &"melee"
	if attacker["row"] == &"ranged":
		kind = &"ranged"
	elif attacker["row"] == &"air" or flags.has(&"air_strike"):
		kind = &"air"
	# 帶攻城／空襲者可拆工事: prefer demolishing while any fortification stands (W3 gap
	# decision, carried over). Demolition destroys outright — no engineer repair.
	if (flags.has(&"siege") or flags.has(&"air_strike")) and not defender_forts.is_empty():
		var demolished: Dictionary = defender_forts[0]
		defender_forts.remove_at(0)
		events.append({"tick": tick, "type": &"demolish", "by": _unit_label(attacker),
				"card_id": demolished["card_id"]})
		return
	# fortification absorbs: 盾陣 one melee, 防空 one ranged/air (無視攻擊力). With
	# engineers on field it turns damaged (待修) instead of being consumed.
	var absorb_flag: StringName = &"blocks_melee_once" if kind == &"melee" else &"blocks_ranged_once"
	var defender_is_player: bool = not player_side
	for i: int in range(defender_forts.size()):
		var fort: Dictionary = defender_forts[i]
		if bool(fort["damaged"]) or not (fort["flags"] as Array).has(absorb_flag):
			continue
		var defenders_units: Array[Dictionary] = battle.player_units if defender_is_player else battle.enemy_units
		if defender_is_player and _has_engineer(defenders_units):
			fort["damaged"] = true
			fort["damaged_round"] = battle.round
		else:
			defender_forts.remove_at(i)   # 擋完即消耗
		events.append({"tick": tick, "type": &"absorb", "card_id": fort["card_id"],
				"by": _unit_label(attacker)})
		return
	var target: Dictionary = _pick_target(defenders, kind)
	if target.is_empty():
		return
	# accuracy roll, then dodge roll — both on the &"battle" track, in this order.
	if not state.rng.chance(&"battle", float(attacker["accuracy"]) / 100.0):
		events.append({"tick": tick, "type": &"miss", "by": _unit_label(attacker),
				"target": _unit_label(target)})
		return
	if state.rng.chance(&"battle", float(target["dodge"]) / 100.0):
		events.append({"tick": tick, "type": &"dodge", "by": _unit_label(target),
				"attacker": _unit_label(attacker)})
		# W13: dodge XP accrues here (被攻擊且活下來).
		return
	var damage: int = int(attacker["attack"])
	if player_side and battle.attack_buff_rounds > 0:
		damage += 1   # 軍歌: 兩回合內全體 +1 攻
	target["hp"] = int(target["hp"]) - damage
	events.append({"tick": tick, "type": &"hit", "by": _unit_label(attacker),
			"target": _unit_label(target), "damage": damage})
	# W13: accuracy XP accrues here (出手攻擊).
	if int(target["hp"]) <= 0:
		events.append({"tick": tick, "type": &"death", "victim": _unit_label(target),
				"by": _unit_label(attacker), "faction": target["faction"]})
		if player_side and target["faction"] == &"enemy":
			battle.merit += int(target["strength"])   # 戰功＝清除的實力總和 (攻+血)
			if (attacker["flags"] as Array).has(&"plunder"):
				battle.plunder += 5 * Era.coeff(state.generation)   # 掠奪: 它清除的單位


static func _pick_target(defenders: Array[Dictionary], kind: StringName) -> Dictionary:
	# 近戰列互擊; 遠程列自由選目標; 空襲任選. Focus fire in deploy order (W3 gap decision);
	# melee falls back to any living unit once the enemy melee row is cleared.
	if kind == &"melee":
		for unit: Dictionary in defenders:
			if int(unit["hp"]) > 0 and unit["row"] == &"melee":
				return unit
	for unit: Dictionary in defenders:
		if int(unit["hp"]) > 0:
			return unit
	return {}


static func _unit_label(unit: Dictionary) -> StringName:
	return unit["card_id"] if unit["card_id"] != &"" else unit["grade"]


static func _sweep_dead(units: Array[Dictionary]) -> int:
	var removed: int = 0
	for i: int in range(units.size() - 1, -1, -1):
		if int(units[i]["hp"]) > 0:
			continue
		var dead: Dictionary = units[i]
		units.remove_at(i)
		removed += 1
		var instance: Cards.CardInstance = dead["instance"]
		if instance != null:
			Cards.wipe_growth(instance)   # D11: the institution survives, the veterans don't
	return removed


# --- internals: victory (exhaustion, D3) ---

static func _check_exhaustion(battle: BattleField) -> void:
	var enemy_exhausted: bool = battle.enemy_units.is_empty() \
			and battle.next_wave >= battle.waves.size()
	var player_committed_out: bool = battle.available.is_empty() or battle.conceded
	var player_exhausted: bool = battle.player_units.is_empty() and player_committed_out
	if enemy_exhausted and _has_land(battle.player_units):
		battle.outcome = &"win"   # 場上仍有陸軍部隊則勝 (只剩空中單位不算)
	elif player_exhausted:
		# Includes the mutual-exhaustion edge: no land force claims the field → 敗北
		# for the player (conservative, docs/decisions.md W12).
		battle.outcome = &"loss"


static func _has_land(units: Array[Dictionary]) -> bool:
	for unit: Dictionary in units:
		if unit["row"] != &"air" and not (unit["flags"] as Array).has(&"non_land"):
			return true
	return false
