# CLAUDE.md — agent operating pins for this repo

Godot **4.6** / **GDScript** (never C#) / **2D** roguelike deckbuilder (**Insignificant**).
The repo root is **documentation only**; all code lives in one place:

- **`insignificant-game/` — the full-game PoC and the only Godot project.** Working on the game?
  **Read `insignificant-game/CLAUDE.md` and cd there** — it has the contract
  (`poc-docs/architecture.md`), the verified dev-loop commands (`poc-docs/dev-loop.md`), and the
  task board. Never run engine/test commands from the repo root; there is no project here.
- **`doc/`** — project history and doctrine: `agent-development-loop.md` (the two-part
  self-correction loop, proven by the original repo-root loop PoC, closed 2026-06-17),
  `poc-implementation-guidelines.md` (merged guide: Part 1 = full-game PoC contract, fulfilled
  2026-07-08; Part 2 = the archived loop-PoC guide), `prompts.md` (live prompt log),
  `image-assets-generation-orchestrator-cookbook.md` (art pipeline on the Mac Studio — the agent
  cookbook; absorbed the exploratory art-pipeline-poc-guide, which was removed 2026-07-08) with
  `mac-studio-handoff.md` (paste-ready bootstrap prompts for the Studio sessions),
  `doc/loop-poc-archive/` (the loop PoC's PLAN/STRUCTURE/MEMORY/process snapshots). The loop
  PoC's code was removed 2026-07-08 — recover it via git history if ever needed.

## Game-design corpus (Obsidian — *what* we're building; the design source of truth)
The game design lives in an Obsidian corpus at
`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian/game-design/` (**the current
planning home since 2026-07-04**; game title: **Insignificant**). That corpus is the **design**;
this repo is the **build**. Don't duplicate game-design detail into this file — link to it.
- Entry point: `Insignificant.md` — the concept/pitch main page (concept statement, USP, core
  loops, systems table). Every game term wikilinks to its dedicated setting doc.
- **Doc ↔ code relation:** every setting doc's frontmatter carries a `code:` list mapping it to
  its module / data table / test suite, paths relative to this repo (e.g.
  `insignificant-game/core/economy.gd`). Keep it current when modules move. The reverse direction
  is each module's header comment citing its `design/*.md` source.
- Setting docs (one per system, big-table format, numbers are v1 baseline knobs): `時代與回合`,
  `營運` (BP/regions/building lines/escalating build cost — no maintenance fee), `國策`, `Legacy`,
  `經濟與債務` (single money pool, debt = negative treasury), `幸福`, `內亂與失敗` (fail chain →
  政權崩潰 at pop<5, the only game over), `戰鬥` (single battlefield, auto-deployment by combat attribute,
  win = clear enemy while holding land units, minimize-military-spend gamble), `卡牌`, `地圖與機會`,
  `對手文明` (5 fixed power-curve automa), `世界大戰` (rounds 15/35; reparations
  `max(正國庫×50%, power×2)`, can go negative), `民主` (candidate truth table), `結局`
  (survive to round 50 = win; ranking gives narrative epilogue only, never a loss).
- **The corpus is 定稿 / development-ready (2026-07-07)**: all history annotations and open-question
  quote blocks were resolved and removed. The only remaining `>` blocks are each doc's intro summary
  (keep that format). Structure/rules/links are locked; numeric values are v1 baselines calibrated by
  playtesting — calibration changes values, never structure. New open questions go back in as `>`
  quote blocks when a future design round reopens something.
- The old corpus `.../obsidian/game ideas/agent plans/` is **archived** (7 Q&A rounds, decision
  history in its `archive/`; `constitution.md` there still holds the timeless invariants and the
  design-iteration method). Consult it for rationale/history, don't update it.

**Design-iteration loop** (how the game design advances; canonical copy in `constitution.md` §5):
`answer (human) → converge into a CONNECTED model (every system names what it feeds / is fed by) → multi-round adversarial validation (skeptics hunt "outputs without inputs" disconnects) → archive this round's questions → pose the next, deeper round`. Run each round as a dynamic workflow. The human's standing rule: questions must come from connected understanding, never surface plausibility.

## Non-negotiables (full versions in `insignificant-game/CLAUDE.md`)
- GDScript, 2D, Godot 4.6 idioms: `await` not `yield`; `CharacterBody2D` not `KinematicBody2D`; **static typing** everywhere.
- **Game logic lives in pure, GUI-free functions** (`RefCounted` / static fns) so it's unit-testable headless.
- **Both loop parts before "done":** headless tests can pass while a GPU run fails. Always run Part B.
- Don't hand-corrupt `.tscn` `uid://` identity; don't reopen locked decisions (engine/language/dimensionality).
- Humans own fun/balance — surface design questions, don't decide them.

## Reference implementation — `../Slay-The-Robot/` (read it, don't restate it)
A sibling clone (`../Slay-The-Robot/`, MIT, **same stack: Godot 4.6 / GDScript / 2D**) is a mature, complete StS-clone *framework*. Treat it as a **worked reference design to consult when planning or implementing a subsystem** — open the actual source, don't paraphrase its design back into this file. It answers "how would a finished version model this?", not "what should we build." Where to look:
- **Map + fog:** `scripts/actions/world_generation_actions/ActionGenerateAct.gd` (floors×locations DAG, seeded RNG, floor adjacency, per-floor type assignment) · `data/mutable/LocationData.gd` (node model; **fog = `location_obfuscated` hides type until `location_visited`**) · `scenes/ui/MapLocation.tscn` (view) · `scripts/actions/world_interaction_actions/ActionVisitLocation.gd` (traversal).
- **Cards / decks / content:** `data/prototype/CardData.gd` (data-driven card model from JSON) · `data/readonly/CardPackData.gd` (content packs).
- **Deterministic RNG:** `autoload/Random.gd` (seeded "tracks" per system).
- **Effect pipeline (architecture idea):** `scripts/actions/**`, `scripts/action_interceptors/**`, `scripts/validators/**` — one logic path shared by gameplay and UI previews. `README.md` is the feature-level tour.
- **Save / mod:** `SerializableData` + `autoload/FileLoader.gd`.

**Reference only — never lift code.** It has **no automated tests** and its logic is coupled to ~13 autoload singletons (`Global`, `Signals`, `ActionHandler`, `HandManager`…). Copying it imports that coupling and breaks our non-negotiable (pure, GUI-free, headless-testable). So: borrow the **design + data shapes**, re-express them as pure `RefCounted`/static fns under our two-part loop. (Cosmetic: it renders `gl_compatibility` @1200×700 vs our Forward+/Metal @640×360 — don't expect pixel-identical behavior.)
