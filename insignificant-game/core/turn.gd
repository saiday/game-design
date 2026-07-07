class_name Turn
extends RefCounted
# 時代與回合 (design/時代與回合.md): the one-generation orchestrator. Three branches:
# normal (operate → route → node → settle), world-war override (15/35), democracy auto-run.
# The DECISIONS inside phases come from a caller (Sim's bot in tests, the view in play);
# Turn owns sequencing, era transitions, unrest timing, telemetry, and the ending check.


static func begin_generation(state: GameState) -> Dictionary:
	# Resets + era transition + BP grant. Call once at the top of every generation.
	var report: Dictionary = {"generation": state.generation, "era": Era.of(state.generation)}
	state.psyops_used_this_gen = false
	state.unrest_battles_this_gen = 0
	Policy.on_generation_start(state)
	var previous_era: int = int(state.flags.get(&"era_seen", 1))
	var current_era: int = Era.index(state.generation)
	if current_era != previous_era:
		state.flags[&"era_seen"] = current_era
		Cards.on_era_transition(state)          # 就地演化
		report["state_religion_decay"] = Happiness.on_era_transition(state)
		report["era_transition"] = true
	if Era.is_world_war(state.generation):
		report["world_war"] = true               # 整代覆寫: no operate/route; policy frozen
	elif state.is_democracy:
		report["democracy"] = true               # BP 停產
	else:
		Operations.grant_bp(state)
		report["bp"] = state.bp
	return report


static func route(state: GameState) -> Array[Dictionary]:
	# 選路 layer: generated nodes + injected wars (rival aggression / your declaration).
	var nodes: Array[Dictionary] = MapNodes.generate(state)
	var aggressor: StringName = Rivals.roll_aggression(state)
	if aggressor != &"":
		MapNodes.inject_battle_node(nodes, &"civil_war", aggressor)
	if state.pending_war_target != &"":
		MapNodes.inject_battle_node(nodes, &"civil_war", state.pending_war_target)
		nodes[nodes.size() - 1]["player_declared"] = true
		state.pending_war_target = &""
	Rivals.roll_enemy_psyops(state)              # 文化國 may sabotage your next opening hand
	return nodes


static func roll_unrest_battle(state: GameState) -> bool:
	# 每代擲一次 (≤1 場民怨戰). Caller decides: fight / concession / martial law.
	return Unrest.roll(state)


static func maybe_democracy_blood(state: GameState) -> bool:
	# 為民主而流血: possible while democracy is unlocked but not entered AND happiness < 70.
	return (not state.is_democracy) and Democracy.unlocked(state) and state.happiness < 70


static func settle(state: GameState) -> Dictionary:
	# 結算: economy → legacy passives/triggers → rival powers → telemetry → advance clock.
	var report: Dictionary = {}
	report["economy"] = Economy.settle(state)
	report["legacy_passives"] = Legacy.apply_passives(state)
	report["legacies_granted"] = Legacy.check_triggers(state)
	Rivals.update_powers(state)
	if bool(state.flags.get(&"forced_democracy", false)) and not state.is_democracy:
		state.flags.erase(&"forced_democracy")
		report["democracy_entered"] = Democracy.enter(state, false)
	var snapshot: Dictionary = state.to_dict()
	snapshot["player_power"] = Rivals.player_power(state)
	snapshot["unrest_weight"] = Unrest.weight(state)
	snapshot["danger"] = Ending.danger_panel(state)
	state.log.append(snapshot)
	state.generation += 1
	report["ending"] = Ending.check(state)
	return report


static func run_world_war(state: GameState, player_neutral: bool = false) -> Dictionary:
	return WorldWar.run(state, player_neutral)
