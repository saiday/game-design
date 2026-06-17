extends GdUnitTestSuite
## M2 Part-A: the hex tile's geometry is computed, not eyeballed. Verify the
## polygon is a regular hexagon — 6 vertices, all at the requested radius.
## The view node draws this; the math stays pure and headless-testable.

func test_regular_hexagon_has_six_vertices() -> void:
	var pts := HexTile.regular_hexagon(70.0)
	assert_int(pts.size()).is_equal(6)

func test_regular_hexagon_vertices_lie_on_radius() -> void:
	var radius := 70.0
	var pts := HexTile.regular_hexagon(radius)
	for p in pts:
		assert_float(p.length()).is_equal_approx(radius, 0.001)
