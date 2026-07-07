# M0 smoke test: proves gdUnit4 discovers and runs tests inside insignificant-game/.
class_name SmokeTest
extends GdUnitTestSuite


func test_truth() -> void:
	assert_bool(true).is_true()


func test_arithmetic() -> void:
	assert_int(2 + 3).is_equal(5)
