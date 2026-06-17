# agent-process.md — setup recipe + journey log

Concise, reproducible record so the environment can be ported to another machine.
Verified machine: Apple M1 Pro, macOS 25.5, Godot 4.6.3 — 2026-06-17.

## Goal
Prove the two-part self-correction loop on real hardware: a LOGIC bug caught by
headless tests + a VISUAL bug caught by a screenshot, both fixed. Not game content.

## Environment setup (port these steps verbatim)
```bash
# 0. Prereqs: Homebrew. (gh/curl handy.) Project dir with doc/ specs.
# 1. Engine — Godot 4.6.x, GDScript build (NOT mono/C#):
brew install --cask godot                 # -> /Applications/Godot.app ; verify:
/Applications/Godot.app/Contents/MacOS/Godot --version   # 4.6.3.stable.official

# 2. Repo:
git init                                   # + .gitignore (ignores .godot/ reports/ captures/)

# 3. Test framework — gdUnit4 v6.1.3 (godot-gdunit-labs/gdUnit4):
curl -sL -o /tmp/gd.tgz https://github.com/godot-gdunit-labs/gdUnit4/archive/refs/tags/v6.1.3.tar.gz
tar -xzf /tmp/gd.tgz -C /tmp
cp -R /tmp/gdUnit4-6.1.3/addons/gdUnit4 ./addons/      # the release has no zip asset; use source tree

# 4. Minimal project: project.godot (config_version=5, main_scene=res://game/main.tscn,
#    640x360, enable addons/gdUnit4/plugin.cfg). Files: test/, game/main.tscn, tools/capture.gd.

# 5. Prove Part A (headless logic tests):
export GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
export GODOT_DISABLE_LEAK_CHECKS=1
"$GODOT_BIN" --headless --path . --import --quit-after 2000     # import warm-up (ignore its exit code)
./addons/gdUnit4/runtest.sh -a res://test                      # GATE: exit 0 + >=1 test ran

# 6. Prove Part B (real-GPU capture):
"$GODOT_BIN" --path .                                           # GATE: captures/*.png non-blank + ASSERT PASS
```

## Journey (what happened)
- M0.1 Recon: Godot/brew appeared absent (brew was just off PATH); confirmed Godot 4.6.3 installable via cask. Installed.
- M0.2 `git init` + Godot `.gitignore`.
- M0.3 Installed gdUnit4 v6.1.3 from source tarball; wrote minimal project; import warm-up → exit 0, `.godot` cache built.
- M0.4 **Part A PASS:** `runtest.sh -a res://test` → exit 0, 2/2 tests, report artifact.
- M0.5 **Part B PASS (riskiest):** `Godot --path .` rendered via Metal/Forward+ and wrote a valid 640×360 PNG; visually verified (dark bg + centered yellow card, taxonomy-clean).
- M0.6 Wrote durable state (CLAUDE/PLAN/STRUCTURE/MEMORY + this file).
- M0 committed (`dccda38`) on `main` (initial commit; `.antigravitycli/` machine-symlink added to .gitignore).
- M1 **Logic backbone, built test-first (TDD):** wrote `test/rules_test.gd` first → exit 105 (types missing) →
  added `GameState`/`Card` + no-op `Rules.play_card` stub → exit 100 (math assertion fails) → implemented
  pure math → **exit 0, 4/4**. Also proved the purity test's teeth via a throwaway mutate-in-place impl
  (only that test failed), then restored. Artifact `reports/report_6`.

## Gotchas worth porting (see MEMORY.md for detail)
- `runtest.sh` prints a benign `remote port ... between 1 and 65535` ERROR (intentional debugger trap) — run still passes.
- runtest.sh doesn't pass `--headless` (Metal inits anyway); for strict headless call `GdUnitCmdTool.gd` with `--headless`.
- The agent/terminal session here HAS GPU + window-server access — required for Part B. On a headless box this step would hard-stop.

## Status / next
M0 + M1 complete (env proven; pure rule + tests green, exit 0). **Next: M2** — Part-B visual slice
(scene with 1 card + 1 hex tile reflecting `GameState`; capture asserts card rect ⊂ viewport).
Companion-doc Open-Items update is parked for M4.
