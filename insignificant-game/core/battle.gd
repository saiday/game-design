class_name Battle
extends RefCounted
# 戰鬥 (design/戰鬥.md): single battlefield, auto-deploy by combat attribute, enemy arrives
# in SCHEDULED WAVES rolled per battle, each 回合 is a fixed tick window in which units act
# on their own attack speed (no simultaneous resolution), and core emits the round's whole
# event timeline before the view animates anything (docs/plan-battle-model-rewrite.md D1-D6).
# 出牌的唯一限制是軍費: no hand, no draw, any unplayed card any round, treasury may go
# negative and never blocks a play (D1/D3). Defeat is symmetric exhaustion: field empty AND
# nothing left to commit (D3). Survivors persist across waves, both sides (D4).
# Only player units carry the quality three + growth; every enemy (正規軍 and 非正規軍)
# fights at the engine defaults below (WW3). 世界大戰 (design/世界大戰.md, WW1-WW5) rides
# this same engine as the 7th type: two-camp prepared wave schedules, per-side exhaustion,
# uncapped rounds; WorldWar composes the war and settles it.
# 鎮壓的手段有代價: a riot in which any 機械型部隊卡 was played ends with 幸福 −15,
# win or lose, once per battle.
#
# Air & fortifications (ADR-0006/0007): 近戰列 never reaches 空域, 遠程列 selects freely
# (空域 included), 空襲 hits ground only; 防空飛彈 is the dedicated active air counter
# (destroy-on-hit); a fortification hit once is DISABLED, never removed, and an engineer
# repairs one per round round-robin. 只剩空軍 can't claim a field, for either side.
#
# Every timeline event carries the side of the party its actor field names (&"by", or &"unit"
# where there is no &"by"). Labels are card ids, so both camps' 步兵團 answer to one label and
# an attack could not be attributed to a camp without it (architecture.md §Timeline event
# contract; added in W14.7 when the first replayer needed it).
#
# The cover chain (ADR-0008): 自動佈陣 is an ordered chain 近戰列（最前）→ 工事線 → 遠程列 → 空域,
# each layer screening the one behind it. 正規軍 field screens of their own (never 防空飛彈, never
# repairable); 工兵團 stations in the 遠程列 and works at the 工事線. Still no coordinates: a station
# is the categorical row plus, for a screened row, which wall covers it — emitted as
# &"take_station" so the two timeline replayers stage the picture without holding a formation rule.
#
# Cover stops bullets, not people (ADR-0010): a 盾陣 absorbs RANGED fire aimed at the 遠程列 with a
# 3～5-shot budget rolled per wall, and 近戰 walks around it and engages the row directly. Neutral
# field scatter is the same object without an owner: one 中立掩體 per barrier-carrying prop on this
# battle type's ground, shared first-come by both sides, taken automatically by any land unit that
# has lost hit points, and DESTROYED rather than disabled when its budget runs out — no engineer,
# no repair, the one lifecycle difference from a fortification. Slowdown and detour are the view's;
# the core still has no movement to slow.
#
# Design gaps decided here (docs/decisions.md, W12 + W14.5): 正規軍 wave composition greedy
# strongest-first; mutual simultaneous exhaustion = player 敗北; siege/air prefer ACTIVE
# fortifications; retreat still issues the reward card (only cancelled battles don't).
# W13 growth hooks (D9/D13): accuracy XP per attack taken, dodge XP on dodge/survived hit,
# speed XP per survived round; filled XP emits a &"medal" event at that tick, effect next round.

const TICKS_PER_ROUND: int = 100        # calibration knob (plan: open items)
const RETREAT_COST_BASE: int = 10
const RETREAT_POP: int = 2
const FORT_LIMIT: int = 2               # 工事卡同場上限 (CardsData.FORT_FIELD_LIMIT mirror)
const RIOT_MECH_HAPPINESS: int = 15     # 鎮壓的手段有代價 (design/戰鬥.md)

# 掩體吸收上限, rolled per barrier on the &"battle" track (design/戰鬥.md 場景呈現 + 工事卡):
# 弱 1～2 發、中 2～3 發、強 3～5 發. 盾陣 rolls the strong band — the equivalence is the rule
# (ADR-0010), so it reads the same table instead of carrying a second pair of numbers.
const BARRIER_SHOTS: Dictionary = {&"weak": [1, 2], &"medium": [2, 3], &"hard": [3, 5]}
const WALL_TIER: StringName = &"hard"   # 盾陣 ＝ 強級掩體

# Engine defaults every enemy fights at (戰鬥.md 對手兩型; calibration knobs).
const ENEMY_ACCURACY: float = 100.0
const ENEMY_DODGE: float = 0.0
const ENEMY_SPEED: float = 1.0

# 非正規軍 anonymous tiers: 弱＝攻1/血2、中＝攻2/血4、硬＝攻3/血6 (×時代係數). 首領＝硬級.
const GRADE_STATS: Dictionary = {&"weak": [1, 2], &"medium": [2, 4], &"hard": [3, 6]}

# battle_type -> round cap, money reward, wave schedule (v1 基準; rolled at start within
# each wave's round window on the &"battle" track — 開戰前情報 reveals the roll).
# civil_war waves carry budget shares of 總實力 ≈ P×0.5 instead of fixed grades (對手文明).
# world_war (the 7th type, WW1-WW5): round_cap 0 = uncapped (波數上限 throttles instead);
# its two-camp wave schedule is composed by WorldWar and passed to start() prepared.
# `zh` is the type's display name, the only string a player should ever read for it — a battle id
# is a code identifier and nobody is fighting a `tax_battle`.
# `no_retreat` ＝ 三個型別禁用撤軍 (戰鬥.md §撤軍): 內部暴動戰, 為民主而流血, 世界大戰 — 全員選邊、
# 無退出口. It lives here as data rather than in the caller because it is a rule the corpus states,
# and a UI that has to remember three ids will eventually forget one.
const TYPES: Dictionary = {
	&"world_war": {"zh": "世界大戰", "round_cap": 0, "reward_per_coeff": 0, "no_retreat": true, "waves": []},
	&"tax_battle": {"zh": "收稅戰", "round_cap": 6, "reward_per_coeff": 15, "no_retreat": false,
		"waves": [{"window": [1, 1], "grades": [&"weak", &"weak"], "siege": false}]},
	&"field_battle": {"zh": "一般地圖戰", "round_cap": 8, "reward_per_coeff": 25, "no_retreat": false,
		"waves": [{"window": [1, 1], "grades": [&"medium", &"weak"], "siege": false},
			{"window": [3, 4], "grades": [&"medium"], "siege": false}]},
	&"hidden_battle": {"zh": "隱藏戰", "round_cap": 8, "reward_per_coeff": 45, "no_retreat": false,
		"waves": [{"window": [1, 1], "grades": [&"hard"], "siege": true},
			{"window": [3, 4], "grades": [&"hard"], "siege": true}]},
	&"riot": {"zh": "內部暴動戰", "round_cap": 8, "reward_per_coeff": 0, "no_retreat": true,
		"waves": [{"window": [1, 1], "grades": [&"medium"], "siege": false},
			{"window": [3, 4], "grades": [&"medium"], "siege": false}]},
	&"democracy_blood": {"zh": "為民主而流血", "round_cap": 8, "reward_per_coeff": 0, "no_retreat": true,
		"waves": [{"window": [1, 1], "grades": [&"hard", &"medium"], "siege": false},
			{"window": [4, 5], "grades": [&"hard"], "siege": false}]},
	&"civil_war": {"zh": "文明戰爭", "round_cap": 10, "reward_per_coeff": 0, "no_retreat": false,
		"waves": [{"window": [1, 1], "share": 0.40},
			{"window": [4, 5], "share": 0.35},
			{"window": [7, 8], "share": 0.25}]},
}

# Intel qualification ladder (國策 偵查線): era ids covered per completed node.
const INTEL_COVERAGE: Dictionary = {
	&"scout_camp": [&"tribal", &"classical"],
	&"political_marriage": [&"faith", &"industrial"],
	&"intelligence_agency": [&"modern"],
	&"satellite_surveillance": [&"information"],
}


class BattleField:
	extends RefCounted
	var battle_type: StringName
	var rival_id: StringName = &""
	var player_declared: bool = false     # 聖戰 bonuses apply only to wars YOU declared
	var round: int = 1
	var round_cap: int = 8
	var outcome: StringName = &""         # &"win"|&"loss"|&"retreat"|&"defected" ("" = ongoing)
	var waves: Array[Dictionary] = []     # schedule: {round, units, side} sorted by round
	                                      # (side &"player" = allied arrivals, world war only)
	var next_wave: int = 0
	var camps: Dictionary = {}            # world war only: {player_camp, enemy_camp} civ ids
	var merit_by_faction: Dictionary = {} # 戰功 per faction tag: Σ strength of units cleared
	var last_clear_by_side: Dictionary = {&"player": &"", &"enemy": &""}
	                                      # who last cleared a unit ON that side (最後一擊)
	var player_units: Array[Dictionary] = []
	var enemy_units: Array[Dictionary] = []
	var player_forts: Array[Dictionary] = []
	var enemy_forts: Array[Dictionary] = []
	var repair_cursor: int = 0            # round-robin position over player_forts (ADR-0007)
	var barriers: Array[Dictionary] = []  # 中立掩體 (ADR-0010): the only field entity that belongs
	                                      # to NOBODY — no player_/enemy_ pair, shared first-come by
	                                      # both sides. {prop, tier, shots, destroyed}; a destroyed
	                                      # barrier stays in the array so a replayer can still
	                                      # resolve the id that named it.
	var available: Array = []             # unplayed CardInstances (每張卡每場只出一次)
	var conceded: bool = false            # 還有未出卡但選擇不出 (voluntary exhaustion)
	var spent: int = 0                    # 本場已燒軍費 (UI shows vs expected_reward)
	var expected_reward: int = 0
	var merit: int = 0                    # 戰功: Σ strength of units we cleared
	var plunder: int = 0
	var attack_buff_rounds: int = 0       # 軍歌
	var cost_discount_rounds: int = 0     # 這些破洞不影響功能
	var love_and_peace_armed: bool = false
	var intel_visible: bool = false       # pre-battle: the rolled wave schedule is visible
	var see_deployment: bool = false      # 衛星監控 per-boundary preview (view concern)
	var mechanical_played: bool = false   # any 機械型部隊卡 fielded (riot 幸福 cost)
	var psyops_active: bool = false       # 文化國心戰 (D16): player accuracy snapshots take
	                                      # −RivalData.ENEMY_PSYOPS_ACCURACY_DEBUFF this battle
	var next_uid: int = 0                 # hands out per-entity `uid` (see _assign_uids)
	var last_timeline: Array[Dictionary] = []   # the previous round's full event list


# --- setup ---

static func intel_covers(state: GameState) -> bool:
	# 偵查是資格線: current era must be covered, or you fight blind.
	var era_id: StringName = Era.of(state.generation)
	for node_id: StringName in INTEL_COVERAGE.keys():
		if state.policies.has(node_id) and (INTEL_COVERAGE[node_id] as Array).has(era_id):
			return true
	return false


static func start(state: GameState, battle_type: StringName, rival_id: StringName = &"", player_declared: bool = false, surprise: bool = false, prepared_waves: Array[Dictionary] = []) -> BattleField:
	var battle := BattleField.new()
	battle.battle_type = battle_type
	battle.rival_id = rival_id
	battle.player_declared = player_declared
	battle.round_cap = int(TYPES[battle_type]["round_cap"])
	var coeff: int = Era.coeff(state.generation)
	battle.expected_reward = int(TYPES[battle_type]["reward_per_coeff"]) * coeff
	if battle_type == &"civil_war":
		var rival := Rivals.find(state, rival_id)
		battle.expected_reward = int(rival.power * 2.0)
		if player_declared and state.policies.has(&"holy_war"):
			battle.expected_reward = int(battle.expected_reward * 1.5)
	if prepared_waves.is_empty():
		_roll_waves(state, battle)
	else:
		# world war: WorldWar composed the two-camp schedule (WW4); sort round-ascending,
		# player-camp arrivals before enemy-camp arrivals within a round.
		battle.waves = prepared_waves.duplicate()
		battle.waves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a["round"]) != int(b["round"]):
				return int(a["round"]) < int(b["round"])
			return a["side"] == &"player" and b["side"] != &"player")
	battle.intel_visible = intel_covers(state) and not (battle_type == &"hidden_battle" and surprise)
	battle.see_deployment = state.policies.has(&"satellite_surveillance")
	battle.available = state.deck.duplicate()
	if bool(state.flags.get(&"enemy_psyops_next_battle", false)):
		battle.psyops_active = true   # D16: 下場戰命中率減益 — this battle consumes the flag
		state.flags.erase(&"enemy_psyops_next_battle")
	_place_barriers(state, battle)
	_arrive_waves(state, battle)   # wave 1 (敵方開場單位 became wave 1)
	_assign_uids(battle)
	return battle


static func defection_gate(state: GameState) -> int:
	var mult: int = 5 if state.policies.has(&"cultural_export") else 8
	return mult * Era.index(state.generation)


static func can_defect(state: GameState, battle: BattleField) -> bool:
	# 投誠 only fits small-scale narrative battles (一般地圖戰), opening only (round 1).
	return battle.battle_type == &"field_battle" and battle.round == 1 \
		and state.culture >= defection_gate(state)


static func defect(state: GameState, battle: BattleField) -> Dictionary:
	if not can_defect(state, battle):
		return {"ok": false, "reason": &"cannot_defect"}
	battle.outcome = &"defected"
	return {"ok": true, "reason": &""}


# --- player actions (all at the round boundary; no input during playback, D6) ---

static func card_cost(state: GameState, battle: BattleField, instance: Cards.CardInstance) -> int:
	var cost: int = Cards.military_cost_of(state, instance)
	if battle.cost_discount_rounds > 0:
		cost -= 1
	return maxi(cost, 0)


static func deploy(state: GameState, battle: BattleField, available_index: int) -> Dictionary:
	# 軍費 is the ONLY gate and it never blocks (D1/D3): treasury just goes negative.
	if battle.outcome != &"":
		return {"ok": false, "reason": &"battle_over"}
	var instance: Cards.CardInstance = battle.available[available_index]
	var entry: Dictionary = Cards.card(instance.id)
	# 同場上限 2 counts every fielded fort for the whole battle: forts are never removed, so a
	# disabled (待修) one still occupies its slot and slots never free up (ADR-0007)
	if entry["class"] == &"fortification" and battle.player_forts.size() >= FORT_LIMIT:
		return {"ok": false, "reason": &"fort_limit"}
	var cost: int = card_cost(state, battle, instance)
	state.treasury -= cost   # 軍費可扣到負
	battle.spent += cost
	battle.available.remove_at(available_index)
	if entry["class"] == &"mechanical":
		battle.mechanical_played = true
	match entry["class"]:
		&"fortification":
			battle.player_forts.append(_fort_from_card(state, instance))
		&"skill":
			_cast_skill(state, battle, instance)
			if bool(entry["destroyed_on_use"]):
				Cards.destroy_permanently(state, instance.id)
			# 用後消耗: non-policy skills just don't return this battle
		_:
			battle.player_units.append(_unit_from_card(state, battle, instance))
	_assign_uids(battle)   # the view can identify what it just fielded, before the round resolves
	return {"ok": true, "reason": &"", "cost": cost}


static func concede(battle: BattleField) -> void:
	# 還有未出卡但選擇不出 — a legal voluntary concession; consequence identical to 判輸 (D3).
	battle.conceded = true


static func type_name(battle_type: StringName) -> String:
	return String(TYPES[battle_type]["zh"])


static func can_retreat(battle: BattleField) -> bool:
	# 三個型別禁用撤軍 (戰鬥.md §撤軍). The UI asks; it does not keep its own list.
	return not bool(TYPES[battle.battle_type]["no_retreat"])


static func retreat(state: GameState, battle: BattleField) -> Dictionary:
	# 隨時可退: 10×係數, 永久 +2 人口; spent stays sunk. Whether this type allows it at all is
	# `can_retreat` — the caller asks before offering the button (戰鬥.md 撤軍).
	var cost: int = RETREAT_COST_BASE * Era.coeff(state.generation)
	state.treasury -= cost
	state.population += RETREAT_POP
	battle.outcome = &"retreat"
	return {"cost": cost, "population": RETREAT_POP}


# --- round resolution: one fixed tick window, full timeline before any animation (D6) ---

static func end_round(state: GameState, battle: BattleField) -> Dictionary:
	if battle.outcome != &"":
		return {"outcome": battle.outcome, "events": []}
	var events: Array[Dictionary] = []
	_assign_uids(battle)   # anything that arrived since the last boundary gets its handle first
	_repair_forts(state, battle, events)
	_take_stations(battle, events)   # after the repair: a restored wall screens from this round
	_seek_cover_all(battle, events)  # 下一個機會 for anyone hurt and uncovered (ADR-0010)
	_refresh_player_stats(state, battle)
	# 爛仗時候才宣揚愛與和平: after round 5, destroy one non-leader enemy.
	if battle.love_and_peace_armed and battle.round >= 5:
		_destroy_one_non_leader(battle, events, 0)
		battle.love_and_peace_armed = false
	_resolve_window(state, battle, events)
	var kills: int = _sweep_dead(battle.enemy_units)
	var losses: int = _sweep_dead(battle.player_units)
	# 攻速 XP: 每存活一個回合 (D9) — after the sweep, so only units that lived through the
	# window accrue; the killed accrue nothing (their growth was just wiped anyway).
	for unit: Dictionary in battle.player_units:
		_grant_battle_xp(unit, &"speed", TICKS_PER_ROUND, events)
	_check_exhaustion(battle)
	if battle.outcome == &"" and battle.round_cap > 0 and battle.round >= battle.round_cap:
		battle.outcome = &"loss"   # 判輸＝耗盡, same consequence (D3); cap 0 = 無上限 (世界大戰)
	if battle.outcome == &"":
		battle.round += 1
		_arrive_waves(state, battle)   # next wave stacks on the remnant (D4)
		_assign_uids(battle)   # the arrivals are on the field NOW, and the view reads it at the
		                       # boundary — everything standing there has to have a handle already
		if battle.attack_buff_rounds > 0:
			battle.attack_buff_rounds -= 1
		if battle.cost_discount_rounds > 0:
			battle.cost_discount_rounds -= 1
	battle.last_timeline = events
	return {"round": battle.round, "events": events, "kills": kills, "losses": losses,
			"outcome": battle.outcome}


static func finish(state: GameState, battle: BattleField) -> Dictionary:
	# Apply the outcome's economy/system consequences. Turn/sim calls this once per battle.
	var report: Dictionary = {
		"battle_type": battle.battle_type, "outcome": battle.outcome,
		"spent": battle.spent, "merit": battle.merit,
	}
	var won: bool = battle.outcome == &"win" or battle.outcome == &"defected"
	if battle.plunder > 0:
		state.treasury += battle.plunder
		report["plunder"] = battle.plunder
	match battle.battle_type:
		&"tax_battle", &"field_battle", &"hidden_battle":
			if won:
				state.treasury += battle.expected_reward
				report["reward"] = battle.expected_reward
		&"riot":
			if battle.mechanical_played:
				# 對自己人民出動戰爭機器，人民記得 — applies on every outcome.
				Happiness.adjust(state, -RIOT_MECH_HAPPINESS)
				report["suppression_happiness"] = -RIOT_MECH_HAPPINESS
			if battle.outcome == &"loss" or battle.outcome == &"retreat":
				report["riot_loss"] = Unrest.apply_riot_loss(state)
		&"democracy_blood":
			if battle.outcome == &"loss" or battle.outcome == &"retreat":
				state.flags[&"forced_democracy"] = true
				report["forced_democracy"] = true
		&"civil_war":
			if won:
				state.treasury += battle.expected_reward
				report["reward"] = battle.expected_reward
				report["war"] = Rivals.record_civil_war(state, battle.rival_id, true)
			else:
				var rival := Rivals.find(state, battle.rival_id)
				rival.power *= 1.05   # 判輸: 對手 power +5%
				report["war"] = Rivals.record_civil_war(state, battle.rival_id, false)
	# 戰後獎勵卡: 每場戰鬥結束必發, 勝敗皆然、七種類型皆然 (rolled + revealed; the caller
	# accepts via Cards.accept_reward or drops it — 卡牌.md 卡牌經濟).
	report["reward_instance"] = Cards.roll_reward(state)
	return report


# --- internals: waves ---

static func _roll_waves(state: GameState, battle: BattleField) -> void:
	# 波次的時點在開戰時於表列回合區間內抽定 (&"battle" track); 開戰前情報 reveals this roll.
	var coeff: int = Era.coeff(state.generation)
	var spec_waves: Array = TYPES[battle.battle_type]["waves"]
	for spec: Dictionary in spec_waves:
		var window: Array = spec["window"]
		var arrival: int = state.rng.randi_range(&"battle", int(window[0]), int(window[1]))
		var units: Array[Dictionary] = []
		if spec.has("share"):
			units = _regular_army_wave(state, battle, float(spec["share"]))
		else:
			for grade: StringName in (spec["grades"] as Array):
				units.append(_irregular_unit(state, grade, coeff, bool(spec["siege"])))
		if not units.is_empty():
			battle.waves.append({"round": arrival, "units": units, "side": &"enemy",
					"forts": regular_screens(units, &"enemy")})
	battle.waves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["round"]) < int(b["round"]))
	if battle.waves.is_empty():
		# tiny civil-war rival: still field one weakest regular in wave 1
		var weakest := _cheapest_regular_type(state)
		var rival: Rivals.RivalState = Rivals.find(state, battle.rival_id)
		var lone: Array[Dictionary] = [regular_unit(state, weakest, &"enemy", &"enemy", rival)]
		battle.waves.append({"round": 1, "side": &"enemy", "units": lone,
			"forts": regular_screens(lone, &"enemy")})


static func _arrive_waves(state: GameState, battle: BattleField) -> void:
	while battle.next_wave < battle.waves.size() \
			and int(battle.waves[battle.next_wave]["round"]) <= battle.round:
		var wave: Dictionary = battle.waves[battle.next_wave]
		var player_side: bool = wave["side"] == &"player"
		var into: Array[Dictionary] = battle.player_units if player_side else battle.enemy_units
		for unit: Dictionary in (wave["units"] as Array):
			into.append(unit)
		# 正規軍 screens ride in with the wave they cover, and 同場上限 2 counts the whole battle
		# exactly as it does for the player: a wall is never removed, so a slot never frees up.
		# The wall rolls its absorption budget when it takes the 工事線, not when the wave was
		# composed — 佈陣時抽定 (戰鬥.md), and a wall the slot limit turns away never rolls at all.
		var line: Array[Dictionary] = battle.player_forts if player_side else battle.enemy_forts
		for fort: Dictionary in (wave.get("forts", []) as Array):
			if line.size() < FORT_LIMIT:
				_arm_wall(state, fort)
				line.append(fort)
		battle.next_wave += 1


static func _place_barriers(state: GameState, battle: BattleField) -> void:
	# 戰場散景物件＝中立掩體 (design/戰鬥.md 場景呈現, ADR-0010). How many a battle fields is the
	# count of barrier-carrying props on its own ground, read off the art registry in table order
	# and never invented here (docs/decisions.md W14.9) — which is why 隱藏戰 fields none and
	# 世界大戰 fields two. `core/data/asset_paths.gd` is a content table like any other, and its
	# `barrier` column is the one value in it that rules read.
	# Placement stays the view's, seeded from the battle's own seed: the core knows which barriers
	# this battle has, how many shots each has left and who is behind each one, and no coordinates.
	for prop: Dictionary in AssetPaths.scatter_barrier_props(battle.battle_type):
		var tier: StringName = prop["barrier"]
		battle.barriers.append({"prop": StringName(prop["id"]), "tier": tier,
				"shots": _roll_shots(state, tier), "destroyed": false})


static func _roll_shots(state: GameState, tier: StringName) -> int:
	# 發數以 battle 亂數軌於區間內抽定 (戰鬥.md): one call per barrier, at 佈陣 time.
	var band: Array = BARRIER_SHOTS[tier]
	return state.rng.randi_range(&"battle", int(band[0]), int(band[1]))


static func _irregular_unit(state: GameState, grade: StringName, coeff: int, siege: bool) -> Dictionary:
	# 非正規軍: anonymous tiers, 預設近戰列; 帶攻城 units sit in the ranged row (戰鬥.md).
	var stats: Array = GRADE_STATS[grade]
	var hp: int = Difficulty.scale_enemy_stat(state, int(stats[1]) * coeff)
	return {
		"card_id": &"", "grade": grade, "regular": false,
		"side": &"enemy", "faction": &"enemy",
		"attack": Difficulty.scale_enemy_stat(state, int(stats[0]) * coeff),
		"hp": hp, "max_hp": hp,
		"strength": (int(stats[0]) + int(stats[1])) * coeff,
		"row": &"ranged" if siege else &"melee",
		"flags": ([&"siege"] if siege else []) as Array,
		"accuracy": ENEMY_ACCURACY, "dodge": ENEMY_DODGE, "speed": ENEMY_SPEED,
		"progress": 0.0, "instance": null, "stationed": false, "screened_by": &"", "cover": &"",
	}


static func regular_force(state: GameState, budget: float, side: StringName, faction: StringName, rival: Rivals.RivalState) -> Array[Dictionary]:
	# 正規軍 conversion (WW3): a strength budget becomes real-roster units at baseline
	# stats. Composition gap decided greedy strongest-first (docs/decisions.md, W12);
	# 國策限定 and support (no_attack) types stay out of the conversion roster.
	# Used by 文明戰爭 (enemy side, one rival) and 世界大戰 (both camps, per civ).
	var units: Array[Dictionary] = []
	for card_id: StringName in regular_roster_desc(state):
		var strength: float = float(_type_strength(state, card_id))
		while budget >= strength:
			budget -= strength
			units.append(regular_unit(state, card_id, side, faction, rival))
	return units


static func regular_screens(units: Array[Dictionary], side: StringName) -> Array[Dictionary]:
	# 正規軍也出盾陣掩護自己的遠程列 (戰鬥.md 對手兩型, ADR-0008). A wave that brings a 遠程列
	# regular brings one wall segment with it — one card is one segment spanning that row's
	# frontage. Never 防空飛彈 (enemy civs field no anti-air, ADR-0006) and never repairable:
	# the 正規軍 roster excludes 不主動攻擊 types, so there is no enemy 工兵團 and a suppressed
	# enemy screen stays down. 非正規軍 field no works at all, so a 帶攻城 irregular standing in
	# the ranged row still gets nothing.
	# Only the enemy camp: on the player's side the 工事線 is the player's own two slots and its
	# engineer's beat, and allied 正規軍 must not eat them (docs/decisions.md, W14.7).
	var screens: Array[Dictionary] = []
	if side != &"enemy":
		return screens
	for unit: Dictionary in units:
		if bool(unit["regular"]) and unit["row"] == &"ranged":
			screens.append(_screen_fort())
			break
	return screens


static func _screen_fort() -> Dictionary:
	# The enemy's wall is the same 盾陣 the player fields, minus an owner card instance: era form
	# resolves from card_id at render time, and 運作中／被禁用 is its whole state (ADR-0007).
	return {"card_id": &"shield_wall",
			"flags": (CardsData.CARDS[&"shield_wall"]["flags"] as Array).duplicate(),
			"disabled": false, "shots": 0}   # armed by `_arm_wall` when the wave lands it


static func _regular_army_wave(state: GameState, battle: BattleField, share: float) -> Array[Dictionary]:
	# 文明戰爭 wave: rival power × 0.5 × share (對手文明 三波總實力預算).
	var rival := Rivals.find(state, battle.rival_id)
	return regular_force(state, rival.power * 0.5 * share, &"enemy", &"enemy", rival)


static func regular_roster_desc(state: GameState) -> Array[StringName]:
	# Unit types formed this era, strongest first (ties: catalog order).
	var idx: int = Era.index(state.generation)
	var roster: Array[StringName] = []
	for card_id: StringName in CardsData.CARDS.keys():
		var entry: Dictionary = CardsData.CARDS[card_id]
		if not Cards.is_unit(card_id) or entry["source_kind"] == &"policy":
			continue
		if (entry["flags"] as Array).has(&"no_attack") or not Cards.has_form(card_id, idx):
			continue
		roster.append(card_id)
	roster.sort_custom(func(a: StringName, b: StringName) -> bool:
		return _type_strength(state, a) > _type_strength(state, b))
	return roster


static func _cheapest_regular_type(state: GameState) -> StringName:
	var roster := regular_roster_desc(state)
	if roster.is_empty():
		return &"infantry"
	return roster[roster.size() - 1]


static func weakest_regular_strength(state: GameState) -> int:
	# The smallest budget that converts into one 正規軍 unit (WorldWar's too-weak guard).
	return _type_strength(state, _cheapest_regular_type(state))


static func _type_strength(state: GameState, card_id: StringName) -> int:
	var entry: Dictionary = CardsData.CARDS[card_id]
	return (int(entry["attack"]) + int(entry["hp"])) * Era.coeff(state.generation)


static func regular_unit(state: GameState, card_id: StringName, side: StringName, faction: StringName, rival: Rivals.RivalState) -> Dictionary:
	# Real roster type at era-baseline 攻/血, engine-default三值, no roll/growth (WW3).
	# faction = 戰功 attribution tag (WW5: the owning civ id in 世界大戰; &"enemy" in the
	# single-rival 文明戰爭). A psyops-discounted rival's units fight discounted wherever
	# they appear, allied camp included (docs/decisions.md, W12.5).
	var entry: Dictionary = CardsData.CARDS[card_id]
	var coeff: int = Era.coeff(state.generation)
	var attack: int = Difficulty.scale_enemy_stat(state, int(entry["attack"]) * coeff)
	if rival != null:
		# 被心戰過的對手: 攻擊力照累計折扣打折 (−10%/次, 7折封頂)
		attack = maxi(int(round(float(attack) * Rivals.attack_multiplier(rival))), 1)
	var hp: int = Difficulty.scale_enemy_stat(state, int(entry["hp"]) * coeff)
	return {
		"card_id": card_id, "grade": &"", "regular": true,
		"side": side, "faction": faction,
		"attack": attack,
		"hp": hp, "max_hp": hp,
		"strength": _type_strength(state, card_id),
		"row": entry["row"], "flags": (entry["flags"] as Array).duplicate(),
		"accuracy": ENEMY_ACCURACY, "dodge": ENEMY_DODGE, "speed": ENEMY_SPEED,
		"progress": 0.0, "instance": null, "stationed": false, "screened_by": &"", "cover": &"",
	}


# --- internals: units, forts, skills ---

static func _unit_from_card(state: GameState, battle: BattleField, instance: Cards.CardInstance) -> Dictionary:
	var entry: Dictionary = Cards.card(instance.id)
	var hp: int = Cards.hp_of(instance)
	return {
		"card_id": instance.id, "grade": &"", "regular": false,
		"side": &"player", "faction": &"player",
		"attack": Cards.attack_of(instance), "hp": hp, "max_hp": hp,
		"strength": Cards.attack_of(instance) + Cards.hp_of(instance),
		"row": entry["row"], "flags": (entry["flags"] as Array).duplicate(),
		"accuracy": _snapshot_accuracy(state, battle, instance),
		"dodge": Cards.dodge_of(state, instance),
		"speed": Cards.speed_of(state, instance),
		"progress": 0.0, "instance": instance, "stationed": false, "screened_by": &"", "cover": &"",
	}


static func _snapshot_accuracy(state: GameState, battle: BattleField, instance: Cards.CardInstance) -> float:
	# 文化國心戰 (D16) is battle-scoped (下場戰 only), so it lands here in the snapshot
	# layer, not inside Cards.accuracy_of — psyops_active lives on this BattleField.
	var accuracy: float = Cards.accuracy_of(state, instance)
	if battle.psyops_active:
		accuracy = maxf(accuracy - RivalData.ENEMY_PSYOPS_ACCURACY_DEBUFF, 0.0)
	return accuracy


static func _refresh_player_stats(state: GameState, battle: BattleField) -> void:
	# Growth effects land 自下一回合生效 (D13): re-snapshot the quality three at every
	# boundary so mid-battle medals apply from the next window automatically.
	for unit: Dictionary in battle.player_units:
		var instance: Cards.CardInstance = unit["instance"]
		if instance == null:
			continue
		unit["accuracy"] = _snapshot_accuracy(state, battle, instance)
		unit["dodge"] = Cards.dodge_of(state, instance)
		unit["speed"] = Cards.speed_of(state, instance)


static func _fort_from_card(state: GameState, instance: Cards.CardInstance) -> Dictionary:
	# 運作中／被禁用 is the fort's whole state (ADR-0007) — no hit points, no damage counter. A
	# 盾陣 additionally carries how many shots its current wall can still absorb (ADR-0010): a
	# budget is not a health bar, it is spent by absorbing and refilled by the engineer.
	var fort: Dictionary = {"card_id": instance.id,
			"flags": (Cards.card(instance.id)["flags"] as Array).duplicate(),
			"disabled": false, "shots": 0}
	_arm_wall(state, fort)
	return fort


static func _arm_wall(state: GameState, fort: Dictionary) -> void:
	# 每道牆佈陣時抽定 3～5 發吸收上限，吸滿即失效待修，修好後重抽 (戰鬥.md 工事卡, ADR-0010).
	# Re-rolled on repair rather than remembered, so 同場上限 2 is not a lottery the player cannot
	# see (docs/decisions.md W14.9). 防空飛彈 absorbs nothing, so it never carries a budget.
	if (fort["flags"] as Array).has(&"screens_ranged_row"):
		fort["shots"] = _roll_shots(state, WALL_TIER)


static func _repair_forts(state: GameState, battle: BattleField, events: Array[Dictionary]) -> void:
	# 工兵團每回合修復一個待修工事 (ADR-0007). Presence timing no longer matters — only that an
	# engineer stands on the side when the repair runs, so later waves clear an older backlog.
	# Multiple disabled forts take turns: the cursor advances past the one just repaired, so a
	# fort that keeps getting re-disabled can't starve its neighbour.
	if battle.player_forts.is_empty() or not _has_engineer(battle.player_units):
		return
	var count: int = battle.player_forts.size()
	for offset: int in range(count):
		var i: int = (battle.repair_cursor + offset) % count
		var fort: Dictionary = battle.player_forts[i]
		if not bool(fort["disabled"]):
			continue
		fort["disabled"] = false
		_arm_wall(state, fort)   # 修好後重抽發數 (ADR-0010)
		battle.repair_cursor = (i + 1) % count
		events.append({"tick": 0, "type": &"repair", "side": &"player",
				"card_id": fort["card_id"], "card_id_uid": _uid(fort)})
		if (fort["flags"] as Array).has(&"screens_ranged_row"):
			# 修復再啟用 restores the cover, so the row it screens says so again at this tick —
			# the wall may have gone down and come back inside one round (docs/decisions.md W14.6).
			_station_side(battle.player_units, battle.player_forts, events, true)
		return   # one per round


static func _take_stations(battle: BattleField, events: Array[Dictionary]) -> void:
	# 自動佈陣＝一條掩護鏈 (ADR-0008): a unit takes its station the round it joins the field, and
	# the event names the wall that covers it. It re-announces when that cover changes under it —
	# a wall deployed behind it, a wall permanently stripped — and `_repair_forts` forces the
	# announcement after a repair, so a replayer never shows a covered row as bare
	# (architecture.md §Timeline event contract; docs/decisions.md W14.6).
	_station_side(battle.player_units, battle.player_forts, events)
	_station_side(battle.enemy_units, battle.enemy_forts, events)


static func _station_side(units: Array[Dictionary], forts: Array[Dictionary], events: Array[Dictionary], force: bool = false) -> void:
	var index: int = _first_active_fort(forts, &"screens_ranged_row")
	var screen: StringName = forts[index]["card_id"] if index >= 0 else &""
	var screen_uid: int = _uid(forts[index]) if index >= 0 else 0
	for unit: Dictionary in units:
		if int(unit["hp"]) <= 0:
			continue
		# 空域不佔地面位 and the 近戰列 stands in front of the wall: only the 遠程列 is screened.
		var screened: bool = unit["row"] == &"ranged"
		var cover: StringName = screen if screened else &""
		if bool(unit["stationed"]) and StringName(unit["screened_by"]) == cover \
				and not (force and screened):
			continue
		unit["stationed"] = true
		unit["screened_by"] = cover
		events.append({"tick": 0, "type": &"take_station", "side": unit["side"],
				"unit": _unit_label(unit), "unit_uid": _uid(unit), "row": unit["row"],
				"screened_by": cover, "screened_by_uid": screen_uid if cover != &"" else 0})


static func _has_engineer(units: Array[Dictionary]) -> bool:
	for unit: Dictionary in units:
		if int(unit["hp"]) > 0 and (unit["flags"] as Array).has(&"repairs_fortifications"):
			return true
	return false


# --- internals: 中立掩體 (neutral cover, ADR-0010) ---

static func _seek_cover_all(battle: BattleField, events: Array[Dictionary]) -> void:
	# The 下一個機會 pass: a unit whose barrier was destroyed under it, and any hurt survivor that
	# had nowhere to go when it was hit. Player units in deploy order, then enemy units — the same
	# fixed order the tick window rides on, which is what makes 先到先用 deterministic.
	if battle.barriers.is_empty():
		return
	for unit: Dictionary in battle.player_units:
		_seek_cover(battle, unit, 0, events)
	for unit: Dictionary in battle.enemy_units:
		_seek_cover(battle, unit, 0, events)


static func _seek_cover(battle: BattleField, unit: Dictionary, tick: int, events: Array[Dictionary]) -> void:
	# 受傷的陸軍單位會自動退到還完好的掩體後面 (戰鬥.md 場景呈現). 受傷 ＝ any hit point lost
	# (docs/decisions.md W14.9), so the fallback lands the moment a unit is first hit. 掩體先到先用、
	# 敵我都能用, one unit per barrier; 空域單位不用掩體 (scatter is ground dressing, ADR-0006 owns
	# air). The player never picks who hides where.
	if int(unit["hp"]) <= 0 or int(unit["hp"]) >= int(unit["max_hp"]) or _is_air(unit):
		return
	if StringName(unit["cover"]) != &"":
		return
	for barrier: Dictionary in battle.barriers:
		if bool(barrier["destroyed"]) or not _barrier_free(battle, StringName(barrier["prop"])):
			continue
		unit["cover"] = barrier["prop"]
		events.append({"tick": tick, "type": &"take_cover", "side": unit["side"],
				"unit": _unit_label(unit), "unit_uid": _uid(unit),
				"barrier": barrier["prop"], "tier": barrier["tier"]})
		return


static func _barrier_free(battle: BattleField, prop: StringName) -> bool:
	# Occupancy lives on the unit, not on the barrier: a dead unit stops occupying its rock the
	# moment it dies, without anyone having to remember to release it.
	for units: Array[Dictionary] in [battle.player_units, battle.enemy_units]:
		for unit: Dictionary in units:
			if int(unit["hp"]) > 0 and StringName(unit["cover"]) == prop:
				return false
	return true


static func _cover_of(battle: BattleField, unit: Dictionary) -> Dictionary:
	# The intact barrier this unit is behind, or {} — a destroyed one absorbs nothing.
	var prop: StringName = unit["cover"]
	if prop == &"":
		return {}
	for barrier: Dictionary in battle.barriers:
		if StringName(barrier["prop"]) == prop and not bool(barrier["destroyed"]):
			return barrier
	return {}


static func _absorb_wall(fort: Dictionary, attacker: Dictionary, tick: int, events: Array[Dictionary]) -> void:
	# 吸收一發射向遠程列的遠程火力，無視攻擊力; 吸滿發數即失效待修 — disabled, never removed
	# (ADR-0007 lifecycle, ADR-0010 trigger).
	fort["shots"] = int(fort["shots"]) - 1
	if int(fort["shots"]) <= 0:
		fort["disabled"] = true
	events.append({"tick": tick, "type": &"intercept", "side": attacker["side"],
			"by": _unit_label(attacker), "by_uid": _uid(attacker),
			"card_id": fort["card_id"], "card_id_uid": _uid(fort), "barrier": &"",
			"shots_left": maxi(int(fort["shots"]), 0)})


static func _absorb_barrier(battle: BattleField, barrier: Dictionary, attacker: Dictionary, tick: int, events: Array[Dictionary]) -> void:
	# A 中立掩體 absorbs exactly as a wall does, and then dies where a wall would wait for the
	# engineer: 散景不是工事，吸滿發數就永久消失 (戰鬥.md 場景呈現).
	barrier["shots"] = int(barrier["shots"]) - 1
	events.append({"tick": tick, "type": &"intercept", "side": attacker["side"],
			"by": _unit_label(attacker), "by_uid": _uid(attacker),
			"card_id": &"", "card_id_uid": 0, "barrier": barrier["prop"],
			"shots_left": maxi(int(barrier["shots"]), 0)})
	if int(barrier["shots"]) > 0:
		return
	barrier["destroyed"] = true
	events.append({"tick": tick, "type": &"barrier_destroyed", "side": attacker["side"],
			"by": _unit_label(attacker), "by_uid": _uid(attacker), "barrier": barrier["prop"]})
	# Whoever was behind it is exposed again, and falls back to another intact barrier at the next
	# opportunity if one is free (docs/decisions.md W14.9).
	for units: Array[Dictionary] in [battle.player_units, battle.enemy_units]:
		for unit: Dictionary in units:
			if StringName(unit["cover"]) != StringName(barrier["prop"]):
				continue
			unit["cover"] = &""
			if int(unit["hp"]) <= 0:
				continue
			events.append({"tick": tick, "type": &"take_cover", "side": unit["side"],
					"unit": _unit_label(unit), "unit_uid": _uid(unit),
					"barrier": &"", "tier": &""})


static func _cast_skill(state: GameState, battle: BattleField, instance: Cards.CardInstance) -> void:
	var flags: Array = Cards.card(instance.id)["flags"]
	if flags.has(&"attack_buff_2_rounds"):
		battle.attack_buff_rounds = 2   # applied at fire time to every friendly unit
	elif flags.has(&"cost_discount_2_rounds"):
		battle.cost_discount_rounds = 2
	elif flags.has(&"destroy_non_leader_after_round_5"):
		battle.love_and_peace_armed = true
	elif flags.has(&"destroy_non_leader"):
		var events: Array[Dictionary] = []
		_destroy_one_non_leader(battle, events, 0)
		battle.last_timeline.append_array(events)
	elif flags.has(&"convert_non_leader"):
		for i: int in range(battle.enemy_units.size()):
			var enemy: Dictionary = battle.enemy_units[i]
			if _is_non_leader(enemy):
				battle.enemy_units.remove_at(i)
				enemy["side"] = &"player"
				enemy["faction"] = &"player"
				enemy["row"] = &"melee"
				enemy["stationed"] = false   # 投誠者重新就位: new side, new layer of the chain
				battle.player_units.append(enemy)
				break


static func _is_non_leader(unit: Dictionary) -> bool:
	# 首領＝硬級; non-leader skills touch only weak/medium 非正規軍, never 正規軍 (卡牌.md).
	return not bool(unit["regular"]) and unit["grade"] != &"hard" and int(unit["hp"]) > 0


static func _destroy_one_non_leader(battle: BattleField, events: Array[Dictionary], tick: int) -> void:
	for unit: Dictionary in battle.enemy_units:
		if _is_non_leader(unit):
			unit["hp"] = 0
			events.append({"tick": tick, "type": &"death", "side": &"player",
					"victim": _unit_label(unit), "victim_uid": _uid(unit),
					"by": &"skill", "by_uid": 0, "faction": unit["faction"]})
			_credit_clear(battle, &"player", unit)
			return


# --- internals: the tick window ---

static func _resolve_window(state: GameState, battle: BattleField, events: Array[Dictionary]) -> void:
	# Units act on their own attack speed via per-unit accumulators that carry across
	# rounds (speed 0.6 = an attack roughly every 1.67 windows). Within a tick, player
	# units fire before enemy units, each side in deploy order — fixed order is part of
	# the determinism contract (docs/implementation-notes.md).
	# 防空飛彈 opens the window: a fort has no 攻速, so its one shot per round lands on the
	# first tick — ahead of the strikes that suppress it, which is what makes the 防空+工兵
	# loop an exchange instead of permanent suppression (docs/decisions.md, W14.5).
	_fire_anti_air(state, battle, 1, events)
	for tick: int in range(1, TICKS_PER_ROUND + 1):
		for unit: Dictionary in battle.player_units:
			_accumulate_and_fire(state, battle, unit, tick, events)
		for unit: Dictionary in battle.enemy_units:
			_accumulate_and_fire(state, battle, unit, tick, events)


static func _accumulate_and_fire(state: GameState, battle: BattleField, unit: Dictionary, tick: int, events: Array[Dictionary]) -> void:
	if int(unit["hp"]) <= 0 or float(unit["speed"]) <= 0.0:
		return   # the dead don't fire: 快的先打，先打的活下來 (D6)
	if (unit["flags"] as Array).has(&"no_attack") or int(unit["attack"]) <= 0:
		return
	unit["progress"] = float(unit["progress"]) + float(unit["speed"]) / float(TICKS_PER_ROUND)
	while float(unit["progress"]) >= 1.0 and int(unit["hp"]) > 0:
		unit["progress"] = float(unit["progress"]) - 1.0
		var before: int = events.size()
		_fire(state, battle, unit, tick, events)
		# 命中率 XP: 出手攻擊 (D9) — any attack action taken (disable/intercept/miss/dodge/hit
		# all emit an event); a fire with nothing to shoot at emits none and accrues none.
		if events.size() > before:
			_grant_battle_xp(unit, &"accuracy", tick, events)


static func _fire(state: GameState, battle: BattleField, attacker: Dictionary, tick: int, events: Array[Dictionary]) -> void:
	# Side is structural (which camp array the unit fights in); faction is the 戰功
	# attribution tag (WW5) — allied 正規軍 are player-side but carry their civ's faction.
	var player_side: bool = attacker["side"] == &"player"
	var defenders: Array[Dictionary] = battle.enemy_units if player_side else battle.player_units
	var defender_forts: Array[Dictionary] = battle.enemy_forts if player_side else battle.player_forts
	var flags: Array = attacker["flags"]
	var kind: StringName = _attack_kind(attacker)
	# 帶攻城／空襲者優先癱瘓運作中的敵方工事 (ADR-0007): one hit disables, no accuracy roll, the
	# fort stays on the field. A disabled fort is inert and no longer a target, so a second
	# sieger goes for units instead of re-hitting the wreck.
	if flags.has(&"siege") or flags.has(&"air_strike"):
		var busted: int = _first_active_fort(defender_forts)
		if busted >= 0:
			defender_forts[busted]["disabled"] = true
			events.append({"tick": tick, "type": &"disable", "side": attacker["side"],
					"by": _unit_label(attacker), "by_uid": _uid(attacker),
					"card_id": defender_forts[busted]["card_id"],
					"card_id_uid": _uid(defender_forts[busted])})
			return
	var target: Dictionary = _pick_target(defenders, kind)
	if target.is_empty():
		return   # 近戰打不到空域、空襲打不到空域: no legal target = no attack this shot
	# 掩體擋的是子彈，不是人 (ADR-0010). Only 遠程列 fire is absorbed, and it is absorbed BEFORE any
	# roll: 無視攻擊力 means the shot never resolves at all, so an accurate shot and a blind one cost
	# the same one from the budget. 近戰 walks around a wall and engages the row directly; 空襲 comes
	# from above it and is never absorbed; shots at 空域 bypass the 工事線 entirely, since a wall on
	# the ground cannot absorb a shot at the sky (ADR-0006, docs/decisions.md W14.9).
	if kind == &"ranged":
		# The 工事線 stands in front of the WHOLE 遠程列, so a wall answers before anything the
		# target found for itself; a screen with no 遠程列 unit behind it still never fires
		# (docs/decisions.md W14.6). A 中立掩體 covers its occupant in any row, and is what is left
		# once the wall is down.
		if target["row"] == &"ranged":
			var shield: int = _first_active_fort(defender_forts, &"screens_ranged_row")
			if shield >= 0:
				_absorb_wall(defender_forts[shield], attacker, tick, events)
				return
		var barrier: Dictionary = _cover_of(battle, target)
		if not barrier.is_empty():
			_absorb_barrier(battle, barrier, attacker, tick, events)
			return
	# accuracy roll, then dodge roll — both on the &"battle" track, in this order.
	if not state.rng.chance(&"battle", float(attacker["accuracy"]) / 100.0):
		events.append({"tick": tick, "type": &"miss", "side": attacker["side"],
				"by": _unit_label(attacker), "by_uid": _uid(attacker),
				"target": _unit_label(target), "target_uid": _uid(target)})
		return
	if state.rng.chance(&"battle", float(target["dodge"]) / 100.0):
		events.append({"tick": tick, "type": &"dodge", "side": target["side"],
				"by": _unit_label(target), "by_uid": _uid(target),
				"attacker": _unit_label(attacker), "attacker_uid": _uid(attacker)})
		_grant_battle_xp(target, &"dodge", tick, events)   # 被攻擊且活下來 (D9)
		return
	var damage: int = int(attacker["attack"])
	if player_side and battle.attack_buff_rounds > 0:
		damage += 1   # 軍歌: 兩回合內全體 +1 攻
	target["hp"] = int(target["hp"]) - damage
	events.append({"tick": tick, "type": &"hit", "side": attacker["side"],
			"by": _unit_label(attacker), "by_uid": _uid(attacker),
			"target": _unit_label(target), "target_uid": _uid(target), "damage": damage})
	if int(target["hp"]) > 0:
		# 閃避率 XP: survived the hit (被攻擊且活下來). A miss accrues nothing — the attack
		# never reached the unit (docs/decisions.md, W13). The killing blow accrues nothing.
		_grant_battle_xp(target, &"dodge", tick, events)
		# ...and a land unit that has just lost hit points falls back behind cover (ADR-0010).
		_seek_cover(battle, target, tick, events)
	if int(target["hp"]) <= 0:
		events.append({"tick": tick, "type": &"death", "side": attacker["side"],
				"victim": _unit_label(target), "victim_uid": _uid(target),
				"by": _unit_label(attacker), "by_uid": _uid(attacker),
				"faction": target["faction"]})
		_credit_clear(battle, attacker["faction"], target)
		if player_side and (attacker["flags"] as Array).has(&"plunder"):
			battle.plunder += 5 * Era.coeff(state.generation)   # 掠奪: 它清除的單位


static func _fire_anti_air(state: GameState, battle: BattleField, tick: int, events: Array[Dictionary]) -> void:
	# 防空飛彈 (ADR-0006): every ACTIVE battery fires once per round window at one 空域 unit and
	# a hit destroys it outright — the fort carries no attack value, so it ignores hit points
	# exactly as it ignores attack values when it blocks. 一發飛彈就是一架飛機.
	_fire_batteries(state, battle, battle.player_forts, battle.enemy_units, &"player", tick, events)
	_fire_batteries(state, battle, battle.enemy_forts, battle.player_units, &"enemy", tick, events)


static func _fire_batteries(state: GameState, battle: BattleField, forts: Array[Dictionary], defenders: Array[Dictionary], faction: StringName, tick: int, events: Array[Dictionary]) -> void:
	# Engine defaults resolve the shot (命中 100%, no 品質三項, the same precedent as every
	# enemy unit); the target's 閃避率 still rolls. No air target = no fire, no roll.
	for fort: Dictionary in forts:
		if bool(fort["disabled"]) or not (fort["flags"] as Array).has(&"fires_at_air"):
			continue
		var target: Dictionary = _pick_air_target(defenders)
		if target.is_empty():
			continue
		var label: StringName = fort["card_id"]
		var label_uid: int = _uid(fort)
		if not state.rng.chance(&"battle", ENEMY_ACCURACY / 100.0):
			events.append({"tick": tick, "type": &"miss", "side": faction,
					"by": label, "by_uid": label_uid,
					"target": _unit_label(target), "target_uid": _uid(target)})
			continue
		if state.rng.chance(&"battle", float(target["dodge"]) / 100.0):
			events.append({"tick": tick, "type": &"dodge", "side": target["side"],
					"by": _unit_label(target), "by_uid": _uid(target),
					"attacker": label, "attacker_uid": label_uid})
			_grant_battle_xp(target, &"dodge", tick, events)   # 被攻擊且活下來 (D9)
			continue
		target["hp"] = 0   # 命中即擊落: the missile ignores hit points
		events.append({"tick": tick, "type": &"shootdown", "side": faction,
				"by": label, "by_uid": label_uid,
				"target": _unit_label(target), "target_uid": _uid(target)})
		events.append({"tick": tick, "type": &"death", "side": faction,
				"victim": _unit_label(target), "victim_uid": _uid(target),
				"by": label, "by_uid": label_uid, "faction": target["faction"]})
		_credit_clear(battle, faction, target)


static func _credit_clear(battle: BattleField, clearer: StringName, target: Dictionary) -> void:
	# 戰功＝清除的實力總和 (攻+血), credited to the clearer's faction tag (WW5);
	# battle.merit stays the player's OWN tally.
	battle.merit_by_faction[clearer] = int(battle.merit_by_faction.get(clearer, 0)) \
			+ int(target["strength"])
	battle.last_clear_by_side[target["side"]] = clearer
	if clearer == &"player":
		battle.merit += int(target["strength"])


static func _attack_kind(unit: Dictionary) -> StringName:
	if unit["row"] == &"ranged":
		return &"ranged"
	if unit["row"] == &"air" or (unit["flags"] as Array).has(&"air_strike"):
		return &"air"
	return &"melee"


static func _is_air(unit: Dictionary) -> bool:
	return unit["row"] == &"air" or (unit["flags"] as Array).has(&"non_land")


static func _first_active_fort(forts: Array[Dictionary], required_flag: StringName = &"") -> int:
	for i: int in range(forts.size()):
		var fort: Dictionary = forts[i]
		if bool(fort["disabled"]):
			continue
		if required_flag != &"" and not (fort["flags"] as Array).has(required_flag):
			continue
		return i
	return -1


static func _pick_target(defenders: Array[Dictionary], kind: StringName) -> Dictionary:
	# Targeting matrix (ADR-0006), focus fire in deploy order within each band (W3 gap
	# decision): 近戰列 fights the enemy melee row, then its GROUND backline, and can NEVER
	# reach 空域; 遠程列 selects freely, 空域 included — ranged fire is the baseline air
	# answer every roster can carry; 空襲 hits ground targets only (no air-to-air).
	if kind == &"melee":
		for unit: Dictionary in defenders:
			if int(unit["hp"]) > 0 and unit["row"] == &"melee":
				return unit
	for unit: Dictionary in defenders:
		if int(unit["hp"]) <= 0:
			continue
		if kind != &"ranged" and _is_air(unit):
			continue
		return unit
	return {}


static func _pick_air_target(defenders: Array[Dictionary]) -> Dictionary:
	for unit: Dictionary in defenders:
		if int(unit["hp"]) > 0 and _is_air(unit):
			return unit
	return {}


static func _grant_battle_xp(unit: Dictionary, stat: StringName, tick: int, events: Array[Dictionary]) -> void:
	# D9/D13: XP accrues only on the player's real instances (enemies and 勸降-converted
	# units carry instance == null and never grow). When a stat's XP fills, the medal lands
	# 當場 at this tick — visible in the timeline; its effect applies from the next round's
	# stat re-snapshot (自下一回合生效).
	var instance: Cards.CardInstance = unit["instance"]
	if instance == null:
		return
	if Cards.grant_xp(instance, stat):
		events.append({"tick": tick, "type": &"medal", "side": unit["side"],
				"unit": _unit_label(unit), "unit_uid": _uid(unit), "stat": stat,
				"level": int(instance.levels.get(stat, 0))})


static func _unit_label(unit: Dictionary) -> StringName:
	return unit["card_id"] if unit["card_id"] != &"" else unit["grade"]


static func _assign_uids(battle: BattleField) -> void:
	# Per-entity identity for the replayers (architecture.md §Timeline event contract). A label is
	# a card id, so two 步兵團 on one side answer to the same one and no replayer could tell their
	# strikes apart; `uid` is the handle that can. Units and forts get one because their labels
	# repeat; a 中立掩體 does not, because a battle fields at most one instance per prop id.
	# Assigned by one fixed sweep over the field in arrival order, so the same seed hands out the
	# same numbers, and never reassigned — a 投誠 defector keeps its uid across the side change,
	# because it is the same regiment fighting for someone else.
	for group: Array[Dictionary] in [battle.player_units, battle.enemy_units,
			battle.player_forts, battle.enemy_forts]:
		for entity: Dictionary in group:
			if int(entity.get("uid", 0)) > 0:
				continue
			battle.next_uid += 1
			entity["uid"] = battle.next_uid


static func _uid(entity: Dictionary) -> int:
	# 0 ＝ this field names no unit and no fort: a 技能卡 kill, an unscreened row.
	return int(entity.get("uid", 0))


static func _sweep_dead(units: Array[Dictionary]) -> int:
	var removed: int = 0
	for i: int in range(units.size() - 1, -1, -1):
		if int(units[i]["hp"]) > 0:
			continue
		var dead: Dictionary = units[i]
		units.remove_at(i)
		removed += 1
		var instance: Cards.CardInstance = dead["instance"]
		if instance != null:
			Cards.wipe_growth(instance)   # D11: the institution survives, the veterans don't
	return removed


# --- internals: victory (exhaustion, D3) ---

static func _check_exhaustion(battle: BattleField) -> void:
	# D3 per camp (WW1): a side is exhausted when its field is empty AND it has nothing
	# left to commit — pending waves count for both sides (world war: allied arrivals).
	# 只剩空軍不算拿下戰場、敵我皆然 (ADR-0006): an exhausted side's opponent wins only with
	# 陸軍 afield. An air-only opponent keeps fighting — either side may still land ground
	# (the player by deploying, the enemy by pending waves) — until land claims the field or
	# the round cap rules 判輸.
	var enemy_exhausted: bool = battle.enemy_units.is_empty() \
			and not _pending_waves(battle, &"enemy")
	var player_committed_out: bool = battle.available.is_empty() or battle.conceded
	var player_exhausted: bool = battle.player_units.is_empty() and player_committed_out \
			and not _pending_waves(battle, &"player")
	if enemy_exhausted and _has_land(battle.player_units):
		battle.outcome = &"win"
	elif player_exhausted and _has_land(battle.enemy_units):
		battle.outcome = &"loss"
	elif player_exhausted and enemy_exhausted:
		# Mutual exhaustion with no land force to claim the field → 敗北 for the player
		# (conservative, docs/decisions.md W12).
		battle.outcome = &"loss"
	elif battle.round_cap == 0:
		_check_deadlock(battle)   # 世界大戰 has no cap to fall back on


static func _check_deadlock(battle: BattleField) -> void:
	# 世界大戰 僵局判定 (design/世界大戰.md, ADR-0006). With air unreachable by air, an uncapped
	# war can reach a field that can no longer change — mutually unreachable remnants, or one
	# camp exhausted while the other holds only air with no land left to commit. Settle it the
	# moment that happens: the camp still holding 陸軍 wins; nobody holding 陸軍 (or both) =
	# the player's camp loses (conservative, matching the mutual-exhaustion ruling).
	if _pending_waves(battle, &"player") or _pending_waves(battle, &"enemy"):
		return
	if not (battle.available.is_empty() or battle.conceded):
		return   # the player can still commit a card, so the field can still change
	if can_act(battle, &"player") or can_act(battle, &"enemy"):
		return
	var player_land: bool = _has_land(battle.player_units)
	battle.outcome = &"win" if player_land and not _has_land(battle.enemy_units) else &"loss"


static func has_pending_waves(battle: BattleField) -> bool:
	# Any arrivals left on either side (world war: allied waves too) — i.e. the field can still
	# change without anyone acting.
	return battle.next_wave < battle.waves.size()


static func can_act(battle: BattleField, side: StringName) -> bool:
	# Public read for callers that need "can this side still hit anything?" without replicating
	# the targeting matrix: the sim uses it to stop driving a frozen field, and the battle view
	# can use it to explain why a unit is idle (近戰打不到空域).
	if side == &"player":
		return _side_can_act(battle.player_units, battle.enemy_units, battle.player_forts)
	return _side_can_act(battle.enemy_units, battle.player_units, battle.enemy_forts)


static func _side_can_act(attackers: Array[Dictionary], defenders: Array[Dictionary], forts: Array[Dictionary]) -> bool:
	# Can this side still change the field? Any living attacker with a legal target under the
	# targeting matrix, or any active 防空 battery with an aircraft to shoot at.
	for unit: Dictionary in attackers:
		if int(unit["hp"]) <= 0 or float(unit["speed"]) <= 0.0:
			continue
		if (unit["flags"] as Array).has(&"no_attack") or int(unit["attack"]) <= 0:
			continue
		if not _pick_target(defenders, _attack_kind(unit)).is_empty():
			return true
	if _pick_air_target(defenders).is_empty():
		return false
	return _first_active_fort(forts, &"fires_at_air") >= 0


static func _pending_waves(battle: BattleField, side: StringName) -> bool:
	for i: int in range(battle.next_wave, battle.waves.size()):
		if battle.waves[i]["side"] == side:
			return true
	return false


static func _has_land(units: Array[Dictionary]) -> bool:
	# 工事不是部隊: forts never count toward the field-empty / land-holding checks (ADR-0007).
	for unit: Dictionary in units:
		if not _is_air(unit):
			return true
	return false
