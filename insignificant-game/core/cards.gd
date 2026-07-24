class_name Cards
extends RefCounted
# 卡牌 (design/卡牌.md): unlock gates, 單位品質 (grade + innate three rolled at acquisition),
# 成長 (medal levels per stat), deck economy (unified paid 解散, 戰後獎勵卡), era evolution
# incl. form-end auto-disband, strength. Catalog + quality bands in CardsData.
# Battle consumes 攻/血 via attack_of/hp_of (fixed per type+era, D8) and the quality three
# via accuracy_of/dodge_of/speed_of (innate + growth; W13 adds 老兵 floor + 心戰 debuff).
# Acquisition randomness lives on the &"cards" rng track; draw-order contract in
# docs/implementation-notes.md.

const UNLOCK_COST_BASE: int = 10
const DISBAND_COST_BASE: int = 8
const REWARD_DUPLICATE_COST_BASE: int = 5
const DECK_MINIMUM: int = 5

const QUALITY_STATS: Array[StringName] = [&"accuracy", &"dodge", &"speed"]  # fixed draw order


class CardInstance:
	extends RefCounted
	var id: StringName
	var tier: int = 1
	# 單位品質 (卡牌.md §單位品質): rolled once at acquisition for unit cards only;
	# fortification/skill instances never roll (grade stays &""). The roll survives death,
	# evolution, everything (D10/D12) — only 解散 destroys it, with the instance.
	var grade: StringName = &""    # &"bad" | &"medium" | &"good"; &"" = no quality
	var accuracy: float = 0.0      # innate 命中率 (percent)
	var dodge: float = 0.0         # innate 閃避率 (percent)
	var speed: float = 0.0         # innate 攻速 (attacks per round window)
	# 成長 (卡牌.md §成長): medal levels earned per stat (battle-automatic + 兵營-assigned,
	# both live here) and xp progress toward the next medal (accrued by battle, W13).
	# Death wipes both (D11) via wipe_growth; the innate roll above is never re-rolled.
	var levels: Dictionary = {}    # StringName stat -> int medal levels
	var xp: Dictionary = {}        # StringName stat -> int progress toward next medal

	func _init(card_id: StringName, card_tier: int) -> void:
		id = card_id
		tier = card_tier


# --- catalog queries ---

static func card(card_id: StringName) -> Dictionary:
	return CardsData.CARDS[card_id]


static func is_unit(card_id: StringName) -> bool:
	# Only unit cards (personnel/mechanical, incl. 國策限定部隊) carry quality.
	var cls: StringName = card(card_id)["class"]
	return cls == &"personnel" or cls == &"mechanical"


static func has_form(card_id: StringName, era_idx: int) -> bool:
	# Authoritative "does this card exist in this era" test: covers the early gate AND the
	# top-end cutoffs (聖戰士團 工業-only, 私掠傭兵團 ends before 資訊).
	var entry: Dictionary = card(card_id)
	if not bool(entry["evolves"]):
		return true   # skills are era-neutral
	return String((entry["era_names"] as Array)[clampi(era_idx, 1, 6) - 1]) != ""


static func form_name(card_id: StringName, tier: int) -> String:
	var entry: Dictionary = card(card_id)
	if not bool(entry["evolves"]):
		return String(entry["zh"])   # skills: the name IS the joke, era-neutral
	return String((entry["era_names"] as Array)[tier - 1])


static func display_name(instance: CardInstance) -> String:
	# Grade prefix rides the current era form (卡牌.md: 糟糕的長矛方陣); medium = no prefix.
	var prefix: String = String(CardsData.GRADE_PREFIX.get(instance.grade, ""))
	return prefix + form_name(instance.id, instance.tier)


static func attack_of(instance: CardInstance) -> int:
	var entry: Dictionary = card(instance.id)
	if not bool(entry["evolves"]):
		return int(entry["attack"])
	return int(entry["attack"]) * Era.COST_COEFF[instance.tier - 1]


static func hp_of(instance: CardInstance) -> int:
	var entry: Dictionary = card(instance.id)
	if not bool(entry["evolves"]):
		return int(entry["hp"])
	return int(entry["hp"]) * Era.COST_COEFF[instance.tier - 1]


static func military_cost_of(state: GameState, instance: CardInstance) -> int:
	var entry: Dictionary = card(instance.id)
	var base: int = int(entry["military_cost"])
	if entry["class"] == &"skill":
		# skills don't scale; 百家爭鳴: skill military cost −1, floor 1
		if state.policies.has(&"hundred_schools"):
			return maxi(base - 1, 1)
		return base
	return base * Era.COST_COEFF[instance.tier - 1]


# --- 單位品質: acquisition roll + effective stats ---

static func band_for(card_id: StringName, stat: StringName, grade: StringName) -> Array[float]:
	# Bad/Good bands extend one band-width below/above the Medium band, clamped
	# (卡牌.md §品質等級 夾限: 命中率 0–100、閃避率 0–50、攻速下限 0.1).
	var band: Array = (CardsData.QUALITY[card_id] as Dictionary)[stat]
	var lo: float = float(band[0])
	var hi: float = float(band[1])
	var width: float = (hi - lo) * CardsData.BAND_WIDTH_MULT
	match grade:
		&"bad":
			hi = lo
			lo = lo - width
		&"good":
			lo = hi
			hi = hi + width
	var floor_value: float = CardsData.SPEED_MIN if stat == &"speed" else 0.0
	var ceil_value: float = INF
	match stat:
		&"accuracy": ceil_value = CardsData.ACCURACY_MAX
		&"dodge": ceil_value = CardsData.DODGE_MAX
	return [clampf(lo, floor_value, ceil_value), clampf(hi, floor_value, ceil_value)]


static func roll_quality(state: GameState, instance: CardInstance) -> void:
	# 解鎖／取得的瞬間抽定 (卡牌.md §單位品質), on the &"cards" track. Draw order is a
	# determinism contract: one grade draw, then accuracy → dodge → speed; stats the card
	# lacks (工兵團: dodge only) consume NO draw.
	if not is_unit(instance.id):
		return
	var roll: float = state.rng.randf(&"cards")
	var cumulative: float = 0.0
	instance.grade = CardsData.GRADE_ORDER.back()   # float-edge guard (roll == 1.0)
	for g: StringName in CardsData.GRADE_ORDER:
		cumulative += float(CardsData.GRADE_PROBS[g])
		if roll < cumulative:
			instance.grade = g
			break
	var quality: Dictionary = CardsData.QUALITY[instance.id]
	for stat: StringName in QUALITY_STATS:
		if not quality.has(stat):
			continue
		var band: Array[float] = band_for(instance.id, stat, instance.grade)
		var value: float = lerpf(band[0], band[1], state.rng.randf(&"cards"))
		match stat:
			&"accuracy": instance.accuracy = value
			&"dodge": instance.dodge = value
			&"speed": instance.speed = value


static func accuracy_of(_state: GameState, instance: CardInstance) -> float:
	# Innate + medal levels ×3%/階, capped 100 (卡牌.md §成長). The state parameter is
	# reserved: W13 adds the 老兵 floor (軍事區) and 文化國 accuracy debuff here.
	var lv: int = int(instance.levels.get(&"accuracy", 0))
	return clampf(instance.accuracy + lv * float(CardsData.GROWTH_STEP[&"accuracy"]),
			0.0, CardsData.ACCURACY_MAX)


static func dodge_of(_state: GameState, instance: CardInstance) -> float:
	# Innate + medal levels ×2%/階, capped 50. State reserved for W13 (老兵 floor).
	var lv: int = int(instance.levels.get(&"dodge", 0))
	return clampf(instance.dodge + lv * float(CardsData.GROWTH_STEP[&"dodge"]),
			0.0, CardsData.DODGE_MAX)


static func speed_of(_state: GameState, instance: CardInstance) -> float:
	# Innate + medal levels ×0.1/階, 無封頂 (the D14 runaway is bounded by 兵營 production
	# rate, not structure). State reserved for W13 (老兵 floor).
	var lv: int = int(instance.levels.get(&"speed", 0))
	return maxf(instance.speed + lv * float(CardsData.GROWTH_STEP[&"speed"]), 0.0)


# --- 成長 primitives (accrual rules land in W13; battle applies death in W12) ---

static func award_medal(instance: CardInstance, stat: StringName) -> int:
	# One 勳章 = +1 level on one stat (D13/D14). No per-card cap. Returns the new level.
	var lv: int = int(instance.levels.get(stat, 0)) + 1
	instance.levels[stat] = lv
	return lv


static func wipe_growth(instance: CardInstance) -> void:
	# 陣亡 → 已獲成長全部歸零 (D11): all medals from both sources and all xp. The innate
	# three and grade stay — death never re-rolls (D12: 訓練傳統 survives the veterans).
	instance.levels = {}
	instance.xp = {}


# --- unlocking ---

static func tech_gate(state: GameState) -> int:
	# Gate to buy the CURRENT era's tier: 時代序×10; 文字與曆法 → ×8; 政教合一 +2×序.
	var idx: int = Era.index(state.generation)
	var mult: int = 8 if state.policies.has(&"writing_calendar") else 10
	var gate: int = idx * mult
	if state.policies.has(&"theocracy"):
		gate += 2 * idx
	return gate


static func unlock_cost(state: GameState) -> int:
	var cost: int = UNLOCK_COST_BASE * Era.coeff(state.generation)
	if state.policies.has(&"patent_system"):
		@warning_ignore("integer_division")
		cost = cost / 2
	return cost


static func source_satisfied(state: GameState, card_id: StringName) -> bool:
	var entry: Dictionary = card(card_id)
	var source: StringName = entry["source"]
	match entry["source_kind"]:
		&"region":
			return state.regions.has(source)
		&"building":
			return state.buildings.has(source)
		&"policy":
			return state.policies.has(source)
		&"legacy":
			return state.legacies.has(source)
	return false


static func can_unlock(state: GameState, card_id: StringName) -> Dictionary:
	if not CardsData.CARDS.has(card_id):
		return {"ok": false, "reason": &"unknown_card"}
	if state.unlocked_cards.has(card_id):
		return {"ok": false, "reason": &"already_unlocked"}
	var entry: Dictionary = card(card_id)
	if bool(entry["destroyed_on_use"]) and state.flags.get(&"destroyed_cards", []).has(card_id):
		return {"ok": false, "reason": &"permanently_destroyed"}   # 本局不再取得
	if not has_form(card_id, Era.index(state.generation)):
		return {"ok": false, "reason": &"no_form_this_era"}
	if not source_satisfied(state, card_id):
		return {"ok": false, "reason": &"source_missing"}
	if state.tech < tech_gate(state):
		return {"ok": false, "reason": &"tech_gate"}
	return {"ok": true, "reason": &""}


static func unlock(state: GameState, card_id: StringName) -> Dictionary:
	# 先付錢、後開品質 — 買卡是賭 (卡牌.md §解鎖規則): the quality roll happens inside
	# _new_instance, after the money is gone.
	var check: Dictionary = can_unlock(state, card_id)
	if not bool(check["ok"]):
		return check
	var cost: int = unlock_cost(state)
	state.treasury -= cost   # may go negative
	state.unlocked_cards.append(card_id)
	var instance := _new_instance(state, card_id)
	state.deck.append(instance)
	return {"ok": true, "reason": &"", "cost": cost, "tier": instance.tier, "grade": instance.grade}


# --- 戰後獎勵卡 (卡牌.md 卡牌經濟; battle calls roll_reward at battle end, W12) ---

static func reward_pool(state: GameState) -> Array[StringName]:
	# Current-era-formed normal cards. 國策限定 and Legacy-granted cards never enter the
	# pool; region/tech gates do NOT apply here.
	var idx: int = Era.index(state.generation)
	var pool: Array[StringName] = []
	for card_id: StringName in CardsData.CARDS.keys():
		var entry: Dictionary = CardsData.CARDS[card_id]
		if entry["source_kind"] == &"policy" or entry["source_kind"] == &"legacy":
			continue
		if not has_form(card_id, idx):
			continue
		pool.append(card_id)
	return pool


static func roll_reward(state: GameState) -> CardInstance:
	# Pick + full quality roll, both on the &"cards" track. Returns an UNATTACHED instance:
	# the reveal screen shows grade + stats, then the player accepts (accept_reward) or
	# declines (drop the instance; declining is free and doesn't spend first-seen status).
	var pool: Array[StringName] = reward_pool(state)
	var card_id: StringName = state.rng.pick(&"cards", pool)
	return _new_instance(state, card_id)


static func accept_reward(state: GameState, instance: CardInstance) -> Dictionary:
	# First-seen (deck currently lacks the id) = free; duplicate = 5×時代係數 收編.
	# Never grants purchase rights (納入不開購買權): unlocked_cards untouched.
	var duplicate: bool = false
	for owned: CardInstance in state.deck:
		if owned.id == instance.id:
			duplicate = true
			break
	var cost: int = 0
	if duplicate:
		cost = REWARD_DUPLICATE_COST_BASE * Era.coeff(state.generation)
		state.treasury -= cost   # may go negative
	state.deck.append(instance)
	return {"ok": true, "duplicate": duplicate, "cost": cost}


static func add_reward_card(state: GameState, card_id: StringName) -> CardInstance:
	# DEPRECATED shim: kept only so pre-rewrite sim.gd/view/main.gd compile until W14/W15
	# rewire to roll_reward + accept_reward. Free rolled copy, no purchase rights.
	var instance := _new_instance(state, card_id)
	state.deck.append(instance)
	return instance


# --- deck economy ---

static func disband(state: GameState, deck_index: int) -> Dictionary:
	# 解散（刪牌）— the ONLY removal action, never free (卡牌.md 卡牌經濟): 8×時代係數;
	# 人數型 +2 人口 (permanent), 機械型 nothing (sunk cost). Grade, innate three, and all
	# medals are destroyed with the instance — this is what makes 解散 an operational call.
	if state.deck.size() <= DECK_MINIMUM:
		return {"ok": false, "reason": &"deck_minimum"}
	var instance: CardInstance = state.deck[deck_index]
	var cost: int = DISBAND_COST_BASE * Era.coeff(state.generation)
	state.treasury -= cost   # may go negative
	var pop: int = int(card(instance.id)["disband_pop"])
	state.population += pop
	state.deck.remove_at(deck_index)
	return {"ok": true, "reason": &"", "cost": cost, "population_recovered": pop}


static func destroy_permanently(state: GameState, card_id: StringName) -> void:
	# 技能類限定卡用後即永久銷毀 (Battle calls this on use).
	for i: int in range(state.deck.size()):
		var instance: CardInstance = state.deck[i]
		if instance.id == card_id:
			state.deck.remove_at(i)
			break
	state.unlocked_cards.erase(card_id)
	var destroyed: Array = state.flags.get(&"destroyed_cards", [])
	destroyed.append(card_id)
	state.flags[&"destroyed_cards"] = destroyed


static func on_era_transition(state: GameState) -> Dictionary:
	# 就地演化: every evolving card rises to the current era's form, carrying grade, innate
	# three, and medals (卡牌.md §陣亡與重骰: 就地演化全部保留). Cards whose forms END here
	# (聖戰士團 after 工業, 私掠傭兵團 after 現代) auto-disband: free, recovery per card
	# table, and it proceeds even below the deck minimum (the minimum guards voluntary
	# disband; a formless ghost card would contradict the evolution table).
	var idx: int = Era.index(state.generation)
	var evolved: Array[StringName] = []
	var auto_disbanded: Array[StringName] = []
	var pop_recovered: int = 0
	for i: int in range(state.deck.size() - 1, -1, -1):
		var instance: CardInstance = state.deck[i]
		var entry: Dictionary = card(instance.id)
		if not bool(entry["evolves"]):
			continue
		if has_form(instance.id, idx):
			var new_tier: int = maxi(instance.tier, mini(idx, 6))
			if new_tier != instance.tier:
				instance.tier = new_tier
				evolved.append(instance.id)
		else:
			var pop: int = int(entry["disband_pop"])
			state.population += pop
			pop_recovered += pop
			auto_disbanded.append(instance.id)
			state.deck.remove_at(i)
	return {
		"evolved": evolved,
		"auto_disbanded": auto_disbanded,
		"population_recovered": pop_recovered,
	}


static func deck_strength(state: GameState) -> int:
	# 牌組實力總和 for the power formula: Σ(attack+hp); skills/forts contribute 0.
	var total: int = 0
	for instance: CardInstance in state.deck:
		total += attack_of(instance) + hp_of(instance)
	return total


static func starting_deck(state: GameState) -> void:
	# 起始牌組＝5×步兵團 (卡牌.md §起始牌組, corpus-pinned): 開局即視為取得的瞬間 — each of
	# the five rolls its own grade + innate three right here.
	state.unlocked_cards.append(&"infantry")
	for i: int in range(DECK_MINIMUM):
		state.deck.append(_new_instance(state, &"infantry"))


static func _new_instance(state: GameState, card_id: StringName) -> CardInstance:
	var entry: Dictionary = card(card_id)
	var tier: int = 1
	if bool(entry["evolves"]):
		tier = clampi(Era.index(state.generation), 1, 6)
	var instance := CardInstance.new(card_id, tier)
	roll_quality(state, instance)
	return instance
