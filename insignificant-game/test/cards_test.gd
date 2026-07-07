class_name CardsTest
extends GdUnitTestSuite


func _state() -> GameState:
	return GameState.new_run(33)


func test_catalog_totals() -> void:
	assert_int(CardsData.CARDS.size()).is_equal(17)
	var by_class := {&"personnel": 0, &"mechanical": 0, &"fortification": 0, &"skill": 0}
	for card_id: StringName in CardsData.CARDS.keys():
		var cls: StringName = CardsData.CARDS[card_id]["class"]
		by_class[cls] = int(by_class[cls]) + 1
	assert_int(int(by_class[&"personnel"])).is_equal(4)
	assert_int(int(by_class[&"mechanical"])).is_equal(5)
	assert_int(int(by_class[&"fortification"])).is_equal(3)
	assert_int(int(by_class[&"skill"])).is_equal(5)


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


func test_can_unlock_min_era() -> void:
	var s := _state()
	s.tech = 100
	s.buildings[&"barracks"] = 1
	assert_that(Cards.can_unlock(s, &"bomber")["reason"]).is_equal(&"no_form_this_era")
	s.generation = 25   # industrial
	assert_bool(bool(Cards.can_unlock(s, &"bomber")["ok"])).is_true()


func test_unlock_pays_and_adds_to_deck() -> void:
	var s := _state()
	s.tech = 10
	s.regions.append(&"livelihood")
	var r := Cards.unlock(s, &"infantry")
	assert_bool(bool(r["ok"])).is_true()
	assert_int(int(r["cost"])).is_equal(10)
	assert_int(s.treasury).is_equal(20)
	assert_int(s.deck.size()).is_equal(1)
	assert_that(Cards.unlock(s, &"infantry")["reason"]).is_equal(&"already_unlocked")


func test_unlock_enters_at_current_era_tier() -> void:
	var s := _state()
	s.generation = 33   # modern, era 5
	s.tech = 100
	s.regions.append(&"livelihood")
	Cards.unlock(s, &"cavalry")
	var instance: Cards.CardInstance = s.deck[0]
	assert_int(instance.tier).is_equal(5)
	assert_that(Cards.form_name(instance.id, instance.tier)).is_equal("坦克營")


func test_starting_deck() -> void:
	var s := _state()
	Cards.starting_deck(s)
	assert_int(s.deck.size()).is_equal(5)
	assert_bool(s.unlocked_cards.has(&"infantry")).is_true()


func test_delete_card_cost_refund_and_minimum() -> void:
	var s := _state()
	Cards.starting_deck(s)
	assert_that(Cards.delete_card(s, 0)["reason"]).is_equal(&"deck_minimum")
	s.deck.append(Cards.CardInstance.new(&"infantry", 1))
	s.population = 12
	var r := Cards.delete_card(s, 0)
	assert_bool(bool(r["ok"])).is_true()
	assert_int(s.treasury).is_equal(22)    # 30 − 8×1
	assert_int(s.population).is_equal(14)  # personnel +2
	assert_int(s.deck.size()).is_equal(5)


func test_disband_recovery_by_class() -> void:
	var s := _state()
	Cards.starting_deck(s)
	s.deck.append(Cards.CardInstance.new(&"elite_forces", 2))
	s.population = 12
	var r := Cards.disband(s, 5)   # mechanical: no recovery
	assert_int(int(r["population_recovered"])).is_equal(0)
	assert_int(s.population).is_equal(12)
	assert_int(s.treasury).is_equal(30)   # disband is free


func test_era_evolution_in_place() -> void:
	var s := _state()
	s.deck.append(Cards.CardInstance.new(&"infantry", 1))
	s.deck.append(Cards.CardInstance.new(&"war_song", 1))
	s.generation = 25   # industrial
	Cards.on_era_transition(s)
	assert_int((s.deck[0] as Cards.CardInstance).tier).is_equal(4)
	assert_int((s.deck[1] as Cards.CardInstance).tier).is_equal(1)   # skills never evolve


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


func test_destroy_permanently_blocks_reunlock() -> void:
	var s := _state()
	s.generation = 41
	s.tech = 1000
	s.policies.append(&"space_station")
	Cards.unlock(s, &"orbital_strike")
	Cards.destroy_permanently(s, &"orbital_strike")
	assert_int(s.deck.size()).is_equal(0)
	assert_that(Cards.can_unlock(s, &"orbital_strike")["reason"]).is_equal(&"permanently_destroyed")


func test_deck_strength() -> void:
	var s := _state()
	s.deck.append(Cards.CardInstance.new(&"infantry", 1))    # 1+2
	s.deck.append(Cards.CardInstance.new(&"war_song", 1))    # skill: 0
	s.deck.append(Cards.CardInstance.new(&"artillery", 2))   # (4+2)×2
	assert_int(Cards.deck_strength(s)).is_equal(15)
