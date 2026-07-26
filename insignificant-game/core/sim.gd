class_name Sim
extends RefCounted
# Scripted auto-player: drives Turn through full 50-generation runs for invariant tests
# and balance telemetry (the three sensitive knobs: BP curve, escalation 0.25, unrest
# weights). The bot is deliberately simple — a competent-but-greedy baseline player.

const SAFETY_CAP: int = 60
const DEMOCRACY_ENTRY_GEN: int = 38
const POP_COMFORT: int = 20   # disband-for-population target (base pop cap; tax ≈ 20/gen)
const BATTLE_ROUND_GUARD: int = 200   # uncapped-battle backstop (see _drive_battle)

const BUILD_ORDER: Array = [
	[&"region", &"livelihood"], [&"building", &"housing"], [&"building", &"food"],
	[&"region", &"finance"], [&"building", &"commerce"], [&"building", &"medical"],
	[&"region", &"culture"], [&"building", &"arts"],
	[&"region", &"academic"], [&"building", &"school"],
	[&"region", &"military"], [&"building", &"barracks"],
	[&"building", &"bank"], [&"building", &"media"], [&"building", &"arsenal"],
	[&"building", &"astronomy"], [&"building", &"debt_office"],
]
const POLICY_PRIORITY: Array[StringName] = [
	&"centralization", &"bureaucracy", &"hundred_schools", &"enlightened_absolutism",
	&"writing_calendar", &"ancestor_worship", &"scout_camp", &"mass_media",
]
const UPGRADE_PRIORITY: Array[StringName] = [&"commerce", &"housing", &"school", &"arts", &"bank"]


static func run(seed_value: int, difficulty: StringName = &"normal") -> Dictionary:
	var state := GameState.new_run(seed_value, difficulty)
	Rivals.setup(state)
	Cards.starting_deck(state)
	var ending: Dictionary = {"over": false, "kind": &"stuck"}
	while true:
		var begin := Turn.begin_generation(state)
		if begin.has("world_war"):
			_world_war(state)
		elif begin.has("democracy"):
			Democracy.generation_step(state)
		else:
			_operate(state)
			var nodes := Turn.route(state)
			_resolve_node(state, _pick_node(nodes))
			if Turn.roll_unrest_battle(state):
				_handle_unrest(state)
		var settled := Turn.settle(state)
		if bool((settled["ending"] as Dictionary)["over"]):
			ending = settled["ending"]
			break
		if state.generation > SAFETY_CAP:
			break
		if not state.is_democracy and state.generation >= DEMOCRACY_ENTRY_GEN \
				and Democracy.unlocked(state):
			Democracy.enter(state, true)
	return {"ending": ending, "state": state, "generations": state.log.size()}


# --- operate-phase bot ---

static func _operate(state: GameState) -> void:
	var debt_floor: int = -30 * Era.coeff(state.generation)
	_grow_population(state, debt_floor)
	_spend_medals(state)
	var progressed := true
	while state.bp > 0 and progressed:
		progressed = false
		for step: Array in BUILD_ORDER:
			if state.bp < 1:
				break
			var kind: StringName = step[0]
			var target: StringName = step[1]
			if kind == &"region" and not state.regions.has(target):
				if state.treasury - Operations.region_cost(state) >= debt_floor:
					progressed = bool(Operations.build_region(state, target)["ok"]) or progressed
			elif kind == &"building" and not state.buildings.has(target):
				if state.regions.has(BuildingData.LINES[target]["region"]) \
						and state.treasury - Operations.building_cost(state, target) >= debt_floor:
					progressed = bool(Operations.build_building(state, target)["ok"]) or progressed
		if state.bp >= 2 and _invest_policy(state):
			progressed = true
		if not progressed and state.bp >= 1:
			progressed = _upgrade_something(state, debt_floor)
	_unlock_cards(state)
	Operations.end_operate_phase(state)


static func _grow_population(state: GameState, debt_floor: int) -> void:
	# 起始人口 0 opening (營運.md/卡牌.md 起始牌組): the population engine starts by
	# disbanding personnel cards (+2 人口 each). Convert spare personnel (deck-order
	# first; battle rewards keep replenishing the deck) while population is below
	# comfort — Cards.disband itself guards the deck minimum.
	while state.population < POP_COMFORT and state.deck.size() > Cards.DECK_MINIMUM:
		if state.treasury - Cards.DISBAND_COST_BASE * Era.coeff(state.generation) < debt_floor:
			return
		var target: int = -1
		for i: int in range(state.deck.size()):
			if int(Cards.card((state.deck[i] as Cards.CardInstance).id)["disband_pop"]) > 0:
				target = i
				break
		if target < 0 or not bool(Cards.disband(state, target)["ok"]):
			return


static func _spend_medals(state: GameState) -> void:
	# D14: the bot routes the whole 兵營 stock to its strongest unit card (max 攻+血,
	# ties to deck order) — a deterministic "carry" pick; the stat routes by lane.
	while state.medals > 0:
		var best: int = -1
		var best_strength: int = -1
		for i: int in range(state.deck.size()):
			var instance: Cards.CardInstance = state.deck[i]
			if Cards.lane_stat(instance.id) == &"":
				continue
			var strength: int = Cards.attack_of(instance) + Cards.hp_of(instance)
			if strength > best_strength:
				best_strength = strength
				best = i
		if best < 0 or not bool(Operations.assign_medal(state, best)["ok"]):
			return


static func _invest_policy(state: GameState) -> bool:
	var amount: int = mini(2 - state.policy_bp_this_gen, state.bp - 1)
	if amount < 1:
		return false
	var target: StringName = state.policy_in_progress
	if target == &"":
		var open := Policy.available(state)
		for wanted: StringName in POLICY_PRIORITY:
			if open.has(wanted):
				target = wanted
				break
		if target == &"" and not open.is_empty():
			target = open[0]
	if target == &"":
		return false
	return bool(Policy.invest(state, target, amount)["ok"])


static func _upgrade_something(state: GameState, debt_floor: int) -> bool:
	for line_id: StringName in UPGRADE_PRIORITY:
		if state.buildings.has(line_id) \
				and state.treasury - Operations.upgrade_cost(state, line_id) >= debt_floor:
			if bool(Operations.upgrade_building(state, line_id)["ok"]):
				return true
	return false


static func _unlock_cards(state: GameState) -> void:
	if state.unlocked_cards.size() >= 5:
		return
	for card_id: StringName in [&"archers", &"cavalry", &"elite_forces", &"war_song"]:
		if state.treasury < Cards.unlock_cost(state):
			return
		if bool(Cards.can_unlock(state, card_id)["ok"]):
			Cards.unlock(state, card_id)


# --- route/node bot ---

static func _pick_node(nodes: Array[Dictionary]) -> Dictionary:
	for node: Dictionary in nodes:   # injected wars are mandatory in spirit — fight them
		if node["battle_type"] == &"civil_war":
			return node
	for node: Dictionary in nodes:
		if node["content"] == &"opportunity":
			return node
	return nodes[0]


static func _resolve_node(state: GameState, node: Dictionary) -> void:
	if node["content"] == &"opportunity":
		var opportunity: StringName = MapNodes.roll_opportunity(state)
		MapNodes.resolve_opportunity(state, opportunity, _opportunity_choice(state, opportunity))
		return
	var battle := Battle.start(
		state, node["battle_type"],
		node.get("rival_id", &""), bool(node.get("player_declared", false)),
		bool(node.get("surprise", false)))
	_fight(state, battle)


static func _opportunity_choice(state: GameState, opportunity: StringName) -> StringName:
	match opportunity:
		&"merchant":
			return &"take_money"
		&"refugee":
			if state.happiness >= 68:
				return &"accept"
			if state.treasury > 20 * Era.coeff(state.generation):
				return &"pay"
			return &"refuse"
		&"disaster":
			return &"endure"
	return &"accept"   # national_treasure


static func _fight(state: GameState, battle: Battle.BattleField) -> void:
	# Minimal W12 policy (no hand: any unplayed card, 軍費-gated by bot prudence only —
	# W14 owns the real tempo-aware auto-player).
	if Battle.can_defect(state, battle):
		Battle.defect(state, battle)
	_drive_battle(state, battle)
	_take_reward(state, Battle.finish(state, battle))


static func _world_war(state: GameState) -> void:
	# 世界大戰 is the same drive loop on the shared table: the bot deploys only its own
	# cards (allies auto-fight); no defect, no retreat (不可撤軍); WorldWar.finish settles
	# camps/reparations and issues the reward card.
	var battle := WorldWar.start(state)
	_drive_battle(state, battle)
	_take_reward(state, WorldWar.finish(state, battle))


static func _drive_battle(state: GameState, battle: Battle.BattleField) -> void:
	# Tempo policy (最小軍費 as a strength race): each boundary, field the cheapest unit
	# cards until our fielded 攻+血 matches the enemy's — no more (waves may stack later,
	# but survivors persist and rewards don't scale with overspend). In riots, personnel
	# first: any mechanical deploy costs 幸福 −15 (鎮壓的手段有代價). If the bot won't hold
	# the field while enemies stand, it concedes — mandatory for uncapped battles (WW).
	var spend_floor: int = -50 * Era.coeff(state.generation)
	while battle.outcome == &"" and battle.round <= BATTLE_ROUND_GUARD:
		var deployed_any := false
		var played := true
		while played and _fielded_strength(battle.player_units) < _fielded_strength(battle.enemy_units):
			played = false
			var pick: int = _pick_deploy(state, battle, true) if battle.battle_type == &"riot" \
					else _pick_deploy(state, battle, false)
			if pick >= 0 and state.treasury - Battle.card_cost(state, battle, battle.available[pick]) >= spend_floor:
				played = bool(Battle.deploy(state, battle, pick)["ok"])
				deployed_any = deployed_any or played
		# Give up the field when the bot won't spend another coin on it: nothing fieldable
		# against a standing enemy, or remnants that can't reach each other at all (this bot has
		# no air answer, so melee-only survivors just stare at a bomber). 還有未出卡但選擇不出 is
		# a legal voluntary concession, and it lets the engine settle an uncapped war on the spot
		# instead of burning empty rounds.
		var overrun: bool = battle.player_units.is_empty() and not battle.enemy_units.is_empty()
		var frozen: bool = not Battle.has_pending_waves(battle) \
				and not Battle.can_act(battle, &"player") \
				and not Battle.can_act(battle, &"enemy")
		if not battle.conceded and not deployed_any and (overrun or frozen):
			Battle.concede(battle)
		Battle.end_round(state, battle)
	if battle.outcome == &"" and not battle.conceded:
		# Backstop for a grind the rules DO allow to continue (e.g. a lone sieger re-disabling a
		# fort an engineer keeps repairing). Never expected to fire; the concede rule above and
		# Battle's 僵局判定 resolve every frozen field first.
		Battle.concede(battle)
		Battle.end_round(state, battle)


static func _fielded_strength(units: Array[Dictionary]) -> int:
	var total: int = 0
	for unit: Dictionary in units:
		if int(unit["hp"]) > 0:
			total += int(unit["attack"]) + int(unit["hp"])
	return total


static func _pick_deploy(state: GameState, battle: Battle.BattleField, personnel_only: bool) -> int:
	# Cheapest deployable unit card; personnel_only pass falls back to any unit when no
	# personnel remain (a riot the bot can't win with people is still worth machines).
	var cheapest: int = -1
	var cheapest_cost: int = 1 << 30
	for i: int in range(battle.available.size()):
		var instance: Cards.CardInstance = battle.available[i]
		var cls: StringName = Cards.card(instance.id)["class"]
		if cls == &"skill" or cls == &"fortification":
			continue   # bot keeps it simple: units only
		if personnel_only and cls != &"personnel":
			continue
		var cost: int = Battle.card_cost(state, battle, instance)
		if cost < cheapest_cost:
			cheapest_cost = cost
			cheapest = i
	if cheapest < 0 and personnel_only:
		return _pick_deploy(state, battle, false)
	return cheapest


static func _take_reward(state: GameState, finish: Dictionary) -> void:
	if finish.has("reward_instance"):
		var reward: Cards.CardInstance = finish["reward_instance"]
		var duplicate := false
		for owned: Cards.CardInstance in state.deck:
			if owned.id == reward.id:
				duplicate = true
				break
		if not duplicate:
			Cards.accept_reward(state, reward)   # bot: take first-seen free, skip duplicates


static func _handle_unrest(state: GameState) -> void:
	if Unrest.use_martial_law(state):
		return
	if state.treasury >= Unrest.concession_cost(state):
		Unrest.apply_concession(state)
		return
	var battle := Battle.start(state, &"riot")
	_fight(state, battle)
