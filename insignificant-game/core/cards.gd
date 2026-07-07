class_name Cards
extends RefCounted
# 卡牌 (design/卡牌.md): unlock gates, deck economy, era evolution, strength.
# Catalog in CardsData. Battle consumes stats via the *_of helpers (stats scale by the
# era coefficient of the card's TIER; skills are era-neutral and never scale).

const UNLOCK_COST_BASE: int = 10
const DELETE_COST_BASE: int = 8
const DECK_MINIMUM: int = 5
const PERSONNEL_DISBAND_POP: int = 2


class CardInstance:
	extends RefCounted
	var id: StringName
	var tier: int = 1

	func _init(card_id: StringName, card_tier: int) -> void:
		id = card_id
		tier = card_tier


# --- catalog queries ---

static func card(card_id: StringName) -> Dictionary:
	return CardsData.CARDS[card_id]


static func form_name(card_id: StringName, tier: int) -> String:
	var entry: Dictionary = card(card_id)
	if not bool(entry["evolves"]):
		return String(entry["zh"])   # skills: the name IS the joke, era-neutral
	return String((entry["era_names"] as Array)[tier - 1])


static func attack_of(instance: CardInstance) -> int:
	var entry: Dictionary = card(instance.id)
	if not bool(entry["evolves"]):
		return int(entry["attack"])
	return int(entry["attack"]) * Era.COST_COEFF[instance.tier - 1]


static func hp_of(instance: CardInstance) -> int:
	var entry: Dictionary = card(instance.id)
	if not bool(entry["evolves"]):
		return int(entry["hp"])
	return int(entry["hp"]) * Era.COST_COEFF[instance.tier - 1]


static func military_cost_of(state: GameState, instance: CardInstance) -> int:
	var entry: Dictionary = card(instance.id)
	var base: int = int(entry["military_cost"])
	if entry["class"] == &"skill":
		# skills don't scale; 百家爭鳴: skill military cost −1, floor 1
		if state.policies.has(&"hundred_schools"):
			return maxi(base - 1, 1)
		return base
	return base * Era.COST_COEFF[instance.tier - 1]


# --- unlocking ---

static func tech_gate(state: GameState) -> int:
	# Gate to buy the CURRENT era's tier: 時代序×10; 文字與曆法 → ×8; 政教合一 +2×序.
	var idx: int = Era.index(state.generation)
	var mult: int = 8 if state.policies.has(&"writing_calendar") else 10
	var gate: int = idx * mult
	if state.policies.has(&"theocracy"):
		gate += 2 * idx
	return gate


static func unlock_cost(state: GameState) -> int:
	var cost: int = UNLOCK_COST_BASE * Era.coeff(state.generation)
	if state.policies.has(&"patent_system"):
		@warning_ignore("integer_division")
		cost = cost / 2
	return cost


static func source_satisfied(state: GameState, card_id: StringName) -> bool:
	var entry: Dictionary = card(card_id)
	var source: StringName = entry["source"]
	match entry["source_kind"]:
		&"region":
			return state.regions.has(source)
		&"building":
			return state.buildings.has(source)
		&"policy":
			return state.policies.has(source)
		&"legacy":
			return state.legacies.has(source)
	return false


static func can_unlock(state: GameState, card_id: StringName) -> Dictionary:
	if not CardsData.CARDS.has(card_id):
		return {"ok": false, "reason": &"unknown_card"}
	if state.unlocked_cards.has(card_id):
		return {"ok": false, "reason": &"already_unlocked"}
	var entry: Dictionary = card(card_id)
	if bool(entry["destroyed_on_use"]) and state.flags.get(&"destroyed_cards", []).has(card_id):
		return {"ok": false, "reason": &"permanently_destroyed"}   # 本局不再取得
	if Era.index(state.generation) < int(entry["min_era"]):
		return {"ok": false, "reason": &"no_form_this_era"}
	if not source_satisfied(state, card_id):
		return {"ok": false, "reason": &"source_missing"}
	if state.tech < tech_gate(state):
		return {"ok": false, "reason": &"tech_gate"}
	return {"ok": true, "reason": &""}


static func unlock(state: GameState, card_id: StringName) -> Dictionary:
	var check: Dictionary = can_unlock(state, card_id)
	if not bool(check["ok"]):
		return check
	var cost: int = unlock_cost(state)
	state.treasury -= cost   # may go negative
	state.unlocked_cards.append(card_id)
	var instance := _new_instance(state, card_id)
	state.deck.append(instance)
	return {"ok": true, "reason": &"", "cost": cost, "tier": instance.tier}


static func add_reward_card(state: GameState, card_id: StringName) -> CardInstance:
	# 戰鬥獎勵卡: free copy into the deck (player already chose to take it).
	if not state.unlocked_cards.has(card_id):
		state.unlocked_cards.append(card_id)
	var instance := _new_instance(state, card_id)
	state.deck.append(instance)
	return instance


# --- deck economy ---

static func delete_card(state: GameState, deck_index: int) -> Dictionary:
	if state.deck.size() <= DECK_MINIMUM:
		return {"ok": false, "reason": &"deck_minimum"}
	var instance: CardInstance = state.deck[deck_index]
	var cost: int = DELETE_COST_BASE * Era.coeff(state.generation)
	state.treasury -= cost
	var pop: int = _recovery_pop(instance.id)
	state.population += pop
	state.deck.remove_at(deck_index)
	return {"ok": true, "reason": &"", "cost": cost, "population_recovered": pop}


static func disband(state: GameState, deck_index: int) -> Dictionary:
	# 解散回收: personnel +2 population, mechanical nothing (sunk cost). Free, no money.
	if state.deck.size() <= DECK_MINIMUM:
		return {"ok": false, "reason": &"deck_minimum"}
	var instance: CardInstance = state.deck[deck_index]
	var pop: int = _recovery_pop(instance.id)
	state.population += pop
	state.deck.remove_at(deck_index)
	return {"ok": true, "reason": &"", "population_recovered": pop}


static func destroy_permanently(state: GameState, card_id: StringName) -> void:
	# 技能類限定卡用後即永久銷毀 (Battle calls this on use).
	for i: int in range(state.deck.size()):
		var instance: CardInstance = state.deck[i]
		if instance.id == card_id:
			state.deck.remove_at(i)
			break
	state.unlocked_cards.erase(card_id)
	var destroyed: Array = state.flags.get(&"destroyed_cards", [])
	destroyed.append(card_id)
	state.flags[&"destroyed_cards"] = destroyed


static func on_era_transition(state: GameState) -> void:
	# 就地演化: every evolving card rises to the current era's form.
	var idx: int = Era.index(state.generation)
	for instance: CardInstance in state.deck:
		if bool(card(instance.id)["evolves"]):
			instance.tier = maxi(instance.tier, mini(idx, 6))


static func deck_strength(state: GameState) -> int:
	# 牌組實力總和 for the power formula: Σ(attack+hp); skills contribute 0.
	var total: int = 0
	for instance: CardInstance in state.deck:
		total += attack_of(instance) + hp_of(instance)
	return total


static func starting_deck(state: GameState) -> void:
	# Driver decision: the design implies a deck ≥5 from generation 1 but names no
	# starting list — 5× 步兵團 (the cheapest personnel line, pre-unlocked).
	state.unlocked_cards.append(&"infantry")
	for i: int in range(DECK_MINIMUM):
		state.deck.append(CardInstance.new(&"infantry", 1))


static func _new_instance(state: GameState, card_id: StringName) -> CardInstance:
	var entry: Dictionary = card(card_id)
	var tier: int = 1
	if bool(entry["evolves"]):
		tier = clampi(Era.index(state.generation), int(entry["min_era"]), 6)
	return CardInstance.new(card_id, tier)


static func _recovery_pop(card_id: StringName) -> int:
	return int(card(card_id)["disband_pop"])
