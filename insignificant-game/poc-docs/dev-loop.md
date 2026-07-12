# Dev loop — verified commands & pitfalls (this project)

> Everything here was verified on both dev machines (Godot 4.6.3 at
> `/Applications/Godot.app` on each, Apple Silicon / Metal, gdUnit4 v6.1.3: MacBook M1 Pro,
> Mac Studio M2 Max). Generic loop rationale lives in the repo root's
> `doc/agent-development-loop.md`; this file is only what you type and what bites.

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

## Part B — GPU capture demo (run before calling any view/system change "done")

```bash
cd /Users/saiday/projects/game-design/insignificant-game
export GODOT_DISABLE_LEAK_CHECKS=1 INSIG_DEMO=1 INSIG_SEED=1
/Applications/Godot.app/Contents/MacOS/Godot --path .          # NOT --headless — needs the real GPU
```

- Demo mode simulates the same click handlers a human uses, walks every phase panel, writes
  `captures/w5_*.png`, prints `ASSERT PASS/FAIL` lines, exits 0/1 (45 s watchdog).
- Judge from the PNGs, not the exit code alone: hunt clipping / wrong scale / missing text /
  stale labels (the taxonomy in root `doc/agent-development-loop.md` §3). Part B has already
  caught a real defect once (stale phase titles) — take the review seriously.
- Interactive play: same command without `INSIG_DEMO`.

## Balance batch (when tuning numbers)

```bash
cd /Users/saiday/projects/game-design/insignificant-game
"$GODOT_BIN" --headless --path . -s tools/balance_batch.gd     # 60 runs → reports/balance_batch.json
```

Compare against `poc-docs/balance-report.md` before/after a knob change.

## Pitfalls (all hit for real in this repo)

1. **Shell cwd resets between tool calls** — `cd` into this directory in EVERY command, or
   Godot/runtest.sh won't find the project. Sanity check on any test run: the summary must say
   21 suites / 188 cases (update this pin when suites are added). (Historical note: the repo root used to hold a second Godot project
   whose 6 stale tests produced a convincing false green; it was removed 2026-07-08, so a wrong
   cwd now fails loudly instead — keep the count check anyway.)
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
7. **iCloud corpus files** (`design/` upstream) can change between read and write — re-read
   immediately before editing an Obsidian file; escape `|` as `\|` inside table wikilinks.
8. **`captures/` is not in git** — on a fresh clone, Part B prints `ERROR: Can't save PNG` for
   every capture (asserts still pass, so the exit code lies about it). `mkdir -p captures`
   before the first Part B run.
