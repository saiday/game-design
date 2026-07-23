class_name Difficulty
extends RefCounted
# Difficulty algorithm (docs/difficulty-design.md, synced to the design corpus).
# One signed level d (easy −1 / normal 0 / hard +1) drives three channels with
# per-channel slopes — no per-encounter special cases:
#   enemy combat stats   ×(1 + 0.20·d)
#   event penalties      ×(1 + 0.25·d)   (negative money outcomes + mitigation fees)
#   rival curves         P0 ×(1 + 0.10·d), g +0.02·d, aggression frequency ×(1 + 0.25·d)

const LEVELS: Dictionary = {&"easy": -1, &"normal": 0, &"hard": 1}

const ENEMY_STAT_SLOPE: float = 0.20
const EVENT_PENALTY_SLOPE: float = 0.25
const RIVAL_P0_SLOPE: float = 0.10
const RIVAL_G_SLOPE: float = 0.02
const AGGRESSION_SLOPE: float = 0.25


static func level(difficulty: StringName) -> int:
	return int(LEVELS.get(difficulty, 0))


static func enemy_stat_mult(state: GameState) -> float:
	return 1.0 + ENEMY_STAT_SLOPE * float(level(state.difficulty))


static func event_penalty_mult(state: GameState) -> float:
	return 1.0 + EVENT_PENALTY_SLOPE * float(level(state.difficulty))


static func rival_p0_mult(difficulty: StringName) -> float:
	return 1.0 + RIVAL_P0_SLOPE * float(level(difficulty))


static func rival_g_delta(difficulty: StringName) -> float:
	return RIVAL_G_SLOPE * float(level(difficulty))


static func aggression_mult(state: GameState) -> float:
	return 1.0 + AGGRESSION_SLOPE * float(level(state.difficulty))


static func scale_enemy_stat(state: GameState, value: int) -> int:
	return maxi(int(round(float(value) * enemy_stat_mult(state))), 1)


static func scale_penalty(state: GameState, money: int) -> int:
	# Only NEGATIVE money outcomes scale (penalties); rewards are difficulty-neutral.
	if money >= 0:
		return money
	return int(round(float(money) * event_penalty_mult(state)))
