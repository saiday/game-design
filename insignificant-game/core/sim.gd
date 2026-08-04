class_name Sim
extends RefCounted
# Scripted auto-player: drives Turn through full 50-generation runs for invariant tests
# and balance telemetry (the three sensitive knobs: BP curve, escalation 0.25, unrest
# weights). The bot is deliberately simple — a competent-but-greedy baseline player.
#
# W16 gave it a 工事卡 policy (see §fortification policy below). Everything the bot decides
# is a heuristic we authored, so the batch measures the heuristic, never what a card is worth
# to a human who can read a wave schedule — `docs/balance-report.md` states that limit where
# it reports the numbers.

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
	var telemetry := new_telemetry()
	var ending: Dictionary = {"over": false, "kind": &"stuck"}
	while true:
		var begin := Turn.begin_generation(state)
		if begin.has("world_war"):
			_world_war(state, telemetry)
		elif begin.has("democracy"):
			Democracy.generation_step(state)
		else:
			_operate(state)
			var nodes := Turn.route(state)
			_resolve_node(state, _pick_node(nodes), telemetry)
			if Turn.roll_unrest_battle(state):
				_handle_unrest(state, telemetry)
		var settled := Turn.settle(state)
		if bool((settled["ending"] as Dictionary)["over"]):
			ending = settled["ending"]
			break
		if state.generation > SAFETY_CAP:
			break
		if not state.is_democracy and state.generation >= DEMOCRACY_ENTRY_GEN \
				and Democracy.unlocked(state):
			Democracy.enter(state, true)
	return {"ending": ending, "state": state, "generations": state.log.size(),
			"telemetry": telemetry}


static func new_telemetry() -> Dictionary:
	# Bot-side battle counters, kept OUT of GameState: they describe how this auto-player
	# played, not what the game is. `tools/balance_batch.gd` writes them per run; W16 added
	# the fort rows because ADR-0007/0008/0010's knobs had no other instrument.
	return {
		"battles": 0,                # battles actually driven (defected/cancelled ones included)
		# Opportunity, so a low deploy count can be read as "never had the card", "never had the
		# target" or "chose not to" instead of collapsing all three into one number:
		"battles_wall_held": 0,      # …opened with a 盾陣 in the deck
		"battles_battery_held": 0,   # …opened with a 防空飛彈 in the deck
		"battles_air_faced": 0,      # …had a living enemy 空域 unit at some round boundary
		"walls_fielded": 0,          # 盾陣 deployed by the bot
		"batteries_fielded": 0,      # 防空飛彈 deployed by the bot
		"engineers_fielded": 0,      # 工兵團 deployed by the follow-the-wall rule
		"fort_spend": 0,             # 軍費 spent on all three of the above
		"wall_shots_absorbed": 0,    # ranged shots the bot's own walls ate (`intercept`)
		"forts_disabled": 0,         # the bot's forts knocked out by 帶攻城/空襲 (`disable`)
		"fort_repairs": 0,           # 工兵團 restorations (`repair`)
		"shootdowns": 0,             # aircraft destroyed by the bot's 防空飛彈 (`shootdown`)
	}


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
			if int(Cards.card((state.deck[i] as Cards.CardInstance).id)["disband_pop"]) <= 0:
				continue
			if _is_last_repairer(state, i):
				continue   # W16: 工兵團 is worth 2 人口 and a whole fort lifecycle — keep the last one
			target = i
			break
		if target < 0 or not bool(Cards.disband(state, target)["ok"]):
			return


static func _is_last_repairer(state: GameState, index: int) -> bool:
	# A 工兵團 is disbandable personnel like any other (+2 人口), but it is also the ONLY thing
	# that repairs a 工事卡 (ADR-0007) — disbanding the last one turns every wall the bot owns
	# into a one-shot item. So it is protected exactly while a 工事卡 sits in the deck.
	var instance: Cards.CardInstance = state.deck[index]
	if not (Cards.card(instance.id)["flags"] as Array).has(&"repairs_fortifications"):
		return false
	var holds_fort := false
	var other_repairer := false
	for i: int in range(state.deck.size()):
		var other: Cards.CardInstance = state.deck[i]
		var entry: Dictionary = Cards.card(other.id)
		if entry["class"] == &"fortification":
			holds_fort = true
		elif i != index and (entry["flags"] as Array).has(&"repairs_fortifications"):
			other_repairer = true
	return holds_fort and not other_repairer


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


static func _resolve_node(state: GameState, node: Dictionary, telemetry: Dictionary) -> void:
	if node["content"] == &"opportunity":
		var opportunity: StringName = MapNodes.roll_opportunity(state)
		MapNodes.resolve_opportunity(state, opportunity, _opportunity_choice(state, opportunity))
		return
	var battle := Battle.start(
		state, node["battle_type"],
		node.get("rival_id", &""), bool(node.get("player_declared", false)),
		bool(node.get("surprise", false)))
	_fight(state, battle, telemetry)


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


static func _fight(state: GameState, battle: Battle.BattleField, telemetry: Dictionary) -> void:
	# Minimal W12 policy (no hand: any unplayed card, 軍費-gated by bot prudence only —
	# W14 owns the real tempo-aware auto-player).
	if Battle.can_defect(state, battle):
		Battle.defect(state, battle)
	_drive_battle(state, battle, telemetry)
	_take_reward(state, Battle.finish(state, battle))


static func _world_war(state: GameState, telemetry: Dictionary) -> void:
	# 世界大戰 is the same drive loop on the shared table: the bot deploys only its own
	# cards (allies auto-fight); no defect, no retreat (不可撤軍); WorldWar.finish settles
	# camps/reparations and issues the reward card.
	var battle := WorldWar.start(state)
	_drive_battle(state, battle, telemetry)
	_take_reward(state, WorldWar.finish(state, battle))


static func _drive_battle(state: GameState, battle: Battle.BattleField, telemetry: Dictionary) -> void:
	# Tempo policy (最小軍費 as a strength race): each boundary, field the cheapest unit
	# cards until our fielded 攻+血 matches the enemy's — no more (waves may stack later,
	# but survivors persist and rewards don't scale with overspend). In riots, personnel
	# first: any mechanical deploy costs 幸福 −15 (鎮壓的手段有代價). If the bot won't hold
	# the field while enemies stand, it concedes — mandatory for uncapped battles (WW).
	# Cover rides on top of that race rather than inside it (W16, §fortification policy).
	var spend_floor: int = -50 * Era.coeff(state.generation)
	telemetry["battles"] = int(telemetry["battles"]) + 1
	if _available_fort(battle, &"screens_ranged_row") >= 0:
		telemetry["battles_wall_held"] = int(telemetry["battles_wall_held"]) + 1
	if _available_fort(battle, &"fires_at_air") >= 0:
		telemetry["battles_battery_held"] = int(telemetry["battles_battery_held"]) + 1
	var air_faced := false
	while battle.outcome == &"" and battle.round <= BATTLE_ROUND_GUARD:
		if not air_faced and _enemy_has_air(battle):
			air_faced = true
			telemetry["battles_air_faced"] = int(telemetry["battles_air_faced"]) + 1
		var deployed_any := false
		var played := true
		while played and _fielded_strength(battle.player_units) < _fielded_strength(battle.enemy_units):
			played = false
			var pick: int = _pick_deploy(state, battle, true) if battle.battle_type == &"riot" \
					else _pick_deploy(state, battle, false)
			if pick >= 0 and _affordable(state, battle, pick, spend_floor):
				played = bool(Battle.deploy(state, battle, pick)["ok"])
				deployed_any = deployed_any or played
		# Cover comes AFTER the strength race and never inside it: a 工事卡 carries no 攻 and no
		# 血, so it moves `_fielded_strength` by zero and a parity loop asked to buy one would
		# never stop. Units first keeps the W14 tempo policy the dominant term, so what the batch
		# reads as "the fort delta" is the addition and not a reordering.
		deployed_any = _field_support(state, battle, spend_floor, telemetry) or deployed_any
		# Give up the field when the bot won't spend another coin on it: nothing fieldable
		# against a standing enemy, or remnants that can't reach each other at all (melee-only
		# survivors just stare at a bomber, and since W16 a 防空飛彈 the bot never drew is still
		# no answer). 還有未出卡但選擇不出 is a legal voluntary concession, and it lets the engine
		# settle an uncapped war on the spot instead of burning empty rounds.
		var overrun: bool = battle.player_units.is_empty() and not battle.enemy_units.is_empty()
		var frozen: bool = not Battle.has_pending_waves(battle) \
				and not Battle.can_act(battle, &"player") \
				and not Battle.can_act(battle, &"enemy")
		if not battle.conceded and not deployed_any and (overrun or frozen):
			Battle.concede(battle)
		_count_fort_events(Battle.end_round(state, battle), telemetry)
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


static func _affordable(state: GameState, battle: Battle.BattleField, index: int, spend_floor: int) -> bool:
	# 軍費 never blocks a deploy (D1/D3) — the treasury just goes negative — so "affordable" is
	# purely the bot's own prudence line, one definition shared by units and cover.
	return state.treasury - Battle.card_cost(state, battle, battle.available[index]) >= spend_floor


# --- fortification policy (W16) ---
#
# From W14 to W15 `_pick_deploy` skipped `class == &"fortification"` outright, so the batch
# never saw a player-side 工事卡 and ADR-0007's disable/repair lifecycle, ADR-0008's narrowing
# to the 遠程列 and ADR-0010's 3～5-shot ranged budget had zero coverage on the side that pays
# for them. These three reads are what closes that. They are deliberately written as rule
# statements ("a wall screens the 遠程列 from 遠程 fire") rather than as engine exploits: the
# engine's ranged focus-fire happens to run in deploy order, and a bot tuned to that would
# measure the target picker instead of the wall.
#
# 同場上限 2 counts every fort fielded in the battle, disabled ones included, because forts are
# never removed (ADR-0007) — a slot spent is a slot gone for good, which is why a second wall
# is bought only when the first is a wreck nothing can repair.


static func fort_pick(battle: Battle.BattleField) -> int:
	# Which 工事卡 in `battle.available` is worth its 軍費 at this boundary; -1 = none.
	# Battery before wall: 空域 is the only threat the bot has no other answer to (it fields the
	# cheapest unit, so it answers bombers only by accident — balance-report.md, W14.5).
	if battle.player_forts.size() >= Battle.FORT_LIMIT:
		return -1
	if _enemy_has_air(battle) and not _has_active_fort(battle, &"fires_at_air"):
		var battery: int = _available_fort(battle, &"fires_at_air")
		if battery >= 0:
			return battery
	if _wall_wanted(battle):
		return _available_fort(battle, &"screens_ranged_row")
	return -1


static func engineer_pick(battle: Battle.BattleField) -> int:
	# 工兵團跟著牆走. Without one on the field a 工事卡 is a one-shot item: 一次癱瘓即待修 and
	# nothing else in the game restores it (ADR-0007). It costs 2 軍費 and stations in the 遠程列,
	# behind the very wall it maintains (ADR-0008), so the wall protects its own repairer.
	if battle.player_forts.is_empty():
		return -1
	if _has_living_flag(battle.player_units, &"repairs_fortifications"):
		return -1
	return _available_flag(battle, &"repairs_fortifications")


static func _field_support(state: GameState, battle: Battle.BattleField, spend_floor: int,
		telemetry: Dictionary) -> bool:
	# At most one fort and one engineer per boundary: the field changes between rounds and the
	# bot re-reads it rather than emptying its deck into a single decision.
	# 工事卡 are class &"fortification" and 工兵團 is &"personnel", so neither trips
	# `mechanical_played` — cover is free of 鎮壓的手段有代價's 幸福 −15 and needs no riot case.
	if not _has_living(battle.player_units):
		return false   # cover holds no field on its own; something has to stand behind it
	var fielded := false
	var fort: int = fort_pick(battle)
	if fort >= 0 and _affordable(state, battle, fort, spend_floor):
		var is_battery: bool = _instance_has_flag(battle.available[fort], &"fires_at_air")
		var fort_report: Dictionary = Battle.deploy(state, battle, fort)
		if bool(fort_report["ok"]):
			fielded = true
			var key: String = "batteries_fielded" if is_battery else "walls_fielded"
			telemetry[key] = int(telemetry[key]) + 1
			telemetry["fort_spend"] = int(telemetry["fort_spend"]) + int(fort_report["cost"])
	var engineer: int = engineer_pick(battle)
	if engineer >= 0 and _affordable(state, battle, engineer, spend_floor):
		var engineer_report: Dictionary = Battle.deploy(state, battle, engineer)
		if bool(engineer_report["ok"]):
			fielded = true
			telemetry["engineers_fielded"] = int(telemetry["engineers_fielded"]) + 1
			telemetry["fort_spend"] = int(telemetry["fort_spend"]) + int(engineer_report["cost"])
	return fielded


static func _wall_wanted(battle: Battle.BattleField) -> bool:
	# A 盾陣 absorbs 遠程 fire aimed at the 遠程列 and nothing else (ADR-0008 scope, ADR-0010
	# attack type): 近戰 walks around it, 空襲 comes over it. So it is worth 3 軍費 only when the
	# bot has a 遠程列 to screen AND someone is shooting into it.
	if not _has_living_row(battle.player_units, &"ranged"):
		return false
	if not _enemy_shoots_ranged(battle):
		return false
	if _has_active_fort(battle, &"screens_ranged_row"):
		return false
	# A disabled wall is a slot already paid for. Spend the other slot on a second wall only when
	# nothing will stand this one back up: an engineer on the field, or one still in the deck,
	# makes the wreck cheaper to fix (2 軍費, and it re-rolls a fresh budget) than to replace (3).
	if _has_fort(battle, &"screens_ranged_row"):
		if _has_living_flag(battle.player_units, &"repairs_fortifications") \
				or _available_flag(battle, &"repairs_fortifications") >= 0:
			return false
	return true


# --- fortification policy: field + deck reads ---

static func _has_living(units: Array[Dictionary]) -> bool:
	for unit: Dictionary in units:
		if int(unit["hp"]) > 0:
			return true
	return false


static func _has_living_row(units: Array[Dictionary], row: StringName) -> bool:
	for unit: Dictionary in units:
		if int(unit["hp"]) > 0 and unit["row"] == row:
			return true
	return false


static func _has_living_flag(units: Array[Dictionary], flag: StringName) -> bool:
	for unit: Dictionary in units:
		if int(unit["hp"]) > 0 and (unit["flags"] as Array).has(flag):
			return true
	return false


static func _enemy_has_air(battle: Battle.BattleField) -> bool:
	return _has_living_row(battle.enemy_units, &"air")


static func _enemy_shoots_ranged(battle: Battle.BattleField) -> bool:
	# 遠程列 with something to shoot with. `_attack_kind` reads the row, so this is the same set
	# of attackers a wall can ever absorb; 帶攻城 irregulars stand there too and spend their shot
	# disabling the wall instead, which is still a reason to own one.
	for unit: Dictionary in battle.enemy_units:
		if int(unit["hp"]) <= 0 or unit["row"] != &"ranged":
			continue
		if int(unit["attack"]) > 0 and not (unit["flags"] as Array).has(&"no_attack"):
			return true
	return false


static func _has_fort(battle: Battle.BattleField, flag: StringName) -> bool:
	for fort: Dictionary in battle.player_forts:
		if (fort["flags"] as Array).has(flag):
			return true
	return false


static func _has_active_fort(battle: Battle.BattleField, flag: StringName) -> bool:
	for fort: Dictionary in battle.player_forts:
		if not bool(fort["disabled"]) and (fort["flags"] as Array).has(flag):
			return true
	return false


static func _instance_has_flag(instance: Cards.CardInstance, flag: StringName) -> bool:
	return (Cards.card(instance.id)["flags"] as Array).has(flag)


static func _available_fort(battle: Battle.BattleField, flag: StringName) -> int:
	# First unplayed 工事卡 carrying `flag`. The class check is what separates this from
	# `_available_flag`: a flag alone would also match the 工兵團 that maintains the thing.
	for i: int in range(battle.available.size()):
		var instance: Cards.CardInstance = battle.available[i]
		if Cards.card(instance.id)["class"] != &"fortification":
			continue
		if _instance_has_flag(instance, flag):
			return i
	return -1


static func _available_flag(battle: Battle.BattleField, flag: StringName) -> int:
	for i: int in range(battle.available.size()):
		if _instance_has_flag(battle.available[i], flag):
			return i
	return -1


static func _count_fort_events(report: Dictionary, telemetry: Dictionary) -> void:
	# Read straight off the timeline contract (architecture.md §Timeline event contract), which
	# is why the sides look asymmetric: `side` names the ACTOR, so a wall of the bot's absorbing
	# or being suppressed shows up as an enemy-side event, while `repair` and `shootdown` carry
	# the fort owner's side. `battle.player_forts` only ever holds the bot's own cards — allied
	# 正規軍 screens go to the enemy camp only (Battle.regular_screens) — so nothing here counts
	# an ally's wall as the player's.
	for event: Dictionary in (report.get("events", []) as Array):
		match StringName(event["type"]):
			&"intercept":
				if event["side"] == &"enemy" and StringName(event["card_id"]) != &"":
					telemetry["wall_shots_absorbed"] = int(telemetry["wall_shots_absorbed"]) + 1
			&"disable":
				if event["side"] == &"enemy":
					telemetry["forts_disabled"] = int(telemetry["forts_disabled"]) + 1
			&"repair":
				telemetry["fort_repairs"] = int(telemetry["fort_repairs"]) + 1
			&"shootdown":
				if event["side"] == &"player":
					telemetry["shootdowns"] = int(telemetry["shootdowns"]) + 1


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


static func _handle_unrest(state: GameState, telemetry: Dictionary) -> void:
	if Unrest.use_martial_law(state):
		return
	if state.treasury >= Unrest.concession_cost(state):
		Unrest.apply_concession(state)
		return
	var battle := Battle.start(state, &"riot")
	_fight(state, battle, telemetry)
