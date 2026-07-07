class_name EraTest
extends GdUnitTestSuite
# Boundaries from design/時代與回合.md: 部落1–8 古典9–16 信仰17–24 工業25–32 現代33–40 資訊41–50,
# coefficients ×1/2/3/5/8/12, BP caps 2/3/3/4/5/5, world wars at 15/35.


func test_era_boundaries() -> void:
	assert_that(Era.of(1)).is_equal(&"tribal")
	assert_that(Era.of(8)).is_equal(&"tribal")
	assert_that(Era.of(9)).is_equal(&"classical")
	assert_that(Era.of(16)).is_equal(&"classical")
	assert_that(Era.of(17)).is_equal(&"faith")
	assert_that(Era.of(24)).is_equal(&"faith")
	assert_that(Era.of(25)).is_equal(&"industrial")
	assert_that(Era.of(32)).is_equal(&"industrial")
	assert_that(Era.of(33)).is_equal(&"modern")
	assert_that(Era.of(40)).is_equal(&"modern")
	assert_that(Era.of(41)).is_equal(&"information")
	assert_that(Era.of(50)).is_equal(&"information")


func test_era_index() -> void:
	assert_int(Era.index(1)).is_equal(1)
	assert_int(Era.index(9)).is_equal(2)
	assert_int(Era.index(17)).is_equal(3)
	assert_int(Era.index(25)).is_equal(4)
	assert_int(Era.index(33)).is_equal(5)
	assert_int(Era.index(50)).is_equal(6)


func test_cost_coefficients() -> void:
	assert_int(Era.coeff(1)).is_equal(1)
	assert_int(Era.coeff(9)).is_equal(2)
	assert_int(Era.coeff(17)).is_equal(3)
	assert_int(Era.coeff(25)).is_equal(5)
	assert_int(Era.coeff(33)).is_equal(8)
	assert_int(Era.coeff(41)).is_equal(12)


func test_bp_caps() -> void:
	assert_int(Era.bp_cap(1)).is_equal(2)
	assert_int(Era.bp_cap(9)).is_equal(3)
	assert_int(Era.bp_cap(17)).is_equal(3)
	assert_int(Era.bp_cap(25)).is_equal(4)
	assert_int(Era.bp_cap(33)).is_equal(5)
	assert_int(Era.bp_cap(41)).is_equal(5)


func test_tech_gate_base() -> void:
	assert_int(Era.tech_gate_base(1)).is_equal(10)
	assert_int(Era.tech_gate_base(6)).is_equal(60)


func test_world_war_generations() -> void:
	assert_bool(Era.is_world_war(15)).is_true()
	assert_bool(Era.is_world_war(35)).is_true()
	assert_bool(Era.is_world_war(14)).is_false()
	assert_bool(Era.is_world_war(50)).is_false()
