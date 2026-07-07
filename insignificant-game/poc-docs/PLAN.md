# PoC build plan & task board (durable recovery state)

> **If you are resuming after an interruption:** this file + git log is the truth. Find the first
> unchecked gate below, verify the previous gate actually holds (run Part A; run Part B if past W5),
> and continue from there. Guideline: `doc/poc-implementation-gudielines.md` (repo root).
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
- [ ] **W5 — View layer (Part B).** `view/main.tscn` phase UI blocks (operate / route / node /
      battle / settle / WW / democracy), click-driven, placeholder visuals only; `tools/capture.gd`
      with ASSERT PASS/FAIL + PNG to `captures/`. Gate: capture PNG shows each phase block, no
      ASSERT FAIL, no runtime errors.
- [ ] **W6 — Balance instrumentation + wrap.** Telemetry summary from sim runs (BP curve, escalating
      cost 0.25, unrest weights — the three sensitive knobs); decision docs complete in `poc-docs/`;
      final report to PM.

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
| battle (+data) | ✓ | ✓ | hand system (open 4 / draw 1) is a driver decision |
| world_war | ✓ | ✓ | automated resolution (simplification) |
| democracy (+data) | ✓ | ✓ | money deltas ×coeff; auto-explore 15×coeff/node |
| legacy | ✓ | ✓ | passive magnitudes are driver v1 values |
| ending (+data) | ✓ | ✓ | collapse epilogue text is a driver addition |
| difficulty | ✓ | ✓ | |
| turn | ✓ | ✓ | |
| sim | ✓ | ✓ | |
| view/main + capture | — | — | Part B |

## Standing rules

- Both loop parts before "done" (headless green ≠ done; W5 gate is mandatory).
- Static typing; pure core; view computes nothing.
- Commit after each green gate; stage specific paths (`doc/prompts.md` churns every turn).
- Balance/fun questions → surface to PM, don't decide (numbers in design/ are v1 baselines;
  the sim exists to *measure* them, recommendations go in the W6 report).
