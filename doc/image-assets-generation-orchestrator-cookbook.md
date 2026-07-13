# Image-Assets Generation Orchestrator Cookbook

> **Audience:** the Claude (Opus-class) agent that will run **on the Mac Studio** and orchestrate
> image-asset generation for **Insignificant**. You drive the pipeline end-to-end; the human
> reviews style and approves assets.

---

## 0. Standing decisions (do not re-litigate)

| Decision | Value | Source |
|---|---|---|
| Art style | **Moebius-style illustration** (ligne-claire linework, watercolor fills) via Krea-2-Turbo + Moebius LoRA; **no pixelization for any asset class**. Locked in `insignificant-game/assets/pipeline/style-bible.md`; matches corpus §視覺與聽覺風格. Native resolution: **Full HD 1920×1080** (see §10). Flat info-dense UI. | human pick at the Phase 1 gate |
| Generation locality | **Local-only** on the Mac Studio. No cloud image APIs. | human |
| Commercial status | Hobby / undecided — but **prefer permissively-licensed models anyway** so a later commercial pivot doesn't invalidate assets. Non-permissive weights need explicit human sign-off. **Signed off: Krea 2** (Community License, commercial free only under $1M TTM revenue) as the production checkpoint, with the pivot risk surfaced — the sign-off record lives in style-bible.md §6; re-verify before any commercial release. | human |
| Asset scope v1 | All four classes: buildings/units ×6 eras, card illustrations, UI icons & frames, backgrounds & portraits | human |
| Orchestration | Claude Code runs **on the Mac Studio** with this repo cloned; outputs reviewed via committed contact sheets | human |
| Backbone tool | **ComfyUI headless via its localhost JSON API**; production recipe = **Krea-2-Turbo + Moebius LoRA** (style bible) — the only models installed; **Pillow** for contact sheets and keying (no pixelization, §5); Draw Things = human spot-checks only, never the pipeline | this doc + human |
| Consistency strategy | **Template-first, semi-generated** (§6): structural assets are generated once, human-frozen, then reused mechanically; AI only fills content inside frozen structure | human + this doc |

Authority split (same as the code loop): **you own execution and objective checks; the human owns
aesthetics.** You never declare art "good" or pick the style anchor — you produce options and
evidence, the human picks. Nothing enters the game without human sign-off (§9).

**Operating rules** (inherited from the exploration guide; still binding):
- **Verify, don't guess.** Image-gen tooling moves fast and Apple-Silicon behavior differs from
  the NVIDIA-centric guides most of the internet is written for. Confirm speed/quality/licensing
  on *this* machine rather than trusting a blog.
- **Reproducibility is non-optional.** Prompt, seed, model, and params saved for every kept
  output (§9); an asset you can't regenerate is a dead end for a consistent set.
- **Agent-drivable, not GUI-locked.** The pipeline backbone must be scriptable (CLI/API); no
  manual clicking in the loop.
- **Static art only.** No animation/spritesheets — the locked design direction is static
  cards/sprites, and AI frame-to-frame animation is weak anyway.
- **One self-generated, style-unified pack; never stitch third-party packs.** Each purchased pack
  carries its own palette, line weight, and lighting — mixing them guarantees clashes. Everything
  descends from one style source (the style bible, §7 Phase 1). Manual/vector/existing assets are
  the *exception*, reserved for what AI does poorly, and even then restyled to the style bible and
  verified for cohesion.
- **Known AI weak spots — plan around them, don't fight them:** seamless tilesets (output drifts,
  seams need explicit verification if any map tiling is ever needed), pixel-exact UI chrome and
  text (answered by §6 frozen templates + Godot `Label` text), animation frames (out of scope).
- **Human-in-the-loop refine is the norm:** generate many, pick best, clean up — not hands-off
  output.
- **Capture learnings** in §14 as you go; a negative result recorded honestly is a valid result.

## 1. Relationship to prior docs

- The **design corpus** (Obsidian `game-design/`, see repo `CLAUDE.md`) is the source of truth for
  *what* to draw: `營運` (building lines × 6 eras), `卡牌` (card list + era evolution), `時代與回合`
  (the six eras), `對手文明` (5 automa civs), `結局` (epilogue scenes), `經濟與債務`/`幸福` (the
  stats that need icons). Build the asset inventory from these docs, never from memory.
- `insignificant-game/` is the delivery target: Godot 4.6, Forward+; target resolution Full HD
  1920×1080 (§10).

## 2. Hardware reality (Mac Studio, M2 Max, 96GB unified memory)

- 96GB unified memory means **memory is not your constraint; compute speed is** (the 25GB
  production checkpoint loads with room to spare — but see the §14 memory-pressure finding).
- Measured production timings (style bible §2): **~170 s/image @1024²**, scaling roughly with
  pixel count (divider 1024×256 ≈ 39 s, button 1024×512 ≈ 78 s, card 768×1024 ≈ 118 s).
  Batch-and-review, not interactive — an overnight run is a few hundred candidates.
- Apple Silicon runs via **PyTorch MPS (Metal)**. CUDA-only custom nodes/tooling will fail —
  treat any CUDA-only dependency as a red flag and find the Metal path.
- Long batches: run under `caffeinate -i` so the machine doesn't sleep mid-batch.

## 3. Environment setup (fresh machine → working pipeline)

Verify current versions/URLs at setup time; pins below were sane as of 2026-07. Record what you
actually installed in §14.

```bash
xcode-select --install                      # Command Line Tools (if missing)
brew install uv git git-lfs imagemagick     # Homebrew assumed present; install it if not

mkdir -p ~/imagegen && cd ~/imagegen
git clone https://github.com/comfyanonymous/ComfyUI
cd ComfyUI
uv venv --python 3.12 .venv && source .venv/bin/activate
uv pip install torch torchvision torchaudio   # stable PyTorch; MPS is built in
uv pip install -r requirements.txt
python -c "import torch; assert torch.backends.mps.is_available()"   # must pass

python main.py --listen 127.0.0.1 --port 8188   # headless server (on this machine it runs as
curl -s http://127.0.0.1:8188/system_stats | head -c 300   # the launchd service, §14 install row)
```

Install **ComfyUI-Manager** (`git clone https://github.com/ltdrdata/ComfyUI-Manager custom_nodes/comfyui-manager`)
for custom-node management.

### Model kit

The locked recipe's four files are the **only models installed** (hashes in style-bible.md §7;
they live in `~/ComfyUI-Shared/models/`, see the §14 install row). Re-download with
`uv tool install huggingface_hub` → `hf download <repo> <file> --local-dir ...`; **check the
license page at download time.**

| Role | Model | Repo / file | License | Dir |
|---|---|---|---|---|
| **Production checkpoint** | Krea-2-Turbo | `Comfy-Org/Krea-2` → `krea2_turbo_bf16.safetensors` + `qwen3vl_4b_bf16.safetensors` (text encoder) + `qwen_image_vae.safetensors` (VAE) | **Krea 2 Community License — non-permissive, human-signed-off; see style-bible.md §6** | `diffusion_models/`, `text_encoders/`, `vae/` |
| **Production style LoRA** | Krea2 Moebius | `Urabewe/Urabewe-LoRA-Collection` → `Krea 2/Krea2_Moebius_LoRA.safetensors` | MIT | `loras/` |

Adding any other model (e.g. IP-Adapter as the §6 level-4 consistency lever, via `h94/IP-Adapter`
+ ComfyUI_IPAdapter_plus) is a deliberate step: verify the license, and non-permissive weights
need human sign-off per §0.

## 4. Driving ComfyUI as an agent

Never click the GUI as your pipeline. The loop is:

1. Author or load a **workflow JSON in API format** (in the GUI once: enable dev mode → "Save (API
   Format)"; thereafter edit the JSON directly). Keep canonical workflows in
   `insignificant-game/assets/pipeline/workflows/*.json` — one per asset class.
2. Patch the JSON per job (prompt text, seed, dimensions, LoRA strength) and submit:
   `POST http://127.0.0.1:8188/prompt` with body `{"prompt": <workflow>, "client_id": "<uuid>"}` →
   returns `prompt_id`.
3. Poll `GET /history/<prompt_id>` until done; output PNGs land in `ComfyUI/output/`. Set each
   job's `filename_prefix` in the SaveImage node to the manifest ID so files are self-identifying.
4. **Look at every image you keep** (you can read PNGs) and self-check the objective criteria in
   §8 before it ever reaches the human.

Rules: **explicit fixed seeds always** (no `-1`); one variable changes per iteration when
debugging quality; batch via seed sweeps (same prompt, seeds `n..n+15`), not prompt roulette.

## 5. Post-process (no pixelization)

**Pixelization is dropped for all asset classes** (human decision at the Phase 1 gate: thin
ligne-claire linework and watercolor fills do not survive grid-snap + palette quantization).

- **No grid snap, no palette quantization, no master palette.** Assets ship at generation
  resolution and scale in-engine.
- What remains of post-processing:
  - **Transparency keying** for sprites: prompt the isolation background (`plain light gray
    background`, per the style bible prompt block), key it out, and verify no halo against a dark
    and a light backdrop before approval.
  - **Review copies / contact sheets** (§9) unchanged.
- Per-class **generation sizes** replace sprite grids; they live in the style bible §3 and are
  working baselines (resolution is cheap to change; the style recipe is what's locked).
- Reopening pixelization, grids, or a master palette is a §12 escalation (human decision), not an
  agent call.

## 6. Consistency strategy — template-first, semi-generated

**The core insight (human): style consistency is not achieved by making the model
consistent; it's achieved by generating structure ONCE and never regenerating it.** AI output
varies run-to-run; frozen pixels don't. So split every asset into *structure* (generated once,
human-approved, frozen forever) and *content* (generated fresh per asset, inside the structure).

**Frozen templates (structure — generated once, then mechanical reuse):**
- **Card frame/border**: generate candidates for one frame (variants per rarity/class only if the
  design requires), human picks, freeze into `approved/ui/`. The frame's **content-window rect**
  (where illustration goes) is recorded in the style bible and every card illustration is produced
  to exactly that rect.
- **Panels, buttons, dividers (UI chrome)**: generate the 9-slice source once, freeze; Godot's
  `NinePatchRect` does the stretching. AI never regenerates chrome per screen — this also
  sidesteps AI's known weakness at crisp pixel chrome (§0 weak spots).
- **Icon base plate**: one frozen background plate/shape; only the glyph inside is generated.

**Compose in Godot, don't bake:** a card on screen = frozen frame (`NinePatchRect`/`TextureRect`)
+ illustration texture in the content window + **real `Label` text with the locked UI font**
(Noto Sans family, zh-TW = Noto Sans TC; style bible §10). Never bake
frame+art+text into one PNG: baking means a frame tweak invalidates every card, numbers can't
update live, and AI-rendered text is unusable anyway. The only baked composites allowed are
review contact sheets.

**Content variation inside frozen structure (per-asset generation):**
- Card illustrations, portraits, backgrounds, building/unit sprites — generated fresh, but always
  under the style bible's locked recipe and prompt block, sized to the frozen rects.
- **Masked inpainting** when a family shares layout: freeze the shared region, inpaint only the
  changing region (ComfyUI inpaint workflow).
- **img2img lineage for era evolution**: era N's *approved* sprite is the init image for era N+1
  at low denoise (~0.4–0.6), so the lineage visibly persists and only era-specific features change.

**Lever hierarchy — always exhaust the cheaper one first:**
1. Frozen templates + runtime compositing (this section)
2. Locked style-bible recipe: Krea-2-Turbo + Moebius LoRA @1.0 + the subject-only prompt block (style bible §2-§3; no palette quantization, §5)
3. Seed families / img2img lineage (same base seed or init image across a family)
4. IP-Adapter style reference (zero-shot, weaker on fine detail)
5. Custom style LoRA trained on our own approved set — **escalation, human decision** (§12)

## 7. Phase plan

Phases are gate-ordered: **never claim a later gate before an earlier one holds.** A dynamic
workflow may interleave work, but gates close in order.

**Phase 0 — Bring-up** (**closed**): ComfyUI serving the JSON API with reproducible seeded
workflows; install layout and timings in §14.

**Phase 1 — Style anchor** (**closed**): asset inventory built from the corpus docs (§1) into
`insignificant-game/assets/pipeline/inventory.md`; style boards contact-sheeted; the human's
pick is locked in `assets/pipeline/style-bible.md` — exact recipe, prompt block, per-class
sizes, license sign-off, reference images. **Every generation cites the style bible; changing
it is a human decision.**

**Phase 2 — Templates** (**closed**): the five structural assets per §6 generated, human-picked,
and frozen into `assets/approved/ui/` with measured geometry (style bible §9); UI font locked
(style bible §10). Manual cleanup on chrome was allowed here precisely because it happens once —
frozen templates never regenerate.

**Phase 3 — Class pipelines**, in this order (volume × risk):
1. **UI icons** (**closed**: all 74 glyphs frozen in `assets/approved/icons/`) — glyphs on the
   frozen base plate.
2. **Buildings & units ×6 eras** — the volume class. Per building line: era N approved sprite
   seeds era N+1 via img2img lineage (§6); **era-gated waves** (`phase3_buildings_wave.py` +
   `phase3_building_chains.json`): each era is §8-reviewed before it seeds the next, because
   artifacts propagate down chains (§14). Buildings status: 11 lines frozen (66 sprites in
   `assets/approved/buildings/`); bank + debt_office regenerated from scratch with researched
   iconography (§14 2026-07-13), all 6 eras §8-clean, chain-pick gate pending. Units not started.
3. **Card illustrations** — per card in `卡牌`, produced to the frozen content-window rect;
   highest quality bar, human reviews in smaller batches.
4. **Backgrounds & portraits** — low volume, large canvas; generated under the style-bible recipe
   like everything else (~170 s/image on Krea 2 is fine at this volume).

**Phase 4 — Godot integration**: §10, runs per approved class. Target resolution: **Full HD
1920×1080**. First pass is in (`core/data/asset_paths.gd` registry, Noto Sans TC subsets,
runtime-composed chrome in `view/main.gd`, window 1920×1080; Part A + Part B green) — each later
approved class wires in through the same registry, capture reviewed with the same Part-B
discipline.

## 8. Objective self-checks (before an image reaches the human)

Reject and re-roll without asking if: silhouette unreadable at ship size; wrong aspect/framing or
doesn't fit its frozen template rect; alpha halos after keying; subject mismatch with the
inventory line; obvious artifacts (extra limbs, garbled text); **invented logo badges or fake
artist signatures** (an observed artifact class of the production recipe, not established model
behavior — tally the rate per batch and log it in §14; there is no negative-prompt lever at
cfg 1, so reject + re-roll is the only control); era variant that doesn't visibly differ
from its neighbors. What you must NOT judge: whether it's pretty, on-theme, or the best of the
batch — that's the human's pick.

## 9. Review loop, provenance, repo layout

```
insignificant-game/assets/
  pipeline/            # style-bible.md, inventory.md, style-refs/, workflows/*.json, manifest.jsonl, batch/sheet/freeze scripts
  contact-sheets/      # committed review grids (Pillow)
  approved/<class>/    # human-approved ship assets only — the ONLY dir Godot scenes reference
```

Raw candidates stay on the Studio **outside the repo** (e.g. `~/imagegen/candidates/`) — never
commit candidate piles. The review unit is the **contact sheet**: a labeled grid (manifest IDs
under each cell) committed to `contact-sheets/`, human replies with picks/rejections, picks get
post-processed into `approved/` with a manifest status flip. **Sheet cells stay ≥ 640 px on the
raw's long side (human rule): the human zooms into cells for detail review — a sheet too small
to zoom is not reviewable.**

**Manifest** (`manifest.jsonl`, one line per kept asset — an asset you can't regenerate is a dead
end):

```json
{"id":"bld_farm_era3_s41","file":"approved/buildings/building_farm_era3.png","class":"buildings",
 "prompt":"...","negative":null,"seed":41,"checkpoint":"krea2_turbo_bf16@<hash>","loras":[["Krea2_Moebius_LoRA",1.0]],
 "workflow":"workflows/krea2_lora_txt2img.json","init":"approved/buildings/building_farm_era2.png",
 "post":{"key":"light-gray"},"status":"approved","date":"2026-07-XX"}
```

(`init` records the img2img lineage parent, when used. `post` records keying params or `null` —
no pixelization, §5.) Naming: `building_<line>_era<n>.png`,
`unit_<type>_era<n>.png`, `card_<id>.png`, `icon_<stat>.png`, `bg_era<n>.png`,
`portrait_civ<n>.png` — ids matching the corpus/`core/` data tables.

## 10. Godot integration

- **Render resolution: Full HD 1920×1080** — the PoC window runs it (wired with the first
  approved classes); core is resolution-blind (`poc-docs/architecture.md`). Assets are high-res
  illustrations — default (linear) texture filtering, lossless PNG import. Templates record
  rects/margins relative to the generated image, not screen pixels — scaling happens in-engine.
- **The registry is `core/data/asset_paths.gd`** (pure id→path table + frozen-template geometry,
  test-pinned to disk): new approved classes slot in by the same id scheme
  (`icon_<id>` / `building_<line>_era<n>`); the view loads textures, core never does.
- **Composite, don't bake** (§6): cards/panels are scene trees — frozen frame texture +
  illustration texture + `Label` text (UI font, §6) — never single baked PNGs. `view/main.gd`
  holds the working patterns (styleboxes from templates, glyph-on-plate badges, card widget).
- Wire assets data-driven (path derived from id + era), matching the pure-core architecture —
  read `insignificant-game/CLAUDE.md` and `poc-docs/architecture.md` before touching scenes, and
  run **both loop parts** (headless tests + Part B capture) after wiring.
- Keep the corpus `code:` frontmatter convention: if you add asset tables/modules, map them.

## 11. Apple-Silicon pitfalls (verify, don't assume)

- **CUDA-only custom nodes** (some ControlNet preprocessors, xformers) fail on MPS — check a
  node's issues for Mac support before adopting it.
- First generation after model load is much slower (Metal shader compile) — never benchmark run #1.
- The server caches models in-process and MPS holds freed tensors until process exit — after each
  batch session (verify `/queue` is empty first, **never mid-batch**), release memory via
  `POST /free` or a service kickstart (§14 memory row).
- iCloud paths (the Obsidian corpus) can be offline-evicted — if a corpus read returns stubs,
  `brctl download` or open the file once.

## 12. Escalation triggers (stop and ask the human)

- A local path can't be made to work on this machine after honest effort — report it; a negative
  result is a useful result.
- Licensing for a needed model/LoRA is unclear or non-commercial and no permissive substitute is
  found; and anything that would put non-permissive-licensed output into `approved/`.
- A required quality bar can't be reached locally (e.g. a class won't reach card-usable quality) —
  surface it rather than forcing it.
- Consistency can't be achieved with the cheap levers (§6 hierarchy 1–4) and would need
  significant training investment — that's a human decision, not a quiet escalation of effort.
  Any proposal to train a custom style LoRA goes here (cost/benefit is a human call).
- The style bible can't hold across a class (e.g. icons refuse to match sprites) after honest
  effort — surface evidence, don't quietly widen the style.
- Frozen-template or style-bible changes after their phase gate locked them — including any
  proposal to reintroduce pixelization, sprite grids, or a master palette (dropped by human
  decision, §5).

## 13. References (fetched/verified 2026-06-17 by the exploration guide — re-verify before relying)

- ComfyUI on Apple Silicon (MPS speed, optimization flags): https://www.workflowlab.dev/deploy/comfyui-mac-apple-silicon-mps-speed
- Character/style consistency (LoRA / IP-Adapter / ControlNet): https://thinkpeak.ai/stable-diffusion-character-consistency-tutorial/ · https://www.lovart.ai/blog/complete-guide-consistent-ai-character-design
- Honest limits of AI 2D asset generation (single-frame strong; tilesets/animation weak): https://www.summerengine.com/blog/ai-2d-game-asset-generator

## 14. Findings log (append as you learn — keep this doc honest)

| Date | Finding |
|---|---|
| 2026-07-08 | **Install layout:** ComfyUI git clone at `~/imagegen/ComfyUI` (0.27.0 @ `ffbecfff`, Python 3.12.11, torch 2.12.1, MPS), run as the launchd service `com.insignificant.comfyui` (KeepAlive + RunAtLoad; logs in `~/imagegen/logs/`; manage with `launchctl kickstart -k` / `bootout gui/$UID/com.insignificant.comfyui`). Models resolve via `extra_model_paths.yaml` to `~/ComfyUI-Shared/models/<kind>/`; outputs land in `~/ComfyUI-Shared/output/`. The dormant Comfy Desktop app also wants port 8188 — don't open it while the service runs. |
| 2026-07-08 | **Reproducibility is per-environment:** same seed → bit-identical pixels within one install, NOT across torch versions (visually identical, 26-71% of pixels drift slightly). Pin the env for any asset family in progress; re-anchor img2img lineages after a torch upgrade. Compare pixels, not PNG bytes (ComfyUI embeds workflow metadata in the file). |
| 2026-07-08 | **Machine quirks:** run pipeline scripts with `~/imagegen/ComfyUI/.venv/bin/python` (has Pillow+numpy; system python3 doesn't); the rtk Bash hook mangles large JSON piped through inline one-liners — write API responses to files first (or use `rtk proxy`). Contact sheets are assembled with Pillow. Every pipeline command must start with `cd .../insignificant-game/assets/pipeline &&` in the SAME shell command — background tasks always spawn at the repo root (they ignore the foreground shell's cwd entirely), and the foreground cwd drifts too (repo-root git commands); relative-path launches then fail with "can't open file". |
| 2026-07-09 | **Phase 1 gate CLOSED — recipe r4 (Krea-2-Turbo + Moebius LoRA @1.0) locked; pixelization dropped for all assets.** Krea 2 Community License explicitly signed off (record: style-bible §6). Recipe facts: CLIPLoader type `krea2`, euler/simple 8 steps cfg 1, ConditioningZeroOut → **no negative-prompt lever** (quality control = §8 reject + re-roll, never negative-prompt tuning); the Moebius LoRA has no trigger word and its author says to avoid art-style descriptors in prompts. |
| 2026-07-09 | **Render resolution decided: Full HD 1920×1080.** PoC window stays 1280×720 until Phase 4; core is resolution-blind. |
| 2026-07-09 | **Badge/signature artifacts are a per-batch observation, not a model trait (human challenge, upheld):** Phase 1 style boards hit 3/4 seeds on two subjects; every batch since came back clean — templates 0/20 (plus 2/20 faint parchment scribbles, inpainted at freeze), divider re-roll 0/4, core icons 0/36, core_fix 0/12. Tally every batch here. |
| 2026-07-09 | **ComfyUI resident memory (~60GB after mixed model use) is designed caching, not a leak;** memory pressure once SIGTERM'd the server mid-job. Tooling since: `comfy_run.py` retries poll blips and detects jobs that vanished in a restart; batch scripts retry a lost job once. Habit: after each batch session (verify `/queue` is empty first — **never mid-batch**) release memory via `curl -X POST http://127.0.0.1:8188/free -H 'Content-Type: application/json' -d '{"unload_models": true, "free_memory": true}'` or `launchctl kickstart -k gui/$UID/com.insignificant.comfyui`. `--disable-smart-memory` rejected as a default (per-job reload ≈ doubles batch wall-clock). |
| 2026-07-09 | **Phase 2 template learnings:** "empty window / plain empty center" honored 20/20; buttons render a baked drop shadow (keyed at tolerance 95); mid-edge ornaments smear under 9-slice stretch — prefer corners-only variants; **NinePatch sources impose minimum UI sizes** (panel ≈178×169, button ≈181×138 at source scale) below which corner patches squash. |
| 2026-07-09 | **Phase 2 gate CLOSED — five templates frozen in `assets/approved/ui/`** by `phase2_freeze.py` (border-flood keying, programmatically measured rects/margins, parchment ink inpaint = the once-allowed manual cleanup); geometry in style bible §9. **UI font locked: Noto Sans family** (localization rules out single-script personality fonts; zh-TW = Noto Sans TC, OFL 1.1 verified in the official repo). Runners-up, licenses + TC coverage verified via fontTools cmap: jf open 粉圓 v2.1 (OFL 1.1) and Iansui 芫荽 v1.020 (OFL 1.1). |
| 2026-07-10 | **Icon glyph prompting (core + core_fix batches):** abstract-negative concepts need explicit broken/emptied objects ("cracked coin stack" read as plain wealth 3/3; "coin broken in two halves" unmistakable 3/3); figure subjects need explicit uniformity ("identical …") or the model renders demographic variety; give every subject an inherently colored object or it falls back to ink-only line art — garment color words alone are weaker than flame/red cloth. Border-flood keying leaves enclosed near-bg regions opaque (a gear's holes vs a fist's white fill are indistinguishable without semantics) — reads fine on the plate; clean per-glyph at freeze if it clashes. |
| 2026-07-10 | **Phase 3 core icon gate CLOSED — all 10 core-stat glyphs frozen in `assets/approved/icons/`** (halo check clean 10/10 on dark and light — `contact-sheets/phase3_icons_core_halo_check.png`). Remaining 64 icons running as one overnight sweep (9 groups × 3 seeds = 192 images), subjects written with color-bearing elements and de-collided silhouettes up front. |
| 2026-07-10 | **Env + docs cut to the locked recipe (human direction):** removed the Phase 0-1 utility/fallback weights (SDXL base + fp16-fix VAE, Z-Image-Turbo + its text encoder/VAE, three pixel-art LoRAs — ~26GB freed; only the Krea 2 trio + Moebius LoRA remain installed) and, from the repo, the retired style-board/pixelize scripts, `palettes/`, and unused workflow JSONs. The full exploration record (model verdicts, hashes and licenses of removed models, palette licensing research, superseded Desktop-app layout) lives in git history. |
| 2026-07-11 | **Phase 3 icon sweep (9 groups, 64 subjects × seeds 61-63 = 192 images, zero lost jobs): artifact tally 8/192, all one class — invented printed text on flat blank surfaces** (chip faces, folder seals, box/document fronts: era6 3/3, intelligence_agency 3/3, fund s62, bureaucracy s63); zero logo badges, zero signatures. Rule: **don't hand a glyph subject a prominent flat blank surface, or fill it explicitly** ("covered in circuit traces", "tied with red string"). world_expo pulled full scene compositions 3/3 ("grand pavilion" reads as architecture-scene, not object). Five subjects re-rolled as `sweep_fix` (three §8 misses + text-free alternates for cultural_revolution's pseudo-hanzi covers and critical_spirit's invited pseudo-text — human judges the originals against them). era6 needed a second re-roll: "covered in circuit traces" still yielded printed "era" 3/3 (the word leaks from the framing suffix itself); **occupying the surface with an object** (hexagonal crystal core) or swapping the subject (network globe), both under a "digital age" framing, killed the text 6/6. |
| 2026-07-11 | **Phase 3 sweep gate picks executed — 60 more glyphs frozen (70 of 74 icons now in `assets/approved/icons/`, halo check clean on `contact-sheets/phase3_icons_halo_check.png`).** Design decision folded in: **religion stays non-specific; the neutral religious motif is a golden tree** (the dogma tome's cross emblem and era-3's stained glass re-rolled to carry it; `picks_fix` batch, which also re-renders democratic_spirit as an explicitly marked ballot). Still open: religious_dogma / democratic_spirit / era3 picks from the `picks_fix` rows, and the era6 variant confirmation (crystal-core chip vs network globe). |
| 2026-07-12 | **Phase 3 icon class CLOSED — all 74 UI icons frozen in `assets/approved/icons/`** (final picks: religious_dogma2 s62, democratic_spirit2 s62, era3v2 s62, era6v3 s61; halo check clean 74/74 on `contact-sheets/phase3_icons_halo_check.png`; manifest fully flipped). Class totals: 222 images generated across 5 batches for 74 approved glyphs (3.0 raw:approved), aggregate §8 artifact rate 11/222 — all invented printed text, none of the Phase 1 badge/signature classes. Next class per §7: buildings/units ×6 eras (img2img era lineage). |
| 2026-07-12 | **Phase 3 buildings pilot (food line, 4 seed chains × 6 eras = 24 images): the img2img era lineage works.** Chains at denoise 0.55 (`workflows/krea2_lora_img2img.json`, `comfy_run.py --image/--denoise` — source uploaded via `/upload/image`, no shared-folder coupling) keep palette, footprint and props while the tech level advances; img2img ≈ 90 s @1024² vs ~160 s txt2img. §8 tally 10/24, two building-specific artifact classes: **invented text signs** on barns/sheds (the flat-surface rule §14 2026-07-11 holds for buildings) and **real-world national flags** (US flags — "red barn" pulls Americana). Critical finding: **artifacts propagate down a lineage chain** (s73's flag entered at era 2 and rode to era 5; s74's rode eras 4-6) — for the remaining lines, §8-gate each era BEFORE seeding the next, and mid-chain re-rolls need a seed bump or subject tweak (same seed+source+prompt reproduces the artifact). Clean chain: s71 6/6. |
| 2026-07-12 | **Buildings era waves 1-2 (11 lines × 4 chains, era-gated via `phase3_buildings_wave.py` + `phase3_building_chains.json`): 88 cells, 7 §8 rejects, all text/symbol classes.** New findings: (1) **profession/function nouns leak as literal signage** — "clinic house" printed a CLINIC sign exactly as "information era" printed "era" on the chip; name the contents, not the job title ("stone house with mortar, pestle and herb wreath above the door" came back clean). (2) New reject class: **protected real-world emblems** (a red cross banner on a clinic — Geneva-protected, treated like national flags). (3) Era-1 barracks drew **anachronistic rifle racks** from "weapon rack" — era-form subjects must name era-appropriate objects ("rack of wooden spears"). (4) The Phase 1 **fake-signature class resurfaced once** (1 background signature in ~1070 images since; it sits in the keyed-out region and the freeze speck filter strips it — accepted with this note). Zero US flags in eras 1-2: plain-pennant phrasing + clean roots are holding. |
| 2026-07-13 | **Buildings era waves 3-5: §8 pressure scales with era modernity** — rejects per wave: e3 3/48, e4 12/48, e5 21/48 (modern buildings ARE signage carriers: every bank chain grew gold name lettering, every debt office printed TREASURY BOND, medical grew red crosses twice). Countermeasures that ended each loop, now standing rules: (1) **contents-only subjects** — no profession/function nouns anywhere ("public hospital", "conscription office", "investment bank", "broadcast station" all printed themselves); (2) **occupy the fascia with an emblem** (caduceus / sunburst / bronze ledger / golden bull) — a named centerpiece both fills the sign spot and keeps the building readable; (3) **props with real-world liveries drag their symbols in** (ambulance → red cross, marching drums → uniformed band + tricolor) — prefer static architectural props. The caduceus is the approved neutral medical marker (protected red cross is never acceptable). All 5 problem subjects converged in one re-roll round after rewriting; final state 48/48 clean per wave. |
| 2026-07-13 | **Buildings era wave 6 closed (17/48 rejects over two re-roll rounds; final 48/48 clean) — the era-modernity signage curve peaked and the countermeasure hierarchy is now clear.** (1) **Occupying the signage surface beats rewording**: every bank facade printed neon name text until the subject covered the facade edge to edge with one giant chart (then 4/4 clean); same for the arsenal roofline railgun. (2) **The framing-suffix word "game" prints verbatim** on neon/billboard surfaces in late eras (earlier: chip faces) — it cannot be reworded away since the suffix is locked; occupy the surface instead. (3) **Real-world flags cluster on government-adjacent buildings** (US, Spain-pattern, starred red on palaces/debt offices); "plain golden pennants on the roof" fixed 3/3. (4) The religion rule caught a **lineage-inherited cross** (media center descended from the e3 cathedral). (5) New low-grade artifact: background contamination (doodles/ghost objects) — freeze-time speck filter handles small marks; pervasive cases get re-rolled. Generation for all 12 building lines is COMPLETE: 74 icons + 76 building sprites §8-clean; line-pick gate open on 11 high-res lineage sheets (640px cells per the §9 rule). |
| 2026-07-13 | **Buildings gate round 1: 8 lines picked and frozen; 4 lines redesigned per human feedback, adding standing DESIGN rules** (beyond §8): (1) **cross-line tech-timeline consistency** — no line shows later-era technology than the line that owns it (media's satellite dishes at e5 clashed with astronomy owning dishes at e6; replaced with an antenna mast); (2) **prop fidelity at sprite scale** — "giant paper rolls" read as toilet paper; describe the machine, not the material; (3) **era N+1 extends era N's structure** rather than replacing it (commerce e6 = the e5 storefront plus a rooftop logistics extension); (4) **no finance-chart symbolism as architecture** (bank e6 green rising arrow read as a stock logo; replaced with a metallic tower); (5) **interiors are welcome** — debt line redesigned as see-through offices with era-appropriate officials visible at desks. Redesign §8 outcome: 69 images over 5 rounds, 29 text rejects — media is the highest signage-pressure line in the game (press/broadcast/social genres BEG for text); media ships 2 clean chains (71, 74) instead of 4. Dirty-parent propagation reconfirmed: a small e4 sign amplified into a giant e5 sign through img2img. |
| 2026-07-13 | **Bank + debt_office redesign closed: research-first subjects survive where invented ones don't.** A 12-query research pass (banca/thesauros/Exchequer/red tape/SWF history) replaced both lines' subjects with historically grounded, object-based iconography — beehive granary + hacksilver scales, sealed thesauros, green-cloth banca tables, vault doors, Exchequer chequered cloth + tally bundles, red-tape pigeonholes, bond-window queues, golden-tree SWF — and eras 1-4 then passed 24/24 first-roll (symbols that exist as OBJECTS render clean; invented symbolism invites text). The late eras still fought: 65 images total, 25 rejects, final 40/40 clean. New standing findings: (1) **named measuring instruments print their scales** — "thermometer with plain tick marks" grew gibberish numerals 4/4; describing the raw phenomenon instead ("tall glass tube of glowing red liquid in a plain dark wooden frame") went 4/4 clean; (2) **outdoor entrance props inflate into co-subjects** (ticker-tape machine became a whimsical centerpiece 8/8 across two wordings); moving the prop indoors — "visible in the lobby through the arched entrance window" — shrinks it to prop scale and occupies the window surface; (3) **side annexes in an img2img parent morph into companion mini-buildings/mascot objects at the next era** (pagoda, brick house, model city, robots at e6); "standing alone on a wide empty stone plaza" + the pennant clause killed the class; (4) finance-institution subjects carry the game's highest logo/flag/mascot prior (horse-head logo, currency-glyph signs, rainbow/EU-star flags, robot mascots — all §8-rejected on sight). Chain-pick gate open on the two rebuilt 640px lineage sheets. |
