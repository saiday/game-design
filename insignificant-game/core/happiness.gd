class_name Happiness
extends RefCounted
# 幸福 (design/幸福.md): 0..100 indirect axis. Producers are building lines and one-shot
# policy events; this module owns the clamp, the two thresholds, and the 建立國教
# decaying bonus. Downstream consumers query good_draw_bonus / low_penalty.

const MIN_VALUE: int = 0
const MAX_VALUE: int = 100
const GOOD_DRAW_THRESHOLD: int = 70   # >= 70: opportunity good-draw weight +20%
const LOW_THRESHOLD: int = 60         # < 60: unrest weight +20%
const STATE_RELIGION_BONUS: int = 30
# 隨時代衰退 has no pinned schedule — driver choice: -10 per era transition (gone in 3 eras).
const STATE_RELIGION_DECAY_PER_ERA: int = 10
const DECAY_FLAG: StringName = &"state_religion_decay_left"


static func adjust(state: GameState, delta: int) -> int:
	state.happiness = clampi(state.happiness + delta, MIN_VALUE, MAX_VALUE)
	return state.happiness


static func good_draw_bonus(state: GameState) -> bool:
	return state.happiness >= GOOD_DRAW_THRESHOLD


static func low_penalty(state: GameState) -> bool:
	return state.happiness < LOW_THRESHOLD


static func apply_state_religion(state: GameState) -> int:
	# 建立國教 completion: one-shot +30 that fades over later eras.
	state.flags[DECAY_FLAG] = STATE_RELIGION_BONUS
	return adjust(state, STATE_RELIGION_BONUS)


static func on_era_transition(state: GameState) -> int:
	# Called once per era change (Turn orchestrator). Returns the (negative) delta applied.
	var left: int = int(state.flags.get(DECAY_FLAG, 0))
	if left <= 0:
		return 0
	var step: int = mini(STATE_RELIGION_DECAY_PER_ERA, left)
	state.flags[DECAY_FLAG] = left - step
	adjust(state, -step)
	return -step
