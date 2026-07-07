class_name OpportunityData
extends RefCounted
# 機會表 (design/地圖與機會.md) + 國寶 acquisition (design/經濟與債務.md) as const data.
# MapNodes reads these tables; logic never hardcodes content.
#
# Effect keys understood by MapNodes.resolve_opportunity:
#   money_per_coeff  int  treasury delta × Era.coeff (signed)
#   cost_per_coeff   int  extra payment × Era.coeff (mitigation price; reported separately)
#   population       int  population delta
#   happiness        int  happiness delta (applied via Happiness.adjust, clamped 0..100)
#   rare_card        bool grant one rare card (recorded as flags[&"pending_rare_cards"])
#   treasure         bool grant one national treasure (flags[&"national_treasures"])
#   culture          int  culture delta

const TABLE: Dictionary = {
	&"merchant": {
		"label": "行商／寶藏",
		"base_weight": 40.0,
		"choices": {
			&"take_money": {"money_per_coeff": 30},
			&"take_card": {"rare_card": true},
		},
	},
	&"refugee": {
		"label": "難民",
		"base_weight": 30.0,
		"choices": {
			&"accept": {"population": 3, "happiness": -3},
			&"refuse": {"happiness": -5},
			&"pay": {"money_per_coeff": -20, "population": 2, "happiness": 2},
		},
	},
	&"disaster": {
		"label": "隱藏災難",
		"base_weight": 30.0,
		"choices": {
			&"endure": {"money_per_coeff": -25},
			# 減災: pay 15×coeff, damage drops from 25×coeff to 10×coeff.
			&"mitigate": {"money_per_coeff": -10, "cost_per_coeff": 15},
		},
	},
	&"national_treasure": {
		"label": "國寶",
		# Base weight 0: only reachable via astronomy line / moon_race weight bonuses
		# (design gives bonuses but no base weight — conservative choice, flagged).
		"base_weight": 0.0,
		"choices": {
			# Culture gain on acquisition has no number in the design (flagged): +5 baseline.
			&"accept": {"treasure": true, "culture": 5},
		},
	},
}

# Weight modifiers (percentage points on the table above).
const GOOD_DRAW_SHIFT: float = 20.0             # 幸福 ≥ 70: merchant +20, disaster -20
const SECULARIZATION_DISASTER_CUT: float = 10.0 # 推行世俗: disaster -10
const ASTRONOMY_TREASURE_BONUS: float = 10.0    # 學術·天文線 (any tier): treasure +10
const MOON_RACE_TREASURE_BONUS: float = 20.0    # 登月競賽: treasure +20
