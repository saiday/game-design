class_name HappinessTest
extends GdUnitTestSuite


func test_adjust_clamps() -> void:
	var s := GameState.new_run(1)
	s.happiness = 95
	assert_int(Happiness.adjust(s, 20)).is_equal(100)
	s.happiness = 3
	assert_int(Happiness.adjust(s, -10)).is_equal(0)


func test_thresholds() -> void:
	var s := GameState.new_run(1)
	s.happiness = 70
	assert_bool(Happiness.good_draw_bonus(s)).is_true()
	assert_bool(Happiness.low_penalty(s)).is_false()
	s.happiness = 69
	assert_bool(Happiness.good_draw_bonus(s)).is_false()
	s.happiness = 59
	assert_bool(Happiness.low_penalty(s)).is_true()


func test_state_religion_bonus_and_decay() -> void:
	var s := GameState.new_run(1)
	s.happiness = 50
	assert_int(Happiness.apply_state_religion(s)).is_equal(80)
	assert_int(Happiness.on_era_transition(s)).is_equal(-10)
	assert_int(s.happiness).is_equal(70)
	Happiness.on_era_transition(s)
	Happiness.on_era_transition(s)
	assert_int(s.happiness).is_equal(50)
	# fully decayed: no further effect
	assert_int(Happiness.on_era_transition(s)).is_equal(0)
	assert_int(s.happiness).is_equal(50)
