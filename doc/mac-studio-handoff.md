# Mac Studio hand-off — bootstrapping the assets orchestrator

> **For the human:** what to paste to start an asset session on the Mac Studio. **For the agent
> reading this on the Studio:** your contract is
> `doc/image-assets-generation-orchestrator-cookbook.md` — read it fully before acting; this file
> is only the ignition sequence. Session memory from the MacBook did NOT transfer; the cookbook
> is deliberately self-contained.

Phases 0-2 are closed (locked recipe, frozen UI templates, and font in
`insignificant-game/assets/pipeline/style-bible.md`); Prompts 0-2 below are kept for the record.
Phase 3 progress: the icon class is closed (74 glyphs approved); 11 building lines are frozen
(66 sprites in `assets/approved/buildings/`), and bank + debt_office are regenerated with
researched iconography awaiting their chain-pick gate; units, cards, and backgrounds/portraits
remain (Prompt 3, one class per session). Prompt 4's first pass is in (registry + fonts +
runtime chrome, both loop parts green) — it re-runs per newly approved class.

## Human checklist (before each session)

1. **ComfyUI serving**: the launchd service `com.insignificant.comfyui` answers on
   `127.0.0.1:8188` (it survives reboots; don't open the dormant Comfy Desktop app — both want
   the port).
2. **This repo** up to date with push access (the agent commits contact sheets and approved
   assets).
3. **Obsidian corpus synced** at
   `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian/game-design/`
   (asset inventory and subjects come from it).

## ComfyUI launch agents settings

Default state: the `com.insignificant.comfyui` LaunchAgent
(`~/Library/LaunchAgents/com.insignificant.comfyui.plist`) auto-starts ComfyUI on
`127.0.0.1:8188` at every login and relaunches it if it exits (`RunAtLoad` + `KeepAlive`).
Leave it running during asset sessions. Use the commands below to toggle it between sessions.

**Done with image generation — stop it and keep it off across logins:**

```
launchctl disable gui/$(id -u)/com.insignificant.comfyui
launchctl bootout  gui/$(id -u)/com.insignificant.comfyui
```

`disable` writes a persistent flag that survives reboots so it no longer starts at login;
`bootout` stops the running instance now. The plist file stays in place, and port 8188 is freed
(so the Comfy Desktop app can now be opened without colliding).

**Start ComfyUI when needed — re-enable login start and launch it now:**

```
launchctl enable    gui/$(id -u)/com.insignificant.comfyui
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.insignificant.comfyui.plist
```

**Check current state:**

```
launchctl print gui/$(id -u)/com.insignificant.comfyui | grep state
curl -s 127.0.0.1:8188/system_stats >/dev/null && echo up || echo down
```

## Prompt 0 — bring-up (done; kept for the record)

```
Read doc/image-assets-generation-orchestrator-cookbook.md in full, then run Phase 0 (bring-up):

- ComfyUI is already installed on this machine and has Z-Image-Turbo installed. Find the installation, verify it serves the headless API per cookbook §3-§4 (adapt if it's the desktop app), and record the actual install layout in the findings log (§14).
- Download the workhorse trio (SDXL base, fp16-fix VAE, pixel-art LoRA) and Z-Image-Turbo per the §3 model kit and download order. Verify each license page at download time; FLUX downloads are fallback-only per §3.
- Prove the API round-trip: one SDXL image, fixed seed, workflow JSON saved under insignificant-game/assets/pipeline/workflows/. Then sanity-check Z-Image-Turbo the same way.
- Never benchmark the first run after a model load (§11). Record real s/image timings, versions, and the Z-Image verdict in §14.
- Create the assets/pipeline directory skeleton (§9) with pixelize.py from §5.
- Commit and push when Phase 0's gate holds. If a step is blocked after honest effort, §12: stop
  and report — a negative result is a valid result.
```

## Prompt 1 — style anchor (done; kept for the record — the outcome is the style bible)

```
Cookbook Phase 1 (style anchor), per §7:

- Build assets/pipeline/inventory.md from the Obsidian corpus setting docs (see repo CLAUDE.md for the corpus path and doc list) — every needed asset, one line each, ids matching the corpus/core data tables.
- Propose 3 master-palette candidates and per-class sprite grid sizes (§7 Phase 1 has a starting proposal — propose, don't decide).
- Generate style boards: the same 3 subjects under 3 style recipes, pixelized per §5, assembled into labeled contact sheets (§9), committed and pushed.
- Then STOP and present the boards to me. I pick the winner; you lock it into assets/pipeline/style-bible.md. The style bible only changes by my decision afterward.
```

## Prompt 2 — templates (done; kept for the record — the outcome is style bible §9-§10)

```
Cookbook Phase 2 (templates), per §6-§7: generate candidates for the five frozen structural
assets in inventory.md "UI templates" — card frame (content-window rect recorded at freeze),
panel 9-slice, button 9-slice, icon base plate, divider — under the locked style bible
(assets/pipeline/style-bible.md): subject-only prompts, fixed seeds, §8 checks (watch for
invented logo badges / fake signatures — tally this batch's rate and log it in §14). The
target resolution is Full HD 1920×1080 (§10); still record the content-window rect and 9-slice
margins relative to the generated image, never to screen pixels — scaling happens in-engine. Also propose 2-3 legible UI fonts with
Traditional Chinese coverage (license-verified, OFL preferred) — the §6 font pick happens at
this gate. Contact-sheet, commit, push, and STOP for my pick. Manual cleanup on chrome is
allowed here (once). Frozen templates never regenerate after this gate (§12).
```

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
insignificant-game/CLAUDE.md, poc-docs/architecture.md and poc-docs/dev-loop.md before touching
the project. Integrate ONLY manifest status=approved assets, per class:
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
