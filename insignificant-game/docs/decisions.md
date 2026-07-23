# Design-gap decision log

Where the design is silent, the implementer decides conservatively and logs it here: one row
per gap, grouped by the wave that hit it. Never invent mechanics. All values are v1 baseline
knobs, calibration-eligible like everything else. Decisions with lasting architectural
consequences also get an ADR in the repo root's `docs/adr/`.

## Starting values (W1)

The corpus pins start population (12) but not start treasury, happiness, culture, or tech.
Driver decisions:

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
| 文化國 psyops-vs-player cadence | every ~8 generations (next battle opening hand −1) | data/rivals.gd |
| Civil-war defeat power hit ("power 受挫") | ×0.9 per loss | rivals.gd |
| Catch-up player-protection ceiling (floor 0.65 is pinned; ceiling isn't) | strongest rival ≤ player×1.5, adjustment bounded ±25% | rivals.gd |
| First contact | all rivals met at generation 1 (+5 influence) | rivals.gd |
| Battle hand system (design implies "opening hand" but pins nothing) | opening hand 4 (+1 military region, −1 enemy psyops), draw 1/round, reshuffle discard when empty | battle.gd |
| Auto-resolution targeting | focus fire in deploy order; siege/air demolish fortifications first; mobile bypasses to ranged row | battle.gd |
| Enemy reinforcements | enemies deploy their whole opening at battle start (design lists only 開場單位) | battle.gd |
| 為民主而流血 frequency ("unknown 低頻") | 15% of unknown battles while unlocked-but-refused and happiness<70 | map_nodes.gd |
| World war battle | automated common-table strength contest (±15% seeded roll); camps/turn-order/merit/last-hit/reparations math faithful; per-card play not simulated | world_war.gd |
| Legacy passive magnitudes ("小幅永久＋") | +1/+2 per-generation values per legacy (table in legacy.gd) | legacy.gd |
| Democracy candidate money deltas | ×時代係數 at apply time (flat ±3 would be noise at gen 40) | democracy.gd |
| Democracy auto-explore value | 15×係數 per node (tax-battle-equivalent) | democracy.gd |
| Negative treasury at democracy entry | not reduced (only positive treasury takes the ×0.4 cut) | democracy.gd |
| Collapse epilogue text | driver addition (corpus has only the 7 victory texts) | data/epilogues.gd |
| Difficulty formula | 3-channel signed-level model; full rationale in docs/difficulty-design.md, synced to corpus | difficulty.gd |
| Window resolution | standing decision: Full HD 1920×1080 for both the PoC window and the shipped game (core is resolution-blind). History: PoC opened at 1280×720 for placeholder-UI density; the 2026-07-09 Moebius style pick retired the 640×360 pixel-art plan and set 1920×1080 | project.godot |

> The 「Battle hand system」 and 「文化國 psyops cadence」 rows describe the code as built through
> W9; the battle-model rewrite (`docs/plan-battle-model-rewrite.md`, ADR-0001/0002) retires the
> hand and re-specifies 文化國. Update these rows when W12–W13 land.
