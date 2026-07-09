# Style bible — Insignificant (locked 2026-07-09)

> **Locked by human pick at the Phase 1 gate** (cookbook §7): recipe **r4** from
> `contact-sheets/phase1_style_board_r4.png`, judged on the **raw** row. In the same decision the
> human **dropped pixelization for all assets** (cookbook §5 retired). This file only changes by
> explicit human decision (cookbook §12). Every generation cites this file.

## 1. The style

**Moebius-style illustration**: ligne-claire linework with flat watercolor-like fills, produced by
Krea-2-Turbo under the Moebius LoRA. This is **not pixel art**; the earlier pixel-art direction
(corpus 定稿 2026-07-07, recipes r1-r3) was rejected at the Phase 1 review and the corpus
`Insignificant.md` §視覺與聽覺風格 was updated 2026-07-09.

**Reference images** (the four Phase 1 picks, raw 1024-class, committed): `style-refs/`
- `sb_r4_bld1_s43.png` — era-1 building (tribal farm settlement)
- `sb_r4_bld4_s43.png` — era-4 building (industrial farm)
- `sb_r4_card_s42.png`  — card illustration (spear phalanx)
- `sb_r4_icon_s42.png`  — UI icon (gold coin)

These are also the anchors for consistency levers (img2img lineage seeds, IP-Adapter reference)
per cookbook §6.

## 2. Generation recipe (exact — cite, don't improvise)

- Workflow: `workflows/krea2_lora_txt2img.json`, driven by `comfy_run.py`.
- Sampler: KSampler **euler / simple, 8 steps, cfg 1.0, denoise 1.0**; latent `EmptySD3LatentImage`;
  negative = `ConditioningZeroOut` (**there is no negative-prompt lever** at cfg 1 — quality
  control is §8 reject + re-roll, never negative-prompt tuning).
- Seeds: explicit fixed seeds always; batch = seed sweep on one prompt.
- Timing on this machine (M2 Max, MPS bf16): ~170 s/image @1024², ~125 s @768×1024.

| Role | File (in `~/ComfyUI-Shared/models/`) | Strength | License |
|---|---|---|---|
| Checkpoint | `diffusion_models/krea2_turbo_bf16.safetensors` (Comfy-Org/Krea-2 repack, 12B) | — | **Krea 2 Community License — non-permissive, see §6** |
| Text encoder | `text_encoders/qwen3vl_4b_bf16.safetensors` (CLIPLoader type `krea2`) | — | with checkpoint |
| VAE | `vae/qwen_image_vae.safetensors` | — | with checkpoint |
| LoRA | `loras/Krea2_Moebius_LoRA.safetensors` (Urabewe/Urabewe-LoRA-Collection) | **1.0** | MIT |

SHA-256 of the exact files used (recorded at lock time): see §7.

## 3. Prompt block

**No style prefix, no trigger word, and no art-style descriptors anywhere in the prompt** (the
LoRA author's explicit guidance; style words fight the LoRA). Prompts are subject-only, composed
as `<subject core>, <class framing suffix>`:

| Class | Framing suffix (verified in Phase 1) | Size |
|---|---|---|
| Buildings / units / forts | `game building sprite, side view, centered, isolated on a plain light gray background` (swap "building" for the class noun) | 1024×1024 |
| Card illustrations | `game card illustration, dramatic composition` | 768×1024 |
| UI icons | `game <thing> icon, bold dark outline, centered, plain light gray background` | 1024×1024 |
| Backgrounds | scene description, no isolation suffix | 1344×768 (verify per batch) |
| Portraits | `character portrait, bust, centered, plain light gray background` | 1024×1024 |

Krea 2 + this LoRA follows isolation instructions perfectly (16/16 in Phase 1) — no sprite-sheet
drift, unlike the SDXL recipes. Card and background sizes/framing beyond the two Phase 1-verified
rows are working baselines: adjust freely, log in §14, but the style recipe itself is locked.

## 4. Post-process (pixelization retired)

- **No grid snap, no palette quantization, no master palette.** Assets ship at generation
  resolution; scaling happens in-engine. `pixelize.py` and `palettes/` remain in the repo as
  Phase 1 provenance only.
- **Transparent sprites**: key out the flat light-gray ground (chroma/flood key on the isolation
  background), verify no halo on a dark and a light backdrop before approval.
- Contact sheets and manifest provenance per cookbook §9, unchanged (`post` field: `null` or the
  keying params).

## 5. Recipe-specific §8 checks (added at lock time)

Reject and re-roll (no negative-prompt lever exists — see §2):
- **Invented game-logo badges** on sprites (hit 3/4 building seeds in Phase 1).
- **Fake artist signatures** on card art (hit 3/4 card seeds in Phase 1).
- The old "off-palette pixels after quantization" check is void.

## 6. License sign-off (recorded)

**Krea 2 Community License** (non-permissive) — **human sign-off 2026-07-09**, given with the
terms surfaced: free commercial use only while company trailing-twelve-month revenue is under
$1M USD; above that an enterprise license from Krea is required; deployers carry a
content-filtering obligation; Krea claims no rights over outputs. Consistent with §0's
hobby/undecided commercial status. **Re-verify the license before any commercial release**; a
future commercial pivot above the threshold means relicensing or regenerating.
The Moebius LoRA is MIT (no constraint).

## 7. Model hashes (provenance)

```
78bbf8f4165eda19cea3cb06c78089221932a39e2eed8af9da741f942c47ffb3  diffusion_models/krea2_turbo_bf16.safetensors
36f3ff447ef59201722e8f9ce6020c9819fdcfba6aa2608c4e09b1c0ce114e34  text_encoders/qwen3vl_4b_bf16.safetensors
a70580f0213e67967ee9c95f05bb400e8fb08307e017a924bf3441223e023d1f  vae/qwen_image_vae.safetensors
16d613224c8d08dce512933839518744b2add4c75dbd49a630a60995d3fe73a8  loras/Krea2_Moebius_LoRA.safetensors
```

Environment pin at lock time: ComfyUI 0.27.0 @ `ffbecfff` (git clone, launchd service), Python
3.12.11, torch 2.12.1, MPS. Per §14 (2026-07-08): seed reproducibility is per-environment — after
a torch upgrade, re-anchor any img2img lineage in progress.

## 8. Resolution (resolved 2026-07-09)

640×360 native resolution was a pixel-art-coupled decision and died with pixelization. **Human
decision 2026-07-09: the shipped game targets Full HD 1920×1080.** Assets ship at generation
resolution and scale in-engine; templates record content-window rects and 9-slice margins
relative to the generated image, never to screen pixels. The PoC window stays 1280×720 until
Phase 4 wiring (cookbook §10).
