class_name Battle
extends RefCounted
# 戰鬥 (design/戰鬥.md): single battlefield, auto-deploy by combat attribute
# (fortification line / melee row / ranged row / air), per-round both sides play,
# simultaneous resolution, symmetric win check (cleared side loses IF the other still
# holds LAND units). Money is the only pressure: military cost may push treasury negative.
#
# Driver decisions (design gaps): opening hand 4 (+1 military region, −1 enemy psyops),
# draw 1 per round, focus-fire targeting in deploy order, siege/air demolish enemy
# fortifications before attacking units, enemy plays its whole opening at start.

const OPENING_HAND: int = 4
const RETREAT_COST_BASE: int = 10
const RETREAT_POP: int = 2
const FORT_LIMIT: int = 2

const GRADE_STATS: Dictionary = {&"weak": [1, 2], &"medium": [2, 4], &"hard": [3, 6]}

# battle_type -> {round_cap, reward_per_coeff, first_seen_card, enemy spec…}
const TYPES: Dictionary = {
	&"tax_battle": {"round_cap": 6, "reward_per_coeff": 15, "card_reward": false},
	&"field_battle": {"round_cap": 8, "reward_per_coeff": 25, "card_reward": true},
	&"hidden_battle": {"round_cap": 8, "reward_per_coeff": 45, "card_reward": true},
	&"riot": {"round_cap": 8, "reward_per_coeff": 0, "card_reward": false},
	&"democracy_blood": {"round_cap": 8, "reward_per_coeff": 0, "card_reward": false},
	&"civil_war": {"round_cap": 10, "reward_per_coeff": 0, "card_reward": false},
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
	var player_units: Array[Dictionary] = []
	var enemy_units: Array[Dictionary] = []
	var player_forts: Array[Dictionary] = []
	var enemy_forts: Array[Dictionary] = []
	var hand: Array = []                  # Array[Cards.CardInstance]
	var draw_pile: Array = []
	var discard_pile: Array = []
	var spent: int = 0                    # 本場已燒軍費 (UI shows vs expected_reward)
	var expected_reward: int = 0
	var merit: int = 0                    # 戰功: Σ(attack+hp) of units we cleared
	var plunder: int = 0
	var attack_buff_rounds: int = 0       # 軍歌
	var cost_discount_rounds: int = 0     # 這些破洞不影響功能
	var love_and_peace_armed: bool = false
	var intel_visible: bool = false       # pre-battle enemy pool visible
	var see_deployment: bool = false      # 衛星監控


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
	_build_enemy(state, battle)
	battle.intel_visible = intel_covers(state) and not (battle_type == &"hidden_battle" and surprise)
	battle.see_deployment = state.policies.has(&"satellite_surveillance")
	# deck -> shuffled draw pile (track &"battle"), opening hand
	battle.draw_pile = state.deck.duplicate()
	_shuffle(state, battle.draw_pile)
	var hand_size: int = OPENING_HAND + Operations.opening_hand_bonus(state)
	if bool(state.flags.get(&"enemy_psyops_next_battle", false)):
		hand_size -= 1   # 文化國心戰: 下場戰開場手牌 −1
		state.flags.erase(&"enemy_psyops_next_battle")
	for i: int in range(hand_size):
		_draw(battle)
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


# --- player actions ---

static func card_cost(state: GameState, battle: BattleField, instance: Cards.CardInstance) -> int:
	var cost: int = Cards.military_cost_of(state, instance)
	if battle.cost_discount_rounds > 0:
		cost -= 1
	return maxi(cost, 0)


static func play_card(state: GameState, battle: BattleField, hand_index: int) -> Dictionary:
	if battle.outcome != &"":
		return {"ok": false, "reason": &"battle_over"}
	var instance: Cards.CardInstance = battle.hand[hand_index]
	var entry: Dictionary = Cards.card(instance.id)
	if entry["class"] == &"fortification" and battle.player_forts.size() >= FORT_LIMIT:
		return {"ok": false, "reason": &"fort_limit"}
	var cost: int = card_cost(state, battle, instance)
	state.treasury -= cost   # 軍費可扣到負
	battle.spent += cost
	battle.hand.remove_at(hand_index)
	match entry["class"]:
		&"fortification":
			battle.player_forts.append(_fort_from_card(instance))
		&"skill":
			_cast_skill(state, battle, instance)
			if bool(entry["destroyed_on_use"]):
				Cards.destroy_permanently(state, instance.id)
			# 用後消耗: non-policy skills just don't return this battle (no discard)
		_:
			var unit := _unit_from_card(state, battle, instance)
			battle.player_units.append(unit)
			if unit["flags"].has(&"fills_trench"):
				_fill_one_trench(battle.enemy_forts)
	return {"ok": true, "reason": &"", "cost": cost}


static func retreat(state: GameState, battle: BattleField) -> Dictionary:
	# 隨時可退: 10×係數, 永久 +2 人口; spent stays sunk.
	var cost: int = RETREAT_COST_BASE * Era.coeff(state.generation)
	state.treasury -= cost
	state.population += RETREAT_POP
	battle.outcome = &"retreat"
	return {"cost": cost, "population": RETREAT_POP}


# --- round resolution ---

static func end_round(state: GameState, battle: BattleField) -> Dictionary:
	if battle.outcome != &"":
		return {"outcome": battle.outcome}
	# 爛仗時候才宣揚愛與和平: after round 5, destroy one non-leader enemy.
	if battle.love_and_peace_armed and battle.round >= 5:
		_destroy_one_non_leader(battle)
		battle.love_and_peace_armed = false
	var report: Dictionary = {"round": battle.round, "kills": 0, "losses": 0}
	_resolve_combat(state, battle, report)
	_check_victory(battle)
	if battle.outcome == &"" and battle.round >= battle.round_cap:
		battle.outcome = &"loss"   # 判輸＝回合上限: auto-retreat, sunk costs
	if battle.outcome == &"":
		battle.round += 1
		if battle.attack_buff_rounds > 0:
			battle.attack_buff_rounds -= 1
		if battle.cost_discount_rounds > 0:
			battle.cost_discount_rounds -= 1
		_draw(battle)
	report["outcome"] = battle.outcome
	return report


static func finish(state: GameState, battle: BattleField) -> Dictionary:
	# Apply the outcome's economy/system consequences. Turn calls this once per battle.
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
				if bool(TYPES[battle.battle_type]["card_reward"]):
					report["reward_card"] = _roll_reward_card(state)
		&"riot":
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
	return report


# --- internals ---

static func _shuffle(state: GameState, pile: Array) -> void:
	# Fisher-Yates on the &"battle" track (Array.shuffle() uses the global RNG — never).
	for i: int in range(pile.size() - 1, 0, -1):
		var j: int = state.rng.randi_range(&"battle", 0, i)
		var tmp: Variant = pile[i]
		pile[i] = pile[j]
		pile[j] = tmp


static func _draw(battle: BattleField) -> void:
	if battle.draw_pile.is_empty():
		battle.draw_pile = battle.discard_pile
		battle.discard_pile = []
	if not battle.draw_pile.is_empty():
		battle.hand.append(battle.draw_pile.pop_back())


static func _unit_from_card(state: GameState, battle: BattleField, instance: Cards.CardInstance) -> Dictionary:
	var entry: Dictionary = Cards.card(instance.id)
	var flags: Array = (entry["flags"] as Array).duplicate()
	if flags.has(&"tank_from_modern") and instance.tier >= 5:
		flags.append(&"crosses_trench")
	var attack: int = Cards.attack_of(instance)
	if battle.attack_buff_rounds > 0:
		attack += 1   # 軍歌 applies to units fielded while it's active
	return {
		"card_id": instance.id, "attack": attack, "hp": Cards.hp_of(instance),
		"row": entry["row"], "flags": flags, "leader": false,
	}


static func _fort_from_card(instance: Cards.CardInstance) -> Dictionary:
	var entry: Dictionary = Cards.card(instance.id)
	return {"card_id": instance.id, "flags": (entry["flags"] as Array).duplicate(), "filled": false}


static func _cast_skill(state: GameState, battle: BattleField, instance: Cards.CardInstance) -> void:
	var flags: Array = Cards.card(instance.id)["flags"]
	if flags.has(&"attack_buff_2_rounds"):
		battle.attack_buff_rounds = 2
		for unit: Dictionary in battle.player_units:
			unit["attack"] = int(unit["attack"]) + 1
	elif flags.has(&"cost_discount_2_rounds"):
		battle.cost_discount_rounds = 2
	elif flags.has(&"destroy_non_leader_after_round_5"):
		battle.love_and_peace_armed = true
	elif flags.has(&"destroy_non_leader"):
		_destroy_one_non_leader(battle)
	elif flags.has(&"convert_weak_enemy"):
		for i: int in range(battle.enemy_units.size()):
			var enemy: Dictionary = battle.enemy_units[i]
			if enemy.get("grade", &"") == &"weak":
				battle.enemy_units.remove_at(i)
				enemy["row"] = &"melee"
				battle.player_units.append(enemy)
				break


static func _destroy_one_non_leader(battle: BattleField) -> void:
	for i: int in range(battle.enemy_units.size()):
		if not bool(battle.enemy_units[i].get("leader", false)):
			var dead: Dictionary = battle.enemy_units[i]
			battle.merit += int(dead["attack"]) + int(dead["hp"])
			battle.enemy_units.remove_at(i)
			return


static func _fill_one_trench(forts: Array[Dictionary]) -> bool:
	for fort: Dictionary in forts:
		if (fort["flags"] as Array).has(&"blocks_melee_contact") and not bool(fort["filled"]):
			fort["filled"] = true
			return true
	return false


static func _has_active_trench(forts: Array[Dictionary]) -> bool:
	for fort: Dictionary in forts:
		if (fort["flags"] as Array).has(&"blocks_melee_contact") and not bool(fort["filled"]):
			return true
	return false


static func _build_enemy(state: GameState, battle: BattleField) -> void:
	var coeff: int = Era.coeff(state.generation)
	match battle.battle_type:
		&"tax_battle":
			_add_enemies(state, battle, [&"weak", &"weak"], coeff, false)
		&"field_battle":
			_add_enemies(state, battle, [&"medium", &"medium", &"weak"], coeff, false)
		&"hidden_battle":
			_add_enemies(state, battle, [&"hard", &"hard"], coeff, true)
		&"riot":
			_add_enemies(state, battle, [&"medium", &"medium"], coeff, false)
		&"democracy_blood":
			_add_enemies(state, battle, [&"hard", &"hard", &"medium"], coeff, false)
		&"civil_war":
			_build_civil_war_enemy(state, battle, coeff)


static func _add_enemies(state: GameState, battle: BattleField, grades: Array, coeff: int, siege: bool) -> void:
	for grade: StringName in grades:
		var stats: Array = GRADE_STATS[grade]
		var flags: Array = [&"siege"] if siege else []
		battle.enemy_units.append({
			"grade": grade,
			"attack": Difficulty.scale_enemy_stat(state, int(stats[0]) * coeff),
			"hp": Difficulty.scale_enemy_stat(state, int(stats[1]) * coeff),
			"row": &"melee", "flags": flags, "leader": false,
		})


static func _build_civil_war_enemy(state: GameState, battle: BattleField, coeff: int) -> void:
	# 總實力 ≈ P×0.5, greedy 硬>中>弱 (strength = (attack+hp)×coeff); hard units carry siege.
	var rival := Rivals.find(state, battle.rival_id)
	var budget: float = rival.power * 0.5
	var mult: float = Rivals.attack_multiplier(rival)   # 心戰累計折扣
	for grade: StringName in [&"hard", &"medium", &"weak"]:
		var stats: Array = GRADE_STATS[grade]
		var strength: float = float((int(stats[0]) + int(stats[1])) * coeff)
		while budget >= strength:
			budget -= strength
			var flags: Array = [&"siege"] if grade == &"hard" else []
			battle.enemy_units.append({
				"grade": grade,
				"attack": maxi(int(round(float(Difficulty.scale_enemy_stat(state, int(stats[0]) * coeff)) * mult)), 1),
				"hp": Difficulty.scale_enemy_stat(state, int(stats[1]) * coeff),
				"row": &"melee", "flags": flags, "leader": false,
			})
	if battle.enemy_units.is_empty():   # tiny rival still fields one discounted weak unit
		var stats: Array = GRADE_STATS[&"weak"]
		battle.enemy_units.append({
			"grade": &"weak", "attack": maxi(int(round(float(int(stats[0]) * coeff) * mult)), 1),
			"hp": int(stats[1]) * coeff, "row": &"melee", "flags": [], "leader": false,
		})


static func _resolve_combat(state: GameState, battle: BattleField, report: Dictionary) -> void:
	# Simultaneous: collect both sides' hits on snapshots, then apply.
	var player_hits: Array[Dictionary] = _plan_attacks(battle.player_units, battle.enemy_units, battle.enemy_forts)
	var enemy_hits: Array[Dictionary] = _plan_attacks(battle.enemy_units, battle.player_units, battle.player_forts)
	_apply_hits(battle, player_hits, battle.enemy_units, battle.enemy_forts, true)
	_apply_hits(battle, enemy_hits, battle.player_units, battle.player_forts, false)
	report["kills"] = _sweep_dead(state, battle, battle.enemy_units, true)
	report["losses"] = _sweep_dead(state, battle, battle.player_units, false)


static func _plan_attacks(attackers: Array[Dictionary], defenders: Array[Dictionary], defender_forts: Array[Dictionary]) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var forts_to_demolish: int = 0
	var trench_blocks: bool = _has_active_trench(defender_forts)
	for unit: Dictionary in attackers:
		var flags: Array = unit["flags"]
		if flags.has(&"no_attack") or int(unit["attack"]) <= 0:
			continue
		var kind: StringName = &"melee"
		if unit["row"] == &"ranged":
			kind = &"ranged"
		elif unit["row"] == &"air" or flags.has(&"air_strike"):
			kind = &"air"
		# siege/air prefer demolishing a fortification while any stands
		if (flags.has(&"siege") or flags.has(&"air_strike")) and forts_to_demolish < defender_forts.size():
			forts_to_demolish += 1
			hits.append({"demolish": true})
			continue
		if kind == &"melee":
			if trench_blocks and not flags.has(&"crosses_trench"):
				continue   # 壕溝: melee cannot make contact
			var target_row: StringName = &"melee"
			if flags.has(&"mobile") and _has_row(defenders, &"ranged"):
				target_row = &"ranged"   # 機動: 繞過近戰列直取遠程列
			hits.append({"demolish": false, "kind": &"melee", "damage": int(unit["attack"]), "row": target_row})
		else:
			hits.append({"demolish": false, "kind": kind, "damage": int(unit["attack"]), "row": &"any"})
	return hits


static func _has_row(units: Array[Dictionary], row: StringName) -> bool:
	for unit: Dictionary in units:
		if unit["row"] == row:
			return true
	return false


static func _apply_hits(battle: BattleField, hits: Array[Dictionary], defenders: Array[Dictionary], defender_forts: Array[Dictionary], player_is_attacker: bool) -> void:
	for hit: Dictionary in hits:
		if bool(hit["demolish"]):
			if not defender_forts.is_empty():
				defender_forts.remove_at(0)
			continue
		# fortification absorbs: 盾陣 one melee, 防空 one ranged/air (ignores attack value)
		var absorb_flag: StringName = &"blocks_melee_once" if hit["kind"] == &"melee" else &"blocks_ranged_once"
		var absorbed: bool = false
		for i: int in range(defender_forts.size()):
			if (defender_forts[i]["flags"] as Array).has(absorb_flag):
				defender_forts.remove_at(i)   # 擋完即消耗
				absorbed = true
				break
		if absorbed:
			continue
		var target: Dictionary = _pick_target(defenders, hit["row"])
		if target.is_empty():
			continue
		target["hp"] = int(target["hp"]) - int(hit["damage"])
		if player_is_attacker:
			target["last_hit_by_player"] = true


static func _pick_target(defenders: Array[Dictionary], row: StringName) -> Dictionary:
	# Focus fire in deploy order; fall back to any living unit when the row is empty.
	for unit: Dictionary in defenders:
		if int(unit["hp"]) > 0 and (row == &"any" or unit["row"] == row):
			return unit
	for unit: Dictionary in defenders:
		if int(unit["hp"]) > 0:
			return unit
	return {}


static func _sweep_dead(state: GameState, battle: BattleField, units: Array[Dictionary], enemy_side: bool) -> int:
	var removed: int = 0
	for i: int in range(units.size() - 1, -1, -1):
		if int(units[i]["hp"]) > 0:
			continue
		var dead: Dictionary = units[i]
		units.remove_at(i)
		removed += 1
		if enemy_side and bool(dead.get("last_hit_by_player", false)):
			# 戰功＝清除的敵方單位實力總和 (實力＝攻+血 at full grade values)
			var stats: Array = GRADE_STATS.get(dead.get("grade", &"weak"), [1, 2])
			var coeff: int = Era.coeff(state.generation)
			battle.merit += (int(stats[0]) + int(stats[1])) * coeff
			if _player_has_plunder(battle):
				battle.plunder += 5 * coeff   # 私掠傭兵團: 掠奪
	return removed


static func _player_has_plunder(battle: BattleField) -> bool:
	for unit: Dictionary in battle.player_units:
		if (unit["flags"] as Array).has(&"plunder"):
			return true
	return false


static func _check_victory(battle: BattleField) -> void:
	var player_land: bool = _has_land(battle.player_units)
	var enemy_land: bool = _has_land(battle.enemy_units)
	var enemy_any: bool = not battle.enemy_units.is_empty()
	var player_any: bool = not battle.player_units.is_empty()
	if not enemy_any and player_land:
		battle.outcome = &"win"
	elif not player_any and enemy_land:
		battle.outcome = &"loss"


static func _has_land(units: Array[Dictionary]) -> bool:
	for unit: Dictionary in units:
		if unit["row"] != &"air" and not (unit["flags"] as Array).has(&"non_land"):
			return true
	return false


static func _roll_reward_card(state: GameState) -> StringName:
	# 戰鬥首見卡: a card the player hasn't unlocked yet; stored for the take/skip choice.
	var candidates: Array[StringName] = []
	for card_id: StringName in CardsData.CARDS.keys():
		var entry: Dictionary = CardsData.CARDS[card_id]
		if entry["source_kind"] == &"policy" or entry["source_kind"] == &"legacy":
			continue   # 限定卡 never drop as random rewards
		if state.unlocked_cards.has(card_id):
			continue
		if Era.index(state.generation) < int(entry["min_era"]):
			continue
		candidates.append(card_id)
	if candidates.is_empty():
		return &""
	var picked: StringName = state.rng.pick(&"battle", candidates)
	state.flags[&"pending_reward_card"] = picked
	return picked
