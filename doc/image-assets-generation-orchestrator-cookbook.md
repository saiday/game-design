# Image-Assets Generation Orchestrator Cookbook

> **Audience:** the Claude (Opus-class) agent that will run **on the Mac Studio** and orchestrate
> image-asset generation for **Insignificant**. You drive the pipeline end-to-end; the human
> reviews style and approves assets. This absorbed and replaced the exploration-level
> `doc/art-pipeline-poc-guide.md` (2026-06-17; removed 2026-07-08, recoverable via git history) —
> its still-valid rules live in §0, its escalation triggers in §12, its references in §13.

Last updated: 2026-07-08.

---

## 0. Standing decisions (do not re-litigate)

| Decision | Value | Source |
|---|---|---|
| Art style | **Pixel art**, 640×360 native low-res, flat info-dense UI | corpus `Insignificant.md` §視覺與聽覺風格 (定稿 2026-07-07) |
| Generation locality | **Local-only** on the Mac Studio. No cloud image APIs. | human, 2026-07-08 |
| Commercial status | Hobby / undecided — but **prefer permissively-licensed models anyway** (SDXL, FLUX.1-schnell, Z-Image-Turbo, Apache/MIT LoRAs) so a later commercial pivot doesn't invalidate assets. Non-permissive weights need explicit human sign-off. | human, 2026-07-08 |
| Asset scope v1 | All four classes: buildings/units ×6 eras, card illustrations, UI icons & frames, backgrounds & portraits | human, 2026-07-08 |
| Orchestration | Claude Code runs **on the Mac Studio** with this repo cloned; outputs reviewed via committed contact sheets | human, 2026-07-08 |
| Backbone tool | **ComfyUI headless via its localhost JSON API**; SDXL + pixel-art LoRA workhorse; **Z-Image-Turbo** as high-fidelity source (FLUX.1-schnell = fallback; **FLUX.2-dev rejected**: 32B is too slow on MPS and its dev license is non-commercial); **Pillow post-process** for pixelization; Draw Things = human spot-checks only, never the pipeline | this doc + human, 2026-07-08 |
| Consistency strategy | **Template-first, semi-generated** (§6): structural assets are generated once, human-frozen, then reused mechanically; AI only fills content inside frozen structure | human + this doc, 2026-07-08 |

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
  the *exception*, reserved for what AI does poorly, and even then restyled to the palette and
  verified for cohesion.
- **Known AI weak spots — plan around them, don't fight them:** seamless tilesets (output drifts,
  seams need explicit verification if any map tiling is ever needed), pixel-exact UI chrome and
  text (answered by §6 frozen templates + Godot `Label` text), animation frames (out of scope).
- **Human-in-the-loop refine is the norm:** generate many, pick best, clean up — not hands-off
  output.
- **Capture learnings** in §14 as you go; a negative result recorded honestly is a valid result.

## 1. Relationship to prior docs

- `doc/art-pipeline-poc-guide.md` (2026-06-17) — **fully merged into this doc and removed
  2026-07-08**; recover via git history if the original wording ever matters. Questions it left
  open are closed: style is **pixel** (the painting-vs-pixel dual trial is void), generation is
  local-only, commercial status is hobby/undecided with the permissive-license preference kept,
  and the device is an **M2 Max, 96GB** (not the Ultra it assumed — changes nothing but speed).
- The **design corpus** (Obsidian `game-design/`, see repo `CLAUDE.md`) is the source of truth for
  *what* to draw: `營運` (building lines × 6 eras), `卡牌` (card list + era evolution), `時代與回合`
  (the six eras), `對手文明` (5 automa civs), `結局` (epilogue scenes), `經濟與債務`/`幸福` (the
  stats that need icons). Build the asset inventory from these docs, never from memory.
- `insignificant-game/` is the delivery target: Godot 4.6, Forward+, 640×360 (§10).

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
| Workhorse checkpoint | SDXL base 1.0 | `stabilityai/stable-diffusion-xl-base-1.0` → `sd_xl_base_1.0.safetensors` | OpenRAIL++ (permissive) | `checkpoints/` |
| VAE fix (mandatory with SDXL on MPS) | fp16-fix VAE | `madebyollin/sdxl-vae-fp16-fix` → `sdxl_vae.safetensors` | MIT | `vae/` |
| Pixel-art LoRA (primary) | Pixel Art XL | `nerijs/pixel-art-xl` | check at download | `loras/` |
| Pixel-art LoRA (alternate) | PixelArtRedmond | `artificialguybr/PixelArtRedmondV2` (or V1) | check at download | `loras/` |
| High-fidelity source (primary) | Z-Image-Turbo | `Tongyi-MAI/Z-Image-Turbo` (verify repo name; ComfyUI native support was fresh as of early 2026 — verify MPS status) | **Apache 2.0** | per ComfyUI docs |
| High-fidelity source (fallback only) | FLUX.1-schnell | `black-forest-labs/FLUX.1-schnell` (or GGUF quant via `city96/FLUX.1-schnell-gguf` + ComfyUI-GGUF) + `comfyanonymous/flux_text_encoders` (clip_l, t5xxl) + FLUX `ae.safetensors` | **Apache 2.0** | `diffusion_models/`, `clip/`, `vae/` |
| Consistency lever (phase 2+) | IP-Adapter (SDXL) | `h94/IP-Adapter` + ComfyUI_IPAdapter_plus node | check at download | per node docs |

**Download order:** the workhorse trio first (SDXL + VAE fix + pixel LoRA — nothing works without
them), then Z-Image-Turbo. Skip FLUX.1-schnell unless Z-Image's MPS/ComfyUI path turns out broken
or its quality disappoints on real subjects — it fills the same low-volume role
(backgrounds/portraits source before pixelization) at twice the parameter count (12B vs 6B).
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

## 5. Pixelization post-process (mandatory stage)

Raw diffusion output is never true pixel art — pixels are off-grid and colors unquantized, and it
will look wrong at 640×360. Every kept image goes through this deterministic stage; its params are
part of the asset's provenance.

Generate large, then reduce: SDXL at 1024², target grid = sprite size (e.g. 64×64 → factor 16).

```python
# pixelize.py — deterministic post-process; keep in insignificant-game/assets/pipeline/
from PIL import Image

def pixelize(src: str, dst: str, grid: tuple[int, int], palette_png: str, alpha_threshold: int = 128) -> None:
    img = Image.open(src).convert("RGBA")                       # generate at grid*N (match aspect!)
    small = img.resize(grid, Image.NEAREST)                     # snap to pixel grid, e.g. (64,64) or (96,128)
    alpha = small.getchannel("A").point(lambda a: 255 if a >= alpha_threshold else 0)
    pal = Image.open(palette_png).convert("RGB").quantize()     # master palette (§7 Phase 1)
    quant = small.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
    quant.putalpha(alpha)
    quant.save(dst)                                             # ship size
    quant.resize((grid[0] * 8, grid[1] * 8), Image.NEAREST).save(dst.replace(".png", "@8x.png"))  # review size
```

Transparent-background sprites: prompt for a plain flat background color absent from the palette,
then key it out before `pixelize` (or use a background-removal node); verify no halo at @8x.

## 6. Consistency strategy — template-first, semi-generated

**The core insight (human, 2026-07-08): style consistency is not achieved by making the model
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
+ illustration texture in the content window + **real `Label` text with a pixel font**. Never bake
frame+art+text into one PNG: baking means a frame tweak invalidates every card, numbers can't
update live, and AI-rendered text is unusable anyway. The only baked composites allowed are
review contact sheets.

**Content variation inside frozen structure (per-asset generation):**
- Card illustrations, portraits, backgrounds, building/unit sprites — generated fresh, but always
  under the style bible + palette quantization, sized to the frozen rects.
- **Masked inpainting** when a family shares layout: freeze the shared region, inpaint only the
  changing region (ComfyUI inpaint workflow).
- **img2img lineage for era evolution**: era N's *approved* sprite is the init image for era N+1
  at low denoise (~0.4–0.6), so the lineage visibly persists and only era-specific features change.

**Lever hierarchy — always exhaust the cheaper one first:**
1. Frozen templates + runtime compositing (this section)
2. Locked style-bible prompt block + pixel LoRA + master-palette quantization (§7 Phase 1)
3. Seed families / img2img lineage (same base seed or init image across a family)
4. IP-Adapter style reference (zero-shot, weaker on fine detail)
5. Custom style LoRA trained on our own approved set — **escalation, human decision** (§12)

## 7. Phase plan

Phases are gate-ordered: **never claim a later gate before an earlier one holds.** A dynamic
workflow may interleave work, but gates close in order.

**Phase 0 — Bring-up**: §3 done; one SDXL image generated via API round-trip with
saved seed/workflow; **Z-Image-Turbo brought up and sanity-checked** (fall back to FLUX.1-schnell
per §3 only if it disappoints); record real timings in §14.

**Phase 1 — Style anchor** (human gate, the most important phase):
1. Build the asset inventory from the corpus docs (§1) into
   `insignificant-game/assets/pipeline/inventory.md` — every needed asset, one line each.
2. Propose the **master palette** (3 candidates, e.g. from Lospec: endesga-32 / resurrect-64 /
   apollo — check each palette's stated license) and **sprite grid sizes** per class (a starting
   proposal: buildings 64×64, units 32×32, card art 96×128, icons 16×16, backgrounds 640×360;
   these are design calls — propose, don't decide).
3. Generate **style boards**: the same 3 subjects (one building across 2 eras, one card, one icon)
   rendered under 3 candidate style recipes (LoRA × prompt block × palette). Contact-sheet them.
4. Human picks. Lock the winner into
   `insignificant-game/assets/pipeline/style-bible.md`: the exact prompt block, negative prompt,
   LoRA + strength, palette file, per-class grid sizes, and reference images. **Every later
   generation cites the style bible; changing it is a human decision.**

**Phase 2 — Templates** (human gate): generate and freeze the structural assets per §6 — card
frame(s) with recorded content-window rects, panel/button 9-slice sources, icon base plate.
Expect manual pixel cleanup on chrome (Aseprite/Piskel or Pillow scripting) — that's the
"semi-" in semi-generated, and it's allowed here precisely because it happens once.

**Phase 3 — Class pipelines**, in this order (volume × risk):
1. **UI icons** — glyphs on the frozen base plate; small, fast feedback; some icons may end up
   hand-drawn/vector restyled to the palette (the allowed exception in §0 operating rules).
2. **Buildings & units ×6 eras** — the volume class. Per building line: era N approved sprite
   seeds era N+1 via img2img lineage (§6); cross-era coherence is an explicit contact-sheet check.
3. **Card illustrations** — per card in `卡牌`, produced to the frozen content-window rect;
   highest quality bar, human reviews in smaller batches.
4. **Backgrounds & portraits** — low volume, large canvas; the Phase-0 winner model as source →
   pixelize; fall back to SDXL if its Mac speed disappoints.

**Phase 4 — Godot integration**: §10. Approved assets composited and rendered
in-engine at 640×360, capture reviewed — same Part-B discipline as the code loop.

## 8. Objective self-checks (before an image reaches the human)

Reject and re-roll without asking if: silhouette unreadable at ship size; wrong aspect/framing or
doesn't fit its frozen template rect; off-palette pixels after quantization (programmatic check:
every pixel ∈ palette); alpha halos; subject mismatch with the inventory line; obvious artifacts
(extra limbs, garbled text); era variant that doesn't visibly differ from its neighbors. What you
must NOT judge: whether it's pretty, on-theme, or the best of the batch — that's the human's pick.

## 9. Review loop, provenance, repo layout

```
insignificant-game/assets/
  pipeline/            # style-bible.md, inventory.md, palette.png, workflows/*.json, pixelize.py, manifest.jsonl
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
 "prompt":"...","negative":"...","seed":41,"checkpoint":"sd_xl_base_1.0@<hash>","loras":[["pixel-art-xl",0.9]],
 "workflow":"workflows/sprite_sdxl.json","init":"approved/buildings/building_farm_era2.png",
 "post":{"grid":[64,64],"palette":"palette.png"},"status":"approved","date":"2026-07-XX"}
```

(`init` records the img2img lineage parent, when used.) Naming: `building_<line>_era<n>.png`,
`unit_<type>_era<n>.png`, `card_<id>.png`, `icon_<stat>.png`, `bg_era<n>.png`,
`portrait_civ<n>.png` — ids matching the corpus/`core/` data tables.

## 10. Godot integration

- Project renders **Forward+ @ 640×360**. Pixel art needs **nearest-neighbor filtering**: set
  `rendering/textures/canvas_textures/default_texture_filter = Nearest` in project settings (or
  per-node `texture_filter`); import PNGs as lossless. Don't expect the desktop preview to match
  a Retina display without integer scaling.
- **Composite, don't bake** (§6): cards/panels are scene trees — frozen frame texture +
  illustration texture + `Label` pixel-font text — never single baked PNGs.
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
- Frozen-template, sprite-size, or palette changes after their phase gate locked them.

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
