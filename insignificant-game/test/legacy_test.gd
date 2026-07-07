class_name LegacyTest
extends GdUnitTestSuite


func _state() -> GameState:
	var s := GameState.new_run(88)
	Rivals.setup(s)
	return s


func test_culture_lead_grants_critical_then_rock() -> void:
	var s := _state()
	s.culture = 1000   # leads everyone
	var first := Legacy.check_triggers(s)
	assert_bool(first.has(&"critical_spirit")).is_true()
	assert_bool(s.legacies.has(&"rock_spirit")).is_false()   # needs a SECOND era window
	Legacy.check_triggers(s)   # same era again — no double count
	assert_bool(s.legacies.has(&"rock_spirit")).is_false()
	s.generation = 9   # classical: second era window
	var second := Legacy.check_triggers(s)
	assert_bool(second.has(&"rock_spirit")).is_true()


func test_no_culture_lead_no_grant() -> void:
	var s := _state()
	s.culture = 0
	Legacy.check_triggers(s)
	assert_bool(s.legacies.has(&"critical_spirit")).is_false()


func test_melting_pot_after_ten_generations() -> void:
	var s := _state()
	s.flags[&"first_annex_gen"] = 5
	s.generation = 14
	Legacy.check_triggers(s)
	assert_bool(s.legacies.has(&"melting_pot")).is_false()
	s.generation = 15
	var granted := Legacy.check_triggers(s)
	assert_bool(granted.has(&"melting_pot")).is_true()


func test_apply_passives_sums_bonuses() -> void:
	var s := _state()
	s.legacies.append(&"rational_spirit")   # tech+2 culture+1
	s.legacies.append(&"rock_spirit")       # pop+1 happiness+1
	s.legacies.append(&"martial_law")       # active-type: no passive
	s.happiness = 50
	var totals := Legacy.apply_passives(s)
	assert_int(int(totals["tech"])).is_equal(2)
	assert_int(s.tech).is_equal(2)
	assert_int(s.culture).is_equal(1)
	assert_int(s.population).is_equal(13)
	assert_int(s.happiness).is_equal(51)


func test_rock_spirit_unlocks_love_and_peace() -> void:
	var s := _state()
	s.tech = 100
	assert_that(Cards.can_unlock(s, &"love_and_peace")["reason"]).is_equal(&"source_missing")
	s.legacies.append(&"rock_spirit")
	assert_bool(bool(Cards.can_unlock(s, &"love_and_peace")["ok"])).is_true()
