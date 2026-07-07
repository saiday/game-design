class_name DemocracyTest
extends GdUnitTestSuite


func _state() -> GameState:
	var s := GameState.new_run(66)
	s.generation = 36
	s.culture = 25
	return s


func test_unlock_threshold() -> void:
	var s := _state()
	s.culture = 20
	assert_bool(Democracy.unlocked(s)).is_false()
	s.culture = 21
	assert_bool(Democracy.unlocked(s)).is_true()


func test_enter_voluntary_grants_legacy_and_cuts_treasury() -> void:
	var s := _state()
	s.treasury = 100
	var r := Democracy.enter(s, true)
	assert_bool(bool(r["ok"])).is_true()
	assert_bool(s.is_democracy).is_true()
	assert_int(s.treasury).is_equal(40)   # 國庫的 40% 轉為貴族資金
	assert_bool(s.legacies.has(&"democratic_spirit")).is_true()
	assert_int(s.candidate_pool.size()).is_equal(10)
	assert_bool(s.incumbent != &"").is_true()
	assert_that(Democracy.enter(s, true)["reason"]).is_equal(&"already_democracy")


func test_forced_entry_no_legacy_no_unlock_needed() -> void:
	var s := _state()
	s.culture = 0
	var r := Democracy.enter(s, false)
	assert_bool(bool(r["ok"])).is_true()
	assert_bool(s.legacies.has(&"democratic_spirit")).is_false()


func test_negative_treasury_not_reduced() -> void:
	var s := _state()
	s.treasury = -80
	Democracy.enter(s, true)
	assert_int(s.treasury).is_equal(-80)   # debt follows you into democracy


func test_media_bias_boosts_tendency() -> void:
	var s := _state()
	s.policies.append(&"mass_media")
	s.flags[&"media_pool_bias"] = &"tech"
	Democracy.enter(s, true)
	for entry: Dictionary in s.candidate_pool:
		var expected: float = 20.0 if entry["id"] == &"technocrat" else 10.0
		assert_float(float(entry["chance"])).is_equal_approx(expected, 0.01)


func test_fund_top_three_only_and_permanent() -> void:
	var s := _state()
	Democracy.enter(s, true)
	for entry: Dictionary in s.candidate_pool:
		entry["chance"] = 10.0
	(s.candidate_pool[0] as Dictionary)["chance"] = 30.0
	(s.candidate_pool[1] as Dictionary)["chance"] = 25.0
	(s.candidate_pool[2] as Dictionary)["chance"] = 20.0
	var leader_id: StringName = (s.candidate_pool[0] as Dictionary)["id"]
	var outsider_id: StringName = (s.candidate_pool[5] as Dictionary)["id"]
	assert_that(Democracy.fund(s, outsider_id)["reason"]).is_equal(&"not_top_three")
	var treasury_before: int = s.treasury
	var r := Democracy.fund(s, leader_id)
	assert_bool(bool(r["ok"])).is_true()
	assert_int(s.treasury).is_equal(treasury_before - 50)
	assert_float(float((s.candidate_pool[0] as Dictionary)["chance"])).is_equal_approx(40.0, 0.01)


func test_reelection_chance_formula() -> void:
	var s := _state()
	s.happiness = 90
	assert_float(Democracy.reelection_chance(s)).is_equal_approx(0.60, 0.001)
	s.happiness = 30
	assert_float(Democracy.reelection_chance(s)).is_equal_approx(0.30, 0.001)


func test_generation_step_applies_truth_table() -> void:
	var s := _state()
	Democracy.enter(s, true)
	var culture_before: int = s.culture
	var treasury_before: int = s.treasury
	var report := Democracy.generation_step(s)
	assert_bool((report["moves"] as Dictionary).has("copy")).is_true()
	assert_bool((report["explore"] as Dictionary)["nodes"] >= 2).is_true()
	# something moved: axes and money both live
	var moved: bool = s.culture != culture_before or s.treasury != treasury_before
	assert_bool(moved).is_true()


func test_auto_explore_scales_and_caps() -> void:
	var s := _state()
	Democracy.enter(s, true)
	var r1 := Democracy._auto_explore(s)
	assert_int(int(r1["nodes"])).is_equal(2)   # generation 36, entered 36
	s.generation = 40
	assert_int(int(Democracy._auto_explore(s)["nodes"])).is_equal(4)
	s.generation = 48
	assert_int(int(Democracy._auto_explore(s)["nodes"])).is_equal(4)   # 硬上限 4


func test_term_limit_removes_incumbent() -> void:
	var s := _state()
	Democracy.enter(s, true)
	var first: StringName = s.incumbent
	for entry: Dictionary in s.candidate_pool:
		if entry["id"] == first:
			entry["terms"] = 2
	s.happiness = 100   # even a beloved incumbent is termed out
	Democracy._election_step(s)
	assert_int(s.candidate_pool.size()).is_equal(9)
	assert_that(s.incumbent).is_not_equal(first)
