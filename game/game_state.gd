class_name GameState
extends RefCounted
## Pure, GUI-free game state (non-negotiable: logic lives in testable
## RefCounted/static fns). Holds the two resources the one-card slice touches.

var energy: int = 0
var gold: int = 0

func _init(p_energy: int = 0, p_gold: int = 0) -> void:
	energy = p_energy
	gold = p_gold

## Independent copy, so rules can return a new state without mutating the
## caller's (keeps Rules.play_card pure).
func duplicate() -> GameState:
	return GameState.new(energy, gold)
