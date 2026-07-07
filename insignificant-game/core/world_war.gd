class_name WorldWar
extends RefCounted
# 世界大戰 (design/世界大戰.md): generations 15/35, whole-generation override, two camps
# from the relations ledger, reparations max(正國庫×50%, power×2) chargeable into negative.
#
# PoC simplification (documented in poc-docs): the common-table card battle is resolved as
# an automated strength contest — camps/turn-order/merit/last-hit/reparations math is
# faithful; individual card plays are not simulated. Player merit share uses player power.

const AI_LOSER_POWER_HIT: float = 0.9
const LAST_HIT_BONUS: float = 0.20


static func is_ww_generation(state: GameState) -> bool:
	return Era.is_world_war(state.generation)


static func form_camps(state: GameState) -> Dictionary:
	# 與你開戰過的在對面; others balance by power proximity; 零衝突 may stay neutral.
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


static func run(state: GameState, player_neutral: bool = false) -> Dictionary:
	# Whole-generation override: no operate, no route; policy frozen (Policy checks the
	# generation itself). Returns the full ledger for UI/telemetry.
	var camps := form_camps(state)
	var player_camp: Array[StringName] = camps["player_camp"]
	var enemy_camp: Array[StringName] = camps["enemy_camp"]
	var player_warred: bool = false
	for rival: Rivals.RivalState in Rivals.living(state):
		player_warred = player_warred or rival.warred_this_window
	if player_neutral and player_warred:
		player_neutral = false   # 零衝突的文明才可中立
	if player_neutral:
		player_camp.erase(&"player")
	var player_power: float = float(Rivals.player_power(state))
	var side_a: float = _camp_power(state, player_camp)
	var side_b: float = _camp_power(state, enemy_camp)
	# strength contest with a bounded random factor (±15%) on the &"rivals" track
	var roll: float = 0.85 + 0.30 * state.rng.randf(&"rivals")
	var a_wins: bool = side_a * roll >= side_b
	var winners: Array[StringName] = player_camp if a_wins else enemy_camp
	var losers: Array[StringName] = enemy_camp if a_wins else player_camp
	# reparations per loser: max(正國庫×50%, power×2), charged even into negative
	var pool: int = 0
	var reparations: Dictionary = {}
	for civ_id: StringName in losers:
		var amount: int = 0
		if civ_id == &"player":
			@warning_ignore("integer_division")
			amount = maxi(maxi(state.treasury, 0) / 2, int(player_power * 2.0))
			state.treasury -= amount
		else:
			var rival := Rivals.find(state, civ_id)
			@warning_ignore("integer_division")
			amount = maxi(Rivals.treasury_of(rival) / 2, int(rival.power * 2.0))
			rival.power *= AI_LOSER_POWER_HIT   # 扣賠款同步壓其 power −10%
		reparations[civ_id] = amount
		pool += amount
	# merit pro-rata (share of camp power) + last-hit 20% bonus to the strongest winner
	var payouts: Dictionary = {}
	var winner_power_total: float = _camp_power(state, winners)
	var last_hitter: StringName = _strongest(state, winners)
	var bonus: int = int(float(pool) * LAST_HIT_BONUS)
	var distributable: int = pool - bonus
	for civ_id: StringName in winners:
		var civ_power: float = player_power if civ_id == &"player" else Rivals.find(state, civ_id).power
		var share: int = int(float(distributable) * civ_power / winner_power_total) if winner_power_total > 0.0 else 0
		if civ_id == last_hitter:
			share += bonus
		payouts[civ_id] = share
		if civ_id == &"player":
			state.treasury += share
	var result: Dictionary = {
		"generation": state.generation,
		"player_camp": player_camp, "enemy_camp": enemy_camp,
		"player_neutral": player_neutral,
		"player_won": (not player_neutral) and a_wins,
		"winners": winners, "reparations": reparations, "pool": pool,
		"payouts": payouts, "last_hitter": last_hitter,
	}
	state.ww_results.append(result)
	Rivals.on_world_war_end(state)   # 開戰過 window resets; WW losses don't count toward exit
	return result


static func _camp_power(state: GameState, camp: Array[StringName]) -> float:
	var total: float = 0.0
	for civ_id: StringName in camp:
		if civ_id == &"player":
			total += float(Rivals.player_power(state))
		else:
			total += Rivals.find(state, civ_id).power
	return total


static func _strongest(state: GameState, camp: Array[StringName]) -> StringName:
	var best: StringName = &""
	var best_power: float = -1.0
	for civ_id: StringName in camp:
		var civ_power: float = float(Rivals.player_power(state)) if civ_id == &"player" else Rivals.find(state, civ_id).power
		if civ_power > best_power:
			best_power = civ_power
			best = civ_id
	return best
