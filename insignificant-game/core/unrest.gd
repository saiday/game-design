class_name Unrest
extends RefCounted
# 內亂與失敗 (design/內亂與失敗.md): unrest weight, per-generation trigger roll,
# concession, martial-law dodge, riot-loss consequences, regime collapse check.
# The riot battle itself (內部暴動戰) is resolved by Battle (W3); this module only
# decides trigger / concession / martial law / loss consequences.

const BASE_WEIGHT: float = 0.15
const LOW_HAPPINESS_WEIGHT: float = 0.20
const DEBT_WEIGHT_PER_100: float = 0.10
const CENTRALIZATION_REDUCTION: float = 0.05
const SECRET_POLICE_REDUCTION: float = 0.10
const THEOCRACY_REDUCTION: float = 0.10
const WEIGHT_CAP: float = 0.60
const CONCESSION_BASE_COST: int = 40
const CONCESSION_HAPPINESS_GAIN: int = 5
const COLLAPSE_POPULATION: int = 5

# Building lines per region type (canonical IDs, architecture.md). Losing a region
# destroys the buildings on it — buildings are keyed by line, lines belong to a
# region type.
const LINES_BY_REGION: Dictionary = {
	&"livelihood": [&"housing", &"food", &"medical"],
	&"academic": [&"school", &"astronomy"],
	&"military": [&"barracks", &"arsenal"],
	&"culture": [&"arts", &"media"],
	&"finance": [&"commerce", &"bank", &"debt_office"],
}


static func weight(state: GameState) -> float:
	# 每代擲一次的內亂權重. Base 15%; +20% if happiness < 60; after 國債司 unlocks the
	# debt-unrest consequence (debt_unrest_mode), +10% per 100 of debt while treasury
	# is actually negative ("後果永遠跟「實際為負」走"); policy reductions; clamp 0..60%.
	var w: float = BASE_WEIGHT
	if Happiness.low_penalty(state):
		w += LOW_HAPPINESS_WEIGHT
	if state.debt_unrest_mode and state.treasury < 0:
		w += DEBT_WEIGHT_PER_100 * (float(absi(state.treasury)) / 100.0)
	if state.policies.has(&"centralization"):
		w -= CENTRALIZATION_REDUCTION
	if state.policies.has(&"secret_police"):
		w -= SECRET_POLICE_REDUCTION
	if state.policies.has(&"theocracy"):
		w -= THEOCRACY_REDUCTION
	return clampf(w, 0.0, WEIGHT_CAP)


static func roll(state: GameState) -> bool:
	# One trigger roll; at most 1 民怨戰 per generation. Returns true iff a battle
	# triggers this call (and counts it). No RNG is consumed when already capped.
	if state.unrest_battles_this_gen >= 1:
		return false
	var triggered: bool = state.rng.chance(&"unrest", weight(state))
	if triggered:
		state.unrest_battles_this_gen += 1
		state.flags[&"unrest_triggered_total"] = int(state.flags.get(&"unrest_triggered_total", 0)) + 1
	return triggered


static func concession_cost(state: GameState) -> int:
	# 讓步: 40 × 時代係數; 祖靈崇拜 halves it (40×coeff is always even).
	var cost: int = CONCESSION_BASE_COST * Era.coeff(state.generation)
	if state.policies.has(&"ancestor_worship"):
		cost = cost / 2
	return cost


static func apply_concession(state: GameState) -> Dictionary:
	# Pay to cancel the riot battle (不打就要買): treasury may go negative; happiness +5.
	var cost: int = concession_cost(state)
	state.treasury -= cost
	var new_happiness: int = Happiness.adjust(state, CONCESSION_HAPPINESS_GAIN)
	return {
		"cost": cost,
		"treasury": state.treasury,
		"happiness": new_happiness,
		"battle_cancelled": true,
	}


static func use_martial_law(state: GameState) -> bool:
	# 戒嚴 (Legacy granted by 秘密警察): one-shot unconditional dodge of one riot battle.
	if not state.martial_law_available:
		return false
	state.martial_law_available = false
	return true


static func apply_riot_loss(state: GameState) -> Dictionary:
	# Losing the 內亂/獨立戰: lose 1 region (deterministic pick on the &"unrest" track)
	# with all buildings on it, plus population −20% (round down). Unlocked cards are
	# untouched (鎖路永不鎖卡). buildings_built is a lifetime counter for escalating
	# build cost and intentionally stays as-is.
	var region_lost: StringName = &""
	var buildings_removed: Array[StringName] = []
	if not state.regions.is_empty():
		var idx: int = state.rng.randi_range(&"unrest", 0, state.regions.size() - 1)
		region_lost = state.regions[idx]
		state.regions.remove_at(idx)
		# Buildings live on lines of the region's type; only destroy them when no
		# other region of the same type remains to host them.
		if not state.regions.has(region_lost):
			for line: StringName in LINES_BY_REGION[region_lost]:
				if state.buildings.has(line):
					state.buildings.erase(line)
					buildings_removed.append(line)
	var population_before: int = state.population
	state.population = state.population * 4 / 5  # −20%, round down (integer-exact)
	return {
		"region_lost": region_lost,
		"buildings_removed": buildings_removed,
		"population_before": population_before,
		"population_after": state.population,
		"population_lost": population_before - state.population,
	}


static func regime_collapsed(state: GameState) -> bool:
	# 政權崩潰: population < 5, the ONLY game over (結局 handles the epilogue).
	return state.population < COLLAPSE_POPULATION
