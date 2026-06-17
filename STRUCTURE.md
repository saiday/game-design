# STRUCTURE.md — architecture + leaf-first build order

## Current files (M0–M2)
```
project.godot              # Godot 4.6 project; main_scene = res://game/main.tscn; 640x360
addons/gdUnit4/            # test framework v6.1.3 (runtest.sh CLI runner)
game/game_state.gd         # M1 GameState (RefCounted): energy, gold, duplicate(). Pure leaf.
game/card.gd               # M1 Card (RefCounted): cost, reward. Pure data, no view.
game/rules.gd              # M1 Rules.play_card(state, card) -> GameState. Pure, static.
game/hex_tile.gd           # M2 HexTile (Polygon2D) + pure static regular_hexagon(radius)
game/main.gd               # M2 scene composition (bg+hex+card+HUD bound to GameState) + Part-B capture/ASSERT
test/example_test.gd       # M0 trivial Part-A proof (GdUnitTestSuite)
test/rules_test.gd         # M1 Part-A gate: play_card math + input-purity (2 cases)
test/hex_tile_test.gd      # M2 Part-A: hexagon geometry (6 vertices, on radius)
game/main.tscn             # scene: Node2D "Main" -> game/main.gd  (M2 retargeted from tools/capture.gd)
tools/capture.gd           # M0 Part-B smoke baseline (now unreferenced; kept as the proven capture pattern)
captures/                  # runtime screenshots (gitignored); m0_smoke.png, m2_slice.png
reports/                   # gdUnit4 CLI reports (gitignored)
doc/                       # the two specs + art guide + prompts
```
Note: the card "view" (ColorRect+Label) is built inline in `main.gd` for the one-card slice
rather than a separate `card_view.gd` — data (`Card`/`GameState`) stays pure; view stays in `main.gd`.

## Signals / input actions
None yet (M0 capture is autostart via `_ready`, no input).

## Build order — leaf-first (logic before view)
1. ✅ `game/game_state.gd` — `class_name GameState extends RefCounted` (`energy:int`, `gold:int`, `duplicate()`). Leaf, pure.
2. ✅ `game/card.gd` — `class_name Card extends RefCounted` (`cost:int`, `reward:int`). Pure data.
3. ✅ `game/rules.gd` — `class_name Rules`; `static func play_card(state, card) -> GameState`. Pure, depends on (1)(2).
4. ✅ `test/rules_test.gd` — gdUnit4 suite over (3). **← M1 gate (exit 0, report_6).**
5. ✅ `game/hex_tile.gd` (`HexTile extends Polygon2D` + tested `regular_hexagon`); card view built inline in `main.gd`.
6. ✅ `game/main.tscn` retargeted to `game/main.gd`, which composes the scene bound to a `GameState`.
7. ✅ `game/main.gd` ASSERTs card rect ⊂ viewport + card/hex pixel classification. **← M2 gate (PNG `m2_slice.png`, ASSERT PASS).**

Rule: build children before parents; logic (1–4) before view (5–7).

## Next (M3 = DoD)
Inject a logic bug (`play_card` wrong math → Part A exit 100) and a visual bug (card off-screen /
behind tile → Part B `ASSERT FAIL`); confirm each layer catches its bug; fix both → all green + clean PNG.
