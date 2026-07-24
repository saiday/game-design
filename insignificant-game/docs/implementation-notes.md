# Implementation notes (battle-model rewrite, W11+)

> **What this is:** the working notebook of the W11–W15 implementation frontier. It records
> the *code-level* conventions each wave establishes (so later waves and future agents inherit
> them instead of re-deciding), and a Deviations log for edge cases that forced a conservative
> call mid-wave. It is a purpose-built log (same class as `PLAN.md` / `decisions.md`): entries
> are append-mostly and may carry dates. Design gaps still go to `docs/decisions.md`; anything
> architectural still gets an ADR. This file is for the layer between: how the code is being
> shaped while the waves land.

## Conventions established (binding on later waves unless contradicted out loud)

### W11 — card model

- **RNG track `&"cards"`** owns the whole card-acquisition domain: quality-grade draw, the
  innate-three draws, and the post-battle reward-card pick. One track so acquisition history
  is a single reproducible stream; battle keeps `&"battle"` for wave rolls.
- **Draw order is part of the determinism contract:** per acquisition = 1 grade draw
  (single `randf` against cumulative `GRADE_ORDER` probabilities: bad → medium → good), then
  one uniform draw per present stat in fixed order **accuracy → dodge → speed**. Stats a card
  lacks (工兵團 has only dodge) consume **no** draw. Never reorder; it changes every seed.
- **Quality stats are floats** (accuracy/dodge as percent, speed as attacks-per-round).
  Rounding is a display concern; core never rounds.
- **`CardsData.QUALITY` holds Medium bands only.** Bad/Good bands are derived
  (`Cards.band_for`) by extending one band-width out and clamping (acc 0–100, dodge 0–50,
  speed ≥ 0.1). The band-width multiplier and grade probabilities are calibration knobs in
  `CardsData`.
- **Growth is `levels` (earned medal levels per stat) + `xp` (progress toward next medal)**
  on the instance. Effective stats = innate + levels × `GROWTH_STEP`, clamped
  (acc ≤ 100, dodge ≤ 50, speed uncapped). `wipe_growth()` clears both dictionaries and is
  the entire death penalty (D11); the innate roll and grade are never touched after
  acquisition (D10/D12). W13 adds 老兵 floor and 文化國 debuff **inside the `*_of`
  functions** — their `(state, instance)` signatures already reserve the state parameter.
- **Effective-stat accessors** are `Cards.accuracy_of/dodge_of/speed_of(state, instance)`;
  `attack_of/hp_of` stay state-free (fixed by type+era, D8). The view and battle must read
  through these, never raw fields.
- **`Cards.has_form(card_id, era_idx)`** (era_names non-empty; skills always true) is the
  authoritative "does this card exist this era" test — it covers both the early gate and the
  new top-end cutoffs (聖戰士團 工業-only, 私掠傭兵團 ends before 資訊). `min_era` in the data
  is now a **derived cache kept only because `battle.gd`'s pre-rewrite reward pick still reads
  it**; `cards_test` asserts it equals the first formed era. **W12: switch battle to
  `Cards.roll_reward`/`reward_pool` and delete `min_era` from card entries.**
- **Reward flow API:** `roll_reward(state) -> CardInstance` (pick + quality roll, unattached),
  shown to the player, then `accept_reward(state, instance)` (first-seen = free; duplicate =
  5×係數; **never** adds to `unlocked_cards` — 納入不開購買權). `add_reward_card(state, id)` is
  a **deprecated shim** kept only so `sim.gd`/`view/main.gd` compile until W14/W15 rewire; it
  no longer grants purchase rights.
- **Module functions return report Dictionaries** even when today's callers discard them
  (`on_era_transition` now reports evolved/auto-disbanded/population). Godot doesn't warn on
  discarded returns; the view (W15) will need these.

### W12 — battle model

- **Unit dict schema** (the shape battle emits and W15 renders):
  `{card_id, grade, regular, side, faction, attack, hp, strength, row, flags, accuracy,
  dodge, speed, progress, instance}`. `strength` = merit value (base 攻+血 ×係數,
  pre-difficulty); `instance` = the player's `CardInstance` (null for every enemy and ally).
  **`side` is structural** (which camp array the unit fights in — targeting, XP, plunder all
  key off it); **`faction` is the 戰功 attribution tag** (&"player"/&"enemy" in the six fixed
  types; owning-civ ids on 世界大戰 正規軍, W12.5). Never derive one from the other.
- **Event schema** (the timeline the view replays): Dictionaries
  `{tick, type: &"absorb"|&"demolish"|&"repair"|&"miss"|&"dodge"|&"hit"|&"death", ...}` with
  unit labels = `card_id` (player/正規軍) or grade (非正規軍). W13 adds `&"medal"` events.
- **Tick model:** per-unit accumulator `progress += speed / TICKS_PER_ROUND` per tick, fires
  on ≥ 1 (subtract 1, may fire twice in one window at speed 2+), **carries across rounds**
  (speed 0.6 ≈ one attack every 1.67 windows). Within a tick: player units before enemy
  units, each side in deploy order. Never reorder any of this — determinism contract.
- **Boundary order inside `end_round`:** engineer repair → player stat re-snapshot →
  love-and-peace trigger → tick window → sweep dead → **speed-XP grant (W13)** → exhaustion
  check → round-cap check → round++ → wave arrival → buff decrement. The per-boundary stat
  re-snapshot is what makes mid-battle medals apply 自下一回合 (D13) for free.
- **Rolls on `&"battle"`:** wave-arrival rounds at `start`, then per-fire accuracy roll
  before dodge roll. The reward card at `finish` rolls on `&"cards"` via `Cards.roll_reward`.
- **view/main.gd is parse-broken until W15** (it still calls the dead hand API). Part A never
  loads it; Part B **cannot run between W12 and W15** — the W15 gate restores it.

### W13 — growth

- **Lane routing is one function:** `Cards.lane_stat(card_id)` (近戰→`speed`, 遠程/空域→
  `accuracy`, `no_attack` 工兵團→`dodge`, non-units → `&""`) is the single authority used by
  both 兵營 assignment (D14) and 老兵 (D15). Never re-derive the lane elsewhere.
- **XP is integer, 1 per qualifying event**, on `instance.xp`; `Cards.grant_xp(instance,
  stat)` owns the fill check (`CardsData.XP_TO_MEDAL`, remainder carries) and returns whether
  a medal was awarded — the caller emits the timeline event. Stats a card lacks silently
  accrue nothing (工兵團: dodge only), so battle hooks never special-case card types.
- **Battle XP hook sites:** accuracy XP is granted in `_accumulate_and_fire` (an attack
  happened iff `_fire` emitted an event — a fire with no target accrues nothing); dodge XP at
  the dodge event and after a survived hit inside `_fire`; speed XP at the boundary after the
  dead are swept. `&"medal"` events carry `{tick, unit, stat, level}`.
- **老兵 lives inside the `*_of` accessors** (`Cards.veteran_bonus`: +1 effective level on
  the lane stat while `state.regions` has `&"military"`; knob `veteran_levels` in
  `BuildingData.REGIONS`). **The 文化國 debuff does NOT** — contradicting the W12 note above
  that reserved both for `*_of`: the debuff is battle-scoped (`psyops_active` sits on the
  BattleField, 下場戰 only), so it lands in `Battle._snapshot_accuracy`, the one place
  deploy-time and boundary snapshots both read. Anything battle-scoped belongs in the
  snapshot layer; anything run-scoped belongs in `*_of`.
- **勳章 stock is `state.medals`** (int, banks without cap). Production: `Operations.
  produce_medals` in `Turn.begin_generation`, every branch (建築照常產出 — WW and democracy
  generations included). Assignment: `Operations.assign_medal(state, deck_index)` (operate
  phase, player verb), `Operations.auto_assign_medals` (民主後; WW-override generations skip
  assignment entirely). Report keys: `medals_produced` / `medals_auto_assigned`.

### W12.5 — world war on the battle engine

- **The war is a driven battle, same shape as every other:** `WorldWar.start(state)` returns
  a `BattleField` (camps stashed on `battle.camps`); the caller runs the ordinary
  `Battle.deploy`/`end_round` loop; `WorldWar.finish(state, battle)` settles reparations and
  itself calls `Battle.finish` (so the 戰後獎勵卡 comes through the WW report's
  `reward_instance`). Never call `Battle.finish` separately for a world war.
- **Prepared waves:** `Battle.start(..., prepared_waves)` bypasses the roll; wave entries
  are `{round, units, side}` for ALL battle types (the six fixed types always side
  &"enemy"). `_arrive_waves` routes by side; exhaustion counts pending waves per side —
  allied arrivals keep the player camp un-exhausted even with an empty field and no cards.
- **`round_cap` 0 means uncapped** (世界大戰: 波數上限 throttles instead; watch mode grinds
  to camp exhaustion). Any cap check must guard `round_cap > 0`.
- **戰功 bookkeeping lives on every battle:** `merit_by_faction` (clearer's faction →
  Σ strength) and `last_clear_by_side` update on every death; only WorldWar reads them
  today, but the fields are populated for all types (battle.merit stays the player's own
  tally and 掠奪 keys off attacker side).
- **Sim termination rule:** `Sim._drive_battle` concedes when the bot's field is empty
  against a standing enemy and it deployed nothing this boundary — mandatory for uncapped
  battles; harmless (an earlier honest loss) for capped ones. `Turn.run_world_war` is
  deleted; `view/main.gd`'s stale call is part of the known W15 debt.

## Deviations (conservative calls made mid-wave; revisit out loud, not silently)

- **2026-07-24 / W11 — plan's "era_names untouched" line is stale.** The rewrite plan's blast
  radius promised era names wouldn't change, but the W10+wayfinder corpus edits did change
  them (騎兵團 工業＝龍騎兵, 菁英 資訊＝生化超級士兵, 轟炸機 工業＝飛船轟炸隊, 盾陣 現代＝電網,
  火砲 loses 古典 弩砲, 私掠傭兵團 forms 盜匪團/竊賊團/網路駭客, 聖戰士團 工業-only) and
  **removed 壕溝 entirely** (工兵團 becomes the fortification repairer). Per the plan's own
  precedence rule the design docs win; data table synced to the corpus. Consequence for the
  art pipeline: the era-1 unit renders keyed to card identity × era are unaffected (era-1
  names unchanged), but later-era name plates should be checked against
  `assets/pipeline/inventory.md` when W15 wires them.
- **2026-07-24 / W11 — evolution auto-disband ignores the deck minimum.** 卡牌.md says a card
  entering an era with no form 自動解散 but doesn't address 牌組下限 5. Forced disband
  proceeds even if it drops the deck below 5 (the alternative — an unplayable ghost card the
  design says doesn't exist — contradicts the evolution table). The minimum keeps guarding
  *voluntary* disband only. Logged as a decisions.md row.
- **2026-07-24 / W11 — 勸降廣播 flag renamed** `convert_weak_enemy` → `convert_non_leader`:
  the corpus now scopes it (and all 非首領 skills) to non-hard irregulars, with 首領＝硬級.
  Old battle.gd reads the old flag and so casts it as a no-op until W12 rewires targeting —
  accepted, battle_test is scheduled for full rewrite in W12.

- **2026-07-24 / W12 — sim._fight patched outside its wave.** `sim.gd` is W14's file, but
  deleting the hand breaks its parse, which would take the whole suite down. It got a
  minimal deterministic policy (field cheapest units until outnumbering the visible enemy
  field by one; take first-seen rewards, skip duplicates). W14 still owns the real
  tempo-aware auto-player and the balance batch.

## Tasks raised (not part of the current wave; tracked on PLAN.md)

- **Starting-state sync:** raised in W11, landed as W13.5 (see Wave status).

## Wave status

- **W11 (card model): done 2026-07-24.** Files: `core/cards.gd`, `core/data/cards.gd`,
  `test/cards_test.gd` (+ `game_state.gd` deck comment). Gate: cards_test green, same-seed
  determinism asserted. All five handoff items to W12 were honored (quality via `*_of` only,
  `wipe_growth` on death, reward via `roll_reward`/`accept_reward`, `min_era` deleted,
  engineers repair + 首領＝硬級 targeting, no retired flags).
- **W12 (battle model): done 2026-07-24.** Files: `core/battle.gd`, `test/battle_test.gd`
  (+ minimal `sim.gd::_fight` compile-fix, see Deviations). Gate met and exceeded: battle_test
  green with a same-seed identical-timeline assertion, and the FULL suite is back to
  **exit 0, 21/21 suites, 208/208 cases** — two waves ahead of the plan's W14 expectation.
  Hand/draw/discard deleted; waves + tick timelines + symmetric exhaustion + survivor
  persistence live; 文明戰爭 fields 正規軍. 世界大戰 on this engine (WW1-WW5) is
  W12.5-scale work — `world_war.gd` still runs the PoC power-sum contest today.
- **W13 (growth): done 2026-07-25.** Files: `core/cards.gd`, `core/data/cards.gd`,
  `core/battle.gd` (hooks), `core/operations.gd`, `core/data/buildings.gd`, `core/rivals.gd`
  (comment), `core/data/rivals.gd`, `core/game_state.gd` (`medals`), `core/turn.gd`, and the
  five touched suites. Gate met: full suite **exit 0, 21/21 suites, 223/223 cases** (15 new).
  Both medal sources live (battle-automatic with timeline events, 兵營 produce/assign +
  democracy auto-assign), 老兵 in the accessors, 文化國 D16 accuracy debuff consumed by the
  battle snapshot. `opening_hand_bonus`/`opening_slots_bonus` deleted. Handoff to W12.5/W14:
  the sim bot never voluntarily assigns 兵營 medals pre-democracy (stock just banks until
  the democracy auto-assign) — the W14 tempo bot should spend it; W15 renders `&"medal"`
  events and the `state.medals` stock (to_dict already carries it).
- **W13.5 (starting-state sync): done 2026-07-25.** Files: `core/game_state.gd`
  (population 0 + `collapse_armed`), `core/unrest.gd` (lazy arming inside
  `regime_collapsed` — samples at the settle cadence, permanent once set), `core/sim.gd`
  (`_grow_population`: disband personnel deck-order-first while pop < 20, deck minimum
  guarded by `Cards.disband`), plus six tests that now pin pop 12 explicitly where the
  delta math assumed it. Gate: full suite exit 0, 21/21, 223/223. Handoff to W14: an
  unarmed run can never collapse, so seeds where the bot keeps pop < 5 forever are
  immortal-by-rule — the balance batch should report pop trajectories and how many runs
  never arm the check.
- **W14 (sim + balance): done 2026-07-25.** Files: `core/sim.gd` (tempo bot:
  `_drive_battle` fields cheapest units to 攻+血 parity per boundary, personnel-first in
  riots via `_pick_deploy`; `_spend_medals` routes the 兵營 stock to the strongest unit
  card), `tools/balance_batch.gd` (new telemetry: collapse_armed, medal counts, WW
  fought/won), `docs/balance-report.md` (rewritten from the 60-run batch). Gate met: full
  suite exit 0, 21/21, 222/222, determinism green. The report's PM-facing headline: WW
  sizing knobs don't yet produce the designed gen-35 wall (player camp wins ~95%), and
  per-lane medal telemetry is the next cheap instrument for the 攻速-runaway flag. Bot
  still never plays skills/forts/psyops (report caveats).
- **W12.5 (world war on the battle engine): done 2026-07-25.** Files: `core/world_war.gd`
  (rewritten: composer + settlement, power-sum contest deleted), `core/battle.gd` (side/
  faction split, prepared waves, per-side pending-wave exhaustion, uncapped rounds,
  merit_by_faction/last_clear_by_side), `core/turn.gd` (run_world_war deleted),
  `core/sim.gd` (_drive_battle/_world_war/_take_reward refactor + concede guard),
  `test/world_war_test.gd` (rewritten, 6 cases). Gate met: world_war_test + battle_test
  green, full suite **exit 0, 21/21 suites, 222/222 cases**; sim runs now fight both world
  wars for real and stay deterministic. Handoff to W14: the war reshapes mid/late-game
  money (reparations pools are real now) — rerun the balance batch; the bot's outnumber-
  by-one deploy rule is naive on a multi-civ table (allies count as its units). W15: the
  battle scene needs faction color/banner markers keyed off `faction` (WW5, no new art).
