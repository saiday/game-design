class_name GameStateTest
extends GdUnitTestSuite


func test_new_run_defaults() -> void:
	var state := GameState.new_run(123)
	assert_int(state.generation).is_equal(1)
	assert_int(state.population).is_equal(12)
	assert_int(state.happiness).is_equal(70)
	assert_int(state.treasury).is_equal(30)
	assert_int(state.culture).is_equal(0)
	assert_int(state.tech).is_equal(0)
	assert_that(state.difficulty).is_equal(&"normal")
	assert_bool(state.is_democracy).is_false()
	assert_bool(state.rng != null).is_true()


func test_new_run_rng_is_seeded_from_run_seed() -> void:
	var a := GameState.new_run(555)
	var b := GameState.new_run(555)
	assert_int(a.rng.randi_range(&"map", 0, 10000)).is_equal(b.rng.randi_range(&"map", 0, 10000))


func test_instances_are_independent() -> void:
	var a := GameState.new_run(1)
	var b := GameState.new_run(2)
	a.regions.append(&"livelihood")
	a.buildings[&"housing"] = 2
	assert_int(b.regions.size()).is_equal(0)
	assert_int(b.buildings.size()).is_equal(0)


func test_to_dict_snapshot() -> void:
	var state := GameState.new_run(99)
	state.generation = 17
	state.treasury = -40
	var snap := state.to_dict()
	assert_that(snap["era"]).is_equal(&"faith")
	assert_int(snap["treasury"]).is_equal(-40)
	assert_int(snap["rivals_alive"]).is_equal(0)
	assert_int(snap["deck_size"]).is_equal(0)
	# snapshot is detached from live state
	(snap["regions"] as Array).append(&"finance")
	assert_int(state.regions.size()).is_equal(0)
