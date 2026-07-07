class_name Democracy
extends RefCounted
# 民主 (design/民主.md): the soft ending — you stop operating, your only verb is funding
# candidates. Irreversible. BP stops, buildings keep producing, treasury renamed 貴族資金
# (same single pool, 40% of a positive treasury survives the transition).
#
# Candidate pool state lives in state.candidate_pool as dicts:
#   {"id": StringName, "chance": float (percentage points), "terms": int}
# Incumbent reelection: 40% + (幸福−50)×0.5%; two reelections -> removed from the pool;
# the pool never refills (10 candidates total, then whoever remains rotates).

const UNLOCK_CULTURE: int = 20
const TREASURY_KEPT: float = 0.4
const FUND_COST: int = 50
const FUND_BONUS: float = 10.0
const BASE_CHANCE: float = 10.0
const MEDIA_BIAS: float = 10.0
const MAX_REELECTIONS: int = 2
const EXPLORE_CAP: int = 4
const EXPLORE_REWARD_PER_COEFF: int = 15   # auto-explore batch value (driver decision)


static func unlocked(state: GameState) -> bool:
	return state.culture > UNLOCK_CULTURE


static func enter(state: GameState, voluntary: bool) -> Dictionary:
	if state.is_democracy:
		return {"ok": false, "reason": &"already_democracy"}
	if voluntary and not unlocked(state):
		return {"ok": false, "reason": &"locked"}
	state.is_democracy = true
	state.democracy_entered_gen = state.generation
	if state.treasury > 0:
		state.treasury = int(state.treasury * TREASURY_KEPT)   # 國庫的 40% 轉為貴族資金
	if voluntary:
		Legacy.grant(state, &"democratic_spirit")
	_build_pool(state)
	_elect(state)   # first leader takes office immediately
	return {"ok": true, "reason": &"", "incumbent": state.incumbent, "voluntary": voluntary}


static func top_three(state: GameState) -> Array[StringName]:
	# 可金援對象＝當前當選機率最高的 3 組 (其餘無入口).
	var sorted_pool: Array = state.candidate_pool.duplicate()
	sorted_pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["chance"]) > float(b["chance"]))
	var out: Array[StringName] = []
	for i: int in range(mini(3, sorted_pool.size())):
		out.append(sorted_pool[i]["id"])
	return out


static func fund(state: GameState, candidate_id: StringName) -> Dictionary:
	# 金援＝拿生命左右民主: same pool that pays (auto-)military costs.
	if not state.is_democracy:
		return {"ok": false, "reason": &"not_democracy"}
	if not top_three(state).has(candidate_id):
		return {"ok": false, "reason": &"not_top_three"}
	for entry: Dictionary in state.candidate_pool:
		if entry["id"] == candidate_id:
			state.treasury -= FUND_COST
			entry["chance"] = float(entry["chance"]) + FUND_BONUS   # permanent +10%
			return {"ok": true, "reason": &"", "chance": entry["chance"]}
	return {"ok": false, "reason": &"unknown_candidate"}


static func reelection_chance(state: GameState) -> float:
	return clampf(40.0 + float(state.happiness - 50) * 0.5, 0.0, 100.0) / 100.0


static func generation_step(state: GameState) -> Dictionary:
	# One democracy generation (20–45s in the real game): election → incumbent's fixed
	# axis moves → auto-explore batch. Battles inside auto-explore are abstracted to the
	# batch value (一律全力求勝 — the leader never throws a fight).
	var report: Dictionary = {}
	report["election"] = _election_step(state)
	report["moves"] = _apply_incumbent(state)
	report["explore"] = _auto_explore(state)
	return report


# --- internals ---

static func _build_pool(state: GameState) -> void:
	state.candidate_pool = []
	var bias: StringName = state.flags.get(&"media_pool_bias", &"")
	for candidate_id: StringName in CandidateData.CANDIDATES.keys():
		var chance: float = BASE_CHANCE
		if state.policies.has(&"mass_media") and bias != &"" \
				and CandidateData.CANDIDATES[candidate_id]["tendency"] == bias:
			chance += MEDIA_BIAS
		state.candidate_pool.append({"id": candidate_id, "chance": chance, "terms": 0})


static func _election_step(state: GameState) -> Dictionary:
	# Incumbent rolls reelection first; on failure (or term limit) the pool votes.
	var incumbent_entry: Dictionary = _find_candidate(state, state.incumbent)
	if not incumbent_entry.is_empty():
		if int(incumbent_entry["terms"]) >= MAX_REELECTIONS:
			state.candidate_pool.erase(incumbent_entry)   # 連任兩次後移出池
		elif state.rng.chance(&"democracy", reelection_chance(state)):
			incumbent_entry["terms"] = int(incumbent_entry["terms"]) + 1
			return {"reelected": true, "incumbent": state.incumbent}
	_elect(state)
	return {"reelected": false, "incumbent": state.incumbent}


static func _elect(state: GameState) -> void:
	if state.candidate_pool.is_empty():
		return   # 10 組打完為止: the last incumbent simply stays
	var weights: Dictionary = {}
	for entry: Dictionary in state.candidate_pool:
		weights[entry["id"]] = maxf(float(entry["chance"]), 0.1)
	state.incumbent = state.rng.weighted_pick(&"democracy", weights)
	state.flags.erase(&"incumbent_first_gen_done")


static func _find_candidate(state: GameState, candidate_id: StringName) -> Dictionary:
	for entry: Dictionary in state.candidate_pool:
		if entry["id"] == candidate_id:
			return entry
	return {}


static func _apply_incumbent(state: GameState) -> Dictionary:
	if state.incumbent == &"":
		return {}
	var data: Dictionary = CandidateData.CANDIDATES[state.incumbent]
	var happiness_delta: int = int(data["happiness"])
	if data.has("first_gen_happiness") and not state.flags.has(&"incumbent_first_gen_done"):
		happiness_delta = int(data["first_gen_happiness"])   # 革命激進派: 首代 +5
	state.flags[&"incumbent_first_gen_done"] = true
	var cap: int = int(Operations.production(state)["pop_cap"])
	var pop_delta: int = int(data["population"])
	if pop_delta > 0:
		state.population = maxi(state.population, mini(state.population + pop_delta, cap))
	else:
		state.population += pop_delta
	state.culture += int(data["culture"])
	state.tech += int(data["tech"])
	Happiness.adjust(state, happiness_delta)
	var money: int = int(data["money"]) * Era.coeff(state.generation)
	state.treasury += money
	return {"copy": data["copy"], "money": money, "happiness": happiness_delta}


static func _auto_explore(state: GameState) -> Dictionary:
	# 每代節點數 = 2 + floor(進民主後代數/2), 硬上限 4; 超出批次結算.
	@warning_ignore("integer_division")
	var count: int = mini(2 + (state.generation - state.democracy_entered_gen) / 2, EXPLORE_CAP)
	var reward: int = count * EXPLORE_REWARD_PER_COEFF * Era.coeff(state.generation)
	state.treasury += reward
	return {"nodes": count, "reward": reward}
