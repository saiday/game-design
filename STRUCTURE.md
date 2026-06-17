# STRUCTURE.md — architecture + leaf-first build order

## Current files (M0–M1)
```
project.godot              # Godot 4.6 project; main_scene = res://game/main.tscn; 640x360
addons/gdUnit4/            # test framework v6.1.3 (runtest.sh CLI runner)
game/game_state.gd         # M1 GameState (RefCounted): energy, gold, duplicate(). Pure leaf.
game/card.gd               # M1 Card (RefCounted): cost, reward. Pure data, no view.
game/rules.gd              # M1 Rules.play_card(state, card) -> GameState. Pure, static.
test/example_test.gd       # M0 trivial Part-A proof (GdUnitTestSuite)
test/rules_test.gd         # M1 Part-A gate: play_card math + input-purity (2 cases)
game/main.tscn             # M0 scene: Node2D "Main" + capture.gd
tools/capture.gd           # embedded Part-B capture helper (render → PNG → ASSERT → quit)
captures/                  # runtime screenshots (gitignored); baseline: m0_smoke.png
reports/                   # gdUnit4 CLI reports (gitignored)
doc/                       # the two specs + art guide + prompts
```

## Signals / input actions
None yet (M0 capture is autostart via `_ready`, no input).

## Build order — leaf-first (logic before view)
1. ✅ `game/game_state.gd` — `class_name GameState extends RefCounted` (`energy:int`, `gold:int`, `duplicate()`). Leaf, pure.
2. ✅ `game/card.gd` — `class_name Card extends RefCounted` (`cost:int`, `reward:int`). Pure data.
3. ✅ `game/rules.gd` — `class_name Rules`; `static func play_card(state, card) -> GameState`. Pure, depends on (1)(2).
4. ✅ `test/rules_test.gd` — gdUnit4 suite over (3). **← M1 gate (exit 0, report_6).**
5. ⬜ `game/card_view.gd` (+ node) + `game/hex_tile.gd` (`Polygon2D`) — leaf view nodes reading a `Card`/`GameState`. (View kept separate from data class to honor logic/GUI split.)
6. ⬜ `game/main.tscn` rework — composes (5), binds to a `GameState`, camera pre-positioned.
7. ⬜ `tools/capture.gd` — add `ASSERT` on card's on-screen rect ⊂ viewport. **← M2 gate here.**

Rule: build children before parents; logic (1–4) before view (5–7).
