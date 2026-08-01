# Build plan & task board (durable recovery state)

> **If you are resuming after an interruption:** this file + git log is the truth. Find the
> first unchecked task below, verify the previous gate actually holds (run Part A; run Part B if
> the view is involved), and continue from there. Contract: `docs/architecture.md`.
> Dev loop: `docs/dev-loop.md`. Design: `design/` (single source of truth).
> Code conventions + deviations of the W11+ rewrite: `docs/implementation-notes.md`.

## Method

Implementation waves. Within a wave, parallel agents each own disjoint files (module + data + test,
see architecture.md module map) and **write code + tests without running them** (parallel gdUnit4
runs race on `.godot/`). After each wave the driver runs the import warm-up + full suite, spawns
fixers if red, and only checks the wave off when **exit 0 with all suites executed**. Commit after
every green wave.

## Production board

> **Read `docs/plan-battle-model-rewrite.md` before starting W10–W15.** It holds the locked design
> (D1–D16), the blast radius, and the wave sequence; the vocabulary and the retired terms live in
> `docs/architecture.md` §Glossary, the repo's only glossary. The battle model is being
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
- [x] **W11 — Card model.** `cards.gd` instances (innate accuracy/dodge/speed rolled at
      acquisition), `data/cards.gd` distributions, `game_state.gd` deck of instances. 攻/血 stay
      fixed per type+era. Gate: Part A green on `cards_test`; rolls deterministic under a seed.
      *(done 2026-07-24: cards_test 29/29 green, same-seed double-run determinism asserted.
      Scope grew to a full catalog sync — the W10+wayfinder corpus changed more than the
      rewrite plan's blast radius predicted: 16 cards (壕溝 retired, engineers become the
      fortification repairer), era-name fixes, 聖戰士團/私掠傭兵團 top-end form cutoffs with
      free auto-disband, unified paid 解散 (free removal is gone), reward roll/accept API
      (`add_reward_card` kept as a deprecated shim for sim/view until W14/W15). battle_test
      red on retired trench mechanics as planned — W12 rewrites that suite. Conventions +
      deviations: `docs/implementation-notes.md`.)*
- [x] **W12 — Battle model.** Wave schedule roll, tick loop, event timeline emission, exhaustion
      win check, survivor persistence. Delete the hand (`OPENING_HAND`, draw/discard piles,
      `play_card(hand_index)`) and the simultaneous resolver. Gate: Part A green on `battle_test`;
      timeline deterministic and replayable from a seed.
      *(done 2026-07-24: battle_test 22 cases green incl. same-seed identical-timeline assert;
      full suite back to exit 0 — 21/21 suites, 208/208 cases — two waves ahead of the W14
      expectation. Waves rolled per battle on `battle` track; per-unit speed accumulators;
      文明戰爭 fields 正規軍 (greedy composition, psyops attack discount); engineers repair
      forts; deaths wipe growth (D11); reward instance issued from `finish` every fought
      battle. `sim.gd::_fight` got a minimal compile-fix policy (W14 owns the real bot);
      `view/main.gd` is parse-broken against the dead hand API until W15 — Part B is DOWN
      W12–W14 by plan. Gap decisions + engine conventions: decisions.md W12 +
      implementation-notes.md.)*
- [x] **W13 — Growth.** Per-stat XP, 勳章 from both sources (battle-automatic, 兵營-assigned),
      軍事區 老兵 veterancy, 文化國 accuracy debuff. Rewires `operations.gd` + `rivals.gd`.
      Gate: Part A green on `cards_test`, `operations_test`, `rivals_test`.
      *(done 2026-07-25: full suite exit 0 — 21/21 suites, 223/223 cases (15 new across
      cards/operations/rivals/battle/turn). XP hooks live in the tick engine (accuracy per
      attack, dodge per dodge/survived hit, speed per survived round; `&"medal"` events at
      the filling tick, effect 自下一回合 via the boundary re-snapshot); 兵營 produces 1
      勳章/gen into `state.medals`, assigned by lane (民主後 auto-assign, WW gens skip);
      老兵 +1 lane level in the `*_of` accessors; 文化國 D16 = −10 accuracy next battle.
      `opening_hand_bonus`/`opening_slots_bonus` deleted. Gap decisions: decisions.md W13;
      conventions: implementation-notes.md.)*
- [x] **W13.5 — Starting-state sync (new task, raised in W11).** The corpus (wayfinder #12)
      now pins 起始人口 0 (營運.md) with the 政權崩潰 check arming only after 人口 first
      reaches 5 (內亂與失敗.md); code still starts at 12 with an always-armed check.
      `game_state.gd` defaults, `unrest.gd` arming flag, decisions.md W1 table update; the sim
      auto-player must learn the 解散-for-population opening or W14 runs starve. Gate: Part A
      green on `unrest_test` + defaults asserted; full-suite green folds into W14's gate.
      *(done 2026-07-25: population starts 0, `collapse_armed` field arms lazily inside
      `Unrest.regime_collapsed` at first 人口 ≥ 5 (sampled at the settle cadence); sim bot
      got `_grow_population` — disband personnel deck-order-first while pop < 20 and the
      deck exceeds the minimum. Six tests that leaned on the old default now set pop 12
      explicitly. Full suite exit 0, 21/21, 223/223 — the W14 fold-in gate is already met.)*
- [x] **W12.5 — World war on the battle engine (new task, raised in W12; plan WW1–WW5).**
      `world_war.gd` still auto-resolves by the PoC power-sum contest. Rebuild it as the 7th
      playable battle type on the W12 engine: two camps, no neutral, per-camp exhaustion,
      卡池張數-sequenced interleaved waves of 正規軍, per-civ faction tags feeding real-clear
      戰功, reparations math unchanged. Must land before W14 (it reshapes balance).
      Gate: Part A green on rewritten `world_war_test` + `battle_test`.
      *(done 2026-07-25: full suite exit 0 — 21/21 suites, 222/222 cases. world_war.gd is
      now composer + settlement (WorldWar.start → deploy/end_round loop → WorldWar.finish);
      the power-sum roll and player_neutral are gone. Engine grew the side/faction split
      (side = camp array, faction = 戰功 tag), prepared two-camp wave schedules, per-side
      pending-wave exhaustion, uncapped rounds (cap 0), and real-clear merit bookkeeping;
      reparations keep the PoC math with exact pool conservation. Sim fights both world
      wars for real (concede guard added for uncapped termination). Gap decisions:
      decisions.md W12.5; conventions: implementation-notes.md.)*
- [x] **W14 — Sim + balance.** `sim.gd::_fight()` rewrite (must auto-resolve headless), full suite
      back to exit 0, balance batch recalibrated. Gate: Part A exit 0 all suites executed;
      `test_determinism_same_seed_same_run` green; findings surfaced to PM in
      `docs/balance-report.md` (measure, don't tune to taste).
      *(done 2026-07-25: tempo bot — strength-parity fielding, personnel-first riots,
      medal routing to the strongest unit, disband-for-population opening, concede guard;
      batch re-run 60 runs and balance-report.md rewritten. Full suite exit 0, 21/21,
      222/222 with determinism green. Headline measurements: player camp wins ~95% of
      world wars (WW2-wall knobs don't bite yet), happiness finally moves (min 16 on
      normal), 0 collapses with every run arming the check, money pile unchanged ~9200.)*
- [x] **W14.5 — Air & fortification rules delta (2026-07-26 design round; ADR-0006/0007,
      wayfinder #18–#22).** battle.gd: targeting matrix (melee excludes 空域, 空襲
      ground-only), 防空 active air fire (era 4+, **destroy-on-hit: no attack value, the
      target dies; engine defaults, target 閃避 still rolls**; era 1–3 forms retired in
      `data/cards.gd`), fort disable-repair state machine (one hit disables, never removed,
      engineer round-robin repair regardless of arrival time, ground-only interception,
      siege/air prefer active forts), 僅剩空軍 continuation + 世界大戰 deadlock resolution,
      `sim.gd` termination guard. Corpus already updated (design-first); code must follow it.
      Gate: Part A exit 0 on battle/cards/sim/world_war suites; determinism green.
      *(done 2026-07-26: full suite exit 0 — 21/21 suites, 234/234 cases (12 new in
      battle_test), determinism green. Targeting matrix + destroy-on-hit 防空 (fires at the
      window's first tick, engine defaults, 閃避 still rolls, era 1–3 forms retired) + fort
      disable/repair (never removed, round-robin, ground-only interception, siege/air prefer
      active forts) + symmetric 僅剩空軍 continuation + 世界大戰 僵局判定 (uncapped only) +
      sim round guard. Timeline events renamed: `absorb`/`demolish` → `intercept`/`disable`,
      new `shootdown`; forts carry `disabled` only — W15 renders these. Balance batch re-run:
      **hard-difficulty world wars fell 95%→79%** (bomber-heavy 正規軍 are now melee-proof) and
      the collapse chain fired for the first time (2/60, both an opening-game pop-5 trap, not
      an air effect) — both surfaced in balance-report.md for the PM. Gap decisions:
      decisions.md W14.5; conventions: implementation-notes.md.)*
- [x] **W14.6 — Corpus round: cover chain + top-down pivot (2026-07-27 design round;
      ADR-0008/0009).** Documentation only, no code. `design/戰鬥.md`: 自動佈陣 becomes an ordered
      cover chain (近戰列（最前）→ 工事線 → 遠程列 → 空域, each layer screening the one behind it),
      盾陣 rescoped from any 地面單位 to the **遠程列**, one card = one wall segment, 工兵團 moves to
      the 遠程列 and works at the 工事線, 正規軍 field 盾陣 (never 防空飛彈, never repairable) while
      非正規軍 field none, §場景呈現 becomes top-down with cover read by arrangement alone.
      `design/卡牌.md`: 工兵團's row + 盾陣's effect cell. ADR-0008 (cover chain, superseding
      ADR-0007's ground-unit scope) and ADR-0009 (top-down, carrying the audit's sprite-cost
      evidence). ADR-0006 amended by striking only the REFRAME clause; every rule in it survives.
      `architecture.md`: 掩護鏈 + station terms and the **full timeline event contract** (two
      replayers now depend on it). style-bible §3 camera split + §11 top-down; `inventory.md` marks
      69 unit sprites + 7 battle backdrops superseded pending W14.8. Gate:
      `python3 docs/tools/check_design_graph.py` exit 0. *(done 2026-07-27: exit 0, 14 system docs,
      62 feed edges, 57 `code:` mappings, 0 errors, 0 warnings. Part A not runnable (no code
      changed), Part B still down until W15. Gap decisions: decisions.md W14.6.)*
- [x] **W14.7 — Cover chain in core + demo becomes a timeline replayer (ADR-0008/0009).**
      `battle.gd`: the shield branch narrows to `target["row"] == &"ranged"`, 工兵團's row moves,
      正規軍 rosters gain screens in `_regular_roster_desc` (`battle.enemy_forts` is declared and
      read but never appended to today, so 帶攻城 is inert in every battle in the game), new
      `take_station` event, header cite. `core/data/cards.gd`: the flag `&"blocks_melee_once"`
      becomes `&"screens_ranged_row"`. `test/battle_test.gd`: rewrite the intercept test, add
      melee-at-melee-is-not-intercepted, melee-at-ranged-is, no-ranged-unit-no-interception,
      enemy-screen-never-repairs, `take_station`. New `tools/export_timeline.gd` (sibling of
      `balance_batch.gd`, which already dumps JSON via `FileAccess`) exporting one fixture per era.
      Demo converted from simulator to replayer: **all rule code deleted**, top-down render, station
      staging; `check_motion_demo.js` drops from 46 rule assertions to a renderer check, and fixture
      staleness is caught in Part A by re-running the exporter and failing on a diff. Add both
      checkers to `dev-loop.md` Part A. Note the balance batch **cannot** measure this change:
      `sim.gd` makes the bot skip every fort card and `balance-report.md` already records 盾陣 and
      防空飛彈 as having zero batch coverage. The enemy-screens change will still move civ-war and
      world-war numbers against the 79% hard-WW baseline and needs re-calibration.
      Gate: Part A exit 0 (21 suites, ~239 cases); exporter diff clean; renderer check exit 0.
      *(done 2026-07-28: full suite exit 0 — 21/21 suites, 240/240 cases (7 new in battle_test);
      exporter byte-stable across re-runs; renderer check exit 0; check_design_graph.py exit 0
      (14 docs, 62 edges, 58 `code:` mappings, 0/0). Part B still down until W15.
      **Two deviations from the plan, both deliberate:** (1) the 正規軍 screens landed in wave
      composition (`Battle.regular_screens` + `_arrive_waves`) rather than in the roster function,
      because a roster returns unit types and a wall arrives with the row it covers; the roster
      filter and `regular_unit` were made public for the exporter. (2) **Every timeline event
      gained a `side` key.** Labels are card ids, so both camps' 步兵團 answer to one label and the
      first replayer could not attribute a single strike to a camp — the pinned contract was not
      replayable as written. architecture.md is updated rather than worked around, and the
      remaining hole (two same-class units on ONE side still share a label) is stated there and in
      decisions.md as a blocker W15 must close before it replays a real 正規軍 roster. The
      fixtures dodge it by fielding one unit per class per side, which `check_motion_demo.js`
      enforces. Balance batch re-run: aggregate movement is inside stream-reshuffle noise (hard WW
      86% vs 79%, i.e. the opposite sign to the change — do not read it as a gain), the money pile
      fell ~10% on normal/hard, and a 政權崩潰 fired outside the opening trap for the first time
      (gen 13, hard) — surfaced in balance-report.md. Gap decisions: decisions.md W14.7.)*
- [ ] **W14.8 — Top-down battlefield art re-render (ADR-0009).** 69 unit/fort sprites + 7 battle
      backdrops through the Mac Studio orchestrator (root `docs/image-assets-generation-orchestrator-cookbook.md`),
      human pick gates. Gate: human pick-gate sign-off; `inventory.md` updated; superseded sprites removed.
      - [x] **Risks answered before spending GPU.** ADR-0009 handed W14.8 two open risks and the
            52 exploration raws (`assets/exploration/topdown-demo/`) answer both, with pictures:
            **mirroring holds** at battle zoom (vehicles are axis-symmetric; figures swap weapon hand,
            which is not a §8 defect; the one hull mark is a mirror-invariant disc), and **eye-level
            drift is confined to 5 cells** (`cavalry_e3/e4` mounted, `artillery_e4` wheeled carriage,
            `anti_air_e1/e2` timber structures), not to multi-figure groups as feared. The audit also
            found a defect class ADR-0009 did not name: **a heading stated only in the framing suffix
            is not obeyed** — bombers rendered nose-left, lone privateers faced the camera — and an
            X-flip cannot rescue it. Evidence and the camera-specific review rules:
            `assets/pipeline/review-brief-units-topdown.md`.
      - [x] **Pipeline authored.** `phase3_units_topdown_batch.py` (70 cells: the 69 ids plus
            `unit_infantry_era4`, the side-view known gap the top-down wording closes; player cores
            lifted from the exploration's validated wording, 18 enemy-tier cores newly authored
            left-facing, 5 cores carrying the heading fix), `phase3_units_topdown_sweep.py`,
            `phase3_backgrounds_topdown_batch.py` (the 7 plates rewritten as ground planes — a
            top-down plate has no sky or horizon, so this is a subject rewrite, not a suffix swap),
            `phase3_units_topdown_sheets.py` (pick-gate sheets carrying a battle-zoom inset per cell).
      - [x] **Deviation from the buildings/units precedent, logged here because it reverses it:**
            **no era gates and no img2img lineage — every cell is a txt2img root.** Cookbook §6.1's
            own table calls for a root when a transition is a category reversal or shares no
            silhouette with the target, and under the new camera every cell qualifies twice (no cell
            has a top-down parent, and three lines change subject category at era 5). The exploration
            generated all 52 player cells this way and its set held together. The cost: era-to-era
            continuity inside a line is now carried by wording alone, so the pick gate must be read
            **down each line's row**, not only across it. The gain: one unattended batch and one
            complete pick gate instead of six sequential human-gated waves.
      - [x] **Round 1 rendered and gated.** 280 unit candidates + 28 plates, zero render failures.
            Human picked 58 of 67 unit cells; `fort_anti_air_era1..3` were ruled non-assets (ADR-0006
            already retires those forms, so the art inventory was the stale artifact) and dropped,
            taking the roster 70 → 67. Picks live in `phase3_units_topdown_picks.json`.
      - [x] **Re-roll rounds and the pick gate — CLOSED** (detached, resumable; logs
            `~/imagegen/logs/w148_*.log`; every round's cells and seeds are recorded in the three
            pick files). **All 82 assets are picked** — 67 unit cells, 7 plates, 8 projectiles — in
            `phase3_units_topdown_picks.json`, `phase3_backgrounds_topdown_picks.json` and
            `phase3_projectiles_topdown_picks.json` respectively; those three files are what the
            freeze scripts read, and `awaiting_seed_pick` is empty. The last cell to close was
            `shield_wall` e2, re-rolled twice for **axis** rather than subject or camera. Eight seeds
            proved a hard trade rather than a wording gap: **wide implies diagonal and on-axis
            implies narrow**, because a wide segment spanning a 1:1 frame's height needs more width
            than the frame has, so the only room for a wide wall is along the diagonal. That also
            reframes what the "good" wide render was — it was wide because it was tilted enough to
            show the shields' faces, and a shield rank seen from genuinely overhead IS a narrow band.
            Units took eight re-roll rounds,
            plates six, projectiles two. `shield_wall` e3 closed without the subject change it
            looked like it needed: the img2img child of e6 holds a self-contained segment, and the
            txt2img alternative was rejected for the same defect its bleed measurement was already
            reporting. The rules each round produced live in
            `review-brief-units-topdown.md` (discrete object with visible ends; mobile not emplaced;
            barriers judged on axis) and cookbook §14 (**register, not vocabulary**: a wide frame
            plus scene language reads as a landscape photograph, so the model supplies a viewer to
            recede from — the fix that finally made the ground plane flat and the wall segments
            straight was asking for a repeating pattern of identical units).
      - [x] **Freeze the approved set — DONE.** `phase3_units_topdown_freeze.py` (67 sprites, key +
            crop, `shield_wall` e5 turned 90° onto its axis), `phase3_projectiles_topdown_freeze.py`
            (8, into the new `approved/projectiles/`) and `phase3_backgrounds_topdown_freeze.py`
            (7 plates, full-frame). `manifest.jsonl` gained 82 approved rows and its status
            vocabulary gained `superseded` / `retired` (decisions.md W14.8): 73 rows superseded,
            3 retired, and **zero approved rows point at a file that does not exist**.
            `asset_paths.gd` gained `PROJECTILE_DIR` / `PROJECTILES` / `projectile()`, and
            `UNIT_COVERAGE` lost `anti_air` 1-3 while gaining `infantry` era 4 — so no unit slot is
            placeholdered any more. Gate: 21 suites / 242 cases exit 0, check_design_graph.py exit 0.
            **The §8 pass caught what the pick gate structurally could not:** 60 of 67 cells enclosed
            background the border flood cannot reach (inside a bow, between a sling strap and the
            fist, between missiles on a rail), which is invisible on a light contact sheet and ships
            as a pale blob on a dark plate. Keying now also cuts background-coloured pixels at a
            much tighter tolerance than the flood's, which removes trapped plate while keeping
            shaded pale material. Deliberately NOT applied to the projectiles, where it gains
            nothing and punches a hole through `proj_bomb` — the reasoning and measurements are in
            both freeze scripts.
      - [ ] **Neutral field objects (new class; unblocked — all 7 plates are approved).**
            **This runs before W15, by human ruling, and the ordering is deliberate — don't
            re-propose overlapping it with the view wave.** The technical argument for overlapping
            is real and is exactly why it's answered here: scatter is decoration, the view places it
            at draw time, and the battle scene would work with an empty scatter set, so W15 does not
            strictly need it. It still goes first, so W14.8 closes as one wave. The plates
            are bare ground by ruling, so everything a player sees standing on the field is now an
            object. Add a scatter class of neutral props — rocks, craters, tree stumps, rubble,
            sandbag piles — **derived per battle type from its approved ground plate**
            (`phase3_backgrounds_topdown_picks.json`), so the wheat field and the crater field
            scatter differently: that file's material and palette are the brief, and a plate
            re-roll invalidates its scatter.
            **They are decoration and nothing else** (`design/戰鬥.md` §場景呈現, decisions.md W14.8):
            no blocking, no cover, no damage, no place in the 掩護鏈, and no rule may read them —
            工事線 stays the only cover model, or cover forks into two systems and the core acquires
            the spatial model ADR-0006/0009 keep refusing it. Placement is the **view's**, seeded
            from the battle's own seed and avoiding the stations, so a replay is identical every
            time while the core still holds no coordinates. Scope the ids into `inventory.md` at the
            same time; the seed's route to a fixture-driven replayer is a timeline-contract question
            for W15, not an engine change here.
            *Gate:* human pick-gate sign-off on the scatter set; `inventory.md` updated.
- [ ] **W15 — Three-scene view revamp, top-down battle (style bible §11 + corpus 場景呈現; was W10).**
      Operations city panorama (collapsible bottom-right dock, icon+value HUD with focus tooltips,
      controller focus navigation) now also carrying 勳章 assignment + 解散 roll evaluation, route
      fog-map scene, and a **top-down** per-battle-type battle scene replaying the core's tick
      timeline, prototyped by W14.7's replayer. The city stays a side-view panorama by design.
      Non-battle background plates are already approved (`9b45ed8`); the battle plates come from
      W14.8. **盾陣 sprites all ship top-to-bottom, so the view needs no per-asset rotation** — it
      draws a barrier like any other sprite. Getting there is W14.8's job, not W15's: e5 is rotated
      90° by the freeze script and e2 is re-rolled onto the axis (measured angles and the reasoning
      in `assets/pipeline/phase3_units_topdown_picks.json` §`barrier_render_axis`; the ruling in
      decisions.md W14.8). What W15 must not do is assume a barrier's axis can be fixed at draw
      time: the axis is an outcome of the render, because naming it in the prompt is what tapered
      three rounds of walls.
      Interface behavior iterates in-engine on Part B captures (no more interface mocks).
      **Part B returns here** (`view/main.gd` is parse-broken until this wave).
      Gate: Part B captures reviewed, zero ASSERT FAIL.

## Closed: PoC waves W0–W9 (record; all gates passed)

The full-game PoC closed with W9: 19 core modules + 7 data tables + view/capture all green,
192/192 cases over 21 suites, exit 0. The codebase continued into production without a rewrite.
Per-module status lives in the suite names (one suite per module); the old module table is
retired.

- [x] **W0 — Scaffold.** Nested project + gdUnit4 + `.gdignore` isolation + design snapshot +
      architecture contract + this board. Gate: smoke test 2/2, exit 0. *(done 2026-07-07)*
- [x] **W1 — Foundations (driver-authored, inline).** `rng.gd`, `era.gd`, `game_state.gd` + tests.
      Gate: Part A green. These three ARE the contract; driver writes them, not agents.
      *(done 2026-07-07: 20/20, exit 0; starting values decided in docs/decisions.md, Starting values)*
- [x] **W2 — Inner systems (workflow, 6 agents; economy owns happiness too).** `economy.gd` +
      `happiness.gd`, `operations.gd` (+ `data/buildings.gd`), `policy.gd` (+ `data/policy_nodes.gd`),
      `unrest.gd`, `cards.gd` (+ `data/cards.gd`), `map_nodes.gd` (+ `data/opportunities.gd`).
      Gate: Part A green. *(done 2026-07-08: 99/99, 11 suites, exit 0. Gap decisions:
      docs/decisions.md, W2 gaps.)*
- [x] **W3 — Outer systems.** `rivals.gd` (+ `data/rivals.gd`), `battle.gd` (enemy specs inline),
      `world_war.gd`, `democracy.gd` (+ `data/candidates.gd`), `legacy.gd`,
      `ending.gd` (+ `data/epilogues.gd`). Gate: Part A green. *(done 2026-07-08 inline by the
      driver: 165/165, 17 suites, exit 0. WW resolved as automated common-table strength contest
      — faithful camps/merit/reparations math, no per-card play [documented simplification].
      slow_burner g_late calibrated 1.24: design's stated 1.11 can't reach its own 230@35 target.)*
- [x] **W4 — Difficulty + orchestrator + simulation.** `difficulty.gd`, `turn.gd`, `sim.gd`;
      full-run seeded simulation tests; `docs/difficulty-design.md`; formula synced into
      `design/` (對手文明 + pointers in 戰鬥/地圖與機會; also fixed slow_burner g_late 1.11→1.24
      there — value calibration to its own 230@35 target).
      Gate: Part A green incl. sim suite. *(done 2026-07-08: 181/181, 20 suites, exit 0)*
- [x] **W5 — View layer (Part B).** `view/main.tscn` + `view/main.gd` (UI built programmatically;
      demo mode INSIG_DEMO=1 simulates clicks, captures per-phase PNGs, prints ASSERTs).
      Gate: all 8 phase captures written, 0 ASSERT FAIL, exit 0, taxonomy review clean.
      *(done 2026-07-08. Part B caught a real defect — stale phase titles on WW/ending — fixed.)*
- [x] **W6 — Balance instrumentation + wrap.** `tools/balance_batch.gd` (60 seeded runs ×3
      difficulties) -> `docs/balance-report.md` (three knobs measured; surfaced: no late-game
      money sink, happiness pegs at 100, rival churn high, zero collapses in 60 runs);
      the W3–W5 section of `docs/decisions.md` completes the decision log. *(done 2026-07-08; final Part A
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
- Commit after each green gate; stage specific paths (`docs/prompts.md` churns every turn).
- Balance/fun questions → surface to PM, don't decide (numbers in design/ are v1 baselines;
  the sim exists to *measure* them, recommendations go in `docs/balance-report.md`).
