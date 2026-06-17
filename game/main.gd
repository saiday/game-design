extends Node2D
## M2 — Part B visual slice + capture/ASSERT (the screenshot layer of the loop).
## Builds the one-card / one-hex-tile scene bound to a GameState, renders one
## real GPU frame, saves a PNG, and prints ASSERT PASS/FAIL judged from pixels.
## Run (NOT --headless; needs the real GPU):
##   /Applications/Godot.app/Contents/MacOS/Godot --path .
## Judge from the artifact: captures/m2_slice.png + the ASSERT lines in stdout.

const VIEW_W := 640
const VIEW_H := 360
const OUT_DIR := "res://captures"
const OUT_FILE := "m2_slice.png"
const WATCHDOG_SECS := 10.0

const BG_COLOR := Color(0.10, 0.10, 0.15)
const HEX_COLOR := Color(0.20, 0.55, 0.55)
const CARD_COLOR := Color(0.90, 0.80, 0.20)

const HEX_CENTER := Vector2(190, 190)
const HEX_RADIUS := 70.0
const CARD_POS := Vector2(400, 110)
const CARD_SIZE := Vector2(110, 150)

var _card: ColorRect

func _ready() -> void:
	# Model: start state, play the one card, show the result — ties M1 logic to the view.
	var before := GameState.new(3, 0)
	var card := Card.new(1, 5)
	var after := Rules.play_card(before, card)

	_build_scene(before, after, card)

	var t := get_tree().create_timer(WATCHDOG_SECS)
	t.timeout.connect(func() -> void:
		print("ASSERT FAIL: capture watchdog fired after %ss (no frame drawn)" % WATCHDOG_SECS)
		get_tree().quit(3))

	_capture_when_drawn()

func _build_scene(before: GameState, after: GameState, card: Card) -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.position = Vector2.ZERO
	bg.size = Vector2(VIEW_W, VIEW_H)
	add_child(bg)

	var hex := HexTile.new()
	hex.polygon = HexTile.regular_hexagon(HEX_RADIUS)
	hex.color = HEX_COLOR
	hex.position = HEX_CENTER
	add_child(hex)

	_card = ColorRect.new()
	_card.color = CARD_COLOR
	_card.position = CARD_POS
	_card.size = CARD_SIZE
	add_child(_card)

	var card_label := Label.new()
	card_label.text = "Cost %d\n+%dg" % [card.cost, card.reward]
	card_label.position = Vector2(10, 10)
	card_label.add_theme_color_override("font_color", Color.BLACK)
	_card.add_child(card_label)

	var hud := Label.new()
	hud.text = "Energy %d -> %d   Gold %d -> %d" % [before.energy, after.energy, before.gold, after.gold]
	hud.position = Vector2(12, 8)
	add_child(hud)

func _capture_when_drawn() -> void:
	# Wait until the GPU has actually drawn a frame before grabbing it.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_do_capture()

func _do_capture() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()

	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var abs_path := abs_dir.path_join(OUT_FILE)
	var save_err := img.save_png(abs_path)
	print("CAPTURE: size=%dx%d save_err=%d path=%s" % [w, h, save_err, abs_path])

	var ok := true
	if save_err != OK:
		print("ASSERT FAIL: save_png returned error %d" % save_err)
		ok = false

	# 1) Card fully on-screen (catches off-screen / clipping).
	var view_rect := Rect2(0, 0, w, h)
	var card_rect := _card.get_global_rect()
	if not view_rect.encloses(card_rect):
		print("ASSERT FAIL: card rect %s not inside viewport %s" % [card_rect, view_rect])
		ok = false
	else:
		print("ASSERT ok: card rect %s inside viewport %s" % [card_rect, view_rect])

	# 2) Card visible on top at its center (catches behind-tile / z-index).
	var card_center := card_rect.position + card_rect.size * 0.5
	if not _pixel_is(img, card_center, CARD_COLOR, [BG_COLOR, HEX_COLOR]):
		print("ASSERT FAIL: card center %s is not the card color (hidden?)" % card_center)
		ok = false
	else:
		print("ASSERT ok: card center shows card color")

	# 3) Hex tile actually drew (catches missing tile).
	if not _pixel_is(img, HEX_CENTER, HEX_COLOR, [BG_COLOR, CARD_COLOR]):
		print("ASSERT FAIL: hex center %s is not the hex color (tile missing?)" % HEX_CENTER)
		ok = false
	else:
		print("ASSERT ok: hex center shows hex color")

	if ok:
		print("ASSERT PASS: M2 slice rendered — card on-screen & on top, hex tile drawn")
	get_tree().quit(0 if ok else 1)

## True if the pixel at `at` is closer to `want` than to every color in `others`.
## Gamma-tolerant: classifies by nearest known color rather than exact match.
func _pixel_is(img: Image, at: Vector2, want: Color, others: Array) -> bool:
	var x := clampi(int(at.x), 0, img.get_width() - 1)
	var y := clampi(int(at.y), 0, img.get_height() - 1)
	var c := img.get_pixel(x, y)
	var d_want := _color_dist(c, want)
	for o in others:
		if _color_dist(c, o) <= d_want:
			return false
	return true

func _color_dist(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return dr * dr + dg * dg + db * db
