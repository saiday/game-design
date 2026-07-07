class_name BuildingData
extends RefCounted
# 營運 content tables (design/營運.md), transcribed faithfully. Logic lives in Operations.
# Per-generation outputs are FIXED per line (一線一棟、產出不疊加) — tier changes the era
# name (and housing's pop-cap bonus), not the output.

const REGION_COST_BASE: int = 20   # 建立區域: 1 BP + 20 錢 × 時代係數 (no escalation)

const REGIONS: Dictionary = {
	&"livelihood": {
		"zh": "民生區", "lines": [&"housing", &"food", &"medical"],
		"passive": {"pop_cap": 10}, "unlocks_card_class": &"personnel",
	},
	&"academic": {
		"zh": "學術區", "lines": [&"school", &"astronomy"],
		"passive": {"tech": 1}, "unlocks_card_class": &"",
	},
	&"military": {
		"zh": "軍事區", "lines": [&"barracks", &"arsenal"],
		"passive": {"opening_hand": 1}, "unlocks_card_class": &"mechanical",
	},
	&"culture": {
		"zh": "文化區", "lines": [&"arts", &"media"],
		"passive": {"culture": 1}, "unlocks_card_class": &"skill",
	},
	&"finance": {
		"zh": "金融區", "lines": [&"commerce", &"bank", &"debt_office"],
		"passive": {"income": 2}, "unlocks_card_class": &"",
	},
}

# "output" keys match Operations.production's pinned keys. "min_tier" = first real tier
# (debt_office only exists from the faith era column onward). "min_era" gates building it.
const LINES: Dictionary = {
	&"housing": {
		"zh": "住宅", "region": &"livelihood", "base_cost": 10,
		"output": {"population": 1}, "pop_cap_per_tier": 5, "min_era": 1, "min_tier": 1,
		"names": ["茅屋", "民居", "街坊", "公寓", "國宅", "智慧住宅"],
	},
	&"food": {
		"zh": "食物", "region": &"livelihood", "base_cost": 10,
		"output": {"population": 1}, "min_era": 1, "min_tier": 1,
		"names": ["屯墾區", "農莊", "莊園農地", "農場", "機械化農場", "垂直農場"],
	},
	&"medical": {
		"zh": "醫療", "region": &"livelihood", "base_cost": 15,
		"output": {"happiness": 2}, "min_era": 1, "min_tier": 1,
		"names": ["藥草棚", "醫館", "修道院醫院", "公立醫院", "醫療中心", "基因診所"],
	},
	&"school": {
		"zh": "學堂", "region": &"academic", "base_cost": 15,
		"output": {"tech": 1}, "min_era": 1, "min_tier": 1,
		"names": ["結繩學堂", "學院", "修道院抄本", "大學", "研究中心", "國家實驗室"],
	},
	&"astronomy": {
		"zh": "天文", "region": &"academic", "base_cost": 20,
		"output": {"tech": 1}, "treasure_weight_bonus": 10.0, "min_era": 1, "min_tier": 1,
		"names": ["觀星台", "天文台", "曆法院", "觀測站", "太空計畫", "深空探測"],
	},
	&"barracks": {
		"zh": "兵營", "region": &"military", "base_cost": 15,
		"output": {}, "card_pool": &"mechanical", "opening_slots": 1, "min_era": 1, "min_tier": 1,
		"names": ["校場", "軍營", "騎士團部", "徵兵所", "軍事基地", "無人機聯隊"],
	},
	&"arsenal": {
		"zh": "兵工", "region": &"military", "base_cost": 15,
		"output": {}, "card_pool": &"fortification", "min_era": 1, "min_tier": 1,
		"names": ["打鐵舖", "兵器坊", "鑄造所", "兵工廠", "軍工複合體", "國防科技園"],
	},
	&"arts": {
		"zh": "藝術", "region": &"culture", "base_cost": 15,
		"output": {"culture": 1, "happiness": 1}, "min_era": 1, "min_tier": 1,
		"names": ["篝火廣場", "神廟／劇院", "大教堂", "歌劇院", "藝術中心", "媒體中心"],
	},
	&"media": {
		"zh": "傳播", "region": &"culture", "base_cost": 20,
		"output": {"culture": 1}, "psyops_potency": 0.15, "min_era": 1, "min_tier": 1,
		"names": ["說書人", "詩社", "印刷坊", "報社", "廣播電視", "社群平台"],
	},
	&"commerce": {
		"zh": "商業", "region": &"finance", "base_cost": 15,
		"output": {"income": 2}, "min_era": 1, "min_tier": 1,
		"names": ["市集", "商行", "商會", "商業中心", "百貨集團", "電商平台"],
	},
	&"bank": {
		"zh": "銀行", "region": &"finance", "base_cost": 20,
		"output": {}, "min_era": 1, "min_tier": 1,
		"names": ["錢莊", "金庫", "私有銀行", "中央銀行", "投資銀行", "證券市場"],
	},
	&"debt_office": {
		"zh": "國債司", "region": &"finance", "base_cost": 40,
		"output": {}, "min_era": 3, "min_tier": 3,
		"names": ["", "", "國債司", "國債局", "財政部公債署", "主權基金"],
	},
}

# 政權核心: free, permanent from generation 1, renames per era, holds the policy slot.
const CORE_NAMES: Array[String] = ["部落中心", "城鎮中心", "領主莊園", "市政廳", "中央政府", "總統府"]

const BASE_POP_CAP: int = 20   # population cap with zero livelihood investment (driver decision)
