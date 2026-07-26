class_name CardsTest
extends GdUnitTestSuite
# Suite for core/cards.gd + core/data/cards.gd (design/卡牌.md: 卡牌總表, 單位品質, 成長,
# 時代演化總表, 卡牌經濟). Quality rolls ride the &"cards" rng track; determinism is asserted
# by running identical seeds twice.


func _state() -> GameState:
	return GameState.new_run(33)


# --- catalog ---

func test_catalog_totals() -> void:
	assert_int(CardsData.CARDS.size()).is_equal(16)   # 壕溝 retired by the corpus rewrite
	var by_class := {&"personnel": 0, &"mechanical": 0, &"fortification": 0, &"skill": 0}
	for card_id: StringName in CardsData.CARDS.keys():
		var cls: StringName = CardsData.CARDS[card_id]["class"]
		by_class[cls] = int(by_class[cls]) + 1
	assert_int(int(by_class[&"personnel"])).is_equal(4)
	assert_int(int(by_class[&"mechanical"])).is_equal(5)
	assert_int(int(by_class[&"fortification"])).is_equal(2)
	assert_int(int(by_class[&"skill"])).is_equal(5)


func test_catalog_era_names_match_corpus() -> void:
	# Spot checks against 卡牌.md 時代演化總表 (the W10 corpus rewrite changed these).
	assert_str(String((CardsData.CARDS[&"cavalry"]["era_names"] as Array)[3])).is_equal("龍騎兵")
	assert_str(String((CardsData.CARDS[&"elite_forces"]["era_names"] as Array)[5])).is_equal("生化超級士兵")
	assert_str(String((CardsData.CARDS[&"bomber"]["era_names"] as Array)[3])).is_equal("飛船轟炸隊")
	assert_str(String((CardsData.CARDS[&"shield_wall"]["era_names"] as Array)[4])).is_equal("電網")
	assert_str(String((CardsData.CARDS[&"artillery"]["era_names"] as Array)[1])).is_equal("")
	assert_array(CardsData.CARDS[&"privateers"]["era_names"]).contains_exactly(
			["", "", "盜匪", "竊賊", "網路駭客", ""])
	assert_array(CardsData.CARDS[&"holy_warriors"]["era_names"]).contains_exactly(
			["", "", "", "神權火槍旅", "", ""])


func test_catalog_era_names_shape() -> void:
	for card_id: StringName in CardsData.CARDS.keys():
		var entry: Dictionary = CardsData.CARDS[card_id]
		if bool(entry["evolves"]):
			assert_int((entry["era_names"] as Array).size()).is_equal(6)


func test_quality_table_covers_exactly_the_units() -> void:
	for card_id: StringName in CardsData.CARDS.keys():
		assert_bool(CardsData.QUALITY.has(card_id)).is_equal(Cards.is_unit(card_id))


func test_retired_mechanics_stay_retired() -> void:
	assert_bool(CardsData.CARDS.has(&"trench")).is_false()
	assert_array(CardsData.CARDS[&"cavalry"]["flags"]).is_empty()
	assert_array(CardsData.CARDS[&"engineers"]["flags"]).contains_exactly_in_any_order(
			[&"repairs_fortifications", &"no_attack"])


# --- unlock gates (unchanged rules) ---

func test_tech_gate_modifiers() -> void:
	var s := _state()
	s.generation = 9   # era index 2
	assert_int(Cards.tech_gate(s)).is_equal(20)
	s.policies.append(&"writing_calendar")
	assert_int(Cards.tech_gate(s)).is_equal(16)
	s.policies.append(&"theocracy")
	assert_int(Cards.tech_gate(s)).is_equal(20)   # 2×8 + 2×2 (神學審查)


func test_unlock_cost_patent_halving() -> void:
	var s := _state()
	s.generation = 17   # coeff 3
	assert_int(Cards.unlock_cost(s)).is_equal(30)
	s.policies.append(&"patent_system")
	assert_int(Cards.unlock_cost(s)).is_equal(15)


func test_can_unlock_source_and_gates() -> void:
	var s := _state()
	s.tech = 100
	assert_that(Cards.can_unlock(s, &"infantry")["reason"]).is_equal(&"source_missing")
	s.regions.append(&"livelihood")
	assert_bool(bool(Cards.can_unlock(s, &"infantry")["ok"])).is_true()
	s.tech = 0
	assert_that(Cards.can_unlock(s, &"infantry")["reason"]).is_equal(&"tech_gate")


func test_can_unlock_no_form_early_gate() -> void:
	var s := _state()
	s.tech = 100
	s.buildings[&"barracks"] = 1
	assert_that(Cards.can_unlock(s, &"bomber")["reason"]).is_equal(&"no_form_this_era")
	s.generation = 25   # industrial
	assert_bool(bool(Cards.can_unlock(s, &"bomber")["ok"])).is_true()


func test_can_unlock_no_form_top_end_cutoff() -> void:
	# 聖戰士團 has its only form in 工業 (卡牌.md 時代演化總表).
	var s := _state()
	s.tech = 1000
	s.policies.append(&"holy_war")
	s.generation = 17   # faith
	assert_that(Cards.can_unlock(s, &"holy_warriors")["reason"]).is_equal(&"no_form_this_era")
	s.generation = 25   # industrial
	assert_bool(bool(Cards.can_unlock(s, &"holy_warriors")["ok"])).is_true()
	s.generation = 33   # modern
	assert_that(Cards.can_unlock(s, &"holy_warriors")["reason"]).is_equal(&"no_form_this_era")


# --- 單位品質: acquisition roll ---

func test_unlock_pays_and_rolls_quality() -> void:
	var s := _state()
	s.tech = 10
	s.regions.append(&"livelihood")
	var r := Cards.unlock(s, &"infantry")
	assert_bool(bool(r["ok"])).is_true()
	assert_int(int(r["cost"])).is_equal(10)
	assert_int(s.treasury).is_equal(20)
	var instance: Cards.CardInstance = s.deck[0]
	assert_bool(CardsData.GRADE_ORDER.has(instance.grade)).is_true()
	# Full envelope = bad band low .. good band high, clamped (Medium 85–95, width 10):
	assert_float(instance.accuracy).is_between(75.0, 100.0)
	assert_float(instance.dodge).is_between(0.0, 25.0)
	assert_float(instance.speed).is_between(0.6, 1.5)
	assert_that(Cards.unlock(s, &"infantry")["reason"]).is_equal(&"already_unlocked")


func _assert_band(band: Array[float], lo: float, hi: float) -> void:
	# Approx compare: band arithmetic on floats (0.6 − 0.3) carries representation error.
	assert_float(band[0]).is_equal_approx(lo, 0.000001)
	assert_float(band[1]).is_equal_approx(hi, 0.000001)


func test_band_math_and_clamps() -> void:
	# 卡牌.md §品質等級 worked example: 步兵團命中率 Medium 85–95 → Bad 75–85、Good 95–100.
	_assert_band(Cards.band_for(&"infantry", &"accuracy", &"bad"), 75.0, 85.0)
	_assert_band(Cards.band_for(&"infantry", &"accuracy", &"medium"), 85.0, 95.0)
	_assert_band(Cards.band_for(&"infantry", &"accuracy", &"good"), 95.0, 100.0)
	# dodge lower clamp at 0: infantry Bad [−5,5] → [0,5]; artillery Bad [−10,0] → [0,0]
	_assert_band(Cards.band_for(&"infantry", &"dodge", &"bad"), 0.0, 5.0)
	_assert_band(Cards.band_for(&"artillery", &"dodge", &"bad"), 0.0, 0.0)
	# accuracy upper clamp at 100: elite Good [98,106] → [98,100]
	_assert_band(Cards.band_for(&"elite_forces", &"accuracy", &"good"), 98.0, 100.0)
	# speed bands stay above the 0.1 floor
	_assert_band(Cards.band_for(&"artillery", &"speed", &"bad"), 0.3, 0.6)


func test_starting_deck_rolls_each_instance() -> void:
	var s := _state()
	Cards.starting_deck(s)
	assert_int(s.deck.size()).is_equal(5)
	assert_bool(s.unlocked_cards.has(&"infantry")).is_true()
	var accuracies: Array[float] = []
	for instance: Cards.CardInstance in s.deck:
		assert_that(instance.id).is_equal(&"infantry")
		assert_bool(CardsData.GRADE_ORDER.has(instance.grade)).is_true()
		if not accuracies.has(instance.accuracy):
			accuracies.append(instance.accuracy)
	# 五張各自抽定 — five independent rolls must not collapse into one statline.
	assert_int(accuracies.size()).is_greater(1)


func test_roll_determinism_same_seed() -> void:
	var a := GameState.new_run(77)
	var b := GameState.new_run(77)
	Cards.starting_deck(a)
	Cards.starting_deck(b)
	for i: int in range(5):
		var left: Cards.CardInstance = a.deck[i]
		var right: Cards.CardInstance = b.deck[i]
		assert_that(left.grade).is_equal(right.grade)
		assert_float(left.accuracy).is_equal_approx(right.accuracy, 0.000001)
		assert_float(left.dodge).is_equal_approx(right.dodge, 0.000001)
		assert_float(left.speed).is_equal_approx(right.speed, 0.000001)
	var ra := Cards.roll_reward(a)
	var rb := Cards.roll_reward(b)
	assert_that(ra.id).is_equal(rb.id)
	assert_that(ra.grade).is_equal(rb.grade)


func test_engineers_roll_dodge_only() -> void:
	var s := _state()
	var instance := Cards.add_reward_card(s, &"engineers")
	assert_bool(CardsData.GRADE_ORDER.has(instance.grade)).is_true()
	assert_float(instance.dodge).is_between(0.0, 25.0)
	assert_float(instance.accuracy).is_equal_approx(0.0, 0.000001)   # 不主動攻擊
	assert_float(instance.speed).is_equal_approx(0.0, 0.000001)      # 不出手


func test_forts_and_skills_never_roll() -> void:
	var s := _state()
	var fort := Cards.add_reward_card(s, &"shield_wall")
	var skill := Cards.add_reward_card(s, &"war_song")
	assert_that(fort.grade).is_equal(&"")
	assert_that(skill.grade).is_equal(&"")
	assert_float(fort.accuracy).is_equal_approx(0.0, 0.000001)


func test_display_name_grade_prefix() -> void:
	var instance := Cards.CardInstance.new(&"infantry", 2)
	instance.grade = &"medium"
	assert_str(Cards.display_name(instance)).is_equal("長矛方陣")
	instance.grade = &"bad"
	assert_str(Cards.display_name(instance)).is_equal("糟糕的長矛方陣")
	instance.grade = &"good"
	assert_str(Cards.display_name(instance)).is_equal("可靠的長矛方陣")


# --- 成長: medal levels, caps, death wipe ---

func test_growth_steps_and_caps() -> void:
	var s := _state()
	var instance := Cards.CardInstance.new(&"infantry", 1)
	instance.accuracy = 95.0
	instance.dodge = 10.0
	instance.speed = 1.0
	assert_int(Cards.award_medal(instance, &"accuracy")).is_equal(1)
	assert_int(Cards.award_medal(instance, &"accuracy")).is_equal(2)
	assert_float(Cards.accuracy_of(s, instance)).is_equal_approx(100.0, 0.000001)   # 101 → cap 100
	Cards.award_medal(instance, &"dodge")
	Cards.award_medal(instance, &"dodge")
	assert_float(Cards.dodge_of(s, instance)).is_equal_approx(14.0, 0.000001)
	for i: int in range(10):
		Cards.award_medal(instance, &"speed")
	assert_float(Cards.speed_of(s, instance)).is_equal_approx(2.0, 0.000001)   # 攻速無封頂


func test_wipe_growth_keeps_the_roll() -> void:
	var s := _state()
	var instance := Cards.CardInstance.new(&"cavalry", 1)
	instance.grade = &"good"
	instance.accuracy = 90.0
	instance.speed = 1.4
	Cards.award_medal(instance, &"speed")
	instance.xp[&"speed"] = 3
	Cards.wipe_growth(instance)
	assert_bool(instance.levels.is_empty()).is_true()
	assert_bool(instance.xp.is_empty()).is_true()
	# D12: the innate roll and grade survive death untouched.
	assert_that(instance.grade).is_equal(&"good")
	assert_float(Cards.speed_of(s, instance)).is_equal_approx(1.4, 0.000001)


# --- deck economy ---

func test_disband_is_paid_and_recovers_by_class() -> void:
	var s := _state()
	Cards.starting_deck(s)
	assert_that(Cards.disband(s, 0)["reason"]).is_equal(&"deck_minimum")
	s.deck.append(Cards.CardInstance.new(&"elite_forces", 2))
	s.population = 12
	var mech := Cards.disband(s, 5)   # mechanical: paid, no recovery (sunk cost)
	assert_bool(bool(mech["ok"])).is_true()
	assert_int(int(mech["cost"])).is_equal(8)
	assert_int(int(mech["population_recovered"])).is_equal(0)
	assert_int(s.treasury).is_equal(22)
	assert_int(s.population).is_equal(12)
	s.deck.append(Cards.CardInstance.new(&"infantry", 1))
	var personnel := Cards.disband(s, 0)   # personnel: paid, +2 population
	assert_int(int(personnel["population_recovered"])).is_equal(2)
	assert_int(s.treasury).is_equal(14)
	assert_int(s.population).is_equal(14)
	assert_int(s.deck.size()).is_equal(5)


func test_destroy_permanently_blocks_reunlock() -> void:
	var s := _state()
	s.generation = 41
	s.tech = 1000
	s.policies.append(&"space_station")
	Cards.unlock(s, &"orbital_strike")
	Cards.destroy_permanently(s, &"orbital_strike")
	assert_int(s.deck.size()).is_equal(0)
	assert_that(Cards.can_unlock(s, &"orbital_strike")["reason"]).is_equal(&"permanently_destroyed")


# --- era evolution ---

func test_unlock_enters_at_current_era_tier() -> void:
	var s := _state()
	s.generation = 33   # modern, era 5
	s.tech = 100
	s.regions.append(&"livelihood")
	Cards.unlock(s, &"cavalry")
	var instance: Cards.CardInstance = s.deck[0]
	assert_int(instance.tier).is_equal(5)
	assert_that(Cards.form_name(instance.id, instance.tier)).is_equal("坦克營")


func test_era_evolution_keeps_roll_and_growth() -> void:
	var s := _state()
	var infantry := Cards.CardInstance.new(&"infantry", 1)
	infantry.grade = &"good"
	infantry.accuracy = 99.0
	Cards.award_medal(infantry, &"accuracy")
	s.deck.append(infantry)
	s.deck.append(Cards.CardInstance.new(&"war_song", 1))
	s.generation = 25   # industrial
	var report := Cards.on_era_transition(s)
	assert_int(infantry.tier).is_equal(4)
	assert_that(infantry.grade).is_equal(&"good")   # 就地演化全部保留
	assert_float(infantry.accuracy).is_equal_approx(99.0, 0.000001)
	assert_int(int(infantry.levels.get(&"accuracy", 0))).is_equal(1)
	assert_int((s.deck[1] as Cards.CardInstance).tier).is_equal(1)   # skills never evolve
	assert_array(report["evolved"]).contains_exactly([&"infantry"])
	assert_array(report["auto_disbanded"]).is_empty()


func test_era_transition_auto_disbands_form_end() -> void:
	# 時代演化總表: 聖戰士團 ends after 工業, 私掠傭兵 after 現代 — free auto-disband that
	# proceeds even below the deck minimum (deliberate, docs/decisions.md).
	var s := _state()
	s.population = 10
	s.deck.append(Cards.CardInstance.new(&"holy_warriors", 4))
	s.deck.append(Cards.CardInstance.new(&"privateers", 4))
	s.generation = 33   # modern
	var report := Cards.on_era_transition(s)
	assert_array(report["auto_disbanded"]).contains_exactly([&"holy_warriors"])
	assert_int(s.deck.size()).is_equal(1)
	assert_int((s.deck[0] as Cards.CardInstance).tier).is_equal(5)   # 網路駭客
	assert_int(s.treasury).is_equal(30)      # free — no disband fee
	assert_int(s.population).is_equal(10)    # mechanical: no recovery
	s.generation = 41   # information: privateers' forms end too
	var late := Cards.on_era_transition(s)
	assert_array(late["auto_disbanded"]).contains_exactly([&"privateers"])
	assert_int(s.deck.size()).is_equal(0)


# --- 戰後獎勵卡 ---

func test_reward_pool_by_era() -> void:
	var s := _state()
	assert_array(Cards.reward_pool(s)).contains_exactly_in_any_order([
		&"infantry", &"archers", &"cavalry", &"engineers",
		&"shield_wall", &"war_song", &"holes_dont_matter",
	])   # 防空飛彈 has no 部落 form: 有空軍才有防空 (ADR-0006)
	s.generation = 25   # industrial: mechanical roster is formed now
	var pool := Cards.reward_pool(s)
	assert_bool(pool.has(&"anti_air")).is_true()
	assert_bool(pool.has(&"elite_forces")).is_true()
	assert_bool(pool.has(&"artillery")).is_true()
	assert_bool(pool.has(&"bomber")).is_true()
	# 國策限定 and Legacy-granted cards never enter the pool.
	assert_bool(pool.has(&"holy_warriors")).is_false()
	assert_bool(pool.has(&"privateers")).is_false()
	assert_bool(pool.has(&"love_and_peace")).is_false()
	assert_bool(pool.has(&"orbital_strike")).is_false()


func test_reward_first_seen_free_duplicate_paid() -> void:
	var s := _state()
	s.generation = 9   # era 2, coeff 2
	var first := Cards.CardInstance.new(&"archers", 2)
	var accepted := Cards.accept_reward(s, first)
	assert_bool(bool(accepted["duplicate"])).is_false()
	assert_int(int(accepted["cost"])).is_equal(0)
	assert_int(s.treasury).is_equal(30)
	var second := Cards.CardInstance.new(&"archers", 2)
	var dup := Cards.accept_reward(s, second)
	assert_bool(bool(dup["duplicate"])).is_true()
	assert_int(int(dup["cost"])).is_equal(10)   # 5×係數2
	assert_int(s.treasury).is_equal(20)
	# 納入不開購買權: reward cards never grant purchase rights.
	assert_bool(s.unlocked_cards.has(&"archers")).is_false()


# --- stats & strength (unchanged rules) ---

func test_stats_scale_with_tier_coeff() -> void:
	var s := _state()
	var infantry := Cards.CardInstance.new(&"infantry", 4)   # industrial coeff 5
	assert_int(Cards.attack_of(infantry)).is_equal(5)        # 1×5
	assert_int(Cards.hp_of(infantry)).is_equal(10)           # 2×5
	assert_int(Cards.military_cost_of(s, infantry)).is_equal(10)   # 2×5


func test_skill_cost_flat_and_hundred_schools() -> void:
	var s := _state()
	var song := Cards.CardInstance.new(&"war_song", 1)
	assert_int(Cards.military_cost_of(s, song)).is_equal(3)
	s.policies.append(&"hundred_schools")
	assert_int(Cards.military_cost_of(s, song)).is_equal(2)
	var holes := Cards.CardInstance.new(&"holes_dont_matter", 1)
	assert_int(Cards.military_cost_of(s, holes)).is_equal(1)   # floor 1


func test_deck_strength() -> void:
	var s := _state()
	s.deck.append(Cards.CardInstance.new(&"infantry", 1))    # 1+2
	s.deck.append(Cards.CardInstance.new(&"war_song", 1))    # skill: 0
	s.deck.append(Cards.CardInstance.new(&"artillery", 3))   # (4+2)×3
	assert_int(Cards.deck_strength(s)).is_equal(21)


# --- W13 成長: lanes, XP, 老兵 ---

func test_lane_stat_routing() -> void:
	assert_that(Cards.lane_stat(&"infantry")).is_equal(&"speed")     # 近戰列 → 攻速
	assert_that(Cards.lane_stat(&"cavalry")).is_equal(&"speed")
	assert_that(Cards.lane_stat(&"elite_forces")).is_equal(&"speed")
	assert_that(Cards.lane_stat(&"archers")).is_equal(&"accuracy")   # 遠程列 → 命中率
	assert_that(Cards.lane_stat(&"artillery")).is_equal(&"accuracy")
	assert_that(Cards.lane_stat(&"bomber")).is_equal(&"accuracy")    # 空域 → 命中率
	assert_that(Cards.lane_stat(&"engineers")).is_equal(&"dodge")    # 工兵團 → 閃避率
	assert_that(Cards.lane_stat(&"shield_wall")).is_equal(&"")       # forts/skills take none
	assert_that(Cards.lane_stat(&"war_song")).is_equal(&"")


func test_grant_xp_fills_to_medal() -> void:
	var instance := Cards.CardInstance.new(&"archers", 1)
	for i: int in range(4):
		assert_bool(Cards.grant_xp(instance, &"accuracy")).is_false()
	assert_int(int(instance.xp[&"accuracy"])).is_equal(4)
	assert_int(instance.levels.size()).is_equal(0)
	assert_bool(Cards.grant_xp(instance, &"accuracy")).is_true()     # 5th fills (XP_TO_MEDAL)
	assert_int(int(instance.levels[&"accuracy"])).is_equal(1)
	assert_int(int(instance.xp[&"accuracy"])).is_equal(0)


func test_grant_xp_ignores_stats_the_card_lacks() -> void:
	var engineer := Cards.CardInstance.new(&"engineers", 1)
	assert_bool(Cards.grant_xp(engineer, &"accuracy")).is_false()    # 工兵團: dodge only
	assert_bool(Cards.grant_xp(engineer, &"speed")).is_false()
	assert_bool(engineer.xp.is_empty()).is_true()
	assert_bool(Cards.grant_xp(engineer, &"dodge")).is_false()       # accrues (threshold 4)
	assert_int(int(engineer.xp[&"dodge"])).is_equal(1)
	var fort := Cards.CardInstance.new(&"shield_wall", 1)
	assert_bool(Cards.grant_xp(fort, &"dodge")).is_false()           # not a unit: nothing
	assert_bool(fort.xp.is_empty()).is_true()


func test_veteran_floor_on_lane_stat_only() -> void:
	var s := GameState.new_run(5)
	var cavalry := Cards.CardInstance.new(&"cavalry", 1)
	cavalry.accuracy = 85.0
	cavalry.dodge = 20.0
	cavalry.speed = 1.2
	assert_float(Cards.speed_of(s, cavalry)).is_equal_approx(1.2, 0.0001)
	s.regions.append(&"military")
	assert_float(Cards.speed_of(s, cavalry)).is_equal_approx(1.3, 0.0001)     # lane stat +1 階
	assert_float(Cards.accuracy_of(s, cavalry)).is_equal_approx(85.0, 0.0001) # others untouched
	assert_float(Cards.dodge_of(s, cavalry)).is_equal_approx(20.0, 0.0001)
	Cards.award_medal(cavalry, &"speed")                             # additive with medals
	assert_float(Cards.speed_of(s, cavalry)).is_equal_approx(1.4, 0.0001)
	Cards.wipe_growth(cavalry)                                       # 常駐底線: survives death
	assert_float(Cards.speed_of(s, cavalry)).is_equal_approx(1.3, 0.0001)
	s.regions.erase(&"military")                                     # lost with the region
	assert_float(Cards.speed_of(s, cavalry)).is_equal_approx(1.2, 0.0001)


func test_veteran_respects_stat_caps() -> void:
	var s := GameState.new_run(5)
	s.regions.append(&"military")
	var archers := Cards.CardInstance.new(&"archers", 1)
	archers.accuracy = 99.0
	assert_float(Cards.accuracy_of(s, archers)).is_equal_approx(100.0, 0.0001)  # 99+3 clamps
	var engineer := Cards.CardInstance.new(&"engineers", 1)
	engineer.dodge = 49.5
	assert_float(Cards.dodge_of(s, engineer)).is_equal_approx(50.0, 0.0001)
