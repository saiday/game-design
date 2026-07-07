class_name MapNodesTest
extends GdUnitTestSuite


func _state() -> GameState:
	return GameState.new_run(77)


func test_generate_deterministic() -> void:
	var a := _state()
	var b := _state()
	var nodes_a := MapNodes.generate(a)
	var nodes_b := MapNodes.generate(b)
	assert_int(nodes_a.size()).is_equal(nodes_b.size())
	for i: int in range(nodes_a.size()):
		assert_that(nodes_a[i]["content"]).is_equal(nodes_b[i]["content"])


func test_generate_count_bounds() -> void:
	var s := _state()
	for i: int in range(50):
		var n := MapNodes.generate(s).size()
		assert_bool(n >= 1 and n <= 3).is_true()


func test_great_voyage_floor_two() -> void:
	var s := _state()
	s.policies.append(&"great_voyage")
	for i: int in range(50):
		assert_bool(MapNodes.generate(s).size() >= 2).is_true()


func test_known_nodes_are_revealed_battles() -> void:
	var s := _state()
	for i: int in range(30):
		for node: Dictionary in MapNodes.generate(s):
			if node["kind"] == &"known":
				assert_that(node["content"]).is_equal(&"battle")
				assert_that(node["battle_type"]).is_equal(&"tax_battle")
				assert_bool(bool(node["face_shown"])).is_true()


func test_world_map_reveals_faces() -> void:
	var s := _state()
	s.policies.append(&"world_map")
	for i: int in range(30):
		for node: Dictionary in MapNodes.generate(s):
			assert_bool(bool(node["face_shown"])).is_true()


func test_hidden_battle_surprise_and_intel() -> void:
	var s := _state()
	var found_surprise := false
	for i: int in range(200):
		for node: Dictionary in MapNodes.generate(s):
			if node["battle_type"] == &"hidden_battle":
				found_surprise = found_surprise or bool(node["surprise"])
	assert_bool(found_surprise).is_true()
	var intel := _state()   # same seed, same rolls — now with the policy
	intel.policies.append(&"intelligence_agency")
	for i: int in range(200):
		for node: Dictionary in MapNodes.generate(intel):
			if node["battle_type"] == &"hidden_battle":
				assert_bool(bool(node["surprise"])).is_false()


func test_inject_battle_node() -> void:
	var nodes: Array[Dictionary] = []
	MapNodes.inject_battle_node(nodes, &"civil_war", &"iron_tribe")
	assert_int(nodes.size()).is_equal(1)
	assert_that(nodes[0]["battle_type"]).is_equal(&"civil_war")
	assert_that(nodes[0]["rival_id"]).is_equal(&"iron_tribe")


func test_skip_cost_scales() -> void:
	var s := _state()
	assert_int(MapNodes.skip_cost(s)).is_equal(10)
	s.generation = 33   # coeff 8
	assert_int(MapNodes.skip_cost(s)).is_equal(80)
	s.treasury = 30
	MapNodes.skip_node(s)
	assert_int(s.treasury).is_equal(-50)


func test_opportunity_weights_baseline() -> void:
	var s := _state()
	s.happiness = 50
	var w := MapNodes.opportunity_weights(s)
	assert_float(float(w[&"merchant"])).is_equal_approx(40.0, 0.01)
	assert_float(float(w[&"refugee"])).is_equal_approx(30.0, 0.01)
	assert_float(float(w[&"disaster"])).is_equal_approx(30.0, 0.01)
	assert_float(float(w[&"national_treasure"])).is_equal_approx(0.0, 0.01)


func test_opportunity_weights_modifiers() -> void:
	var s := _state()
	s.happiness = 70   # good draw: merchant 60, disaster 10
	s.policies.append(&"secularization")   # disaster −10 → 0
	s.policies.append(&"moon_race")        # treasure +20
	s.buildings[&"astronomy"] = 1          # treasure +10
	var w := MapNodes.opportunity_weights(s)
	assert_float(float(w[&"merchant"])).is_equal_approx(60.0, 0.01)
	assert_float(float(w[&"disaster"])).is_equal_approx(0.0, 0.01)
	assert_float(float(w[&"national_treasure"])).is_equal_approx(30.0, 0.01)


func test_roll_opportunity_skips_zero_weights() -> void:
	var s := _state()
	s.happiness = 90
	s.policies.append(&"secularization")   # disaster weight 0
	for i: int in range(100):
		assert_that(MapNodes.roll_opportunity(s)).is_not_equal(&"disaster")


func test_resolve_merchant_money() -> void:
	var s := _state()
	s.generation = 9   # coeff 2
	var r := MapNodes.resolve_opportunity(s, &"merchant", &"take_money")
	assert_int(int(r["money"])).is_equal(60)
	assert_int(s.treasury).is_equal(90)


func test_resolve_refugee_accept() -> void:
	var s := _state()
	s.happiness = 70
	var r := MapNodes.resolve_opportunity(s, &"refugee", &"accept")
	assert_int(int(r["population"])).is_equal(3)
	assert_int(s.population).is_equal(15)
	assert_int(s.happiness).is_equal(67)


func test_resolve_disaster_paths() -> void:
	var endure := _state()
	MapNodes.resolve_opportunity(endure, &"disaster", &"endure")
	assert_int(endure.treasury).is_equal(5)    # 30 − 25×1
	var mitigate := _state()
	var r := MapNodes.resolve_opportunity(mitigate, &"disaster", &"mitigate")
	assert_int(int(r["fee"])).is_equal(15)
	assert_int(mitigate.treasury).is_equal(5)  # 30 − 10 − 15 (v1 wash in money terms)


func test_resolve_treasure_feeds_economy_flag() -> void:
	var s := _state()
	MapNodes.resolve_opportunity(s, &"national_treasure", &"accept")
	assert_int(int(s.flags[&"treasures"])).is_equal(1)
	assert_int(s.culture).is_equal(5)
	assert_bool(bool(Economy.sell_treasure(s)["sold"])).is_true()
