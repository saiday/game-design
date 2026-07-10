# Mac Studio hand-off — bootstrapping the assets orchestrator

> **For the human:** what to paste to start an asset session on the Mac Studio. **For the agent
> reading this on the Studio:** your contract is
> `doc/image-assets-generation-orchestrator-cookbook.md` — read it fully before acting; this file
> is only the ignition sequence. Session memory from the MacBook did NOT transfer; the cookbook
> is deliberately self-contained.

Phases 0-2 are closed (locked recipe, frozen UI templates, and font in
`insignificant-game/assets/pipeline/style-bible.md`); sessions start at Prompt 3 and move to
Prompt 4 when the needed classes are approved.

## Human checklist (before each session)

1. **ComfyUI serving**: the launchd service `com.insignificant.comfyui` answers on
   `127.0.0.1:8188` (it survives reboots; don't open the dormant Comfy Desktop app — both want
   the port).
2. **This repo** up to date with push access (the agent commits contact sheets and approved
   assets).
3. **Obsidian corpus synced** at
   `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/obsidian/game-design/`
   (asset inventory and subjects come from it).

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
