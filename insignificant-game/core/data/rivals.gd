class_name RivalData
extends RefCounted
# 對手文明 (design/對手文明.md): 5 fixed automa P(r)=P0×g^r + naming table.
# attack_period N = on average one civil war every N generations (0 = never attacks).
# slow_burner: g 1.05 until generation 25, then 1.11 (late burst).

const CLASSES: Dictionary = {
	&"science_state": {
		"zh": "科學邦", "p0": 10.0, "g": 1.09, "attack_period": 12,
		"names": ["格物院聯邦", "賽先生共和國", "星曆議會"],
	},
	&"culture_state": {
		"zh": "文化國", "p0": 10.0, "g": 1.07, "attack_period": 0,
		"psyops_player_period": 8,   # 對你心戰: 下場戰開場手牌 −1 (driver decision on cadence)
		"names": ["繆思之邦", "風雅同盟", "百戲王國"],
	},
	&"iron_tribe": {
		"zh": "鐵血部", "p0": 12.0, "g": 1.08, "attack_period": 6,
		"names": ["狼旗汗國", "鐵砧部族", "磨刀氏族"],
	},
	&"vast_state": {
		"zh": "廣土邦", "p0": 14.0, "g": 1.07, "attack_period": 9,
		"names": ["千河王朝", "人海帝國", "廣袤聯盟"],
	},
	&"slow_burner": {
		# Design inconsistency: the doc's stated late g (1.11) yields only ~77 at gen 35,
		# but its 35-gen target is 230 (the biggest WW2 threat — the archetype's role).
		# The target wins: g_late calibrated to 1.24 (8×1.05^25×1.24^10 ≈ 233). Flagged
		# for the design-doc sync (see decision-w2-gaps.md addendum).
		"zh": "慢熱國", "p0": 8.0, "g": 1.05, "g_late": 1.24, "g_switch_gen": 25,
		"attack_period": 12,   # 低 — no number in the design (driver decision)
		"names": ["臥龍邦", "冬眠帝國", "遲醒共和國"],
	},
}

# --- power-scalar mappings (對手＝一條 power 標量; these project it onto other axes).
# The design pins only "國庫由 power 映射" — factors are driver decisions.
const TREASURY_PER_POWER: float = 2.0     # matches WW reparations floor power×2
const POPULATION_PER_POWER: float = 0.5
const CULTURE_PER_POWER: float = 0.3      # psyops condition compares player culture to this

const PSYOPS_DISCOUNT_CAP: float = 0.30   # 7折封頂
const DEFEAT_POWER_PENALTY: float = 0.9   # 每敗一場 power 受挫 (amount unpinned: ×0.9)
const CATCHUP_FLOOR: float = 0.65         # WW−1: strongest rival ≥ player×0.65
const CATCHUP_MAX_BOOST: float = 1.25     # bounded: at most +25%
const CATCHUP_CEILING: float = 1.5        # player protection ceiling (driver decision)
const CATCHUP_MAX_CUT: float = 0.75       # bounded: at most −25%
const ANNEX_POWER_THRESHOLD: float = 0.3  # 併吞: win war while their P < yours×0.3
