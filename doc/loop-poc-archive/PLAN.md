> **ARCHIVED: historical record of the closed repo-root loop PoC (project removed from the repo). Do not resume, execute, or update anything in this file.**

# PLAN.md — PoC task list + verification gates + status

> Existence of this file = **resume, skip scaffold** (companion §6b).
> Goal (DoD): on a deliberately broken change, a LOGIC bug is caught at the test
> layer AND a VISUAL bug at the screenshot layer, both fixed, slice ends green +
> visually correct. Demonstrate once = success.

## Status board
| Milestone | Gate (objective) | Status |
|---|---|---|
| **M0** Environment proven | trivial gdUnit4 test exits 0 & ran ≥1 test; capture writes non-blank PNG | ✅ DONE |
| **M1** Logic backbone | pure `play_card` rule + gdUnit4 test exits 0, report artifact | ✅ DONE |
| **M2** Visual slice | scene draws 1 card + 1 hex tile; capture PNG taxonomy-clean, `ASSERT PASS`, no errors | ✅ DONE |
| **M3** Closed-loop proof (= DoD) | logic bug → exit 100; visual bug → `ASSERT FAIL`/screenshot; both fixed → exit 0 + clean PNG | ✅ DONE |
| **M4** Capture learnings | fold confirmed commands/timings/decisions into `doc/agent-development-loop.md` + Changelog | ✅ DONE |

## M0 — DONE (evidence)
- Godot **4.6.3.stable.official** via `brew install --cask godot`.
- gdUnit4 **v6.1.3** addon installed; `runtest.sh -a res://test` → **exit 0**, 2/2 tests, `reports/report_1/results.xml`.
- `capture.gd` → `captures/m0_smoke.png` (640×360, non-blank, ASSERT PASS) under real Metal/Forward+ GPU. **Baseline screenshot:** `captures/m0_smoke.png`.

## M1 — DONE (evidence, built test-first)
- `game/game_state.gd` (`GameState` RefCounted: `energy`, `gold`, `duplicate()`), `game/card.gd` (`Card`: `cost`, `reward`), `game/rules.gd` (`Rules.play_card` static, pure).
- `test/rules_test.gd`: 2 cases — energy/gold math + input-purity. Built via red→green:
  - RED: test referencing missing types → exit **105** (parse error); then no-op stub → exit **100** (math assertion fails 3≠2, 0≠5).
  - Teeth check: mutate-in-place impl → only the purity test fails (exit **100**), proving it's not vacuous.
  - GREEN: pure impl → **exit 0**, 4/4 cases, artifact `reports/report_6`.

## M2 — DONE (evidence)
- `game/hex_tile.gd` (`HexTile extends Polygon2D` + pure static `regular_hexagon(radius)`), tested in `test/hex_tile_test.gd` (6 vertices, all on radius) — TDD red(105/100)→green.
- `game/main.gd` (`extends Node2D`) composes bg + `HexTile` + card (ColorRect+Label) + HUD bound to a `GameState`; HUD shows the M1 rule's effect (`Energy 3->2  Gold 0->5`). `main.tscn` repointed to it.
- Part A: **exit 0, 6/6**. Part B: `Godot --path .` → **exit 0**, `captures/m2_slice.png` (640×360), **ASSERT PASS** on 3 taxonomy-aware checks (card rect ⊂ viewport · card-center pixel = card color · hex-center pixel = hex color), visually verified taxonomy-clean.

## M3 — DONE (= Definition of Done; loop proven once)
One deliberately-broken change carried BOTH bugs; each detector fired at its own layer, independently:
- *Logic bug:* `play_card` sign flip (`energy += cost`). **Part A → exit 100**, `test_play_card_spends_energy_and_grants_gold` failed (energy expected 2, was 4). Part B still rendered (logic bug didn't block the view).
- *Visual bug:* `CARD_POS` off the right edge (x=700 > 640). **Part B → ASSERT FAIL** ("card rect … not inside viewport") + broken PNG shows the card gone; hex still drew. Part A unaffected by it.
- Fixed both → **Part A exit 0 (6/6)** + **Part B exit 0, ASSERT PASS**, `captures/m2_slice.png` visually taxonomy-clean (HUD `Energy 3->2  Gold 0->5`). **Loop closed.**
- Note: bugs were injected → caught → reverted; M3 adds no code diff — its deliverable is this proof (recorded here).

## Decisions made (§3) — reversible, recorded
gdUnit4 (doc rec) · pure `RefCounted`+static fns (no `.tres`/JSON for one rule) · capture-script only, **no MCP server** (defer per §5) · layout `game/ test/ tools/ addons/ reports/ captures/`.

## Next action
**PoC complete (M0–M4).** The self-correction loop is proven and the spec is reconciled to reality.
Recommended next (per spec §8, awaiting PM direction): expand to the first real subsystem —
card/deck data model → one hex tile + fog reveal → one room/event resolving to a card reward.
