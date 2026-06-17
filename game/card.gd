class_name Card
extends RefCounted
## Pure data for the one card in the slice: playing it costs `cost` energy and
## grants `reward` gold. No view logic here — that's M2's card node.

var cost: int = 0
var reward: int = 0

func _init(p_cost: int = 0, p_reward: int = 0) -> void:
	cost = p_cost
	reward = p_reward
