class_name Legacy
extends RefCounted
# Legacy 文明精神 (design/Legacy.md): condition-triggered permanent amplifiers.
# Policy-granted ones (宗教教條/理性精神/戒嚴) are granted by Policy on completion;
# 民主精神 by Democracy on voluntary entry. This module owns the settle-time checks
# (culture lead → 批判/搖滾精神, melting-pot counter) and the passive per-generation
# bonuses. Bonus magnitudes are unpinned in the design ("小幅永久＋") — driver v1 values.

const MELTING_POT_GENERATIONS: int = 10

# Per-generation axis bonuses (driver decisions; the design pins direction, not size).
const PASSIVES: Dictionary = {
	&"religious_dogma": {"culture": 1, "tech": 1},   # happiness surge handled as one-shot decay
	&"rational_spirit": {"tech": 2, "culture": 1},
	&"critical_spirit": {"tech": 2},
	&"rock_spirit": {"population": 1, "happiness": 1},
	&"democratic_spirit": {"population": 1, "culture": 1, "happiness": 1},
	&"melting_pot": {"population": 1, "culture": 1, "tech": 1},
}


static func grant(state: GameState, legacy_id: StringName) -> bool:
	if state.legacies.has(legacy_id):
		return false
	state.legacies.append(legacy_id)
	return true


static func check_triggers(state: GameState) -> Array[StringName]:
	# Called once per settle. Returns newly granted legacies.
	var granted: Array[StringName] = []
	# 批判精神 / 搖滾精神: culture lead over ALL living rivals, in two DIFFERENT eras.
	if _culture_leads_all(state):
		var led: Array = state.flags.get(&"culture_led_eras", [])
		var era_id: StringName = Era.of(state.generation)
		if not led.has(era_id):
			led.append(era_id)
			state.flags[&"culture_led_eras"] = led
		if led.size() >= 1 and grant(state, &"critical_spirit"):
			granted.append(&"critical_spirit")
		if led.size() >= 2 and grant(state, &"rock_spirit"):
			granted.append(&"rock_spirit")
	# 文化大熔爐: ≥1 annex/inheritance, maintained 10 generations (passive count, no BP lock).
	if state.flags.has(&"first_annex_gen"):
		if state.generation - int(state.flags[&"first_annex_gen"]) >= MELTING_POT_GENERATIONS:
			if grant(state, &"melting_pot"):
				granted.append(&"melting_pot")
	return granted


static func apply_passives(state: GameState) -> Dictionary:
	# Turn calls this during settle, after building production.
	var totals: Dictionary = {"population": 0, "happiness": 0, "culture": 0, "tech": 0}
	for legacy_id: StringName in state.legacies:
		if not PASSIVES.has(legacy_id):
			continue   # 戒嚴 is active-type, no passive
		var bonus: Dictionary = PASSIVES[legacy_id]
		totals["population"] = int(totals["population"]) + int(bonus.get("population", 0))
		totals["happiness"] = int(totals["happiness"]) + int(bonus.get("happiness", 0))
		totals["culture"] = int(totals["culture"]) + int(bonus.get("culture", 0))
		totals["tech"] = int(totals["tech"]) + int(bonus.get("tech", 0))
	state.population += int(totals["population"])
	state.culture += int(totals["culture"])
	state.tech += int(totals["tech"])
	if int(totals["happiness"]) != 0:
		Happiness.adjust(state, int(totals["happiness"]))
	return totals


static func _culture_leads_all(state: GameState) -> bool:
	var alive := Rivals.living(state)
	if alive.is_empty():
		return false   # nobody left to lead — 提前完全勝利 handles this instead
	for rival: Rivals.RivalState in alive:
		if state.culture <= Rivals.culture_of(rival):
			return false
	return true
