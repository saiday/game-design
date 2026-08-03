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


func _stations(report: Dictionary) -> Dictionary:
	# &"take_station" events of this round, keyed by unit label (the fixtures here field one
	# unit per class, so a label is a handle — see architecture.md §Timeline event contract).
	var out: Dictionary = {}
	for event: Dictionary in (report["events"] as Array):
		if event["type"] == &"take_station":
			out[event["unit"]] = event
	return out


func _events_of(report: Dictionary, event_type: StringName) -> Array:
	var out: Array = []
	for event: Dictionary in (report["events"] as Array):
		if event["type"] == event_type:
			out.append(event)
	return out


func _ranged_pressure(state: GameState, battle: Battle.BattleField, speed: float = 1.0) -> void:
	# The enemy field reduced to ONE 遠程列 attacker that is not a sieger. 非正規軍 stand in the
	# 近戰列 unless they carry 帶攻城, and a sieger busts a wall instead of shooting past it, so real
	# ranged pressure means a 正規軍 弓箭團. `speed` buys shots per window: a wall's whole 3～5-shot
	# budget can be spent inside one round.
	battle.enemy_units.clear()
	battle.waves.clear()
	battle.next_wave = 0
	var archer: Dictionary = Battle.regular_unit(state, &"archers", &"enemy", &"enemy", null)
	archer["speed"] = speed
	battle.enemy_units.append(archer)


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


# --- the cover chain: 盾陣 absorbs ranged fire aimed at the 遠程列 (ADR-0008 + ADR-0010) ---

func test_wall_absorbs_ranged_fire_until_its_budget_empties() -> void:
	# ADR-0010 inverts ADR-0008's interception: the wall eats 遠程火力 aimed at the row it screens,
	# 3～5 shots' worth, and 吸滿發數 is what disables it.
	var s := _state()
	_craft(s, &"archers", 4, 0.0, 0.0, 0.0)          # silent 遠程列 unit: the row being screened
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"archers")
	_deploy_id(s, battle, &"shield_wall")
	_ranged_pressure(s, battle)                      # one shot per round, so the budget is visible
	var budget: int = int(battle.player_forts[0]["shots"])
	assert_int(budget).is_between(3, 5)              # 佈陣時抽定 3～5 發
	for i: int in range(budget):
		var report := Battle.end_round(s, battle)
		var absorbed: Array = _events_of(report, &"intercept")
		assert_int(absorbed.size()).is_equal(1)
		assert_that(absorbed[0]["card_id"]).is_equal(&"shield_wall")
		assert_int(int(absorbed[0]["shots_left"])).is_equal(budget - i - 1)
		assert_bool(_has_event(report, &"hit")).is_false()   # 無視攻擊力: nothing resolves
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_true()
	assert_int(battle.player_forts.size()).is_equal(1)       # 本場永不移除, even with no engineer
	# a disabled 盾陣 absorbs nothing and nobody repairs it: the next shot reaches the unit
	assert_bool(_has_event(Battle.end_round(s, battle), &"hit")).is_true()


func test_melee_walks_around_the_wall_and_engages_the_ranged_row() -> void:
	# 牆擋的是子彈，不是人 (ADR-0010): 近戰啃完近戰列後直接繞過牆打遠程列. This is the exact rule
	# ADR-0008 had backwards, so it is asserted from both ends — the wall never fires, and the rock
	# the hurt unit dives behind does not stop a fist either.
	var s := _state()
	_craft(s, &"archers", 4, 0.0, 0.0, 0.0)          # hp 5: survives the mob's 攻2 twice
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")           # 中×1 (攻2), 近戰列
	_deploy_id(s, battle, &"archers")
	_deploy_id(s, battle, &"shield_wall")
	var report := Battle.end_round(s, battle)
	assert_bool(_has_event(report, &"intercept")).is_false()
	assert_bool(_has_event(report, &"hit")).is_true()
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_false()   # never fired, never down
	assert_int(int(battle.player_forts[0]["shots"])).is_between(3, 5)  # budget untouched
	assert_bool(_has_event(report, &"take_cover")).is_true()           # hurt, so it fell back
	assert_bool(_has_event(Battle.end_round(s, battle), &"hit")).is_true()


func test_wall_ignores_ranged_fire_aimed_at_the_melee_row() -> void:
	# The 工事線 stands BEHIND the 近戰列 (ADR-0008), so a shot at the front layer lands in front of
	# the wall. Same for a wall with nothing behind it at all: an all-melee deck buys a screen that
	# never fires and never disables (docs/decisions.md W14.6).
	var s := _state()
	_craft(s, &"elite_forces", 3, 0.0, 0.0, 0.0)     # silent 近戰列 sponge, hp 12
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"elite_forces")
	_deploy_id(s, battle, &"shield_wall")
	_ranged_pressure(s, battle)
	var first := Battle.end_round(s, battle)
	assert_bool(_has_event(first, &"hit")).is_true()
	assert_bool(_has_event(first, &"intercept")).is_false()
	# the neutral rock it dove behind is what covers it instead — cover with no owner and no row
	assert_that(battle.player_units[0]["cover"]).is_equal(&"scat_riot_crate")
	for i: int in range(3):
		Battle.end_round(s, battle)
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_false()
	assert_int(int(battle.player_forts[0]["shots"])).is_between(3, 5)


func test_regular_army_fields_a_screen_it_can_never_repair() -> void:
	# 正規軍也出盾陣 (戰鬥.md 對手兩型): the wave that brings a 遠程列 regular brings the wall that
	# covers it. There is no enemy 工兵團, so once your 遠程列 has spent its budget the screen stays
	# down for the rest of the battle — the engineer line's value.
	var s := _state()
	Rivals.setup(s)
	var rival := Rivals.find(s, &"iron_tribe")
	rival.power = 30.0                               # wave 1: cavalry + archers → one screen
	_craft(s, &"archers", 1, 0.0, 0.0, 6.0)          # six shots a round, enough for any budget
	var battle := Battle.start(s, &"civil_war", &"iron_tribe")
	assert_int(battle.enemy_forts.size()).is_equal(1)
	assert_that(battle.enemy_forts[0]["card_id"]).is_equal(&"shield_wall")
	var budget: int = int(battle.enemy_forts[0]["shots"])
	assert_int(budget).is_between(3, 5)
	battle.enemy_units.clear()                       # only their 遠程列 left, so our fire is screened
	battle.enemy_units.append(Battle.regular_unit(s, &"archers", &"enemy", &"enemy", rival))
	battle.enemy_units[0]["speed"] = 0.0             # silent: isolate the wall
	_deploy_id(s, battle, &"archers")
	var report := Battle.end_round(s, battle)
	assert_int(_events_of(report, &"intercept").size()).is_equal(budget)
	assert_bool(bool(battle.enemy_forts[0]["disabled"])).is_true()
	Battle.end_round(s, battle)
	assert_bool(bool(battle.enemy_forts[0]["disabled"])).is_true()   # 敵方的工事永不修復


# --- 中立掩體: neutral cover, first come, either side (ADR-0010) ---

func test_barrier_roster_comes_from_the_battle_types_own_ground() -> void:
	# One barrier per barrier-carrying prop in this battle type's approved scatter roster, read off
	# `AssetPaths.SCATTER` and never invented here (docs/decisions.md W14.9). 隱藏戰's zero is the
	# identity of that ground, not an oversight.
	var s := _state(21)
	assert_int(Battle.start(s, &"hidden_battle").barriers.size()).is_equal(0)
	var riot := Battle.start(s, &"riot")
	assert_int(riot.barriers.size()).is_equal(1)
	assert_that(riot.barriers[0]["prop"]).is_equal(&"scat_riot_crate")
	assert_that(riot.barriers[0]["tier"]).is_equal(&"weak")
	assert_int(int(riot.barriers[0]["shots"])).is_between(1, 2)
	assert_bool(bool(riot.barriers[0]["destroyed"])).is_false()
	var war := _world_war_field(s, &"infantry")
	assert_int(war.barriers.size()).is_equal(2)
	assert_that(war.barriers[0]["tier"]).is_equal(&"weak")
	assert_that(war.barriers[1]["tier"]).is_equal(&"medium")
	assert_int(int(war.barriers[1]["shots"])).is_between(2, 3)
	# rolled on the &"battle" track, so the same seed lays out the same cover
	assert_str(str(_world_war_field(_state(7), &"infantry").barriers)) \
		.is_equal(str(_world_war_field(_state(7), &"infantry").barriers))


func test_hurt_land_unit_takes_cover_and_the_rock_eats_the_next_bullets() -> void:
	var s := _state()
	_craft(s, &"infantry", 4, 0.0, 0.0, 0.0)         # silent 近戰列 sponge, hp 10
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"infantry")
	_ranged_pressure(s, battle)
	var first := Battle.end_round(s, battle)
	assert_bool(_has_event(first, &"hit")).is_true()          # unhurt, so nothing covers it yet
	var covered: Array = _events_of(first, &"take_cover")
	assert_int(covered.size()).is_equal(1)
	assert_that(covered[0]["unit"]).is_equal(&"infantry")
	assert_that(covered[0]["barrier"]).is_equal(&"scat_riot_crate")
	assert_that(covered[0]["tier"]).is_equal(&"weak")
	assert_int(int(covered[0]["tick"])).is_greater(0)         # the moment it was hit, not the boundary
	# from here the rock takes the fire, 弱＝擋 1～2 發, and the shot that empties it destroys it
	var shots: int = int(battle.barriers[0]["shots"])
	var last: Dictionary = {}
	for i: int in range(shots):
		last = Battle.end_round(s, battle)
		var absorbed: Array = _events_of(last, &"intercept")
		assert_int(absorbed.size()).is_equal(1)
		assert_that(absorbed[0]["barrier"]).is_equal(&"scat_riot_crate")
		assert_that(absorbed[0]["card_id"]).is_equal(&"")     # 中立: no owner, so no card
		assert_bool(_has_event(last, &"hit")).is_false()
	assert_bool(_has_event(last, &"barrier_destroyed")).is_true()
	assert_bool(bool(battle.barriers[0]["destroyed"])).is_true()
	assert_that(battle.player_units[0]["cover"]).is_equal(&"")   # exposed again
	assert_bool(_has_event(Battle.end_round(s, battle), &"hit")).is_true()


func test_engineers_cannot_bring_a_destroyed_barrier_back() -> void:
	# 散景不是工事 (戰鬥.md 場景呈現): the one lifecycle difference. A fort waits for the engineer,
	# a barrier is gone.
	var s := _state()
	_craft(s, &"infantry", 4, 0.0, 0.0, 0.0)
	_craft(s, &"engineers", 1, 0.0, 10.0, 0.0)
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"infantry")
	_deploy_id(s, battle, &"engineers")
	_ranged_pressure(s, battle)
	var last: Dictionary = {}
	for i: int in range(5):
		last = Battle.end_round(s, battle)
		if _has_event(last, &"barrier_destroyed"):
			break
	assert_bool(_has_event(last, &"barrier_destroyed")).is_true()
	var exposed: Array = _events_of(last, &"take_cover")
	assert_that(exposed[exposed.size() - 1]["barrier"]).is_equal(&"")   # nothing covers it now
	for i: int in range(2):
		var report := Battle.end_round(s, battle)
		assert_bool(_has_event(report, &"repair")).is_false()
		assert_bool(_has_event(report, &"intercept")).is_false()
	assert_bool(bool(battle.barriers[0]["destroyed"])).is_true()


func test_barrier_is_shared_by_both_sides_first_come() -> void:
	# 掩體先到先用、敵我都能用 — 中立就是這個意思. Here the ENEMY gets the rock, and our own 遠程列
	# fire is what it absorbs.
	var s := _state()
	_craft(s, &"archers", 1, 100.0, 0.0, 1.0)        # 攻1, one shot a round
	var battle := Battle.start(s, &"riot")           # 中×1: hp 4, 近戰列
	_deploy_id(s, battle, &"archers")
	battle.enemy_units[0]["speed"] = 0.0             # silent mob: isolate who takes cover
	battle.waves.clear()
	battle.next_wave = 0
	var covered: Array = _events_of(Battle.end_round(s, battle), &"take_cover")
	assert_int(covered.size()).is_equal(1)
	assert_that(covered[0]["side"]).is_equal(&"enemy")
	assert_that(covered[0]["unit"]).is_equal(&"medium")
	var second := Battle.end_round(s, battle)
	var absorbed: Array = _events_of(second, &"intercept")
	assert_int(absorbed.size()).is_equal(1)
	assert_that(absorbed[0]["side"]).is_equal(&"player")   # the shooter's side, as ever
	assert_bool(_has_event(second, &"hit")).is_false()


func test_air_never_takes_cover_and_bombs_are_never_absorbed() -> void:
	# ADR-0006 stands untouched: cover absorbs 遠程列 fire only, 空襲 comes from above it, and
	# 空域 units do not hide behind ground dressing (docs/decisions.md W14.9).
	var s := _state(5)
	s.generation = 25                                # industrial: 轟炸機 has a form
	_craft(s, &"bomber", 4, 100.0, 0.0, 1.0)
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"bomber")
	battle.player_units[0]["attack"] = 1             # keep the mob alive: the point is the path
	battle.waves.clear()
	battle.next_wave = 0
	var first := Battle.end_round(s, battle)
	assert_bool(_has_event(first, &"take_cover")).is_true()      # the mob dives behind the crate
	var second := Battle.end_round(s, battle)
	assert_bool(_has_event(second, &"intercept")).is_false()     # 空襲不被掩體吸收
	assert_bool(_has_event(second, &"hit")).is_true()
	assert_int(int(battle.barriers[0]["shots"])).is_between(1, 2) # and the rock is untouched
	# our bomber is being shot at by the mob and still never takes cover
	_ranged_pressure(s, battle)
	Battle.end_round(s, battle)
	assert_that(battle.player_units[0]["cover"]).is_equal(&"")


func test_irregulars_field_no_works_even_in_the_ranged_row() -> void:
	# 非正規軍不出任何工事 — a 帶攻城 irregular stands in the 遠程列 with nothing covering it.
	var s := _state()
	var battle := Battle.start(s, &"hidden_battle")   # 硬×1 帶攻城, ranged row
	assert_that(battle.enemy_units[0]["row"]).is_equal(&"ranged")
	assert_int(battle.enemy_forts.size()).is_equal(0)


func test_take_station_names_the_wall_that_covers_the_row() -> void:
	var s := _state()
	_craft(s, &"infantry", 1, 0.0, 0.0, 0.0)
	_craft(s, &"archers", 1, 0.0, 0.0, 0.0)
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"infantry")
	_deploy_id(s, battle, &"archers")
	_deploy_id(s, battle, &"shield_wall")
	var stations := _stations(Battle.end_round(s, battle))
	assert_int(stations.size()).is_equal(3)                  # 2 ours + the 中×1 that arrived
	assert_that(stations[&"archers"]["screened_by"]).is_equal(&"shield_wall")
	assert_that(stations[&"infantry"]["screened_by"]).is_equal(&"")   # 近戰列 stands in front
	assert_that(stations[&"infantry"]["row"]).is_equal(&"melee")
	assert_that(stations[&"medium"]["screened_by"]).is_equal(&"")     # 非正規軍 have no works
	# a unit already in the chain does not re-announce itself round after round
	assert_int(_stations(Battle.end_round(s, battle)).size()).is_equal(0)


func test_take_station_re_emits_when_the_screen_changes() -> void:
	var s := _state()
	_craft(s, &"archers", 4, 0.0, 0.0, 0.0)
	_craft(s, &"engineers", 1, 0.0, 10.0, 0.0)
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"archers")
	_deploy_id(s, battle, &"engineers")
	_deploy_id(s, battle, &"shield_wall")
	_ranged_pressure(s, battle, 6.0)                        # spends the whole budget in one round
	Battle.end_round(s, battle)                             # the wall absorbs its 3-5 and goes down
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_true()
	var second := Battle.end_round(s, battle)               # 工兵 repairs it: the cover is back
	assert_bool(_has_event(second, &"repair")).is_true()
	var stations := _stations(second)
	assert_that(stations[&"archers"]["screened_by"]).is_equal(&"shield_wall")
	assert_that(stations[&"engineers"]["screened_by"]).is_equal(&"shield_wall")
	assert_int(int(stations[&"archers"]["tick"])).is_equal(0)   # same tick as the repair


# --- fortifications: disable & repair, never removed (ADR-0007) ---


func test_engineer_repairs_one_disabled_fort_per_round_and_it_rolls_a_fresh_budget() -> void:
	var s := _state()
	_craft(s, &"engineers", 1, 0.0, 10.0, 0.0)       # support: never fires
	_craft(s, &"archers", 4, 0.0, 0.0, 0.0)          # the 遠程列 the wall screens
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"engineers")
	_deploy_id(s, battle, &"archers")
	_deploy_id(s, battle, &"shield_wall")
	_ranged_pressure(s, battle, 6.0)                 # six shots a round: any budget empties
	Battle.end_round(s, battle)
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_true()
	assert_int(int(battle.player_forts[0]["shots"])).is_equal(0)
	var report := Battle.end_round(s, battle)
	assert_bool(_has_event(report, &"repair")).is_true()
	# 修復再啟用: the wall comes back with a NEWLY ROLLED budget and absorbs from the same round,
	# so the 工兵+盾陣 pair is a suppression duel — one repair a round against the incoming fire.
	assert_bool(_has_event(report, &"intercept")).is_true()
	assert_int(battle.player_forts.size()).is_equal(1)
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_true()   # six shots emptied it again


func test_engineer_arriving_late_repairs_older_damage() -> void:
	# ADR-0007: the engineer-present-at-the-hit conditional is gone — all that matters is that an
	# engineer eventually stands on the side.
	var s := _state()
	_craft(s, &"archers", 4, 0.0, 0.0, 0.0)           # 遠程列: the row the wall screens
	_craft(s, &"engineers", 1, 0.0, 10.0, 0.0)
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"archers")
	_deploy_id(s, battle, &"shield_wall")
	_ranged_pressure(s, battle, 6.0)
	Battle.end_round(s, battle)                       # emptied with nobody to fix it
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_true()
	_deploy_id(s, battle, &"engineers")               # arrives a round later
	assert_bool(_has_event(Battle.end_round(s, battle), &"repair")).is_true()


func test_repair_round_robin_does_not_starve_the_second_fort() -> void:
	var s := _state()
	_craft(s, &"engineers", 1, 0.0, 10.0, 0.0)
	for i: int in range(2):
		s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"engineers")
	_deploy_id(s, battle, &"shield_wall")
	_deploy_id(s, battle, &"shield_wall")
	battle.enemy_units.clear()                        # isolate the repair cadence
	battle.player_forts[0]["disabled"] = true
	battle.player_forts[1]["disabled"] = true
	Battle.end_round(s, battle)                       # repairs #0, cursor moves to #1
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_false()
	battle.player_forts[0]["disabled"] = true         # #0 goes down again
	Battle.end_round(s, battle)                       # 依序輪流: #1's turn, not #0 again
	assert_bool(bool(battle.player_forts[1]["disabled"])).is_false()
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_true()


func test_siege_disables_active_fort_then_hits_units() -> void:
	var s := _state()
	_craft(s, &"engineers", 1, 0.0, 10.0, 0.0)
	s.deck.append(Cards.CardInstance.new(&"shield_wall", 1))
	var battle := Battle.start(s, &"hidden_battle")   # 硬×1 帶攻城 (ranged row)
	_deploy_id(s, battle, &"engineers")
	_deploy_id(s, battle, &"shield_wall")
	var report := Battle.end_round(s, battle)
	assert_int(battle.player_forts.size()).is_equal(1)   # suppression, not demolition
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_true()
	assert_bool(_has_event(report, &"disable")).is_true()
	# the sieger stops re-hitting the wreck; with the engineer repairing, the two trade
	var second := Battle.end_round(s, battle)
	assert_bool(_has_event(second, &"repair")).is_true()
	assert_bool(_has_event(second, &"disable")).is_true()


# --- air: targeting matrix + 防空飛彈 (ADR-0006) ---

func test_melee_cannot_attack_air() -> void:
	var s := _state(5)
	_craft(s, &"bomber", 4, 0.0, 0.0, 0.0)     # blind and silent: a pure air target
	var battle := Battle.start(s, &"riot")     # 中×1, melee row
	_deploy_id(s, battle, &"bomber")
	var report := Battle.end_round(s, battle)
	assert_int(int(report["losses"])).is_equal(0)
	assert_bool(_has_event(report, &"hit")).is_false()   # a club gang can't beat a bomber down
	assert_bool(_has_event(report, &"miss")).is_false()  # it never even takes the shot


func test_ranged_can_pick_air_targets() -> void:
	var s := _state(5)
	_craft(s, &"bomber", 4, 0.0, 0.0, 0.0)
	var battle := Battle.start(s, &"hidden_battle")   # 硬×1 帶攻城 sits in the ranged row
	_deploy_id(s, battle, &"bomber")
	var report := Battle.end_round(s, battle)
	assert_bool(_has_event(report, &"hit")).is_true()   # 遠程列自由選目標（含空域）


func test_air_strike_hits_ground_only() -> void:
	var s := _state(5)
	Rivals.setup(s)
	s.generation = 25                          # industrial: enemy 正規軍 field bombers
	var rival := Rivals.find(s, &"iron_tribe")
	rival.power = 200.0
	_craft(s, &"bomber", 4, 100.0, 0.0, 1.0)
	var battle := Battle.start(s, &"civil_war", &"iron_tribe")
	battle.enemy_units.clear()                 # air-only enemy field: nothing to strike
	battle.enemy_forts.clear()                 # and no 正規軍 screen to spend the shot on either
	battle.enemy_units.append(Battle.regular_unit(s, &"bomber", &"enemy", &"enemy", null))
	_deploy_id(s, battle, &"bomber")
	var report := Battle.end_round(s, battle)
	assert_bool(_has_event(report, &"hit")).is_false()    # 空襲任選地面目標: no air-to-air
	assert_int(int(report["kills"])).is_equal(0)


func test_anti_air_destroys_one_aircraft_per_round() -> void:
	var s := _state(5)
	Rivals.setup(s)
	s.generation = 25
	var rival := Rivals.find(s, &"iron_tribe")
	rival.power = 200.0
	s.deck.append(Cards.CardInstance.new(&"anti_air", 4))
	var battle := Battle.start(s, &"civil_war", &"iron_tribe")
	battle.enemy_units.clear()
	for i: int in range(2):
		battle.enemy_units.append(Battle.regular_unit(s, &"bomber", &"enemy", &"enemy", null))
	_deploy_id(s, battle, &"anti_air")
	var report := Battle.end_round(s, battle)
	assert_bool(_has_event(report, &"shootdown")).is_true()
	assert_int(int(report["kills"])).is_equal(1)          # 命中即擊落, one missile one aircraft
	assert_int(battle.enemy_units.size()).is_equal(1)
	assert_int(battle.merit).is_equal(int(Battle._type_strength(s, &"bomber")))
	# the survivor answers by suppressing the battery, and with no engineer it stays down
	assert_bool(_has_event(report, &"disable")).is_true()
	var second := Battle.end_round(s, battle)
	assert_bool(_has_event(second, &"shootdown")).is_false()
	assert_int(battle.enemy_units.size()).is_equal(1)


func test_engineer_keeps_the_battery_downing_one_aircraft_per_round() -> void:
	# The 防空+工兵 loop (ADR-0006/0007): their strike suppresses the battery, your engineer
	# repairs it, and it fires again the next round — one aircraft per round.
	var s := _state(5)
	s.generation = 25
	_craft(s, &"engineers", 4, 0.0, 10.0, 0.0)
	s.deck.append(Cards.CardInstance.new(&"anti_air", 4))
	var battle := _world_war_field(s, &"bomber")
	battle.enemy_units.append(Battle.regular_unit(s, &"bomber", &"enemy", &"enemy", null))
	_deploy_id(s, battle, &"engineers")
	_deploy_id(s, battle, &"anti_air")
	Battle.end_round(s, battle)
	assert_int(battle.enemy_units.size()).is_equal(1)
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_true()   # suppressed at tick 100
	var second := Battle.end_round(s, battle)
	assert_bool(_has_event(second, &"repair")).is_true()
	assert_bool(_has_event(second, &"shootdown")).is_true()
	assert_int(battle.enemy_units.size()).is_equal(0)


func test_anti_air_does_not_intercept_and_needs_an_air_target() -> void:
	var s := _state()
	_craft(s, &"infantry", 1, 0.0, 0.0, 0.0)
	s.deck.append(Cards.CardInstance.new(&"anti_air", 4))
	var battle := Battle.start(s, &"riot")               # ground melee enemy only
	_deploy_id(s, battle, &"infantry")
	_deploy_id(s, battle, &"anti_air")
	var report := Battle.end_round(s, battle)
	assert_bool(_has_event(report, &"shootdown")).is_false()   # 沒有空域目標就不開火
	assert_bool(_has_event(report, &"intercept")).is_false()   # 防空不攔截: its absorb job is gone
	assert_bool(_has_event(report, &"hit")).is_true()          # the melee attack lands unimpeded
	assert_bool(bool(battle.player_forts[0]["disabled"])).is_false()


func test_anti_air_has_no_form_before_industrial() -> void:
	var s := _state()
	assert_bool(Cards.has_form(&"anti_air", 1)).is_false()   # 有空軍才有防空
	assert_bool(Cards.has_form(&"anti_air", 3)).is_false()
	assert_bool(Cards.has_form(&"anti_air", 4)).is_true()


func test_air_only_opponent_cannot_end_an_exhausted_players_battle() -> void:
	# ADR-0006, symmetric 僅剩空軍: the player is exhausted, but the enemy holds only air,
	# so the battle continues until the round cap rules 判輸.
	var s := _state(5)
	Rivals.setup(s)
	s.generation = 25
	var rival := Rivals.find(s, &"iron_tribe")
	rival.power = 200.0
	var battle := Battle.start(s, &"civil_war", &"iron_tribe")
	battle.enemy_units.clear()
	battle.enemy_units.append(Battle.regular_unit(s, &"bomber", &"enemy", &"enemy", null))
	battle.waves.clear()
	battle.next_wave = 0
	Battle.end_round(s, battle)                    # empty deck: player already has nothing
	assert_bool(battle.player_units.is_empty()).is_true()
	assert_that(battle.outcome).is_equal(&"")      # 只剩空軍拿不下戰場, 敵我皆然
	while battle.outcome == &"":
		Battle.end_round(s, battle)
	assert_that(battle.outcome).is_equal(&"loss")   # 判輸 at the cap (civil_war: 10)
	assert_int(battle.round).is_equal(10)


func _world_war_field(s: GameState, enemy_type: StringName) -> Battle.BattleField:
	# 世界大戰 opened straight on the engine with one prepared enemy wave (WorldWar composes the
	# real two-camp schedule; here the point is the uncapped round rule).
	var wave: Array[Dictionary] = [{"round": 1, "side": &"enemy",
			"units": [Battle.regular_unit(s, enemy_type, &"enemy", &"enemy", null)] as Array[Dictionary]}]
	return Battle.start(s, &"world_war", &"", false, false, wave)


func test_world_war_deadlock_settles_immediately() -> void:
	# 世界大戰 僵局判定: no round cap to fall back on, so the moment the field can no longer
	# change the war settles — here the bomber kills the last ground unit and then has nothing
	# left it can legally hit, and no camp holds 陸軍 → 玩家所在營敗 (design/世界大戰.md).
	var s := _state(5)
	s.generation = 25                              # industrial: 轟炸機 has a form
	var battle := _world_war_field(s, &"bomber")
	assert_int(battle.round_cap).is_equal(0)
	battle.player_units.append(Battle.regular_unit(s, &"infantry", &"player", &"player", null))
	Battle.end_round(s, battle)
	assert_bool(battle.player_units.is_empty()).is_true()   # struck down by the 空襲
	assert_that(battle.outcome).is_equal(&"loss")
	assert_int(battle.round).is_equal(1)            # settled on the spot, no endless watch mode


func test_world_war_mutual_air_remnants_settle_at_once() -> void:
	# The corpus's own example of 戰局不再可能變化: 兩邊都只剩空域單位. Neither camp holds 陸軍,
	# so the player's camp loses — and watch mode never spins forever.
	var s := _state(5)
	s.generation = 25
	_craft(s, &"bomber", 4, 100.0, 0.0, 1.0)
	var battle := _world_war_field(s, &"bomber")
	_deploy_id(s, battle, &"bomber")               # both camps now hold air and nothing else
	Battle.end_round(s, battle)
	assert_int(battle.player_units.size()).is_equal(1)   # air-vs-air is unreachable both ways
	assert_int(battle.enemy_units.size()).is_equal(1)
	assert_that(battle.outcome).is_equal(&"loss")
	assert_int(battle.round).is_equal(1)


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
	s.population = 12
	Cards.starting_deck(s)
	var battle := Battle.start(s, &"field_battle")
	var report := Battle.retreat(s, battle)
	assert_that(battle.outcome).is_equal(&"retreat")
	assert_int(int(report["cost"])).is_equal(10)
	assert_int(s.population).is_equal(14)
	assert_bool(Battle.finish(s, battle).has("reward_instance")).is_true()


# --- W13 growth: XP accrual, medal events, 心戰 debuff ---

func test_battle_xp_accrues_per_source() -> void:
	var s := _state()
	var instance := _craft(s, &"cavalry", 1, 100.0, 0.0, 1.0)
	var battle := Battle.start(s, &"tax_battle")
	_deploy_id(s, battle, &"cavalry")
	var rounds: int = 0
	while battle.outcome == &"":
		Battle.end_round(s, battle)
		rounds += 1
	assert_that(battle.outcome).is_equal(&"win")
	assert_int(int(instance.xp.get(&"accuracy", 0))).is_equal(2)    # 出手攻擊 ×2 (one kill each)
	assert_int(int(instance.xp.get(&"dodge", 0))).is_equal(1)       # survived exactly one hit
	assert_int(int(instance.xp.get(&"speed", 0))).is_equal(rounds)  # 每存活一個回合
	assert_int(instance.levels.size()).is_equal(0)                  # nothing filled yet


func test_medal_lands_in_timeline_when_xp_fills() -> void:
	var s := _state()
	var instance := _craft(s, &"cavalry", 1, 100.0, 0.0, 1.0)
	instance.xp[&"accuracy"] = 4   # one attack away from the medal (XP_TO_MEDAL 5)
	var battle := Battle.start(s, &"tax_battle")
	_deploy_id(s, battle, &"cavalry")
	var report := Battle.end_round(s, battle)
	var medal_seen := false
	for event: Dictionary in (report["events"] as Array):
		if event["type"] == &"medal":
			medal_seen = true
			assert_that(event["stat"]).is_equal(&"accuracy")
			assert_that(event["unit"]).is_equal(&"cavalry")
			assert_int(int(event["level"])).is_equal(1)
	assert_bool(medal_seen).is_true()
	assert_int(int(instance.levels[&"accuracy"])).is_equal(1)
	assert_int(int(instance.xp[&"accuracy"])).is_equal(0)


func test_medal_applies_from_next_round_snapshot() -> void:
	var s := _state()
	_craft(s, &"engineers", 1, 0.0, 0.0, 0.0)                   # 遠程列 support, deploy index 0
	var instance := _craft(s, &"cavalry", 3, 80.0, 0.0, 0.1)    # 近戰列 focus target; hp 6 survives
	var battle := Battle.start(s, &"riot")
	_deploy_id(s, battle, &"engineers")
	_deploy_id(s, battle, &"cavalry")
	assert_float(float(battle.player_units[1]["accuracy"])).is_equal_approx(80.0, 0.001)
	Cards.award_medal(instance, &"accuracy")                    # e.g. a 兵營 medal mid-run
	assert_float(float(battle.player_units[1]["accuracy"])).is_equal_approx(80.0, 0.001)
	Battle.end_round(s, battle)                                 # boundary re-snapshot (D13)
	assert_float(float(battle.player_units[1]["accuracy"])).is_equal_approx(83.0, 0.001)


func test_enemy_psyops_debuffs_accuracy_for_one_battle() -> void:
	var s := _state()
	_craft(s, &"cavalry", 1, 90.0, 0.0, 1.0)
	s.flags[&"enemy_psyops_next_battle"] = true
	var battle := Battle.start(s, &"tax_battle")
	assert_bool(battle.psyops_active).is_true()
	assert_bool(s.flags.has(&"enemy_psyops_next_battle")).is_false()   # consumed
	_deploy_id(s, battle, &"cavalry")
	assert_float(float(battle.player_units[0]["accuracy"])).is_equal_approx(80.0, 0.001)
	var second := Battle.start(s, &"tax_battle")                # 下場戰 only
	assert_bool(second.psyops_active).is_false()
