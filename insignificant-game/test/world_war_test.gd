class_name WorldWarTest
extends GdUnitTestSuite
# Suite for core/world_war.gd (design/世界大戰.md 戰場模型, WW1-WW5): two camps no neutral,
# 卡池張數-sequenced interleaved 正規軍 waves on the shared-table battle engine, per-camp
# exhaustion deciding the war, real-clear 戰功, reparations with exact conservation.


func _state() -> GameState:
	var s := GameState.new_run(15)
	s.generation = 15
	Rivals.setup(s)
	Rivals.update_powers(s)
	return s


func _craft(state: GameState, card_id: StringName, acc: float, dodge: float, speed: float) -> Cards.CardInstance:
	var instance := Cards.CardInstance.new(card_id, 1)
	instance.grade = &"medium"
	instance.accuracy = acc
	instance.dodge = dodge
	instance.speed = speed
	state.deck.append(instance)
	return instance


func _grind(state: GameState, battle: Battle.BattleField) -> int:
	# Watch mode: no deployment, remnants trade blows until one camp exhausts.
	var rounds: int = 0
	while battle.outcome == &"" and rounds < 500:
		Battle.end_round(state, battle)
		rounds += 1
	return rounds


func test_camps_put_warred_rivals_opposite_no_neutral() -> void:
	var s := _state()
	Rivals.find(s, &"iron_tribe").warred_this_window = true
	var camps := WorldWar.form_camps(s)
	assert_bool((camps["enemy_camp"] as Array).has(&"iron_tribe")).is_true()
	assert_bool((camps["player_camp"] as Array).has(&"player")).is_true()
	# WW2: no neutral — every living civ (player included) lands in exactly one camp
	var total: int = (camps["player_camp"] as Array).size() + (camps["enemy_camp"] as Array).size()
	assert_int(total).is_equal(6)


func test_card_count_formula() -> void:
	assert_int(WorldWar.card_count(36.0)).is_equal(4)
	assert_int(WorldWar.card_count(40.0)).is_equal(4)
	assert_int(WorldWar.card_count(41.0)).is_equal(5)


func test_start_fields_both_camps_with_tagged_regulars() -> void:
	var s := _state()
	Rivals.find(s, &"iron_tribe").warred_this_window = true
	var battle := WorldWar.start(s)
	assert_that(battle.battle_type).is_equal(&"world_war")
	assert_int(battle.round_cap).is_equal(0)   # 無回合上限 (波數上限節流)
	assert_bool(battle.camps.has("player_camp")).is_true()
	# wave 1 of both camps arrives at round 1: allies fight beside you from the opening
	assert_bool(battle.enemy_units.size() > 0).is_true()
	assert_bool(battle.player_units.size() > 0).is_true()
	var ally: Dictionary = battle.player_units[0]
	assert_that(ally["side"]).is_equal(&"player")
	assert_bool((battle.camps["player_camp"] as Array).has(ally["faction"])).is_true()   # civ tag (WW5)
	assert_bool(bool(ally["regular"])).is_true()
	assert_bool(ally["instance"] == null).is_true()   # 正規軍 never grow — only your cards do
	var foe: Dictionary = battle.enemy_units[0]
	assert_that(foe["side"]).is_equal(&"enemy")
	assert_bool((battle.camps["enemy_camp"] as Array).has(foe["faction"])).is_true()
	# 波數上限: every civ contributes at most 2 waves
	assert_bool(battle.waves.size() <= 5 * WorldWar.WAVES_PER_CIV).is_true()


func test_watch_mode_converges_and_finish_conserves_the_pool() -> void:
	var s := _state()
	Rivals.find(s, &"iron_tribe").warred_this_window = true
	var battle := WorldWar.start(s)   # empty deck: the player camp is allies only
	var rounds := _grind(s, battle)
	assert_bool(rounds < 500).is_true()   # 必然收斂、不會卡死
	assert_bool(battle.outcome == &"win" or battle.outcome == &"loss").is_true()
	var result := WorldWar.finish(s, battle)
	var pool: int = int(result["pool"])
	assert_bool(pool > 0).is_true()
	for civ_id: StringName in (result["reparations"] as Dictionary).keys():
		assert_bool((result["winners"] as Array).has(civ_id)).is_false()   # losers pay
	var payout_sum: int = 0
	for civ_id: StringName in (result["payouts"] as Dictionary).keys():
		assert_bool((result["winners"] as Array).has(civ_id)).is_true()    # winners collect
		payout_sum += int(result["payouts"][civ_id])
	assert_int(payout_sum).is_equal(pool)   # 守恆: 發出去的正好等於池, exact
	assert_bool((result["winners"] as Array).has(result["last_hitter"])).is_true()
	assert_int(s.ww_results.size()).is_equal(1)
	for rival: Rivals.RivalState in s.rivals:
		assert_bool(rival.warred_this_window).is_false()   # window resets after the war


func test_player_alone_loses_and_pays_into_negative() -> void:
	var s := _state()
	s.treasury = 0
	s.population = 10
	s.happiness = 0
	s.deck = []
	for rival: Rivals.RivalState in s.rivals:
		rival.warred_this_window = true   # everyone opposite: the player fights alone
	var battle := WorldWar.start(s)
	_grind(s, battle)
	assert_that(battle.outcome).is_equal(&"loss")   # empty field, nothing to commit (D3)
	var result := WorldWar.finish(s, battle)
	assert_bool(bool(result["player_won"])).is_false()
	assert_bool(s.treasury < 0).is_true()   # 可扣到負 (power floor: even broke you pay)


func test_player_front_swings_and_wins_the_war() -> void:
	var s := _state()
	for rival: Rivals.RivalState in s.rivals:
		if rival.id != &"iron_tribe":
			rival.alive = false
	var iron := Rivals.find(s, &"iron_tribe")
	iron.warred_this_window = true
	iron.power = 12.0   # too weak for any era-3 unit: the guard fields one weakest regular
	_craft(s, &"cavalry", 100.0, 0.0, 1.0)
	var treasury_before: int = s.treasury
	var battle := WorldWar.start(s)
	assert_int((battle.camps["player_camp"] as Array).size()).is_equal(1)   # the player alone
	var deployed := Battle.deploy(s, battle, 0)
	assert_bool(bool(deployed["ok"])).is_true()
	var power_before_finish: float = iron.power
	_grind(s, battle)
	assert_that(battle.outcome).is_equal(&"win")   # the battle decides the war (WW1)
	var result := WorldWar.finish(s, battle)
	assert_bool(bool(result["player_won"])).is_true()
	assert_that(result["last_hitter"]).is_equal(&"player")
	var pool: int = int(result["pool"])
	assert_int(int((result["payouts"] as Dictionary)[&"player"])).is_equal(pool)   # sole winner
	assert_float(iron.power).is_equal_approx(power_before_finish * 0.9, 0.001)     # loser hit
	var deploy_cost: int = 3   # cavalry 軍費, era 1
	assert_int(s.treasury).is_equal(treasury_before - deploy_cost + pool)
	# real-clear 戰功 (WW5): one weakest era-3 regular = (攻1+血1)×係數2 = 4
	assert_int(int((result["merit"] as Dictionary)[&"player"])).is_equal(4)
