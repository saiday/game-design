# Build plan & task board (durable recovery state)

> **If you are resuming after an interruption:** this file + git log is the truth. Find the
> first unchecked task below, verify the previous gate actually holds (run Part A; run Part B if
> the view is involved), and continue from there. Contract: `doc/architecture.md`.
> Dev loop: `doc/dev-loop.md`. Design: `design/` (single source of truth).

## Method

Implementation waves. Within a wave, parallel agents each own disjoint files (module + data + test,
see architecture.md module map) and **write code + tests without running them** (parallel gdUnit4
runs race on `.godot/`). After each wave the driver runs the import warm-up + full suite, spawns
fixers if red, and only checks the wave off when **exit 0 with all suites executed**. Commit after
every green wave.

## Production board

> **Read `doc/plan-battle-model-rewrite.md` before starting W10–W15.** It holds the locked design
> (D1–D16), the glossary, the retired-terms list, and the blast radius. The battle model is being
> replaced: no hand, enemy waves, tick timelines, cards as rolled instances that grow. Do not
> reopen those decisions while executing; surface a design question instead.

- [x] **W10 — Corpus rewrite (design truth first; no code).** `卡牌.md`, `戰鬥.md`, `營運.md`,
      `對手文明.md` in `design/`, then fix `code:` frontmatter both directions. Gate: human reads
      and accepts the four docs; 手牌 / 部隊位 /
      同時結算 appear **only as explicit negations** (「沒有手牌、沒有抽牌」), never as live rules.
      **Corpus before code is not negotiable** — every mechanic this rewrite removes was built by
      an agent resolving a doc contradiction alone. *(done 2026-07-17: four docs rewritten,
      `design/` snapshot re-copied byte-identical, human accepted. `code:` frontmatter unchanged —
      no modules moved yet; W11–W14 own the reverse direction. Carries 3 open items into W11:
      ~30 agent-authored v1 baselines, 老兵 / 兵營 勳章 don't name which stat they raise, no
      adversarial validation pass.)*
- [ ] **W11 — Card model.** `cards.gd` instances (innate accuracy/dodge/speed rolled at
      acquisition), `data/cards.gd` distributions, `game_state.gd` deck of instances. 攻/血 stay
      fixed per type+era. Gate: Part A green on `cards_test`; rolls deterministic under a seed.
- [ ] **W12 — Battle model.** Wave schedule roll, tick loop, event timeline emission, exhaustion
      win check, survivor persistence. Delete the hand (`OPENING_HAND`, draw/discard piles,
      `play_card(hand_index)`) and the simultaneous resolver. Gate: Part A green on `battle_test`;
      timeline deterministic and replayable from a seed.
- [ ] **W13 — Growth.** Per-stat XP, 勳章 from both sources (battle-automatic, 兵營-assigned),
      軍事區 老兵 veterancy, 文化國 accuracy debuff. Rewires `operations.gd` + `rivals.gd`.
      Gate: Part A green on `cards_test`, `operations_test`, `rivals_test`.
- [ ] **W14 — Sim + balance.** `sim.gd::_fight()` rewrite (must auto-resolve headless), full suite
      back to exit 0, balance batch recalibrated. Gate: Part A exit 0 all suites executed;
      `test_determinism_same_seed_same_run` green; findings surfaced to PM in
      `doc/balance-report.md` (measure, don't tune to taste).
- [ ] **W15 — Three-scene view revamp (style bible §11 + corpus 場景呈現; was W10).** Operations
      city panorama (collapsible bottom-right dock, icon+value HUD with focus tooltips, controller
      focus navigation) now also carrying 勳章 assignment + 解散 roll evaluation, route fog-map
      scene, per-battle-type battle scene replaying the core's tick timeline. Backgrounds class
      plates are already approved (`9b45ed8`); the blocker is W11–W14, not art. Interface behavior
      iterates in-engine on Part B captures (no more interface mocks).

## Closed: PoC waves W0–W9 (record; all gates passed)

The full-game PoC closed with W9: 19 core modules + 7 data tables + view/capture all green,
192/192 cases over 21 suites, exit 0. The codebase continued into production without a rewrite.
Per-module status lives in the suite names (one suite per module); the old module table is
retired.

- [x] **W0 — Scaffold.** Nested project + gdUnit4 + `.gdignore` isolation + design snapshot +
      architecture contract + this board. Gate: smoke test 2/2, exit 0. *(done 2026-07-07)*
- [x] **W1 — Foundations (driver-authored, inline).** `rng.gd`, `era.gd`, `game_state.gd` + tests.
      Gate: Part A green. These three ARE the contract; driver writes them, not agents.
      *(done 2026-07-07: 20/20, exit 0; starting values decided in decision-starting-values.md)*
- [x] **W2 — Inner systems (workflow, 6 agents; economy owns happiness too).** `economy.gd` +
      `happiness.gd`, `operations.gd` (+ `data/buildings.gd`), `policy.gd` (+ `data/policy_nodes.gd`),
      `unrest.gd`, `cards.gd` (+ `data/cards.gd`), `map_nodes.gd` (+ `data/opportunities.gd`).
      Gate: Part A green. *(done 2026-07-08: 99/99, 11 suites, exit 0. Gap decisions:
      decision-w2-gaps.md.)*
- [x] **W3 — Outer systems.** `rivals.gd` (+ `data/rivals.gd`), `battle.gd` (enemy specs inline),
      `world_war.gd`, `democracy.gd` (+ `data/candidates.gd`), `legacy.gd`,
      `ending.gd` (+ `data/epilogues.gd`). Gate: Part A green. *(done 2026-07-08 inline by the
      driver: 165/165, 17 suites, exit 0. WW resolved as automated common-table strength contest
      — faithful camps/merit/reparations math, no per-card play [documented simplification].
      slow_burner g_late calibrated 1.24: design's stated 1.11 can't reach its own 230@35 target.)*
- [x] **W4 — Difficulty + orchestrator + simulation.** `difficulty.gd`, `turn.gd`, `sim.gd`;
      full-run seeded simulation tests; `doc/difficulty-design.md`; formula synced into
      `design/` (對手文明 + pointers in 戰鬥/地圖與機會; also fixed slow_burner g_late 1.11→1.24
      there — value calibration to its own 230@35 target).
      Gate: Part A green incl. sim suite. *(done 2026-07-08: 181/181, 20 suites, exit 0)*
- [x] **W5 — View layer (Part B).** `view/main.tscn` + `view/main.gd` (UI built programmatically;
      demo mode INSIG_DEMO=1 simulates clicks, captures per-phase PNGs, prints ASSERTs).
      Gate: all 8 phase captures written, 0 ASSERT FAIL, exit 0, taxonomy review clean.
      *(done 2026-07-08. Part B caught a real defect — stale phase titles on WW/ending — fixed.)*
- [x] **W6 — Balance instrumentation + wrap.** `tools/balance_batch.gd` (60 seeded runs ×3
      difficulties) -> `doc/balance-report.md` (three knobs measured; surfaced: no late-game
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
- [x] **W9 — Battle rule delta: 鎮壓的手段有代價.** `core/battle.gd` + `core/happiness.gd` + tests:
      an 內亂型 battle in which any 機械型部隊卡 was played ends with 幸福 −15, win or lose, once
      per battle (design source: 戰鬥.md / 內亂與失敗.md / 幸福.md). Gate: Part A green.
      *(done 2026-07-15: 192/192, 21 suites, exit 0)*

## Standing rules

- Both loop parts before "done" (headless green ≠ done; the Part B gate discipline from W5
  onward is mandatory for anything the view touches).
- Static typing; pure core; view computes nothing.
- Commit after each green gate; stage specific paths (`doc/prompts.md` churns every turn).
- Balance/fun questions → surface to PM, don't decide (numbers in design/ are v1 baselines;
  the sim exists to *measure* them, recommendations go in `doc/balance-report.md`).
