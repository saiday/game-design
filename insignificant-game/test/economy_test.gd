class_name EconomyTest
extends GdUnitTestSuite


func _state() -> GameState:
	return GameState.new_run(7)


func test_tax_base_and_bureaucracy() -> void:
	var s := _state()
	s.population = 12
	assert_int(Economy.tax_income(s)).is_equal(12)
	s.policies.append(&"bureaucracy")
	assert_int(Economy.tax_income(s)).is_equal(13)   # floor(12×1.1)


func test_capital_gains_requires_securities_tier() -> void:
	var s := _state()
	s.treasury = 1000
	assert_int(Economy.capital_gains(s, 100)).is_equal(0)
	s.buildings[&"bank"] = 5
	assert_int(Economy.capital_gains(s, 100)).is_equal(0)
	s.buildings[&"bank"] = 6
	assert_int(Economy.capital_gains(s, 100)).is_equal(20)   # 2% of 1000, under cap 50


func test_capital_gains_capped_by_half_tax() -> void:
	var s := _state()
	s.treasury = 10000
	s.buildings[&"bank"] = 6
	assert_int(Economy.capital_gains(s, 12)).is_equal(6)     # 200 capped at 12/2
	s.treasury = -50
	assert_int(Economy.capital_gains(s, 12)).is_equal(0)


func test_interest_ladder() -> void:
	var s := _state()
	s.treasury = -100
	assert_int(Economy.interest_due(s)).is_equal(10)          # base 10%
	s.buildings[&"bank"] = 3
	assert_int(Economy.interest_due(s)).is_equal(7)           # 私有銀行 7%
	s.buildings[&"bank"] = 6
	assert_int(Economy.interest_due(s)).is_equal(5)           # ladder floors at 5%
	s.buildings[&"debt_office"] = 3
	assert_int(Economy.interest_due(s)).is_equal(3)           # halved 2.5% → ceil(2.5)
	s.treasury = 100
	assert_int(Economy.interest_due(s)).is_equal(0)


func test_settle_tax_flows_into_treasury() -> void:
	var s := _state()   # pop 12, treasury 30
	var report := Economy.settle(s)
	assert_int(int(report["tax"])).is_equal(12)
	assert_int(s.treasury).is_equal(42)


func test_settle_applies_production() -> void:
	var s := _state()
	s.regions.append(&"finance")
	s.regions.append(&"culture")
	s.buildings[&"medical"] = 1
	s.happiness = 50
	Economy.settle(s)
	assert_int(s.happiness).is_equal(52)     # medical +2
	assert_int(s.culture).is_equal(1)        # culture region
	assert_int(s.treasury).is_equal(30 + 2 + 12)   # finance income + tax


func test_settle_debt_happiness_penalty() -> void:
	var s := _state()
	s.treasury = -100
	s.happiness = 70
	Economy.settle(s)
	# -100 +12 tax -9 interest(ceil 8.8... base10% on -88? order: tax first then interest on -88 → 9) = -97
	assert_bool(s.treasury < 0).is_true()
	assert_int(s.happiness).is_equal(65)


func test_settle_debt_office_switches_mode() -> void:
	var s := _state()
	s.treasury = -500
	s.happiness = 70
	s.buildings[&"debt_office"] = 3
	Economy.settle(s)
	assert_bool(s.debt_unrest_mode).is_true()
	assert_int(s.happiness).is_equal(70)     # no happiness hit in unrest mode


func test_settle_population_respects_cap() -> void:
	var s := _state()
	s.population = 20   # base cap 20, no livelihood
	s.regions.append(&"livelihood")   # cap 30 now… but housing produces the growth
	s.buildings[&"food"] = 1          # +1 pop
	Economy.settle(s)
	assert_int(s.population).is_equal(21)
	s.population = 30
	Economy.settle(s)
	assert_int(s.population).is_equal(30)    # capped at 20+10


func test_sell_treasure() -> void:
	var s := _state()
	assert_bool(bool(Economy.sell_treasure(s)["sold"])).is_false()
	s.flags[&"treasures"] = 2
	s.generation = 9   # coeff 2
	var r := Economy.sell_treasure(s)
	assert_bool(bool(r["sold"])).is_true()
	assert_int(int(r["amount"])).is_equal(60)
	assert_int(int(s.flags[&"treasures"])).is_equal(1)
