extends Node2D
## Embedded GDScript capture helper — Part B of the self-correction loop
## (companion doc §5). This M0 version builds a trivial, deterministic, clearly
## non-blank scene IN CODE, renders one real GPU frame, saves a PNG to disk, and
## prints ASSERT PASS / ASSERT FAIL to stdout. It is the Part-B smoke test: it
## proves this machine can render + screenshot at all. The real M2 scene will
## replace the in-code visuals; the capture/await/assert/quit machinery stays.
##
## Run (NOT --headless; we need the real GPU):
##   /Applications/Godot.app/Contents/MacOS/Godot --path .
## Judge from the artifact: the PNG on disk + the ASSERT lines in stdout.

const OUT_DIR := "res://captures"
const OUT_FILE := "m0_smoke.png"
const WATCHDOG_SECS := 10.0

func _ready() -> void:
	# Build a deterministic, clearly non-blank frame: dark bg + bright card rect.
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.10, 0.15)
	bg.position = Vector2.ZERO
	bg.size = Vector2(640, 360)
	add_child(bg)

	var card := ColorRect.new()
	card.color = Color(0.90, 0.80, 0.20)
	card.position = Vector2(260, 90)
	card.size = Vector2(120, 180)
	add_child(card)

	# Watchdog: never hang the loop if rendering never initializes.
	var t := get_tree().create_timer(WATCHDOG_SECS)
	t.timeout.connect(func() -> void:
		print("ASSERT FAIL: capture watchdog fired after %ss (no frame drawn)" % WATCHDOG_SECS)
		get_tree().quit(3))

	_capture_when_drawn()

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

	# Renderer-agnostic non-blank check: sample several points; a real render
	# yields distinct, non-black pixels. A blank/black frame = render failed.
	var samples: Array[Color] = [
		img.get_pixel(20, 20),     # bg corner
		img.get_pixel(320, 180),   # card center
		img.get_pixel(610, 340),   # bg far corner
	]
	var distinct := {}
	var all_black := true
	for c in samples:
		distinct[c.to_html(false)] = true
		if c.r > 0.02 or c.g > 0.02 or c.b > 0.02:
			all_black = false

	if distinct.size() < 2:
		print("ASSERT FAIL: frame is a single uniform color (likely blank / no render)")
		ok = false
	elif all_black:
		print("ASSERT FAIL: frame is entirely black (render produced nothing)")
		ok = false

	if ok:
		print("ASSERT PASS: non-blank %dx%d frame captured (%d distinct sampled colors)" % [w, h, distinct.size()])

	get_tree().quit(0 if ok else 1)
