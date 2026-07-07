class_name Operations
extends RefCounted
# 營運 (design/營運.md): BP production/carryover, region/building build + in-place upgrade,
# escalating build cost, per-generation production. Content tables in BuildingData.
# Action funcs validate first and return {"ok": bool, "reason": StringName, ...}.

const ESCALATION_PER_BUILDING: float = 0.25
const CARRYOVER_CAP: int = 2
const CARRYOVER_CAP_ENLIGHTENED: int = 3


static func bp_income(state: GameState) -> int:
	@warning_ignore("integer_division")
	var from_pop: int = maxi(1, state.population / 10)
	return mini(from_pop, Era.bp_cap(state.generation))


static func grant_bp(state: GameState) -> void:
	# Start of the operate phase. Democracy: BP 停產 (buildings still produce elsewhere).
	if state.is_democracy:
		state.bp = 0
		return
	state.bp = bp_income(state) + state.bp_carryover
	state.bp_carryover = 0


static func end_operate_phase(state: GameState) -> void:
	var cap: int = CARRYOVER_CAP_ENLIGHTENED if state.policies.has(&"enlightened_absolutism") else CARRYOVER_CAP
	state.bp_carryover = mini(state.bp, cap)
	state.bp = 0


static func escalation(state: GameState) -> float:
	# 遞增係數 = 1 + 0.25 × 全國已建棟數. Counts NEW buildings only (upgrades never
	# increment; lifetime count — riot losses don't refund it).
	return 1.0 + ESCALATION_PER_BUILDING * float(state.buildings_built)


static func region_cost(state: GameState) -> int:
	# Regions are NOT escalated (遞增 applies to 蓋樓/升級 only).
	return BuildingData.REGION_COST_BASE * Era.coeff(state.generation)


static func build_region(state: GameState, region_id: StringName) -> Dictionary:
	if not BuildingData.REGIONS.has(region_id):
		return {"ok": false, "reason": &"unknown_region"}
	if state.regions.has(region_id):
		return {"ok": false, "reason": &"already_built"}
	if state.is_democracy:
		return {"ok": false, "reason": &"democracy"}
	if state.bp < 1:
		return {"ok": false, "reason": &"no_bp"}
	var cost: int = region_cost(state)
	state.bp -= 1
	state.treasury -= cost   # may go negative — debt is the brake, not a wall
	state.regions.append(region_id)
	return {"ok": true, "reason": &"", "cost": cost}


static func building_cost(state: GameState, line_id: StringName) -> int:
	# 蓋第一階 = 基準錢 × 時代係數 × 遞增係數 (floor).
	var line: Dictionary = BuildingData.LINES[line_id]
	return int(float(int(line["base_cost"]) * Era.coeff(state.generation)) * escalation(state))


static func build_building(state: GameState, line_id: StringName) -> Dictionary:
	if not BuildingData.LINES.has(line_id):
		return {"ok": false, "reason": &"unknown_line"}
	var line: Dictionary = BuildingData.LINES[line_id]
	if not state.regions.has(line["region"]):
		return {"ok": false, "reason": &"region_missing"}
	if state.buildings.has(line_id):
		return {"ok": false, "reason": &"already_built"}
	if Era.index(state.generation) < int(line["min_era"]):
		return {"ok": false, "reason": &"era_locked"}
	if state.is_democracy:
		return {"ok": false, "reason": &"democracy"}
	if state.bp < 1:
		return {"ok": false, "reason": &"no_bp"}
	var cost: int = building_cost(state, line_id)
	state.bp -= 1
	state.treasury -= cost
	state.buildings[line_id] = int(line["min_tier"])
	state.buildings_built += 1
	return {"ok": true, "reason": &"", "cost": cost, "tier": int(line["min_tier"])}


static func upgrade_cost(state: GameState, line_id: StringName) -> int:
	# 就地升級 = 階差額 × 時代係數 × 遞增係數; tiers advance one at a time so the
	# tier difference is the line's base cost once (interpretation: 階差額 = 基準錢 × 階差).
	var line: Dictionary = BuildingData.LINES[line_id]
	return int(float(int(line["base_cost"]) * Era.coeff(state.generation)) * escalation(state))


static func upgrade_building(state: GameState, line_id: StringName) -> Dictionary:
	if not state.buildings.has(line_id):
		return {"ok": false, "reason": &"not_built"}
	var tier: int = int(state.buildings[line_id])
	var target: int = tier + 1
	if target > Era.index(state.generation):
		return {"ok": false, "reason": &"era_capped"}
	if target > 6:
		return {"ok": false, "reason": &"max_tier"}
	if state.is_democracy:
		return {"ok": false, "reason": &"democracy"}
	if state.bp < 1:
		return {"ok": false, "reason": &"no_bp"}
	var cost: int = upgrade_cost(state, line_id)
	state.bp -= 1
	state.treasury -= cost
	state.buildings[line_id] = target   # upgrades do NOT touch buildings_built
	return {"ok": true, "reason": &"", "cost": cost, "tier": target}


static func production(state: GameState) -> Dictionary:
	# Per-generation output of regions + buildings. Keys are pinned in architecture.md.
	var out: Dictionary = {
		"population": 0, "happiness": 0, "culture": 0, "tech": 0, "income": 0,
		"pop_cap": BuildingData.BASE_POP_CAP,
	}
	for region_id: StringName in state.regions:
		var passive: Dictionary = BuildingData.REGIONS[region_id]["passive"]
		for key: String in ["tech", "culture", "income"]:
			out[key] = int(out[key]) + int(passive.get(key, 0))
		out["pop_cap"] = int(out["pop_cap"]) + int(passive.get("pop_cap", 0))
	for line_id: StringName in state.buildings.keys():
		var line: Dictionary = BuildingData.LINES[line_id]
		var output: Dictionary = line["output"]
		for key: String in ["population", "happiness", "culture", "tech", "income"]:
			out[key] = int(out[key]) + int(output.get(key, 0))
		if line.has("pop_cap_per_tier"):
			out["pop_cap"] = int(out["pop_cap"]) + int(line["pop_cap_per_tier"]) * int(state.buildings[line_id])
	return out


# --- combat/system flags queried by other modules (not part of production) ---

static func opening_hand_bonus(state: GameState) -> int:
	# 軍事區 passive: 戰鬥開場手牌 +1.
	return 1 if state.regions.has(&"military") else 0


static func opening_slots_bonus(state: GameState) -> int:
	# 兵營 line: 戰鬥開場部隊位 +1 (any tier).
	return 1 if state.buildings.has(&"barracks") else 0


static func card_pool_tier(state: GameState, line_id: StringName) -> int:
	# 兵營/兵工 open their card class up to the line's current tier.
	return int(state.buildings.get(line_id, 0))


static func psyops_potency(state: GameState) -> float:
	# 心戰 per-use attack discount: base −10%; 傳播 line built → −15% (cap stays 7折).
	return 0.15 if state.buildings.has(&"media") else 0.10


static func treasure_weight_bonus(state: GameState) -> float:
	# 學術·天文線: 國寶機會權重 +10% (any tier); MapNodes adds moon_race's +20% itself.
	return 10.0 if state.buildings.has(&"astronomy") else 0.0
