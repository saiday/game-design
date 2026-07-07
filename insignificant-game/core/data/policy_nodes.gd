class_name PolicyNodes
extends RefCounted
# 國策 DAG v3.0 (design/國策.md) — 24 nodes / 139 BP total, transcribed faithfully.
# Solid edges (＋) -> requires_all; dashed choose-one groups (／) -> requires_any
# (each inner Array is one group; at least one member of EACH group must be completed).
# "effects" is a free-form description: rule-modifier entries document what other
# modules query via state.policies.has(id); "one_shot_*" entries are applied by
# Policy._apply_completion at the moment the node completes. No node produces
# per-generation output (buildings do that) — policy only rewrites rules or fires
# one-shot events.

const TOTAL_BP: int = 139
const NODE_COUNT: int = 24

const NODES: Dictionary = {
	# ---- 權力穩固 (power) ----
	&"centralization": {  # 中央集權 — root
		"cost_bp": 4,
		"theme": &"power",
		"requires_all": [],
		"requires_any": [],
		"effects": {"unrest_base_weight_delta": -0.05},
	},
	&"bureaucracy": {  # 官僚體系 — hub: feeds secret_police / enlightened_absolutism / political_marriage
		"cost_bp": 5,
		"theme": &"power",
		"requires_all": [&"centralization"],
		"requires_any": [],
		"effects": {"tax_bonus": 0.10},
	},
	&"secret_police": {  # 秘密警察
		"cost_bp": 6,
		"theme": &"power",
		"requires_all": [&"bureaucracy"],
		"requires_any": [],
		"effects": {
			"unrest_weight_delta": -0.10,
			"one_shot_happiness": -5,
			"grants_legacy": &"martial_law",  # active-type legacy (戒嚴)
			"martial_law_available": true,
		},
	},
	&"cultural_revolution": {  # 文化大革命 — terminal
		"cost_bp": 6,
		"theme": &"power",
		"requires_all": [&"secret_police", &"mass_media"],
		"requires_any": [],
		"effects": {
			"one_shot_happiness_set_to": 100,
			"one_shot_population_multiplier": 0.8,  # permanent -20%, round down
			"terminal": true,
		},
	},
	&"enlightened_absolutism": {  # 開明專制 — terminal
		"cost_bp": 6,
		"theme": &"power",
		"requires_all": [&"bureaucracy", &"hundred_schools"],
		"requires_any": [],
		"effects": {
			"one_shot_happiness": 10,
			"bp_carryover_cap": 3,  # rule modifier queried by Operations (2 -> 3)
			"terminal": true,
		},
	},

	# ---- 科技 (tech) ----
	&"writing_calendar": {  # 文字與曆法 — root
		"cost_bp": 4,
		"theme": &"tech",
		"requires_all": [],
		"requires_any": [],
		"effects": {"tech_gate_multiplier": 8},  # card tech gate 10×era_index -> 8×era_index
	},
	&"secularization": {  # 推行世俗
		"cost_bp": 6,
		"theme": &"tech",
		"requires_all": [&"writing_calendar", &"hundred_schools"],
		"requires_any": [],
		"effects": {
			"disaster_opportunity_weight_delta": -0.10,
			"grants_legacy": &"rational_spirit",
		},
	},
	&"patent_system": {  # 專利制度
		"cost_bp": 6,
		"theme": &"tech",
		"requires_all": [&"secularization"],
		"requires_any": [],
		"effects": {"card_unlock_cost_multiplier": 0.5},
	},
	&"moon_race": {  # 登月競賽
		"cost_bp": 8,
		"theme": &"tech",
		"requires_all": [&"patent_system"],
		"requires_any": [],
		"effects": {
			"one_shot_tech": 30,
			"treasure_opportunity_weight_delta": 0.20,
		},
	},
	&"space_station": {  # 建立太空站 — terminal
		"cost_bp": 8,
		"theme": &"tech",
		"requires_all": [&"moon_race"],
		"requires_any": [],
		"effects": {"unlocks_card": &"orbital_strike", "terminal": true},  # 軌道打擊 (Cards owns)
	},

	# ---- 宗教 (religion) ----
	&"ancestor_worship": {  # 祖靈崇拜 — root
		"cost_bp": 3,
		"theme": &"religion",
		"requires_all": [],
		"requires_any": [],
		"effects": {"concession_cost_multiplier": 0.5},
	},
	&"state_religion": {  # 建立國教
		"cost_bp": 6,
		"theme": &"religion",
		"requires_all": [&"ancestor_worship"],
		"requires_any": [],
		"effects": {
			"one_shot_happiness": 30,  # decays by era — handled by Happiness via flag state_religion_gen
			"grants_legacy": &"religious_dogma",
		},
	},
	&"theocracy": {  # 政教合一
		"cost_bp": 6,
		"theme": &"religion",
		"requires_all": [&"state_religion", &"centralization"],
		"requires_any": [],
		"effects": {
			"unrest_weight_delta": -0.10,
			"tech_gate_delta_per_era": 2,  # 神學審查: card tech gate +2×era_index
		},
	},
	&"holy_war": {  # 聖戰 — terminal
		"cost_bp": 7,
		"theme": &"religion",
		"requires_all": [&"theocracy"],
		"requires_any": [],
		"effects": {
			"offensive_war_open_attack_bonus": 1,
			"victory_reparations_multiplier": 1.5,
			"unlocks_card": &"holy_warrior_band",  # 聖戰士團 (Cards owns)
			"terminal": true,
		},
	},

	# ---- 文化 (culture) ----
	&"hundred_schools": {  # 百家爭鳴 — root, hub: feeds enlightened_absolutism / secularization / mass_media
		"cost_bp": 4,
		"theme": &"culture",
		"requires_all": [],
		"requires_any": [],
		"effects": {
			"skill_card_military_spend_delta": -1,
			"skill_card_military_spend_min": 1,
		},
	},
	&"mass_media": {  # 大眾媒體 — hub: feeds cultural_revolution / cultural_export / world_expo / intelligence_agency
		"cost_bp": 6,
		"theme": &"culture",
		"requires_all": [&"hundred_schools"],
		"requires_any": [],
		"effects": {"democracy_pool_bias": 0.10},
	},
	&"cultural_export": {  # 文化輸出 — terminal
		"cost_bp": 7,
		"theme": &"culture",
		"requires_all": [&"mass_media"],
		"requires_any": [[&"great_voyage", &"political_marriage"]],
		"effects": {
			"defection_gate_multiplier": 5,  # 投誠門檻 8×era_index -> 5×era_index
			"influence_accumulation_multiplier": 1.5,
			"unlocks_card": &"persuasion_broadcast",  # 勸降廣播 (Cards owns)
			"terminal": true,
		},
	},

	# ---- 探索 (exploration) ----
	&"great_voyage": {  # 大航海 — root
		"cost_bp": 6,
		"theme": &"exploration",
		"requires_all": [],
		"requires_any": [],
		"effects": {
			"map_nodes_min": 2,  # per-generation node count floor 2 (was 1-3)
			"unlocks_card": &"privateer_band",  # 私掠傭兵團 (Cards owns)
		},
	},
	&"world_map": {  # 世界地圖
		"cost_bp": 5,
		"theme": &"exploration",
		"requires_all": [&"great_voyage", &"scout_camp"],
		"requires_any": [],
		"effects": {"fog_shows_node_face": true},  # unknown nodes show battle/opportunity face
	},
	&"world_expo": {  # 萬國博覽會 — terminal
		"cost_bp": 8,
		"theme": &"exploration",
		"requires_all": [&"world_map", &"mass_media"],
		"requires_any": [],
		"effects": {
			"one_shot_money_per_coeff": 50,  # +50 × Era.coeff
			"one_shot_culture": 5,
			"one_shot_influence_all_living_rivals": 10,
			"terminal": true,
		},
	},

	# ---- 偵查 (scouting) ----
	&"scout_camp": {  # 斥候營 — root
		"cost_bp": 3,
		"theme": &"scouting",
		"requires_all": [],
		"requires_any": [],
		"effects": {"intel_coverage": [&"tribal", &"classical"]},
	},
	&"political_marriage": {  # 政治聯姻
		"cost_bp": 5,
		"theme": &"scouting",
		"requires_all": [&"scout_camp"],
		"requires_any": [[&"state_religion", &"bureaucracy"]],
		"effects": {
			"intel_coverage": [&"faith", &"industrial"],
			"one_shot_influence_all_living_rivals": 5,
		},
	},
	&"intelligence_agency": {  # 情報單位
		"cost_bp": 6,
		"theme": &"scouting",
		"requires_all": [&"political_marriage"],
		"requires_any": [[&"secret_police", &"mass_media"]],
		"effects": {
			"intel_coverage": [&"modern"],
			"no_hidden_battle_surprise": true,
		},
	},
	&"satellite_surveillance": {  # 衛星監控 — terminal
		"cost_bp": 8,
		"theme": &"scouting",
		"requires_all": [&"intelligence_agency", &"moon_race"],
		"requires_any": [],
		"effects": {
			"intel_coverage": [&"information"],
			"see_enemy_opening_deployment": true,
			"terminal": true,
		},
	},
}
