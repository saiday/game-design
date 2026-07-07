class_name RivalsTest
extends GdUnitTestSuite


func _state() -> GameState:
	var s := GameState.new_run(11)
	Rivals.setup(s)
	return s


func test_setup_five_named_rivals() -> void:
	var s := _state()
	assert_int(s.rivals.size()).is_equal(5)
	for rival: Rivals.RivalState in s.rivals:
		assert_bool(rival.alive).is_true()
		assert_bool(rival.display_name.length() > 0).is_true()
		assert_float(rival.player_influence).is_equal_approx(5.0, 0.01)   # 首次接觸
		assert_bool((RivalData.CLASSES[rival.id]["names"] as Array).has(rival.display_name)).is_true()


func test_setup_deterministic_names() -> void:
	var a := _state()
	var b := _state()
	for i: int in range(5):
		assert_that((a.rivals[i] as Rivals.RivalState).display_name).is_equal((b.rivals[i] as Rivals.RivalState).display_name)


func test_power_curve_anchors() -> void:
	# Design anchors: 15 代目標 P — science 36, culture 28, iron 38, vast 39, slow 16.
	assert_int(int(round(Rivals.base_power(&"science_state", 15, &"normal")))).is_equal(36)
	assert_int(int(round(Rivals.base_power(&"culture_state", 15, &"normal")))).is_equal(28)
	assert_int(int(round(Rivals.base_power(&"iron_tribe", 15, &"normal")))).is_equal(38)
	assert_int(int(round(Rivals.base_power(&"vast_state", 15, &"normal")))).is_equal(39)
	var slow := Rivals.base_power(&"slow_burner", 15, &"normal")
	assert_bool(slow >= 16.0 and slow < 17.0).is_true()   # design target "16" (8×1.05^15 ≈ 16.6)


func test_slow_burner_late_burst() -> void:
	# 35 代目標 P ≈ 230 (1.05 until 25, then 1.11).
	var p35 := Rivals.base_power(&"slow_burner", 35, &"normal")
	assert_bool(p35 > 200.0 and p35 < 260.0).is_true()


func test_difficulty_shifts_curve() -> void:
	assert_bool(Rivals.base_power(&"iron_tribe", 15, &"hard") > Rivals.base_power(&"iron_tribe", 15, &"normal")).is_true()
	assert_bool(Rivals.base_power(&"iron_tribe", 15, &"easy") < Rivals.base_power(&"iron_tribe", 15, &"normal")).is_true()


func test_player_power_formula() -> void:
	var s := GameState.new_run(3)
	s.population = 20
	s.culture = 10
	s.happiness = 70
	s.tech = 5
	s.buildings[&"housing"] = 2
	s.buildings[&"school"] = 1
	s.deck.append(Cards.CardInstance.new(&"infantry", 4))   # (1+2)×5 = 15 strength
	assert_int(Rivals.player_power(s)).is_equal(20 + 10 + 7 + 5 + 3 + 1)


func test_declare_war_costs_bp_only() -> void:
	var s := _state()
	s.bp = 2
	s.treasury = 30
	var r := Rivals.declare_war(s, &"iron_tribe")
	assert_bool(bool(r["ok"])).is_true()
	assert_int(s.bp).is_equal(1)
	assert_int(s.treasury).is_equal(30)
	assert_that(s.pending_war_target).is_equal(&"iron_tribe")
	assert_that(Rivals.declare_war(s, &"vast_state")["reason"]).is_equal(&"war_already_pending")


func test_psyops_conditions_and_shared_cap() -> void:
	var s := _state()
	s.bp = 3
	Rivals.update_powers(s)
	var rival := Rivals.find(s, &"iron_tribe")
	s.culture = 0
	assert_that(Rivals.psyops(s, &"iron_tribe")["reason"]).is_equal(&"culture_too_low")
	s.culture = 1000
	var first := Rivals.psyops(s, &"iron_tribe")
	assert_bool(bool(first["ok"])).is_true()
	assert_float(rival.psyops_discount).is_equal_approx(0.10, 0.001)
	assert_float(Rivals.attack_multiplier(rival)).is_equal_approx(0.90, 0.001)
	# shared cap: no second use this generation, on ANY rival
	assert_that(Rivals.psyops(s, &"vast_state")["reason"]).is_equal(&"used_this_generation")


func test_psyops_discount_caps_at_30() -> void:
	var s := _state()
	s.culture = 10000
	var rival := Rivals.find(s, &"vast_state")
	for i: int in range(5):
		s.psyops_used_this_gen = false
		s.bp = 2
		Rivals.psyops(s, &"vast_state")
	assert_float(Rivals.attack_multiplier(rival)).is_equal_approx(0.70, 0.001)


func test_record_civil_war_influence_and_penalty() -> void:
	var s := _state()
	s.generation = 15
	Rivals.update_powers(s)
	var rival := Rivals.find(s, &"vast_state")
	var before := rival.power
	Rivals.record_civil_war(s, &"vast_state", true)
	assert_int(rival.defeats).is_equal(1)
	assert_float(rival.power).is_equal_approx(before * 0.9, 0.01)
	assert_float(rival.player_influence).is_equal_approx(20.0, 0.01)   # 5 首遇 + 15 戰爭
	assert_bool(rival.warred_this_window).is_true()


func test_two_defeats_exit_with_inheritance() -> void:
	var s := _state()
	s.generation = 15
	s.population = 100   # keep player power high so no annex threshold hit… power big
	Rivals.update_powers(s)
	var rival := Rivals.find(s, &"iron_tribe")
	rival.power = 200.0   # well above annex threshold vs any player power here
	rival.rival_influence[&"vast_state"] = 50.0   # vast_state out-influences the player
	Rivals.record_civil_war(s, &"iron_tribe", true)
	assert_bool(rival.alive).is_true()
	rival.power = 200.0
	var second := Rivals.record_civil_war(s, &"iron_tribe", true)
	assert_bool(rival.alive).is_false()
	assert_bool(bool(second["exited"])).is_true()
	assert_that((second["inheritance"] as Dictionary)["heir"]).is_equal(&"vast_state")
	var heir := Rivals.find(s, &"vast_state")
	assert_float(heir.power_bonus).is_equal_approx(90.0, 0.5)   # (200×0.9 defeat penalty)×0.5


func test_annex_when_below_threshold() -> void:
	var s := _state()
	s.population = 200   # player power >> rival
	var rival := Rivals.find(s, &"culture_state")
	rival.power = 10.0
	var r := Rivals.record_civil_war(s, &"culture_state", true)
	assert_bool(bool(r["annexed"])).is_true()
	assert_bool(rival.alive).is_false()
	assert_int(int(s.flags[&"annexed_count"])).is_equal(1)


func test_catchup_floor_at_ww_minus_one() -> void:
	var s := _state()
	s.generation = 14
	s.population = 500   # player power ~500+, rivals ~30 — floor triggers, bounded +25%
	var strongest_before: float = 0.0
	for rival: Rivals.RivalState in s.rivals:
		strongest_before = maxf(strongest_before, Rivals.base_power(rival.id, 14, &"normal"))
	Rivals.update_powers(s)
	var strongest_after: float = 0.0
	for rival: Rivals.RivalState in s.rivals:
		strongest_after = maxf(strongest_after, rival.power)
	assert_float(strongest_after).is_equal_approx(strongest_before * 1.25, 0.5)


func test_hegemony_influence_accrues() -> void:
	var s := _state()
	s.population = 500   # player is #1
	var rival := Rivals.find(s, &"iron_tribe")
	var before := rival.player_influence
	Rivals.update_powers(s)
	assert_float(rival.player_influence).is_equal_approx(before + 1.0, 0.01)


func test_only_player_remains() -> void:
	var s := _state()
	assert_bool(Rivals.only_player_remains(s)).is_false()
	for rival: Rivals.RivalState in s.rivals:
		rival.alive = false
	assert_bool(Rivals.only_player_remains(s)).is_true()
