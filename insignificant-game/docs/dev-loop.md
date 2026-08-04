# Dev loop — verified commands & pitfalls (this project)

> Everything here was verified on both dev machines (Godot 4.6.3 at
> `/Applications/Godot.app` on each, Apple Silicon / Metal, gdUnit4 v6.1.3: MacBook M1 Pro,
> Mac Studio M2 Max). Generic loop rationale lives in the repo root's
> `docs/agent-development-loop.md`; this file is only what you type and what bites.

## Part A — headless logic tests (run after EVERY core/ or test/ change)

```bash
cd /Users/saiday/projects/game-design/insignificant-game   # NEVER skip — see pitfall #1
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_DISABLE_LEAK_CHECKS=1
"$GODOT_BIN" --headless --path . --import --quit-after 2000   # warm-up; REQUIRED after any new/renamed class_name
./addons/gdUnit4/runtest.sh -a res://test
```

- Exit codes: `0` pass · `100` failures · `101` warnings · `105` parse/discovery error.
- Gate on the exit code AND "Executed test suites (N/N)" — gdUnit4 exits `0` on "no tests found".
- Reports: `reports/report_N/{results.xml,index.html}`. Failure detail is in the XML.
- Benign noise: `ERROR: The remote port number must be between 1 and 65535` (runtest.sh's debugger trap).

### Timeline fixture + replayer check (run after ANY `core/battle.gd` or timeline change)

The HTML battle replayer holds no rules: it plays back a fixture exported from the real engine. So
a rule change that moves the timeline must move the fixture, and staleness is caught by re-running
the exporter and diffing rather than by trusting anyone to remember.

```bash
"$GODOT_BIN" --headless --path . -s tools/export_timeline.gd   # 6 eras -> docs/fixtures/battle_timeline.json
python3 docs/tools/build_motion_demo.py                        # re-embeds the fixture in the page
git diff --exit-code -- docs/fixtures/battle_timeline.json docs/explore-topdown-motion-demo.html
node docs/tools/check_motion_demo.js                           # renderer + freshness, exit 1 on drift
```

- The exporter is deterministic (fixed seed, `state.rng` tracks): a re-run on unchanged rules
  produces a byte-identical fixture, so the `git diff` is the staleness gate. A non-empty diff after
  a battle change is expected — **commit the regenerated fixture and page with it.**
- `check_motion_demo.js` needs no Godot. It fails if the page's embedded fixture drifts from the
  file, if rule code reappears on the page (it greps for rolls, target selection, outcome rules), if
  any event fails to resolve to something on screen, or if the 掩護鏈 stops staging front to back.
- Pillow is required by the builder (`python3 -m pip install Pillow`).

### Design-graph check (run after ANY `design/`, doc, or module-header change)

```bash
python3 docs/tools/check_design_graph.py            # exit 1 on any error
python3 docs/tools/check_design_graph.py --doc-map  # also regenerate doc-map's graph table
```

Current clean state: **14 system docs, 62 feed edges, 59 `code:` mappings, 0 errors, 0 warnings.**

What it enforces, so you don't have to hold it in your head:

- Every `graph:` `feeds` / `fed_by` name resolves to a real doc in `design/`, and every
  `resources_in` / `resources_out` name is a real field in `core/game_state.gd`.
- Every `[[wikilink]]` resolves (it understands `\|` table escapes, `|` aliases, `#anchors`).
- Every `code:` path exists, and any `.gd` header citing `design/X.md` is listed by that doc.
- Every doc-shaped file in the repo has a row (or a cluster row) in `docs/doc-map.html`.
- **Warnings** are asymmetric feed edges: A says it feeds B, B does not say it is fed by A.
  These are design questions — resolve them from the corpus prose or ask the human. The script
  never invents an edge to silence itself, and warnings do not fail the run.

Unlike the Godot commands, this one anchors on its own file location, so cwd does not matter.

## Part B — GPU capture demo (run before calling any view/system change "done")

> **DOWN W12–W14:** `view/main.gd` is parse-broken against the rewritten battle API (no hand)
> until the W15 view revamp. Part A never loads it; don't attempt Part B until W15 restores it.

```bash
cd /Users/saiday/projects/game-design/insignificant-game
export GODOT_DISABLE_LEAK_CHECKS=1 INSIG_DEMO=1 INSIG_SEED=1
/Applications/Godot.app/Contents/MacOS/Godot --path .          # NOT --headless — needs the real GPU
```

- Demo mode simulates the same click handlers a human uses, walks every phase panel, writes
  `captures/w5_*.png`, prints `ASSERT PASS/FAIL` lines, exits 0/1 (45 s watchdog).
- Judge from the PNGs, not the exit code alone: hunt clipping / wrong scale / missing text /
  stale labels (the taxonomy in root `docs/agent-development-loop.md` §3). Part B has caught
  real defects that Part A passed, so take the review seriously.
- Interactive play: same command without `INSIG_DEMO`.

## Balance batch (when tuning numbers)

```bash
cd /Users/saiday/projects/game-design/insignificant-game
"$GODOT_BIN" --headless --path . -s tools/balance_batch.gd     # 60 runs → reports/balance_batch.json
```

Compare against `docs/balance-report.md` before/after a knob change.

## Pitfalls (all hit for real in this repo)

1. **Shell cwd resets between tool calls** — `cd` into this directory in EVERY command, or
   Godot/runtest.sh won't find the project. Sanity check on any test run: the summary must say
   21 suites / 257 cases, exit 0 (update this pin when suites or cases are added).
2. **New `class_name` ⇒ import warm-up first**, or discovery fails with exit `105`
   ("Identifier not declared"). The warm-up is load-bearing, not a safety belt.
3. **gdUnit4 aborts a suite after its first failing case** — one red run doesn't show
   everything; re-run after each fix. "Failures" counts assertions, not cases.
4. **`Array.shuffle()`/`randi()` are forbidden in core/** — they use the global RNG and break
   run determinism (the sim tests will catch you). Everything random goes through
   `state.rng.<track>` (see architecture.md).
5. **Untyped-for-loop warnings:** iterate with typed loop vars (`for x: StringName in ...`);
   integer division needs `@warning_ignore("integer_division")` to stay warning-clean.
6. **Env vars don't persist between tool calls** — re-export `GODOT_BIN` etc. in every command.
7. **Design docs are big markdown tables with `[[wikilinks]]`** — escape `|` as `\|` inside table
   cells, or the row silently splits into extra columns.
8. **`captures/` is not in git** — on a fresh clone, Part B prints `ERROR: Can't save PNG` for
   every capture (asserts still pass, so the exit code lies about it). `mkdir -p captures`
   before the first Part B run.
