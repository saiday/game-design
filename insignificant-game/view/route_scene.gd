class_name RouteScene
extends Control
# 選路＝迷霧地圖 (design/地圖與機會.md §場景呈現, style bible §11): a scene with its OWN backdrop,
# not a menu floating over the city. The map is the civilization's NEAR region — the same plate every
# generation, because 50 代 all happen in this one hinterland; the map never extends, only what stands
# on it changes.
#
# **迷霧是畫面語言，不只是規則**: an unknown node is visibly THERE and unreadable — the marker shows,
# the face does not. The 世界地圖 國策 upgrades the fog rather than lifting it, drawing the 戰鬥面／
# 機會面 on the node itself (core decides that in `face_shown`; this scene only draws it).
#
# Where the nodes stand is the VIEW's, seeded off the run so a generation always looks the same, and
# the core never gains a coordinate — the same division of labour ADR-0010 set for battlefield scatter.

signal node_chosen(index: int)
signal skip_chosen

const MARKER_ICON: int = 96
const HALO_SCALE: float = 1.7
const BAND_TOP: float = 0.30       # the strip of map the nodes may land in, as a fraction of height
const BAND_BOTTOM: float = 0.74
const JITTER_X: float = 0.055      # how far a node may drift off its even spacing
const HALO_TINT: Color = Color(0.78, 0.83, 0.92, 0.50)

var _chrome: Chrome
var _backdrop: TextureRect
var _markers: Control
var _skip: Button
var _caption: Label
var _buttons: Array[Button] = []
var _fogged: int = 0


func setup(chrome: Chrome) -> void:
	_chrome = chrome
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.texture = _chrome.texture(AssetPaths.background(&"route_map"))
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_markers = Control.new()
	_markers.set_anchors_preset(Control.PRESET_FULL_RECT)
	_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_markers)
	# 付錢略過是地圖上的常駐出口 (地圖與機會.md): an exit from the map, standing in a fixed corner
	# rather than appearing in a list of nodes — it is not one of the places you can go.
	_skip = _chrome.button("", func() -> void: skip_chosen.emit(), &"map_skip")
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.offset_left = -420.0
	_skip.offset_top = -128.0
	_skip.offset_right = -40.0
	_skip.offset_bottom = -40.0
	add_child(_skip)
	_caption = _chrome.ink_label("", 20)
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_caption.offset_left = 48.0
	_caption.offset_top = -110.0
	_caption.offset_right = 900.0
	_caption.offset_bottom = -40.0
	_caption.add_theme_color_override("font_color", Color(0.97, 0.95, 0.90))
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_color_override("font_outline_color", Color(0.10, 0.09, 0.12, 0.95))
	add_child(_caption)


func refresh(state: GameState, nodes: Array[Dictionary]) -> void:
	for child: Node in _markers.get_children():
		_markers.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_fogged = 0
	# Seeded off the run and the generation, on a view-local RNG: touching state.rng would make
	# LOOKING at the map change the run.
	var placer := RandomNumberGenerator.new()
	placer.seed = hash("route:%d:%d" % [state.run_seed, state.generation])
	for i: int in range(nodes.size()):
		var spot := Vector2(
			float(i + 1) / float(nodes.size() + 1) + placer.randf_range(-JITTER_X, JITTER_X),
			placer.randf_range(BAND_TOP, BAND_BOTTOM))
		_place_marker(nodes[i], i, spot)
	_skip.text = "付錢略過（%d 錢）" % MapNodes.skip_cost(state)
	_caption.text = "第 %d 代｜本代 %d 個節點。迷霧下的節點看得見、看不透。" % [
		state.generation, nodes.size()]
	focus_first()


func focus_first() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus()
	else:
		_skip.grab_focus()


func marker_count() -> int:
	return _buttons.size()


func fogged_count() -> int:
	return _fogged


func press_node(index: int) -> void:
	_buttons[index].pressed.emit()


func press_skip() -> void:
	_skip.pressed.emit()


func markers_on_map() -> bool:
	# Every marker has to be inside the scene, or a node the player cannot reach was generated.
	var rect := get_global_rect()
	for button: Button in _buttons:
		if not rect.encloses(button.get_global_rect()):
			return false
	return true


# --- internals ---

func _place_marker(node: Dictionary, index: int, spot: Vector2) -> void:
	var readable: bool = node["kind"] == &"known" or bool(node["face_shown"])
	var badge: StringName = &"map_unknown"
	var face: String = "迷霧"
	if readable:
		if node["content"] == &"battle":
			badge = &"map_war" if node["battle_type"] == &"civil_war" else &"map_battle"
			face = Battle.type_name(node["battle_type"])
		else:
			badge = &"map_opportunity"
			face = "機會事件"
	var holder := Control.new()
	holder.anchor_left = spot.x
	holder.anchor_top = spot.y
	holder.anchor_right = spot.x
	holder.anchor_bottom = spot.y
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_markers.add_child(holder)
	if not readable:
		# The fog itself: a haze around the marker, so an unreadable node still reads as A NODE.
		_fogged += 1
		var halo := TextureRect.new()
		var halo_size: float = MARKER_ICON * HALO_SCALE
		halo.texture = _chrome.texture(String(AssetPaths.UI_ICON_PLATE["path"]))
		halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		halo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		halo.size = Vector2(halo_size, halo_size)
		halo.position = Vector2(-halo_size, -halo_size) * 0.5
		halo.modulate = HALO_TINT
		halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(halo)
	var marker := _chrome.button("", func() -> void: node_chosen.emit(index))
	marker.icon = _chrome.plate_icon(AssetPaths.icon(badge), MARKER_ICON)
	marker.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	marker.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	marker.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	marker.add_theme_stylebox_override("focus", _chrome.stylebox(
		AssetPaths.UI_BUTTON, Color(1.25, 1.18, 0.84)))
	marker.size = Vector2(MARKER_ICON, MARKER_ICON)
	marker.position = Vector2(-MARKER_ICON, -MARKER_ICON) * 0.5
	holder.add_child(marker)
	_buttons.append(marker)
	var caption := _chrome.ink_label("%d　%s" % [index + 1, face], 18)
	caption.add_theme_color_override("font_color", Color(0.99, 0.97, 0.92))
	caption.add_theme_constant_override("outline_size", 8)
	caption.add_theme_color_override("font_outline_color", Color(0.10, 0.09, 0.12, 0.95))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.size = Vector2(300.0, 30.0)
	caption.position = Vector2(-150.0, MARKER_ICON * 0.55)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(caption)
