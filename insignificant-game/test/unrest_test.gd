class_name UnrestTest
extends GdUnitTestSuite


func _state() -> GameState:
	return GameState.new_run(5)


func test_weight_base() -> void:
	var s := _state()   # happiness 70, treasury 30
	assert_float(Unrest.weight(s)).is_equal_approx(0.15, 0.001)


func test_weight_low_happiness() -> void:
	var s := _state()
	s.happiness = 59
	assert_float(Unrest.weight(s)).is_equal_approx(0.35, 0.001)


func test_weight_debt_only_in_unrest_mode() -> void:
	var s := _state()
	s.treasury = -200
	assert_float(Unrest.weight(s)).is_equal_approx(0.15, 0.001)   # pre-國債司: hits happiness instead
	s.debt_unrest_mode = true
	assert_float(Unrest.weight(s)).is_equal_approx(0.35, 0.001)   # +10%×(200/100)


func test_weight_policy_reductions_and_floor() -> void:
	var s := _state()
	s.policies.append(&"centralization")
	s.policies.append(&"secret_police")
	s.policies.append(&"theocracy")
	assert_float(Unrest.weight(s)).is_equal_approx(0.0, 0.001)    # 0.15−0.25 floored at 0


func test_weight_cap() -> void:
	var s := _state()
	s.happiness = 30
	s.debt_unrest_mode = true
	s.treasury = -400
	assert_float(Unrest.weight(s)).is_equal_approx(0.60, 0.001)   # 0.15+0.20+0.40 capped


func test_roll_at_most_once_per_generation() -> void:
	var s := _state()
	s.happiness = 0
	s.debt_unrest_mode = true
	s.treasury = -1000   # weight pinned to cap 0.6
	var triggered := false
	for i: int in range(200):
		if Unrest.roll(s):
			triggered = true
			break
	assert_bool(triggered).is_true()
	assert_int(s.unrest_battles_this_gen).is_equal(1)
	assert_bool(Unrest.roll(s)).is_false()


func test_concession_cost_and_ancestor_worship() -> void:
	var s := _state()
	assert_int(Unrest.concession_cost(s)).is_equal(40)
	s.generation = 25   # coeff 5
	assert_int(Unrest.concession_cost(s)).is_equal(200)
	s.policies.append(&"ancestor_worship")
	assert_int(Unrest.concession_cost(s)).is_equal(100)


func test_apply_concession() -> void:
	var s := _state()
	s.treasury = 10
	s.happiness = 50
	var r := Unrest.apply_concession(s)
	assert_int(s.treasury).is_equal(-30)   # may go negative
	assert_int(s.happiness).is_equal(55)
	assert_bool(bool(r["battle_cancelled"])).is_true()


func test_martial_law_one_shot() -> void:
	var s := _state()
	assert_bool(Unrest.use_martial_law(s)).is_false()
	s.martial_law_available = true
	assert_bool(Unrest.use_martial_law(s)).is_true()
	assert_bool(Unrest.use_martial_law(s)).is_false()


func test_riot_loss_removes_region_buildings_and_pop() -> void:
	var s := _state()
	s.population = 20
	s.regions.append(&"livelihood")
	s.buildings[&"housing"] = 1
	s.buildings[&"school"] = 1   # academic — must survive
	var r := Unrest.apply_riot_loss(s)
	assert_that(r["region_lost"]).is_equal(&"livelihood")
	assert_bool(s.buildings.has(&"housing")).is_false()
	assert_bool(s.buildings.has(&"school")).is_true()
	assert_int(s.population).is_equal(16)


func test_regime_collapse_threshold() -> void:
	var s := _state()
	s.population = 5
	assert_bool(Unrest.regime_collapsed(s)).is_false()
	s.population = 4
	assert_bool(Unrest.regime_collapsed(s)).is_true()
