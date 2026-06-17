extends GdUnitTestSuite
## M0.4 — trivial Part A proof. Exists only to confirm gdUnit4 runs headless
## from the CLI and reports a result. Two real assertions so the run cannot be
## a "no tests found" false-green (companion doc §8 / guide §7).

func test_addition() -> void:
	assert_int(1 + 1).is_equal(2)

func test_string_identity() -> void:
	assert_str("godot").is_equal("godot")
