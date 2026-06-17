# STRUCTURE.md — architecture + leaf-first build order

## Current files (M0)
```
project.godot              # Godot 4.6 project; main_scene = res://game/main.tscn; 640x360
addons/gdUnit4/            # test framework v6.1.3 (runtest.sh CLI runner)
test/example_test.gd       # M0 trivial Part-A proof (GdUnitTestSuite)
game/main.tscn             # M0 scene: Node2D "Main" + capture.gd
tools/capture.gd           # embedded Part-B capture helper (render → PNG → ASSERT → quit)
captures/                  # runtime screenshots (gitignored); baseline: m0_smoke.png
reports/                   # gdUnit4 CLI reports (gitignored)
doc/                       # the two specs + art guide + prompts
```

## Signals / input actions
None yet (M0 capture is autostart via `_ready`, no input).

## Planned (M1–M2) — leaf-first build order
1. `game/game_state.gd` — `class_name GameState extends RefCounted` (`energy:int`, `gold:int`, `duplicate()`). Leaf, pure.
2. `game/rules.gd` — `class_name Rules`; `static func play_card(state, card) -> GameState`. Pure, depends only on (1).
3. `test/rules_test.gd` — gdUnit4 suite over (2). Depends on (1)(2). **← M1 gate here.**
4. `game/card.gd` + node, `game/hex_tile.gd` (`Polygon2D`) — leaf view nodes.
5. `game/main.tscn` rework — composes (4), binds to a `GameState`, camera pre-positioned.
6. `tools/capture.gd` — add `ASSERT` on card's on-screen rect ⊂ viewport. **← M2 gate here.**

Rule: build children before parents; logic nodes (1–3) before view nodes (4–6).
