# Decisions: W3–W5 gaps the design leaves open

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
| Difficulty formula | 3-channel signed-level model; full rationale in doc/difficulty-design.md, synced to corpus | difficulty.gd |
| PoC window 1280×720 | text-heavy placeholder UI needs the density; shipped-game resolution was reopened by the 2026-07-09 Moebius style pick (was 640×360 pixel art) and decided the same day: Full HD 1920×1080 (core is resolution-blind) | project.godot |
