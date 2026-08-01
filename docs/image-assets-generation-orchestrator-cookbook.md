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
- **Capture learnings** where they belong: a stabilised rule goes into the section that owns it
  (§3, §4, §6, §8), and only a not-yet-doctrine finding goes in §14, under its three-sentence
  format rule. A negative result recorded honestly is a valid result.

## 1. Relationship to prior docs

- **`insignificant-game/design/`** (see repo `CLAUDE.md`) is the source of truth for *what* to
  draw: `營運` (building lines × 6 eras), `卡牌` (card list + era evolution), `時代與回合`
  (the six eras), `對手文明` (5 automa civs), `結局` (epilogue scenes), `經濟與債務`/`幸福` (the
  stats that need icons). Build the asset inventory from these docs, never from memory.
- `insignificant-game/` is the delivery target: Godot 4.6, Forward+; target resolution Full HD
  1920×1080 (§10).

## 2. Hardware reality (Mac Studio, M2 Max, 96GB unified memory)

- 96GB unified memory means **memory is not your constraint; compute speed is** (the 25GB
  production checkpoint loads with room to spare). That holds while you are rendering. It stops
  holding the moment you are not: an idle server keeps ~58 GB of the machine, so §4's rules on
  releasing memory between rounds and shutting the server down at the end of a session are what
  keep this bullet true.
- Measured production timings (style bible §2): **~170 s/image @1024²**, scaling roughly with
  pixel count (divider 1024×256 ≈ 39 s, button 1024×512 ≈ 78 s, card 768×1024 ≈ 118 s).
  Batch-and-review, not interactive — an overnight run is a few hundred candidates.
- Apple Silicon runs via **PyTorch MPS (Metal)**. CUDA-only custom nodes/tooling will fail —
  treat any CUDA-only dependency as a red flag and find the Metal path.
- Long batches: run under `caffeinate -i` so the machine doesn't sleep mid-batch.

## 3. Environment setup (fresh machine → working pipeline)

Verify current versions/URLs at setup time; pins below were sane as of 2026-07. Record anything
you install differently in the "installed layout" subsection below, not as a findings row.

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
curl -s http://127.0.0.1:8188/system_stats | head -c 300   # the launchd service, see below)
```

Install **ComfyUI-Manager** (`git clone https://github.com/ltdrdata/ComfyUI-Manager custom_nodes/comfyui-manager`)
for custom-node management.

### Installed layout on this machine

- ComfyUI git clone at `~/imagegen/ComfyUI`, running as the launchd service
  `com.insignificant.comfyui` (KeepAlive + RunAtLoad; logs in `~/imagegen/logs/`; manage with
  `launchctl kickstart -k` / `bootout gui/$UID/com.insignificant.comfyui`). The dormant Comfy
  Desktop app also wants port 8188 — never open it while the service runs.
- Models resolve via `extra_model_paths.yaml` to `~/ComfyUI-Shared/models/<kind>/`; outputs land in
  `~/ComfyUI-Shared/output/`.
- **Run pipeline scripts with `~/imagegen/ComfyUI/.venv/bin/python`** — it has Pillow and numpy;
  system python3 does not.
- **Every pipeline command starts with `cd .../insignificant-game/assets/pipeline &&` in the SAME
  shell command.** Background tasks spawn at the repo root and ignore the foreground shell's cwd
  entirely, and the foreground cwd drifts too; relative-path launches then fail with "can't open
  file".
- The rtk Bash hook mangles large JSON piped through inline one-liners — write API responses to a
  file first, or use `rtk proxy`.
- **Reproducibility is per-environment.** The same seed is bit-identical *within* one install but
  not across torch versions (visually identical, 26-71% of pixels drift slightly). Pin the
  environment for any asset family in progress, and re-anchor img2img lineages after a torch
  upgrade. Compare pixels, not PNG bytes: ComfyUI embeds workflow metadata in the file.
- **A PNG's embedded workflow metadata is render-time truth.** Freeze scripts read prompt, seed,
  denoise, and lineage from it, so manifest rows stay honest even after a batch's wording iterates
  past what a picked seed actually rendered with.

### Model kit

The locked recipe's four files are the **only models installed** (hashes in style-bible.md §7;
they live in `~/ComfyUI-Shared/models/`, see §3's installed layout). Re-download with
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

### Batch driver discipline

Every rule here was paid for by a lost or corrupted run.

- **Detach every multi-hour batch from the agent harness.** Harness background tasks are reaped at
  ~10 minutes, which has killed drivers mid-run while their ComfyUI jobs completed unrecorded. Use
  `nohup caffeinate -i sh runner.sh > runner.log 2>&1 & disown`, keep harness tasks as log
  *watchers* only (grep for gate lines), and give every batch script a resume guard — skip outputs
  that already exist, skip state-recorded cells — so a relaunch is free.
- **A detached driver looks dead when it isn't.** Python stdout to a redirected log is
  block-buffered, so a healthy driver's log can sit at a bare job-gate line for 20+ minutes.
  Diagnose in this order: `pgrep -fl <driver>` for liveness, decode `GET /queue` (each item's
  SaveImage `filename_prefix`) for what is actually queued, and only then resubmit what is genuinely
  missing. Resubmitting a "lost" job double-queues it against the live driver.
- **Dedup recovery order matters:** kill the redundant drivers *first* (a poller whose job is
  deleted retries and resubmits), then `POST /queue {"delete": [prompt_ids]}` for the surplus,
  keeping the copy whose driver writes chain state.
- **Chain-state JSON is clobber-prone.** Every driver exit dumps its stale in-memory dict, which has
  reverted sibling cells and silently eaten hand-edits. Run `pgrep -f <driver>` before every state
  edit *and* every dependent launch, and verify the parent cell in the JSON immediately before
  launching a child. A queued render's true parent is verifiable by decoding its workflow JSON
  (LoadImage `image` + SaveImage `filename_prefix`).
- **Every re-roll bumps its seed by +100, even when only the prompt changed.** ComfyUI increments a
  same-stem re-roll to `_00002_` while chain state, sheets, and img2img all read `_00001_`.
- **A per-chain prompt edit on a shared text slot needs an AST-based source-span edit** (parse,
  locate the exact list-index literal, replace by line/column), not a string replace: a chain's
  stored `prompt` can be stale against the current file whenever a sibling most recently overwrote
  that shared slot.
- **`done in` times include queue wait**, not just render time. A 1365 s line is a busy queue, not a
  slow GPU.
- **Release model memory between long rounds, never mid-batch.** Verify `/queue` is empty, then
  `POST /free {"unload_models": true, "free_memory": true}` or kickstart the service. Resident
  ~60 GB after mixed model use is designed caching, not a leak, but memory pressure has once
  SIGTERM'd the server mid-job. `--disable-smart-memory` is rejected as a default: per-job reload
  roughly doubles batch wall-clock.
- **Shut the server down when the session's generation is finished, not just between rounds.** An
  idle ComfyUI holds ~58 GB of a 96 GB machine (measured, peak 68 GB) and never gives it back while
  the process lives, because that is the same designed caching the bullet above describes. The human
  works on this Mac; leaving the server resident overnight for a round that may never come costs
  them most of the machine. Restart is one command, so the default is down:

  ```bash
  curl -s http://127.0.0.1:8188/queue     # confirm BOTH queues are empty first
  pkill -f "imagegen/ComfyUI/.venv/bin/python main.py"
  # restart, headless, detached (the launchd agent com.insignificant.comfyui is disabled on this
  # machine; leave it that way, and mirror ALL of its args by hand):
  cd ~/imagegen/ComfyUI && nohup .venv/bin/python main.py --listen 127.0.0.1 --port 8188 \
    --output-directory ~/ComfyUI-Shared/output --input-directory ~/ComfyUI-Shared/input \
    >> ~/imagegen/logs/comfyui.log 2>&1 & disown
  ```

  Both details are load-bearing. The **kill pattern must match the real command line**: the server
  is launched from inside `~/imagegen/ComfyUI`, so its args read `main.py`, not `ComfyUI/main.py`,
  and the obvious pattern silently matches nothing while `pkill` still exits 0. Verify the port is
  actually dead rather than trusting the exit code. And the **two directory args are not optional**:
  without them output lands in `ComfyUI/output/`, while every pipeline script and every `rendered()`
  resume check reads `~/ComfyUI-Shared/output/` — a batch would re-render work it had already done
  and find none of it.

  The gate is the queue, not the clock: a shutdown mid-batch loses every job still queued, and
  those jobs are hours. Stay up only while something is actually rendering or a pick round is
  expected to produce a re-roll within the same session.
- **§8 review scales through parallel subagents**, at roughly 1/200th the orchestrator's context
  cost, and they reach for objective tests an eyeball skips (per-border pixel diffs to prove a
  barrel crosses the canvas edge, pixel connectivity to tell an enclosed hole from an edge notch).
  Two hard requirements: **each concurrent reviewer gets a private crop directory and stem-named
  files** (ten agents sharing one scratchpad overwrote each other and reported other lines' defects,
  costing a whole round), and reject rules must be narrow, because an over-broad rule induces false
  rejects. **A failed reviewer is a re-dispatch, not a re-roll** — reviewers never touch chain
  state. Treat a surprising verdict as possible instrumentation error before acting on it, and
  zoom-verify every reject against the actual PNG yourself before accepting it.

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
  at low denoise, so the lineage visibly persists and only era-specific features change. Pick the
  denoise from the transition type, not by habit — see §6.1.

**Lever hierarchy — always exhaust the cheaper one first:**
1. Frozen templates + runtime compositing (this section)
2. Locked style-bible recipe: Krea-2-Turbo + Moebius LoRA @1.0 + the subject-only prompt block (style bible §2-§3; no palette quantization, §5)
3. Seed families / img2img lineage (same base seed or init image across a family)
4. IP-Adapter style reference (zero-shot, weaker on fine detail)
5. Custom style LoRA trained on our own approved set — **escalation, human decision** (§12)

### 6.1 img2img lineage levers — classify the transition BEFORE the wave

Era N's approved sprite seeds era N+1, so **an artifact propagates down the whole chain**: §8-gate
every era before it seeds the next. Carry-through has four distinct mechanisms needing different
levers, and pre-classifying each transition instead of running everything at 0.55 and re-rolling
roughly **doubled** first-pass yield (82% against ~40%).

| Transition from era N to N+1 | Lever |
|---|---|
| Same category; material or feature change only (sandbag wall → concrete bunker) | **denoise 0.55.** No inheritance tax — structure lines are the cheap, reliable bucket. |
| A dominant parent **object** or **pose** must be shed, count preserved | **denoise 0.70.** Object identity and pose inherit *separately*, so wording that replaces the noun leaves the verb untouched. |
| Category or **count** reversal, or a silhouette sharing nothing with the target | **txt2img root.** No denoise dissolves this. Tag `"root": true`; the seam is permanent and must stay visible to sheets and manifest. |
| Neither lever clears it after one full round | Break the lineage, or close the cell short (§8.3 step 4). |

- **0.70's cost is framing adherence**, and it scales with how wide the composition already sits:
  compact subjects broke 0 of 6, wide ranks broke 4 of 4. A targeted rescue, never a default.
- **Wording can suppress an artifact the parent does not contain, but not one it does.** If the
  parent's own prompt specifies the offending object, no child phrasing removes it.
- **Parent composition can outweigh wording.** When one chain fails a wording that sibling chains
  pass first-roll, retire the parent rather than writing a fourth wording. Diagnose
  parent-versus-wording by comparing sibling chains *before* burning wording versions.
- **A dirty lineage rebuilds from the root.** Micro-inventions (~30 px) amplify differently in every
  child, so mid-chain whack-a-mole never converges. Take 6-8 zoom crops (3-9×) over the path,
  mid-band, and all corners before locking any parent.
- **Audit era N against era N-1 before the wave.** Un-audited lines yielded 27% first-pass against
  54% audited. An unnamed slot is where the parent's version persists by default, so name every slot
  the parent fills, even when the answer is "bare head". Mind that a line whose start era equals the
  wave era is a txt2img root with no parent at all.

## 7. Phase plan

Phases are gate-ordered: **never claim a later gate before an earlier one holds.** A dynamic
workflow may interleave work, but gates close in order. **This section is the single
current-state status surface**: one status phrase per phase/class here; dates, pick numbers,
and evidence live in git history and `manifest.jsonl`. Update the status phrase whenever a gate moves.

**Phase 0 — Bring-up** (**closed**): ComfyUI serving the JSON API with reproducible seeded
workflows; install layout in §3, timings in §2.

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
1. **UI icons** (**closed**: all 75 glyphs frozen in `assets/approved/icons/`) — glyphs on the
   frozen base plate. Judge icon expressiveness at 44px HUD size, never at sheet size (§8.4).
2. **Buildings & units ×6 eras** — the volume class. Per building line: era N approved sprite
   seeds era N+1 via img2img lineage (§6); **era-gated waves** (`phase3_buildings_wave.py` +
   `phase3_building_chains.json`): each era is §8-reviewed before it seeds the next, because
   artifacts propagate down chains (§6.1). Buildings: **closed** (76 sprites frozen in
   `assets/approved/buildings/`: the 12 building lines plus the core line). Units (incl.
   fortifications and enemy tiers): **closed** (69 sprites frozen in `assets/approved/units/`
   via `phase3_units_freeze.py`; one lineage per line, with three human-ruled cross-chain
   divergences and `infantry_era4` left as a known gap). **A top-down re-render of the whole
   battlefield roster is open** (ADR-0009, PLAN.md W14.8): 70 cells × 4 seeds as txt2img roots with
   no era gates — the lineage classification and its cost are argued in
   `phase3_units_topdown_sweep.py`'s header — plus the 7 `bg_battle_*` plates rewritten as ground
   planes. Camera-specific review rules: `review-brief-units-topdown.md`. The side-view set stays
   frozen and wired until the human picks. Full round history, the pick record,
   The closed-short set is the §14 live row; the round-by-round record is in git commit messages.
   Era-3 wording is authored under the positive-slot rule (§8.3): **never name a
   banned object, describe the desired slot** — prohibitions measurably backfire at cfg 1.
3. **Card illustrations** (**closed** — 57 frozen in `assets/approved/cards/`) — 57 cards per
   `卡牌`, produced as txt2img dramatic scenes (the Phase 1 anchor is a battle scene, not a sprite);
   unit/fort card cores lifted from the approved unit prompts and reframed hero-forward, skill
   cards fresh conceptual subjects. The full 171-cell sweep was §8-reviewed, the human ran the full
   pick pass (`PICKS`, one seed per subject), and 8 subjects were re-cut over two re-roll rounds
   (`REROLLS` / `REROLL2`) before all 57 froze via `phase3_cards_freeze.py` (straight full-frame
   768×1024 copy like backgrounds — no keying; the frame window crops the bottom signature band at
   runtime). Registry wired in `core/data/asset_paths.gd` (`CARD_DIR`, `CARD_COVERAGE`,
   `CARD_SKILLS`, `card()` / `card_skill()`), swept by 3 new `asset_paths_test.gd` cases (Part A
   197/197). Full pick record + gate decisions (anti_air_era5 clean-swap, bomber accepted as-is) in
   The pick record is in `manifest.jsonl` and git history.
4. **Backgrounds & portraits** — low volume, large canvas; generated under the style-bible recipe
   like everything else (~170 s/image on Krea 2 is fine at this volume). Scope follows the
   three-scene model (style bible §11, corpus 場景呈現 sections): per-era city plates, the route
   fog-map plate, one battlefield per battle type, title + endings — 17 plates in
   `inventory.md` Backgrounds. Landscape subjects REQUIRE the style-carrying suffix (§8.4)
   or they render photoreal. Backgrounds: **closed** (all 17 plates frozen in
   `assets/approved/backgrounds/`; picks and freeze in git history). Portraits: **closed**
   (all 15 frozen in `assets/approved/portraits/`: 5 rival-class + 10 democracy-candidate leader
   portraits, v2 understated-leader re-direction after v1's trope-heavy archetypes were rejected).
   Registry wired in `core/data/asset_paths.gd` (`PORTRAIT_DIR`, `PORTRAIT_CIVS`, `PORTRAIT_CANDIDATES`,
   `portrait_civ()` / `portrait_candidate()`), swept by 2 new `asset_paths_test.gd` cases that also
   assert the lists match `RivalData.CLASSES` / `CandidateData.CANDIDATES` (Part A 199/199). Frozen
   FULL-FRAME like cards, NOT keyed like units: the style-carrying suffix renders a watercolor wash
   that hard-keys into ragged halos, so the wash ships as a painted-portrait background (view frames
   them). The photoreal-suffix rule is §8.4; the re-direction and freeze record are in git history.

**Phase 4 — Godot integration**: §10, runs per approved class. Target resolution: **Full HD
1920×1080**. First pass is in (`core/data/asset_paths.gd` registry, Noto Sans TC subsets,
runtime-composed chrome in `view/main.gd`, window 1920×1080; Part A + Part B green) — each later
approved class wires in through the same registry, capture reviewed with the same Part-B
discipline. Buildings are wired: the operate panel renders a city strip (core center at the
current era + each built line's tier era-form sprite, swapped by id).

## 8. Objective self-checks (before an image reaches the human)

You own the objective pass; the human owns taste. **What you must NOT judge:** whether an image is
pretty, on-theme, or the best of its batch.

**Hard rejects, re-roll without asking:** silhouette unreadable at ship size; wrong aspect or
framing, or doesn't fit its frozen template rect; alpha halos after keying; subject mismatch against
`inventory.md`; anatomical breakage (extra limbs, fused figures); **count drift** (more or fewer
copies of an object than the prompt names); **readable-surface marks** — lettering, insignia, sign
panels, plaques, inset roundels; **real-world or protected symbols** (national flags, the
Geneva-protected red cross, specific-country allusions, which also violate the corpus parody rule
不影射特定現實國家); era variant that doesn't visibly differ from its neighbours.

**Passes, with a note:** blunt panel-less posts, pillars, and gates; costume deviation from a sibling
chain; anything still ambiguous at 9-14× zoom, because ambiguity is not a confident defect.

There is **no negative-prompt lever at cfg 1** (§0), so reject-and-rewrite is the only control, and
the rewrite follows the ladder in §8.3.

### 8.1 Zoom before every verdict

Ambiguous micro-objects get a crop and a 3-9× resize (PIL) **before** any verdict is recorded. This
flips readings in both directions: a kneeling figure resolved to a flower cluster and a smoke plume
to a cloud bank, but wall marks also resolved to crisp letter rows. Zoom the corners and any open
foreground band every time — the fake-signature class runs hottest exactly there.

### 8.2 Artifact classes and their current countermeasure

| Class | Where it shows up | Countermeasure |
|---|---|---|
| **Invented text / signage** | any flat blank surface: fascias, chip faces, box and document fronts, banners, hull sides, costume bands | Occupy the surface with a named object or a plain unbroken colour. Never name the contents' job title — "clinic", "investment bank", "broadcast station", "conscription office" all print themselves; name what is inside instead. |
| **Insignia on a blank surface** | caps, sleeves, pauldrons, pennants, wings, turrets | Occupy with a benign **sanctioned** mark (a cockade, a plain band, the golden tree). An object holds; a painted "plain circle" oscillates through roundels and chevrons. |
| **Real-world / protected symbols** | government-adjacent buildings, finance lines, medical, military costume | Hard reject. Approved neutral substitutes: **caduceus** for medical (never the red cross), **golden tree** for religion, **plain golden pennants** where flags keep appearing. |
| **Fake artist signature** | bottom band of painterly renders; open foreground on landscape plates | No prompt lever. Keyed classes: the freeze-time speck filter strips it. Cards: the frame content window crops the bottom band, so it never ships (§8.4). Flat comic-mode renders don't produce it at all. |
| **Whimsy / background contamination** | empty terrain bands, blank roofs, open canvas beside a falling object | Occupy the band; plain seed re-roll for one-offs; re-roll pervasive cases. |
| **Prompt-induced symmetry** | "a rank of" + identical figures + a level-held object merging into one bar | Break the geometry — stagger the line, stand the object upright, tuck it under one arm. Naming whose hands hold it does **not** work. Present identically at every denoise, which is what proves it is self-inflicted rather than inherited. |
| **Mascot / emoji collapse** | emotion-noun subjects ("an angry rioter") | Name the person and their props, never the emotion. |
| **Action-prior leak** | unfamiliar weapons ("slingers whirling slings" renders bows 4/4) | Name the mechanism, not the action, and anchor every loose part to a named hand on the body rather than to the tool. |
| **Measuring instruments** | thermometers, gauges, scales | Describe the raw phenomenon, not the instrument, or it prints gibberish numerals. |
| **Overlapped-rank face occlusion** | side-view ranks, where figure N's weapon lands on figure N+1's face | Composition is seed luck; re-roll under the same wording. |

### 8.3 The wording ladder (work down it; stop at the first rung that holds)

Established by controlled comparison across the units eras. Rung 1 **reverses** the earlier habit of
pinning counter-wording, and rung 4 bounds rung 1.

1. **Describe the desired slot positively. Never name a banned object.** With no negative-prompt
   lever, a banned token still conditions the image: "no blades" reads substantially as "blades".
   Head-to-head on one defect class the same day, all 3 positive rewrites fixed their cell and all 3
   prohibitions failed, 2 measurably worse — one glowing tube became two, four arrows became seven
   blades plus sparks. This is also why denial-only pins ("empty", "deserted") keep breeding
   occupants: they leave the surface unnamed.
2. **Occupy the slot with a benign sanctioned occupant.** An unnamed slot is where the checkpoint's
   favourite persists by default.
3. **When a fix displaces the artifact into the same family rather than removing it, that is a stable
   model preference, not a wording bug.** Expect migration: a fixed sleeve pushes the mark to the
   pennant, a fixed chest pushes it to the shoulder. Name the preference in benign form early instead
   of trying a fifth occupant, and treat migration as the signal to stop and close short.
4. **Against an unusually strong prior, naming the concept at all — even to negate it — is
   counterproductive, and there may be no wording fix.** One line's insignia went: bare circle →
   badges; negations → a ring grew anyway; fully enumerated negations → an unmistakable RAF-style
   roundel; every concept word removed → a Soviet star *plus* a roundel. **Diagnostic: when two
   consecutive different strategies (one negation-heavy, one concept-avoidant) both fail as badly or
   worse than the wording before them, stop.** That is checkpoint-level bias. Record it as a
   closed-short dead end and escalate (§12); it needs a design relaxation or a tooling lever
   (inpainting, region lock, touch-up), never another wording round.

Four corollaries:

- **Count drift converges with an explicit counting frame**, not negation: "exactly three spears
  total and no more". This reliably converges duplicate *objects*; it does **not** reliably converge a
  duplicate shape *detail* on a single object once that prior is strong. Two failures on the same spot
  after a counting fix means stop.
- **A wording simplification needs the same audit as a wording fix.** Deleting prose can delete a
  constraint that was silently preventing a defect.
- **Check that the target location is actually visible in the pose** before re-wording a mark that
  won't appear. No phrasing puts a mark on an occluded chest.
- **A closed-short cell does not spontaneously converge because unrelated nearby wording changed.**
  Only a genuinely different approach to the same defect is worth another attempt.

### 8.4 Per-class notes

- **The framing suffix carries the style, and a bare subject loses it.** "game building sprite",
  "game unit sprite", and "game card illustration" all trigger the LoRA. A **bare landscape or a
  formal bust renders photoreal**, and both need an explicit medium-naming suffix ("hand-painted …,
  watercolor and ink illustration, soft flat colors, clean line work"). This is the one sanctioned
  exception to §3's no-art-style-descriptors guidance: it applies to photoreal-prone subjects only,
  and it changes the tunable suffix, never the locked recipe.
- **The locked suffix's own words print verbatim** on neon, billboard, and chip surfaces ("game",
  "era"). The suffix cannot be reworded, so occupy the surface instead.
- **Insignia are desirable on card hero art and rejected on sprites.** Same mark, opposite verdict —
  judge against the class, not a global rule.
- **A heading stated only in the framing suffix is not reliably obeyed by a SINGLE-figure subject;
  front-load it into the subject clause.** The top-down exploration found "facing toward the right"
  as a trailing clause ignored across a whole line, and the W14.8 roster audit found lone figures
  rendering face-on to the camera under a suffix naming the opposite, fixed 4/4 seeds by moving the
  heading into the subject ("striding toward the right edge of the frame"). Multi-figure groups and
  vehicles do not need it — the rank or the hull already states a direction — so this is a rule about
  subjects with no internal geometry to imply heading, not about suffixes in general.
- **Icon expressiveness is judged at 44 px HUD size**, never at sheet size.
- **Three freeze patterns; do not mix them up.** Icons, buildings, and units **key** to transparent.
  Cards and portraits ship **full-frame** — cards because they are dramatic scenes whose bottom band
  the frame crops, portraits because watercolor's feathered edges will not take a clean alpha key.
- **Design rules beyond §8, established at the buildings gate:** no line shows later-era technology
  than the line that owns it; describe the machine, not the material (giant paper rolls read as toilet
  paper); era N+1 extends era N's structure rather than replacing it; no finance-chart symbolism as
  architecture; interiors are welcome; era-form subjects must name era-appropriate objects (a "weapon
  rack" in era 1 drew rifles).

## 9. Review loop, provenance, repo layout

### Vocabulary (use these words; they have been muddled before)

| Term | Means |
|---|---|
| **candidate** | One generated PNG. Lives outside the repo in `~/ComfyUI-Shared/output/<batch>/`. Never committed, never referenced by Godot. |
| **cell** | One asset slot in the inventory — a subject at an era, e.g. `unit_archers_era4`. A cell is rendered as several candidates (one per seed) and exactly one is picked. |
| **seed sweep** | The set of candidates for one cell: same prompt, different fixed seeds. The unit of choice at a gate. |
| **contact sheet** | The committed review grid in `contact-sheets/`: a labelled montage of candidates with their manifest ids under each cell. **This is the review unit** — the human replies with picks and rejections against it. Cells stay ≥ 640 px on the raw's long side, because the human zooms in. |
| **pick gate** | The human review step itself. Nothing enters `approved/` without one. |
| **freeze** | Copying a picked candidate into `approved/<class>/` under its inventory id, applying the class's post-process (key to transparent, or full-frame), and writing its `manifest.jsonl` row. |
| **background plate** | A full-frame scene image that renders *behind* the sprites, id scheme `bg_*`, asset class "Backgrounds" in `inventory.md`. **"Backdrop" and "plate" are prose synonyms for this and nothing else** — prefer "background plate" in new writing. A plate is not a sprite: it ships full-frame, never keyed, and carries an empty band where sprites composite. |
| **frozen template** | A structural asset generated once and never regenerated (§6): card frame, panel, button, divider, icon plate. Distinct from a picked asset, which is merely approved. |


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

- **Render resolution: Full HD 1920×1080** — the game window runs it (wired with the first
  approved classes); core is resolution-blind (`insignificant-game/docs/architecture.md`). Assets are high-res
  illustrations — default (linear) texture filtering, lossless PNG import. Templates record
  rects/margins relative to the generated image, not screen pixels — scaling happens in-engine.
- **The registry is `core/data/asset_paths.gd`** (pure id→path table + frozen-template geometry,
  test-pinned to disk): new approved classes slot in by the same id scheme
  (`icon_<id>` / `building_<line>_era<n>`); the view loads textures, core never does.
- **Composite, don't bake** (§6): cards/panels are scene trees — frozen frame texture +
  illustration texture + `Label` text (UI font, §6) — never single baked PNGs. `view/main.gd`
  holds the working patterns (styleboxes from templates, glyph-on-plate badges, card widget).
- Wire assets data-driven (path derived from id + era), matching the pure-core architecture —
  read `insignificant-game/CLAUDE.md` and `insignificant-game/docs/architecture.md` before touching scenes, and
  run **both loop parts** (headless tests + Part B capture) after wiring.
- Keep the design doc `code:` frontmatter convention: if you add asset tables/modules, map them.

## 11. Apple-Silicon pitfalls (verify, don't assume)

- **CUDA-only custom nodes** (some ControlNet preprocessors, xformers) fail on MPS — check a
  node's issues for Mac support before adopting it.
- First generation after model load is much slower (Metal shader compile) — never benchmark run #1.
- The server caches models in-process and MPS holds freed tensors until process exit — after each
  batch session (verify `/queue` is empty first, **never mid-batch**), release memory via
  `POST /free` or a service kickstart, and shut the server down once the session is done
  (§4 batch driver discipline).
- **`ps`/Activity Monitor understate this process by more than 10x.** MPS allocations are
  IOKit-backed rather than resident anon pages, so an idle server reporting `RSS=3.7 GB` was
  actually holding 58 GB. Measure with `footprint -p <pid>` and read `phys_footprint`; never
  reassure anyone about memory using an RSS column.

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

## 14. Findings log

**This log is only for findings that are not yet doctrine.** Once a finding stabilises into a
rule it belongs in the section that owns it (§3 environment, §4 driving and ops, §6 consistency
and lineage, §8 artifact classes and wording) — move it there and delete the row. A gate that
closed, a batch's reject tally, a seed that got picked: that is history, and history lives in git
commit messages and `manifest.jsonl`. Phase status lives in §7, one phrase per class.

**Format, enforced: one row, three sentences at most.** State the finding, the evidence that
established it, and what to do about it. No round-by-round narrative, no per-cell tallies, no seed
lists. If a row needs more than three sentences it is doctrine — promote it and cite the section
instead. If a new finding contradicts an older one, **delete the older row**; do not stack a
correction on top of it, because this repo's docs describe current state, not changelog.

| Date | Finding |
|---|---|
| 2026-07-21 | **Five cells are reproducible prompt-wording dead ends for this checkpoint/LoRA/subject combination, frozen with the defect accepted by human ruling** (`"rejected": true` in chain state, `status: "rejected"` in the manifest): bomber era4-6 insignia, enemy_hard era5 running-gear rust, artillery era6 hull-light glow, archers era4/era6 chain 81 marks, elite_forces era6 chains 82/83 insignia. Each failed four wording generations across two opposed strategies, which is the §8.3 stop signal. Resolving any of them needs a design relaxation or a tooling lever (inpainting, ControlNet region lock, manual touch-up), never another wording round. |
| 2026-07-21 | **Per-cell replacement prompts introduce cross-chain DESIGN divergence, a class no wording fix addresses.** Because replacements are authored per rejected cell rather than per line, sibling chains of one line drift apart (a lone figure vs a group of three, a dropped accent colour, a weathered vs clean paint convention), and a camera-angle instruction layered onto the fixed side-view convention does not reliably take. Flag this distinctly from a technical defect and take it to the human. |
| 2026-07-29 | **A wide frame plus scene language yields a receding ground plane, no matter how hard the prompt asks for an overhead camera; the fix is REGISTER, not vocabulary.** A 2×2 probe pinned it: the same cobble prose recedes at 1920×1088 but renders flat at 1088×1088, while a checkerboard renders flat at both, so neither the material nor the aspect does it alone — a wide frame plus "a flat expanse of X … under uniform overcast light" reads as a landscape photograph and the model supplies a viewer to recede from. Ask instead for a repeating pattern of identical units ("a regular grid of cobbles, every cobble the same size as every other"), drop "expanse", the viewer phrase and the lighting condition, and it renders flat at the shipped aspect; the same rewrite fixes tapered fortification sprites, which are the same defect wearing a different hat. |
| 2026-08-01 | **A set of long straight parallel lines is a perspective trigger by itself, independent of register.** The last plate still receding named plough furrows; restating them as a pattern against the frame ("crossing the frame from side to side at a constant spacing") converged *harder* than the wording it was meant to fix, and only removing the furrows outright — occupying their space with soil detail per §8.3 rung 1 — rendered flat, after which the model still supplied implied planting rows at constant scale. So in a flat-texture core, never name a long-line feature (furrow, lane, rail, seam, row): describe the material and let the lines emerge. **Corollary, and it is the expensive half: when the SUBJECT inherently is a pair of long parallel lines — a crenellated wall-walk, a rail bed, a colonnade — no wording removes the trigger, because you cannot describe the subject without it.** A crenellated wall-walk failed five rounds and twenty seeds across both a rewritten core and an img2img parent, always the same way: viewpoint slides to the end of the corridor and the segment runs off the frame. Recognise this class early and take it to the human as a subject-change question (§9's "only a subject change can fix this" rule), because every wording round spent on it is guaranteed waste. |
| 2026-08-01 | **Uniformity has to be un-asked positively, exactly like absence.** The register fix above over-corrected — "an even repeating pattern of X, every X the same size as every other" turned irregular materials into mechanical tilings (mud ruts became a lattice of identical quilted lozenges) — and two probes split the cause: deleting the per-core scale-constancy clause is free (the style tail's own scale sentence keeps the plate flat), while the fix for the tiling is to state the variety you want ("ruts of many different lengths, widths and depths running in every direction and crossing over one another"), which renders irregular AND flat. §8.3 rung 1 generalises: occupy the slot, whether what you are removing is an object or a sameness. |
| 2026-07-23 | **`infantry_era4` is a known unit-sprite gap** — its era-4 render closed short with no sibling chain to promote, and the view placeholders that one slot. The cards class authored infantry era4 fresh, so `CARD_COVERAGE` has no equivalent hole. |
