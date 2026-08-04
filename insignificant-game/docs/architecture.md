# Architecture contract (all implementation agents read this first)

> **What this is:** the shared contract for Insignificant — module map, layering rules,
> GameState schema, naming glossary, determinism and test conventions. Design *content* (rules,
> numbers, tables) lives in `design/` (the single source of truth for game rules). This doc only
> fixes *how the code is shaped* so parallel agents don't collide.

## Layering (MANDATORY, from the guideline)

1. **`core/` — pure logic.** Every file is `class_name X extends RefCounted` (or a class with only
   static functions). **No scene nodes, no autoloads, no `_ready`, no signals, no `Input`, no
   rendering.** Everything here must be constructible and testable headless.
2. **`core/data/` — static content tables** (buildings, cards, policy nodes, candidates, rivals,
   opportunities, epilogues) as `const` tables in plain GDScript. Data-driven: logic reads tables,
   never hardcodes content.
3. **`view/` — Godot scenes/UI.** Reads GameState, calls core functions on click, renders with
   placeholder visuals (ColorRect/Label/Button only). View never computes rules.
4. **`test/` — gdUnit4 suites**, one per core module (`test/economy_test.gd` for `core/economy.gd`).
5. **`tools/` — headless `SceneTree` scripts** run with `-s`, never part of the game: the balance
   batch (`balance_batch.gd` → `reports/`) and the timeline exporter (`export_timeline.gd` →
   `docs/fixtures/battle_timeline.json`, replayed by the HTML battle replayer). They read core the
   same way a test does and write only under `reports/` or `docs/fixtures/`.

**Static typing everywhere** (`var x: int`, `func f(state: GameState) -> int`). Godot 4.6 idioms:
`await` not `yield`, typed arrays (`Array[int]`), `StringName` for enum-like keys.

## Function style

- Core functions are `static func` on the module class, taking `state: GameState` first:
  `static func settle(state: GameState) -> SettleReport`.
- Functions **mutate the passed state in place** and return a small typed report object
  (RefCounted) or Dictionary describing what happened (for the view/log). No hidden globals.
- All randomness through `state.rng` (seeded tracks) — same seed ⇒ same run, always.
- Costs/values that scale by era go through `Era.coeff(generation)` — never duplicate the 1/2/3/5/8/12 table.

## Module map (`core/`)

| Module | class_name | Owns (design doc) |
|---|---|---|
| `rng.gd` | `SeededRng` | named RNG tracks (map/battle/opportunity/rivals/democracy/naming) |
| `era.gd` | `Era` | generation→era, era cost coeff, tech gate 時代序, era BP caps (時代與回合) |
| `game_state.gd` | `GameState` | the whole mutable run state + `new_run(seed)` + `to_dict()` (schema below) |
| `economy.gd` | `Economy` | tax, interest ladder, capital gains, settle pipeline, debt consequences (經濟與債務) |
| `operations.gd` | `Operations` | BP production/carryover, region/building build+upgrade, escalating cost, 兵營 勳章 production/assignment (營運) |
| `policy.gd` | `Policy` | 國策 DAG (24 nodes) data + lock progression + effect flags queries (國策) |
| `happiness.gd` | `Happiness` | happiness sources/clamps (幸福) |
| `unrest.gd` | `Unrest` | unrest weight, trigger roll, concession, riot consequences, regime collapse check (內亂與失敗) |
| `cards.gd` | `Cards` | card catalog, unlock/tech gates, deck ops, era evolution, delete/disband (卡牌) |
| `battle.gd` | `Battle` | battlefield sim: auto-deploy, rounds, fortifications, win/loss, war merit, military spend; 7 battle types (戰鬥) |
| `map_nodes.gd` | `MapNodes` | per-generation node layer, fog, opportunity events (地圖與機會) |
| `rivals.gd` | `Rivals` | 5 automa power curves, aggression, relations/influence ledger, exit/annex/inherit (對手文明) |
| `world_war.gd` | `WorldWar` | camps, turn order, WW sim, reparations (世界大戰) |
| `democracy.gd` | `Democracy` | entry, candidate pool, funding, election, auto-run per generation (民主) |
| `legacy.gd` | `Legacy` | legacy conditions + effect queries (Legacy) |
| `ending.gd` | `Ending` | survival/collapse, ranking, epilogue pick (結局) |
| `difficulty.gd` | `Difficulty` | difficulty formula: enemy scaling, event severity, rival params (doc + design sync) |
| `turn.gd` | `Turn` | one-generation orchestrator: operate → route → node → settle; WW/democracy overrides |
| `sim.gd` | `Sim` | scripted auto-player for full-run simulation/invariant tests |

Module boundaries = file boundaries. **An agent implementing module X touches only
`core/x.gd`, `core/data/x_*.gd`, `test/x_test.gd`** — nothing else. Cross-module needs go through
GameState fields or an existing module's public statics; if something is missing from GameState,
report it instead of hacking around it.

## GameState schema (author: driver; extend via report, don't fork)

```gdscript
class_name GameState extends RefCounted
# identity / clock
var seed: int
var rng: SeededRng
var generation: int            # 1..50
var difficulty: StringName     # &"easy" | &"normal" | &"hard"
# four axes + money
var population: int            # start 0 (起始人口 0); <5 ⇒ regime collapse (only game over)
var collapse_armed: bool       # the collapse check arms when population first reaches 5
var happiness: int             # 0..100
var culture: int
var tech: int
var treasury: int              # single money pool; negative = debt (never directly lethal)
# operations
var bp: int                    # unspent BP this generation
var bp_carryover: int          # ≤2 (enlightened_absolutism ⇒ ≤3)
var regions: Array[StringName] # built regions of 5 types (livelihood/academic/military/culture/finance)
var buildings: Dictionary      # StringName line -> int tier (one building per line, upgrade in place)
var buildings_built: int       # lifetime count of NEW buildings (escalating-cost coefficient; upgrades DON'T increment)
var medals: int                # 兵營-produced 勳章 stock awaiting assignment (banks without cap)
# policy tree
var policies: Array[StringName]        # completed node ids
var policy_in_progress: StringName     # &"" if none
var policy_points_in: int              # BP already sunk into in-progress node
# deck
var deck: Array                # Array[CardInstance] (defined in cards.gd)
var unlocked_cards: Array[StringName]
# legacies
var legacies: Array[StringName]
var martial_law_available: bool        # 戒嚴 one-shot
# rivals: Array[RivalState] (defined in rivals.gd: id, display_name, p0, g, power, alive,
#   warred_this_window, defeats, psyops_hits, influence: Dictionary)
var rivals: Array
var psyops_used_this_gen: bool         # 心戰 1/generation shared cap
var pending_war_target: StringName     # set by declare_war, consumed by next node
# democracy
var is_democracy: bool
var democracy_entered_gen: int
var incumbent: StringName
var candidate_pool: Array              # Array[Dictionary] from data table + probabilities
# flags & counters
var ww_results: Array                  # per-WW summary dicts
var unrest_battles_this_gen: int
var debt_unrest_mode: bool             # 國債司: debt consequence switches from -5 happiness to unrest weight
var flags: Dictionary                  # misc one-shot flags (e.g. state_religion_decay ticks)
# telemetry (balance calibration)
var log: Array                         # per-generation snapshot dicts appended by Turn.settle
```

Derived values are functions, not stored fields: `Operations.bp_income(state)`,
`Rivals.player_power(state)` (人口+文化+幸福/10+科技+建築階數總和+牌組實力/10), `Era.of(generation)`, etc.

## Glossary (design term → code name; use these exactly)

**This is the repo's only glossary.** Every doc that needs the vocabulary links here rather than
restating it; a second copy drifts from the code the moment one side is edited alone. `design/` owns
what a term *means in the game*, this owns what it is *called in code*, and the two are joined by the
`code:` frontmatter the graph checker verifies. Don't create a root `CONTEXT.md` (`/domain-modeling`
will try).

代 generation · 時代 era (tribal/classical/faith/industrial/modern/information) · 時代係數 `Era.coeff()`
· BP build points · 營運 operations · 國策 policy · 幸福 happiness · 內亂 unrest · 讓步 concession
· 戒嚴 martial law · 政權崩潰 regime collapse · 軍費 military spend · 賠償 reparations · 戰功 war_merit
· 宣戰 declare_war · 心戰 psyops · 併吞 annex · 退場 rival exit · 影響力 influence · 貴族資金 noble funds
(democracy rename of treasury, same pool) · 資本利得 capital gains · 國寶 national treasure
· 人數型/機械型/技能 personnel/mechanical/skill cards.

### Battle model terms (see `docs/plan-battle-model-rewrite.md` for the locked design)

These carry traps, so they get rows instead of a run. **Code** is the identifier actually in the
source, not a translation of the 中文. **Avoid** is normative: those words are wrong here, either
because they name a different concept or because no identifier uses them.

| Term | Code | What it is | Avoid |
|---|---|---|---|
| 攻 attack | `attack` | How hard a card's type hits. Fixed per type and era; never rolls. | **power** — in this codebase that is the civilization scalar below, not a card stat |
| 血 hp | `hp` | How many men the regiment has. Fixed per type and era; never rolls. | health, damage pool |
| **innate three** | `accuracy` / `dodge` / `speed` | The three stats rolled per card *instance* at acquisition: how good these particular men are. | stats (ambiguous with 攻/血, which never roll) |
| 勳章 medal | `medal`, `medals`, `award_medal`, `assign_medal` | A growth award of +1 level on one stat. | card (a 勳章 is never a card) |
| 老兵 veterancy | `veterans`, `veteran_bonus`, `veteran_levels` | 軍事區's 基礎被動: an always-on +1 growth level on the recipient's lane stat. | `veterancy` as an identifier (no identifier uses it) |
| **lane** | `Cards.lane_stat()` | The category deciding *which* stat a 勳章 or 老兵 level lands on. | `row`: they diverge at 工兵團, which stations in the 遠程列 but keeps the 閃避率 lane |
| 回合 round | `round`, `end_round` | A fixed tick window; deployment, 軍費 and wave arrival all happen at its boundary. | turn (that is 代 / `generation`) |
| **tick** | `tick`, `TICKS_PER_ROUND` | The atomic time unit inside a 回合. | frame, step |
| **wave** | `_roll_waves`, `prepared_waves`, `next_wave` | One scheduled enemy commitment inside a battle. | spawn, reinforcement |
| **exhaustion** | `exhausted`, `_check_exhaustion` | The defeat condition: field empty AND nothing left to commit. Per camp in 世界大戰. | rout, wipe |
| 掩護鏈 cover chain | none: the ordering is implied by each unit's `row` | The formation 近戰列 → 工事線 → 遠程列 → 空域, each layer screening the one behind it (ADR-0008). | formation, front line, 部隊位 (retired) |
| **station** | `row` (`melee`/`ranged`/`air`/`fortification`/`global`) + `stationed` + `screened_by` | A unit's place in the chain: its row, plus which wall screens it (遠程列 only). Assigned by 自動佈陣, never chosen. | slot, coordinate, position (the core holds none) |
| 掩護 screen | `screens_ranged_row`, `regular_screens`, `screened_by` | What one layer of the chain does for the layer behind it. Only the 遠程列 is ever screened, and only against **ranged** fire (ADR-0010). | cover (that is the neutral kind below), block, absorb |
| 工事 fortification | `fort`, `forts`, `enemy_forts`, `FORT_LIMIT` | A structure occupying the 工事線: disabled and repaired, never removed (ADR-0007). | works; `fortification` as an identifier (no identifier uses it) |
| 盾陣 wall | `shield_wall` | The screening fort: one card is one segment spanning the 遠程列's frontage. | shield; not a synonym for 工事 (防空飛彈 is a fort too), and not a synonym for the barrier below (a wall is owned, repairable and in the chain) |
| 中立掩體 barrier | `barriers`, `BARRIER_SHOTS`, `take_cover`, `unit["cover"]` | Neutral cover: an unowned wall standing on the ground, one per barrier-carrying scatter prop of that battle type, shared first-come by both sides, destroyed rather than disabled when its budget empties (ADR-0010). Not in the 掩護鏈 and not a 工事. | scatter (that is the whole art class, most of which carries no barrier), obstacle, terrain |
| **absorption budget** | `shots` (on a fort and on a barrier), `shots_left` (on the event) | How many ranged shots this cover can still eat. Rolled per wall / per barrier on the `battle` track, re-rolled when an engineer repairs a wall. | hp, health (a fort and a barrier both have none — 工事讀作建物) |
| 防空飛彈 battery | `anti_air`, `_fire_anti_air` | The air-defence fort: destroys an aircraft on hit (ADR-0006). | flak, AA, SAM |
| **power** | `RivalState.power`, `Rivals.player_power` | A civilization's strength scalar, and the only rival state there is. 正規軍 converts it into units when a battle starts. | 攻 / `attack`, a card stat with no relation to it |
| 正規軍 regular army | `regular`, `regular_unit`, `regular_roster_desc`, `regular_screens` | A civilization's power converted into on-field units at baseline stats. Per battle. | rival deck (there is none; the scalar is the only rival state) |
| 非正規軍 irregulars | `irregular`, `_irregular_unit`, `grade` | The anonymous 弱/中/硬 tiers and thematic monsters: the 5 non-civ battle types. | mob, trash, tier |
| **timeline** | `last_timeline` | The complete tick-stamped event list core emits per round. The view replays it and decides nothing. | log, history |
| **timeline fixture** | `docs/fixtures/battle_timeline.json` | One exported battle per era: the replayers' input and Part A's staleness gate. | sample, dump |
| **replayer** | none | Anything that turns a timeline back into motion and decides nothing: `view/`'s battle scene and the HTML page. | simulator (a replayer holds no rule code) |
| **label** | `_unit_label` | What a timeline entry calls a unit: its `card_id`, or its anonymous `grade`. Says *what kind of thing* it is, and so which sprite to draw. **Not an identity** — see `uid`. | id, name, identity |
| **uid** | `uid`, `_assign_uids`, `next_uid` | Which particular unit or fort a label means: an int unique within the battle, handed out in arrival order and never reassigned. `0` names no entity. | index (it is not a position in any array), instance (that is `Cards.CardInstance`) |
| **side** | `side` | On a timeline entry, the side of the party its actor field names. | `faction`, which also exists on `death` but means the *victim's* side |

**Retired — never reintroduce:** 手牌 (hand), 部隊位 (slots; replaced by assignable 勳章),
同時結算 (simultaneous resolution; units act on their own attack speed),
`blocks_melee_once` (a 盾陣 absorbing *any* melee attack; the flag is `screens_ranged_row`),
**a 盾陣 stopping melee at all** (ADR-0010 inverted it: cover stops bullets, not people, so 近戰
walks around a wall and engages the row behind it), **一擊即失效 on a wall** (an emptied budget is
what disables one now), **decoration-only field scatter** (a barrier-carrying prop is neutral cover
and rules read it).
If a doc, comment, or test implies any of these exists, it is stale; fix it. See ADR-0001/0003/0008/0010.
The 掩護鏈 is **not** a revival of 部隊位: slots were a bounded set of play positions the player
filled, the chain is an ordering the engine derives from each unit's row.

#### Timeline event contract

`battle.last_timeline` is an `Array[Dictionary]`, one entry per event, tick-ordered within the round.
Every entry carries `tick: int`, `type: StringName` and `side: StringName`; the rest is per-type.
**This table is the contract, not documentation of it.** Two independent replayers consume it
(`view/`'s battle scene and the HTML timeline replayer), so a rename here breaks both: W14.5 already
renamed `absorb` → `intercept` and `demolish` → `disable` once.

`side` is the side (`&"player"` / `&"enemy"`) of the party the entry's **actor field** names — `by`,
or `unit` where there is no `by`. Every attack in the game is cross-side, so the other party in the
same entry is on the opposite side, and a fort named by `card_id` belongs to the side being attacked.
W14.7 added it: labels are card ids, so both camps' 步兵團 answer to one label and no replayer could
attribute a strike to a camp without it.

**Identity travels with every label.** For each payload key that names a unit or a fort, the entry
also carries `<key>_uid`: `by_uid`, `target_uid`, `victim_uid`, `attacker_uid`, `unit_uid`,
`card_id_uid`, `screened_by_uid`. That rule has **no exceptions**, so a replayer derives the identity
key from the label key rather than memorising a table, and `0` means the key names no entity at all
(`by: &"skill"`, an unscreened row). Barriers are deliberately left out: a battle fields at most one
instance per scatter prop, so `barrier` is already a handle.

| `type` | Payload keys (plus each one's `_uid`) | Meaning |
|---|---|---|
| `hit` | `by`, `target`, `damage` | An attack landed. `damage` already includes the 軍歌 +1. |
| `miss` | `by`, `target` | Accuracy roll failed. A miss accrues no 閃避率 XP: the attack never reached the unit. |
| `dodge` | `by`, `attacker` | Dodge roll succeeded. **`by` is the unit that dodged**, not the attacker (the only entry where `by` is the defender, so `side` is the dodger's). |
| `death` | `victim`, `by`, `faction` | HP reached 0. `by` is the clearer's label, `&"skill"` for a 技能卡 kill (`by_uid: 0`), or a fort's `card_id` for a shootdown; `side` is the clearer's, so the victim is on the other one. `faction` is the victim's, for 戰功 attribution. |
| `intercept` | `by`, `card_id`, `barrier`, `shots_left` | Cover absorbed one **ranged** attack aimed at the unit behind it (ADR-0010; a 盾陣 covers the whole 遠程列, a 中立掩體 covers its own occupant in any row). Exactly one of `card_id` (the wall's card id) and `barrier` (the neutral barrier's prop id) is set, the other `&""`. `shots_left` is what remains of that cover's budget: at `0` a wall is now disabled and a barrier is destroyed. No accuracy or dodge roll happens — 無視攻擊力 means the shot never resolved. |
| `disable` | `by`, `card_id` | A 帶攻城／空襲 attacker disabled an **active** fort. No roll; the fort is never removed. |
| `shootdown` | `by`, `target` | A 防空飛彈 destroyed an aircraft. `by` is the fort's `card_id` and `side` is the fort's. Always followed by a `death` at the same tick. |
| `repair` | `card_id` | 工兵團 restored one disabled fort. Always `tick: 0` (repair opens the window, ahead of the strikes that suppress it). |
| `medal` | `unit`, `stat`, `level` | A stat's XP filled and the 勳章 landed 當場 at this tick. `level` is the new level. **XP accrual itself emits nothing** — only the medal is visible. |
| `take_station` | `unit`, `row`, `screened_by` | A unit took its place in the 掩護鏈, at `tick: 0` of the round it joins the field. `screened_by` is the `card_id` of the fort covering it, or `&""` when nothing does (only the 遠程列 is ever screened). Re-emitted for that row whenever its cover changes: a `repair` restores a wall, a deploy adds one, an emptied budget strips one. |
| `take_cover` | `unit`, `barrier`, `tier` | A hurt land unit fell back behind a 中立掩體, or lost the one it had (ADR-0010). `barrier` is the barrier's prop id and `tier` its weak/medium/hard grade; **both are `&""` when the unit is now covered by nothing**, which is how a destroyed barrier's occupant is announced — the same convention `take_station` uses for an unscreened row. Fires at the tick of the hit that hurt the unit, or at `tick: 0` when a later chance frees a barrier up. |
| `barrier_destroyed` | `by`, `barrier` | The shot that emptied a 中立掩體's budget destroyed it: no engineer, no repair, gone for the rest of the battle. Always preceded by the `intercept` that spent the last shot, at the same tick, and followed by a `take_cover` releasing whoever was behind it. |

**What is state and not an event:** the roster of things on the field — units, forts, and
`battle.barriers` — is read from the BattleField, exactly as the two replayers already read `units`
and `forts`. Every unit and fort on it carries the same `uid` its events use. The timeline only says
what *happens* to them. A barrier is named by its scatter prop id (`scat_<type>_<prop>`), which is a
genuine handle because a battle fields at most one instance per prop; where the props stand is the
view's business, seeded from the battle's own seed (ADR-0010).

**Label vs identity — draw with one, key with the other.** A label (`by` / `target` / `victim` /
`unit` / `card_id`) comes from `_unit_label`: a unit's `card_id`, or its anonymous `grade` for
irregulars. It says *what kind of thing this is*, which is how a replayer picks the sprite, and it
repeats — two 步兵團 on the same side share one, and so do two 盾陣. The `uid` beside it says *which
one*, and is what a replayer keys its per-unit state off. A defector keeps its `uid` across the side
change, because 勸降 moves the same regiment rather than trading one unit for another.

`uid`s are handed out by `Battle._assign_uids` in one fixed sweep over the field (player units, enemy
units, player forts, enemy forts, each in arrival order) at `start`, at the end of every `deploy`, and
at the top of every `end_round` — so the same seed hands out the same numbers, and a unit injected
straight into a BattleField by a test is identified at the next boundary like any other.

## Canonical IDs (StringName; use these exactly — never invent variants)

**Regions (5):** `livelihood` 民生 · `academic` 學術 · `military` 軍事 · `culture` 文化 · `finance` 金融

**Building lines (12):** `housing` 住宅 · `food` 食物 · `medical` 醫療 (livelihood) ·
`school` 學堂 · `astronomy` 天文 (academic) · `barracks` 兵營 · `arsenal` 兵工 (military) ·
`arts` 藝術 · `media` 傳播 (culture) · `commerce` 商業 · `bank` 銀行 · `debt_office` 國債司 (finance)

**Policy nodes (24):** `centralization` 中央集權 · `bureaucracy` 官僚體系 · `secret_police` 秘密警察 ·
`cultural_revolution` 文化大革命 · `enlightened_absolutism` 開明專制 · `writing_calendar` 文字與曆法 ·
`secularization` 推行世俗 · `patent_system` 專利制度 · `moon_race` 登月競賽 · `space_station` 太空站 ·
`ancestor_worship` 祖靈崇拜 · `state_religion` 建立國教 · `theocracy` 政教合一 · `holy_war` 聖戰 ·
`hundred_schools` 百家爭鳴 · `mass_media` 大眾媒體 · `cultural_export` 文化輸出 · `great_voyage` 大航海 ·
`world_map` 世界地圖 · `world_expo` 萬國博覽會 · `scout_camp` 斥候營 · `political_marriage` 政治聯姻 ·
`intelligence_agency` 情報單位 · `satellite_surveillance` 衛星監控

**Legacies (7):** `religious_dogma` 宗教教條 · `rational_spirit` 理性精神 · `critical_spirit` 批判精神 ·
`rock_spirit` 搖滾精神 · `democratic_spirit` 民主精神 · `melting_pot` 文化大熔爐 · `martial_law` 戒嚴

**Rival classes (5):** `science_state` 科學邦 · `culture_state` 文化國 · `iron_tribe` 鐵血部 ·
`vast_state` 廣土邦 · `slow_burner` 慢熱國

Policy effects are queried by direct membership test (`state.policies.has(&"bureaucracy")`) from any
module — the Policy module owns tree structure/progression, not effect lookups.

## Test conventions

- One suite per module, `class_name XTest extends GdUnitTestSuite`, file `test/x_test.gd`.
- Keep suites small and focused; gdUnit4 aborts a suite after its first failure — prefer many small
  test funcs over one mega-func.
- Determinism tests: same seed twice ⇒ identical outcome.
- Fixtures: build minimal GameState by hand (`GameState.new_run(seed)` then tweak fields); never
  load scenes in core tests.
- Commands: `docs/dev-loop.md` holds the verified invocations and exit codes. The import
  warm-up there is REQUIRED after adding any `class_name`.

## Key decisions log (design gaps: `docs/decisions.md`; architectural calls: repo-root `docs/adr/`)

- **Nested Godot project** at `insignificant-game/` — the repo's only Godot project; the root is
  docs-only.
- **Content as GDScript const tables** (`core/data/`), not `.tres`/JSON — legible to agents, typed,
  zero parse layer; revisit only if modding/save-compat demands it.
- **Window 1920×1080** (matches the shipped target, `assets/pipeline/style-bible.md` §8; wired
  with the approved-art chrome) — an art decision, not a logic one; nothing in core knows the
  resolution. Approved assets resolve through `core/data/asset_paths.gd` (pure id→path registry
  + frozen-template geometry); the view loads textures, core never does.
- **Mutate-in-place + report objects** over immutable state copies: the state is large; full-run
  simulations (50 generations × invariants) need cheap turns.
