# Design-gap decision log

Where the design is silent, the implementer decides conservatively and logs it here: one row
per gap, grouped by the wave that hit it. Never invent mechanics. All values are v1 baseline
knobs, calibration-eligible like everything else. Decisions with lasting architectural
consequences also get an ADR in the repo root's `docs/adr/`.

## Starting values (W1)

The corpus pins start population (0, 營運.md; the 政權崩潰 check arms only after 人口 first
reaches 5, 內亂與失敗.md — synced in W13.5) but not start treasury, happiness, culture, or
tech. Driver decisions:

| Field | Start | Reasoning |
|---|---|---|
| treasury | 30 | Buys one region (20×1) + one cheap building in the tribal era without going into debt on generation 1; forces a real choice by generation 2–3. |
| happiness | 70 | Exactly at the ≥70 good-draw threshold: the player starts with the perk and loses it on the first neglect, teaching the 幸福 downstreams early. |
| culture | 0 | Both accumulate purely from buildings/policies; no reason for a head start. |
| tech | 0 | Same. |

If playtest shows generation-1 deadlock or a too-comfortable opening, tune treasury first
(it's the least entangled knob).

## W2 gaps: inner systems

Small numbers/rules the corpus doesn't pin, decided during W2 implementation (the interesting
ones go into the balance report):

| Gap | Decision | Where |
|---|---|---|
| 節點 known:unknown ratio (design gives only "1–3 nodes, unknown=60/40") | 50/50 | map_nodes.gd |
| 隱藏戰 share among unknown battles | 20% | map_nodes.gd |
| 略過節點 cost (付錢略過, no number) | 10×時代係數 (same as battle retreat) | map_nodes.gd |
| 建立國教 +30 decay schedule (隨時代衰退) | −10 per era transition (gone in 3 eras) | happiness.gd |
| Base population cap with zero livelihood investment | 20 | data/buildings.gd |
| 升級的階差額 | 基準錢 × tier difference (tiers advance one at a time → base × 1) | operations.gd |
| 國寶 sale price / culture on acquisition (no numbers) | 30×係數 / +5 culture | economy.gd, data/opportunities.gd |
| 國寶 base opportunity weight | 0 (only reachable via 天文線 +10 / 登月 +20) | data/opportunities.gd |
| Starting deck (deck ≥5 implied from generation 1, none named) | 5× 步兵團 | cards.gd |
| Build/unlock/skip costs and money floor | ALL may push treasury negative — debt is the brake, no wall | operations.gd etc. |
| Stat scaling | Evolving cards (units/forts) scale attack/hp/軍費 by their tier's era coefficient; skills stay flat (era-neutral by design) | cards.gd |

**Design observation surfaced in the balance report:** 隱藏災難 endure (−25×係數) vs mitigate
(pay 15×係數, take −10×係數) is a money wash — identical total. As written, mitigation has no
mechanical upside. Either intended as a psychological choice or a knob to revisit.

## W3–W5 gaps: outer systems, view, difficulty

| Gap | Decision | Where |
|---|---|---|
| Rival axes from the power scalar (design pins only "國庫由 power 映射") | treasury = power×2 (matches WW reparations floor), population = power×0.5, culture = power×0.3 (psyops condition) | data/rivals.gd |
| 慢熱國 late growth | g_late calibrated 1.24 — the doc's stated 1.11 yields ~77 at gen 35 vs its own 230 target (the "biggest WW2 threat" role); target wins, corpus value updated | data/rivals.gd, corpus 對手文明 |
| 慢熱國 aggression ("低", no number) | every ~12 generations | data/rivals.gd |
| 文化國 psyops-vs-player cadence | every ~8 generations; effect re-specified by W13 as the D16 accuracy debuff (see W13 gaps) | data/rivals.gd |
| Civil-war defeat power hit ("power 受挫") | ×0.9 per loss | rivals.gd |
| Catch-up player-protection ceiling (floor 0.65 is pinned; ceiling isn't) | strongest rival ≤ player×1.5, adjustment bounded ±25% | rivals.gd |
| First contact | all rivals met at generation 1 (+5 influence) | rivals.gd |
| Battle hand system (design implies "opening hand" but pins nothing) | ~~opening hand 4, draw 1/round~~ **retired by W12** — the W10 corpus pins D1: no hand, any unplayed card any round, 軍費 the only gate | battle.gd |
| Auto-resolution targeting | focus fire in deploy order; siege/air demolish fortifications first (the mobile ranged-row bypass retired with 壕溝 in the W10 corpus) | battle.gd |
| Enemy reinforcements | ~~whole opening at battle start~~ **retired by W12** — the corpus pins rolled wave schedules (D2/D5) | battle.gd |
| 為民主而流血 frequency ("unknown 低頻") | 15% of unknown battles while unlocked-but-refused and happiness<70 | map_nodes.gd |
| World war battle | automated common-table strength contest (±15% seeded roll); camps/turn-order/merit/last-hit/reparations math faithful; per-card play not simulated | world_war.gd |
| Legacy passive magnitudes ("小幅永久＋") | +1/+2 per-generation values per legacy (table in legacy.gd) | legacy.gd |
| Democracy candidate money deltas | ×時代係數 at apply time (flat ±3 would be noise at gen 40) | democracy.gd |
| Democracy auto-explore value | 15×係數 per node (tax-battle-equivalent) | democracy.gd |
| Negative treasury at democracy entry | not reduced (only positive treasury takes the ×0.4 cut) | democracy.gd |
| Collapse epilogue text | driver addition (corpus has only the 7 victory texts) | data/epilogues.gd |
| Difficulty formula | 3-channel signed-level model; full rationale in docs/difficulty-design.md, synced to corpus | difficulty.gd |
| Window resolution | standing decision: Full HD 1920×1080 for both the PoC window and the shipped game (core is resolution-blind). History: PoC opened at 1280×720 for placeholder-UI density; the 2026-07-09 Moebius style pick retired the 640×360 pixel-art plan and set 1920×1080 | project.godot |

## W11 gaps: card model

| Gap | Decision | Where |
|---|---|---|
| Evolution auto-disband vs 牌組下限 5 (卡牌.md pins 自動解散 at form end but not its interaction with the minimum) | Forced disband proceeds even below 5; the minimum guards **voluntary** 解散 only — a formless ghost card would contradict the evolution table | cards.gd |
| Reward-card pick's rng track (卡牌.md pins the quality roll on `cards`; the pick itself names no track) | Same `cards` track: pick → grade → stats is one reproducible acquisition stream | cards.gd |

## W12 gaps: battle model

| Gap | Decision | Where |
|---|---|---|
| 正規軍 wave composition within a budget (對手文明 pins the budget and roster, not the mix) | Greedy strongest-first over unit types formed this era ((攻+血)×係數 desc); 國策限定 and support types (no_attack 工兵團) stay out of the conversion roster; a rival too weak for any wave still fields one weakest regular in wave 1 | battle.gd |
| Mutual simultaneous exhaustion (both fields empty, both with nothing left to commit — no land force claims the field) | Player 敗北 (conservative: the design defines victory only as the other side still holding 陸軍) | battle.gd |
| Which battle ends issue the 戰後獎勵卡 (design: 每場結束必發, excludes only cancelled battles) | Win / loss / 判輸 / retreat all issue the roll; only 讓步・戒嚴-cancelled battles (never fought) don't | battle.gd |
| Within-tick fire order (design pins speed ordering across ticks, not inside one tick) | Player units before enemy units, each side in deploy order — fixed order is part of the determinism contract | battle.gd |

> 2026-07-24, wayfinder #12: the corpus now pins what earlier rows decided or assumed — 起始牌組
> 5×步兵團 is promoted into 卡牌.md §起始牌組, and the W1 note's 「corpus pins start population
> (12)」 is superseded by 起始人口 0 (營運.md; collapse check arms at first 人口 ≥ 5, 內亂與失敗.md).
> Same pass: post-battle reward card every battle (first-seen free / duplicate 5×係數), 解散 unified
> as the single paid removal (8×係數), and quality grades Bad/Medium/Good. Code follows with the
> #14 fix wave and W11+.

## W13 gaps: growth

| Gap | Decision | Where |
|---|---|---|
| XP fill size (卡牌.md pins the accrual sources and per-medal steps, not how much XP fills a medal) | 1 XP per qualifying event; medal at accuracy 5 / dodge 4 / speed 6 XP, remainder carries | data/cards.gd `XP_TO_MEDAL` |
| Dodge-XP qualifying events (被攻擊且活下來 — which resolutions count?) | Dodged attacks and survived hits accrue; a miss doesn't (the attack never reached the unit), and the killing blow doesn't (didn't survive it) | battle.gd `_fire` |
| 老兵 +1 vs earned levels (「起始 +1 成長階」 vs 「常駐底線」) | Additive: the +1 sits under the earned ladder (level 3 + 老兵 = 4 effective), never a `max(levels, 1)` floor — "starting one level up" shifts the whole ladder | cards.gd `veteran_bonus` |
| 兵營 medal stock lifetime (產出勳章, no expiry rule) | Unassigned medals bank without cap or expiry; production lands at generation start (Turn.begin_generation) so the medal is assignable in the same operate phase | operations.gd, game_state.gd `medals` |
| 民主後 auto-assign default target (卡牌.md marks the rule itself a calibration item) | Deck-order-first unit card takes the whole stock (deterministic, no rng) | operations.gd `auto_assign_medals` |
| 文化國 debuff magnitude (D16; 威脅 極低＝nuisance) | −10 accuracy percentage points, floored at 0, next battle only; 傳播線 心戰效果增強 stays outgoing-only per 營運.md | data/rivals.gd `ENEMY_PSYOPS_ACCURACY_DEBUFF` |

## W12.5 gaps: world war on the battle engine

| Gap | Decision | Where |
|---|---|---|
| 出場序 → concrete rounds (世界大戰.md pins the interleave order, not arrival timing) | Per camp: civs sort by 卡池張數 desc (tie: class id), each contributes wave 1 then wave 2 in that order; the camp queue's k-th wave arrives round k+1; player-camp arrivals precede enemy-camp within a round | world_war.gd `_build_waves`, battle.gd prepared-wave sort |
| Per-civ budget split across its 2 waves (波數上限 2 pinned, split isn't) | P×0.5 total (same conversion as 文明戰爭), 60/40 heavier-first | world_war.gd `WAVE_SHARES` |
| A civ too weak for any 正規軍 unit | Fields one weakest regular in its first wave (mirrors the 文明戰爭 guard) | world_war.gd |
| Psyops discount vs camp membership (對手文明: 「世界大戰同桌時它的單位」, camp unspecified) | A discounted civ's 正規軍 fight discounted wherever they appear — allied camp included (you weakened them; now they're your weak ally) | battle.gd `_regular_unit` |
| 最後一擊 when the losing camp's last unit wasn't cleared by a winner (e.g. player concedes with enemies standing) | Falls back to the winning camp's highest real 戰功 civ | world_war.gd `_top_merit` |
| Pool distribution rounding (守恆: 發出去的正好等於池) | Floor-rounded shares; the remainder (and the 20% bonus) goes to the last hitter — payouts sum to the pool exactly | world_war.gd `finish` |
| Faction tag in 文明戰爭 (WW5 pins civ tags for the shared table only) | Single-rival battles keep `&"enemy"`; civ-id faction tags appear only in 世界大戰 units | battle.gd |
