# Mac Studio hand-off — bootstrapping the assets orchestrator

> **For the human:** what to paste to start an asset session on the Mac Studio. **For the agent
> reading this on the Studio:** your contract is
> `docs/image-assets-generation-orchestrator-cookbook.md` — read it fully before acting; this file
> is only the ignition sequence. Session memory from the MacBook did NOT transfer; the cookbook
> is deliberately self-contained.

Current phase status lives in the cookbook (§7 per-class status, details in the §14 findings
log). Phases 0-2 are closed; their outcome is the locked recipe, frozen UI templates, and font
in `insignificant-game/assets/pipeline/style-bible.md`. The live prompts below are Prompt 3
(one Phase 3 class per session) and Prompt 4 (Godot integration, re-run per approved class).

## Human checklist (before each session)

1. **ComfyUI**: nothing to do. It is off between sessions and the agent starts it for the round
   and stops it after (see the lifecycle section below). Just don't leave the Comfy Desktop app
   open — it wants port 8188 too.
2. **This repo** up to date with push access (the agent commits contact sheets and approved
   assets; asset inventory and subjects come from `insignificant-game/design/`, which ships with
   the clone — no separate corpus sync needed).

## ComfyUI lifecycle

**ComfyUI is off between sessions, and the agent puts it back that way.** An idle server holds
~58 GB of this 96 GB machine and never returns it while the process lives (cookbook §4, §11), so
a server left up for a round that may never come costs the human most of their Mac. The rule for
both sides: bring it up when a round is about to render, take it down when the round's queue is
empty. Restart is one command, so "down" is the cheap default and "up" is the deliberate state.

The `com.insignificant.comfyui` LaunchAgent (`~/Library/LaunchAgents/com.insignificant.comfyui.plist`,
`RunAtLoad` + `KeepAlive`) is **currently disabled**, which is why nothing starts at login. An
agent starting the server for a round mirrors the plist's args by hand and leaves the disabled
flag alone: a `KeepAlive` service cannot be shut down at the end of a session, which is the whole
point.

```bash
curl -s 127.0.0.1:8188/system_stats >/dev/null && echo up || echo down   # is it serving?
curl -s 127.0.0.1:8188/queue                                             # empty BOTH queues before stopping

# start (headless, detached, survives the agent's shell) — all four args matter: without the two
# directory args, output lands in ComfyUI/output/ and every pipeline script reads ComfyUI-Shared/
cd ~/imagegen/ComfyUI && nohup .venv/bin/python main.py --listen 127.0.0.1 --port 8188 \
  --output-directory ~/ComfyUI-Shared/output --input-directory ~/ComfyUI-Shared/input \
  >> ~/imagegen/logs/comfyui.log 2>&1 & disown

# stop — kill whatever owns the port. Never `pkill -f` a path pattern: the server's command line
# differs depending on whether launchd or a hand-typed `cd && nohup` started it, so a path pattern
# misses one of the two while still exiting 0. Always verify the port, not the exit code.
lsof -ti tcp:8188 | xargs -r kill
curl -s --max-time 3 127.0.0.1:8188/system_stats >/dev/null && echo "STILL UP" || echo down
```

Never stop it mid-batch: queued jobs die with the process and they are hours. Port 8188 is freed
once it is down, so the dormant Comfy Desktop app can be opened without colliding.

**If you want login-start back** (the plist's original behaviour; then the server is up whenever
you are logged in, memory cost included):

```
launchctl enable    gui/$(id -u)/com.insignificant.comfyui
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.insignificant.comfyui.plist
launchctl print     gui/$(id -u)/com.insignificant.comfyui | grep state
```

To go back to off-between-sessions: `launchctl disable gui/$(id -u)/com.insignificant.comfyui`
then `launchctl bootout gui/$(id -u)/com.insignificant.comfyui`. `disable` writes a flag that
survives reboots; `bootout` stops the instance now; the plist file stays in place either way.

## Prompt 3 — class pipelines (repeatable; one class per session is fine)

```
Cookbook Phase 3, next class in §7 order (icons → buildings/units ×6 eras → cards →
backgrounds/portraits). The batch contract, proven in Phases 1-2:
- Generate under style bible §2-§3 exactly: subject-only prompts with the class framing suffix,
  fixed 3-4 seed sweep per subject. Batch scripts follow phase2_templates_batch.py's shape
  (hardened comfy_run.py, caffeinate, one retry per lost job).
- §8-check every raw and log the batch's artifact tally in §14 (logo badges / fake signatures
  are observed classes to count, not assumed traits). Re-roll failures with the same recipe;
  never widen the style.
- Post-process per §5: key the light-gray ground, halo-check on dark AND light backdrops
  (phase2_freeze.py holds the tuned flood-key params — reuse them).
- Icons: glyphs composite into the frozen plate's disc rect (style bible §9); contact-sheet
  them already composited on the plate so I judge the shipped look.
- Buildings/units: era N's approved sprite seeds era N+1 via img2img (~0.4-0.6 denoise, §6);
  cross-era coherence gets its own contact-sheet row per line.
- Contact sheets: rows = subjects, cols = seeds. Manifest entries status=candidate on
  generation; approved picks move to assets/approved/ with a status flip. Cards go to review
  in smaller batches (highest quality bar).
- Commit, push, STOP for my picks. After the batch session, verify /queue is empty, then free
  ComfyUI model memory (§14 habit). Escalate per §12 instead of widening the style.
```

## Prompt 4 — Godot integration (runs per approved class; UI chrome first, then each sprite class)

```
Cookbook Phase 4 (Godot integration), per §10, target 1920×1080 (style bible §8). Read
insignificant-game/CLAUDE.md, insignificant-game/docs/architecture.md and
insignificant-game/docs/dev-loop.md before touching the project. Integrate ONLY manifest status=approved assets, per class:
- Asset registry: one pure data-driven module maps asset id -> res:// texture path (icons
  icon_<id>, buildings building_<line>_era<n> derived from line id + current era; new classes
  slot in by the same id scheme). No node code computes paths; the view reads the registry.
- UI chrome: compose at runtime — frozen templates with the NinePatchRect margins, content
  rects and minimum sizes from style bible §9; real Label text in the locked Noto Sans family
  (fetch + subset the font binaries now, zh-TW = Noto Sans TC); never bake frame+art+text.
- Icons: bare approved glyphs composite into the plate's disc rect at runtime (style bible §9);
  stat readouts pair glyph + Label number.
- Buildings and later sprite classes: keyed transparent PNGs, scale in-engine only (assets ship
  at generation resolution); era changes swap the texture by id, never restyle in code.
- Keep the corpus code: frontmatter mapping current for anything you add. Run BOTH loop parts
  (headless tests + Part B capture) and STOP for my review of the captures.
```

## Ground rules the human relies on (agent: these are already in the cookbook — obey them)

- Human owns aesthetics; every phase gate above ends with a STOP for human review.
- Nothing enters `assets/approved/` or a Godot scene without an explicit human pick.
- Raw candidates stay outside the repo; only contact sheets and approved assets are committed.
- Licensing: permissive models only without explicit sign-off (§0, §3).
