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
5. **`tools/` — capture script for Part B.**

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
| `operations.gd` | `Operations` | BP production/carryover, region/building build+upgrade, escalating cost, declare_war/psyops actions (營運) |
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
var population: int            # start 12; <5 ⇒ regime collapse (only game over)
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

代 generation · 時代 era (tribal/classical/faith/industrial/modern/information) · 時代係數 `Era.coeff()`
· BP build points · 營運 operations · 國策 policy · 幸福 happiness · 內亂 unrest · 讓步 concession
· 戒嚴 martial law · 政權崩潰 regime collapse · 軍費 military spend · 賠償 reparations · 戰功 war_merit
· 宣戰 declare_war · 心戰 psyops · 併吞 annex · 退場 rival exit · 影響力 influence · 貴族資金 noble funds
(democracy rename of treasury, same pool) · 資本利得 capital gains · 國寶 national treasure
· 工事 fortification · 人數型/機械型/技能 personnel/mechanical/skill cards.

### Battle model terms (see `doc/plan-battle-model-rewrite.md` for the locked design)

攻 `attack` (**= power**; one concept, fixed per card type+era, never rolls) · 血 `hp` (fixed per
type+era; "how many men") · **innate three** `accuracy` / `dodge` / `speed` (rolled per card
*instance* at acquisition; "how good these particular men are") · 勳章 `medal` (a growth award,
never called a card) · 老兵 `veterancy` (軍事區's 基礎被動) · **wave** (one scheduled enemy
commitment inside a battle) · **tick** (atomic time unit inside a 回合) · **timeline** (the
complete tick-stamped event list core emits per round; the view replays it and decides nothing) ·
**exhaustion** (the defeat condition: field empty AND nothing left to commit) · 回合 `round` (a
fixed tick window; deployment, 軍費, and wave arrival all happen at its boundary).

**Retired — never reintroduce:** 手牌 (hand), 部隊位 (slots), 同時結算 (simultaneous resolution).
If a doc, comment, or test implies any of these exists, it is stale; fix it. See ADR-0001/0003.

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
- Commands (verified on this machine, run from `insignificant-game/`):
  ```bash
  export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
  export GODOT_DISABLE_LEAK_CHECKS=1
  "$GODOT_BIN" --headless --path . --import --quit-after 2000   # REQUIRED after adding any class_name
  ./addons/gdUnit4/runtest.sh -a res://test                     # exit 0 pass / 100 fail / 105 parse error
  ```

## Key decisions log (each big one also gets a standalone file in doc/)

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
