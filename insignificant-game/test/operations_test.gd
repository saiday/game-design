class_name OperationsTest
extends GdUnitTestSuite


func _state() -> GameState:
	return GameState.new_run(42)


func test_bp_income_floor_and_pop() -> void:
	var s := _state()
	s.population = 12
	assert_int(Operations.bp_income(s)).is_equal(1)
	s.population = 5
	assert_int(Operations.bp_income(s)).is_equal(1)
	s.population = 20
	assert_int(Operations.bp_income(s)).is_equal(2)


func test_bp_income_era_cap() -> void:
	var s := _state()
	s.population = 90
	s.generation = 1
	assert_int(Operations.bp_income(s)).is_equal(2)
	s.generation = 25
	assert_int(Operations.bp_income(s)).is_equal(4)
	s.generation = 41
	assert_int(Operations.bp_income(s)).is_equal(5)


func test_grant_bp_consumes_carryover() -> void:
	var s := _state()
	s.population = 12
	s.bp_carryover = 2
	Operations.grant_bp(s)
	assert_int(s.bp).is_equal(3)
	assert_int(s.bp_carryover).is_equal(0)


func test_grant_bp_democracy_noop() -> void:
	var s := _state()
	s.is_democracy = true
	s.bp_carryover = 2
	Operations.grant_bp(s)
	assert_int(s.bp).is_equal(0)


func test_carryover_cap() -> void:
	var s := _state()
	s.bp = 5
	Operations.end_operate_phase(s)
	assert_int(s.bp_carryover).is_equal(2)
	assert_int(s.bp).is_equal(0)
	s.bp = 5
	s.policies.append(&"enlightened_absolutism")
	Operations.end_operate_phase(s)
	assert_int(s.bp_carryover).is_equal(3)


func test_escalation_counts_builds_not_upgrades() -> void:
	var s := _state()
	assert_float(Operations.escalation(s)).is_equal_approx(1.0, 0.001)
	s.bp = 10
	s.regions.append(&"livelihood")
	Operations.build_building(s, &"housing")
	Operations.build_building(s, &"food")
	assert_float(Operations.escalation(s)).is_equal_approx(1.5, 0.001)
	s.generation = 9   # classical: tier 2 allowed
	Operations.upgrade_building(s, &"housing")
	assert_float(Operations.escalation(s)).is_equal_approx(1.5, 0.001)


func test_build_region_cost_and_guards() -> void:
	var s := _state()
	s.bp = 1
	var r := Operations.build_region(s, &"livelihood")
	assert_bool(r["ok"]).is_true()
	assert_int(int(r["cost"])).is_equal(20)
	assert_int(s.treasury).is_equal(10)
	assert_int(s.bp).is_equal(0)
	var again := Operations.build_region(s, &"livelihood")
	assert_that(again["reason"]).is_equal(&"already_built")
	var no_bp := Operations.build_region(s, &"finance")
	assert_that(no_bp["reason"]).is_equal(&"no_bp")


func test_build_building_requires_region() -> void:
	var s := _state()
	s.bp = 1
	var r := Operations.build_building(s, &"housing")
	assert_that(r["reason"]).is_equal(&"region_missing")


func test_build_building_cost_escalates() -> void:
	var s := _state()
	s.bp = 10
	s.regions.append(&"livelihood")
	var first := Operations.build_building(s, &"housing")   # 10×1×1.0
	assert_int(int(first["cost"])).is_equal(10)
	var second := Operations.build_building(s, &"food")     # 10×1×1.25
	assert_int(int(second["cost"])).is_equal(12)
	assert_int(s.buildings_built).is_equal(2)


func test_upgrade_era_cap_and_cost() -> void:
	var s := _state()
	s.bp = 10
	s.regions.append(&"livelihood")
	Operations.build_building(s, &"housing")
	var capped := Operations.upgrade_building(s, &"housing")   # tribal: tier 2 locked
	assert_that(capped["reason"]).is_equal(&"era_capped")
	s.generation = 9   # classical, coeff 2, escalation 1.25
	var up := Operations.upgrade_building(s, &"housing")       # 10×2×1.25 = 25
	assert_bool(up["ok"]).is_true()
	assert_int(int(up["cost"])).is_equal(25)
	assert_int(int(s.buildings[&"housing"])).is_equal(2)
	assert_int(s.buildings_built).is_equal(1)


func test_debt_office_era_gate_and_min_tier() -> void:
	var s := _state()
	s.bp = 10
	s.regions.append(&"finance")
	s.generation = 9   # classical — too early
	var early := Operations.build_building(s, &"debt_office")
	assert_that(early["reason"]).is_equal(&"era_locked")
	s.generation = 17  # faith
	var ok := Operations.build_building(s, &"debt_office")
	assert_bool(ok["ok"]).is_true()
	assert_int(int(s.buildings[&"debt_office"])).is_equal(3)


func test_production_empty_state() -> void:
	var s := _state()
	var p := Operations.production(s)
	assert_int(int(p["population"])).is_equal(0)
	assert_int(int(p["income"])).is_equal(0)
	assert_int(int(p["pop_cap"])).is_equal(20)


func test_production_sums_regions_and_lines() -> void:
	var s := _state()
	s.regions.append(&"livelihood")
	s.regions.append(&"finance")
	s.regions.append(&"culture")
	s.buildings[&"housing"] = 2
	s.buildings[&"arts"] = 1
	s.buildings[&"commerce"] = 1
	var p := Operations.production(s)
	assert_int(int(p["population"])).is_equal(1)   # housing
	assert_int(int(p["happiness"])).is_equal(1)    # arts
	assert_int(int(p["culture"])).is_equal(2)      # culture region + arts
	assert_int(int(p["income"])).is_equal(4)       # finance region + commerce
	assert_int(int(p["pop_cap"])).is_equal(40)     # 20 base + 10 region + 5×2 housing


func test_combat_flags() -> void:
	var s := _state()
	assert_int(Operations.opening_hand_bonus(s)).is_equal(0)
	assert_float(Operations.psyops_potency(s)).is_equal_approx(0.10, 0.001)
	s.regions.append(&"military")
	s.buildings[&"barracks"] = 1
	s.buildings[&"media"] = 1
	assert_int(Operations.opening_hand_bonus(s)).is_equal(1)
	assert_int(Operations.opening_slots_bonus(s)).is_equal(1)
	assert_float(Operations.psyops_potency(s)).is_equal_approx(0.15, 0.001)
	assert_int(Operations.card_pool_tier(s, &"barracks")).is_equal(1)
	assert_int(Operations.card_pool_tier(s, &"arsenal")).is_equal(0)
