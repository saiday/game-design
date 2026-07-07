class_name Ending
extends RefCounted
# 結局 (design/結局.md): no victory threshold — surviving to generation 50 IS the win.
# Three exits: 政權崩潰 (only failure), 走到最後 (ranked narrative epilogue),
# 提前完全勝利 (last civilization standing).


static func check(state: GameState) -> Dictionary:
	if Unrest.regime_collapsed(state):
		return {
			"over": true, "kind": &"collapse", "victory": false,
			"epilogue": EpilogueData.COLLAPSE,
		}
	if Rivals.only_player_remains(state):
		return {
			"over": true, "kind": &"total_victory", "victory": true,
			"epilogue": EpilogueData.TOTAL_VICTORY,
		}
	if state.generation > Era.FINAL_GENERATION:
		var final_rank: int = rank(state)
		return {
			"over": true, "kind": &"survived", "victory": true,
			"rank": final_rank, "epilogue": EpilogueData.BY_RANK[final_rank],
		}
	return {"over": false}


static func rank(state: GameState) -> int:
	# Player power vs LIVING rivals; fewer survivors -> better possible ranks.
	var player: float = float(Rivals.player_power(state))
	var above: int = 0
	for rival: Rivals.RivalState in Rivals.living(state):
		if rival.power > player:
			above += 1
	return above + 1


static func danger_panel(state: GameState) -> Dictionary:
	# 介面全程顯示距離失敗有多遠 (design hard requirement — the view binds to this).
	return {
		"debt": maxi(-state.treasury, 0),
		"interest_per_gen": Economy.interest_due(state),
		"unrest_weight": Unrest.weight(state),
		"population": state.population,
		"collapse_threshold": Unrest.COLLAPSE_POPULATION,
	}
