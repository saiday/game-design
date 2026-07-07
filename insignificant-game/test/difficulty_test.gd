class_name DifficultyTest
extends GdUnitTestSuite


func test_multipliers_by_level() -> void:
	var easy := GameState.new_run(1, &"easy")
	var normal := GameState.new_run(1, &"normal")
	var hard := GameState.new_run(1, &"hard")
	assert_float(Difficulty.enemy_stat_mult(easy)).is_equal_approx(0.8, 0.001)
	assert_float(Difficulty.enemy_stat_mult(normal)).is_equal_approx(1.0, 0.001)
	assert_float(Difficulty.enemy_stat_mult(hard)).is_equal_approx(1.2, 0.001)
	assert_float(Difficulty.event_penalty_mult(hard)).is_equal_approx(1.25, 0.001)
	assert_float(Difficulty.aggression_mult(easy)).is_equal_approx(0.75, 0.001)


func test_enemy_stats_scale_in_battle() -> void:
	var hard := GameState.new_run(2, &"hard")
	Cards.starting_deck(hard)
	var battle := Battle.start(hard, &"tax_battle")
	assert_int(int(battle.enemy_units[0]["attack"])).is_equal(1)   # round(1×1.2), min 1
	assert_int(int(battle.enemy_units[0]["hp"])).is_equal(2)       # round(2×1.2)
	hard.generation = 33   # coeff 8: weak 8/16 → 10/19
	var late := Battle.start(hard, &"tax_battle")
	assert_int(int(late.enemy_units[0]["attack"])).is_equal(10)
	assert_int(int(late.enemy_units[0]["hp"])).is_equal(19)


func test_penalties_scale_rewards_do_not() -> void:
	var hard := GameState.new_run(3, &"hard")
	var r := MapNodes.resolve_opportunity(hard, &"merchant", &"take_money")
	assert_int(int(r["money"])).is_equal(30)   # reward untouched
	var d := MapNodes.resolve_opportunity(hard, &"disaster", &"endure")
	assert_int(int(d["money"])).is_equal(-31)  # round(−25×1.25)


func test_rival_curves_shift() -> void:
	var normal_p := Rivals.base_power(&"iron_tribe", 15, &"normal")
	var hard_p := Rivals.base_power(&"iron_tribe", 15, &"hard")
	var easy_p := Rivals.base_power(&"iron_tribe", 15, &"easy")
	assert_bool(hard_p > normal_p * 1.1).is_true()    # p0 +10% AND g +0.02 compound
	assert_bool(easy_p < normal_p * 0.9).is_true()


func test_scale_enemy_stat_floor() -> void:
	var easy := GameState.new_run(4, &"easy")
	assert_int(Difficulty.scale_enemy_stat(easy, 1)).is_equal(1)   # never below 1
