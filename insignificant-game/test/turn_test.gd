class_name TurnTest
extends GdUnitTestSuite


func _state() -> GameState:
	var s := GameState.new_run(44)
	Rivals.setup(s)
	Cards.starting_deck(s)
	return s


func test_begin_generation_grants_bp_and_resets() -> void:
	var s := _state()
	s.psyops_used_this_gen = true
	s.unrest_battles_this_gen = 1
	s.policy_bp_this_gen = 2
	var r := Turn.begin_generation(s)
	assert_int(int(r["bp"])).is_equal(1)
	assert_bool(s.psyops_used_this_gen).is_false()
	assert_int(s.unrest_battles_this_gen).is_equal(0)
	assert_int(s.policy_bp_this_gen).is_equal(0)


func test_era_transition_evolves_cards() -> void:
	var s := _state()
	s.flags[&"era_seen"] = 1
	s.generation = 9   # classical
	var r := Turn.begin_generation(s)
	assert_bool(bool(r["era_transition"])).is_true()
	assert_int((s.deck[0] as Cards.CardInstance).tier).is_equal(2)
	# same era next generation: no transition
	s.generation = 10
	assert_bool(Turn.begin_generation(s).has("era_transition")).is_false()


func test_world_war_generation_overrides() -> void:
	var s := _state()
	s.generation = 15
	var r := Turn.begin_generation(s)
	assert_bool(bool(r["world_war"])).is_true()
	assert_bool(r.has("bp")).is_false()   # 無營運


func test_route_injects_declared_war() -> void:
	var s := _state()
	s.pending_war_target = &"iron_tribe"
	var nodes := Turn.route(s)
	var found := false
	for node: Dictionary in nodes:
		if node["battle_type"] == &"civil_war" and node["rival_id"] == &"iron_tribe":
			found = bool(node["player_declared"])
	assert_bool(found).is_true()
	assert_that(s.pending_war_target).is_equal(&"")


func test_settle_logs_and_advances_clock() -> void:
	var s := _state()
	var r := Turn.settle(s)
	assert_int(s.log.size()).is_equal(1)
	assert_int(s.generation).is_equal(2)
	assert_bool(bool((r["ending"] as Dictionary)["over"])).is_false()
	var snapshot: Dictionary = s.log[0]
	assert_bool(snapshot.has("player_power")).is_true()
	assert_bool(snapshot.has("unrest_weight")).is_true()
	assert_bool((snapshot["danger"] as Dictionary).has("collapse_threshold")).is_true()


func test_settle_enters_forced_democracy() -> void:
	var s := _state()
	s.flags[&"forced_democracy"] = true
	Turn.settle(s)
	assert_bool(s.is_democracy).is_true()
	assert_bool(s.legacies.has(&"democratic_spirit")).is_false()   # forced ≠ voluntary
