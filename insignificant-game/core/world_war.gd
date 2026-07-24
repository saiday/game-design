class_name WorldWar
extends RefCounted
# 世界大戰 (design/世界大戰.md): generations 15/35, whole-generation override. The 7th
# PLAYABLE battle type (WW1-WW5): every living civ (player included) lands in exactly two
# camps — no neutral — and fights one shared-table battle on Battle's wave/tick engine.
# Camp victory is exhaustion (D3 per camp); power only sizes each civ's 正規軍, it never
# rolls the outcome. The player deploys their own deck (軍費-gated) while every ally and
# enemy 正規軍 auto-fights; 撤軍 is disabled (callers never offer it).
# 戰功 = each civ's actual battlefield clears (Battle.merit_by_faction); reparations
# max(正國庫×50%, power×2) per losing civ, last-hit 20% + 80% pro-rata, exact conservation.
#
# Flow: start(state) -> BattleField (drive with Battle.deploy/end_round like any battle)
# -> finish(state, battle) applies the war's economy/system consequences.

const AI_LOSER_POWER_HIT: float = 0.9
const LAST_HIT_BONUS: float = 0.20
const WAVES_PER_CIV: int = 2                       # 波數上限 (v1 基準; throttles the uncapped war)
const WAVE_SHARES: Array[float] = [0.6, 0.4]       # per-civ budget split, heavier first
const BUDGET_PER_POWER: float = 0.5                # 總實力 ≈ P×0.5 (same conversion as 文明戰爭)


static func is_ww_generation(state: GameState) -> bool:
	return Era.is_world_war(state.generation)


static func form_camps(state: GameState) -> Dictionary:
	# 分營 (WW2): 與你開戰過的在對面; the rest balance the totals; NO neutral — every
	# living civ (player included) is in exactly one camp.
	var player_camp: Array[StringName] = [&"player"]
	var enemy_camp: Array[StringName] = []
	var unaligned: Array[Rivals.RivalState] = []
	for rival: Rivals.RivalState in Rivals.living(state):
		if rival.warred_this_window:
			enemy_camp.append(rival.id)
		else:
			unaligned.append(rival)
	# balance the rest by proximity: join the side whose current total power is smaller
	for rival: Rivals.RivalState in unaligned:
		if _camp_power(state, player_camp) <= _camp_power(state, enemy_camp):
			player_camp.append(rival.id)
		else:
			enemy_camp.append(rival.id)
	return {"player_camp": player_camp, "enemy_camp": enemy_camp}


static func card_count(power: float) -> int:
	# 卡池張數（出場序用）＝ ceil(P/10)
	return int(ceil(power / 10.0))


static func start(state: GameState) -> Battle.BattleField:
	# Composes the two-camp wave schedule (WW4) and opens the shared-table battle.
	var camps := form_camps(state)
	var waves := _build_waves(state, camps)
	var battle := Battle.start(state, &"world_war", &"", false, false, waves)
	battle.camps = camps
	return battle


static func finish(state: GameState, battle: Battle.BattleField) -> Dictionary:
	# Settle the war from the battle outcome (WW1: the battle decides; no roll).
	# Reparations math is the PoC math unchanged; 戰功 is now real battlefield clears (WW5).
	var battle_report := Battle.finish(state, battle)   # 戰後獎勵卡 issues here too
	var player_camp: Array[StringName] = battle.camps["player_camp"]
	var enemy_camp: Array[StringName] = battle.camps["enemy_camp"]
	var player_won: bool = battle.outcome == &"win"
	var winners: Array[StringName] = player_camp if player_won else enemy_camp
	var losers: Array[StringName] = enemy_camp if player_won else player_camp
	var losing_side: StringName = &"enemy" if player_won else &"player"
	# reparations per loser: max(正國庫×50%, power×2), charged even into negative
	var pool: int = 0
	var reparations: Dictionary = {}
	for civ_id: StringName in losers:
		var amount: int = 0
		if civ_id == &"player":
			@warning_ignore("integer_division")
			amount = maxi(maxi(state.treasury, 0) / 2, int(float(Rivals.player_power(state)) * 2.0))
			state.treasury -= amount   # 可扣到負 → 債務難度; 不因此直接輸
		else:
			var rival := Rivals.find(state, civ_id)
			@warning_ignore("integer_division")
			amount = maxi(Rivals.treasury_of(rival) / 2, int(rival.power * 2.0))
			rival.power *= AI_LOSER_POWER_HIT   # 扣賠款同步壓其 power −10%
		reparations[civ_id] = amount
		pool += amount
	# 最後一擊: whoever cleared the losing camp's last on-field unit takes 20% first;
	# the remaining 80% splits pro-rata by real 戰功; rounding remainder goes to the
	# last hitter so 發出去的正好等於池 (守恆, exact — docs/decisions.md W12.5).
	var last_hitter: StringName = battle.last_clear_by_side[losing_side]
	if not winners.has(last_hitter):
		last_hitter = _top_merit(battle, winners)
	var bonus: int = int(float(pool) * LAST_HIT_BONUS)
	var distributable: int = pool - bonus
	var merit_total: int = 0
	for civ_id: StringName in winners:
		merit_total += int(battle.merit_by_faction.get(civ_id, 0))
	var payouts: Dictionary = {}
	var paid: int = 0
	for civ_id: StringName in winners:
		var share: int = 0
		if merit_total > 0:
			share = int(float(distributable) * float(int(battle.merit_by_faction.get(civ_id, 0))) / float(merit_total))
		payouts[civ_id] = share
		paid += share
	payouts[last_hitter] = int(payouts.get(last_hitter, 0)) + (pool - paid)   # bonus + remainder
	if winners.has(&"player"):
		state.treasury += int(payouts[&"player"])
	var result: Dictionary = {
		"generation": state.generation,
		"player_camp": player_camp, "enemy_camp": enemy_camp,
		"player_won": player_won,
		"winners": winners, "reparations": reparations, "pool": pool,
		"payouts": payouts, "last_hitter": last_hitter,
		"merit": battle.merit_by_faction.duplicate(),
		"rounds": battle.round,
		"reward_instance": battle_report["reward_instance"],
	}
	state.ww_results.append(result)
	Rivals.on_world_war_end(state)   # 開戰過 window resets; WW losses don't count toward exit
	return result


# --- internals ---

static func _build_waves(state: GameState, camps: Dictionary) -> Array[Dictionary]:
	# 出場序 (WW4): within each camp, civs sort by 卡池張數 desc (tie: class id) and each
	# contributes WAVES_PER_CIV waves — all first waves, then all second waves; the camp
	# queue's k-th wave arrives at round k+1. Bigger power → earlier and heavier. The
	# player contributes NO 正規軍 wave — their force is the deck, deployed by hand.
	var out: Array[Dictionary] = []
	for side: StringName in [&"player", &"enemy"]:
		var camp: Array[StringName] = camps["player_camp"] if side == &"player" else camps["enemy_camp"]
		var civs: Array[Rivals.RivalState] = []
		for civ_id: StringName in camp:
			if civ_id != &"player":
				civs.append(Rivals.find(state, civ_id))
		civs.sort_custom(func(a: Rivals.RivalState, b: Rivals.RivalState) -> bool:
			if card_count(a.power) != card_count(b.power):
				return card_count(a.power) > card_count(b.power)
			return String(a.id) < String(b.id))
		var arrival: int = 1
		for wave_idx: int in range(WAVES_PER_CIV):
			for rival: Rivals.RivalState in civs:
				var budget: float = rival.power * BUDGET_PER_POWER * WAVE_SHARES[wave_idx]
				var units: Array[Dictionary] = Battle.regular_force(state, budget, side, rival.id, rival)
				if units.is_empty() and wave_idx == 0:
					# a civ too weak for any unit still fields one weakest regular in its
					# first wave (mirrors the 文明戰爭 guard; docs/decisions.md W12.5)
					units = Battle.regular_force(
							state, float(Battle.weakest_regular_strength(state)), side, rival.id, rival)
				if not units.is_empty():
					out.append({"round": arrival, "units": units, "side": side})
					arrival += 1
	return out


static func _camp_power(state: GameState, camp: Array[StringName]) -> float:
	var total: float = 0.0
	for civ_id: StringName in camp:
		if civ_id == &"player":
			total += float(Rivals.player_power(state))
		else:
			total += Rivals.find(state, civ_id).power
	return total


static func _top_merit(battle: Battle.BattleField, winners: Array[StringName]) -> StringName:
	# Fallback when the losing camp's last unit wasn't cleared by a winner (e.g. the
	# player conceded with enemies standing): highest real 戰功, ties to camp order.
	var best: StringName = winners[0]
	var best_merit: int = -1
	for civ_id: StringName in winners:
		var merit: int = int(battle.merit_by_faction.get(civ_id, 0))
		if merit > best_merit:
			best_merit = merit
			best = civ_id
	return best
