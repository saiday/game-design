# CLAUDE.md — insignificant-game (the production game "Insignificant")

Godot **4.6** / **GDScript** (never C#) / **2D**. A civilization-management × StS-style
deckbuilder: 50 generations, survive to the end = win, pop<5 = the only game over. This is the
**production codebase** (grown directly from the full-game PoC, not a rewrite): every system
implemented as pure logic under a two-part verification loop; the v1 baseline numbers are
calibrated by simulation and playtesting. This directory is the repo's ONLY Godot project (the
root is docs-only) — always `cd` here before running anything.

## Read in this order (don't code before 1–2)

1. `docs/architecture.md` — **the contract.** Layering rules, module map, GameState schema,
   canonical StringName IDs (24 policy nodes / 12 building lines / regions / legacies / rival
   classes), 中→EN glossary, cross-module API pins, test conventions. Everything below is a
   summary of it or an exception to nothing in it.
2. `docs/dev-loop.md` — verified Part A / Part B / balance-batch commands + the 7 pitfalls
   that actually bit (cwd trap, exit-105 class_name cache, determinism rules…).
3. `design/` — the 15 game-rule docs (single source of truth; see "Design authority" below). The
   system you're touching, plus anything it feeds (each doc's intro lists 被誰餵/餵給誰).
4. `docs/PLAN.md` — task board & wave history; the recovery point after any interruption.

## Design authority chain

- **Upstream truth** = `design/` in this repo. It's git-tracked and edited directly — no external
  corpus to re-sync from, no re-copy step.
- Design status is 定稿: structure/rules/links locked; **numbers are v1 baseline knobs** —
  calibration changes values, never structure. Fun/balance calls belong to the PM: measure with
  the sim, surface findings (`docs/balance-report.md`), don't decide.
- **Doc ↔ code metadata:** every design doc's frontmatter has a `code:` list naming its module /
  data table / test suite; every module's header comment cites its `design/*.md`. When you move
  or add files, update BOTH directions in the same change — then run
  `python3 docs/tools/check_design_graph.py`, which is what actually verifies it.
- **The corpus is a graph, and it is checked.** Each system doc's frontmatter `graph:` block
  declares what feeds it, what it feeds, and which GameState fields it reads and writes — the
  machine-readable form of the prose 被誰餵/餵給誰 intro. Keep the two in sync when you touch
  either. `check_design_graph.py` (see `docs/dev-loop.md`) resolves every edge, both `code:`
  directions, every wikilink, and doc-map coverage; it is part of Part A.
- Where the design is silent, decide conservatively and log it as one row in
  `docs/decisions.md` (which holds the format plus everything already decided). Decisions with
  lasting architectural consequences also get an ADR in the repo root's `docs/adr/`. Never
  invent mechanics.

## Non-negotiables

- **Pure core.** `core/` is `class_name X extends RefCounted` + static funcs taking
  `state: GameState` first — no nodes, signals, autoloads, `_ready`, `Input`, rendering. If a
  rule can't be tested headless, refactor until it can. The view computes nothing.
- **Determinism.** All randomness via `state.rng` named tracks; costs via `Era.coeff()`. Same
  seed ⇒ identical run — `test/sim_test.gd` enforces this; `Date.now`-style entropy is a bug.
- **Static typing everywhere**; Godot 4.6 idioms (`await`, typed arrays, `&"StringName"` ids —
  only the canonical IDs from architecture.md, never invented variants).
- **Content is data.** Rules read `core/data/*.gd` const tables; logic never hardcodes content.
- **Both loop parts before "done".** Part A (gdUnit4, exit 0, all suites executed; plus
  `docs/tools/check_design_graph.py` at exit 0 when docs or headers moved) AND Part B
  (INSIG_DEMO capture: PNGs reviewed against the defect taxonomy, zero ASSERT FAIL). Headless
  green alone has already missed real defects here.
- **Module boundaries = file boundaries.** Touching module X means `core/x.gd`,
  `core/data/x_*.gd`, `test/x_test.gd`. Missing GameState fields: extend `game_state.gd` (driver
  file) with a comment — don't fork state into your module.
- **Controller support.** The shipped game must be fully playable with a gamepad, not just
  mouse/keyboard. Every interaction added to `view/` needs a controller path (input actions,
  focus navigation); never build mouse-only UI. Input handling stays in the view layer
  (`core/` remains `Input`-free per the pure-core rule).
- Don't hand-corrupt `.tscn` (`view/main.gd` builds all UI programmatically — keep it that way);
  don't reopen locked decisions (engine/language/2D, corpus structure).

## Working loop

edit → Part A → (view touched? Part B) → update `docs/PLAN.md` (+ `docs/decisions.md` if you
decided a design gap) →
commit with a gate-stating message (`git log --oneline` shows the house style: what went green,
counts, exit code). Stage specific paths — the repo root's `docs/prompts.md` churns every turn.
Numbers changed? Run the balance batch and diff against `docs/balance-report.md`.

## Map

| Where | What |
|---|---|
| `core/` (19 modules) + `core/data/` (7 tables) | all game logic; module↔doc map in architecture.md |
| `test/` (21 suites, 240 cases green) | one suite per module; sim_test = full-run invariants |
| `view/main.gd` | phase-panel UI (runtime-composed approved-art chrome, 1920×1080) + embedded Part B demo/capture mode |
| `tools/balance_batch.gd` | 60-run telemetry → `reports/balance_batch.json` |
| `tools/export_timeline.gd` | one full-roster battle per era → `docs/fixtures/battle_timeline.json`; the HTML battle replayer plays that back and holds zero rule code. Part A re-runs the exporter and fails on a diff |
| `docs/difficulty-design.md` | difficulty formula + rationale (folded into `design/`) |
| `docs/` | contract, dev loop, task board, decision log, balance report |
| root `docs/agent-development-loop.md` | the generic two-part-loop doctrine this project rides on |
