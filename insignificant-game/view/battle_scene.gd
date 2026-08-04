class_name BattleScene
extends Control
# 戰鬥＝依戰鬥類型的專屬戰場, seen from straight above (design/戰鬥.md §場景呈現, ADR-0009).
#
# **This is a replayer and holds no rules.** Core resolves a whole round into a tick-stamped
# timeline (`architecture.md` §Timeline event contract) and this walks that list in tick order,
# drawing what already happened. It never rolls, never picks a target, never decides an outcome.
# The HTML page in `docs/` is the same replayer against an exported fixture, and both read the same
# contract — a divergence between them is a bug in one of them, never a difference of opinion.
#
# The picture IS the rule (掩護鏈, ADR-0008): both sides face each other across a midline and each
# stages front to back 近戰列 → 工事線 → 遠程列 → 空域, so the wall visibly stands in front of the
# archers it screens. **掩護只靠位置讀，沒有掩護標記、沒有標籤.**
#
# Two things this scene owns that the core deliberately does not: where anything stands (seeded from
# the battle, so a replay looks identical), and the fact that 中立掩體 slow and divert land units —
# 移動變慢與繞路只是畫面的事，沒有任何規則量它.

signal deploy_requested(available_index: int)
signal round_requested
signal concede_requested
signal retreat_requested
signal defect_requested
signal playback_finished   # the tick window has been watched; the boundary is the player's again

const ROUND_SECONDS: float = 2.2         # how long a 回合's tick window takes to watch
const SHOT_SECONDS: float = 0.16
const FIELD_TOP: float = 0.30            # the plate's playable band, as fractions of the scene
const FIELD_BOTTOM: float = 0.80
const MID: float = 0.5
# |x − mid| per station, ＝ the cover chain read as depth: 近戰列 in front, 空域 furthest back.
const ROW_DEPTH: Dictionary = {
	&"melee": 0.085, &"fortification": 0.170, &"ranged": 0.255, &"air": 0.360,
}
# The clear ground BETWEEN station columns, as |x − mid| bands: scatter may land in any of them
# and never on a column. Derived from ROW_DEPTH by hand rather than computed, because the columns
# are a fixed staging decision and a loop would only hide that.
const GAPS: Array[Array] = [
	[0.010, 0.055], [0.115, 0.145], [0.200, 0.230], [0.285, 0.335], [0.390, 0.455],
]
const UNIT_SIZE: float = 124.0
const WALL_WIDTH: float = 34.0        # a wall's width follows its sprite's axis, clamped to this band
const WALL_MAX_WIDTH: float = 108.0
const WALL_MARGIN: float = 26.0       # how far a wall overhangs the frontage it screens
const SHOT_SIZE: float = 38.0
const BARRIER_SIZE: Dictionary = {&"weak": 72.0, &"medium": 104.0, &"hard": 146.0}
const GRADE_SPRITE: Dictionary = {
	&"weak": &"enemy_weak", &"medium": &"enemy_mid", &"hard": &"enemy_hard",
}
const HURT_TINT: Color = Color(1.0, 0.72, 0.68)
const DISABLED_TINT: Color = Color(0.55, 0.55, 0.58, 0.85)

var _chrome: Chrome
var _state: GameState
var _battle: Battle.BattleField
var _backdrop: TextureRect
var _scatter: Control
var _field: Control
var _shots: Control
var _console: PanelContainer
var _info: Label
var _spend: Label
var _deploy_list: VBoxContainer
var _actions: HBoxContainer
var _banner: Label

var _sprites: Dictionary = {}      # uid -> Control (units and forts alike; uids are unique per battle)
var _barriers: Dictionary = {}     # prop id -> Control
var _flying: Array[Dictionary] = []
var _timeline: Array[Dictionary] = []
var _cursor: int = 0
var _clock: float = 0.0
var _playing: bool = false
var _silent: bool = false   # fast-forward: apply what the events CHANGED, animate none of it


func setup(chrome: Chrome) -> void:
	_chrome = chrome
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop = TextureRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_scatter = _layer()
	_field = _layer()
	_shots = _layer()
	_banner = _chrome.ink_label("", 22)
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_left = 60.0
	_banner.offset_top = 180.0
	_banner.offset_right = -60.0
	_banner.offset_bottom = 230.0
	_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.62))
	_banner.add_theme_constant_override("outline_size", 9)
	_banner.add_theme_color_override("font_outline_color", Color(0.10, 0.06, 0.05, 0.95))
	add_child(_banner)
	_build_console()


func open(state: GameState, battle: Battle.BattleField) -> void:
	_state = state
	_battle = battle
	_backdrop.texture = _chrome.texture(AssetPaths.background_battle(battle.battle_type))
	for group: Dictionary in [_sprites, _barriers]:
		for node: Node in group.values():
			node.queue_free()
	_sprites.clear()
	_barriers.clear()
	_flying.clear()
	_timeline.clear()
	_playing = false
	_scatter_the_ground()
	_place_barriers()
	refresh()


func refresh() -> void:
	_restage()
	_refresh_console()


func playing() -> bool:
	return _playing


func play_round() -> void:
	# The boundary is over: watch what core already resolved. 玩家在窗口內不操作.
	_timeline = _battle.last_timeline
	_cursor = 0
	_clock = 0.0
	_playing = true
	_set_console_enabled(false)


func finish_playback() -> void:
	# Fast-forward whatever is left (used by Part B, and by a player who clicks through).
	if not _playing:
		return
	# Skipping the watching means skipping the animation, not just its duration: a whole round can
	# carry hundreds of events, and spawning a tween and a sprite for each one is how a fast-forward
	# turns into a stall. Part B's watchdog caught exactly that.
	_silent = true
	while _cursor < _timeline.size():
		_apply(_timeline[_cursor])
		_cursor += 1
	_silent = false
	for shot: Dictionary in _flying:
		(shot["node"] as Node).queue_free()
	_flying.clear()
	_playing = false
	_set_console_enabled(true)
	_restage()
	playback_finished.emit()


func sprite_count() -> int:
	return _sprites.size()


func barrier_count() -> int:
	return _barriers.size()


func deploy_option_count() -> int:
	return _deploy_list.get_child_count()


func press_deploy(index: int) -> void:
	(_deploy_list.get_child(index) as Button).pressed.emit()


func press_action(needle: String) -> bool:
	for child: Node in _actions.get_children():
		var button := child as Button
		if button != null and not button.disabled and button.text.contains(needle):
			button.pressed.emit()
			return true
	return false


func chain_reads_front_to_back(side: StringName) -> bool:
	# The one structural claim this scene makes, asserted rather than asserted-about: each side's
	# 近戰列 stands in front of its 工事線, which stands in front of its 遠程列, which stands in
	# front of its 空域 — and every station is on its own half of the field (ADR-0008).
	var depth: Dictionary = {}
	for unit: Dictionary in _units_of(side):
		var node: Control = _sprites.get(int(unit["uid"])) as Control
		if node == null:
			continue
		var d: float = absf(node.position.x + node.size.x * 0.5 - size.x * MID)
		depth[unit["row"]] = minf(float(depth.get(unit["row"], d)), d)
		if side == &"player" and node.position.x > size.x * MID:
			return false
		if side == &"enemy" and node.position.x + node.size.x < size.x * MID:
			return false
	for fort: Dictionary in _forts_of(side):
		var node: Control = _sprites.get(int(fort["uid"])) as Control
		if node != null:
			var d: float = absf(node.position.x + node.size.x * 0.5 - size.x * MID)
			depth[&"fortification"] = minf(float(depth.get(&"fortification", d)), d)
	var order: Array[StringName] = [&"melee", &"fortification", &"ranged", &"air"]
	var last: float = -1.0
	for row: StringName in order:
		if not depth.has(row):
			continue
		if float(depth[row]) <= last:
			return false
		last = float(depth[row])
	return true


func _process(delta: float) -> void:
	_advance_shots(delta)
	if not _playing:
		return
	_clock += delta * float(Battle.TICKS_PER_ROUND) / ROUND_SECONDS
	while _cursor < _timeline.size() and float(_timeline[_cursor]["tick"]) <= _clock:
		_apply(_timeline[_cursor])
		_cursor += 1
	if _cursor >= _timeline.size() and _clock >= float(Battle.TICKS_PER_ROUND):
		finish_playback()


# --- staging: the picture that IS the cover chain ---

func _restage() -> void:
	var live: Dictionary = {}
	for side: StringName in [&"player", &"enemy"]:
		var by_row: Dictionary = {}
		for unit: Dictionary in _units_of(side):
			var row: StringName = unit["row"]
			if not by_row.has(row):
				by_row[row] = [] as Array[Dictionary]
			(by_row[row] as Array[Dictionary]).append(unit)
		for row: StringName in by_row:
			var rank: Array[Dictionary] = by_row[row]
			for i: int in range(rank.size()):
				var uid: int = int(rank[i]["uid"])
				live[uid] = true
				_unit_node(uid, rank[i]).position = _station(side, row, i, rank.size()) \
					- Vector2(UNIT_SIZE, UNIT_SIZE) * 0.5
		for fort: Dictionary in _forts_of(side):
			live[int(fort["uid"])] = true
			_fort_node(int(fort["uid"]), fort, side)
	for uid: int in _sprites.keys():
		if not live.has(uid):
			(_sprites[uid] as Node).queue_free()
			_sprites.erase(uid)


func _station(side: StringName, row: StringName, index: int, count: int) -> Vector2:
	var depth: float = float(ROW_DEPTH[row])
	var x: float = (MID - depth if side == &"player" else MID + depth) * size.x
	var top: float = FIELD_TOP * size.y
	var span: float = (FIELD_BOTTOM - FIELD_TOP) * size.y
	var y: float = top + span * (float(index) + 1.0) / (float(count) + 1.0)
	return Vector2(x, y)


func _unit_node(uid: int, unit: Dictionary) -> Control:
	if _sprites.has(uid):
		var existing: TextureRect = _sprites[uid] as TextureRect
		existing.modulate = HURT_TINT if int(unit["hp"]) < int(unit["max_hp"]) else Color.WHITE
		existing.flip_h = _mirrored(unit)   # a 勸降 defector turns around; same uid, new heading
		return existing
	var art := TextureRect.new()
	art.texture = _unit_texture(unit)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size = Vector2(UNIT_SIZE, UNIT_SIZE)
	art.flip_h = _mirrored(unit)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# What this unit throws is a property of the unit, not of the label an event happens to use:
	# a label repeats and an anonymous 非正規軍's grade says nothing about its weapon.
	art.set_meta(&"line", _sprite_line(unit))
	art.set_meta(&"row", unit["row"])
	_field.add_child(art)
	_sprites[uid] = art
	return art


func _mirrored(unit: Dictionary) -> bool:
	# 雙方相對: a unit must face the side it is fighting. The sprite roster gives us two authored
	# headings (review-brief-units-topdown.md §1) — the player LINES point right, the three
	# anonymous enemy tiers point left — and the same line serves both camps, because 正規軍 field
	# your own roster. So the flip is a function of which art it uses and which side it is on, not
	# of side alone; a 勸降 defector keeps its tier art and turns around. W14.8's audit measured
	# that mirroring holds at battle zoom (vehicles are axis-symmetric; a figure swaps weapon hand,
	# which §8 does not call a defect).
	var faces_right: bool = unit["card_id"] != &""
	var wants_right: bool = unit["side"] == &"player"
	return faces_right != wants_right


func _fort_node(uid: int, fort: Dictionary, side: StringName) -> Control:
	# 工事讀作建物，不是單位: no stat labels, only 運作中／被禁用 — which is a tint, not a bar.
	# A 盾陣 is ONE segment spanning the frontage of the row it screens (never a block on one unit);
	# a 防空飛彈 is a point emplacement.
	var wall: bool = (fort["flags"] as Array).has(&"screens_ranged_row")
	var depth: float = float(ROW_DEPTH[&"fortification"])
	var x: float = (MID - depth if side == &"player" else MID + depth) * size.x
	var art: TextureRect = _sprites.get(uid) as TextureRect
	if art == null:
		art = TextureRect.new()
		var era: int = Era.index(_state.generation)
		if AssetPaths.has_unit(fort["card_id"], era):
			art.texture = _chrome.texture(AssetPaths.unit(fort["card_id"], era))
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_meta(&"line", fort["card_id"])
		art.set_meta(&"row", &"ranged")   # a 防空飛彈 fires; a 盾陣 never does
		_field.add_child(art)
		_sprites[uid] = art
	if wall:
		# 一段牆，橫在遠程列前面（不掩護單一單位）: the wall's LENGTH is the frontage of the row it
		# screens, and its width follows the sprite's own axis. Stretching it to the full band
		# turned a wall into a pole — the barriers ship top-to-bottom precisely so the view can
		# scale them without ever rotating or distorting them (decisions.md W14.8).
		var frontage := _row_frontage(side, &"ranged")
		var length: float = frontage.y - frontage.x
		var aspect: float = 0.4
		if art.texture != null:
			aspect = float(art.texture.get_width()) / float(art.texture.get_height())
		art.size = Vector2(clampf(length * aspect, WALL_WIDTH, WALL_MAX_WIDTH), length)
		art.position = Vector2(x - art.size.x * 0.5, frontage.x)
	else:
		art.size = Vector2(UNIT_SIZE, UNIT_SIZE)
		art.position = Vector2(x, _station(side, &"fortification", 0, 2).y) \
			- Vector2(UNIT_SIZE, UNIT_SIZE) * 0.5
	art.modulate = DISABLED_TINT if bool(fort["disabled"]) else Color.WHITE
	return art


func _row_frontage(side: StringName, row: StringName) -> Vector2:
	# The top and bottom of the ground a row occupies. An empty 遠程列 still gets a wall — a screen
	# with nobody behind it is legal and the player paid for it — so the empty case falls back to
	# the middle of the band rather than collapsing to nothing.
	var top: float = INF
	var bottom: float = -INF
	for unit: Dictionary in _units_of(side):
		if unit["row"] != row:
			continue
		var node: Control = _sprites.get(int(unit["uid"])) as Control
		if node == null:
			continue
		top = minf(top, node.position.y)
		bottom = maxf(bottom, node.position.y + node.size.y)
	if top > bottom:
		var band_top: float = FIELD_TOP * size.y
		var band: float = (FIELD_BOTTOM - FIELD_TOP) * size.y
		return Vector2(band_top + band * 0.28, band_top + band * 0.72)
	return Vector2(top - WALL_MARGIN, bottom + WALL_MARGIN)


func _sprite_line(unit: Dictionary) -> StringName:
	return unit["card_id"] if unit["card_id"] != &"" else GRADE_SPRITE.get(unit["grade"], &"enemy_weak")


func _unit_texture(unit: Dictionary) -> Texture2D:
	var era: int = Era.index(_state.generation)
	var line: StringName = _sprite_line(unit)
	if AssetPaths.has_unit(line, era):
		return _chrome.texture(AssetPaths.unit(line, era))
	return null


# --- the ground: scatter and neutral cover ---

func _scatter_the_ground() -> void:
	# 擺放由本場戰鬥的種子決定 (ADR-0010), so a replay looks the same every time and the core still
	# holds no coordinates. Decorative props are the view's alone; the barrier-carrying ones are
	# placed by `_place_barriers`, which reads the roster core actually fielded.
	for child: Node in _scatter.get_children():
		child.queue_free()
	var placer := RandomNumberGenerator.new()
	placer.seed = hash("scatter:%d:%d:%s" % [
		_state.run_seed, _state.generation, _battle.battle_type])
	for prop: Dictionary in AssetPaths.SCATTER.get(_battle.battle_type, [] as Array):
		if StringName(prop["barrier"]) != &"none":
			continue
		for _copy: int in range(placer.randi_range(3, 6)):
			var art := _prop_sprite(prop, placer, placer.randf_range(52.0, 78.0))
			art.position = _open_ground(placer) - art.size * 0.5
			_scatter.add_child(art)


func _place_barriers() -> void:
	# 體積對應掩體等級 is a rule the picture carries (戰鬥.md): a barrier is drawn from its TIER,
	# never from how many pixels its sprite happens to be, so a player reads at a glance which rock
	# will hold. What is on the field comes from `battle.barriers`; where it stands is ours.
	var placer := RandomNumberGenerator.new()
	placer.seed = hash("barrier:%d:%d:%s" % [
		_state.run_seed, _state.generation, _battle.battle_type])
	for barrier: Dictionary in _battle.barriers:
		var prop: StringName = barrier["prop"]
		var spec: Dictionary = _scatter_spec(prop)
		if spec.is_empty():
			continue
		var art := _prop_sprite(spec, placer, float(BARRIER_SIZE[barrier["tier"]]))
		art.position = _open_ground(placer) - art.size * 0.5
		_scatter.add_child(art)
		_barriers[prop] = art


func _scatter_spec(prop: StringName) -> Dictionary:
	for spec: Dictionary in AssetPaths.SCATTER.get(_battle.battle_type, [] as Array):
		if StringName(spec["id"]) == prop:
			return spec
	return {}


func _prop_sprite(spec: Dictionary, placer: RandomNumberGenerator, box: float) -> TextureRect:
	var variant: int = placer.randi_range(1, int(spec["variants"]))
	var art := TextureRect.new()
	art.texture = _chrome.texture(AssetPaths.scatter(spec["id"], variant))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size = Vector2(box, box)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


func _open_ground(placer: RandomNumberGenerator) -> Vector2:
	# 避開單位就位的位置 (ADR-0010): a prop lands in one of the GAPS between station columns, on
	# either side of the midline, so the whole field gets dressed and nothing a unit stands on is
	# covered by a rock. Scatter is ground, not a hedge down the middle.
	var gap: Array = GAPS[placer.randi_range(0, GAPS.size() - 1)]
	var depth: float = placer.randf_range(float(gap[0]), float(gap[1]))
	var left: bool = placer.randf() < 0.5
	return Vector2(
		size.x * (MID - depth if left else MID + depth),
		size.y * placer.randf_range(FIELD_TOP - 0.08, FIELD_BOTTOM + 0.06))


# --- replay: one event, one thing the player sees ---

func _apply(event: Dictionary) -> void:
	var type: StringName = event["type"]
	match type:
		&"hit", &"miss":
			_throw(int(event["by_uid"]), int(event["target_uid"]),
				Color.WHITE if type == &"hit" else Color(1, 1, 1, 0.45))
			if type == &"hit":
				_flash(int(event["target_uid"]), Color(1.6, 0.55, 0.45))
		&"dodge":
			_flash(int(event["by_uid"]), Color(0.6, 1.5, 1.5))
		&"death":
			var node: Control = _sprites.get(int(event["victim_uid"])) as Control
			if node != null:
				node.queue_free()
				_sprites.erase(int(event["victim_uid"]))
		&"intercept":
			# 平時不搶眼，在每一發打到它身上的那一刻現身擋下 — cover is invisible until it works,
			# and the shot has to visibly stop AT it, not at the unit it was aimed past.
			var wall_uid: int = int(event["card_id_uid"])
			var cover: Control = _sprites.get(wall_uid) as Control if wall_uid > 0 \
				else _barriers.get(event["barrier"]) as Control
			if cover != null:
				_flash_node(cover, Color(1.5, 1.4, 0.7))
				_throw_at(int(event["by_uid"]), cover.position + cover.size * 0.5, Color.WHITE)
		&"barrier_destroyed":
			if _barriers.has(event["barrier"]):
				(_barriers[event["barrier"]] as Node).queue_free()
				_barriers.erase(event["barrier"])
		&"disable", &"repair":
			var fort: Control = _sprites.get(int(event["card_id_uid"])) as Control
			if fort != null:
				fort.modulate = DISABLED_TINT if type == &"disable" else Color.WHITE
		&"shootdown":
			_throw(int(event["by_uid"]), int(event["target_uid"]), Color.WHITE)
		&"medal":
			_flash(int(event["unit_uid"]), Color(1.8, 1.6, 0.6))
		&"take_cover":
			_take_cover(int(event["unit_uid"]), event["barrier"])
		&"take_station":
			pass   # position comes from _restage; the event only says the chain changed


func _take_cover(uid: int, prop: StringName) -> void:
	# 受傷的陸軍單位退到掩體後面: the fallback is a MOVE, which is the whole reason the player can
	# see it happen. Nothing measures the distance — 移動變慢與繞路只是畫面的事.
	var node: Control = _sprites.get(uid) as Control
	if node == null:
		return
	if prop == &"" or not _barriers.has(prop):
		return
	var rock: Control = _barriers[prop] as Control
	var behind: float = 1.0 if node.position.x < size.x * MID else -1.0
	node.position = rock.position + rock.size * 0.5 \
		+ Vector2(behind * (rock.size.x * 0.5 + UNIT_SIZE * 0.4), 0.0) \
		- node.size * 0.5


func _throw(from_uid: int, to_uid: int, tint: Color) -> void:
	var to: Control = _sprites.get(to_uid) as Control
	var from: Control = _sprites.get(from_uid) as Control
	if from == null:
		return
	var end: Vector2 = (to.position + to.size * 0.5) if to != null \
		else from.position + from.size * 0.5 \
			+ Vector2(size.x * 0.08 * (1.0 if from.position.x < size.x * MID else -1.0), 0.0)
	_throw_at(from_uid, end, tint)


func _throw_at(from_uid: int, end: Vector2, tint: Color) -> void:
	if _silent:
		return
	var from: Control = _sprites.get(from_uid) as Control
	if from == null:
		return
	# 近戰列 closes and hits; only the rows that shoot have anything to draw crossing the gap.
	# Reading the ROW rather than the label is what keeps an era-1 mob from firing bullets.
	var ammo: StringName = &"" if from.get_meta(&"row", &"melee") == &"melee" \
		else AssetPaths.projectile_for(from.get_meta(&"line", &""), Era.index(_state.generation))
	var start: Vector2 = from.position + from.size * 0.5
	if ammo == &"":
		# 近戰 closes instead of throwing: a lunge toward the target and back.
		_lunge(from, end)
		return
	var art := TextureRect.new()
	art.texture = _chrome.texture(AssetPaths.projectile(ammo))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size = Vector2(SHOT_SIZE, SHOT_SIZE)
	art.modulate = tint
	art.flip_h = end.x < start.x   # 右向渲染、敵方鏡像 (inventory.md §Flying weapons)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shots.add_child(art)
	_flying.append({"node": art, "from": start, "to": end, "t": 0.0})


func _lunge(node: Control, toward: Vector2) -> void:
	var home := node.position
	var step: Vector2 = (toward - home).normalized() * 18.0
	var tween := create_tween()
	tween.tween_property(node, "position", home + step, SHOT_SECONDS * 0.5)
	tween.tween_property(node, "position", home, SHOT_SECONDS * 0.5)


func _advance_shots(delta: float) -> void:
	for i: int in range(_flying.size() - 1, -1, -1):
		var shot: Dictionary = _flying[i]
		shot["t"] = float(shot["t"]) + delta / SHOT_SECONDS
		var node: Control = shot["node"] as Control
		if float(shot["t"]) >= 1.0:
			node.queue_free()
			_flying.remove_at(i)
			continue
		node.position = (shot["from"] as Vector2).lerp(shot["to"], float(shot["t"])) \
			- node.size * 0.5


func _flash(uid: int, tint: Color) -> void:
	var node: Control = _sprites.get(uid) as Control
	if node != null:
		_flash_node(node, tint)


func _flash_node(node: Control, tint: Color) -> void:
	if _silent:
		return
	var base := node.modulate
	var tween := create_tween()
	tween.tween_property(node, "modulate", tint, 0.06)
	tween.tween_property(node, "modulate", base, 0.18)


# --- the round-boundary console ---

func _build_console() -> void:
	_console = _chrome.panel()
	_console.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_console.offset_left = 40.0
	_console.offset_top = -300.0
	_console.offset_right = -40.0
	_console.offset_bottom = -24.0
	add_child(_console)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_console.add_child(box)
	_info = _chrome.ink_label("", 16)
	box.add_child(_info)
	# 「本場已燒軍費 vs 預期賠償」全程常駐 (戰鬥.md 核心博弈) — this is the game's central bet.
	_spend = _chrome.ink_label("", 21, true)
	box.add_child(_spend)
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_deploy_list = VBoxContainer.new()
	_deploy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deploy_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_deploy_list)
	_actions = HBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	_actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	split.add_child(_actions)


func _refresh_console() -> void:
	var cap: String = "第 %d 回合（無回合上限）" % _battle.round if _battle.round_cap == 0 \
		else "第 %d／%d 回合" % [_battle.round, _battle.round_cap]
	var intel: String = "情報：本場波次表可見（%d 波）" % _battle.waves.size() if _battle.intel_visible \
		else "情報：盲打（當代未覆蓋偵查）"
	_info.text = "%s｜%s｜%s\n我方場上 %d（工事 %d）　敵方場上 %d（工事 %d）" % [
		Battle.type_name(_battle.battle_type), cap, intel,
		_battle.player_units.size(), _battle.player_forts.size(),
		_battle.enemy_units.size(), _battle.enemy_forts.size()]
	_spend.text = "本場已燒軍費 %d ｜ 預期賠償 %d" % [_battle.spent, _battle.expected_reward]
	# 內亂型戰鬥依規則在開場標明民怨來源 (戰鬥.md)
	_banner.text = ("內亂：對自己人民出動戰爭機器有代價——出過機械型部隊卡，戰後幸福 −%d"
		% Battle.RIOT_MECH_HAPPINESS) if _battle.battle_type == &"riot" else ""
	for child: Node in _deploy_list.get_children():
		_deploy_list.remove_child(child)
		child.queue_free()
	for i: int in range(_battle.available.size()):
		var instance: Cards.CardInstance = _battle.available[i]
		var index := i
		var quality: String = ""
		if Cards.is_unit(instance.id):
			quality = "　命中 %.0f／閃避 %.0f／攻速 %.2f" % [
				Cards.accuracy_of(_state, instance), Cards.dodge_of(_state, instance),
				Cards.speed_of(_state, instance)]
		var button := _chrome.button("投入 %s（軍費 %d）%s" % [
			Cards.display_name(instance), Battle.card_cost(_state, _battle, instance), quality],
			func() -> void: deploy_requested.emit(index))
		_deploy_list.add_child(button)
	for child: Node in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	if Battle.can_defect(_state, _battle):
		_actions.add_child(_chrome.button("投誠（免軍費勝）",
			func() -> void: defect_requested.emit()))
	_actions.add_child(_chrome.button("結束回合 → 演出", func() -> void: round_requested.emit()))
	_actions.add_child(_chrome.button("不再出牌（自願認輸）",
		func() -> void: concede_requested.emit()))
	if Battle.can_retreat(_battle):
		_actions.add_child(_chrome.button("撤軍（%d 錢，+%d 人口）" % [
			Battle.RETREAT_COST_BASE * Era.coeff(_state.generation), Battle.RETREAT_POP],
			func() -> void: retreat_requested.emit()))
	_focus_first()


func _set_console_enabled(on: bool) -> void:
	# 玩家在窗口內不操作 (戰鬥.md): during playback the console is visibly out of reach.
	_console.modulate = Color.WHITE if on else Color(1, 1, 1, 0.35)
	for container: Control in [_deploy_list, _actions]:
		for child: Node in container.get_children():
			var button := child as Button
			if button != null:
				button.disabled = not on
	if on:
		_focus_first()


func _focus_first() -> void:
	for child: Node in _actions.get_children():
		var button := child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return


func _layer() -> Control:
	var node := Control.new()
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node


func _units_of(side: StringName) -> Array[Dictionary]:
	return _battle.player_units if side == &"player" else _battle.enemy_units


func _forts_of(side: StringName) -> Array[Dictionary]:
	return _battle.player_forts if side == &"player" else _battle.enemy_forts


func press_deploy_enabled() -> bool:
	for child: Node in _deploy_list.get_children():
		var button := child as Button
		if button != null and not button.disabled:
			return true
	return false


func press_deploy_named(needle: String) -> bool:
	for child: Node in _deploy_list.get_children():
		var button := child as Button
		if button != null and not button.disabled and button.text.contains(needle):
			button.pressed.emit()
			return true
	return false


func wall_is_a_segment() -> bool:
	# 一張卡就是一段牆，橫在遠程列前面 (ADR-0008/0010): a 盾陣 must be drawn as a SEGMENT lying across
	# the lane, never a block parked on one unit — the whole reason the camera went top-down. The
	# ratio is deliberately loose (the era-1 timber wall's own sprite is 1:2) because what is being
	# asserted is "longer than it is thick, on its own axis", not a particular slenderness.
	for fort: Dictionary in _battle.player_forts:
		if not (fort["flags"] as Array).has(&"screens_ranged_row"):
			continue
		var node: Control = _sprites.get(int(fort["uid"])) as Control
		if node == null or node.size.y < node.size.x * 1.8:
			return false
	return true
