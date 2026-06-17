# PLAN.md — PoC task list + verification gates + status

> Existence of this file = **resume, skip scaffold** (companion §6b).
> Goal (DoD): on a deliberately broken change, a LOGIC bug is caught at the test
> layer AND a VISUAL bug at the screenshot layer, both fixed, slice ends green +
> visually correct. Demonstrate once = success.

## Status board
| Milestone | Gate (objective) | Status |
|---|---|---|
| **M0** Environment proven | trivial gdUnit4 test exits 0 & ran ≥1 test; capture writes non-blank PNG | ✅ DONE |
| **M1** Logic backbone | pure `play_card` rule + gdUnit4 test exits 0, report artifact | ⬜ pending (awaiting PM OK to pass M0) |
| **M2** Visual slice | scene draws 1 card + 1 hex tile; capture PNG taxonomy-clean, `ASSERT PASS`, no errors | ⬜ pending |
| **M3** Closed-loop proof (= DoD) | logic bug → exit 100; visual bug → `ASSERT FAIL`/screenshot; both fixed → exit 0 + clean PNG | ⬜ pending |
| **M4** Capture learnings | fold confirmed commands/timings/decisions into `doc/agent-development-loop.md` + Changelog | ⬜ pending (M0 findings parked in MEMORY.md/agent-process.md) |

## M0 — DONE (evidence)
- Godot **4.6.3.stable.official** via `brew install --cask godot`.
- gdUnit4 **v6.1.3** addon installed; `runtest.sh -a res://test` → **exit 0**, 2/2 tests, `reports/report_1/results.xml`.
- `capture.gd` → `captures/m0_smoke.png` (640×360, non-blank, ASSERT PASS) under real Metal/Forward+ GPU. **Baseline screenshot:** `captures/m0_smoke.png`.

## M1–M3 — the smallest slice (design, not yet built)
- **Rule (M1, pure/Part A):** `Rules.play_card(state, card) -> GameState`. `GameState` = `RefCounted` with `energy:int`, `gold:int`. Card costs energy, grants gold. Static, GUI-free; unit-tested with gdUnit4 (assert exact post-state).
- **Scene (M2, Part B):** one card (ColorRect+Label, no art pipeline) + one hex tile (`Polygon2D`) reflecting `GameState`. `capture.gd` adds an `ASSERT` on the card's on-screen rect ⊂ viewport.
- **Deliberate bugs (M3 = DoD):**
  - *Logic:* wrong resource math in `play_card` (e.g. energy not decremented). Caught by gdUnit4 (**exit 100**); scene still renders → visual layer stays clean. Proves logic⇒test layer.
  - *Visual:* card moved off-screen / behind the tile (logic untouched). Tests stay green; capture `ASSERT FAIL` + visible defect. Proves render⇒visual layer.
  - Fix both → exit 0 + taxonomy-clean PNG. Loop closed once.

## Decisions made (§3) — reversible, recorded
gdUnit4 (doc rec) · pure `RefCounted`+static fns (no `.tres`/JSON for one rule) · capture-script only, **no MCP server** (defer per §5) · layout `game/ test/ tools/ addons/ reports/ captures/`.

## Next action
**Awaiting PM OK** to execute past M0 (build M1). Stop point per kickoff instruction.
