# CLAUDE.md — agent operating pins for this project

Godot **4.6** / **GDScript** (never C#) / **2D** roguelike deckbuilder. The PoC's
product is a *proven self-correction loop*, not game content. Specs live in
`doc/agent-development-loop.md` (prescriptive single source of truth) and
`doc/poc-implementation-guide.md` (gates + guardrails). Durable state:
`PLAN.md`, `STRUCTURE.md`, `MEMORY.md`. Setup recipe: `agent-process.md`.

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
