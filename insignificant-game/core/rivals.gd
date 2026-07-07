class_name Rivals
extends RefCounted
# 對手文明 (design/對手文明.md): 5 power-scalar automa, relations/influence ledger,
# player verbs (宣戰/心戰), aggression, catch-up, annex / two-defeats exit / inheritance.
# Rivals never run an operations menu — power is a curve, everything else is a mapping.


class RivalState:
	extends RefCounted
	var id: StringName                 # class id (science_state…), design vocabulary
	var display_name: String           # drawn from the naming table at setup; the ONLY UI name
	var power: float = 0.0
	var alive: bool = true
	var warred_this_window: bool = false   # reset after each world war
	var defeats: int = 0                   # civil-war losses (any side); 2 => exit
	var psyops_discount: float = 0.0       # accumulated attack discount, cap 0.30 (7折)
	var player_influence: float = 0.0      # player's influence ON this rival
	var rival_influence: Dictionary = {}   # other rival id -> influence on this rival
	var penalty_mult: float = 1.0          # ×0.9 per civil-war defeat
	var power_bonus: float = 0.0           # inherited power (+50% of an exited rival)


static func setup(state: GameState) -> void:
	# 每場開局各分類抽一個名字; 首次接觸 +5 influence (all met at generation 1 — driver decision).
	for class_id: StringName in RivalData.CLASSES.keys():
		var rival := RivalState.new()
		rival.id = class_id
		rival.display_name = String(state.rng.pick(&"naming", RivalData.CLASSES[class_id]["names"]))
		rival.player_influence = 5.0
		rival.power = base_power(class_id, state.generation, state.difficulty)
		state.rivals.append(rival)
	# No hegemony/catch-up here — those are per-settle effects (update_powers).


static func base_power(class_id: StringName, generation: int, difficulty: StringName) -> float:
	var entry: Dictionary = RivalData.CLASSES[class_id]
	var delta: float = float(RivalData.DIFFICULTY_G_DELTA[difficulty])
	var g: float = float(entry["g"]) + delta
	if entry.has("g_switch_gen") and generation > int(entry["g_switch_gen"]):
		var switch_gen: int = int(entry["g_switch_gen"])
		var g_late: float = float(entry["g_late"]) + delta
		return float(entry["p0"]) * pow(g, switch_gen) * pow(g_late, generation - switch_gen)
	return float(entry["p0"]) * pow(g, generation)


static func update_powers(state: GameState) -> void:
	# Called each settle. At WW−1 the bounded catch-up band is applied (near-invisible).
	for rival: RivalState in state.rivals:
		if not rival.alive:
			continue
		rival.power = base_power(rival.id, state.generation, state.difficulty) * rival.penalty_mult + rival.power_bonus
	if state.generation == 14 or state.generation == 34:
		_apply_catchup(state)
	_apply_hegemony_influence(state)


static func player_power(state: GameState) -> int:
	# 人口 + 文化 + 幸福/10 + 科技 + 建築階數總和 + 牌組實力總和/10
	var tiers: int = 0
	for line_id: StringName in state.buildings.keys():
		tiers += int(state.buildings[line_id])
	@warning_ignore("integer_division")
	return state.population + state.culture + state.happiness / 10 + state.tech + tiers + Cards.deck_strength(state) / 10


static func find(state: GameState, rival_id: StringName) -> RivalState:
	for rival: RivalState in state.rivals:
		if rival.id == rival_id:
			return rival
	return null


static func living(state: GameState) -> Array[RivalState]:
	var out: Array[RivalState] = []
	for rival: RivalState in state.rivals:
		if rival.alive:
			out.append(rival)
	return out


# --- power-scalar mappings ---

static func treasury_of(rival: RivalState) -> int:
	return int(rival.power * RivalData.TREASURY_PER_POWER)


static func culture_of(rival: RivalState) -> int:
	return int(rival.power * RivalData.CULTURE_PER_POWER)


static func attack_multiplier(rival: RivalState) -> float:
	return 1.0 - minf(rival.psyops_discount, RivalData.PSYOPS_DISCOUNT_CAP)


# --- player verbs (operate phase) ---

static func declare_war(state: GameState, rival_id: StringName) -> Dictionary:
	# 1 BP, no money (出兵成本已在軍費裡); next node becomes a civil war vs them.
	var rival := find(state, rival_id)
	if rival == null or not rival.alive:
		return {"ok": false, "reason": &"not_alive"}
	if state.is_democracy:
		return {"ok": false, "reason": &"democracy"}
	if state.bp < 1:
		return {"ok": false, "reason": &"no_bp"}
	if state.pending_war_target != &"":
		return {"ok": false, "reason": &"war_already_pending"}
	state.bp -= 1
	state.pending_war_target = rival_id
	return {"ok": true, "reason": &""}


static func psyops(state: GameState, rival_id: StringName) -> Dictionary:
	# 1 BP; condition: your culture ABOVE theirs (threshold, not consumed);
	# −10%/use (−15% with 傳播線) permanent attack discount, 7折 cap;
	# once per generation shared across ALL rivals.
	var rival := find(state, rival_id)
	if rival == null or not rival.alive:
		return {"ok": false, "reason": &"not_alive"}
	if state.is_democracy:
		return {"ok": false, "reason": &"democracy"}
	if state.psyops_used_this_gen:
		return {"ok": false, "reason": &"used_this_generation"}
	if state.culture <= culture_of(rival):
		return {"ok": false, "reason": &"culture_too_low"}
	if state.bp < 1:
		return {"ok": false, "reason": &"no_bp"}
	state.bp -= 1
	state.psyops_used_this_gen = true
	rival.psyops_discount = minf(rival.psyops_discount + Operations.psyops_potency(state), RivalData.PSYOPS_DISCOUNT_CAP)
	rival.player_influence += 5.0
	return {"ok": true, "reason": &"", "discount": rival.psyops_discount}


# --- rival behavior per generation ---

static func roll_aggression(state: GameState) -> StringName:
	# Returns the id of a rival attacking this generation (injected as an extra node), or &"".
	for rival: RivalState in living(state):
		var period: int = int(RivalData.CLASSES[rival.id]["attack_period"])
		if period > 0 and state.rng.chance(&"rivals", 1.0 / float(period)):
			return rival.id
	return &""


static func roll_enemy_psyops(state: GameState) -> bool:
	# 文化國: 對你心戰 — your next battle starts with opening hand −1.
	var rival := find(state, &"culture_state")
	if rival == null or not rival.alive:
		return false
	var period: int = int(RivalData.CLASSES[&"culture_state"]["psyops_player_period"])
	if state.rng.chance(&"rivals", 1.0 / float(period)):
		state.flags[&"enemy_psyops_next_battle"] = true
		return true
	return false


# --- war outcomes (Battle/Turn call these) ---

static func record_civil_war(state: GameState, rival_id: StringName, player_won: bool) -> Dictionary:
	# 文明戰爭（每場，不論勝敗）: influence +15, 開戰過 window flag; loser's power suffers.
	var rival := find(state, rival_id)
	rival.warred_this_window = true
	rival.player_influence += 15.0
	var report: Dictionary = {"rival": rival_id, "player_won": player_won}
	if not player_won:
		return report
	rival.defeats += 1
	rival.penalty_mult *= RivalData.DEFEAT_POWER_PENALTY
	rival.power *= RivalData.DEFEAT_POWER_PENALTY
	if rival.power < float(player_power(state)) * RivalData.ANNEX_POWER_THRESHOLD:
		report["annexed"] = true
		report["gains"] = annex(state, rival)
	elif rival.defeats >= 2:
		report["exited"] = true
		report["inheritance"] = _exit_and_inherit(state, rival)
	return report


static func annex(state: GameState, rival: RivalState) -> Dictionary:
	# 併吞: +其正國庫 50% + 人口 20%; counts for 文化大熔爐.
	@warning_ignore("integer_division")
	var money: int = maxi(treasury_of(rival), 0) / 2
	var pop: int = int(rival.power * RivalData.POPULATION_PER_POWER * 0.2)
	state.treasury += money
	state.population += pop
	rival.alive = false
	state.flags[&"annexed_count"] = int(state.flags.get(&"annexed_count", 0)) + 1
	state.flags[&"first_annex_gen"] = int(state.flags.get(&"first_annex_gen", state.generation))
	return {"money": money, "population": pop}


static func _exit_and_inherit(state: GameState, exiting: RivalState) -> Dictionary:
	# 退場: inherited by whoever holds the most influence on it (ties -> higher power).
	exiting.alive = false
	var best_id: StringName = &"player"
	var best_influence: float = exiting.player_influence
	var best_power: float = float(player_power(state))
	for other: RivalState in living(state):
		var influence: float = float(exiting.rival_influence.get(other.id, 0.0))
		if influence > best_influence or (influence == best_influence and other.power > best_power):
			best_id = other.id
			best_influence = influence
			best_power = other.power
	if best_id == &"player":
		var gains := annex(state, exiting)   # 比照併吞, counts for 文化大熔爐
		exiting.alive = false
		return {"heir": &"player", "gains": gains}
	var heir := find(state, best_id)
	heir.power_bonus += exiting.power * 0.5
	heir.power += exiting.power * 0.5
	return {"heir": best_id}


static func on_world_war_end(state: GameState) -> void:
	# 開戰過 window resets after each world war (defeats in WW don't count toward exit).
	for rival: RivalState in state.rivals:
		rival.warred_this_window = false


static func only_player_remains(state: GameState) -> bool:
	return living(state).is_empty()


# --- internals ---

static func _apply_catchup(state: GameState) -> void:
	# Bounded, near-invisible band at WW−1: strongest rival lifted to ≥ player×0.65
	# (max +25%) and cut to ≤ player×1.5 (max −25%, the player-protection ceiling).
	var alive := living(state)
	if alive.is_empty():
		return
	var strongest: RivalState = alive[0]
	for rival: RivalState in alive:
		if rival.power > strongest.power:
			strongest = rival
	var target: float = float(player_power(state))
	if strongest.power < target * RivalData.CATCHUP_FLOOR:
		strongest.power = minf(target * RivalData.CATCHUP_FLOOR, strongest.power * RivalData.CATCHUP_MAX_BOOST)
	elif strongest.power > target * RivalData.CATCHUP_CEILING:
		strongest.power = maxf(target * RivalData.CATCHUP_CEILING, strongest.power * RivalData.CATCHUP_MAX_CUT)


static func _apply_hegemony_influence(state: GameState) -> void:
	# 霸權滲透: this generation's power #1 (player included) gains +1 influence on all others.
	var top_power: float = float(player_power(state))
	var top_id: StringName = &"player"
	for rival: RivalState in living(state):
		if rival.power > top_power:
			top_power = rival.power
			top_id = rival.id
	for rival: RivalState in living(state):
		if rival.id == top_id:
			continue
		if top_id == &"player":
			rival.player_influence += 1.0
		else:
			rival.rival_influence[top_id] = float(rival.rival_influence.get(top_id, 0.0)) + 1.0
