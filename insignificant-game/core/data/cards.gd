class_name CardsData
extends RefCounted
# Static card catalog transcribed from design/卡牌.md (16 cards: 卡牌總表 + 時代演化總表 +
# 品質分布表). Logic lives in core/cards.gd; this file is content only.
#
# Entry fields:
#   zh: String                 representative zh name (卡表「卡名」, identification only —
#                              the UI always shows the current era form via Cards.display_name)
#   class: StringName          &"personnel" | &"mechanical" | &"fortification" | &"skill"
#   source_kind: StringName    &"region" | &"building" | &"policy" | &"legacy"
#   source: StringName         canonical id from architecture.md the card requires
#   military_cost: int         base 軍費 (tier 1); units/fortifications scale ×Era coeff per tier
#   attack: int, hp: int       base 攻/血 (tier 1); scale ×Era coeff per tier; fort/skill = 0.
#                              Fixed per type+era, never rolled (D8) — quality is separate.
#   row: StringName            自動佈陣: &"melee" | &"ranged" | &"air" | &"fortification" | &"global"
#   evolves: bool              units + fortifications evolve in place; skills never do
#                              (era availability = Cards.has_form on era_names; no min_era field)
#   era_names: Array           6 per-era form names ("" = no form that era; a "" AFTER formed
#                              eras = the card auto-disbands on entering that era)
#   disband_pop: int           解散 population recovery (+2 personnel, 0 otherwise)
#   destroyed_on_use: bool     用後永久銷毀 (本局不再取得) — policy one-shot skills
#   flags: Array               special-behavior markers consumed by Battle

const FORT_FIELD_LIMIT: int = 2  # 工事卡同場上限 2 (battlefield constraint, not deck count)

# --- 單位品質 (卡牌.md §單位品質) ---------------------------------------------------------
# Only unit cards (personnel/mechanical) roll quality; fortifications and skills never do.
# QUALITY holds the v1 Medium bands ([lo, hi] inclusive); Bad/Good bands are derived by
# Cards.band_for: one band-width below/above, clamped (acc 0..100, dodge 0..50, speed >= 0.1).
# 工兵團 has only dodge (不主動攻擊、不出手 — no accuracy, no speed, and no draws for them).

const QUALITY: Dictionary = {
	&"infantry": {&"accuracy": [85.0, 95.0], &"dodge": [5.0, 15.0], &"speed": [0.9, 1.2]},
	&"archers": {&"accuracy": [60.0, 80.0], &"dodge": [10.0, 25.0], &"speed": [0.8, 1.1]},
	&"cavalry": {&"accuracy": [80.0, 90.0], &"dodge": [15.0, 30.0], &"speed": [1.0, 1.4]},
	&"engineers": {&"dodge": [5.0, 15.0]},
	&"elite_forces": {&"accuracy": [90.0, 98.0], &"dodge": [20.0, 35.0], &"speed": [1.1, 1.5]},
	&"artillery": {&"accuracy": [55.0, 75.0], &"dodge": [0.0, 10.0], &"speed": [0.6, 0.9]},
	&"bomber": {&"accuracy": [70.0, 85.0], &"dodge": [5.0, 15.0], &"speed": [0.5, 0.8]},
	&"holy_warriors": {&"accuracy": [85.0, 95.0], &"dodge": [0.0, 10.0], &"speed": [1.2, 1.6]},
	&"privateers": {&"accuracy": [80.0, 90.0], &"dodge": [10.0, 25.0], &"speed": [1.0, 1.3]},
}

# Grade roll (取得時抽定; probabilities and band width are calibration knobs)
const GRADE_ORDER: Array[StringName] = [&"bad", &"medium", &"good"]
const GRADE_PROBS: Dictionary = {&"bad": 0.10, &"medium": 0.80, &"good": 0.10}
const GRADE_PREFIX: Dictionary = {&"bad": "糟糕的", &"good": "可靠的"}  # medium: no prefix
const BAND_WIDTH_MULT: float = 1.0

# Clamps (卡牌.md §品質等級 夾限)
const ACCURACY_MAX: float = 100.0
const DODGE_MAX: float = 50.0
const SPEED_MIN: float = 0.1

# 成長階 v1 基準 (卡牌.md §成長): effect per medal level; acc/dodge cap at the clamps above,
# 攻速無封頂. Steps differ per stat by design.
const GROWTH_STEP: Dictionary = {&"accuracy": 3.0, &"dodge": 2.0, &"speed": 0.1}

# 經驗填滿門檻: the corpus pins the accrual sources (命中率＝出手攻擊, 閃避率＝被攻擊且活下來,
# 攻速＝每存活一個回合) and the per-medal steps, but not the fill size — these are v1 knobs
# (docs/decisions.md, W13). 1 XP per qualifying event; the medal lands when a stat's xp
# reaches its threshold (remainder carries; battle emits the &"medal" event at that tick).
const XP_TO_MEDAL: Dictionary = {&"accuracy": 5, &"dodge": 4, &"speed": 6}

# --- catalog -----------------------------------------------------------------------------

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
		"evolves": true,
		"era_names": ["馭獸騎手", "戰車騎兵", "重裝騎士團", "龍騎兵", "坦克營", "無人戰車群"],
		"disband_pop": 2,
		"destroyed_on_use": false,
		# 機動 is expressed through the quality bands (high speed/dodge), not a targeting flag.
		"flags": [],
	},
	&"engineers": {
		"zh": "工兵團",
		"class": &"personnel",
		"source_kind": &"building",
		"source": &"arsenal",
		"military_cost": 2,
		"attack": 0,
		"hp": 3,
		# 遠程列: the engineer stations BEHIND the wall it maintains and works at the 工事線
		#   (ADR-0008 掩護鏈). lane_stat checks no_attack before the row, so this move leaves
		#   閃避率 and the 老兵/勳章 lanes untouched.
		"row": &"ranged",
		"evolves": true,
		"era_names": ["修路隊", "築城匠", "攻城工兵", "工兵營", "機械化工兵", "戰鬥工程隊"],
		"disband_pop": 2,
		"destroyed_on_use": false,
		# repairs_fortifications: an engineer on field repairs ONE disabled fortification per
		#   round, round-robin over the fort line — 不限工事失效時誰在場, so engineers deployed in
		#   later waves repair forts disabled before they arrived (戰鬥.md 工事卡, ADR-0007).
		# no_attack: support unit, never attacks.
		"flags": [&"repairs_fortifications", &"no_attack"],
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
		"evolves": true,
		"era_names": ["", "禁衛軍", "聖殿武士", "擲彈兵", "特種部隊", "生化超級士兵"],
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
		"evolves": true,
		"era_names": ["", "", "射石砲", "野戰砲", "自走砲", "電磁砲"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		"flags": [&"siege"],  # siege: disables an active enemy fortification (ADR-0007)
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
		"evolves": true,
		"era_names": ["", "", "", "飛船轟炸隊", "轟炸機聯隊", "匿蹤轟炸機"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		# air_strike: 空襲 hits GROUND targets only (never air-to-air, ADR-0006) and disables
		#   an active enemy fortification first (fort-busting is suppression now, ADR-0007).
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
		"evolves": true,
		"era_names": ["木盾牆", "盾陣", "城垛", "沙包工事", "電網", "複合裝甲牆"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		# screens_ranged_row: 盾陣＝遠程列的掩體 (ADR-0008). One card is one wall segment spanning
		# the ranged row's frontage, not a shield on one named unit. It ignores attack value,
		# intercepts one melee attack aimed at a unit in the 遠程列 — and nothing else — and is
		# disabled by the interception: never removed, never consumed, repairable by engineers
		# (ADR-0007). Also disabled by siege/air strikes.
		"flags": [&"screens_ranged_row"],
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
		"evolves": true,
		# 防空飛彈始於工業時代——有空軍才有防空 (卡牌.md 工事卡的時代演化表, ADR-0006). The era
		# 1-3 forms (擋箭棚/箭樓/城防塔) are retired with the absorb job they used to do; their
		# approved art stays on disk, knowingly stranded (AssetPaths.UNIT_COVERAGE).
		"era_names": ["", "", "", "高射砲", "防空飛彈", "雷射攔截網"],
		"disband_pop": 0,
		"destroyed_on_use": false,
		# fires_at_air: the dedicated active air counter (ADR-0006). Fires once per round
		# window at one 空域 unit and a hit DESTROYS it — a fortification ignores attack values
		# when it blocks, so it ignores hit points when it fires. Engine defaults resolve it
		# (命中 100%, no 品質三項); the target's 閃避率 still rolls. It intercepts nothing.
		"flags": [&"fires_at_air"],
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
		"evolves": false,
		"disband_pop": 0,
		"destroyed_on_use": false,
		# after battle round 5: destroy one non-leader enemy unit. 首領＝硬級: non-leader
		# skills hit only weak/medium irregulars, never hard tiers or 正規軍 (卡牌.md).
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
		"evolves": true,
		# 工業-only form; auto-disbands on entering 現代 (時代演化總表: 形態止於某個時代).
		"era_names": ["", "", "", "神權火槍旅", "", ""],
		"disband_pop": 0,
		"destroyed_on_use": false,
		"flags": [&"fanatic"],  # 狂熱: high attack, thin hp (marker only)
	},
	&"privateers": {
		"zh": "私掠傭兵",
		"class": &"mechanical",  # 部隊·國策限定 — no disband recovery, so mechanical rules
		"source_kind": &"policy",
		"source": &"great_voyage",
		"military_cost": 4,
		"attack": 2,
		"hp": 3,
		"row": &"melee",
		"evolves": true,
		# Forms end at 現代; auto-disbands on entering 資訊 (時代演化總表).
		"era_names": ["", "", "盜匪", "竊賊", "網路駭客", ""],
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
		"evolves": false,
		"disband_pop": 0,
		"destroyed_on_use": true,  # 用後永久銷毀，本局不再取得
		# convert_non_leader: one non-leader enemy unit defects (首領＝硬級 rule as above).
		"flags": [&"convert_non_leader"],
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
		"evolves": false,
		"disband_pop": 0,
		"destroyed_on_use": true,  # 用後永久銷毀，本局不再取得
		"flags": [&"destroy_non_leader"],  # 無條件消滅一個非首領敵方單位 (同上首領規則)
	},
}
