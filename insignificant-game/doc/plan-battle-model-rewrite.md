# Battle model rewrite: implementation plan (master reference)

> **For agentic workers:** this is the **reference**, not a task list you can execute directly.
> It carries the locked design, the glossary, and the wave sequence. Each wave below gets its
> own detailed TDD plan written just-in-time, when the preceding wave's shape is known. Use
> `superpowers:subagent-driven-development` or `superpowers:executing-plans` against those
> per-wave plans, not against this file.
>
> This file is a purpose-built planning log (same class as `PLAN.md` and `decision-*.md`), so
> unlike the rest of `doc/` it is allowed to carry rationale. It exists because the rationale is
> load-bearing: three mechanics were previously built out of doc contradictions, and the "why"
> below is what stops that recurring.

**Goal:** Replace the StS-derived hand/deck battle with a wave-fed autobattler in which units are
rolled instances that grow, so 最小軍費取勝 becomes a live multi-round tempo decision.

**Architecture:** The enemy commits in rolled waves; the player deploys any unplayed card on any
round, gated only by 軍費. Each 回合 is a fixed tick window that `core/battle.gd` resolves into a
complete, deterministic event timeline **before** the view animates a frame; the view is a replay
device. Cards become instances carrying a rolled innate quality triple plus earned growth.

**Tech stack:** Godot 4.6, GDScript, 2D. gdUnit4 for Part A. `INSIG_DEMO` capture for Part B.

---

## Global constraints

Copied from `insignificant-game/CLAUDE.md`. Every wave's requirements implicitly include these.

- **GDScript only**, never C#. Godot **4.6** idioms. **Static typing everywhere**.
- **Pure core.** `core/` is `class_name X extends RefCounted` + static funcs taking
  `state: GameState` first. No nodes, signals, autoloads, `_ready`, `Input`, rendering.
  **The view computes nothing.**
- **Determinism.** All randomness via `state.rng` named tracks. Same seed produces an identical
  run; `test/sim_test.gd::test_determinism_same_seed_same_run` enforces it. Wall-clock entropy is
  a bug.
- **Content is data.** Rules read `core/data/*.gd` const tables. Logic never hardcodes content.
- **Both loop parts before "done".** Part A (gdUnit4, exit 0, all suites executed) AND Part B
  (`INSIG_DEMO` capture reviewed against the defect taxonomy, zero ASSERT FAIL).
- **Module boundaries are file boundaries.** Touching module X means `core/x.gd`,
  `core/data/x_*.gd`, `test/x_test.gd`.
- **Doc ↔ code metadata both directions** in the same change: each corpus doc's `code:`
  frontmatter, and each module's header comment citing its `design/*.md`.
- **Design authority chain.** The Obsidian corpus at
  `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian/game-design/` is upstream
  truth. `design/` here is a read-only snapshot; re-copy changed files after any corpus edit.
- **Numbers are v1 baseline knobs.** Calibration changes values, never structure. Fun and balance
  calls belong to the human: measure with the sim, surface findings in `doc/balance-report.md`,
  do not decide.

---

## Why this exists

The corpus was 定稿 and contradicted itself. `戰鬥.md` ruled that 「出牌的唯一限制是軍費」 (money is
the only gate, you may deploy everything), while `營運.md` sold 軍事區 a passive of 「戰鬥開場手牌 +1」
and 兵營 a line output of 「戰鬥開場部隊位 +1」, and `對手文明.md` gave 文化國 the threat 「你的下場戰
開場手牌 −1」. Three mutually exclusive deployment gates (軍費, 手牌, 部隊位) coexisted in a locked
design.

An agent resolved that contradiction the only way it could: it built a full StS hand system
(`OPENING_HAND = 4`, draw pile, discard, draw 1/round) and logged it in `decision-w3-w5-gaps.md`
as 「design implies "opening hand" but pins nothing」. The note was accurate. The corpus caused it.

Separately, `_add_enemies()` ran once at setup and `enemy_units` was never appended to again, so
敵方開場單位 was never an *opening*, it was the enemy's whole force delivered on round 1. Combined
with a field-empty win check, every battle was decided in one or two rounds and the 回合上限 of 6
to 12 was decoration. The 最小軍費取勝 gamble that `戰鬥.md` calls the core 博弈 had collapsed into a
single arithmetic step.

This rewrite fixes the contradiction at the source (corpus first, then code) and rebuilds the
battle around the gamble the design always claimed to be about.

---

## Locked decisions

Human-decided in the grilling session of 2026-07-17. **Do not reopen these while executing.**
Surface a design question instead.

### Deployment and pacing

| # | Decision |
|---|---|
| **D1** | **No hand.** 手牌 is retired entirely. Any unplayed card may be deployed on any round. 軍費 is the only gate. `戰鬥.md`'s existing rule becomes literally true. |
| **D2** | **The enemy arrives in scheduled waves.** Waves are what meter a battle across rounds. |
| **D3** | **Defeat is exhaustion, symmetric.** A side loses when its field is empty **and** it has nothing left to commit (enemy: no waves remain; player: no unplayed affordable card). 陸軍 rule, 回合上限 判輸, and 撤軍 all unchanged. |
| **D4** | **Survivors persist.** Units that live through a wave stay on the field into the next, **both sides**. An uncleared wave means the next wave stacks on its remnant. |
| **D5** | **Wave schedules are authored per battle type and rolled per battle** via a `state.rng` track. The six fixed types get authored wave tables (敵方開場單位 becomes wave 1). 文明戰爭 and 世界大戰 spread their existing strength budget (總實力 ≈ P×0.5) across a schedule. 開戰前情報 reveals **the roll**. |

**Why waves and not a hand:** with D1, D4, and D5, under-committing lets the enemy stack and
drown you, while over-committing burns 軍費 you did not need. That is 最小軍費取勝 as a tempo
problem across rounds, which is what the round caps always implied and nothing delivered.

### Time and resolution

| # | Decision |
|---|---|
| **D6** | **A 回合 is a fixed tick window** (tick count is a calibration knob; 100 is the starting proposal). Deployment and 軍費 stay round-gated. Core resolves the round's **entire event timeline** (every hit, dodge, death, kill credit, medal award, with tick stamps) **before** the view animates anything. The view replays it. **No input during playback.** |
| — | **同時結算 is retired.** Units act on their own attack speed, so melee no longer resolves simultaneously and `_resolve_combat()`'s snapshot model dies. |
| — | **Mutual destruction disappears.** Under 同時結算 two units could kill each other; under speed the faster one fires first and lives. |
| — | **戰功歸屬 survives unchanged.** It records the clearer, and speed makes that less ambiguous, not more. 世界大戰 is unaffected. |

**Why per-round and not per-battle:** the whole battle cannot be precomputed, because D1 makes the
player an input at every boundary. Round N+1's timeline cannot exist until the player has deployed
against wave N, and that decision depends on what they just watched. The battle is a chain of
precomputed blocks, re-formed at each boundary.

**Balance flag for the human:** attack speed becomes the strongest stat in the game. This is the
standard autobattler trap. Measure it before shipping v1 numbers.

### Cards as instances

| # | Decision |
|---|---|
| **D7** | **Acquisition is the gacha.** Every card **instance** rolls its innate quality within a per-type distribution. Two 弓箭團 are not the same 弓箭團. |
| **D8** | **The innate three are accuracy, dodge, speed.** 攻 and 血 stay **fixed** per type and era, exactly as 卡牌總表 says. 血 is how many men (deterministic), 攻 is how hard the type hits, the innate three are how good these particular men are. |
| **D9** | **Per-stat XP: you improve what you exercise.** Accuracy grows by attacking. Dodge grows by being attacked and surviving. Speed accrues passively from rounds survived. A unit's stat line reads as its history. |
| **D10** | **就地演化 carries everything forward.** Innate three and earned medals both survive era evolution. A bad roll is therefore permanent for the run unless replaced via the paid 解散 → 解卡費 loop, which is what makes 解散 a considerable operational action. |
| **D11** | **Death wipes earned growth; the card returns at level 0.** The institution survives, the veterans do not. |
| **D12** | **Death does NOT re-roll the innate three.** |

**Why D12 is not optional:** if death re-rolled the innate three, deliberate suicide would be the
cheapest re-roll in the game. Deploying a bad 弓箭團 to die costs 2×時代係數 軍費 and soaks enemy
hits on the way out; the legitimate 解散 → 解卡費 loop costs 10×時代係數. The exploit is 5× cheaper
and does you a favour. D12 kills it. Read the innate three as the regiment's **doctrine** (how it
recruits, drills, and shoots): experience dies with the veterans, the training tradition does not.

**Why the art pipeline is safe:** names stay in the era evolution table, 攻 and 血 stay in
卡牌總表, and only three invisible quality stats roll. Era-1 units art (`c64270c`, 15 lineage
lines keyed to card identity × era) is **not invalidated**. Nothing generated needs regenerating.

### Medals (勳章)

| # | Decision |
|---|---|
| **D13** | **Battle medals are automatic.** When a unit's XP completes, the medal lands at that precomputed tick. No input, fully inside the round's block, shown live. |
| **D14** | **Building medals are assigned.** 軍事·兵營 produces a 勳章; the player chooses **which card receives it**, in the operation scene. This replaces 兵營's 「戰鬥開場部隊位 +1」. |
| **D15** | **軍事區 基礎被動 = 老兵 (veterancy):** your units start one growth level up. This replaces 「戰鬥開場手牌 +1」. It is pure 純戰力, cannot be bought with money, and preserves 軍事區's 無軸 identity. |
| **D16** | **文化國 心戰 → your units start the next battle with reduced accuracy.** This replaces 「你的下場戰開場手牌 −1」. 傳播線's existing 「心戰效果增強」 upgrade keeps working on both directions unchanged. |

**Naming:** the award is 勳章 (medal). It is **not** a 卡. 卡 already means a deck card, and the
medal is a thing awarded *to* a card. Keeping these separate is deliberate; conflating 手牌 across
two docs is what cost this project a mechanic.

---

## Glossary

Terms are load-bearing. Use exactly these; do not drift to synonyms.

| Term | Meaning |
|---|---|
| **攻 / power / `attack`** | One concept, three spellings, all the same thing. Fixed per card type and era, from 卡牌總表, scaled by 時代係數. Never rolls. |
| **血 / HP** | Fixed per card type and era. "How many men the regiment has." Never rolls. |
| **innate three** | accuracy, dodge, speed. Rolled per card **instance** at acquisition, within a per-type distribution. "How good these particular men are." |
| **勳章 (medal)** | A growth award. Two sources: battle (automatic on XP completion, D13) and 兵營 (assigned in the operation scene, D14). Never called a card. |
| **wave** | One scheduled enemy commitment inside a battle. Rolled per battle (D5). |
| **tick** | The atomic time unit inside a 回合. Units act on their own attack speed. |
| **timeline** | The complete, ordered, tick-stamped event list core emits for one round. The view replays it and decides nothing. |
| **老兵 / veterancy** | 軍事區's 基礎被動 (D15): units start one growth level up. |
| **exhaustion** | The defeat condition (D3): field empty **and** nothing left to commit. |
| **回合 (round)** | A fixed tick window. The atomic unit of play: deployment, 軍費, and wave arrival all happen at its boundary. |

### Retired terms (never reintroduce)

| Term | Status |
|---|---|
| **手牌 (hand)** | **Retired (D1).** No hand, no draw pile, no opening hand, no hand size. If a doc or comment implies one, it is stale; fix it. |
| **部隊位 (slots)** | **Retired (D14).** Was 兵營's line output. Replaced by assignable 勳章. |
| **同時結算** | **Retired (D6).** Units act on attack speed. |

---

## Blast radius

Verified against the tree at `c64270c`. `192/192 green` does not survive this; expect it to go red
and come back.

| File | What breaks / changes |
|---|---|
| `core/battle.gd` (516 lines) | `OPENING_HAND`, `hand`, `draw_pile`, `discard_pile`, `_draw()`, `play_card(hand_index)` all die. `_resolve_combat()`'s simultaneous snapshot dies. `_check_victory()`'s field-empty test becomes exhaustion (D3). `_add_enemies()` becomes per-wave. New: wave schedule roll, tick loop, event timeline emission. |
| `core/cards.gd` | `CardInstance` is currently `id` + `tier`. Add innate three, per-stat XP, medals. Cards become instances with history. `attack_of()` / `hp_of()` stay as they are (D8). |
| `core/data/cards.gd` | Add per-type distributions for the innate three. `attack` / `hp` / `era_names` untouched. |
| `core/sim.gd` | `_fight()` (line 158) loops over `battle.hand`. Full rewrite. Must auto-resolve headless and stay deterministic. |
| `core/operations.gd` | `opening_hand_bonus()` (line 138) dies → 老兵 veterancy (D15). `opening_slots_bonus()` (line 143) dies → 兵營 medal production (D14). |
| `core/rivals.gd` | 文化國 psyops rewires from `enemy_psyops_next_battle` hand −1 to an accuracy debuff (D16). `attack_multiplier()` / `psyops_discount` (player → rival direction) unchanged. |
| `core/game_state.gd` | `deck` becomes instances carrying innate three + XP + medals. `flags[&"enemy_psyops_next_battle"]` semantics change. |
| `core/data/rivals.gd` | 文化國 psyops effect entry. |
| `test/battle_test.gd` | Rewrite. |
| `test/cards_test.gd` | Rewrite. |
| `test/sim_test.gd` | Determinism + termination invariants must hold across the new model. |
| `test/operations_test.gd` | 軍事區 / 兵營 assertions. |
| `test/rivals_test.gd` | 文化國 psyops assertions. |
| `tools/balance_batch.gd` | Battles change shape; recalibrate against `doc/balance-report.md`. |
| `view/main.gd` | Superseded by the three-scene revamp (final wave). |
| Corpus: `卡牌.md` | 卡牌總表 gains distributions; 卡牌經濟 gains the growth/medal rules; framing stops being StS. |
| Corpus: `戰鬥.md` | 戰場結算法, 勝負, 戰鬥類型表 (敵方開場單位 → wave schedules), 場景呈現 (drop 手牌). |
| Corpus: `營運.md` | 軍事區 基礎被動 (line ~46), 軍事·兵營 line output (line ~61), 餵給誰 gains the 營運 → unit growth edge. |
| Corpus: `對手文明.md` | 文化國 threat (line ~33). |
| `design/` snapshot | Re-copy all four after the corpus edit. |
| `doc/decision-w3-w5-gaps.md` | The 「Battle hand system」 row (line 12) and 「文化國 psyops-vs-player cadence」 row (line 8) are superseded. |

---

## Wave sequence

`PLAN.md`'s current W10 (three-scene view revamp) is **blocked by this work** and moves to the
end. Its art blocker is genuinely cleared (`9b45ed8` backgrounds gate, `c64270c` units era 1), but
the core it would render no longer exists. The route fog-map scene is the only piece independent
of this rewrite.

Update `PLAN.md` to:

| Wave | Deliverable | Gate |
|---|---|---|
| **W10** | **Corpus rewrite.** All four docs above, plus `design/` re-copy, plus the `code:` frontmatter both directions. **No code.** | Human reads and accepts the four docs. No contradiction survives between them: grep 手牌 and 部隊位 to zero. |
| **W11** | **Card model.** `cards.gd` instances, innate three, acquisition roll, `data/cards.gd` distributions, `game_state.gd` deck. | Part A green on `cards_test`. Rolls deterministic under a seed. |
| **W12** | **Battle model.** Waves, wave roll, tick loop, event timeline, exhaustion, survivor persistence. Delete the hand. | Part A green on `battle_test`. Timeline is deterministic and replayable from a seed. |
| **W13** | **Growth.** Per-stat XP, medals (both sources), 老兵, 兵營 assignment, 文化國 accuracy debuff. `operations.gd` + `rivals.gd` rewiring. | Part A green on `cards_test`, `operations_test`, `rivals_test`. |
| **W14** | **Sim + balance.** `sim.gd::_fight()` rewrite, full suite back to exit 0, balance batch recalibrated. | **Part A exit 0, all suites executed.** `test_determinism_same_seed_same_run` green. Balance findings surfaced to the human in `doc/balance-report.md`; do not tune to taste. |
| **W15** | **Three-scene view revamp** (the old W10). Operations city panorama with 勳章 assignment and 解散 evaluation UI, route fog-map, per-battle-type battle scene replaying the timeline. | Part A + **Part B** capture, zero ASSERT FAIL. |

**Corpus first is not negotiable.** Every mechanic torn out here was built because an agent found
a doc contradiction and resolved it alone. If code lands before docs, the next agent inherits a
corpus contradicting the code, and this session repeats in three months.

---

## Open calibration items

Numbers are the human's, per the design authority chain. Measure and surface; do not decide.

- Tick count per 回合 (proposal: 100).
- Innate three distribution ranges per card type. Must be a "reasonable range" (human's words);
  a golden roll should be exciting and rare, a bad roll should sting without being unplayable.
- Growth step per 勳章. Note +1 accuracy over a 100-tick round is a rounding error while +1 speed
  may be a large damage swing; steps likely differ per stat.
- Wave schedules per battle type, and how the 總實力 ≈ P×0.5 budget spreads for 文明戰爭.
- 兵營 medal production rate (per generation? per era?).
- 回合上限 per type (currently 6/8/8/8/8/10/12) must be ≥ last wave + time to clear it, or the
  player times out while winning.
- Accuracy debuff magnitude for 文化國 (D16). Its 威脅 column says 「極低（不主動）」, so this
  should be a nuisance, not a threat.

## Parked design questions

Raised in session, **not decided**. Do not resolve these unilaterally; ask the human.

- **Does 解散 of a veteran still return +2 人口?** Probably yes (it is about the men, not their
  skill), but unconfirmed.
- **Should 人數型 units that die in battle cost 人口?** Currently death costs nothing and 解散
  returns +2. A death cost would connect 戰鬥 → 人口, but it is not in the corpus and was not
  decided.
- **Can the player hold reserves deliberately, or is "unplayed" purely a money outcome?** D1 says
  money is the only gate, which implies the latter.
- **世界大戰 共桌 ordering** (「各文明依卡池張數排出場序，陣營交錯出牌」) under waves: unexamined.
