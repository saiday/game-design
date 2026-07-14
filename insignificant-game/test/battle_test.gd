class_name BattleTest
extends GdUnitTestSuite


func _state() -> GameState:
	var s := GameState.new_run(55)
	Cards.starting_deck(s)
	return s


func _unit(attack: int, hp: int, row: StringName = &"melee", flags: Array = []) -> Dictionary:
	return {"card_id": &"test", "attack": attack, "hp": hp, "row": row, "flags": flags, "leader": false}


func test_start_enemy_composition_and_reward() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")
	assert_int(b.enemy_units.size()).is_equal(2)
	assert_int(int(b.enemy_units[0]["attack"])).is_equal(1)
	assert_int(int(b.enemy_units[0]["hp"])).is_equal(2)
	assert_int(b.expected_reward).is_equal(15)
	s.generation = 17   # coeff 3
	var h := Battle.start(s, &"hidden_battle")
	assert_int(h.enemy_units.size()).is_equal(2)
	assert_int(int(h.enemy_units[0]["attack"])).is_equal(9)   # hard 3×3
	assert_bool((h.enemy_units[0]["flags"] as Array).has(&"siege")).is_true()
	assert_int(h.expected_reward).is_equal(135)


func test_opening_hand_size_and_bonuses() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")
	assert_int(b.hand.size()).is_equal(4)
	var s2 := _state()
	s2.regions.append(&"military")
	assert_int(Battle.start(s2, &"tax_battle").hand.size()).is_equal(5)
	var s3 := _state()
	s3.flags[&"enemy_psyops_next_battle"] = true
	assert_int(Battle.start(s3, &"tax_battle").hand.size()).is_equal(3)
	assert_bool(s3.flags.has(&"enemy_psyops_next_battle")).is_false()


func test_play_card_pays_military_cost() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")
	var r := Battle.play_card(s, b, 0)   # infantry, cost 2
	assert_bool(bool(r["ok"])).is_true()
	assert_int(s.treasury).is_equal(28)
	assert_int(b.spent).is_equal(2)
	assert_int(b.player_units.size()).is_equal(1)


func test_win_tax_battle_and_reward() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")
	b.player_units.append(_unit(5, 20))
	Battle.end_round(s, b)   # kills first weak, takes 2 damage
	Battle.end_round(s, b)
	assert_that(b.outcome).is_equal(&"win")
	assert_int(b.merit).is_equal(6)   # 2×(1+2)
	var f := Battle.finish(s, b)
	assert_int(int(f["reward"])).is_equal(15)
	assert_int(s.treasury).is_equal(45)


func test_simultaneous_strikes() -> void:
	var s := _state()
	var b := Battle.start(s, &"riot")   # medium×2 (2/4 each)
	b.player_units.append(_unit(2, 2))
	Battle.end_round(s, b)
	# we dealt 2 to first medium (hp 2 left); both mediums dealt 4 total, we die
	assert_int(b.player_units.size()).is_equal(0)
	assert_int(b.enemy_units.size()).is_equal(2)
	assert_that(b.outcome).is_equal(&"loss")


func test_trench_blocks_melee_until_filled() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")
	b.enemy_forts.append({"card_id": &"trench", "flags": [&"blocks_melee_contact"], "filled": false})
	b.player_units.append(_unit(10, 50))
	Battle.end_round(s, b)
	assert_int(b.enemy_units.size()).is_equal(2)   # melee never connected
	Battle._fill_one_trench(b.enemy_forts)
	Battle.end_round(s, b)
	assert_int(b.enemy_units.size()).is_equal(1)


func test_tank_crosses_trench() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")
	b.enemy_forts.append({"card_id": &"trench", "flags": [&"blocks_melee_contact"], "filled": false})
	b.player_units.append(_unit(10, 50, &"melee", [&"crosses_trench"]))
	Battle.end_round(s, b)
	assert_int(b.enemy_units.size()).is_equal(1)


func test_engineer_fills_trench_on_entry() -> void:
	var s := _state()
	s.deck = []
	s.deck.append(Cards.CardInstance.new(&"engineers", 1))
	var b := Battle.start(s, &"tax_battle")
	b.enemy_forts.append({"card_id": &"trench", "flags": [&"blocks_melee_contact"], "filled": false})
	Battle.play_card(s, b, 0)
	assert_bool(bool(b.enemy_forts[0]["filled"])).is_true()


func test_shield_absorbs_one_melee_hit() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")   # 2 weak melee enemies
	b.player_forts.append({"card_id": &"shield_wall", "flags": [&"blocks_melee_once"], "filled": false})
	b.player_units.append(_unit(0, 3, &"melee", [&"no_attack"]))
	Battle.end_round(s, b)
	# first enemy hit absorbed (shield consumed), second hit lands (1 damage)
	assert_int(b.player_forts.size()).is_equal(0)
	assert_int(int(b.player_units[0]["hp"])).is_equal(2)


func test_anti_air_absorbs_ranged() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")
	b.enemy_units = [{"grade": &"weak", "attack": 5, "hp": 2, "row": &"ranged", "flags": [], "leader": false}]
	b.player_forts.append({"card_id": &"anti_air", "flags": [&"blocks_ranged_once"], "filled": false})
	b.player_units.append(_unit(0, 3, &"melee", [&"no_attack"]))
	Battle.end_round(s, b)
	assert_int(b.player_forts.size()).is_equal(0)
	assert_int(int(b.player_units[0]["hp"])).is_equal(3)


func test_siege_demolishes_fort_first() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")
	b.enemy_units = [{"grade": &"hard", "attack": 3, "hp": 6, "row": &"melee", "flags": [&"siege"], "leader": false}]
	b.player_forts.append({"card_id": &"shield_wall", "flags": [&"blocks_melee_once"], "filled": false})
	b.player_units.append(_unit(0, 10, &"melee", [&"no_attack"]))
	Battle.end_round(s, b)
	assert_int(b.player_forts.size()).is_equal(0)          # demolished, not consumed-by-absorb
	assert_int(int(b.player_units[0]["hp"])).is_equal(10)  # attack spent on the fort


func test_air_only_cannot_win() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")
	b.player_units.append(_unit(50, 50, &"air", [&"air_strike", &"non_land"]))
	Battle.end_round(s, b)
	assert_int(b.enemy_units.size()).is_equal(1)
	Battle.end_round(s, b)
	assert_int(b.enemy_units.size()).is_equal(0)
	assert_that(b.outcome).is_not_equal(&"win")   # 只剩空中單位不算拿下戰場


func test_round_cap_timeout_is_loss() -> void:
	var s := _state()
	var b := Battle.start(s, &"tax_battle")   # cap 6
	b.player_units.append(_unit(0, 100, &"melee", [&"no_attack"]))
	for i: int in range(6):
		Battle.end_round(s, b)
	assert_that(b.outcome).is_equal(&"loss")


func test_retreat_cost_and_population() -> void:
	var s := _state()
	s.generation = 9   # coeff 2
	var b := Battle.start(s, &"field_battle")
	Battle.retreat(s, b)
	assert_that(b.outcome).is_equal(&"retreat")
	assert_int(s.treasury).is_equal(10)    # 30 − 20
	assert_int(s.population).is_equal(14)


func test_defection_gate() -> void:
	var s := _state()
	s.generation = 9   # era 2: gate 16
	s.culture = 15
	var b := Battle.start(s, &"field_battle")
	assert_bool(Battle.can_defect(s, b)).is_false()
	s.culture = 16
	assert_bool(Battle.can_defect(s, b)).is_true()
	s.policies.append(&"cultural_export")   # gate 10
	s.culture = 10
	assert_bool(Battle.can_defect(s, b)).is_true()
	Battle.defect(s, b)
	var f := Battle.finish(s, b)
	assert_int(int(f["reward"])).is_equal(50)   # full reward, zero spend
	assert_int(b.spent).is_equal(0)


func test_civil_war_enemy_budget_and_psyops_discount() -> void:
	var s := _state()
	Rivals.setup(s)
	var rival := Rivals.find(s, &"iron_tribe")
	rival.power = 40.0                       # budget 20, coeff 1: 2× hard (9 each)
	rival.psyops_discount = 0.30
	var b := Battle.start(s, &"civil_war", &"iron_tribe")
	assert_int(b.enemy_units.size()).is_equal(2)
	assert_int(int(b.enemy_units[0]["attack"])).is_equal(2)   # round(3×0.7)
	assert_int(b.expected_reward).is_equal(80)                # power×2


func test_civil_war_finish_win_and_loss() -> void:
	var s := _state()
	Rivals.setup(s)
	var rival := Rivals.find(s, &"vast_state")
	rival.power = 100.0
	var b := Battle.start(s, &"civil_war", &"vast_state")
	b.outcome = &"win"
	var f := Battle.finish(s, b)
	assert_int(int(f["reward"])).is_equal(200)
	assert_int(rival.defeats).is_equal(1)
	var rival2 := Rivals.find(s, &"science_state")
	rival2.power = 100.0
	var b2 := Battle.start(s, &"civil_war", &"science_state")
	b2.outcome = &"loss"
	Battle.finish(s, b2)
	assert_float(rival2.power).is_equal_approx(105.0, 0.01)   # 判輸: 對手 power +5%
	assert_int(rival2.defeats).is_equal(0)


func test_holy_war_reparations_bonus() -> void:
	var s := _state()
	Rivals.setup(s)
	s.policies.append(&"holy_war")
	var rival := Rivals.find(s, &"iron_tribe")
	rival.power = 100.0
	var declared := Battle.start(s, &"civil_war", &"iron_tribe", true)
	assert_int(declared.expected_reward).is_equal(300)   # 200 × 1.5
	var defended := Battle.start(s, &"civil_war", &"iron_tribe", false)
	assert_int(defended.expected_reward).is_equal(200)   # only wars YOU declared


func test_riot_loss_consequences() -> void:
	var s := _state()
	s.population = 20
	s.regions.append(&"livelihood")
	var b := Battle.start(s, &"riot")
	b.outcome = &"loss"
	var f := Battle.finish(s, b)
	assert_bool(f.has("riot_loss")).is_true()
	assert_int(s.population).is_equal(16)
	assert_int(s.regions.size()).is_equal(0)


func test_riot_mechanical_suppression_costs_happiness_once() -> void:
	var s := _state()
	s.deck = []
	s.deck.append(Cards.CardInstance.new(&"elite_forces", 1))
	s.deck.append(Cards.CardInstance.new(&"artillery", 1))
	var b := Battle.start(s, &"riot")
	Battle.play_card(s, b, 0)
	Battle.play_card(s, b, 0)   # second mechanical card: still one charge per battle
	b.outcome = &"win"
	var f := Battle.finish(s, b)
	assert_int(int(f["suppression_happiness"])).is_equal(-15)
	assert_int(s.happiness).is_equal(55)   # 70 − 15, 勝敗皆然


func test_riot_mechanical_suppression_applies_on_loss_too() -> void:
	var s := _state()
	s.population = 20
	s.deck = []
	s.deck.append(Cards.CardInstance.new(&"elite_forces", 1))
	var b := Battle.start(s, &"riot")
	Battle.play_card(s, b, 0)
	b.outcome = &"loss"
	var f := Battle.finish(s, b)
	assert_int(int(f["suppression_happiness"])).is_equal(-15)
	assert_int(s.happiness).is_equal(55)
	assert_bool(f.has("riot_loss")).is_true()   # loss consequences stack on top


func test_riot_personnel_only_keeps_happiness() -> void:
	var s := _state()
	var b := Battle.start(s, &"riot")
	Battle.play_card(s, b, 0)   # starting deck is all infantry (personnel)
	b.outcome = &"win"
	var f := Battle.finish(s, b)
	assert_bool(f.has("suppression_happiness")).is_false()
	assert_int(s.happiness).is_equal(70)


func test_mechanical_outside_riot_has_no_suppression_cost() -> void:
	var s := _state()
	s.deck = []
	s.deck.append(Cards.CardInstance.new(&"artillery", 1))
	var b := Battle.start(s, &"field_battle")
	Battle.play_card(s, b, 0)
	b.outcome = &"win"
	var f := Battle.finish(s, b)
	assert_bool(f.has("suppression_happiness")).is_false()
	assert_int(s.happiness).is_equal(70)


func test_democracy_blood_loss_forces_democracy() -> void:
	var s := _state()
	var b := Battle.start(s, &"democracy_blood")
	b.outcome = &"loss"
	Battle.finish(s, b)
	assert_bool(bool(s.flags[&"forced_democracy"])).is_true()


func test_reward_card_excludes_restricted() -> void:
	var s := _state()
	var b := Battle.start(s, &"field_battle")
	b.player_units.append(_unit(50, 100))
	while b.outcome == &"":
		Battle.end_round(s, b)
	assert_that(b.outcome).is_equal(&"win")
	var f := Battle.finish(s, b)
	var card_id: StringName = f["reward_card"]
	assert_bool(card_id != &"").is_true()
	var entry: Dictionary = CardsData.CARDS[card_id]
	assert_that(entry["source_kind"]).is_not_equal(&"policy")
	assert_that(entry["source_kind"]).is_not_equal(&"legacy")


func test_intel_qualification_ladder() -> void:
	var s := _state()
	assert_bool(Battle.intel_covers(s)).is_false()
	s.policies.append(&"scout_camp")
	assert_bool(Battle.intel_covers(s)).is_true()    # tribal covered
	s.generation = 17                                # faith era
	assert_bool(Battle.intel_covers(s)).is_false()   # coverage doesn't extend itself
	s.policies.append(&"political_marriage")
	assert_bool(Battle.intel_covers(s)).is_true()


func test_war_song_buffs_attack() -> void:
	var s := _state()
	s.deck = []
	s.deck.append(Cards.CardInstance.new(&"war_song", 1))
	var b := Battle.start(s, &"tax_battle")
	b.player_units.append(_unit(1, 10))
	Battle.play_card(s, b, 0)
	assert_int(int(b.player_units[0]["attack"])).is_equal(2)
	assert_int(b.attack_buff_rounds).is_equal(2)
