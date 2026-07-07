class_name CardsData
extends RefCounted
# Static card catalog transcribed from design/卡牌.md (17 cards).
# Logic lives in core/cards.gd; this file is content only.
#
# Entry fields:
#   zh: String                 representative zh name (卡表「卡名」, identification)
#   class: StringName          &"personnel" | &"mechanical" | &"fortification" | &"skill"
#   source_kind: StringName    &"region" | &"building" | &"policy" | &"legacy"
#   source: StringName         canonical id from architecture.md the card requires
#   military_cost: int         base 軍費 (tier 1); units/fortifications scale ×Era coeff per tier
#   attack: int, hp: int       base 攻/血 (tier 1); scale ×Era coeff per tier; fort/skill = 0
#   row: StringName            自動佈陣: &"melee" | &"ranged" | &"air" | &"fortification" | &"global"
#   min_era: int               earliest era index (1..6) with a form (「—」in the evolution table)
#   evolves: bool              units + fortifications evolve in place; skills never do
#   era_names: Array           6 per-era form names ("" = no form yet); absent for skills
#   disband_pop: int           解散/刪牌 population recovery (+2 personnel, 0 otherwise)
#   destroyed_on_use: bool     用後永久銷毀 (本局不再取得) — policy one-shot skills
#   flags: Array               special-behavior markers consumed by Battle

const FORT_FIELD_LIMIT: int = 2  # 工事卡同場上限 2 (battlefield constraint, not deck count)

const CARDS: Dictionary = {
	&"infantry": {
		"zh": "步兵團",
		"class": &"personnel",
		"source_kind": &"region",
		"source": &"livelihood",
		"military_cost": 2,
		"attack": 1,
		"hp": 2,
		"row": &"melee",
		"min_era": 1,
		"evolves": true,
		"era_names": ["棍棒戰團", "長矛方陣", "劍盾步兵", "線列步兵", "摩托化步兵", "動力裝甲兵"],
		"disband_pop": 2,
		"destroyed_on_use": false,
		"flags": [],
	},
	&"archers": {
		"zh": "弓箭團",
		"class": &"personnel",
		"source_kind": &"region",
		"source": &"livelihood",
		"military_cost": 2,
		"attack": 1,
		"hp": 1,
		"row": &"ranged",
		"min_era": 1,
		"evolves": true,
		"era_names": ["投石手", "弓箭團", "弩手連", "火槍散兵", "狙擊小隊", "精準飛彈組"],
		"disband_pop": 2,
		"destroyed_on_use": false,
		"flags": [],
	},
	&"cavalry": {
		"zh": "騎兵團",
		"class": &"personnel",
		"source_kind": &"region",
		"source": &"livelihood",
		"military_cost": 3,
		"attack": 2,
		"hp": 2,
		"row": &"melee",
		"min_era": 1,
		"evolves": true,
		"era_names": ["馭獸騎手", "戰車騎兵", "重裝騎士團", "驃騎兵", "坦克營", "無人戰車群"],
		"disband_pop": 2,
		"destroyed_on_use": false,
		# mobile: may bypass melee row to strike enemy ranged row.
		# tank_from_modern: modern+ forms (tier >= 5) cross trenches (Cards.crosses_trench).
		"flags": [&"mobile", &"tank_from_modern"],
	},
	&"engineers": {
		"zh": "工兵團",
		"class": &"personnel",
		"source_kind": &"building",
		"source": &"arsenal",
		"military_cost": 2,
		"attack": 0,
		"hp": 3,
		"row": &"melee",
		"min_era": 1,
		"evolves": true,
		"era_names": ["修路隊", "築城匠", "攻城工兵", "工兵營", "機械化工兵", "戰鬥工程隊"],
		"disband_pop": 2,
		"destroyed_on_use": false,
		# fills_trench: on entry, fills one enemy trench (restores passage).
		# no_attack: support unit, never attacks.
		"flags": [&"fills_trench", &"no_attack"],
	},
	&"elite_forces": {
		"zh": "菁英特種部隊",
		"class": &"mechanical",
		"source_kind": &"building",
		"source": &"barracks",
		"military_cost": 5,
		"attack": 3,
		"hp": 4,
		"row": &"melee",
		"min_era": 2,
		"evolves": true,
		"era_names": ["", "禁衛軍", "聖殿武士", "擲彈兵", "特種部隊", "機甲突擊隊"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		"flags": [],
	},
	&"artillery": {
		"zh": "火砲",
		"class": &"mechanical",
		"source_kind": &"building",
		"source": &"barracks",
		"military_cost": 6,
		"attack": 4,
		"hp": 2,
		"row": &"ranged",
		"min_era": 2,
		"evolves": true,
		"era_names": ["", "弩砲", "射石砲", "野戰砲", "自走砲", "電磁砲"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		"flags": [&"siege"],  # siege: can demolish enemy fortifications
	},
	&"bomber": {
		"zh": "轟炸機",
		"class": &"mechanical",
		"source_kind": &"building",
		"source": &"barracks",
		"military_cost": 8,
		"attack": 5,
		"hp": 3,
		"row": &"air",
		"min_era": 4,
		"evolves": true,
		"era_names": ["", "", "", "熱氣球轟炸隊", "轟炸機聯隊", "匿蹤轟炸機"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		# air_strike: picks any target, can demolish fortifications.
		# non_land: cannot take the field alone for victory (戰鬥: 只剩空中單位不算).
		"flags": [&"air_strike", &"non_land"],
	},
	&"shield_wall": {
		"zh": "盾陣",
		"class": &"fortification",
		"source_kind": &"building",
		"source": &"arsenal",
		"military_cost": 3,
		"attack": 0,
		"hp": 0,
		"row": &"fortification",
		"min_era": 1,
		"evolves": true,
		"era_names": ["木盾牆", "盾陣", "城垛", "沙包工事", "混凝土碉堡", "複合裝甲牆"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		# blocks_melee_once: ignores attack value; absorbs one melee hit then is consumed.
		"flags": [&"blocks_melee_once"],
	},
	&"trench": {
		"zh": "壕溝",
		"class": &"fortification",
		"source_kind": &"building",
		"source": &"arsenal",
		"military_cost": 4,
		"attack": 0,
		"hp": 0,
		"row": &"fortification",
		"min_era": 1,
		"evolves": true,
		"era_names": ["陷坑", "壕溝", "護城壕", "鐵絲網塹壕", "反戰車壕", "自動化防線"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		# blocks_melee_contact: while present, enemy melee row cannot reach our units;
		# counterable by siege, enemy engineers (fill), or tank forms (cross).
		"flags": [&"blocks_melee_contact"],
	},
	&"anti_air": {
		"zh": "防空飛彈",
		"class": &"fortification",
		"source_kind": &"building",
		"source": &"arsenal",
		"military_cost": 4,
		"attack": 0,
		"hp": 0,
		"row": &"fortification",
		"min_era": 1,
		"evolves": true,
		"era_names": ["擋箭棚", "箭樓", "城防塔", "高射砲", "防空飛彈", "雷射攔截網"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		# blocks_ranged_once: absorbs one ranged or air-strike hit then is consumed.
		"flags": [&"blocks_ranged_once"],
	},
	&"war_song": {
		"zh": "軍歌",
		"class": &"skill",
		"source_kind": &"region",
		"source": &"culture",
		"military_cost": 3,
		"attack": 0,
		"hp": 0,
		"row": &"global",
		"min_era": 1,
		"evolves": false,
		"disband_pop": 0,
		"destroyed_on_use": false,
		"flags": [&"attack_buff_2_rounds"],  # 兩回合內全體 +1 攻
	},
	&"holes_dont_matter": {
		"zh": "這些破洞不影響功能",
		"class": &"skill",
		"source_kind": &"region",
		"source": &"culture",
		"military_cost": 1,
		"attack": 0,
		"hp": 0,
		"row": &"global",
		"min_era": 1,
		"evolves": false,
		"disband_pop": 0,
		"destroyed_on_use": false,
		"flags": [&"cost_discount_2_rounds"],  # 兩回合內出牌軍費 −1
	},
	&"love_and_peace": {
		"zh": "爛仗時候才宣揚愛與和平",
		"class": &"skill",
		"source_kind": &"legacy",
		"source": &"rock_spirit",
		"military_cost": 0,
		"attack": 0,
		"hp": 0,
		"row": &"global",
		"min_era": 1,
		"evolves": false,
		"disband_pop": 0,
		"destroyed_on_use": false,
		# after battle round 5: unconditionally destroy one non-leader enemy unit
		"flags": [&"destroy_non_leader_after_round_5"],
	},
	&"holy_warriors": {
		"zh": "聖戰士團",
		"class": &"mechanical",  # 部隊·國策限定 — no disband recovery, so mechanical rules
		"source_kind": &"policy",
		"source": &"holy_war",
		"military_cost": 4,
		"attack": 4,
		"hp": 1,
		"row": &"melee",
		"min_era": 3,
		"evolves": true,
		"era_names": ["", "", "聖戰士團", "神權火槍旅", "狂信裝甲師", "聖戰網軍"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		"flags": [&"fanatic"],  # 狂熱: high attack, thin hp (marker only)
	},
	&"privateers": {
		"zh": "私掠傭兵團",
		"class": &"mechanical",  # 部隊·國策限定 — no disband recovery, so mechanical rules
		"source_kind": &"policy",
		"source": &"great_voyage",
		"military_cost": 4,
		"attack": 2,
		"hp": 3,
		"row": &"melee",
		"min_era": 3,
		"evolves": true,
		"era_names": ["", "", "私掠傭兵團", "殖民遠征軍", "戰地承包商", "網路傭兵團"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		"flags": [&"plunder"],  # 掠奪: each unit it clears grants +5×Era coeff money
	},
	&"persuasion_broadcast": {
		"zh": "勸降廣播",
		"class": &"skill",
		"source_kind": &"policy",
		"source": &"cultural_export",
		"military_cost": 3,
		"attack": 0,
		"hp": 0,
		"row": &"global",
		"min_era": 1,
		"evolves": false,
		"disband_pop": 0,
		"destroyed_on_use": true,  # 用後永久銷毀，本局不再取得
		"flags": [&"convert_weak_enemy"],  # 使一個弱級敵方單位倒戈為我方
	},
	&"orbital_strike": {
		"zh": "軌道打擊",
		"class": &"skill",
		"source_kind": &"policy",
		"source": &"space_station",
		"military_cost": 5,
		"attack": 0,
		"hp": 0,
		"row": &"global",
		"min_era": 1,
		"evolves": false,
		"disband_pop": 0,
		"destroyed_on_use": true,  # 用後永久銷毀，本局不再取得
		"flags": [&"destroy_non_leader"],  # 無條件消滅一個非首領敵方單位
	},
}
