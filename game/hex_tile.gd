class_name HexTile
extends Polygon2D
## A regular hexagon tile (view node). The vertex math is a pure static fn so
## it's unit-testable headless; the node just draws the resulting polygon.

## The 6 vertices of a regular hexagon of `radius`, centered on the origin.
## Pure — depends only on its argument, holds no node state.
static func regular_hexagon(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var angle := PI / 3.0 * float(i)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts
