class_name Sim
extends RefCounted
# Scripted auto-player: drives Turn through full 50-generation runs for invariant tests
# and balance telemetry (the three sensitive knobs: BP curve, escalation 0.25, unrest
# weights). The bot is deliberately simple — a competent-but-greedy baseline player.

const SAFETY_CAP: int = 60
const DEMOCRACY_ENTRY_GEN: int = 38

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
			Turn.run_world_war(state)
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
	if Battle.can_defect(state, battle):
		Battle.defect(state, battle)
	var spend_floor: int = -50 * Era.coeff(state.generation)
	while battle.outcome == &"":
		var played := true
		while played and battle.player_units.size() < 4:
			played = false
			var cheapest: int = -1
			var cheapest_cost: int = 1 << 30
			for i: int in range(battle.hand.size()):
				var instance: Cards.CardInstance = battle.hand[i]
				if Cards.card(instance.id)["class"] == &"skill":
					continue   # bot keeps it simple: units only
				var cost: int = Battle.card_cost(state, battle, instance)
				if cost < cheapest_cost:
					cheapest_cost = cost
					cheapest = i
			if cheapest >= 0 and state.treasury - cheapest_cost >= spend_floor:
				played = bool(Battle.play_card(state, battle, cheapest)["ok"])
		Battle.end_round(state, battle)
	var finish := Battle.finish(state, battle)
	if finish.has("reward_card") and state.flags.has(&"pending_reward_card"):
		Cards.add_reward_card(state, state.flags[&"pending_reward_card"])
		state.flags.erase(&"pending_reward_card")


static func _handle_unrest(state: GameState) -> void:
	if Unrest.use_martial_law(state):
		return
	if state.treasury >= Unrest.concession_cost(state):
		Unrest.apply_concession(state)
		return
	var battle := Battle.start(state, &"riot")
	_fight(state, battle)
