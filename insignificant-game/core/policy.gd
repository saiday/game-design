class_name Policy
extends RefCounted
# 國策 (design/國策.md): DAG progression over PolicyNodes. Research = locking BP into one
# node at a time (≤2 BP/generation, always leave ≥1 free BP); switching pauses a node and
# keeps its progress; frozen during world wars and after democracy. No mutex anywhere.
# Rule-modifier effects are membership queries (state.policies.has(id)) owned by consumer
# modules; this module applies only the one-shot completion effects.

const PER_GEN_LOCK_CAP: int = 2
const MIN_FREE_BP: int = 1


static func on_generation_start(state: GameState) -> void:
	state.policy_bp_this_gen = 0


static func completed(state: GameState, node_id: StringName) -> bool:
	return state.policies.has(node_id)


static func prerequisites_met(state: GameState, node_id: StringName) -> bool:
	var node: Dictionary = PolicyNodes.NODES[node_id]
	for req: StringName in node["requires_all"]:
		if not state.policies.has(req):
			return false
	for group: Array in node["requires_any"]:
		var any_met := false
		for option: StringName in group:
			if state.policies.has(option):
				any_met = true
				break
		if not any_met:
			return false
	return true


static func available(state: GameState) -> Array[StringName]:
	var out: Array[StringName] = []
	for node_id: StringName in PolicyNodes.NODES.keys():
		if not completed(state, node_id) and prerequisites_met(state, node_id):
			out.append(node_id)
	return out


static func progress(state: GameState, node_id: StringName) -> int:
	return int(state.policy_progress.get(node_id, 0))


static func frozen(state: GameState) -> bool:
	return Era.is_world_war(state.generation) or state.is_democracy


static func invest(state: GameState, node_id: StringName, amount: int) -> Dictionary:
	if not PolicyNodes.NODES.has(node_id):
		return {"ok": false, "reason": &"unknown_node"}
	if completed(state, node_id):
		return {"ok": false, "reason": &"already_completed"}
	if not prerequisites_met(state, node_id):
		return {"ok": false, "reason": &"prerequisites"}
	if frozen(state):
		return {"ok": false, "reason": &"frozen"}
	if amount < 1:
		return {"ok": false, "reason": &"bad_amount"}
	if state.policy_bp_this_gen + amount > PER_GEN_LOCK_CAP:
		return {"ok": false, "reason": &"gen_cap"}
	if state.bp - amount < MIN_FREE_BP:
		return {"ok": false, "reason": &"must_keep_free_bp"}
	# Switching to another node just changes the pointer; prior progress stays banked.
	state.policy_in_progress = node_id
	state.bp -= amount
	state.policy_bp_this_gen += amount
	var invested: int = progress(state, node_id) + amount
	var cost: int = int(PolicyNodes.NODES[node_id]["cost_bp"])
	if invested < cost:
		state.policy_progress[node_id] = invested
		return {"ok": true, "reason": &"", "completed": false, "invested": invested, "cost": cost}
	# Overshoot is impossible in practice (invest ≤2 at a time), but clamp anyway.
	state.policy_progress.erase(node_id)
	state.policies.append(node_id)
	state.policy_in_progress = &""
	var effects: Dictionary = _apply_completion(state, node_id)
	return {"ok": true, "reason": &"", "completed": true, "invested": cost, "cost": cost, "effects": effects}


static func _apply_completion(state: GameState, node_id: StringName) -> Dictionary:
	# One-shot completion effects only. Rule modifiers are membership queries elsewhere.
	var applied: Dictionary = {}
	match node_id:
		&"secret_police":
			applied["happiness"] = Happiness.adjust(state, -5)
			state.martial_law_available = true
			_grant_legacy(state, &"martial_law")
		&"cultural_revolution":
			state.happiness = 100
			var before: int = state.population
			@warning_ignore("integer_division")
			state.population = state.population * 4 / 5
			applied["population_lost"] = before - state.population
		&"enlightened_absolutism":
			applied["happiness"] = Happiness.adjust(state, 10)
		&"state_religion":
			applied["happiness"] = Happiness.apply_state_religion(state)
			_grant_legacy(state, &"religious_dogma")
			_check_church_state_compromise(state)
		&"secularization":
			_grant_legacy(state, &"rational_spirit")
			_check_church_state_compromise(state)
		&"moon_race":
			state.tech += 30
			applied["tech"] = state.tech
		&"world_expo":
			var money: int = 50 * Era.coeff(state.generation)
			state.treasury += money
			state.culture += 5
			_add_influence_all_living(state, 10.0)
			applied["money"] = money
		&"political_marriage":
			_add_influence_all_living(state, 5.0)
	applied["node"] = node_id
	return applied


static func _grant_legacy(state: GameState, legacy_id: StringName) -> void:
	if not state.legacies.has(legacy_id):
		state.legacies.append(legacy_id)


static func _check_church_state_compromise(state: GameState) -> void:
	# 國教＋推行世俗同修: no mutex — both completed triggers the 政教妥協 event copy.
	if state.policies.has(&"state_religion") and state.policies.has(&"secularization"):
		state.flags[&"church_state_compromise"] = true


static func _add_influence_all_living(state: GameState, amount: float) -> void:
	# RivalState (rivals.gd, W3) carries player_influence; duck-typed so W2 has no
	# hard dependency. No-op on an empty rivals array.
	for rival: Variant in state.rivals:
		if rival.alive:
			rival.player_influence += amount
