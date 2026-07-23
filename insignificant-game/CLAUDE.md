# CLAUDE.md — insignificant-game (the production game "Insignificant")

Godot **4.6** / **GDScript** (never C#) / **2D**. A civilization-management × StS-style
deckbuilder: 50 generations, survive to the end = win, pop<5 = the only game over. This is the
**production codebase** (grown directly from the full-game PoC, not a rewrite): every system
implemented as pure logic under a two-part verification loop; the v1 baseline numbers are
calibrated by simulation and playtesting. This directory is the repo's ONLY Godot project (the
root is docs-only) — always `cd` here before running anything.

## Read in this order (don't code before 1–2)

1. `doc/architecture.md` — **the contract.** Layering rules, module map, GameState schema,
   canonical StringName IDs (24 policy nodes / 12 building lines / regions / legacies / rival
   classes), 中→EN glossary, cross-module API pins, test conventions. Everything below is a
   summary of it or an exception to nothing in it.
2. `doc/dev-loop.md` — verified Part A / Part B / balance-batch commands + the 7 pitfalls
   that actually bit (cwd trap, exit-105 class_name cache, determinism rules…).
3. `design/` — the 15 game-rule docs (single source of truth; see "Design authority" below). The
   system you're touching, plus anything it feeds (each doc's intro lists 被誰餵/餵給誰).
4. `doc/PLAN.md` — task board & wave history; the recovery point after any interruption.

## Design authority chain

- **Upstream truth** = `design/` in this repo. It's git-tracked and edited directly — no external
  corpus to re-sync from, no re-copy step.
- Design status is 定稿: structure/rules/links locked; **numbers are v1 baseline knobs** —
  calibration changes values, never structure. Fun/balance calls belong to the PM: measure with
  the sim, surface findings (`doc/balance-report.md`), don't decide.
- **Doc ↔ code metadata:** every design doc's frontmatter has a `code:` list naming its module /
  data table / test suite; every module's header comment cites its `design/*.md`. When you move
  or add files, update BOTH directions in the same change.
- Where the design is silent, decide conservatively and log it — one row/file under
  `doc/decision-*.md` (see `decision-starting-values.md`, `decision-w2-gaps.md`,
  `decision-w3-w5-gaps.md` for the format and everything already decided). Never invent mechanics.

## Non-negotiables

- **Pure core.** `core/` is `class_name X extends RefCounted` + static funcs taking
  `state: GameState` first — no nodes, signals, autoloads, `_ready`, `Input`, rendering. If a
  rule can't be tested headless, refactor until it can. The view computes nothing.
- **Determinism.** All randomness via `state.rng` named tracks; costs via `Era.coeff()`. Same
  seed ⇒ identical run — `test/sim_test.gd` enforces this; `Date.now`-style entropy is a bug.
- **Static typing everywhere**; Godot 4.6 idioms (`await`, typed arrays, `&"StringName"` ids —
  only the canonical IDs from architecture.md, never invented variants).
- **Content is data.** Rules read `core/data/*.gd` const tables; logic never hardcodes content.
- **Both loop parts before "done".** Part A (gdUnit4, exit 0, all suites executed) AND Part B
  (INSIG_DEMO capture: PNGs reviewed against the defect taxonomy, zero ASSERT FAIL). Headless
  green alone has already missed real defects here.
- **Module boundaries = file boundaries.** Touching module X means `core/x.gd`,
  `core/data/x_*.gd`, `test/x_test.gd`. Missing GameState fields: extend `game_state.gd` (driver
  file) with a comment — don't fork state into your module.
- Don't hand-corrupt `.tscn` (`view/main.gd` builds all UI programmatically — keep it that way);
  don't reopen locked decisions (engine/language/2D, corpus structure).

## Working loop

edit → Part A → (view touched? Part B) → update `doc/PLAN.md` + relevant decision doc →
commit with a gate-stating message (`git log --oneline` shows the house style: what went green,
counts, exit code). Stage specific paths — the repo root's `doc/prompts.md` churns every turn.
Numbers changed? Run the balance batch and diff against `doc/balance-report.md`.

## Map

| Where | What |
|---|---|
| `core/` (19 modules) + `core/data/` (7 tables) | all game logic; module↔doc map in architecture.md |
| `test/` (21 suites, 199 cases green) | one suite per module; sim_test = full-run invariants |
| `view/main.gd` | phase-panel UI (runtime-composed approved-art chrome, 1920×1080) + embedded Part B demo/capture mode |
| `tools/balance_batch.gd` | 60-run telemetry → `reports/balance_batch.json` |
| `doc/difficulty-design.md` | difficulty formula + rationale (folded into `design/`) |
| `doc/` | contract, dev loop, task board, decision log, balance report |
| root `doc/agent-development-loop.md` | the generic two-part-loop doctrine this project rides on |
