class_name BattleTest
extends GdUnitTestSuite
# Suite for core/battle.gd (design/戰鬥.md + plan-battle-model-rewrite D1-D6): rolled wave
# schedules, tick-window resolution on attack speed, event timelines, symmetric exhaustion,
# survivor persistence, 正規軍 conversion. Player stats are hand-crafted per test (acc/dodge/
# speed set directly on instances) so combat math is exact; roll determinism itself is
# covered in cards_test.


func _state(seed_value: int = 33) -> GameState:
	return GameState.new_run(seed_value)


func _craft(state: GameState, card_id: StringName, tier: int, acc: float, dodge: float, speed: float) -> Cards.CardInstance:
	var instance := Cards.CardInstance.new(card_id, tier)
	instance.grade = &"medium"
	instance.accuracy = acc
	instance.dodge = dodge
	instance.speed = speed
	state.deck.append(instance)
	return instance


func _deploy_id(state: GameState, battle: Battle.BattleField, card_id: StringName) -> Dictionary:
	for i: int in range(battle.available.size()):
		if (battle.available[i] as Cards.CardInstance).id == card_id:
			return Battle.deploy(state, battle, i)
	return {"ok": false, "reason": &"not_in_available"}


func _has_event(report: Dictionary, event_type: StringName) -> bool:
	for event: Dictionary in (report["events"] as Array):
		if event["type"] == event_type:
			return true
	return false


# --- waves ---

func test_wave_roll_deterministic_and_within_window() -> void:
	var a := _state(7)
	var b := _state(7)
	var battle_a := Battle.start(a, &"field_battle")
	var battle_b := Battle.start(b, &"field_battle")
	assert_int(battle_a.waves.size()).is_equal(2)
	assert_int(int(battle_a.waves[0]["round"])).is_equal(1)
	assert_int(int(battle_a.waves[1]["round"])).is_between(3, 4)
	assert_int(int(battle_a.waves[1]["round"])).is_equal(int(battle_b.waves[1]["round"]))
	assert_int((battle_a.waves[0]["units"] as Array).size()).is_equal(2)   # 中×1＋弱×1
	assert_int((battle_a.waves[1]["units"] as Array).size()).is_equal(1)   # 中×1


func test_wave_one_is_the_opening() -> void:
	var s := _state()
	var battle := Battle.start(s, &"tax_battle")
	assert_int(battle.enemy_units.size()).is_equal(2)   # 弱×2: wave 1 = 敵方開場單位
	assert_int(battle.next_wave).is_equal(1)
	assert_int(int(battle.enemy_units[0]["attack"])).is_equal(1)
	assert_int(int(battle.enemy_units[0]["hp"])).is_equal(2)
	assert_int(battle.expected_reward).is_equal(15)


func test_waves_stack_on_survivors() -> void:
	# D4: an uncleared wave means the next wave stacks on its remnant.
	var s := _state()
	Cards.starting_deck(s)   # player has cards but fields nothing: enemies just stack
	var battle := Battle.start(s, &"field_battle")
	var wave2_round: int = int(battle.waves[1]["round"])
	while battle.round < wave2_round and battle.outcome == &"":
		Battle.end_round(s, battle)
	assert_int(battle.enemy_units.size()).is_equal(3)   # 2 survivors + 1 stacked


# --- the tick window ---

func test_timeline_deterministic_same_seed() -> void:
	var a := _state(11)
	var b := _state(11)
	Cards.starting_deck(a)
	Cards.starting_deck(b)
	var battle_a := Battle.start(a, &"field_battle")
	var battle_b := Battle.start(b, &"field_battle")
	Battle.deploy(a, battle_a, 0)
	Battle.deploy(b, battle_b, 0)
	var report_a := Battle.end_round(a, battle_a)
	var report_b := Battle.end_round(b, battle_b)
	assert_str(str(report_a["events"])).is_equal(str(report_b["events"]))
	assert_str(str(report_a)).is_equal(str(report_b))


func test_faster_fires_first_no_mutual_destruction() -> void:
	# D6: units act on their own speed; the faster one fires first and LIVES.
	var s := _state(5)
	_craft(s, &"elite_forces", 2, 100.0, 0.0, 2.0)   # atk 6, hp 8, two shots per window
	var battle := Battle.start(s, &"tax_battle")     # 弱×2: atk 1, hp 2, speed 1.0
	_deploy_id(s, battle, &"elite_forces")
	var report := Battle.end_round(s, battle)
	assert_int(int(report["kills"])).is_equal(2)
	assert_int(int(report["losses"])).is_equal(0)
	assert_that(battle.outcome).is_equal(&"win")     # exhausted: no units, no waves left
	assert_int(int(battle.player_units[0]["hp"])).is_equal(8)   # never got hit
	assert_int(battle.merit).is_equal(6)             # 2 × weak strength (1+2)×係數1


func test_accuracy_zero_always_misses() -> void:
	var s := _state(9)
	_craft(s, &"elite_forces", 2, 0.0, 0.0, 1.0)     # blind; hp 8 soaks the answer
	var battle := Battle.start(s, &"tax_battle")
	_deploy_id(s, battle, &"elite_forces")
	var report := Battle.end_round(s, battle)
	assert_int(int(report["kills"])).is_equal(0)
	assert_int(battle.enemy_units.size()).is_equal(2)
	assert_bool(_has_event(report, &"miss")).is_true()
	assert_int(int(battle.player_units[0]["hp"])).is_equal(6)   # took 1+1 from the weak pair


func test_dodge_events_occur() -> void:
	var s := _state(13)
	_craft(s, &"elite_forces", 4, 0.0, 50.0, 1.0)    # hp 20, max dodge, never hits back
	var battle := Battle.start(s, &"tax_battle")
	_deploy_id(s, battle, &"elite_forces")
	var dodge_seen := false
	for i: int in range(5):
		if battle.outcome != &"":
			break
		if _has_event(Battle.end_round(s, battle), &"dodge"):
			dodge_seen = true
	assert_bool(dodge_seen).is_true()


func test_war_song_buffs_damage_at_fire_time() -> void:
	var s := _state(5)
	_craft(s, &"infantry", 1, 100.0, 0.0, 1.0)       # atk 1 → 2 with 軍歌
	s.deck.append(Cards.CardInstance.new(&"war_song", 1))
	var battle := Battle.start(s, &"tax_battle")
	_deploy_id(s, battle, &"war_song")
	_deploy_id(s, battle, &"infantry")
	var report := Battle.end_round(s, battle)
	var buffed_hit := false
	for event: Dictionary in (report["events"] as Array):
		if event["type"] == &"hit" and event["by"] == &"infantry" and int(event["damage"]) == 2:
			buffed_hit = true
	assert_bool(buffed_hit).is_true()


# --- exhaustion (D3) ---

func test_player_exhaustion_is_loss() -> void:
	var s := _state()   # empty deck: nothing fielded, nothing to commit
	var battle := Battle.start(s, &"tax_battle")
	Battle.end_round(s, battle)
	assert_that(battle.outcome).is_equal(&"loss")
	var finish := Battle.finish(s, battle)
	assert_that(finish["outcome"]).is_equal(&"loss")
	assert_bool(finish.has("reward_instance")).is_true()   # 勝敗皆然、每場必發


func test_concede_with_cards_left_is_legal_loss() -> void:
	var s := _state()
	Cards.starting_deck(s)
	var battle := Battle.start(s, &"tax_battle")
	Battle.concede(battle)   # 還有未出卡但選擇不出
	Battle.end_round(s, battle)
	assert_that(battle.outcome).is_equal(&"loss")


func test_air_only_field_cannot_take_the_win() -> void:
	var s := _state(5)
	_craft(s, &"bomber", 4, 100.0, 0.0, 1.0)   # atk 25: one kill per window
	var battle := Battle.start(s, &"tax_battle")
	_deploy_id(s, battle, &"bomber")
	Battle.end_round(s, battle)
	Battle.end_round(s, battle)
	assert_int(battle.enemy_units.size()).is_equal(0)   # both weak dead by round 2
	assert_that(battle.outcome).is_equal(&"")            # 只剩空中單位不算拿下戰場
	while battle.outcome == &"":
		Battle.end_round(s, battle)
	assert_that(battle.outcome).is_equal(&"loss")        # 判輸 at the round cap
	assert_int(battle.round).is_equal(6)


func test_round_cap_is_loss() -> void:
	var s := _state()
	Cards.starting_deck(s)
	var battle := Battle.start(s, &"field_battle")
	while battle.outcome == &"":
		Battle.end_round(s, battle)   # never deploys; enemies stack, nobody dies
	assert_that(battle.outcome).is_equal(&"loss")
	assert_int(battle.round).is_equal(8)


# --- deployment (D1: 軍費 is the only gate and never blocks) ---

func test_deploy_spends_into_debt_and_once_per_card() -> void:
	var s := _state()
	s.treasury = 0
	_craft(s, &"cavalry", 1, 85.0, 20.0, 1.2)
	var battle := Battle.start(s, &"tax_battle")
	assert_int(battle.available.size()).is_equal(1)
	var report := _deploy_id(s, battle, &"cavalry")
	assert_bool(bool(report["ok"])).is_true()
	assert_int(s.treasury).is_equal(-3)              # negative, never blocked
	assert_int(battle.spent).is_equal(3)
	assert_int(battle.available.size()).is_equal(0)  # 每張卡每場只出一次
	assert_bool(bool(_deploy_id(s, battle, &"cavalry")["ok"])).is_false()


func test_fort_limit_two() -> void:
	var s := _state()
	for i: int in range(3):
		s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"tax_battle")
	assert_bool(bool(Battle.deploy(s, battle, 0)["ok"])).is_true()
	assert_bool(bool(Battle.deploy(s, battle, 0)["ok"])).is_true()
	assert_that(Battle.deploy(s, battle, 0)["reason"]).is_equal(&"fort_limit")


# --- fortifications ---

func test_fort_absorbs_once_then_consumed_without_engineers() -> void:
	var s := _state()
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")           # 中×1, melee
	_deploy_id(s, battle, &"shield_wall")
	var report := Battle.end_round(s, battle)
	assert_int(battle.player_forts.size()).is_equal(0)   # 擋一次近戰即消耗
	assert_bool(_has_event(report, &"absorb")).is_true()


func test_engineers_turn_absorb_into_repair() -> void:
	var s := _state()
	_craft(s, &"engineers", 1, 0.0, 10.0, 0.0)       # support: never fires
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"engineers")
	_deploy_id(s, battle, &"shield_wall")
	Battle.end_round(s, battle)
	assert_int(battle.player_forts.size()).is_equal(1)          # 轉為待修, not consumed
	assert_bool(bool(battle.player_forts[0]["damaged"])).is_true()
	var report := Battle.end_round(s, battle)                    # 自下一回合起修復
	assert_bool(_has_event(report, &"repair")).is_true()


func test_siege_demolishes_fort_outright() -> void:
	var s := _state()
	_craft(s, &"engineers", 1, 0.0, 10.0, 0.0)
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"hidden_battle")  # 硬×1 帶攻城 (ranged row)
	_deploy_id(s, battle, &"engineers")
	_deploy_id(s, battle, &"shield_wall")
	var report := Battle.end_round(s, battle)
	assert_int(battle.player_forts.size()).is_equal(0)   # demolition beats the repair rule
	assert_bool(_has_event(report, &"demolish")).is_true()


# --- death consequences ---

func test_player_death_wipes_growth() -> void:
	var s := _state(5)
	var infantry := _craft(s, &"infantry", 1, 0.0, 0.0, 1.0)   # hp 2: dies to 弱×2
	Cards.award_medal(infantry, &"speed")
	infantry.xp[&"accuracy"] = 2
	var battle := Battle.start(s, &"tax_battle")
	_deploy_id(s, battle, &"infantry")
	var report := Battle.end_round(s, battle)
	assert_int(int(report["losses"])).is_equal(1)
	assert_bool(infantry.levels.is_empty()).is_true()   # D11: 已獲成長全部歸零
	assert_bool(infantry.xp.is_empty()).is_true()
	assert_that(infantry.grade).is_equal(&"medium")     # D12: the roll survives


func test_non_leader_skills_skip_hard_and_regular() -> void:
	var s := _state()
	var battle := Battle.start(s, &"hidden_battle")     # 硬×1 = 首領
	var events: Array[Dictionary] = []
	Battle._destroy_one_non_leader(battle, events, 0)
	assert_int(battle.enemy_units.size()).is_equal(1)   # untouched
	assert_int(battle.merit).is_equal(0)
	assert_int(events.size()).is_equal(0)


# --- 正規軍 (civil war) ---

func test_civil_war_fields_regular_army() -> void:
	var s := _state()
	Rivals.setup(s)
	var rival := Rivals.find(s, &"iron_tribe")
	rival.power = 30.0   # 總實力 15 → wave budgets 6 / 5.25 / 3.75
	var battle := Battle.start(s, &"civil_war", &"iron_tribe")
	assert_int(battle.waves.size()).is_equal(3)
	var wave1: Array = battle.waves[0]["units"]
	assert_int(wave1.size()).is_equal(2)   # cavalry(4) + archers(2), greedy strongest-first
	var first: Dictionary = wave1[0]
	assert_that(first["card_id"]).is_equal(&"cavalry")
	assert_bool(bool(first["regular"])).is_true()
	assert_that(first["grade"]).is_equal(&"")
	assert_float(float(first["accuracy"])).is_equal_approx(100.0, 0.001)   # engine defaults
	assert_float(float(first["speed"])).is_equal_approx(1.0, 0.001)
	assert_int(int(battle.waves[1]["round"])).is_between(4, 5)
	assert_int(int(battle.waves[2]["round"])).is_between(7, 8)


func test_civil_war_psyops_discounts_regular_attack() -> void:
	var s := _state()
	Rivals.setup(s)
	var rival := Rivals.find(s, &"iron_tribe")
	rival.power = 30.0
	rival.psyops_discount = 0.3   # 7折封頂
	var battle := Battle.start(s, &"civil_war", &"iron_tribe")
	var first: Dictionary = (battle.waves[0]["units"] as Array)[0]
	assert_int(int(first["attack"])).is_equal(1)   # cavalry 2 × 0.7 → round → 1


# --- retreat ---

func test_retreat_costs_and_returns_population() -> void:
	var s := _state()
	Cards.starting_deck(s)
	var battle := Battle.start(s, &"field_battle")
	var report := Battle.retreat(s, battle)
	assert_that(battle.outcome).is_equal(&"retreat")
	assert_int(int(report["cost"])).is_equal(10)
	assert_int(s.population).is_equal(14)
	assert_bool(Battle.finish(s, battle).has("reward_instance")).is_true()
