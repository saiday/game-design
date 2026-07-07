class_name CandidateData
extends RefCounted
# 民主 candidate truth table (design/民主.md) — 10 deterministic candidates. The UI shows
# ONLY the action copy; the axis moves are the fixed underlying truth (learnable, not a
# guessing game). Money deltas scale ×Era.coeff at apply time (driver decision — flat ±3
# would be noise against late-era budgets); other axes are flat.
#
# tendency groups (大眾媒體 pool bias targets): &"tech" | &"culture" | &"conflict" | &"" (none)

const CANDIDATES: Dictionary = {
	&"technocrat": {
		"zh": "科技官僚派", "copy": "擴編實驗室、補貼工程師、削減慶典",
		"population": 1, "culture": 0, "happiness": -1, "tech": 3, "money": -2,
		"tendency": &"tech",
	},
	&"culture_revival": {
		"zh": "文化復興派", "copy": "修復古蹟、資助劇團、外派文化使節",
		"population": 0, "culture": 3, "happiness": 1, "tech": 0, "money": -2,
		"tendency": &"culture",
	},
	&"iron_expansion": {
		"zh": "鐵血擴張派", "copy": "擴充部隊、尋求衝突、媒體噤聲",
		"population": 0, "culture": -1, "happiness": -2, "tech": 1, "money": 2,
		"tendency": &"conflict",
	},
	&"populist": {
		"zh": "民粹安撫派", "copy": "發放補貼、舉辦慶典、凍結徵稅",
		"population": 1, "culture": 1, "happiness": 3, "tech": 0, "money": -3,
		"tendency": &"",
	},
	&"free_market": {
		"zh": "商業自由派", "copy": "開放市場、簽貿易協定、鬆綁管制",
		"population": 0, "culture": 0, "happiness": -1, "tech": 1, "money": 4,
		"tendency": &"",
	},
	&"theocratic": {
		"zh": "神權守舊派", "copy": "重建大教堂、恢復祈禱日、審查出版",
		"population": 0, "culture": 2, "happiness": 2, "tech": -2, "money": -1,
		"tendency": &"culture",
	},
	&"military_industrial": {
		"zh": "軍工複合派", "copy": "增購軍備、擴大軍演、補貼兵工廠",
		"population": -1, "culture": 0, "happiness": -1, "tech": 2, "money": -2,
		"tendency": &"conflict",
	},
	&"green_pastoral": {
		"zh": "田園環保派", "copy": "限制開發、擴建公園、裁減軍費",
		"population": 1, "culture": 1, "happiness": 2, "tech": -1, "money": -1,
		"tendency": &"",
	},
	&"centrist": {
		"zh": "中庸技術官僚", "copy": "均衡預算、逐項檢討、小步改革",
		"population": 1, "culture": 1, "happiness": 1, "tech": 1, "money": -1,
		"tendency": &"",
	},
	&"revolutionary": {
		"zh": "革命激進派", "copy": "清洗舊勢力、動員群眾、沒收資產",
		"population": -2, "culture": 2, "happiness": -2, "tech": 0, "money": 3,
		"first_gen_happiness": 5,   # −2/代 but 首代 +5
		"tendency": &"conflict",
	},
}
