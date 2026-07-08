# Mac Studio hand-off — bootstrapping the assets orchestrator

> **For the human:** how to start the first Claude Code session on the Mac Studio and what to
> paste. **For the agent reading this on the Studio:** your contract is
> `doc/image-assets-generation-orchestrator-cookbook.md` — read it fully before acting; this file
> is only the ignition sequence. Session memory from the MacBook did NOT transfer; the cookbook
> is deliberately self-contained.

Last updated: 2026-07-08.

## Human checklist (before the first prompt)

1. **Claude Code installed** on the Studio, logged in.
2. **This repo cloned** with push access (`git clone` + verify `git push` works — the agent
   commits contact sheets and findings).
3. **ComfyUI**: already installed (2026-07-08). Know two things the agent will ask: *how* it was
   installed (git clone + venv vs. desktop app — the desktop app can still serve the API, but the
   git install matches the cookbook), and how you launch it. No models are downloaded yet — the
   agent handles that.
4. **Obsidian corpus on the Studio**: sign into the same iCloud account so
   `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian/game-design/` syncs.
   Not needed for Phase 0, **required from Phase 1** (asset inventory is built from the corpus).
   If iCloud can't be arranged, copy the `game-design/` folder over manually and tell the agent
   where it is.
5. Optional but recommended for long batches: Energy Saver → prevent sleep, or let the agent use
   `caffeinate`.

## Prompt 0 — bring-up (paste as the first message)

```
Read doc/image-assets-generation-orchestrator-cookbook.md in full, then run Phase 0 (bring-up):

- ComfyUI is already installed on this machine but has no models. Find the installation, verify
  it serves the headless API per cookbook §3-§4 (adapt if it's the desktop app), and record the
  actual install layout in the findings log (§14).
- Download the workhorse trio (SDXL base, fp16-fix VAE, pixel-art LoRA) and Z-Image-Turbo per the
  §3 model kit and download order. Verify each license page at download time; FLUX downloads are
  fallback-only per §3.
- Prove the API round-trip: one SDXL image, fixed seed, workflow JSON saved under
  insignificant-game/assets/pipeline/workflows/. Then sanity-check Z-Image-Turbo the same way.
- Never benchmark the first run after a model load (§11). Record real s/image timings, versions,
  and the Z-Image verdict in §14.
- Create the assets/pipeline directory skeleton (§9) with pixelize.py from §5.
- Commit and push when Phase 0's gate holds. If a step is blocked after honest effort, §12: stop
  and report — a negative result is a valid result.
```

## Prompt 1 — style anchor (paste after Phase 0 is committed)

```
Cookbook Phase 1 (style anchor), per §7:

- Build assets/pipeline/inventory.md from the Obsidian corpus setting docs (see repo CLAUDE.md
  for the corpus path and doc list) — every needed asset, one line each, ids matching the
  corpus/core data tables.
- Propose 3 master-palette candidates and per-class sprite grid sizes (§7 Phase 1 has a starting
  proposal — propose, don't decide).
- Generate style boards: the same 3 subjects under 3 style recipes, pixelized per §5, assembled
  into labeled contact sheets (§9), committed and pushed.
- Then STOP and present the boards to me. I pick the winner; you lock it into
  assets/pipeline/style-bible.md. The style bible only changes by my decision afterward.
```

## Prompt 2 — templates (after the style bible is locked)

```
Cookbook Phase 2 (templates), per §6-§7: generate candidates for the frozen structural assets —
card frame(s) with recorded content-window rects, panel/button 9-slice sources, icon base plate —
in the locked style. Contact-sheet them, commit, push, and STOP for my pick. Manual pixel cleanup
on chrome is allowed here (once). Frozen templates never regenerate after this gate (§12).
```

## Prompt 3 — class pipelines (repeatable; one class per session is fine)

```
Cookbook Phase 3, next class in §7 order (icons → buildings/units ×6 eras → cards →
backgrounds/portraits). Batch-generate under the style bible with fixed seeds, self-check per §8,
pixelize per §5, contact-sheet + manifest per §9, commit and push, STOP for my picks. Approved
picks go to assets/approved/ with a manifest status flip. Escalate per §12 instead of widening
the style.
```

## Ground rules the human relies on (agent: these are already in the cookbook — obey them)

- Human owns aesthetics; every phase gate above ends with a STOP for human review.
- Nothing enters `assets/approved/` or a Godot scene without an explicit human pick.
- Raw candidates stay outside the repo; only contact sheets and approved assets are committed.
- Licensing: permissive models only without explicit sign-off (§0, §3).
