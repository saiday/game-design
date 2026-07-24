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

- **Unit dict schema** (the shape battle emits, W13 grows, W15 renders):
  `{card_id, grade, regular, faction, attack, hp, strength, row, flags, accuracy, dodge,
  speed, progress, instance}`. `strength` = merit value (base 攻+血 ×係數, pre-difficulty);
  `instance` = the player's `CardInstance` (null for every enemy); `faction` is the 戰功
  attribution tag (&"player"/&"enemy" today, civ ids when 世界大戰 lands on this engine).
- **Event schema** (the timeline the view replays): Dictionaries
  `{tick, type: &"absorb"|&"demolish"|&"repair"|&"miss"|&"dodge"|&"hit"|&"death", ...}` with
  unit labels = `card_id` (player/正規軍) or grade (非正規軍). W13 adds `&"medal"` events.
- **Tick model:** per-unit accumulator `progress += speed / TICKS_PER_ROUND` per tick, fires
  on ≥ 1 (subtract 1, may fire twice in one window at speed 2+), **carries across rounds**
  (speed 0.6 ≈ one attack every 1.67 windows). Within a tick: player units before enemy
  units, each side in deploy order. Never reorder any of this — determinism contract.
- **Boundary order inside `end_round`:** engineer repair → player stat re-snapshot →
  love-and-peace trigger → tick window → sweep dead → exhaustion check → round-cap check →
  round++ → wave arrival → buff decrement. The per-boundary stat re-snapshot is what makes
  mid-battle medals apply 自下一回合 (D13) for free in W13.
- **XP accrual hooks** are marked with W13 comments inside `_fire` (accuracy XP at hit,
  dodge XP at dodge; speed XP per survived round belongs at the boundary).
- **Rolls on `&"battle"`:** wave-arrival rounds at `start`, then per-fire accuracy roll
  before dodge roll. The reward card at `finish` rolls on `&"cards"` via `Cards.roll_reward`.
- **view/main.gd is parse-broken until W15** (it still calls the dead hand API). Part A never
  loads it; Part B **cannot run between W12 and W15** — the W15 gate restores it.

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

- **Starting-state sync (before the W14 gate):** corpus now pins 起始人口 0 (營運.md) with the
  政權崩潰 check arming only after population first reaches 5 (內亂與失敗.md); code still
  starts at 12 with an always-armed check. Touches `game_state.gd`, `unrest.gd`,
  `docs/decisions.md` W1 table; sim's auto-player must learn the disband-for-population
  opening or every W14 run starves. Deliberately NOT folded into W11 (card files only).

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
  persistence live; 文明戰爭 fields 正規軍. Handoff to W13: fill the XP hooks in `_fire` and
  the speed-XP boundary hook, emit `&"medal"` events at the filling tick, wire 老兵/兵營/
  文化國 into `operations.gd`/`rivals.gd` and the `*_of` accessors (`psyops_active` on the
  BattleField and the reserved `state` params are waiting). 世界大戰 on this engine (WW1-WW5)
  is W12.5-scale work parked inside the W14 wave slot or its own follow-up — `world_war.gd`
  still runs the PoC power-sum contest today.
