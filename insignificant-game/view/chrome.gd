class_name Chrome
extends RefCounted
# Runtime-composed approved-art chrome (assets/pipeline/style-bible.md §9): styleboxes, glyph-on-
# plate badges, the card frame and the 3-slice divider, all built from the frozen templates in
# core/data/asset_paths.gd and NEVER baked together offline. Three scenes share one instance so
# they share one texture cache — every scaled texture and composited plate is built once.
#
# This holds no game state and asks core no questions: it turns approved ids into Controls.
# View-layer only (it loads textures, which core is forbidden to do).

const CHROME_SCALE: float = 0.5   # frozen templates render at half source scale (style bible §8)
const INK: Color = Color(0.20, 0.13, 0.08)          # body text on parchment chrome
const INK_ACCENT: Color = Color(0.55, 0.16, 0.10)   # accent text on parchment chrome
const BUTTON_INK: Color = Color(0.16, 0.11, 0.07)

var _cache: Dictionary = {}


func theme() -> Theme:
	var t := Theme.new()
	t.default_font = load(AssetPaths.FONT_REGULAR) as FontFile
	t.default_font_size = 18
	return t


func bold_font() -> FontFile:
	return load(AssetPaths.FONT_BOLD) as FontFile


# --- textures ---

func texture(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) as Texture2D
	return _cache[path]


func scaled_texture(path: String, scale: float) -> ImageTexture:
	var key := "%s@%f" % [path, scale]
	if not _cache.has(key):
		var img := image(path)
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale),
			Image.INTERPOLATE_LANCZOS)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


func image(path: String) -> Image:
	var img: Image = (load(path) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	return img


func plate_icon(icon_path: String, size: int) -> ImageTexture:
	# glyph composited into the frozen plate's disc rect at runtime (style bible §9)
	var key := "plate:%s@%d" % [icon_path, size]
	if _cache.has(key):
		return _cache[key]
	var plate := image(String(AssetPaths.UI_ICON_PLATE["path"]))
	var glyph := image(icon_path)
	var disc: Rect2i = AssetPaths.UI_ICON_PLATE["disc"]
	var box := Vector2(disc.size) * float(AssetPaths.UI_ICON_PLATE["glyph_fill"])
	var glyph_scale: float = minf(box.x / glyph.get_width(), box.y / glyph.get_height())
	glyph.resize(int(glyph.get_width() * glyph_scale), int(glyph.get_height() * glyph_scale),
		Image.INTERPOLATE_LANCZOS)
	var at := disc.position + (disc.size - Vector2i(glyph.get_width(), glyph.get_height())) / 2
	plate.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), at)
	plate.resize(int(round(float(size) * plate.get_width() / plate.get_height())), size,
		Image.INTERPOLATE_LANCZOS)
	_cache[key] = ImageTexture.create_from_image(plate)
	return _cache[key]


# --- controls ---

func stylebox(tpl: Dictionary, modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = scaled_texture(String(tpl["path"]), CHROME_SCALE)
	var margins: Dictionary = tpl["margins"]
	style.texture_margin_left = float(margins["left"]) * CHROME_SCALE
	style.texture_margin_top = float(margins["top"]) * CHROME_SCALE
	style.texture_margin_right = float(margins["right"]) * CHROME_SCALE
	style.texture_margin_bottom = float(margins["bottom"]) * CHROME_SCALE
	style.content_margin_left = style.texture_margin_left * 0.8
	style.content_margin_top = style.texture_margin_top * 0.8
	style.content_margin_right = style.texture_margin_right * 0.8
	style.content_margin_bottom = style.texture_margin_bottom * 0.8
	style.modulate_color = modulate_color
	return style


func panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", stylebox(AssetPaths.UI_PANEL))
	return p


func divider() -> NinePatchRect:
	var rule := NinePatchRect.new()
	rule.texture = texture(String(AssetPaths.UI_DIVIDER["path"]))
	var margins: Dictionary = AssetPaths.UI_DIVIDER["margins"]
	rule.patch_margin_left = int(margins["left"])
	rule.patch_margin_right = int(margins["right"])
	rule.custom_minimum_size = Vector2(0, (AssetPaths.UI_DIVIDER["size"] as Vector2i).y)
	return rule


func button(text: String, handler: Callable, icon_id: StringName = &"") -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal", stylebox(AssetPaths.UI_BUTTON))
	b.add_theme_stylebox_override("hover", stylebox(AssetPaths.UI_BUTTON, Color(1.08, 1.08, 1.02)))
	b.add_theme_stylebox_override("pressed", stylebox(AssetPaths.UI_BUTTON, Color(0.78, 0.78, 0.82)))
	b.add_theme_stylebox_override("focus", stylebox(AssetPaths.UI_BUTTON, Color(1.20, 1.14, 0.86)))
	b.add_theme_stylebox_override("disabled", stylebox(AssetPaths.UI_BUTTON, Color(0.72, 0.70, 0.68)))
	b.add_theme_color_override("font_color", BUTTON_INK)
	b.add_theme_color_override("font_hover_color", Color(0.10, 0.06, 0.03))
	b.add_theme_color_override("font_pressed_color", BUTTON_INK)
	b.add_theme_color_override("font_focus_color", BUTTON_INK)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.40, 0.36))
	if icon_id != &"":
		b.icon = plate_icon(AssetPaths.icon(icon_id), 44)
		b.add_theme_constant_override("h_separation", 10)
	if handler.is_valid():
		b.pressed.connect(handler)
	return b


func card_widget() -> Dictionary:
	# Live card composition (style bible §9): illustration UNDER the frame's transparent window,
	# Label text OVER the parchment text panel — three layers, composed here, never baked together.
	# Returns the three handles the caller drives: {"root", "art", "text"}.
	var frame_size := Vector2(AssetPaths.UI_CARD_FRAME["size"] as Vector2i) * CHROME_SCALE
	var root := Control.new()
	root.custom_minimum_size = frame_size
	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var window: Rect2i = AssetPaths.UI_CARD_FRAME["window"]
	var art := TextureRect.new()
	art.position = Vector2(window.position) * CHROME_SCALE
	art.size = Vector2(window.size) * CHROME_SCALE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.clip_contents = true
	root.add_child(art)
	var frame := TextureRect.new()
	frame.texture = scaled_texture(String(AssetPaths.UI_CARD_FRAME["path"]), CHROME_SCALE)
	frame.size = frame_size
	root.add_child(frame)
	var panel_rect: Rect2i = AssetPaths.UI_CARD_FRAME["text_panel"]
	var text := Label.new()
	text.position = Vector2(panel_rect.position) * CHROME_SCALE + Vector2(10, 8)
	text.size = Vector2(panel_rect.size) * CHROME_SCALE - Vector2(20, 16)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", INK)
	text.add_theme_font_size_override("font_size", 17)
	root.add_child(text)
	return {"root": root, "art": art, "text": text}


func ink_label(text: String, size: int, accent: bool = false) -> Label:
	# labels living INSIDE parchment chrome read in ink, not the on-dark default white
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK_ACCENT if accent else INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
