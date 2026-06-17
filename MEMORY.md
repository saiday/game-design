# MEMORY.md — quirks & workarounds (append-only)

Verified on this Mac (Apple M1 Pro, macOS 25.5, Godot 4.6.3) on 2026-06-17.

- **Engine install:** `brew install --cask godot` → Godot **4.6.3** at
  `/Applications/Godot.app/Contents/MacOS/Godot`. (Homebrew lives at `/opt/homebrew`;
  `brew` may be off a non-interactive shell's PATH — call it by full path.)
- **gdUnit4 install:** latest is `godot-gdunit-labs/gdUnit4` **v6.1.3** (old `MikeSchulze/gdUnit4`
  301-redirects). Release has no zip asset → pull the source tarball for the tag and copy
  `addons/gdUnit4/` into the project.
- **Import warm-up works on 4.6.3:** `--headless --path . --import --quit-after 2000` exits **0**
  (the godot#83449 exit-code-1 trap did NOT bite here). Kept as a harmless safety belt; still
  gate CI on the *test* step, not this. *(Not tested whether skipping it entirely is safe.)*
- **gdUnit4 run:** `GODOT_BIN=... GODOT_DISABLE_LEAK_CHECKS=1 ./addons/gdUnit4/runtest.sh -a res://test`
  → exit **0** = pass (100=fail, 101=warn). Reports at `reports/report_N/{results.xml,index.html}`.
  - The official `runtest.sh` is correct — **agy's `--run-gdunit-tests` flag was not needed** (companion §10 Open Item resolved).
  - **Benign error to ignore:** `ERROR: The remote port number must be between 1 and 65535` — that's the
    intentional `--remote-debug tcp://127.0.0.1:0` debugger trap in runtest.sh; the run still succeeds.
  - runtest.sh does **not** pass `--headless` (Metal initializes anyway and it works). For a strictly
    headless run, invoke `GdUnitCmdTool.gd` directly with `--headless`.
- **Part B capture works in this Claude Code session:** `Godot --path .` (NO `--headless`) renders via
  **Metal 4.0 / Forward+** on the M1 Pro and `get_viewport().get_texture().get_image()` reads back a real
  frame. So the agent session has GPU/window-server access here. Pattern that works: in `_ready`, build
  visuals → `await get_tree().process_frame` → `await RenderingServer.frame_post_draw` → `get_image()` →
  `save_png(ProjectSettings.globalize_path("res://captures/..."))` → `get_tree().quit()`. A watchdog timer
  guards against a no-render hang.
- **res:// is writable at runtime** when running from source (not exported), so screenshots can save under
  `res://captures/`. Used `globalize_path` to be safe.
- **New `class_name` scripts need an import pass before tests resolve them** (M1): a test referencing a
  brand-new `class_name` global fails discovery with exit **105** ("Identifier ... not declared",
  `Parse error`) until `--headless --path . --import` rebuilds the global class cache. So the import
  warm-up is *load-bearing* whenever you add a new `class_name`, not just cosmetic. Run it before every
  test run in the loop.
- **gdUnit4 CLI aborts the rest of a suite after a failing test** (M1, observed): when an earlier test
  case in a suite FAILED, the later cases in that *same* suite did not execute (suite reported `1 test
  cases` instead of 2; `0 skipped`). A single suite can therefore mask later failures. Implications:
  gate on the **exit code** (100=fail) not the case count; for M3 bug-injection this is fine; to see all
  failures, keep suites small / fix one at a time. (Other suites still run — example_test ran fine.)
- **gdUnit4 counts assertions, not just cases, as failures:** one failing test with two bad
  `assert_int`s reports `2 failures` against `1 test case`. Don't read "failures" as "tests failed".
- **Part-B pixel asserts: classify by nearest known color, don't match exact** (M2). The viewport
  read-back (`get_viewport().get_texture().get_image()`) may differ from source RGB by color space/gamma,
  so exact `==` is brittle. Instead pick a few known scene colors (bg/hex/card) and assert a sampled
  pixel is *closer* to its expected color than to the others (squared-distance). This is gamma-tolerant
  and gives real teeth — an off-screen or hidden element classifies as the wrong color and fails.
- **Image coords == Control/screen coords** (reconfirmed M2): with the root `Node2D` at identity and no
  `Camera2D`, a `Control`'s `get_global_rect()` and a `Node2D`'s `position` map 1:1 to `Image` pixels
  (top-left origin, y-down). So `Rect2(0,0,w,h).encloses(card.get_global_rect())` is a valid on-screen check.
- **`doc/prompts.md` is a live prompt-log the user's tooling rewrites every turn** (current prompt up top,
  prior ones archived). It will show as *modified* constantly. Don't be surprised, and **stage doc commits
  deliberately** (`git add <specific paths>`) instead of `git add -A`, or it gets swept into unrelated commits.
