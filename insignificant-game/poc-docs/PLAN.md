# PoC build plan & task board (durable recovery state)

> **If you are resuming after an interruption:** this file + git log is the truth. Find the first
> unchecked gate below, verify the previous gate actually holds (run Part A; run Part B if past W5),
> and continue from there. Guideline: `doc/poc-implementation-guidelines.md` Part 1 (repo root).
> Contract: `poc-docs/architecture.md`. Design: `design/` (snapshot; Obsidian corpus is upstream).

## Method

Implementation waves. Within a wave, parallel agents each own disjoint files (module + data + test,
see architecture.md module map) and **write code + tests without running them** (parallel gdUnit4
runs race on `.godot/`). After each wave the driver runs the import warm-up + full suite, spawns
fixers if red, and only checks the wave off when **exit 0 with all suites executed**. Commit after
every green wave.

## Waves

- [x] **W0 — Scaffold.** Nested project + gdUnit4 + `.gdignore` isolation + design snapshot +
      architecture contract + this board. Gate: smoke test 2/2, exit 0. *(done 2026-07-07)*
- [x] **W1 — Foundations (driver-authored, inline).** `rng.gd`, `era.gd`, `game_state.gd` + tests.
      Gate: Part A green. These three ARE the contract; driver writes them, not agents.
      *(done 2026-07-07: 20/20, exit 0; starting values decided in decision-starting-values.md)*
- [x] **W2 — Inner systems (workflow, 6 agents; economy owns happiness too).** `economy.gd` +
      `happiness.gd`, `operations.gd` (+ `data/buildings.gd`), `policy.gd` (+ `data/policy_nodes.gd`),
      `unrest.gd`, `cards.gd` (+ `data/cards.gd`), `map_nodes.gd` (+ `data/opportunities.gd`).
      Gate: Part A green. *(done 2026-07-08: 99/99, 11 suites, exit 0. First workflow attempt
      died on usage limits; data tables salvaged from it, logic+tests finished inline by the
      driver one module at a time. Gap decisions: decision-w2-gaps.md.)*
- [x] **W3 — Outer systems.** `rivals.gd` (+ `data/rivals.gd`), `battle.gd` (enemy specs inline),
      `world_war.gd`, `democracy.gd` (+ `data/candidates.gd`), `legacy.gd`,
      `ending.gd` (+ `data/epilogues.gd`). Gate: Part A green. *(done 2026-07-08 inline by the
      driver: 165/165, 17 suites, exit 0. WW resolved as automated common-table strength contest
      — faithful camps/merit/reparations math, no per-card play [documented simplification].
      slow_burner g_late calibrated 1.24: design's stated 1.11 can't reach its own 230@35 target.)*
- [x] **W4 — Difficulty + orchestrator + simulation.** `difficulty.gd`, `turn.gd`, `sim.gd`;
      full-run seeded simulation tests; `doc/difficulty-design.md`; formula synced into the
      Obsidian corpus (對手文明 + pointers in 戰鬥/地圖與機會; snapshot refreshed; also fixed
      slow_burner g_late 1.11→1.24 there — value calibration to its own 230@35 target).
      Gate: Part A green incl. sim suite. *(done 2026-07-08: 181/181, 20 suites, exit 0)*
- [x] **W5 — View layer (Part B).** `view/main.tscn` + `view/main.gd` (UI built programmatically;
      demo mode INSIG_DEMO=1 simulates clicks, captures per-phase PNGs, prints ASSERTs).
      Gate: all 8 phase captures written, 0 ASSERT FAIL, exit 0, taxonomy review clean.
      *(done 2026-07-08. Part B caught a real defect — stale phase titles on WW/ending — fixed.)*
- [x] **W6 — Balance instrumentation + wrap.** `tools/balance_batch.gd` (60 seeded runs ×3
      difficulties) -> `poc-docs/balance-report.md` (three knobs measured; surfaced: no late-game
      money sink, happiness pegs at 100, rival churn high, zero collapses in 60 runs);
      `decision-w3-w5-gaps.md` completes the decision log. *(done 2026-07-08; final Part A
      181/181 exit 0.)*
- [x] **W7 — Approved-art integration (art pipeline Phase 4, handoff Prompt 4).**
      `core/data/asset_paths.gd` (+ `test/asset_paths_test.gd`): registry mapping approved asset
      ids -> res:// paths + frozen-template geometry (style bible §9). `assets/fonts/`: Noto Sans
      TC subsets (OFL verified, README documents the rebuild). `view/main.gd`: runtime-composed
      chrome (panel/button styleboxes, 3-slice divider, glyph-on-plate route badges, card-frame
      opportunity widget, icon stat/danger bars via RichTextLabel img tags); window 1920×1080
      (style bible §8). Gate: Part A 188/188 (21 suites, exit 0) + Part B 0 ASSERT FAIL,
      captures reviewed. *(done 2026-07-13. Part B caught a real defect again — panel body text
      unreadable on parchment chrome — fixed with ink-color overrides before the gate.)*
- [x] **W8 — Buildings class wire-in (art pipeline Phase 4 re-run, buildings approved 76/76).**
      `view/main.gd`: operate-panel city strip — 政權核心 at the current era plus each built
      line's own tier era-form sprite, textures resolved by `AssetPaths.building(line, tier)`
      and swapped by id (scale in-engine only); `test/asset_paths_test.gd` now sweeps every
      line's `min_tier..6` range plus core. Gate: Part A 188/188 (21 suites, exit 0) + Part B
      0 ASSERT FAIL incl. new `operate_city` capture, captures reviewed. *(done 2026-07-14)*
- [ ] **W9 — Battle rule delta: 鎮壓的手段有代價.** `core/battle.gd` + `core/happiness.gd` + tests:
      an 內亂型 battle in which any 機械型部隊卡 was played ends with 幸福 −15, win or lose, once
      per battle (design source: 戰鬥.md / 內亂與失敗.md / 幸福.md). Gate: Part A green.
- [ ] **W10 — Three-scene view revamp (style bible §11 + corpus 場景呈現).** Operations city
      panorama (collapsible bottom-right dock, icon+value HUD with focus tooltips, controller
      focus navigation), route fog-map scene, per-battle-type battle scene. Needs the backgrounds
      class plates (`bg_route_map`, `bg_battle_*`, `bg_city_era*` per inventory.md) approved
      first; interface behavior iterates in-engine on Part B captures (no more interface mocks).

## Module status (agents/driver: flip these as suites go green)

| Module | Written | Tests green | Notes |
|---|---|---|---|
| rng | ✓ | ✓ | |
| era | ✓ | ✓ | |
| game_state | ✓ | ✓ | schema may gain fields via module reports |
| economy | ✓ | ✓ | |
| operations | ✓ | ✓ | |
| policy (+data) | ✓ | ✓ | per-node progress banking (換節點保留進度) |
| happiness | ✓ | ✓ | |
| unrest | ✓ | ✓ | |
| cards (+data) | ✓ | ✓ | |
| map_nodes (+data) | ✓ | ✓ | |
| rivals (+data) | ✓ | ✓ | power-scalar mappings are driver decisions (data/rivals.gd) |
| battle (+data) | ✓ | ✓ | hand system (open 4 / draw 1) is a driver decision; OPEN: W9 riot suppression cost |
| world_war | ✓ | ✓ | automated resolution (simplification) |
| democracy (+data) | ✓ | ✓ | money deltas ×coeff; auto-explore 15×coeff/node |
| legacy | ✓ | ✓ | passive magnitudes are driver v1 values |
| ending (+data) | ✓ | ✓ | collapse epilogue text is a driver addition |
| difficulty | ✓ | ✓ | |
| turn | ✓ | ✓ | |
| sim | ✓ | ✓ | |
| view/main + capture | ✓ | ✓ | demo mode = embedded capture script (Part B) |

## Standing rules

- Both loop parts before "done" (headless green ≠ done; W5 gate is mandatory).
- Static typing; pure core; view computes nothing.
- Commit after each green gate; stage specific paths (`doc/prompts.md` churns every turn).
- Balance/fun questions → surface to PM, don't decide (numbers in design/ are v1 baselines;
  the sim exists to *measure* them, recommendations go in the W6 report).
