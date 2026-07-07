class_name Era
extends RefCounted
# Era clock (design/時代與回合.md): generation 1..50 -> era segment, cost coefficient,
# per-generation BP cap, tech-gate base. The 1/2/3/5/8/12 table lives ONLY here.

const ERA_IDS: Array[StringName] = [
	&"tribal", &"classical", &"faith", &"industrial", &"modern", &"information",
]
const ERA_STARTS: Array[int] = [1, 9, 17, 25, 33, 41]
const COST_COEFF: Array[int] = [1, 2, 3, 5, 8, 12]
const BP_CAP: Array[int] = [2, 3, 3, 4, 5, 5]
const FINAL_GENERATION: int = 50
const WORLD_WAR_GENERATIONS: Array[int] = [15, 35]


static func index(generation: int) -> int:
	# 1-based 時代序 (1..6)
	for i: int in range(ERA_STARTS.size() - 1, -1, -1):
		if generation >= ERA_STARTS[i]:
			return i + 1
	return 1


static func of(generation: int) -> StringName:
	return ERA_IDS[index(generation) - 1]


static func coeff(generation: int) -> int:
	return COST_COEFF[index(generation) - 1]


static func bp_cap(generation: int) -> int:
	return BP_CAP[index(generation) - 1]


static func tech_gate_base(era_index: int) -> int:
	# 卡牌時代階級門檻 = 時代序 × 10 (modifiers: 文字與曆法 ×8, 政教合一 +2×序 — in Cards/Policy)
	return era_index * 10


static func is_world_war(generation: int) -> bool:
	return generation in WORLD_WAR_GENERATIONS
