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
| What neutral field scatter is allowed to do, now that the plate is bare (nothing in the corpus described scatter, and the obvious reading — "obstacles" — collides with ADR-0008) | **Neutral cover with a shot budget** (human ruling, ADR-0010; the decoration-only answer this row first carried is superseded). Some props carry a barrier tier, a hurt land unit falls back behind an intact one, and absorbing its last shot destroys it. Cover no longer forks into two systems because it is now *one* system with two owners: a 盾陣 and a barrier-bearing scatter obey the same rule, and the only difference is that a wall is repairable and scatter is not | `design/戰鬥.md` §場景呈現 + §工事卡; ADR-0010 |
| How scatter is placed, given the core holds no coordinates (ADR-0009: the core gains no coordinates, no velocity, no movement) | The **view** places it, seeded from the battle's own seed, avoiding the stations. Same battle ⇒ same arrangement on every replay, which the two replayers need. The core now holds the barrier *facts* (which barriers, shots left, who is behind each) but still no positions, so a scatter event names a barrier by id and never by location. The seed has to reach a fixture-driven replayer, so the timeline's opening scene event carries it — a contract question W15 settles | `design/戰鬥.md` §場景呈現; contract in architecture.md §Timeline event contract when W14.9 wires it |
| Whether `fort_anti_air_era1..3` are re-rendered (inventory.md still listed them) | Not re-rendered and dropped from the inventory: ADR-0006 retired those forms outright ("no air exists before 工業, so no anti-air exists either") and `core/data/cards.gd` agrees. The art inventory was the stale artifact, not the corpus | `assets/pipeline/inventory.md`; `phase3_units_topdown_batch.py` `START_ERA` |
| Whether flying weapons are an asset class (no row in inventory.md, no entry in `asset_paths.gd`, but the timeline emits a hit/miss per attack and the top-down replayer must draw something crossing the gap) | Yes, a tracked class of 8: `proj_<ammo>`, **no era of its own**, one sprite per ammo type shared by every era that fires it. Side-view art never needed it; the camera created the need | `assets/pipeline/inventory.md` §Flying weapons; `phase3_projectiles_topdown_batch.py` |
| Which axis a 盾陣 sprite is authored on (on the field a wall lies across the lane, top edge to bottom edge, and asking the model for that axis by name tapered the segment to a vanishing point along its own length for three rounds) | **Every barrier ships top to bottom, so the view rotates nothing.** Human ruling. The axis is an outcome to MEASURE per approved sprite, not something the prompt states: e1/e3/e4/e6 landed on axis unasked, and the two that did not were fixed by the two different means their angles deserve — e5 was a clean right angle, turned once losslessly by the freeze script, while e2 was diagonal, where any turn resamples the sprite and rotates its shading with it, so it was re-rolled instead. An axis CAN be asked for, but only as a bounded pair of points (the segment's two end stakes pinned near the top and bottom edges), never as a run: "its length running from near the top of the frame down to near the bottom" tapered every wall in round 3, because naming a long line names a viewer for it to recede from | measurements in `assets/pipeline/phase3_units_topdown_picks.json` §`barrier_render_axis`; `assets/pipeline/review-brief-units-topdown.md` §1; the rotation itself is applied in `phase3_units_topdown_freeze.py` |
| How `manifest.jsonl` records art that a later wave replaces (its status vocabulary is candidate / approved / rejected, with **no supersession value**, and W14.8 overwrites 76 approved side-view rows) | Two new status values rather than a new field on `approved`. `superseded` + `superseded_by: <new render id>` for a row whose asset was replaced in place; `retired` + `retired_reason` for one whose subject no longer exists (`unit_anti_air_era1..3`, ADR-0006). Leaving them at `approved` was rejected because `asset_paths.gd`'s header promises the registry holds only status=approved assets, and 76 rows describing deleted files would make that false; adding a flag instead of changing status was rejected because a reader filtering `status == "approved"` then silently ships stale art. Superseded rows keep every reproducibility field they had, so the record loses nothing | `assets/pipeline/phase3_units_topdown_freeze.py`, `phase3_backgrounds_topdown_freeze.py` |
| Camera drift on mounted figures, wheeled carriages and tall timber structures (the steep-angle clause is obeyed everywhere else in the roster) | Accepted as-is by human ruling, not re-rolled. 20 renders across the 5 cells drifted 20/20 under identical wording, which is §8.3 rung 4's stop signal: the model trades camera for recognizability, because a horse from directly above is an oval. The cost is set coherence, not readability; reopening needs a tooling lever (§12), never another wording round | `assets/pipeline/review-brief-units-topdown.md` |

## W14.9 gaps: the cover model delta (ADR-0010)

The human's ruling gave the shape (cover absorbs ranged fire, not melee; scatter is neutral cover
with weak/medium/hard tiers; a hurt land unit takes cover automatically; scatter is never repaired).
These are the pins it did not carry.

| Gap | Decision | Where |
|---|---|---|
| 盾陣's own shot budget (the ruling gave the scatter tiers as 1-2 / 2-3 / 3-5 and said 盾陣 matches the hard tier, without naming its number) | **3～5, rolled per wall on the `battle` track when it deploys**, and re-rolled when an engineer repairs it. Rolled rather than fixed so a wall matches the tier it is being equated with, tier for tier; re-rolled on repair because the alternative (a wall remembering its first roll for the whole battle) makes 同場上限 2 a lottery the player cannot see and cannot play around | `design/戰鬥.md` §工事卡; `design/卡牌.md` 盾陣 row |
| How many neutral barriers a field carries (the corpus says the view places scatter from the seed, which cannot decide a number the core has to know) | **One instance per barrier-carrying prop in that battle type's approved scatter roster**, so the number is read off the art table and never invented: 世界大戰 2, 稅收/暴動/野戰/民主 1 each, 內戰 1, 隱藏戰 0. Decorative props (no tier) stay uncounted and the view may scatter as many as it likes. A per-battle random count was rejected: it would make 隱藏戰's zero an accident instead of the identity it currently is | `assets/pipeline/inventory.md` §Field scatter; `phase3_scatter_topdown_coverage.json` |
| Whether 帶攻城／空襲 can target scatter, as it targets forts (ADR-0007 gives siegers a no-roll disable against active fortifications) | **No.** Scatter is not a fortification: nothing aims at it, and it only erodes by absorbing fire aimed at the unit behind it. Letting siegers strip cover would hand them a second job and make the hard tier's 3-5 shots meaningless against exactly the decks that already answer walls | ADR-0010; `design/戰鬥.md` §場景呈現 |
| Whether 空襲 fire is absorbed by cover, now that cover stops everything that is not melee (the ruling drew the line at melee, which leaves bombs on the absorbed side) | **No. Cover absorbs 遠程列 fire only.** A wall stands in front of a row and a bomb comes from above it, so absorbing 空襲 would make every 盾陣 a second-rate 防空飛彈 and quietly delete the bomber's reason to exist. 空襲's existing rules are untouched: ground-only targets, fort-busting first | `design/戰鬥.md` §工事卡; ADR-0006 unchanged |
| What "hurt" means for automatic cover-seeking | **Any HP loss** (`hp < max_hp`). The simplest testable reading, and the one that puts the visible fallback where the player expects it — the moment a unit is first hit. A threshold (half HP, say) was rejected as a knob nobody asked for | `core/battle.gd` `_seek_cover`; units carry `max_hp` from W14.9 on |
| What happens to a unit whose barrier is destroyed under it | It is exposed again, and falls back to another intact barrier at the next opportunity if one is free. Barriers are first-come and shared by both sides, so the tick order decides who gets the last rock — the same ordering that already decides who strikes first | `core/battle.gd` `_absorb_barrier` → `_seek_cover_all` |
| Whether 空域 units use cover | **No.** Scatter is ground dressing and the ruling says land units. Air keeps ADR-0006's answers: only 遠程列 fire and 防空飛彈 reach it | `design/戰鬥.md` §場景呈現 |
| Which cover answers first when a hurt 遠程列 unit stands behind BOTH a 盾陣 and a rock (the corpus describes each separately and never stacks them) | The **wall**, then the barrier. The 工事線 stands in front of the whole 遠程列, so a shot crossing it meets the wall before anything the unit found for itself; the rock is what is left once the wall is down. Spending both on one shot was rejected outright — one shot, one absorption | battle.gd `_fire` (the `kind == &"ranged"` chain) |
| Whether absorption happens before or after the accuracy／dodge rolls | **Before, and no roll happens at all** — 無視攻擊力 already means the shot never resolves, and the pre-ADR-0010 interception was pre-roll too. The consequence is deliberate and worth saying out loud: a blind attacker drains cover exactly as fast as a marksman, so cover buys time against volume of fire, not against quality of fire | battle.gd `_fire` (ahead of `state.rng.chance`) |
| When a 正規軍 screen rolls its budget: at wave composition or at arrival (佈陣時抽定 does not distinguish the two for a wall that arrives with a wave) | **At arrival**, when it actually takes the 工事線 — so a wall the 同場上限 2 turns away never rolls at all, and the roll order on the `battle` track follows the field rather than the schedule | battle.gd `_arrive_waves` → `_arm_wall` |
| Where "the next opportunity" is for an exposed or newly-arrived hurt unit | The **round boundary**, right after repair and stationing (`tick: 0`), player units in deploy order then enemy units. Same fixed order as the tick window, which is what makes 先到先用 deterministic | battle.gd `_seek_cover_all` |
| Whether one barrier can shelter more than one unit | **No — one occupant.** 先到先用 only means anything if a taken rock is taken. Occupancy lives on the unit (`unit["cover"]`), not on the barrier, so a dead unit releases its cover the moment it dies without anyone having to remember to | battle.gd `_barrier_free` |
| Whether a 勸降-converted unit keeps the rock it was hiding behind when it changes sides | **Yes.** A barrier belongs to nobody, so switching sides changes nothing about who may stand behind it. It re-stations in the 掩護鏈 (that is a layer, and it changed row) but its cover is a position, and it is still in it | battle.gd `_cast_skill` (convert branch: `stationed` resets, `cover` does not) |
| The non-terminating grind the new rule adds to an uncapped war (一支工兵 + 一道盾陣 vs a lone ranged attacker: the repair re-arms the wall at tick 0 every round, so a one-shot-per-round attacker can never empty it) | Same ruling as the W14.5 row above: **sim-side guard only, never an engine cap.** The rules do allow it, and the two drivers that could spin on it already stop — `sim.gd` concedes at 200 rounds, `tools/export_timeline.gd` at 40. The asymmetry is intended (工兵 is the engineer line's value), and melee, 攻城 and 空襲 all still walk through it | sim.gd `BATTLE_ROUND_GUARD`; tools/export_timeline.gd `ROUND_GUARD` |
| How the barrier roster reaches a fixture-driven replayer, given barrier events name a prop id (architecture.md pins labels as non-identities) | As **state, not events**: a new `barriers` array per era in `docs/fixtures/battle_timeline.json`, exactly as `units` and `forts` already are. A prop id is a genuine handle because a battle fields at most one instance per prop; where they stand stays the view's, from the battle seed | tools/export_timeline.gd; architecture.md §Timeline event contract |

## W15.0 gaps: per-unit identity and the backdrop registry

Two prerequisites the view wave inherits rather than invents: architecture.md already named the
identity hole as the thing W15 must close before it replays a real 正規軍 roster, and the 17
approved backdrop plates were on disk with nothing mapping them.

| Gap | Decision | Where |
|---|---|---|
| How a replayer tells two units of one class apart (labels are card ids, so both 步兵團 on a side answer to one label — the hole W14.7 documented and deferred) | An int **`uid` on every unit and fort**, unique within the battle, handed out in arrival order. A label stays what it always was and keeps picking the sprite; the uid picks *which* sprite. Renaming labels into identities was rejected: the label is what resolves to art, and two replayers already read it that way | `core/battle.gd` `_assign_uids`; architecture.md §Timeline event contract |
| Which payload keys carry an identity | **All of them, with no exceptions**: every key naming a unit or a fort has `<key>_uid` beside it, so a replayer derives the identity key from the label key instead of memorising a table. `0` means the key names no entity (`by: &"skill"`, an unscreened row). Listing only the keys that repeat today was rejected — the list would go stale the first time a rule moved | battle.gd (18 emission sites); `test/battle_test.gd` asserts the rule mechanically |
| Whether 中立掩體 need one too | **No.** A battle fields at most one instance per scatter prop, so the prop id is already a handle (the W14.9 row above pins that). A uid there would be a second name for the same thing | architecture.md §Timeline event contract |
| When uids are assigned, given tests and the world-war composer build fields outside the arrival path | One idempotent sweep at `start`, at the end of every `deploy`, and at the top of every `end_round` — so a unit injected straight into a BattleField is identified at the next boundary like any other, and nothing has to remember to call a constructor. Assigning inside the unit constructors was rejected: `regular_unit` is public and has no battle to count on | battle.gd `_assign_uids` callers |
| Whether a 勸降-converted unit is a new unit | **No — it keeps its uid.** The regiment is the same men fighting for someone else, and a replayer that saw it pop out of existence and a stranger appear would be showing something that did not happen | battle.gd `_cast_skill` (convert branch) |
| How the view resolves backdrops, given `AssetPaths` registered every other approved class but not the 17 `bg_*` plates | `BATTLE_PLATES` keyed by the **canonical battle-type id**, mirroring `SCATTER` — the art pipeline keeps its own shorter plate names and the registry is the one place the two naming schemes meet. City plates resolve by era, the route map is a single plate reused every generation | `core/data/asset_paths.gd`; `test/asset_paths_test.gd` |

## W15.1 gaps: the view comes back, and the city becomes the screen

Restoring `view/` against the post-W12 core surfaced gaps that were invisible while nothing
rendered. Three of them are the same gap wearing different clothes: **content that had no display
name**, because until now nothing showed it to a human.

| Gap | Decision | Where |
|---|---|---|
| 24 policy nodes, 7 battle types and 4 battle outcomes had no player-facing name, so the UI printed `enlightened_absolutism` and `tax_battle` | A **`zh` field in the data table** for anything that is a NAME (`PolicyNodes.NODES`, `Battle.TYPES`); a view-side map only for *phrasings* the content has no opinion about (勝/敗/撤軍, effect labels). The line is ownership: a name belongs to the content, a wording belongs to the UI. A view-side lookup table for all of it was rejected — it drifts from the catalog the first time a card moves | `core/data/policy_nodes.gd`; `core/battle.gd` `TYPES` + `type_name`; `view/main.gd` `OUTCOME_NAMES` |
| 三個型別禁用撤軍 was enforced "by the caller/UI" (a comment in `retreat`), which means every future caller re-remembers three ids | `no_retreat` moves into `TYPES` as data and `Battle.can_retreat(battle)` answers the question. A UI that has to remember a rule will eventually forget it | `core/battle.gd`; `test/battle_test.gd` asserts the whole table |
| Where the operate phase's screen is, now that 營運 is a scene rather than a panel | **The city IS the operate screen**: no panel over it, the dock is the entire command surface. The phases that are not scenes (機會/結算/世界大戰/民主/結局) stay panels over the city, because the city is the world and they are moments in it | `view/main.gd` `_show_overlay(&"")` |
| Whether the dock stays live during a battle or a settlement | **Off-phase the panorama stays and the commands don't.** Leaving it live would offer 蓋樓 mid-fight. The player's fold state is remembered across phases, so re-entering operate restores the dock they left | `view/city_scene.gd` `set_commands_visible` |
| 世界大戰 in the view: the old panel rolled a summary, but W12.5 made it a played battle | The war **opens on the battle table like any other battle** and settles through `WorldWar.finish`; the summary panel became the post-battle screen, and the war issues its reward card through the same reveal. A war generation also skips the unrest roll — 整代覆寫 means the generation was the war | `view/main.gd` `_begin_generation` / `_finish_battle` |
| What the 獎勵卡 reveal shows, given 「太爛就放棄」 is supposed to be a decision | The **actual card**, illustration composited under the frame, plus the roll (grade prefix, 攻/血, 命中／閃避／攻速) and the acquisition price. A text line was what W5 had, and it makes the decision unreadable | `view/main.gd` `_refresh_reward`; `Chrome.card_widget` (shared with the opportunity card) |
| No 勳章 icon exists in the approved 75-icon set, and the HUD needs one for the banked stock | Interim: reuse `icon_attack`, and **record it as an art gap rather than pretend it fits** — a medal is not a sword. Filling it is one cell on a future icon pass, not a reason to hold the view wave | `view/hud.gd` STATS; `assets/pipeline/inventory.md` §UI icons |

**Three defects Part A could not have caught, all found by reading the captures** (which is the
point of the gate): the phase's primary action (結束營運相位) scrolled off the bottom of a full
build list; the HUD's danger row was accent-gold on a pale sky and barely legible over the city
plate; and the tooltip sized itself off an autowrapping Label with no width to wrap at, covering a
third of the screen. All three now have assertions, `end_phase_reachable()` being the sharpest —
it asks whether the button is *inside the dock's rect*, not whether it exists.
