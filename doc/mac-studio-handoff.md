# Mac Studio hand-off — bootstrapping the assets orchestrator

> **For the human:** how to start the first Claude Code session on the Mac Studio and what to
> paste. **For the agent reading this on the Studio:** your contract is
> `doc/image-assets-generation-orchestrator-cookbook.md` — read it fully before acting; this file
> is only the ignition sequence. Session memory from the MacBook did NOT transfer; the cookbook
> is deliberately self-contained.

Phases 0-2 are done (style bible locked: Krea-2-Turbo + Moebius LoRA, no pixelization; the five
UI templates are frozen and the Noto Sans font family locked — see
`insignificant-game/assets/pipeline/style-bible.md`) — prompts 0-2 below are kept for the
record; the next session starts at Prompt 3.

## Human checklist (before the first prompt)

1. **Claude Code installed** on the Studio, logged in.
2. **This repo cloned** with push access (`git clone` + verify `git push` works — the agent
   commits contact sheets and findings).
3. **ComfyUI**: already installed. Know two things the agent will ask: *how* it was installed (git clone + venv vs. desktop app — the desktop app can still serve the API, but the git install matches the cookbook), and how you launch it. No models are downloaded yet — the agent handles that.
4. **Obsidian corpus on the Studio**: sign into the same iCloud account so
   `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian/game-design/` syncs.
   Not needed for Phase 0, **required from Phase 1** (asset inventory is built from the corpus).
   If iCloud can't be arranged, copy the `game-design/` folder over manually and tell the agent
   where it is.
5. Optional but recommended for long batches: Energy Saver → prevent sleep, or let the agent use
   `caffeinate`.

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

## Prompt 4 — Godot integration (after Phase 3 classes are approved)

```
Cookbook Phase 4 (Godot integration), per §10, target 1920×1080 (style bible §8). Read
insignificant-game/CLAUDE.md and poc-docs/architecture.md before touching the project. Wire
approved assets data-driven (texture path derived from id + era); compose chrome at runtime —
frozen templates with the NinePatchRect margins and content rects from style bible §9, real
Label text in the locked Noto Sans family (fetch + subset the font binaries now, zh-TW = Noto
Sans TC) — never bake frame+art+text. Respect the NinePatch minimum sizes (style bible §9).
Keep the corpus code: frontmatter mapping current for anything you add. Run BOTH loop parts
(headless tests + Part B capture) and STOP for my review of the captures.
```

## Ground rules the human relies on (agent: these are already in the cookbook — obey them)

- Human owns aesthetics; every phase gate above ends with a STOP for human review.
- Nothing enters `assets/approved/` or a Godot scene without an explicit human pick.
- Raw candidates stay outside the repo; only contact sheets and approved assets are committed.
- Licensing: permissive models only without explicit sign-off (§0, §3).
