extends SceneTree
# Headless balance batch: N seeded Sim runs per difficulty -> JSON telemetry on the three
# sensitive knobs (BP curve, escalation 0.25, unrest weights).
#   $GODOT_BIN --headless --path . -s tools/balance_batch.gd
# Output: res://reports/balance_batch.json

const SEEDS: int = 20


func _init() -> void:
	var rows: Array = []
	for difficulty: StringName in [&"easy", &"normal", &"hard"]:
		for seed_value: int in range(1, SEEDS + 1):
			rows.append(_summarize(Sim.run(seed_value, difficulty), seed_value, difficulty))
	var out := FileAccess.open("res://reports/balance_batch.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(rows, "  "))
	out.close()
	print("BALANCE BATCH DONE: %d runs -> reports/balance_batch.json" % rows.size())
	quit(0)


func _summarize(result: Dictionary, seed_value: int, difficulty: StringName) -> Dictionary:
	var state: GameState = result["state"]
	var ending: Dictionary = result["ending"]
	var treasury_min: int = 0
	var debt_generations: int = 0
	var bp_by_era: Dictionary = {}
	var last: Dictionary = state.log[state.log.size() - 1] if not state.log.is_empty() else {}
	for snapshot: Dictionary in state.log:
		treasury_min = mini(treasury_min, int(snapshot["treasury"]))
		if int(snapshot["treasury"]) < 0:
			debt_generations += 1
		var era: StringName = snapshot["era"]
		if not bp_by_era.has(era):
			bp_by_era[era] = 0
	return {
		"seed": seed_value,
		"difficulty": String(difficulty),
		"ending": String(ending.get("kind", &"none")),
		"rank": int(ending.get("rank", 0)),
		"generations": int(result["generations"]),
		"final_population": state.population,
		"final_treasury": state.treasury,
		"final_culture": state.culture,
		"final_tech": state.tech,
		"final_happiness": state.happiness,
		"treasury_min": treasury_min,
		"debt_generations": debt_generations,
		"buildings_built": state.buildings_built,
		"escalation_final": Operations.escalation(state),
		"policies_completed": state.policies.size(),
		"deck_size": state.deck.size(),
		"unrest_triggers": int(state.flags.get(&"unrest_triggered_total", 0)),
		"rivals_alive": Rivals.living(state).size(),
		"is_democracy": state.is_democracy,
		"player_power": Rivals.player_power(state),
	}
