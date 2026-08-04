class_name SimTest
extends GdUnitTestSuite
# Full-run seeded simulations: the invariant net over everything at once, plus the bot's
# 工事卡 policy (W16), which is asserted as a decision rather than through a run outcome —
# it is a heuristic, so what is worth testing is that it reads the field the way the rules
# describe (a wall screens a 遠程列 under 遠程 fire; 同場上限 2 is a hard stop).


var _field_state: GameState


func _fort_field(seed_value: int = 3) -> Battle.BattleField:
	# A 一般地圖戰 stripped to a controlled field: no enemies, no waves, and a deck holding one
	# of each card the policy can reach for. Industrial era so 防空飛彈 has a form (ADR-0006).
	_field_state = GameState.new_run(seed_value)
	_field_state.generation = 25
	Cards.starting_deck(_field_state)
	for card_id: StringName in [&"archers", &"engineers", &"shield_wall", &"anti_air"]:
		_field_state.deck.append(Cards.CardInstance.new(card_id, 4))
	var battle := Battle.start(_field_state, &"field_battle")
	battle.enemy_units.clear()
	battle.waves.clear()
	battle.next_wave = 0
	return battle


func _put(battle: Battle.BattleField, card_id: StringName, side: StringName) -> Dictionary:
	var unit := Battle.regular_unit(_field_state, card_id, side, side, null)
	var line: Array[Dictionary] = battle.player_units if side == &"player" else battle.enemy_units
	line.append(unit)
	return unit


func _id_at(battle: Battle.BattleField, index: int) -> StringName:
	return (battle.available[index] as Cards.CardInstance).id if index >= 0 else &""


func test_full_runs_terminate() -> void:
	for seed_value: int in [1, 7, 42]:
		var result := Sim.run(seed_value)
		var state: GameState = result["state"]
		var ending: Dictionary = result["ending"]
		assert_bool(bool(ending["over"])).is_true()
		assert_bool(state.generation <= 61).is_true()
		assert_int(int(result["generations"])).is_greater(5)


func test_determinism_same_seed_same_run() -> void:
	var a := Sim.run(123)
	var b := Sim.run(123)
	var state_a: GameState = a["state"]
	var state_b: GameState = b["state"]
	assert_int(state_a.generation).is_equal(state_b.generation)
	assert_int(state_a.treasury).is_equal(state_b.treasury)
	assert_int(state_a.population).is_equal(state_b.population)
	assert_int(state_a.log.size()).is_equal(state_b.log.size())
	assert_that((a["ending"] as Dictionary)["kind"]).is_equal((b["ending"] as Dictionary)["kind"])


func test_invariants_hold_every_generation() -> void:
	var result := Sim.run(9)
	var state: GameState = result["state"]
	for snapshot: Dictionary in state.log:
		var happiness: int = int(snapshot["happiness"])
		assert_bool(happiness >= 0 and happiness <= 100).is_true()
		assert_bool(int(snapshot["population"]) >= 0).is_true()
		assert_bool(float(snapshot["unrest_weight"]) <= 0.6).is_true()
		assert_bool(int(snapshot["bp"]) >= 0).is_true()


func test_run_produces_balance_telemetry() -> void:
	var result := Sim.run(5)
	var state: GameState = result["state"]
	assert_bool(state.log.size() > 0).is_true()
	var last: Dictionary = state.log[state.log.size() - 1]
	assert_bool(last.has("buildings_built")).is_true()   # escalation knob input
	assert_bool(last.has("treasury")).is_true()
	# the run actually engaged the systems: something got built, money moved
	assert_bool(int(last["buildings_built"]) > 0).is_true()


func test_hard_and_easy_both_complete() -> void:
	for difficulty: StringName in [&"easy", &"hard"]:
		var result := Sim.run(11, difficulty)
		assert_bool(bool((result["ending"] as Dictionary)["over"])).is_true()


# --- 工事卡 policy (W16) ---

func test_wall_wanted_only_with_a_ranged_row_under_ranged_fire() -> void:
	# 盾陣 screens the 遠程列 from 遠程 fire and nothing else (ADR-0008/0010), so both halves of
	# that sentence have to be on the field before it is worth 3 軍費.
	var melee_only := _fort_field()
	_put(melee_only, &"infantry", &"player")
	_put(melee_only, &"archers", &"enemy")
	assert_int(Sim.fort_pick(melee_only)).is_equal(-1)   # nothing of ours stands in the 遠程列

	var no_shooters := _fort_field()
	_put(no_shooters, &"archers", &"player")
	_put(no_shooters, &"infantry", &"enemy")
	assert_int(Sim.fort_pick(no_shooters)).is_equal(-1)  # 近戰 walks around a wall

	var both := _fort_field()
	_put(both, &"archers", &"player")
	_put(both, &"archers", &"enemy")
	assert_that(_id_at(both, Sim.fort_pick(both))).is_equal(&"shield_wall")


func test_battery_answers_air_before_the_wall_answers_arrows() -> void:
	# 空域 is the one threat the cheapest-unit tempo policy cannot answer by accident
	# (balance-report.md W14.5), so the battery outranks the wall when both are wanted.
	var battle := _fort_field()
	_put(battle, &"archers", &"player")
	_put(battle, &"archers", &"enemy")
	_put(battle, &"bomber", &"enemy")
	assert_that(_id_at(battle, Sim.fort_pick(battle))).is_equal(&"anti_air")


func test_fort_limit_two_is_a_hard_stop() -> void:
	# 同場上限 2 counts every fort fielded this battle, disabled ones included: forts are never
	# removed, so a slot spent is gone for the rest of the battle (ADR-0007).
	var battle := _fort_field()
	_put(battle, &"archers", &"player")
	_put(battle, &"archers", &"enemy")
	_put(battle, &"bomber", &"enemy")
	assert_bool(bool(Battle.deploy(_field_state, battle, Sim.fort_pick(battle))["ok"])).is_true()
	assert_bool(bool(Battle.deploy(_field_state, battle, Sim.fort_pick(battle))["ok"])).is_true()
	assert_int(battle.player_forts.size()).is_equal(Battle.FORT_LIMIT)
	assert_int(Sim.fort_pick(battle)).is_equal(-1)


func test_disabled_wall_is_repaired_not_replaced() -> void:
	# A wreck is a slot already paid for. While anything can stand it back up — an engineer on
	# the field or one still in the deck — the bot does not spend its other slot on a second wall.
	var battle := _fort_field()
	_put(battle, &"archers", &"player")
	_put(battle, &"archers", &"enemy")
	assert_bool(bool(Battle.deploy(_field_state, battle, Sim.fort_pick(battle))["ok"])).is_true()
	battle.player_forts[0]["disabled"] = true
	assert_int(Sim.fort_pick(battle)).is_equal(-1)             # the engineer card can fix it
	var engineer: int = Sim.engineer_pick(battle)
	assert_that(_id_at(battle, engineer)).is_equal(&"engineers")
	assert_bool(bool(Battle.deploy(_field_state, battle, engineer)["ok"])).is_true()
	assert_int(Sim.engineer_pick(battle)).is_equal(-1)         # one on the field is enough
	assert_int(Sim.fort_pick(battle)).is_equal(-1)


func test_second_wall_only_when_nothing_can_repair_the_first() -> void:
	var battle := _fort_field()
	_field_state.deck.append(Cards.CardInstance.new(&"shield_wall", 4))
	battle.available.append(_field_state.deck[_field_state.deck.size() - 1])
	_put(battle, &"archers", &"player")
	_put(battle, &"archers", &"enemy")
	assert_bool(bool(Battle.deploy(_field_state, battle, Sim.fort_pick(battle))["ok"])).is_true()
	battle.player_forts[0]["disabled"] = true
	for i: int in range(battle.available.size()):   # strip the engineer out of the deck
		if (battle.available[i] as Cards.CardInstance).id == &"engineers":
			battle.available.remove_at(i)
			break
	assert_that(_id_at(battle, Sim.fort_pick(battle))).is_equal(&"shield_wall")


func test_engineer_follows_a_fort_and_only_a_fort() -> void:
	# 工兵團 is the only thing in the game that restores a 工事卡 (ADR-0007); without a fort of
	# its own on the field the bot has no reason to pay for a unit that never attacks.
	var battle := _fort_field()
	_put(battle, &"archers", &"player")
	_put(battle, &"archers", &"enemy")
	assert_int(Sim.engineer_pick(battle)).is_equal(-1)
	assert_bool(bool(Battle.deploy(_field_state, battle, Sim.fort_pick(battle))["ok"])).is_true()
	assert_that(_id_at(battle, Sim.engineer_pick(battle))).is_equal(&"engineers")


func test_runs_report_fort_telemetry() -> void:
	# The counters the balance batch reads exist and stay coherent across a full run: the bot
	# cannot absorb shots with walls it never fielded, nor repair forts it does not own.
	var result := Sim.run(5)
	var telemetry: Dictionary = result["telemetry"]
	for key: String in Sim.new_telemetry().keys():
		assert_bool(telemetry.has(key)).is_true()
	assert_int(int(telemetry["battles"])).is_greater(0)
	for opportunity: String in ["battles_wall_held", "battles_battery_held", "battles_air_faced"]:
		assert_int(int(telemetry[opportunity])).is_less_equal(int(telemetry["battles"]))
	assert_int(int(telemetry["walls_fielded"])).is_less_equal(int(telemetry["battles_wall_held"]))
	assert_int(int(telemetry["batteries_fielded"])).is_less_equal(int(telemetry["battles_battery_held"]))
	var forts: int = int(telemetry["walls_fielded"]) + int(telemetry["batteries_fielded"])
	if forts == 0:
		assert_int(int(telemetry["wall_shots_absorbed"])).is_equal(0)
		assert_int(int(telemetry["fort_repairs"])).is_equal(0)
	else:
		assert_int(int(telemetry["fort_spend"])).is_greater(0)
