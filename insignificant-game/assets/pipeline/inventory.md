# Asset inventory — Insignificant (v1 scope, cookbook §7 Phase 1)

Built 2026-07-08 from the Obsidian corpus setting docs (營運 / 卡牌 / 戰鬥 / 時代與回合 /
對手文明 / 國策 / Legacy / 經濟與債務 / 幸福 / 內亂與失敗 / 地圖與機會 / 民主 / 世界大戰 / 結局 /
Insignificant.md). Ids follow cookbook §9 naming and the canonical StringName ids in
`insignificant-game/poc-docs/architecture.md`; era numbers are 1=部落 2=古典 3=信仰 4=工業
5=現代 6=資訊 (時代與回合).

Naming extensions beyond §9 (this doc is their definition): `fort_<type>_era<n>` (battlefield
fortifications — structures, not units), `portrait_civ_<rival_class>` (class id instead of an
index — display names are drawn per run from the 命名表, the class is the stable identity),
`portrait_candidate_<id>` (democracy candidates), `ui_<template>` (Phase 2 frozen templates).

**Phase 1 resolution (2026-07-09): pixelization was dropped, so the sprite-grid proposals in the
section headings below are void** — per-class *generation sizes* now live in
`style-bible.md` §3 (headings kept as written for the record; see "Proposals" at the bottom).
Counts: buildings 76 · units 63 + enemy 18 · card art 68 · icons 74 · UI templates 5 ·
backgrounds 9 · portraits 15 → **328 assets**.

## Buildings (`building_<line>_era<n>`, proposed 64×64) — source: 營運 建築線總表/政權核心

One sprite per line per era form (一線一棟、就地升級換名換皮). `debt_office` starts era 3
(信仰時代解鎖). `core` = 政權核心 (free, always present, holds the policy tree).

| id | subject (era form) |
|---|---|
| building_housing_era1 | 茅屋 |
| building_housing_era2 | 民居 |
| building_housing_era3 | 街坊 |
| building_housing_era4 | 公寓 |
| building_housing_era5 | 國宅 |
| building_housing_era6 | 智慧住宅 |
| building_food_era1 | 屯墾區 |
| building_food_era2 | 農莊 |
| building_food_era3 | 莊園農地 |
| building_food_era4 | 農場 |
| building_food_era5 | 機械化農場 |
| building_food_era6 | 垂直農場 |
| building_medical_era1 | 藥草棚 |
| building_medical_era2 | 醫館 |
| building_medical_era3 | 修道院醫院 |
| building_medical_era4 | 公立醫院 |
| building_medical_era5 | 醫療中心 |
| building_medical_era6 | 基因診所 |
| building_school_era1 | 結繩學堂 |
| building_school_era2 | 學院 |
| building_school_era3 | 修道院抄本 |
| building_school_era4 | 大學 |
| building_school_era5 | 研究中心 |
| building_school_era6 | 國家實驗室 |
| building_astronomy_era1 | 觀星台 |
| building_astronomy_era2 | 天文台 |
| building_astronomy_era3 | 曆法院 |
| building_astronomy_era4 | 觀測站 |
| building_astronomy_era5 | 太空計畫 |
| building_astronomy_era6 | 深空探測 |
| building_barracks_era1 | 校場 |
| building_barracks_era2 | 軍營 |
| building_barracks_era3 | 騎士團部 |
| building_barracks_era4 | 徵兵所 |
| building_barracks_era5 | 軍事基地 |
| building_barracks_era6 | 無人機聯隊 |
| building_arsenal_era1 | 打鐵舖 |
| building_arsenal_era2 | 兵器坊 |
| building_arsenal_era3 | 鑄造所 |
| building_arsenal_era4 | 兵工廠 |
| building_arsenal_era5 | 軍工複合體 |
| building_arsenal_era6 | 國防科技園 |
| building_arts_era1 | 篝火廣場 |
| building_arts_era2 | 神廟劇院 |
| building_arts_era3 | 大教堂 |
| building_arts_era4 | 歌劇院 |
| building_arts_era5 | 藝術中心 |
| building_arts_era6 | 媒體中心 |
| building_media_era1 | 說書人 |
| building_media_era2 | 詩社 |
| building_media_era3 | 印刷坊 |
| building_media_era4 | 報社 |
| building_media_era5 | 廣播電視 |
| building_media_era6 | 社群平台 |
| building_commerce_era1 | 市集 |
| building_commerce_era2 | 商行 |
| building_commerce_era3 | 商會 |
| building_commerce_era4 | 商業中心 |
| building_commerce_era5 | 百貨集團 |
| building_commerce_era6 | 電商平台 |
| building_bank_era1 | 錢莊 |
| building_bank_era2 | 金庫 |
| building_bank_era3 | 私有銀行 |
| building_bank_era4 | 中央銀行 |
| building_bank_era5 | 投資銀行 |
| building_bank_era6 | 證券市場 |
| building_debt_office_era3 | 國債司 |
| building_debt_office_era4 | 國債局 |
| building_debt_office_era5 | 財政部公債署 |
| building_debt_office_era6 | 主權基金 |
| building_core_era1 | 部落中心 |
| building_core_era2 | 城鎮中心 |
| building_core_era3 | 領主莊園 |
| building_core_era4 | 市政廳 |
| building_core_era5 | 中央政府 |
| building_core_era6 | 總統府 |

## Units (`unit_<type>_era<n>`, proposed 32×32) — source: 卡牌 部隊卡的時代演化總表

Battlefield sprites for the auto-deployed rows (戰鬥). "—" eras in the corpus table have no
form and no asset. Player sprites are reused mirrored for enemy sides where the enemy is a
named civ; abstract enemy tiers get their own generic sprites (below).

| id | subject (era form) |
|---|---|
| unit_infantry_era1 | 棍棒戰團 |
| unit_infantry_era2 | 長矛方陣 |
| unit_infantry_era3 | 劍盾步兵 |
| unit_infantry_era4 | 線列步兵 |
| unit_infantry_era5 | 摩托化步兵 |
| unit_infantry_era6 | 動力裝甲兵 |
| unit_archers_era1 | 投石手 |
| unit_archers_era2 | 弓箭團 |
| unit_archers_era3 | 弩手連 |
| unit_archers_era4 | 火槍散兵 |
| unit_archers_era5 | 狙擊小隊 |
| unit_archers_era6 | 精準飛彈組 |
| unit_cavalry_era1 | 馭獸騎手 |
| unit_cavalry_era2 | 戰車騎兵 |
| unit_cavalry_era3 | 重裝騎士團 |
| unit_cavalry_era4 | 驃騎兵 |
| unit_cavalry_era5 | 坦克營 |
| unit_cavalry_era6 | 無人戰車群 |
| unit_engineers_era1 | 修路隊 |
| unit_engineers_era2 | 築城匠 |
| unit_engineers_era3 | 攻城工兵 |
| unit_engineers_era4 | 工兵營 |
| unit_engineers_era5 | 機械化工兵 |
| unit_engineers_era6 | 戰鬥工程隊 |
| unit_elite_forces_era2 | 禁衛軍 |
| unit_elite_forces_era3 | 聖殿武士 |
| unit_elite_forces_era4 | 擲彈兵 |
| unit_elite_forces_era5 | 特種部隊 |
| unit_elite_forces_era6 | 機甲突擊隊 |
| unit_artillery_era2 | 弩砲 |
| unit_artillery_era3 | 射石砲 |
| unit_artillery_era4 | 野戰砲 |
| unit_artillery_era5 | 自走砲 |
| unit_artillery_era6 | 電磁砲 |
| unit_bomber_era4 | 熱氣球轟炸隊 |
| unit_bomber_era5 | 轟炸機聯隊 |
| unit_bomber_era6 | 匿蹤轟炸機 |
| unit_holy_warriors_era3 | 聖戰士團 |
| unit_holy_warriors_era4 | 神權火槍旅 |
| unit_holy_warriors_era5 | 狂信裝甲師 |
| unit_holy_warriors_era6 | 聖戰網軍 |
| unit_privateers_era3 | 私掠傭兵團 |
| unit_privateers_era4 | 殖民遠征軍 |
| unit_privateers_era5 | 戰地承包商 |
| unit_privateers_era6 | 網路傭兵團 |

### Fortifications (`fort_<type>_era<n>`, proposed 32×32) — source: 卡牌 工事卡的時代演化表

| id | subject (era form) |
|---|---|
| fort_shield_wall_era1 | 木盾牆 |
| fort_shield_wall_era2 | 盾陣 |
| fort_shield_wall_era3 | 城垛 |
| fort_shield_wall_era4 | 沙包工事 |
| fort_shield_wall_era5 | 混凝土碉堡 |
| fort_shield_wall_era6 | 複合裝甲牆 |
| fort_trench_era1 | 陷坑 |
| fort_trench_era2 | 壕溝 |
| fort_trench_era3 | 護城壕 |
| fort_trench_era4 | 鐵絲網塹壕 |
| fort_trench_era5 | 反戰車壕 |
| fort_trench_era6 | 自動化防線 |
| fort_anti_air_era1 | 擋箭棚 |
| fort_anti_air_era2 | 箭樓 |
| fort_anti_air_era3 | 城防塔 |
| fort_anti_air_era4 | 高射砲 |
| fort_anti_air_era5 | 防空飛彈 |
| fort_anti_air_era6 | 雷射攔截網 |

### Abstract enemy tiers (`unit_enemy_<tier>_era<n>`, proposed 32×32) — source: 戰鬥 敵方單位級別

Generic hostiles for 收稅戰/地圖戰/隱藏戰/內亂戰 (弱/中/硬 per era look).

| id | subject |
|---|---|
| unit_enemy_weak_era1 … unit_enemy_weak_era6 | 弱級敵方單位 ×6 era looks |
| unit_enemy_mid_era1 … unit_enemy_mid_era6 | 中級敵方單位 ×6 era looks |
| unit_enemy_hard_era1 … unit_enemy_hard_era6 | 硬級敵方單位 ×6 era looks |

(18 assets; each of the 3 tier lines above is 6 assets, listed compact to keep this readable.)

## Card illustrations (`card_<id>_era<n>` / `card_<id>`, proposed 96×128) — source: 卡牌

One illustration per era form for evolving cards (卡就地演化換皮); skill cards are era-neutral
(one illustration each, 技能卡不演化名). Illustrations are produced to the frozen card-frame
content-window rect (Phase 2); frame + art + `Label` text composite in Godot, never baked.
Unit/fort card art may use the matching `unit_`/`fort_` sprite as img2img init for family
coherence — same subject, larger canvas.

| id family | era coverage | subjects |
|---|---|---|
| card_infantry_era1..6 | 6 | 棍棒戰團→動力裝甲兵 (as unit table) |
| card_archers_era1..6 | 6 | 投石手→精準飛彈組 |
| card_cavalry_era1..6 | 6 | 馭獸騎手→無人戰車群 |
| card_engineers_era1..6 | 6 | 修路隊→戰鬥工程隊 |
| card_elite_forces_era2..6 | 5 | 禁衛軍→機甲突擊隊 |
| card_artillery_era2..6 | 5 | 弩砲→電磁砲 |
| card_bomber_era4..6 | 3 | 熱氣球轟炸隊→匿蹤轟炸機 |
| card_holy_warriors_era3..6 | 4 | 聖戰士團→聖戰網軍 |
| card_privateers_era3..6 | 4 | 私掠傭兵團→網路傭兵團 |
| card_shield_wall_era1..6 | 6 | 木盾牆→複合裝甲牆 |
| card_trench_era1..6 | 6 | 陷坑→自動化防線 |
| card_anti_air_era1..6 | 6 | 擋箭棚→雷射攔截網 |
| card_war_song | 1 | 軍歌 (era-neutral skill) |
| card_holes_dont_matter | 1 | 這些破洞不影響功能 (era-neutral skill) |
| card_love_and_peace | 1 | 爛仗時候才宣揚愛與和平 (Legacy-granted skill) |
| card_persuasion_broadcast | 1 | 勸降廣播 (policy-limited skill) |
| card_orbital_strike | 1 | 軌道打擊 (policy-limited skill) |

(68 assets.)

## UI icons (`icon_<id>`, proposed 16×16) — sources: 經濟與債務 / 幸福 / 內亂與失敗 / 營運 / 國策 / Legacy / 地圖與機會 / 戰鬥 / 民主 / 時代與回合

Hard requirement (Insignificant.md, 結局): 債務深度、利息、內亂權重、人口距崩潰門檻 visible at
all times — those stats need unmistakable icons. Glyphs are generated onto the frozen icon
base plate (Phase 2, §6).

| group | ids | count |
|---|---|---|
| Core stats | icon_money icon_population icon_bp icon_tech icon_culture icon_happiness icon_debt icon_interest icon_unrest icon_power | 10 |
| Battle stats | icon_attack icon_hp icon_military_cost | 3 |
| Card classes | icon_class_personnel icon_class_mechanical icon_class_fortification icon_class_skill | 4 |
| Regions | icon_region_livelihood icon_region_academic icon_region_military icon_region_culture icon_region_finance | 5 |
| Policy themes | icon_theme_power icon_theme_tech icon_theme_culture icon_theme_religion icon_theme_exploration icon_theme_recon | 6 |
| Policy nodes | icon_policy_centralization icon_policy_bureaucracy icon_policy_secret_police icon_policy_cultural_revolution icon_policy_enlightened_absolutism icon_policy_writing_calendar icon_policy_secularization icon_policy_patent_system icon_policy_moon_race icon_policy_space_station icon_policy_ancestor_worship icon_policy_state_religion icon_policy_theocracy icon_policy_holy_war icon_policy_hundred_schools icon_policy_mass_media icon_policy_cultural_export icon_policy_great_voyage icon_policy_world_map icon_policy_world_expo icon_policy_scout_camp icon_policy_political_marriage icon_policy_intelligence_agency icon_policy_satellite_surveillance | 24 |
| Legacies | icon_legacy_religious_dogma icon_legacy_rational_spirit icon_legacy_critical_spirit icon_legacy_rock_spirit icon_legacy_democratic_spirit icon_legacy_melting_pot icon_legacy_martial_law | 7 |
| Map nodes | icon_map_battle icon_map_unknown icon_map_war icon_map_skip | 4 |
| Opportunities | icon_opp_merchant icon_opp_refugee icon_opp_disaster icon_opp_treasure | 4 |
| Eras | icon_era1 icon_era2 icon_era3 icon_era4 icon_era5 icon_era6 | 6 |
| Democracy | icon_fund | 1 |

(74 assets.)

## UI templates (`ui_<template>`) — Phase 2 frozen structure (§6), inventoried here for scope

| id | subject | note |
|---|---|---|
| ui_card_frame | card frame/border | content-window rect recorded in style bible at freeze; per-class variants only if design requires (start with 1 + class-color accent) |
| ui_panel_9slice | panel chrome 9-slice source | NinePatchRect |
| ui_button_9slice | button 9-slice source | normal state; pressed via modulate first |
| ui_icon_plate | icon base plate | glyphs generated inside it |
| ui_divider | divider/separator strip | |

(5 assets.)

## Backgrounds (`bg_*`, proposed 640×360) — sources: 時代與回合 / 結局 / Insignificant.md

Era backdrops serve both the battle screen and the operations screen (UI panels over them).

| id | subject |
|---|---|
| bg_era1 | 部落 era backdrop |
| bg_era2 | 古典 era backdrop |
| bg_era3 | 信仰 era backdrop |
| bg_era4 | 工業 era backdrop |
| bg_era5 | 現代 era backdrop |
| bg_era6 | 資訊 era backdrop |
| bg_title | title screen |
| bg_ending_survive | 走到最後/提前完全勝利 epilogue backdrop (ranked 結語 are text over it) |
| bg_ending_collapse | 政權崩潰 game-over backdrop |

(9 assets.)

## Portraits (`portrait_civ_<class>` / `portrait_candidate_<id>`, proposed 64×64) — sources: 對手文明 / 民主

One portrait per rival class (per-run drawn names share the class portrait) and one per
democracy candidate faction (ids from `core/data/candidates.gd`).

| id | subject |
|---|---|
| portrait_civ_science_state | 科學邦 (格物院聯邦/賽先生共和國/星曆議會) |
| portrait_civ_culture_state | 文化國 (繆思之邦/風雅同盟/百戲王國) |
| portrait_civ_iron_tribe | 鐵血部 (狼旗汗國/鐵砧部族/磨刀氏族) |
| portrait_civ_vast_state | 廣土邦 (千河王朝/人海帝國/廣袤聯盟) |
| portrait_civ_slow_burner | 慢熱國 (臥龍邦/冬眠帝國/遲醒共和國) |
| portrait_candidate_technocrat | 科技官僚派 |
| portrait_candidate_culture_revival | 文化復興派 |
| portrait_candidate_iron_expansion | 鐵血擴張派 |
| portrait_candidate_populist | 民粹安撫派 |
| portrait_candidate_free_market | 商業自由派 |
| portrait_candidate_theocratic | 神權守舊派 |
| portrait_candidate_military_industrial | 軍工複合派 |
| portrait_candidate_green_pastoral | 田園環保派 |
| portrait_candidate_centrist | 中庸技術官僚 |
| portrait_candidate_revolutionary | 革命激進派 |

(15 assets.)

## Proposals (Phase 1 human gate — RESOLVED 2026-07-09)

**Outcome:** the human picked recipe r4 (Krea-2-Turbo + Moebius LoRA) and **dropped pixelization
for all assets**, so neither proposal below was adopted. No master palette exists; style cohesion
comes from the locked recipe. Per-class generation sizes replace sprite grids — see
`style-bible.md`. Kept for the record:

**Master palette candidates** (Lospec; license verified at download, see manifest) — *not adopted*:
1. **endesga-32** — 32 colors, balanced generalist, strong on earth/stone/metal ramps (buildings across 6 eras).
2. **resurrect-64** — 64 colors, widest range; safest for 6-era span (tribal ochres → neon info-age) at the cost of looser cohesion.
3. **apollo** — 46 colors, muted/painterly bias; strongest single mood, may starve the 資訊 era of saturated accents.

**Sprite grids** (cookbook §7 starting proposal, unchanged after building the inventory —
volumes support it) — *void with pixelization*: buildings 64×64 · units/forts 32×32 · card art
96×128 · icons 16×16 · backgrounds 640×360 · portraits 64×64 (new class, not in §7's list).
