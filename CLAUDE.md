# CLAUDE.md — agent operating pins for this project

Godot **4.6** / **GDScript** (never C#) / **2D** roguelike deckbuilder. The PoC's
product is a *proven self-correction loop*, not game content. Specs live in
`doc/agent-development-loop.md` (prescriptive single source of truth) and
`doc/poc-implementation-guide.md` (gates + guardrails). Durable state:
`PLAN.md`, `STRUCTURE.md`, `MEMORY.md`. Setup recipe: `agent-process.md`.

## Game-design corpus (Obsidian — *what* we'd build, separate from *this PoC loop*)
The game design lives in an Obsidian corpus at
`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian/game-design/` (**the current
planning home since 2026-07-04**; game title: **Insignificant**). That corpus is the **design**;
this repo is the **buildable loop**. Don't duplicate game-design detail into this file — link to it.
- Entry point: `Insignificant.md` — the concept/pitch main page (concept statement, USP, core
  loops, systems table). Every game term wikilinks to its dedicated setting doc.
- Setting docs (one per system, big-table format, placeholder numbers as knobs): `時代與回合`,
  `營運` (BP/regions/building lines/escalating build cost — no maintenance fee), `國策`, `Legacy`,
  `經濟與債務` (single money pool, debt = negative treasury), `幸福`, `內亂與失敗` (fail chain →
  政權崩潰 at pop<5, the only game over), `戰鬥` (3-lane battlefield), `卡牌`, `地圖與機會`,
  `對手文明` (5 fixed power-curve automa), `世界大戰` (rounds 15/35; reparations
  `max(正國庫×50%, power×2)`, can go negative), `民主` (candidate truth table), `結局`
  (survive to round 50 = win; ranking gives narrative epilogue only, never a loss).
- **Unresolved points are marked inline as `>` quote blocks** inside each doc — that's the open-
  question mechanism now (no separate questions doc yet in the new folder).
- The old corpus `.../obsidian/game ideas/agent plans/` is **archived** (7 Q&A rounds, decision
  history in its `archive/`; `constitution.md` there still holds the timeless invariants and the
  design-iteration method). Consult it for rationale/history, don't update it.

**Design-iteration loop** (how the game design advances; canonical copy in `constitution.md` §5):
`answer (human) → converge into a CONNECTED model (every system names what it feeds / is fed by) → multi-round adversarial validation (skeptics hunt "outputs without inputs" disconnects) → archive this round's questions → pose the next, deeper round`. Run each round as a dynamic workflow. The human's standing rule: questions must come from connected understanding, never surface plausibility.

## Engine + commands (verified on this Mac — see MEMORY.md)
```bash
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot   # Godot 4.6.3
export GODOT_DISABLE_LEAK_CHECKS=1                              # avoid false non-zero exit

# Part A — headless logic tests (gdUnit4). Exit 0=pass, 100=fail, 101=warn.
"$GODOT_BIN" --headless --path . --import --quit-after 2000     # import warm-up (don't gate on its exit)
./addons/gdUnit4/runtest.sh -a res://test                      # reports -> reports/report_N/

# Part B — runtime/visual capture (NOT --headless; needs the real GPU).
"$GODOT_BIN" --path .                                           # runs main scene -> capture.gd -> captures/*.png
# Judge from the PNG + grep stdout for "ASSERT FAIL".
```

## Non-negotiables (guide §2)
- GDScript, 2D, Godot 4.6 idioms: `await` not `yield`; `CharacterBody2D` not `KinematicBody2D`; **static typing** everywhere.
- **Game logic lives in pure, GUI-free functions** (`RefCounted` / static fns) so it's unit-testable headless.
- **Both loop parts before "done":** headless tests can pass while a GPU run fails. Always run Part B.
- Don't hand-corrupt `.tscn` `uid://` identity; don't reopen locked decisions (engine/language/dimensionality).
- Humans own fun/balance — surface design questions, don't decide them.

## Loop
edit → Part A (gdUnit4) → Part B (capture PNG + ASSERT) → human (feel/balance). After each green gate, update `STRUCTURE.md`/`MEMORY.md` and commit.

## Reference implementation — `../Slay-The-Robot/` (read it, don't restate it)
A sibling clone (`../Slay-The-Robot/`, MIT, **same stack: Godot 4.6 / GDScript / 2D**) is a mature, complete StS-clone *framework*. Treat it as a **worked reference design to consult when planning or implementing a subsystem** — open the actual source, don't paraphrase its design back into this file. It answers "how would a finished version model this?", not "what should we build." Where to look:
- **Map + fog:** `scripts/actions/world_generation_actions/ActionGenerateAct.gd` (floors×locations DAG, seeded RNG, floor adjacency, per-floor type assignment) · `data/mutable/LocationData.gd` (node model; **fog = `location_obfuscated` hides type until `location_visited`**) · `scenes/ui/MapLocation.tscn` (view) · `scripts/actions/world_interaction_actions/ActionVisitLocation.gd` (traversal).
- **Cards / decks / content:** `data/prototype/CardData.gd` (data-driven card model from JSON) · `data/readonly/CardPackData.gd` (content packs).
- **Deterministic RNG:** `autoload/Random.gd` (seeded "tracks" per system).
- **Effect pipeline (architecture idea):** `scripts/actions/**`, `scripts/action_interceptors/**`, `scripts/validators/**` — one logic path shared by gameplay and UI previews. `README.md` is the feature-level tour.
- **Save / mod:** `SerializableData` + `autoload/FileLoader.gd`.

**Reference only — never lift code.** It has **no automated tests** and its logic is coupled to ~13 autoload singletons (`Global`, `Signals`, `ActionHandler`, `HandManager`…). Copying it imports that coupling and breaks our non-negotiable (pure, GUI-free, headless-testable). So: borrow the **design + data shapes**, re-express them as pure `RefCounted`/static fns under our two-part loop. (Cosmetic: it renders `gl_compatibility` @1200×700 vs our Forward+/Metal @640×360 — don't expect pixel-identical behavior.)
