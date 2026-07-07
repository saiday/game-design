class_name WorldWarTest
extends GdUnitTestSuite


func _state() -> GameState:
	var s := GameState.new_run(15)
	s.generation = 15
	Rivals.setup(s)
	Rivals.update_powers(s)
	return s


func test_camps_put_warred_rivals_opposite() -> void:
	var s := _state()
	Rivals.find(s, &"iron_tribe").warred_this_window = true
	var camps := WorldWar.form_camps(s)
	assert_bool((camps["enemy_camp"] as Array).has(&"iron_tribe")).is_true()
	assert_bool((camps["player_camp"] as Array).has(&"player")).is_true()
	# every living civ lands in exactly one camp
	var total: int = (camps["player_camp"] as Array).size() + (camps["enemy_camp"] as Array).size()
	assert_int(total).is_equal(6)


func test_card_count_formula() -> void:
	assert_int(WorldWar.card_count(36.0)).is_equal(4)
	assert_int(WorldWar.card_count(40.0)).is_equal(4)
	assert_int(WorldWar.card_count(41.0)).is_equal(5)


func test_run_reparations_and_conservation() -> void:
	var s := _state()
	var treasury_before: int = s.treasury
	var result := WorldWar.run(s)
	var pool: int = int(result["pool"])
	assert_bool(pool > 0).is_true()
	# money conservation: every payout is backed by a loser's (possibly negative) ledger
	var payout_sum: int = 0
	for civ_id: StringName in (result["payouts"] as Dictionary).keys():
		payout_sum += int(result["payouts"][civ_id])
	assert_bool(payout_sum <= pool).is_true()
	# player is always on one ledger side
	if bool(result["player_won"]):
		assert_bool(s.treasury >= treasury_before).is_true()
	else:
		assert_bool(s.treasury < treasury_before).is_true()


func test_player_loss_charges_into_negative() -> void:
	var s := _state()
	s.treasury = 0
	s.population = 10   # tiny power: the player camp loses, but power×2 still bills 20
	s.happiness = 0
	s.deck = []
	# make every rival hostile so the player fights alone
	for rival: Rivals.RivalState in s.rivals:
		rival.warred_this_window = true
	var result := WorldWar.run(s)
	assert_bool(bool(result["player_won"])).is_false()
	assert_bool(s.treasury < 0).is_true()   # 可扣到負 (power floor: even broke you pay)


func test_ai_loser_power_drops() -> void:
	var s := _state()
	s.population = 10000   # player camp overwhelming
	Rivals.find(s, &"iron_tribe").warred_this_window = true
	var before: float = Rivals.find(s, &"iron_tribe").power
	WorldWar.run(s)
	assert_float(Rivals.find(s, &"iron_tribe").power).is_equal_approx(before * 0.9, 0.5)


func test_window_resets_after_ww() -> void:
	var s := _state()
	Rivals.find(s, &"vast_state").warred_this_window = true
	WorldWar.run(s)
	for rival: Rivals.RivalState in s.rivals:
		assert_bool(rival.warred_this_window).is_false()


func test_neutral_requires_zero_conflict() -> void:
	var s := _state()
	var result := WorldWar.run(s, true)   # no wars — neutrality allowed
	assert_bool(bool(result["player_neutral"])).is_true()
	assert_bool((result["player_camp"] as Array).has(&"player")).is_false()
	var s2 := _state()
	Rivals.find(s2, &"iron_tribe").warred_this_window = true
	var result2 := WorldWar.run(s2, true)   # conflicted — forced to a camp
	assert_bool(bool(result2["player_neutral"])).is_false()
