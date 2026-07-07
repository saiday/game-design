class_name EndingTest
extends GdUnitTestSuite


func _state() -> GameState:
	var s := GameState.new_run(50)
	Rivals.setup(s)
	return s


func test_ongoing_run() -> void:
	var s := _state()
	assert_bool(bool(Ending.check(s)["over"])).is_false()


func test_collapse_is_the_only_loss() -> void:
	var s := _state()
	s.population = 4
	var r := Ending.check(s)
	assert_bool(bool(r["over"])).is_true()
	assert_that(r["kind"]).is_equal(&"collapse")
	assert_bool(bool(r["victory"])).is_false()


func test_total_victory_immediate() -> void:
	var s := _state()
	for rival: Rivals.RivalState in s.rivals:
		rival.alive = false
	var r := Ending.check(s)
	assert_that(r["kind"]).is_equal(&"total_victory")
	assert_bool(bool(r["victory"])).is_true()
	assert_bool((r["epilogue"] as String).contains("微不足道")).is_true()


func test_survived_rank_and_epilogue() -> void:
	var s := _state()
	s.generation = 51   # past the final generation
	s.population = 10   # weak: everyone outranks you
	s.happiness = 0
	s.deck = []
	for rival: Rivals.RivalState in s.rivals:
		rival.power = 1000.0
	var r := Ending.check(s)
	assert_that(r["kind"]).is_equal(&"survived")
	assert_bool(bool(r["victory"])).is_true()   # any rank is a win
	assert_int(int(r["rank"])).is_equal(6)
	assert_bool((r["epilogue"] as String).contains("活下來就夠了")).is_true()


func test_rank_shrinks_with_dead_rivals() -> void:
	var s := _state()
	s.population = 10
	for rival: Rivals.RivalState in s.rivals:
		rival.power = 1000.0
	(s.rivals[0] as Rivals.RivalState).alive = false
	(s.rivals[1] as Rivals.RivalState).alive = false
	assert_int(Ending.rank(s)).is_equal(4)


func test_danger_panel_fields() -> void:
	var s := _state()
	s.treasury = -120
	var panel := Ending.danger_panel(s)
	assert_int(int(panel["debt"])).is_equal(120)
	assert_int(int(panel["interest_per_gen"])).is_equal(12)
	assert_int(int(panel["collapse_threshold"])).is_equal(5)
	assert_bool(float(panel["unrest_weight"]) >= 0.15).is_true()
