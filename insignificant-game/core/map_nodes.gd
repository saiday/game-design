class_name MapNodes
extends RefCounted
# 地圖與機會 (design/地圖與機會.md): per-generation node layer, fog, skip, opportunity
# resolution. Node dicts are plain data for the view/Turn:
#   {"kind": &"known"|&"unknown", "content": &"battle"|&"opportunity",
#    "battle_type": StringName, "face_shown": bool, "surprise": bool}
# known = always battle, revealed. unknown = 60/40 battle/opportunity, content hidden;
# world_map policy reveals the FACE (battle vs opportunity), not the details.

const SKIP_COST_BASE: int = 10          # driver decision — design says 付錢略過 without a number
const UNKNOWN_BATTLE_CHANCE: float = 0.6
const HIDDEN_AMONG_UNKNOWN_BATTLES: float = 0.2   # driver decision — ambush share unspecified


static func generate(state: GameState) -> Array[Dictionary]:
	var minimum: int = 2 if state.policies.has(&"great_voyage") else 1
	var count: int = state.rng.randi_range(&"map", minimum, 3)
	var nodes: Array[Dictionary] = []
	for i: int in range(count):
		nodes.append(_roll_node(state))
	return nodes


static func inject_battle_node(nodes: Array[Dictionary], battle_type: StringName, rival_id: StringName) -> void:
	# 對手來犯的文明戰爭 injected as an extra, fully visible node (Rivals/Turn calls this).
	nodes.append({
		"kind": &"known", "content": &"battle", "battle_type": battle_type,
		"face_shown": true, "surprise": false, "rival_id": rival_id,
	})


static func skip_cost(state: GameState) -> int:
	return SKIP_COST_BASE * Era.coeff(state.generation)


static func skip_node(state: GameState) -> Dictionary:
	var cost: int = skip_cost(state)
	state.treasury -= cost   # may go negative
	return {"cost": cost, "treasury": state.treasury}


# --- opportunity events ---

static func opportunity_weights(state: GameState) -> Dictionary:
	# Percentage points; weighted_pick normalizes. 幸福 ≥ 70: merchant +20, disaster −20;
	# 推行世俗: disaster −10; 天文線 +10 / 登月競賽 +20 treasure.
	var merchant: float = float(OpportunityData.TABLE[&"merchant"]["base_weight"])
	var refugee: float = float(OpportunityData.TABLE[&"refugee"]["base_weight"])
	var disaster: float = float(OpportunityData.TABLE[&"disaster"]["base_weight"])
	var treasure: float = float(OpportunityData.TABLE[&"national_treasure"]["base_weight"])
	if Happiness.good_draw_bonus(state):
		merchant += OpportunityData.GOOD_DRAW_SHIFT
		disaster -= OpportunityData.GOOD_DRAW_SHIFT
	if state.policies.has(&"secularization"):
		disaster -= OpportunityData.SECULARIZATION_DISASTER_CUT
	treasure += Operations.treasure_weight_bonus(state)
	if state.policies.has(&"moon_race"):
		treasure += OpportunityData.MOON_RACE_TREASURE_BONUS
	return {
		&"merchant": maxf(merchant, 0.0),
		&"refugee": maxf(refugee, 0.0),
		&"disaster": maxf(disaster, 0.0),
		&"national_treasure": maxf(treasure, 0.0),
	}


static func roll_opportunity(state: GameState) -> StringName:
	var weights: Dictionary = opportunity_weights(state)
	# Drop zero-weight entries so weighted_pick can't land on them via float edge cases.
	for key: StringName in weights.keys().duplicate():
		if float(weights[key]) <= 0.0:
			weights.erase(key)
	return state.rng.weighted_pick(&"opportunity", weights)


static func opportunity_choices(opportunity_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for choice: StringName in (OpportunityData.TABLE[opportunity_id]["choices"] as Dictionary).keys():
		out.append(choice)
	return out


static func resolve_opportunity(state: GameState, opportunity_id: StringName, choice: StringName) -> Dictionary:
	var effects: Dictionary = OpportunityData.TABLE[opportunity_id]["choices"][choice]
	var coeff: int = Era.coeff(state.generation)
	var report: Dictionary = {"opportunity": opportunity_id, "choice": choice}
	var money: int = Difficulty.scale_penalty(state, int(effects.get("money_per_coeff", 0)) * coeff)
	var fee: int = -Difficulty.scale_penalty(state, -(int(effects.get("cost_per_coeff", 0)) * coeff))
	state.treasury += money - fee
	report["money"] = money
	report["fee"] = fee
	if effects.has("population"):
		var delta: int = int(effects["population"])
		var cap: int = int(Operations.production(state)["pop_cap"])
		var before: int = state.population
		if delta > 0:
			state.population = maxi(before, mini(before + delta, cap))
		else:
			state.population = before + delta
		report["population"] = state.population - before
	if effects.has("happiness"):
		report["happiness"] = Happiness.adjust(state, int(effects["happiness"]))
	if effects.has("culture"):
		state.culture += int(effects["culture"])
		report["culture"] = int(effects["culture"])
	if bool(effects.get("treasure", false)):
		# Same flag Economy.sell_treasure reads.
		state.flags[&"treasures"] = int(state.flags.get(&"treasures", 0)) + 1
		report["treasure"] = true
	if bool(effects.get("rare_card", false)):
		# The view/sim converts pending rare cards into an actual pick (卡牌 owns catalogs).
		state.flags[&"pending_rare_cards"] = int(state.flags.get(&"pending_rare_cards", 0)) + 1
		report["rare_card"] = true
	return report


static func _roll_node(state: GameState) -> Dictionary:
	# known:unknown ratio unspecified in the design — 50/50 (driver decision).
	var known: bool = state.rng.chance(&"map", 0.5)
	if known:
		return {
			"kind": &"known", "content": &"battle", "battle_type": &"tax_battle",
			"face_shown": true, "surprise": false,
		}
	var is_battle: bool = state.rng.chance(&"map", UNKNOWN_BATTLE_CHANCE)
	var face_shown: bool = state.policies.has(&"world_map")
	if not is_battle:
		return {
			"kind": &"unknown", "content": &"opportunity", "battle_type": &"",
			"face_shown": face_shown, "surprise": false,
		}
	# 為民主而流血: low-frequency unknown draw while democracy is unlocked-but-refused
	# and happiness < 70 (design/戰鬥.md; 15% share is a driver decision).
	if not state.is_democracy and state.culture > 20 and state.happiness < 70 \
			and state.rng.chance(&"map", 0.15):
		return {
			"kind": &"unknown", "content": &"battle", "battle_type": &"democracy_blood",
			"face_shown": face_shown, "surprise": false,
		}
	var hidden: bool = state.rng.chance(&"map", HIDDEN_AMONG_UNKNOWN_BATTLES)
	var battle_type: StringName = &"hidden_battle" if hidden else &"field_battle"
	return {
		"kind": &"unknown", "content": &"battle", "battle_type": battle_type,
		"face_shown": face_shown,
		"surprise": hidden and not state.policies.has(&"intelligence_agency"),
	}
