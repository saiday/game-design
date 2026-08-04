class_name Hud
extends VBoxContainer
# The standing stat strip (design/營運.md 場景呈現, style bible §11): **icon + value only, no text
# labels**. The word for a number and what it does to you live in a parchment tooltip that pops on
# mouse hover OR controller focus — 滑鼠懸停／手把焦點同權, so the strip reads the same on a pad as
# on a mouse. Every cell is focusable for exactly that reason.
#
# Two rows: what you have, and what is coming for you. The danger row is always on screen (it is
# the only place a player sees the collapse clock) and reads in accent ink.

const ICON_SIZE: int = 34
const VALUE_FONT: int = 21
const DANGER_ICON: int = 26
const DANGER_FONT: int = 16
const TIP_TEXT_WIDTH: float = 400.0

# id, icon asset id, the term, and what it means. The explanation is the whole reason a strip of
# bare numbers is legible at all, so it says the consequence, not the definition.
const STATS: Array[Dictionary] = [
	{"id": &"era", "icon": &"era1", "term": "時代", "explain": "第幾代、身處哪個時代。時代係數決定所有成本與敵人強度。"},
	{"id": &"population", "icon": &"population", "term": "人口", "explain": "低於 5 就是政權崩潰，本作唯一的失敗條件。"},
	{"id": &"happiness", "icon": &"happiness", "term": "幸福", "explain": "低幸福加權注入收稅戰與內亂；高幸福讓機會事件好抽。"},
	{"id": &"culture", "icon": &"culture", "term": "文化", "explain": "解鎖民主與投誠門檻；文化輸出讓敵人更容易倒戈。"},
	{"id": &"tech", "icon": &"tech", "term": "科技", "explain": "推進時代序，開啟卡牌與國策的時代閘。"},
	{"id": &"money", "icon": &"money", "term": "國庫", "explain": "單一金錢池，可以扣到負。負的部分就是債務。"},
	{"id": &"bp", "icon": &"bp", "term": "BP", "explain": "本代未花的營運點數，最多帶 2 點到下一代。"},
	{"id": &"medals", "icon": &"attack", "term": "勳章", "explain": "兵營產出、待指派的勳章；指派後那張卡的所屬列數值 +1 階。"},
]
const DANGERS: Array[Dictionary] = [
	{"id": &"debt", "icon": &"debt", "term": "債務", "explain": "國庫的負值部分。利息按階梯逐代滾動。"},
	{"id": &"interest", "icon": &"interest", "term": "利息／代", "explain": "每代自動從國庫扣掉的利息，債越深扣越兇。"},
	{"id": &"unrest", "icon": &"unrest", "term": "內亂權重", "explain": "每代擲一次內亂戰的機率。低幸福與深債會把它推高。"},
	{"id": &"collapse", "icon": &"population", "term": "距崩潰", "explain": "人口離 5 還有多遠。歸零就是結束。"},
]

var _chrome: Chrome
var _cells: Dictionary = {}          # id -> Button
var _tip: PanelContainer
var _tip_term: Label
var _tip_body: Label


func setup(chrome: Chrome) -> void:
	_chrome = chrome
	add_theme_constant_override("separation", 4)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 14)
	add_child(stat_row)
	for spec: Dictionary in STATS:
		stat_row.add_child(_cell(spec, ICON_SIZE, VALUE_FONT, Color(0.94, 0.91, 0.84)))
	var danger_row := HBoxContainer.new()
	danger_row.add_theme_constant_override("separation", 12)
	add_child(danger_row)
	for spec: Dictionary in DANGERS:
		danger_row.add_child(_cell(spec, DANGER_ICON, DANGER_FONT, Color(0.85, 0.72, 0.35)))


func build_tooltip() -> PanelContainer:
	# Lives on the scene root rather than inside the strip so it can overhang the layout.
	_tip = _chrome.panel()
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_tip.add_child(box)
	_tip_term = _chrome.ink_label("", 20)
	_tip_term.add_theme_font_override("font", _chrome.bold_font())
	box.add_child(_tip_term)
	_tip_body = _chrome.ink_label("", 15)
	# The wrap width has to be given, not inferred: an autowrapping Label with no width to wrap at
	# reports a minimum size a column tall, and the panel sizes itself to that. Part B caught it as
	# a tooltip covering a third of the city.
	_tip_body.custom_minimum_size = Vector2(TIP_TEXT_WIDTH, 0)
	box.add_child(_tip_body)
	return _tip


func refresh(state: GameState) -> void:
	var danger: Dictionary = Ending.danger_panel(state)
	(_cells[&"era"] as Button).icon = _chrome.plate_icon(
		AssetPaths.icon_era(Era.index(state.generation)), ICON_SIZE)
	_put(&"era", "%d／%d" % [state.generation, Era.FINAL_GENERATION])
	_put(&"population", str(state.population))
	_put(&"happiness", str(state.happiness))
	_put(&"culture", str(state.culture))
	_put(&"tech", str(state.tech))
	_put(&"money", str(state.treasury))
	_put(&"bp", str(state.bp))
	_put(&"medals", str(state.medals))
	_put(&"debt", str(int(danger["debt"])))
	_put(&"interest", str(int(danger["interest_per_gen"])))
	_put(&"unrest", "%d%%" % int(round(float(danger["unrest_weight"]) * 100.0)))
	_put(&"collapse", str(state.population - int(danger["collapse_threshold"])))


func value_of(id: StringName) -> String:
	return (_cells[id] as Button).text


func first_cell() -> Control:
	return _cells[&"era"]


func focus_cell(id: StringName) -> void:
	(_cells[id] as Button).grab_focus()


func tooltip_visible() -> bool:
	return _tip != null and _tip.visible


func tooltip_term() -> String:
	return _tip_term.text if _tip_term != null else ""


# --- internals ---

func _cell(spec: Dictionary, icon_size: int, font_size: int, tint: Color) -> Button:
	var b := Button.new()
	b.icon = _chrome.plate_icon(AssetPaths.icon(spec["icon"]), icon_size)
	b.text = "—"
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", tint)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_constant_override("h_separation", 6)
	# 滑鼠懸停／手把焦點同權: both open the same tooltip, neither is the "real" one.
	var spec_copy := spec
	b.mouse_entered.connect(func() -> void: show_tip(spec_copy, b))
	b.focus_entered.connect(func() -> void: show_tip(spec_copy, b))
	b.mouse_exited.connect(hide_tip)
	b.focus_exited.connect(hide_tip)
	_cells[spec["id"]] = b
	return b


func show_tip(spec: Dictionary, anchor: Control) -> void:
	if _tip == null:
		return
	_tip_term.text = String(spec["term"])
	_tip_body.text = String(spec["explain"])
	_tip.visible = true
	_tip.size = Vector2.ZERO
	_tip.reset_size()
	# Below the WHOLE strip, not below the cell: a tooltip that covers the danger row while
	# explaining the population number is hiding the thing it is there to make readable.
	var at := Vector2(anchor.global_position.x, global_position.y + size.y + 10.0)
	var room: Vector2 = _tip.get_viewport_rect().size
	at.x = clampf(at.x, 8.0, maxf(room.x - _tip.size.x - 8.0, 8.0))
	_tip.global_position = at


func hide_tip() -> void:
	if _tip != null:
		_tip.visible = false


func _put(id: StringName, text: String) -> void:
	(_cells[id] as Button).text = text
