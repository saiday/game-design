# CLAUDE.md: agent operating pins for this repo

Godot **4.6** / **GDScript** (never C#) / **2D** roguelike deckbuilder (**Insignificant**).
The repo root is **documentation only**. All code and the game design live in
`insignificant-game/`, the repo's only Godot project. Working on the game? Read
`insignificant-game/CLAUDE.md` and `cd` there; never run engine/test commands from the root.

## Where to look (routing matrix)

One `docs/` tree per level: repo-root `docs/` holds cross-project doctrine, process docs, and
human dashboards; `insignificant-game/docs/` holds the build contract and working docs;
`insignificant-game/design/` holds the game rules. Route by intent:

| When working on... | Consult |
|---|---|
| Any game code (logic, data, tests, view) | `insignificant-game/CLAUDE.md`, then `insignificant-game/docs/architecture.md` (the contract) and `insignificant-game/docs/dev-loop.md` (verified commands + pitfalls) |
| Game rules, mechanics, or numbers | `insignificant-game/design/` (single source of truth; entry point `Insignificant.md`, one doc per system) |
| Resuming interrupted build work | `insignificant-game/docs/PLAN.md` (task board) + `git log` |
| Battle-model rewrite (waves W11 to W15) | `insignificant-game/docs/plan-battle-model-rewrite.md` (locked design D1 to D16) + `docs/adr/` 0001 to 0005 |
| A gap the design doesn't pin | `insignificant-game/docs/decisions.md`: decide conservatively, log it there |
| Balance or difficulty measurement | `insignificant-game/docs/balance-report.md` and `insignificant-game/docs/difficulty-design.md` |
| Understanding the two-part dev loop (why, limits) | `docs/agent-development-loop.md` (doctrine; the per-project commands live in `insignificant-game/docs/dev-loop.md`) |
| Art asset generation (Mac Studio sessions) | `docs/image-assets-generation-orchestrator-cookbook.md` (the contract) + `docs/mac-studio-handoff.md` (session ignition prompts) |
| Art style, asset inventory, art review | `insignificant-game/assets/pipeline/style-bible.md`, `inventory.md`, `review-brief-units.md` |
| Architectural decisions (reading or recording) | `docs/adr/` (sequential ADRs; convention in `docs/adr/README.md`; contradict one out loud, never silently) |
| Issues, PRDs, triage | `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md` (GitHub issues in `saiday/game-design` via `gh`) |
| Reporting progress to the human | `docs/progress-dashboard.html`: update it whenever a wave/gate closes or a test/asset count changes, and bump its footer |
| The documentation architecture itself | `docs/doc-map.html` (human-facing doc map; update it when docs move or change roles) |
| Out of scope by design (never build these) | Multiplayer/online: the game is 單機單人 (`design/Insignificant.md`). Save/load: runs are no-reload (`design/結局.md` §永久性; `GameState.to_dict()` is not a save format). |
| Planned but not started (pending, don't invent it) | Audio/music: no pipeline or tooling docs yet, only design intent (`design/Insignificant.md` §視覺與聽覺風格). Localization workflow: none yet, zh-TW only today. When a task needs either, surface it to the human to open that work. |

Human-only file agents never read: `docs/prompts.md` (prompt log; it churns every turn, so
stage specific paths when committing).

## Documentation style (human rule)

Docs describe the **current state**, written for fresh eyes to read and follow. Never store
log-style/changelog notes in them: no decision dates, no "was X / superseded / decided on
date" narratives. That history belongs in **git commit messages**. The only exceptions are
purpose-built logs (cookbook §14 findings log, `docs/prompts.md`,
`insignificant-game/docs/PLAN.md`, `insignificant-game/docs/decisions.md`) and license
sign-off / verification records, which keep their dates.

## Game-design corpus (`insignificant-game/design/`)

The 15 design docs are the game design: the single source of truth for *what* we're building.
The rest of `insignificant-game/` is the build. Every game term wikilinks to its dedicated
setting doc.

- **Status 定稿**: structure, rules, and links are locked; numeric values are v1 baseline
  knobs. Calibration changes values, never structure. Each doc's only standing `>` block is
  its intro summary; new open questions go back in as `>` quote blocks when a future design
  round reopens something.
- **Doc ↔ code metadata:** every design doc's frontmatter carries a `code:` list mapping it to
  its module / data table / test suite (paths relative to this repo); each module's header
  comment cites its `design/*.md` source. When files move, update both directions in the same
  change.
- Never duplicate design detail into this file or any other doc; link to the corpus instead.

**Design-iteration loop** (how the game design advances):
`answer (human) → converge into a CONNECTED model (every system names what it feeds / is fed
by) → multi-round adversarial validation (skeptics hunt "outputs without inputs" disconnects)
→ archive this round's questions → pose the next, deeper round`. Run each round as a dynamic
workflow. The human's standing rule: questions must come from connected understanding, never
surface plausibility.

## Non-negotiables (full versions in `insignificant-game/CLAUDE.md`)

- GDScript, 2D, Godot 4.6 idioms: `await` not `yield`; `CharacterBody2D` not
  `KinematicBody2D`; **static typing** everywhere.
- **Game logic lives in pure, GUI-free functions** (`RefCounted` / static fns) so it's
  unit-testable headless.
- **Both loop parts before "done":** headless tests can pass while a GPU run fails. Always run
  Part B.
- Don't hand-corrupt `.tscn` `uid://` identity; don't reopen locked decisions
  (engine/language/dimensionality).
- Humans own fun/balance. Surface design questions, don't decide them.

## Reference implementation: `../Slay-The-Robot/` (read it, don't restate it)

A sibling clone (`../Slay-The-Robot/`, MIT, same stack: Godot 4.6 / GDScript / 2D) is a
mature, complete StS-clone *framework*. It is not part of this repo and may be absent on a
given machine: check that the path exists before relying on it, and if it's missing, say so
instead of paraphrasing from memory. Treat it as a worked reference design to consult when
planning or implementing a subsystem: open the actual source, don't paraphrase its design back
into this file. It answers "how would a finished version model this?", not "what should we
build." Where to look:

- **Map + fog:** `scripts/actions/world_generation_actions/ActionGenerateAct.gd`
  (floors×locations DAG, seeded RNG, floor adjacency, per-floor type assignment) ·
  `data/mutable/LocationData.gd` (node model; **fog = `location_obfuscated` hides type until
  `location_visited`**) · `scenes/ui/MapLocation.tscn` (view) ·
  `scripts/actions/world_interaction_actions/ActionVisitLocation.gd` (traversal).
- **Cards / decks / content:** `data/prototype/CardData.gd` (data-driven card model from JSON)
  · `data/readonly/CardPackData.gd` (content packs).
- **Deterministic RNG:** `autoload/Random.gd` (seeded "tracks" per system).
- **Effect pipeline (architecture idea):** `scripts/actions/**`, `scripts/action_interceptors/**`,
  `scripts/validators/**`: one logic path shared by gameplay and UI previews. `README.md` is
  the feature-level tour.
- **Save / mod:** `SerializableData` + `autoload/FileLoader.gd`.

**Reference only, never lift code.** It has no automated tests and its logic is coupled to ~13
autoload singletons (`Global`, `Signals`, `ActionHandler`, `HandManager`...). Copying it
imports that coupling and breaks our non-negotiable (pure, GUI-free, headless-testable). So:
borrow the design + data shapes, re-express them as pure `RefCounted`/static fns under our
two-part loop. (Cosmetic: it renders `gl_compatibility` @1200×700 vs our Forward+/Metal; don't
expect pixel-identical behavior. Our shipped resolution is Full HD 1920×1080.)

## Agent skills

### Issue tracker

Issues and PRDs live as GitHub issues in `saiday/game-design`, via the `gh` CLI. See
`docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, each label string equal to its name. See
`docs/agents/triage-labels.md`.

### Domain docs

ADRs are in `docs/adr/`: read the ones touching your area; contradict one out loud, never
silently. Don't create a root `CONTEXT.md` (`/domain-modeling` will try): architecture.md's
glossary is the only one.
