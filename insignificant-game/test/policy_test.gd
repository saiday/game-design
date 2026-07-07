class_name PolicyTest
extends GdUnitTestSuite


func _state() -> GameState:
	var s := GameState.new_run(21)
	s.generation = 9   # classical — outside WW generations
	return s


func _complete(state: GameState, node_id: StringName) -> void:
	# Test helper: force-complete without effects (for prerequisite fixtures).
	state.policies.append(node_id)


func test_data_totals() -> void:
	assert_int(PolicyNodes.NODES.size()).is_equal(24)
	var total := 0
	for node_id: StringName in PolicyNodes.NODES.keys():
		total += int(PolicyNodes.NODES[node_id]["cost_bp"])
	assert_int(total).is_equal(139)


func test_six_roots_available_at_start() -> void:
	var s := _state()
	var roots := Policy.available(s)
	assert_int(roots.size()).is_equal(6)
	for root: StringName in [&"centralization", &"writing_calendar", &"ancestor_worship", &"hundred_schools", &"great_voyage", &"scout_camp"]:
		assert_bool(roots.has(root)).is_true()


func test_requires_any_gating() -> void:
	var s := _state()
	_complete(s, &"scout_camp")
	# political_marriage: scout_camp + (state_religion / bureaucracy)
	assert_bool(Policy.prerequisites_met(s, &"political_marriage")).is_false()
	_complete(s, &"bureaucracy")
	assert_bool(Policy.prerequisites_met(s, &"political_marriage")).is_true()


func test_invest_caps_and_free_bp() -> void:
	var s := _state()
	s.bp = 2
	var too_greedy := Policy.invest(s, &"centralization", 2)   # would leave 0 free
	assert_that(too_greedy["reason"]).is_equal(&"must_keep_free_bp")
	s.bp = 4
	var first := Policy.invest(s, &"centralization", 2)
	assert_bool(first["ok"]).is_true()
	var over_cap := Policy.invest(s, &"centralization", 1)     # 3 > 2 this generation
	assert_that(over_cap["reason"]).is_equal(&"gen_cap")
	Policy.on_generation_start(s)
	s.bp = 4
	var next_gen := Policy.invest(s, &"centralization", 2)
	assert_bool(next_gen["ok"]).is_true()
	assert_bool(next_gen["completed"]).is_true()               # 4/4 BP
	assert_bool(s.policies.has(&"centralization")).is_true()


func test_frozen_in_world_war_and_democracy() -> void:
	var s := _state()
	s.bp = 4
	s.generation = 15
	assert_that(Policy.invest(s, &"centralization", 1)["reason"]).is_equal(&"frozen")
	s.generation = 9
	s.is_democracy = true
	assert_that(Policy.invest(s, &"centralization", 1)["reason"]).is_equal(&"frozen")


func test_switching_keeps_progress() -> void:
	var s := _state()
	s.bp = 4
	Policy.invest(s, &"centralization", 2)
	Policy.on_generation_start(s)
	s.bp = 4
	Policy.invest(s, &"hundred_schools", 2)   # switch away
	assert_int(Policy.progress(s, &"centralization")).is_equal(2)
	Policy.on_generation_start(s)
	s.bp = 4
	var back := Policy.invest(s, &"centralization", 2)
	assert_bool(back["completed"]).is_true()


func test_secret_police_effects() -> void:
	var s := _state()
	_complete(s, &"centralization")
	_complete(s, &"bureaucracy")
	s.happiness = 70
	s.bp = 10
	for i: int in range(3):
		Policy.on_generation_start(s)
		Policy.invest(s, &"secret_police", 2)
	assert_bool(s.policies.has(&"secret_police")).is_true()
	assert_int(s.happiness).is_equal(65)
	assert_bool(s.martial_law_available).is_true()
	assert_bool(s.legacies.has(&"martial_law")).is_true()


func test_cultural_revolution_effects() -> void:
	var s := _state()
	_complete(s, &"secret_police")
	_complete(s, &"mass_media")
	s.happiness = 40
	s.population = 50
	s.bp = 10
	for i: int in range(3):
		Policy.on_generation_start(s)
		Policy.invest(s, &"cultural_revolution", 2)
	assert_int(s.happiness).is_equal(100)
	assert_int(s.population).is_equal(40)


func test_state_religion_and_compromise_flag() -> void:
	var s := _state()
	_complete(s, &"ancestor_worship")
	s.happiness = 50
	s.bp = 10
	for i: int in range(3):
		Policy.on_generation_start(s)
		Policy.invest(s, &"state_religion", 2)
	assert_int(s.happiness).is_equal(80)
	assert_bool(s.legacies.has(&"religious_dogma")).is_true()
	assert_bool(s.flags.has(&"church_state_compromise")).is_false()
	_complete(s, &"writing_calendar")
	_complete(s, &"hundred_schools")
	for i: int in range(3):
		Policy.on_generation_start(s)
		s.bp = 10
		Policy.invest(s, &"secularization", 2)
	assert_bool(s.legacies.has(&"rational_spirit")).is_true()
	assert_bool(bool(s.flags[&"church_state_compromise"])).is_true()


func test_world_expo_one_shots() -> void:
	var s := _state()
	_complete(s, &"world_map")
	_complete(s, &"mass_media")
	s.generation = 25   # coeff 5
	s.treasury = 0
	s.bp = 10
	for i: int in range(4):
		Policy.on_generation_start(s)
		Policy.invest(s, &"world_expo", 2)
	assert_bool(s.policies.has(&"world_expo")).is_true()
	assert_int(s.treasury).is_equal(250)
	assert_int(s.culture).is_equal(5)


func test_moon_race_tech() -> void:
	var s := _state()
	_complete(s, &"patent_system")
	s.bp = 10
	for i: int in range(4):
		Policy.on_generation_start(s)
		Policy.invest(s, &"moon_race", 2)
	assert_int(s.tech).is_equal(30)
