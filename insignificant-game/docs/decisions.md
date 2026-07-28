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
| Auto-resolution targeting | focus fire in deploy order; ~~siege/air demolish fortifications first~~ **superseded by ADR-0006/0007 (2026-07-26 design round)** — siege/air disable active fortifications first (never removed, engineer round-robin repair); melee cannot target 空域; 空襲 ground-only (the mobile ranged-row bypass retired with 壕溝 in the W10 corpus) | battle.gd |
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

## W14.5 gaps: air & fortification rules delta (ADR-0006/0007)

| Gap | Decision | Where |
|---|---|---|
| When in the tick window a 防空飛彈 fires (戰鬥.md pins 每回合一發 and the engine defaults, not the tick) | The window's first tick, right after 工兵 repair (tick 0) — a fort has no 攻速, so it doesn't ride the accumulator. Firing ahead of the strikes that suppress it is what makes the 防空+工兵 loop the exchange ADR-0006 describes; firing at the last tick would let one speed-1.0 bomber suppress the battery forever | battle.gd `_resolve_window`, `_fire_anti_air` |
| 「多個待修依序輪流」 order | A rotating cursor over the fort line: the repair starts scanning at the slot after the last one repaired, so a fort that keeps getting re-disabled can't starve its neighbour | battle.gd `BattleField.repair_cursor` |
| 戰功 for an aircraft the battery downs (a fort has no faction tag) | Credited to the side that owns the fort (player forts → `&"player"`), same as a 技能卡 clear | battle.gd `_fire_batteries` → `_credit_clear` |
| Scope of 僵局判定 (世界大戰.md pins it for the uncapped war; capped types say 回合上限到＝判輸照舊) | Only `round_cap == 0` battles settle on deadlock; the other six ride their round cap even when the field can no longer change | battle.gd `_check_exhaustion` → `_check_deadlock` |
| Deadlock where BOTH camps still hold 陸軍 but neither can act (e.g. only 工兵團 left on both sides) | Player's camp loses — the win branch requires the player to hold land AND the enemy not to (conservative, same ruling as mutual exhaustion) | battle.gd `_check_deadlock` |
| 盾陣 interception when the side has no ground unit to shield | No interception: 攔截一次射向我方地面單位的近戰攻擊 requires an attack aimed at a ground unit, and a player holding only forts is exhausted anyway (工事不計入場上清空) | battle.gd `_fire` (target picked before the fort line) |
| Non-terminating grind the rules do allow in an uncapped war (a lone sieger re-disabling a fort an engineer keeps repairing) | Sim-side guard only, never an engine cap: the bot stops driving at 200 rounds and takes the legal 認輸 exit | sim.gd `BATTLE_ROUND_GUARD` |

## W14.6 gaps: the cover chain (ADR-0008/0009)

| Gap | Decision | Where |
|---|---|---|
| 盾陣 active but the side holds no 遠程列 unit (戰鬥.md scopes the interception to an attack aimed at the 遠程列, and says nothing about a wall with nothing behind it) | No interception, and the wall stays active: the interception needs an attack aimed at the ranged row to exist, so an all-melee deck buys a screen that never fires and never disables. This replaces the W14.5 row above, which asked the same question about a side holding only forts | battle.gd `_fire` (target picked before the fort line, unchanged) |
| Enemy 盾陣 disabled with no repairer (正規軍 field screens but the roster has no 工兵團, and 戰鬥.md pins repair to 工兵團 only) | It stays disabled for the rest of the battle. Not a special case in code: `_repair_forts` already requires an engineer on that side, and there is never one on the enemy side. The asymmetry is the engineer line's value (ADR-0008), so no enemy-repair path is added | battle.gd `_repair_forts` (no change needed; assert it in `battle_test.gd`) |
| Whether `take_station` re-emits when a repair restores a wall (ADR-0008 makes the screen relationship a modelled fact, and a repair changes it) | Yes: re-emit `take_station` for the units the restored wall screens, at the same tick as the `repair`. A replayer that only ever saw stations at deploy time would show the ranged row uncovered for the rest of the battle after its wall came back | battle.gd `_repair_forts`; contract in architecture.md §Timeline event contract |

## W14.7 gaps: cover chain in core + the timeline replayer (ADR-0008/0009)

| Gap | Decision | Where |
|---|---|---|
| How many 盾陣 a 正規軍 army fields and when (戰鬥.md says 正規軍也出盾陣、同場上限 2 照算, but not the count or the timing) | One wall segment per wave that brings a 遠程列 regular, riding in with that wave, capped at `FORT_LIMIT` for the whole battle. The wall arrives with the row it covers, and 同場上限 2 counts the battle exactly as it does for the player, since forts are never removed | battle.gd `regular_screens`, `_arrive_waves` |
| Whether allied 正規軍 in a 世界大戰 bring screens too (they are player-side arrivals; the corpus discusses 對手兩型, not allies) | No. On the player's side the 工事線 is the player's own two slots and its engineer's beat; allied walls would eat the slots `deploy` gates on and give the player free cover it never paid 軍費 for | battle.gd `regular_screens` (returns none for `&"player"`) |
| Which side an event belongs to (the pinned contract carried labels only, and a label is a card id, so both camps' 步兵團 share one) | Every event gains `side`: the side of the party its actor field names (`by`, or `unit` where there is no `by`). Without it the first replayer could not attribute a single strike to a camp, and the W15 view would have hit the same wall. Contract updated in architecture.md rather than worked around in the replayer | battle.gd (every `events.append`), architecture.md §Timeline event contract |
| Per-unit identity in the timeline (`side` fixes camps, not repeats: two 步兵團 on one side still share a label) | Not solved this wave, and not papered over: `tools/export_timeline.gd` composes fixtures with one unit per class per side, so `(side, label)` is a genuine handle, and `check_motion_demo.js` fails if any event cannot be resolved. A replayer over a real 正規軍 roster (W15) needs per-unit ids added to the contract first | tools/export_timeline.gd header, architecture.md |
| When a unit announces its station (ADR-0008 makes the station a modelled fact but not its timing) | At `tick: 0` of the first round it fights in — deploys and wave arrivals both land at the round boundary, so a unit is stationed before the window it acts in. Re-announced when its cover changes (repair, a wall deployed behind it, a wall stripped) | battle.gd `_take_stations`, `_station_side` |
| Export fixture shape (nothing in the design says what a replayer is handed) | One 世界大戰-typed battle per era: uncapped, so it settles when the field can no longer change instead of expiring on a round cap; player fields one card per era-legal unit class plus its whole 工事線; enemy fields one 正規軍 per era-legal roster type. Skill cards are excluded — they hold no station in the chain and render nothing. A 40-round export guard mirrors sim.gd's: export-side only, never an engine cap | tools/export_timeline.gd |

## W14.8 gaps: top-down battlefield art (ADR-0009)

| Gap | Decision | Where |
|---|---|---|
| Whether a battle background plate may carry props (style-bible §11 said the backdrop tells the player which battle this is, and the approved side-view plates carried trees, fences, barricades and wreckage to do it) | No. A plate is flat ground and nothing else. Units move and fight across it, so a prop painted into the plate is an obstacle the engine cannot move, cannot occlude and cannot let a unit stand behind. Per-type identity moves to ground material, colour and light. Anything a unit could collide with is a separate object — 盾陣 already is one | `design/戰鬥.md` §場景呈現; `phase3_backgrounds_topdown_batch.py`; style-bible §3 + §11 |
| What neutral field scatter is allowed to do, now that the plate is bare (nothing in the corpus described scatter, and the obvious reading — "obstacles" — collides with ADR-0008) | **Decoration only.** Scatter does not block, does not give cover, takes no damage, and joins no layer of the 掩護鏈; no rule may read it. 工事線 stays the single cover model. Anything else would fork cover into two systems and hand the core the spatial model ADR-0006/0009 keep refusing it | `design/戰鬥.md` §場景呈現 |
| How scatter is placed, given the core holds no coordinates (ADR-0009: the core gains no coordinates, no velocity, no movement) | The **view** places it, seeded from the battle's own seed, avoiding the stations. Same battle ⇒ same arrangement on every replay, which the two replayers need; the core still holds no positions and emits no scatter events. The seed has to reach a fixture-driven replayer, so the timeline's opening scene event carries it — a contract question W15 settles, not an engine one | `design/戰鬥.md` §場景呈現; contract in architecture.md §Timeline event contract when W15 wires it |
| Whether `fort_anti_air_era1..3` are re-rendered (inventory.md still listed them) | Not re-rendered and dropped from the inventory: ADR-0006 retired those forms outright ("no air exists before 工業, so no anti-air exists either") and `core/data/cards.gd` agrees. The art inventory was the stale artifact, not the corpus | `assets/pipeline/inventory.md`; `phase3_units_topdown_batch.py` `START_ERA` |
| Whether flying weapons are an asset class (no row in inventory.md, no entry in `asset_paths.gd`, but the timeline emits a hit/miss per attack and the top-down replayer must draw something crossing the gap) | Yes, a tracked class of 8: `proj_<ammo>`, **no era of its own**, one sprite per ammo type shared by every era that fires it. Side-view art never needed it; the camera created the need | `assets/pipeline/inventory.md` §Flying weapons; `phase3_projectiles_topdown_batch.py` |
| Camera drift on mounted figures, wheeled carriages and tall timber structures (the steep-angle clause is obeyed everywhere else in the roster) | Accepted as-is by human ruling, not re-rolled. 20 renders across the 5 cells drifted 20/20 under identical wording, which is §8.3 rung 4's stop signal: the model trades camera for recognizability, because a horse from directly above is an oval. The cost is set coherence, not readability; reopening needs a tooling lever (§12), never another wording round | `assets/pipeline/review-brief-units-topdown.md` |
