class_name SimTest
extends GdUnitTestSuite
# Full-run seeded simulations: the invariant net over everything at once.


func test_full_runs_terminate() -> void:
	for seed_value: int in [1, 7, 42]:
		var result := Sim.run(seed_value)
		var state: GameState = result["state"]
		var ending: Dictionary = result["ending"]
		assert_bool(bool(ending["over"])).is_true()
		assert_bool(state.generation <= 61).is_true()
		assert_int(int(result["generations"])).is_greater(5)


func test_determinism_same_seed_same_run() -> void:
	var a := Sim.run(123)
	var b := Sim.run(123)
	var state_a: GameState = a["state"]
	var state_b: GameState = b["state"]
	assert_int(state_a.generation).is_equal(state_b.generation)
	assert_int(state_a.treasury).is_equal(state_b.treasury)
	assert_int(state_a.population).is_equal(state_b.population)
	assert_int(state_a.log.size()).is_equal(state_b.log.size())
	assert_that((a["ending"] as Dictionary)["kind"]).is_equal((b["ending"] as Dictionary)["kind"])


func test_invariants_hold_every_generation() -> void:
	var result := Sim.run(9)
	var state: GameState = result["state"]
	for snapshot: Dictionary in state.log:
		var happiness: int = int(snapshot["happiness"])
		assert_bool(happiness >= 0 and happiness <= 100).is_true()
		assert_bool(int(snapshot["population"]) >= 0).is_true()
		assert_bool(float(snapshot["unrest_weight"]) <= 0.6).is_true()
		assert_bool(int(snapshot["bp"]) >= 0).is_true()


func test_run_produces_balance_telemetry() -> void:
	var result := Sim.run(5)
	var state: GameState = result["state"]
	assert_bool(state.log.size() > 0).is_true()
	var last: Dictionary = state.log[state.log.size() - 1]
	assert_bool(last.has("buildings_built")).is_true()   # escalation knob input
	assert_bool(last.has("treasury")).is_true()
	# the run actually engaged the systems: something got built, money moved
	assert_bool(int(last["buildings_built"]) > 0).is_true()


func test_hard_and_easy_both_complete() -> void:
	for difficulty: StringName in [&"easy", &"hard"]:
		var result := Sim.run(11, difficulty)
		assert_bool(bool((result["ending"] as Dictionary)["over"])).is_true()
