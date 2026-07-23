class_name GameState
extends RefCounted
# The whole mutable run state. Schema is the contract in docs/architecture.md —
# modules extend it via driver report, never by forking their own state containers.
# Derived values (BP income, player power, era) are module functions, not stored here.

# identity / clock
var run_seed: int
var rng: SeededRng
var generation: int = 1
var difficulty: StringName = &"normal"  # &"easy" | &"normal" | &"hard"

# four axes + money
var population: int = 12      # <5 => regime collapse (the only game over)
var happiness: int = 70       # 0..100 (start: driver decision, docs/decisions.md)
var culture: int = 0
var tech: int = 0
var treasury: int = 30        # single money pool; negative = debt (never directly lethal)

# operations
var bp: int = 0
var bp_carryover: int = 0     # <=2 (enlightened_absolutism => <=3)
var regions: Array[StringName] = []   # of: livelihood/academic/military/culture/finance
var buildings: Dictionary = {}        # StringName line -> int tier (1..6), one building per line
var buildings_built: int = 0          # lifetime NEW buildings (escalating cost; upgrades don't count)

# policy tree
var policies: Array[StringName] = []
var policy_in_progress: StringName = &""
var policy_progress: Dictionary = {}    # node id -> BP invested (switching pauses, keeps progress)
var policy_bp_this_gen: int = 0         # locked this generation (cap 2), reset each generation

# deck
var deck: Array = []                   # Array of CardInstance (cards.gd)
var unlocked_cards: Array[StringName] = []

# legacies
var legacies: Array[StringName] = []
var martial_law_available: bool = false

# rivals
var rivals: Array = []                 # Array of RivalState (rivals.gd); filled by Rivals.setup
var psyops_used_this_gen: bool = false
var pending_war_target: StringName = &""

# democracy
var is_democracy: bool = false
var democracy_entered_gen: int = 0
var incumbent: StringName = &""
var candidate_pool: Array = []

# flags & counters
var ww_results: Array = []
var unrest_battles_this_gen: int = 0
var debt_unrest_mode: bool = false     # 國債司: debt penalty switches happiness -> unrest weight
var flags: Dictionary = {}

# telemetry (balance calibration is the point of this PoC)
var log: Array = []


static func new_run(seed_value: int, difficulty_value: StringName = &"normal") -> GameState:
	var state := GameState.new()
	state.run_seed = seed_value
	state.rng = SeededRng.new(seed_value)
	state.difficulty = difficulty_value
	return state


func to_dict() -> Dictionary:
	# Snapshot for the view layer and per-generation telemetry. Not a save format.
	return {
		"generation": generation,
		"era": Era.of(generation),
		"population": population,
		"happiness": happiness,
		"culture": culture,
		"tech": tech,
		"treasury": treasury,
		"bp": bp,
		"bp_carryover": bp_carryover,
		"regions": regions.duplicate(),
		"buildings": buildings.duplicate(),
		"buildings_built": buildings_built,
		"policies": policies.duplicate(),
		"policy_in_progress": policy_in_progress,
		"deck_size": deck.size(),
		"legacies": legacies.duplicate(),
		"rivals_alive": rivals.filter(func(r: Variant) -> bool: return r.alive).size(),
		"is_democracy": is_democracy,
		"debt_unrest_mode": debt_unrest_mode,
	}
