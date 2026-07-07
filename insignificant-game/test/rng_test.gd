class_name RngTest
extends GdUnitTestSuite


func test_same_seed_same_sequence() -> void:
	var a := SeededRng.new(42)
	var b := SeededRng.new(42)
	for i: int in range(20):
		assert_int(a.randi_range(&"battle", 0, 1000)).is_equal(b.randi_range(&"battle", 0, 1000))


func test_different_seeds_diverge() -> void:
	var a := SeededRng.new(1)
	var b := SeededRng.new(2)
	var same := true
	for i: int in range(10):
		if a.randi_range(&"map", 0, 100000) != b.randi_range(&"map", 0, 100000):
			same = false
	assert_bool(same).is_false()


func test_tracks_are_independent() -> void:
	# Consuming the map track must not shift the battle track.
	var a := SeededRng.new(7)
	var b := SeededRng.new(7)
	for i: int in range(50):
		a.randi_range(&"map", 0, 1000)
	for i: int in range(5):
		assert_int(a.randi_range(&"battle", 0, 1000)).is_equal(b.randi_range(&"battle", 0, 1000))


func test_randi_range_bounds() -> void:
	var rng := SeededRng.new(3)
	for i: int in range(100):
		var v := rng.randi_range(&"opportunity", 2, 5)
		assert_bool(v >= 2 and v <= 5).is_true()


func test_chance_extremes() -> void:
	var rng := SeededRng.new(9)
	assert_bool(rng.chance(&"rivals", 1.1)).is_true()
	assert_bool(rng.chance(&"rivals", 0.0)).is_false()


func test_pick_returns_member() -> void:
	var rng := SeededRng.new(11)
	var options: Array = [&"a", &"b", &"c"]
	for i: int in range(30):
		assert_bool(options.has(rng.pick(&"naming", options))).is_true()


func test_weighted_pick_deterministic_and_valid() -> void:
	var a := SeededRng.new(13)
	var b := SeededRng.new(13)
	var weights := {&"merchant": 40.0, &"refugee": 30.0, &"disaster": 30.0}
	for i: int in range(30):
		var got: Variant = a.weighted_pick(&"opportunity", weights)
		assert_bool(weights.has(got)).is_true()
		assert_that(got).is_equal(b.weighted_pick(&"opportunity", weights))


func test_weighted_pick_zero_weight_never_picked() -> void:
	var rng := SeededRng.new(17)
	var weights := {&"only": 10.0, &"never": 0.0}
	for i: int in range(50):
		assert_that(rng.weighted_pick(&"opportunity", weights)).is_equal(&"only")
