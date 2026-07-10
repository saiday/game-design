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
| Commercial status | Hobby / undecided — but **prefer permissively-licensed models anyway** (SDXL, FLUX.1-schnell, Z-Image-Turbo, Apache/MIT LoRAs) so a later commercial pivot doesn't invalidate assets. Non-permissive weights need explicit human sign-off. **Signed off: Krea 2** (Community License, commercial free only under $1M TTM revenue) as the production checkpoint, with the pivot risk surfaced — the sign-off record lives in style-bible.md §6; re-verify before any commercial release. | human |
| Asset scope v1 | All four classes: buildings/units ×6 eras, card illustrations, UI icons & frames, backgrounds & portraits | human |
| Orchestration | Claude Code runs **on the Mac Studio** with this repo cloned; outputs reviewed via committed contact sheets | human |
| Backbone tool | **ComfyUI headless via its localhost JSON API**; production checkpoint = **Krea-2-Turbo + Moebius LoRA** (style bible); SDXL and Z-Image-Turbo stay installed as utility/fallback models (FLUX.1-schnell = fallback; **FLUX.2-dev rejected**: 32B is too slow on MPS and its dev license is non-commercial); **Pillow** for contact sheets and keying (no pixelization, §5); Draw Things = human spot-checks only, never the pipeline | this doc + human |
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

- 96GB unified memory means **memory is not your constraint; compute speed is**. SDXL-class fits
  trivially; FLUX-class fits comfortably.
- Expected order of magnitude (verify on-device at bring-up and record actuals in §14): SDXL 1024²
  ≈ tens of seconds/image; FLUX.1-schnell (4-step) ≈ a minute-ish; Z-Image-Turbo (6B, 8-step)
  should land between them. Batch-and-review, not interactive. An overnight run is hundreds of
  SDXL candidates — use that.
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

python main.py --listen 127.0.0.1 --port 8188   # headless server; keep in background
curl -s http://127.0.0.1:8188/system_stats | head -c 300              # liveness check
```

Install **ComfyUI-Manager** (`git clone https://github.com/ltdrdata/ComfyUI-Manager custom_nodes/comfyui-manager`)
for custom-node management; you'll need **ComfyUI-GGUF** if you use quantized FLUX.

### Model kit

Download with `uv tool install huggingface_hub` → `hf download <repo> <file> --local-dir ...`
into `ComfyUI/models/<kind>/`. **Check each license page at download time**; record hash + license
in the manifest (§9).

| Role | Model | Repo / file | License | Dir |
|---|---|---|---|---|
| **Production checkpoint** | Krea-2-Turbo | `Comfy-Org/Krea-2` → `krea2_turbo_bf16.safetensors` + `qwen3vl_4b_bf16.safetensors` (text encoder) + `qwen_image_vae.safetensors` (VAE) | **Krea 2 Community License — non-permissive, human-signed-off; see style-bible.md §6** | `diffusion_models/`, `text_encoders/`, `vae/` |
| **Production style LoRA** | Krea2 Moebius | `Urabewe/Urabewe-LoRA-Collection` → `Krea 2/Krea2_Moebius_LoRA.safetensors` | MIT | `loras/` |
| Utility checkpoint | SDXL base 1.0 | `stabilityai/stable-diffusion-xl-base-1.0` → `sd_xl_base_1.0.safetensors` | OpenRAIL++ (permissive) | `checkpoints/` |
| VAE fix (mandatory with SDXL on MPS) | fp16-fix VAE | `madebyollin/sdxl-vae-fp16-fix` → `sdxl_vae.safetensors` | MIT | `vae/` |
| Pixel-art LoRA (primary) | Pixel Art XL | `nerijs/pixel-art-xl` | check at download | `loras/` |
| Pixel-art LoRA (alternate) | PixelArtRedmond | `artificialguybr/PixelArtRedmondV2` (or V1) | check at download | `loras/` |
| High-fidelity source (primary) | Z-Image-Turbo | `Tongyi-MAI/Z-Image-Turbo` (verify repo name; ComfyUI native support was fresh as of early 2026 — verify MPS status) | **Apache 2.0** | per ComfyUI docs |
| High-fidelity source (fallback only) | FLUX.1-schnell | `black-forest-labs/FLUX.1-schnell` (or GGUF quant via `city96/FLUX.1-schnell-gguf` + ComfyUI-GGUF) + `comfyanonymous/flux_text_encoders` (clip_l, t5xxl) + FLUX `ae.safetensors` | **Apache 2.0** | `diffusion_models/`, `clip/`, `vae/` |
| Consistency lever (phase 2+) | IP-Adapter (SDXL) | `h94/IP-Adapter` + ComfyUI_IPAdapter_plus node | check at download | per node docs |

**Download order:** the workhorse trio first (SDXL + VAE fix + pixel LoRA — nothing works without
them), then Z-Image-Turbo. Skip FLUX.1-schnell unless Z-Image's MPS/ComfyUI path turns out broken
or its quality disappoints on real subjects — it fills the same low-volume role
(backgrounds/portraits source) at twice the parameter count (12B vs 6B).
Log the Z-Image verdict in §14. **Do not download FLUX.1-dev or FLUX.2-dev** (non-commercial
licenses; FLUX.2-dev is additionally 32B — unusably slow on MPS); either needs explicit human
sign-off per §0.

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
  resolution and scale in-engine. `pixelize.py` and `palettes/` stay in the repo as Phase 1
  provenance only — do not run them on production assets.
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

**Phase 0 — Bring-up** (**closed**, records in §14): §3 done; one SDXL image generated
via API round-trip with saved seed/workflow; **Z-Image-Turbo brought up and sanity-checked** (fall
back to FLUX.1-schnell per §3 only if it disappoints); record real timings in §14.

**Phase 1 — Style anchor** (human gate, the most important phase — **closed**; the lock lives in
`assets/pipeline/style-bible.md`. The steps below describe the gate's procedure; the
palette/grid proposals in steps 2-3 were not adopted):
1. Build the asset inventory from the corpus docs (§1) into
   `insignificant-game/assets/pipeline/inventory.md` — every needed asset, one line each.
2. Propose the **master palette** (3 candidates, e.g. from Lospec: endesga-32 / resurrect-64 /
   apollo — check each palette's stated license) and **sprite grid sizes** per class (a starting
   proposal: buildings 64×64, units 32×32, card art 96×128, icons 16×16, backgrounds 640×360;
   these are design calls — propose, don't decide).
3. Generate **style boards**: the same 3 subjects (one building across 2 eras, one card, one icon)
   rendered under 3 candidate style recipes (LoRA × prompt block × palette). Contact-sheet them.
4. Human picks. Lock the winner into
   `insignificant-game/assets/pipeline/style-bible.md`: the exact prompt block, LoRA + strength,
   per-class generation sizes, license sign-offs, and reference images. **Every later generation
   cites the style bible; changing it is a human decision.**

**Phase 2 — Templates** (human gate): generate and freeze the structural assets per §6 — card
frame(s) with recorded content-window rects, panel/button 9-slice sources, icon base plate.
Expect manual cleanup on chrome (image editor or Pillow scripting) — that's the
"semi-" in semi-generated, and it's allowed here precisely because it happens once.

**Phase 3 — Class pipelines**, in this order (volume × risk):
1. **UI icons** — glyphs on the frozen base plate; small, fast feedback; some icons may end up
   hand-drawn/vector restyled to the style bible (the allowed exception in §0 operating rules).
2. **Buildings & units ×6 eras** — the volume class. Per building line: era N approved sprite
   seeds era N+1 via img2img lineage (§6); cross-era coherence is an explicit contact-sheet check.
3. **Card illustrations** — per card in `卡牌`, produced to the frozen content-window rect;
   highest quality bar, human reviews in smaller batches.
4. **Backgrounds & portraits** — low volume, large canvas; generated under the style-bible recipe
   like everything else (~170 s/image on Krea 2 is fine at this volume).

**Phase 4 — Godot integration**: §10. Target resolution: **Full HD 1920×1080** (§10). Approved
assets composited and rendered in-engine, capture reviewed — same Part-B discipline as the code
loop.

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
  pipeline/            # style-bible.md, inventory.md, style-refs/, workflows/*.json, manifest.jsonl (pixelize.py + palettes/ = retired Phase 1 provenance, §5)
  contact-sheets/      # committed review grids (ImageMagick montage / Pillow), small
  approved/<class>/    # human-approved ship assets only — the ONLY dir Godot scenes reference
```

Raw candidates stay on the Studio **outside the repo** (e.g. `~/imagegen/candidates/`) — never
commit candidate piles. The review unit is the **contact sheet**: a labeled grid (manifest IDs
under each cell) committed to `contact-sheets/`, human replies with picks/rejections, picks get
post-processed into `approved/` with a manifest status flip.

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

- **Render resolution: Full HD 1920×1080.** The PoC window stays 1280×720 until Phase 4 wiring;
  core is resolution-blind (`poc-docs/architecture.md`). Assets are high-res illustrations —
  default (linear) texture filtering, lossless PNG import. Templates record rects/margins
  relative to the generated image, not screen pixels — scaling happens in-engine.
- **Composite, don't bake** (§6): cards/panels are scene trees — frozen frame texture +
  illustration texture + `Label` text (UI font, §6) — never single baked PNGs.
- Wire assets data-driven where possible (path derived from id + era), matching the pure-core
  architecture — read `insignificant-game/CLAUDE.md` and `poc-docs/architecture.md` before
  touching scenes, and run **both loop parts** (headless tests + Part B capture) after wiring.
- Keep the corpus `code:` frontmatter convention: if you add asset tables/modules, map them.

## 11. Apple-Silicon pitfalls (verify, don't assume)

- **Black/NaN SDXL outputs** → you're on the stock fp16 VAE; use `sdxl-vae-fp16-fix` (§3) or run
  VAE in fp32.
- **CUDA-only custom nodes** (some ControlNet preprocessors, xformers) fail on MPS — check a
  node's issues for Mac support before adopting it.
- First generation after model load is much slower (Metal shader compile) — never benchmark run #1.
- FLUX full-precision is slow on MPS; prefer **GGUF quants (Q8/Q6)** via ComfyUI-GGUF.
  Z-Image-Turbo is small enough that quantization may be unnecessary — verify.
- Memory pressure from many loaded models: restart the ComfyUI process between class batches
  rather than fighting the cache.
- If the PyTorch-MPS path underperforms badly for the FLUX-class role, **mflux** (MLX-native
  FLUX, CLI-driven, §13) is a scriptable fallback worth benchmarking before giving up on local.
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

- ComfyUI on Apple Silicon (MPS speed, optimization flags): https://www.workflowlab.dev/deploy/comfyui-mac-apple-silicon-mps-speed · https://smartart.live/articles/258-flux-comfyui-on-apple-silicon-complete-2026-guide-to-hardware-acceleration-gguf-models-memory-optimization.html
- Mac tool benchmark (Draw Things vs ComfyUI, Flux timings): https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/ · https://insiderllm.com/guides/stable-diffusion-mac-mlx/
- mflux (MLX-native FLUX): https://github.com/filipstrand/mflux
- Indie ComfyUI asset pipeline & pixel-art workflow: https://www.strayspark.studio/blog/comfyui-game-asset-pipeline-indie-2026 · https://www.seeles.ai/resources/blogs/ai-generate-pixel-art-game-assets
- Character/style consistency (LoRA / IP-Adapter / ControlNet): https://thinkpeak.ai/stable-diffusion-character-consistency-tutorial/ · https://www.lovart.ai/blog/complete-guide-consistent-ai-character-design
- Self-generating a coherent pack vs buying packs; consistency at scale via art-bible/style training: https://nilo.io/articles/ai-generated-assets-for-games
- Honest limits of AI 2D asset generation (single-frame strong; tilesets/animation weak): https://www.summerengine.com/blog/ai-2d-game-asset-generator

## 14. Findings log (append as you learn — keep this doc honest)

| Date | Finding |
|---|---|
| 2026-07-08 | **Install layout (differs from §3's git-clone plan — adapt, don't fight it):** ComfyUI runs as the **Desktop app** (`/Applications/Comfy Desktop.app`), backend at `~/ComfyUI-Installs/ComfyUI/ComfyUI/` with its own standalone venv (`~/ComfyUI-Installs/ComfyUI/standalone-env/`, Python 3.13.12, PyTorch 2.10.0, Pillow 12.2.0). It serves the **standard JSON API on `127.0.0.1:8188`** — everything in §4 works unchanged. Models resolve via `~/Library/Application Support/Comfy Desktop/shared_model_paths.yaml` to **`~/ComfyUI-Shared/models/<kind>/`**; outputs land in **`~/ComfyUI-Shared/output/`** (not `ComfyUI/output/`). ComfyUI 0.27.0, frontend 1.45.20, device MPS. Caveat: the server only runs while the Desktop app is open; a launchd/headless setup is a later option if that bites. |
| 2026-07-08 | **Model kit + licenses (all verified on HF at download time, none gated):** SDXL base 1.0 `sd_xl_base_1.0.safetensors` sha256 `31e35c80…` (OpenRAIL++); fp16-fix VAE `sdxl_vae.safetensors` `235745af…` (MIT); Pixel Art XL LoRA `pixel-art-xl.safetensors` `4234637c…` (CreativeML OpenRAIL-M); PixelArtRedmond also OpenRAIL-M (not downloaded yet). Z-Image-Turbo was pre-installed by the human via the Desktop app: `z_image_turbo_bf16.safetensors` + `qwen_3_4b.safetensors` + `ae.safetensors` hash-match `Comfy-Org/z_image_turbo` split_files exactly; upstream `Tongyi-MAI/Z-Image-Turbo` is **Apache 2.0**. |
| 2026-07-08 | **Measured timings (M2 Max 96GB, 1024×1024, warm model — run #1 excluded per §11):** SDXL+LoRA 25 steps/euler: **~45 s/image** (first run 51 s). Z-Image-Turbo bf16 8 steps/res_multistep: **~80 s/image** (first run 86 s) — slower than SDXL despite fewer steps (~10 s/step for the 6B DiT on MPS). Overnight batch ≈ ~1,900 SDXL or ~1,000 Z-Image candidates. |
| 2026-07-08 | **Z-Image-Turbo verdict: KEEP as the high-fidelity source; FLUX.1-schnell fallback unnecessary.** MPS + ComfyUI-native path works out of the box (UNETLoader + CLIPLoader `lumina2` + ModelSamplingAuraFlow shift 3 + ConditioningZeroOut negative, cfg 1). Quality on the farmhouse test subject is excellent — coherent, artifact-free. 80 s/image is fine for the low-volume backgrounds/portraits role. FLUX not downloaded. |
| 2026-07-08 | **API round-trip proven with reproducibility:** `workflows/sdxl_txt2img.json` + `workflows/zimage_txt2img.json` (API format, fixed seed 41) live in `insignificant-game/assets/pipeline/`, driven by `comfy_run.py`. Same seed re-run → **bit-identical pixels** (verified via numpy diff = 0), so MPS determinism holds here. Note: output PNG *files* hash differently across runs (ComfyUI embeds workflow metadata incl. `filename_prefix`); compare pixels, not file bytes. |
| 2026-07-08 | **Pixel LoRA first impressions:** pixel-art-xl @0.9 gives a clean, readable pixel-art building sprite on SDXL. But "plain flat magenta background" leaked: the *roof* came out magenta and the background rendered near-white — §5's key-out-a-flat-color trick needs prompt iteration (or a background-removal node) rather than naive color naming. Also found for Phase 1: `tarn59/pixel_art_style_lora_z_image_turbo` (**Apache 2.0**), a pixel LoRA for Z-Image referenced by ComfyUI's own template — a candidate style recipe alongside the SDXL LoRAs. |
| 2026-07-08 | **pixelize.py verified** (ComfyUI's venv python has Pillow + numpy; system python3 doesn't — run pipeline scripts with `~/imagegen/ComfyUI/.venv/bin/python`): 1024² → 64×64 with an 8-color stand-in palette → 0 off-palette pixels, @8x review copy written. Real master palette is the Phase 1 human gate. |
| 2026-07-08 | **Tooling quirk on this machine:** the rtk Bash hook mangles/truncates large JSON piped through inline `python3 -c` one-liners — write API responses to files first (or use `rtk proxy`). `hf` CLI 1.22.0 installed via `uv tool install "huggingface_hub[cli]"` (at `~/.local/bin/hf`). |
| 2026-07-08 | **Switched to the git-clone install (human request, same day) — this supersedes the Desktop-app layout above as the serving path.** Now: `~/imagegen/ComfyUI` (ComfyUI 0.27.0 @ `ffbecfff`, Python 3.12.11, **torch 2.12.1**, ComfyUI-Manager in `custom_nodes/`), run as a **launchd service** `com.insignificant.comfyui` (KeepAlive + RunAtLoad — survives reboots and needs no GUI app; logs in `~/imagegen/logs/`; manage with `launchctl kickstart -k` / `bootout gui/$UID/com.insignificant.comfyui`). Models were **not moved**: `extra_model_paths.yaml` points at the same `~/ComfyUI-Shared/models/`, outputs still `~/ComfyUI-Shared/output/` (`--output-directory`). Desktop app had no third-party custom nodes, so nothing to migrate; it's retained but dormant — **don't open it while the service runs, both want port 8188.** |
| 2026-07-08 | **Cross-install reproducibility is NOT bit-exact (honest finding):** same seed/workflow on desktop (torch 2.10.0/py3.13) vs git clone (torch 2.12.1/py3.12) → visually identical but 26–71% of pixels differ slightly (mean diff 0.4–2.5/255). Within one install it IS bit-identical (re-verified on the clone: diff 0). So: **seed reproducibility is per-environment; pin the env (torch version) for any asset family in progress, and re-anchor img2img lineages after a torch upgrade.** Warm timings unchanged on the clone: SDXL ~45 s, Z-Image ~78 s. Z-Image `lumina2` path re-verified on torch 2.12.1. |
| 2026-07-08 | **`tarn59/pixel_art_style_lora_z_image_turbo` downloaded** (Apache 2.0, 162MB) into shared `loras/` — Phase 1 style-board candidate: Z-Image+LoRA vs SDXL+pixel-art-xl vs SDXL+PixelArtRedmond is a natural 3-recipe comparison. |
| 2026-07-08 | **Phase 1 run notes.** (a) §3's "PixelArtRedmondV2" does not exist as an SDXL repo — the real artifact is `artificialguybr/PixelArtRedmond` → `PixelArtRedmond-Lite64.safetensors` (CreativeML OpenRAIL-M, trigger `Pixel Art, PixArFK`), downloaded. tarn59 Z-Image LoRA trigger is `Pixel art style.` (Apache 2.0). (b) **Lospec palettes are license-safe** (grounded search 2026-07-08): Lospec publishes no license, bare color lists aren't copyrightable (37 CFR §202.1(a)), Resurrect-64's author explicitly OK'd game use in her palette page comments; details in `assets/pipeline/palettes/README.md`. (c) No ImageMagick on this machine — contact sheets are assembled with Pillow (`style_board_sheets.py`), which is fine; don't add a brew dependency for it. |
| 2026-07-08 | **Prompting learnings from the 56-image style-board batch (all three recipes, seeds 41-44):** (1) pixel LoRAs love emitting **multi-object sprite sheets** even when prompted "single X, centered, isolated" — SDXL recipes did it in over half the seeds; add `sprite sheet` to the negative prompt and expect to §8-reject sheet-layouts when a single sprite is wanted. (2) **Icons cannot be prompted at scene framing**: a "coin icon" leaves the subject ~25% of the canvas and dies at 16×16; prompt `extreme close-up ... fills the entire frame edge to edge` (re-roll fixed r1/r2). Even then 16×16 glyph readability is marginal for the SDXL recipes — icons may end up the §0 hand-drawn exception, or need simpler glyph subjects + the frozen §6 base plate. (3) **Recipe temperaments**: pixel-art-xl = crisp true-pixel sprites, follows isolation best of the SDXL pair; PixelArtRedmond = chunky softer pixels but **ignores background-isolation instructions** (always paints a full scene — plan to crop/key); Z-Image+tarn59 = follows instructions best (clean isolated sprites), tends to **isometric 3/4 views** for buildings (vs side view from SDXL recipes) and produces the most painterly card art and the boldest flat icons (best 16×16 survival). (4) Z-Image icon output is flat vector-like rather than pixel-styled — quantization hides this at 16×16. Timings held (SDXL ~45s, Z-Image ~80s). |
| 2026-07-09 | **Krea 2 staged as recipe r4 (human request).** Weights: `Comfy-Org/Krea-2` repack — `krea2_turbo_bf16.safetensors` (25GB, 12B DiT) + `qwen3vl_4b_bf16.safetensors` text encoder + `qwen_image_vae.safetensors`. Native in our clone (0.27.0): CLIPLoader type `krea2`, KSampler **euler/simple, 8 steps, cfg 1**, ConditioningZeroOut negative (no real negative prompt available), `EmptySD3LatentImage`; shift 1.15 is baked into the model config — no ModelSampling node. Timing on MPS bf16: **~170 s/image @1024², ~125 s @768×1024**. **License is NOT permissive: "Krea 2 Community License" — commercial use free only while company TTM revenue < $1M USD, deployer content-filtering obligation, above that an enterprise license is required.** Flagged to the human at Phase 1 presentation; using it beyond style boards = an explicit human sign-off item. Urabewe's LoRA collection (incl. `Krea2_Moebius_LoRA.safetensors`) is MIT; the Moebius LoRA has **no trigger word** and its author says to avoid art-style descriptors in prompts (trained on Krea-2-Raw, runs on Turbo). ImageMagick 7.1.2 is now installed (human request, same day); contact sheets still use Pillow. |
| 2026-07-09 | **r4 (Krea2+Moebius) batch learnings (16 images, seeds 41-44):** follows isolation instructions perfectly — all 16 came out as single isolated subjects on the light-gray ground, no sprite-sheet drift. New artifact class instead: **invented game-logo badges** on building sprites (3/4 bld1 seeds) and **fake artist signatures** on card art (3/4 card seeds) — with cfg 1 + zeroed negative there is no negative-prompt lever, so §8-reject and re-roll; add "logo/signature present?" to the §8 checklist. Style finding: the ligne-claire look is glorious at raw 1024 and survives 96×128 card grids, but **64×64 pixelization destroys thin linework + watercolor fills** — Moebius style and §5's pixelize-to-grid step are in tension; if r4 wins the pick, §5 grids (or pixelization itself) need a human decision. r4 contact sheet therefore carries an extra top "raw" row. |
| 2026-07-09 | **Phase 1 gate CLOSED — human decision: recipe r4 wins (Krea-2-Turbo + Moebius LoRA @1.0), pixelization dropped for ALL assets.** Locked into `assets/pipeline/style-bible.md` (exact recipe + prompt block + model hashes + the four raw picks committed as `assets/pipeline/style-refs/`); Krea 2 Community License explicitly signed off (recorded in style-bible §6). Doc fallout applied the same day: cookbook §0/§5/§6/§7/§8/§9/§10 updated (pixelize.py + palettes/ retired to provenance, §8 off-palette check replaced by logo/signature check), corpus `Insignificant.md` §視覺與聽覺風格 rewritten (pixel art → Moebius) + design/ snapshot re-copied, inventory grid proposals voided, hand-off prompts 2-3 updated. **Left open on purpose: the native render resolution** (640×360 was pixel-coupled) — human decides before Phase 4, flagged in §10 and the corpus. |
| 2026-07-09 | **Render resolution decided by the human: Full HD 1920×1080** — closes the open question from the same-day style pick. §10/§0/§7 updated; corpus open-question block resolved and removed; PoC window stays 1280×720 until Phase 4 (core is resolution-blind). |
| 2026-07-09 | **Human challenged the "Krea 2 invents logo badges" phrasing — correct challenge.** It is a Phase 1 observation (3/4 seeds on the building subject, 3/4 on the card subject; 16 images, one prompt each), not established model behavior. §8 reworded from a standing trait to a per-batch check; tally the artifact rate on every batch (starting with the Phase 2 template batch) and record it here. |
| 2026-07-09 | **ComfyUI resident memory is designed behavior, not a leak (answering the human's 60GB question)** — the server caches every touched model in-process between jobs, and PyTorch's MPS allocator keeps freed tensors until process exit, so ~60GB RSS after mixed Krea-2/SDXL/Z-Image use is steady state. It bit once: with the prior session's models resident (~20GB free), loading the 25GB Krea checkpoint drew a memory-pressure **SIGTERM mid-job** (launchd auto-restarted; the in-flight job died and the poll loop hung on a reset connection). Mitigations now in the tooling: `comfy_run.py` retries poll blips and detects jobs that vanished in a restart; batch scripts retry a lost job once. Habit: after each batch session (verify `/queue` is empty first), release memory via `curl -X POST http://127.0.0.1:8188/free -H 'Content-Type: application/json' -d '{"unload_models": true, "free_memory": true}'` or `launchctl kickstart -k gui/$UID/com.insignificant.comfyui`. `--disable-smart-memory` rejected as a default (per-job reload would roughly double single-model batch wall-clock). |
| 2026-07-09 | **Phase 2 template batch (20 images, 5 templates × seeds 51-54): the Phase 1 badge/signature artifact did NOT recur.** Tally: **0/20 invented logo badges, 0/20 bold fake signatures; 2/20 faint aged-ink scribbles** on card-frame parchment panels (card_frame s52/s53) — kept on the contact sheet with the caveat since they're paintable-out under Phase 2's once-allowed manual cleanup. Template learnings: "empty window / plain empty center" honored 20/20 (the model never filled the windows); buttons render with a **baked drop shadow** (key or crop before NinePatchRect); **mid-edge ornaments** (panel s53 bottom diamond, button s52 top/bottom points) would smear under 9-slice stretch — prefer corners-only variants or clean up once; dividers came out two-tone purple→copper on 3/4 seeds; icon plates render painterly stone centers, more dimensional than the Phase 1 sprites (human judges the fit). Timings scale with pixel count: divider 1024×256 ≈ 39 s, button 1024×512 ≈ 78 s, card 768×1024 ≈ 118 s, 1024² ≈ 160 s. |
| 2026-07-09 | **UI font candidates for the Phase 2 gate (licenses verified on official repo LICENSE/OFL files; TC coverage verified empirically via fontTools cmap against 70 zh-TW game-vocabulary chars incl. 內亂/幸福/債務/戰鬥/營運/國策):** (1) **Noto Sans TC** — OFL 1.1, 7 weights, full Big5+ coverage; the neutral workhorse, best for dense small numbers; wants subsetting (~16MB/weight). (2) **jf open 粉圓 (Huninn)** v2.1 — OFL 1.1 (Reserved Font Names "huninn"/"open huninn" bind only derivatives), Regular only; warm rounded gothic with TW-specific legibility corrections. (3) **Iansui 芫荽** v1.020 — OFL 1.1, Regular only, ~8,170 Big5 chars (all tested game vocab present); handwriting-kai built from Klee One SemiBold, the best temperament match for ligne claire — headings/card names, paired with (1) or (2) for small numbers. Runner-up: LXGW WenKai TC (OFL; too thin at small sizes, non-TW glyph forms). Human picks at the gate. |
| 2026-07-09 | **Phase 2 picks executed (card frame s53 / panel s51 / button s54 / icon plate s53; divider rejected as too fancy, re-rolled).** Four templates frozen into `assets/approved/ui/` by `phase2_freeze.py`: border-flood keying (button tolerance 95 eats its baked drop shadow), card-frame content-window/text-panel rects + 9-slice margins measured programmatically (recorded in style bible §9), parchment ink marks inpainted (~8k px — the once-allowed manual cleanup), margins verified with stretch-test renders. Practical finding: **NinePatch sources impose minimum UI sizes** (panel ≈178×169, button ≈181×138 at source scale) below which corner patches squash — keep composed chrome above them. Divider re-roll with a v2 prompt ("plain rule, flourish ends only"): 4/4 §8-clean (artifact tally 0/4), on `contact-sheets/phase2_divider2.png` awaiting the pick. **UI font locked: Noto Sans family** — the human surfaced a localization requirement (multiple languages planned), which rules out single-script personality fonts; zh-TW = Noto Sans TC (style bible §10). |
| 2026-07-09 | **Phase 2 gate CLOSED — divider pick s55 (dot ends) frozen as `ui_divider.png` (884×24, 3-slice L21/R22).** All five UI templates now live in `assets/approved/ui/` with geometry in style bible §9; the font is locked in §10. Hand-off prompts updated with the proven batch contract: Prompt 3 now carries the Phase 1-2 learnings (subject-only prompts + seed sweeps, per-batch §8 artifact tally, tuned flood-key reuse, icons reviewed composited on the plate, img2img era lineage, post-batch memory release) and a new Prompt 4 covers Godot integration at 1920×1080 with runtime composition and the Noto Sans fetch+subset. |
| 2026-07-09 | **Phase 3 icons, core group pilot (36 images: 10 core-stat glyphs + 2 debt alternates, seeds 61-63): artifact tally 0/36** — no logo badges, no signatures, no §8 artifacts across the whole batch; the icon suffix ("bold dark outline...") produces a consistent sticker-flat glyph look that keys cleanly at tolerance 60. Iconography learning: **abstract-negative concepts need explicit broken/emptied objects** — "stack of coins with a jagged crack" rendered as a plain (wealthy-looking) coin stack 3/3, colliding with icon_money; "a single coin broken in two halves" rendered the split unmistakably 3/3 (kept both plus an empty-pouch variant on the sheet for the pick). Compositing note: border-flood keying leaves *enclosed* near-bg regions opaque (a gear's holes vs the fist's white fill are indistinguishable without semantics) — reads fine on the stone plate; if a picked glyph's holes clash, clean that glyph individually at freeze time. Icons review composited on the frozen plate per the Prompt 3 contract (`phase3_icon_sheets.py`). |
| 2026-07-10 | **Phase 3 core gate: human picked seed 61 across the board (debt = the broken-coin v2); 8 glyphs frozen into `assets/approved/icons/` by `phase3_icons_freeze.py`** (same border-flood keying the review sheet used, tolerance 60; halo check clean on dark and light — `contact-sheets/phase3_icons_core_halo_check.png`). Two icons sent back with human feedback worth generalizing: **population** rendered the two villagers as an explicit male/female pair (fix: prompt identical figures — "two identical villagers in matching hooded tunics" / "huddled group of three identical hooded villagers"); **unrest** came out monochrome while every other glyph carries gold/warm color (fix: give the subject a colored element — torn red sleeve / burning torch). Learning: **specify uniformity and at least one color-bearing element in glyph subjects**, or the model defaults to demographic variety and ink-only line art for figure-and-gesture concepts. Re-rolls ran as group `core_fix` (4 subjects × seeds 61-63). |
