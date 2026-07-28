extends SceneTree
# Timeline exporter (design/戰鬥.md, ADR-0008/0009). Runs one full-roster battle per era on the
# real engine and dumps the tick timelines core emitted, so a replayer can show the battle
# without owning a single rule.
#   $GODOT_BIN --headless --path . -s tools/export_timeline.gd
# Output: res://docs/fixtures/battle_timeline.json (committed; the HTML replayer embeds it via
# docs/tools/build_motion_demo.py, and Part A re-runs this and fails on a diff).
#
# What one fixture is: a 世界大戰-typed battle (the uncapped type, so it settles the moment the
# field can no longer change instead of expiring on a round cap), the player fielding one card
# per era-legal unit class plus its whole 工事線, the enemy fielding one 正規軍 per era-legal
# roster type plus the 盾陣 that wave brings (Battle.regular_screens). Skill cards are left out:
# they have no station in the 掩護鏈 and nothing to render.
#
# ONE UNIT PER CLASS PER SIDE IS LOAD-BEARING, not a convenience. Timeline labels are card ids
# (or an irregular's anonymous grade) and architecture.md is explicit that labels are NOT
# identities — two 步兵團 on one field share one. A fixture with a unique label per unit is what
# lets the HTML replayer key its handles off the label at all (docs/decisions.md, W14.7).

const OUT_PATH: String = "res://docs/fixtures/battle_timeline.json"
const FIXTURE_SEED: int = 20260728       # any fixed seed; the run must be reproducible, not fair
const ROUND_GUARD: int = 40              # export-side only, never an engine cap (cf. sim.gd)


func _init() -> void:
	var eras: Array = []
	for era: int in range(1, Era.ERA_IDS.size() + 1):
		eras.append(_export_era(era))
	var payload: Dictionary = {
		"generated_by": "tools/export_timeline.gd",
		"note": "One full-roster 世界大戰 per era, replayed from core's own tick timeline. "
				+ "Every unit label is unique per side by construction.",
		"ticks_per_round": Battle.TICKS_PER_ROUND,
		"seed": FIXTURE_SEED,
		"eras": eras,
	}
	var out := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if out == null:
		push_error("cannot write %s" % OUT_PATH)
		quit(1)
		return
	out.store_string(JSON.stringify(payload, "  ") + "\n")
	out.close()
	var rounds: int = 0
	for era: Dictionary in eras:
		rounds += (era["rounds"] as Array).size()
	print("TIMELINE EXPORT DONE: %d eras, %d rounds -> %s" % [eras.size(), rounds, OUT_PATH])
	quit(0)


func _export_era(era: int) -> Dictionary:
	var state := GameState.new_run(FIXTURE_SEED + era)
	state.generation = Era.ERA_STARTS[era - 1]
	state.treasury = 0            # 軍費可扣到負: the fixture spends freely and shows the bill

	# --- the enemy: one 正規軍 per era-legal roster type, plus the wave's own screen ---
	var enemy: Array[Dictionary] = []
	for card_id: StringName in Battle.regular_roster_desc(state):
		enemy.append(Battle.regular_unit(state, card_id, &"enemy", &"enemy", null))
	var wave: Array[Dictionary] = [{
		"round": 1, "side": &"enemy", "units": enemy,
		"forts": Battle.regular_screens(enemy, &"enemy"),
	}]

	# --- the player: one rolled instance per era-legal unit class, then the 工事線 ---
	var order: Array[StringName] = []
	for card_id: StringName in CardsData.CARDS.keys():
		var entry: Dictionary = CardsData.CARDS[card_id]
		if entry["class"] == &"skill" or not Cards.has_form(card_id, era):
			continue
		var instance := Cards.CardInstance.new(card_id, era)
		Cards.roll_quality(state, instance)   # 取得時抽定, on the &"cards" track
		state.deck.append(instance)
		order.append(card_id)

	var battle := Battle.start(state, &"world_war", &"", false, false, wave)
	for card_id: StringName in order:
		_deploy(state, battle, card_id)

	var cast: Array = []
	for unit: Dictionary in battle.player_units:
		cast.append(_unit_row(unit, &"player", era))
	for unit: Dictionary in battle.enemy_units:
		cast.append(_unit_row(unit, &"enemy", era))
	var works: Array = []
	for fort: Dictionary in battle.player_forts:
		works.append(_fort_row(fort, &"player", era))
	for fort: Dictionary in battle.enemy_forts:
		works.append(_fort_row(fort, &"enemy", era))

	var rounds: Array = []
	var guarded := false
	while battle.outcome == &"":
		if battle.round > ROUND_GUARD:
			Battle.concede(battle)   # 還有未出卡但選擇不出 is legal; here it just ends the export
			guarded = true
		var round_no: int = battle.round
		var report: Dictionary = Battle.end_round(state, battle)
		rounds.append({"round": round_no, "events": _events(report["events"] as Array)})

	return {
		"era": era,
		"era_id": String(Era.ERA_IDS[era - 1]),
		"generation": state.generation,
		"coeff": Era.coeff(state.generation),
		"battle_type": String(battle.battle_type),
		"outcome": String(battle.outcome),
		"winner": "player" if battle.outcome == &"win" else "enemy",
		"guarded": guarded,
		"spent": battle.spent,
		"merit": battle.merit,
		"units": cast,
		"forts": works,
		"rounds": rounds,
	}


func _deploy(state: GameState, battle: Battle.BattleField, card_id: StringName) -> void:
	for i: int in range(battle.available.size()):
		if (battle.available[i] as Cards.CardInstance).id == card_id:
			var report: Dictionary = Battle.deploy(state, battle, i)
			if not bool(report["ok"]):
				push_warning("era fixture: %s refused (%s)" % [card_id, report["reason"]])
			return


func _unit_row(unit: Dictionary, side: StringName, era: int) -> Dictionary:
	# The replayer draws from this and computes nothing: 攻/血 are the catalog's era values, the
	# quality three are the rolled instance's (enemies carry the engine defaults, 戰鬥.md 對手兩型).
	var card_id: StringName = unit["card_id"]
	var entry: Dictionary = CardsData.CARDS[card_id]
	var flags: Array = []
	for flag: StringName in (unit["flags"] as Array):
		flags.append(String(flag))
	return {
		"label": String(card_id), "side": String(side), "card_id": String(card_id),
		"zh": String(entry["zh"]), "form": Cards.form_name(card_id, era),
		"row": String(unit["row"]), "regular": bool(unit["regular"]),
		"attack": int(unit["attack"]), "hp": int(unit["hp"]),
		"accuracy": float(unit["accuracy"]), "dodge": float(unit["dodge"]),
		"speed": float(unit["speed"]), "flags": flags,
	}


func _fort_row(fort: Dictionary, side: StringName, era: int) -> Dictionary:
	# 工事讀作建物: no stats, only 運作中／被禁用 (ADR-0007). The label is the card id, which is
	# also what every fort event carries.
	var card_id: StringName = fort["card_id"]
	var flags: Array = []
	for flag: StringName in (fort["flags"] as Array):
		flags.append(String(flag))
	return {
		"label": String(card_id), "side": String(side), "card_id": String(card_id),
		"zh": String(CardsData.CARDS[card_id]["zh"]), "form": Cards.form_name(card_id, era),
		"flags": flags,
	}


func _events(events: Array) -> Array:
	# Verbatim pass-through of the round's timeline, StringName -> String so it survives JSON.
	# No filtering and no reordering: the contract in architecture.md is what ships.
	var out: Array = []
	for event: Dictionary in events:
		var row: Dictionary = {}
		for key: String in event.keys():
			var value: Variant = event[key]
			row[key] = String(value) if value is StringName else value
		out.append(row)
	return out
