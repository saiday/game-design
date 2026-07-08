# Art Pipeline PoC Guide (Exploration)

> **Audience:** agents standing up and driving a local image-generation pipeline for this game.
> **Nature:** **exploration, not a decision.** Principle-level — objectives, gates, guardrails. You (the implementing agent) choose the specific tools, models, and parameters. Nothing here locks a style or a stack; the point is to learn enough to choose later.
> **Companion docs:** `doc/agent-development-loop.md` (engine/code loop) and `doc/poc-implementation-guidelines.md` (code PoC guides, merged). The art asset eventually has to land in Godot as a 2D sprite/texture, so keep that endpoint in mind.

Last updated: 2026-06-17.

---

## 0. How to operate

- **Verify, don't guess.** Tooling here moves fast and Apple-Silicon behavior differs from the NVIDIA-centric guides most of the internet is written for. Confirm speed/quality/licensing on *this* machine rather than trusting a blog.
- **This is exploration.** Success is *learning which direction is worth committing to*, not shipping final art. Don't over-invest in any one path before the comparison is made.
- **Keep both styles alive.** Two candidate styles will be tried — **painting** and **pixel**. Do not quietly favor one; produce comparable evidence for both so the human can pick.
- **Agent-drivable beats pretty-GUI.** The pipeline must be runnable by an agent without manual clicking (CLI or local HTTP API), so art generation can join the same observe→review→revise discipline as code.
- **Reproducibility is non-optional.** Save the prompt, seed, model, and any workflow/params *alongside every output*. An asset you can't regenerate is a dead end for a consistent card set.
- **Capture what you learn** back into this doc's Changelog and a short findings section: which tool, rough speed, quality impressions per style, and what blocked you.

## 1. Objective & what "explored enough" means

Stand up a **local, agent-drivable image-generation environment on the Mac Studio** and use it to answer three questions with real artifacts:

1. **Feasibility:** can an agent drive local generation end-to-end (prompt → image file) without a GUI, at usable speed?
2. **Style comparison:** for the *same* card subject, can we produce a small batch in **painting** style and in **pixel** style, at a card-usable resolution, good enough to judge which direction suits the game?
3. **Consistency + integration:** can we make a few cards in *one* style look like a coherent set, and get at least one of them into Godot as a sprite that reads correctly at card size?

"Explored enough" = those three have honest answers (even a "no, because X" is a valid, valuable result). It is **not** a finished art style, a trained production model, or a card template system.

### Strategic stance: build ONE self-generated pack, don't stitch third-party packs

The whole reason this local pipeline exists is **style cohesion**. Mixing purchased asset packs almost guarantees clashes — each pack carries its own palette, line weight, and lighting. The stronger path is to **generate our own assets from a single style source**: assemble a small *art bible* (a curated reference set), derive a **style LoRA / style-trained model** from it, then make cards, tiles, backgrounds, and simple UI all descend from that one source. This is viable in 2026 — the tooling is production-ready for "high-volume, on-style 2D batches" and training a model on your own art bible to generate hundreds of consistent props/UI/backgrounds is a documented indie workflow. It's also cheaper than buying packs you'd then have to fight for consistency.

So this PoC tests not just "do multiple cards match" but **"can one style source hold across *different asset types*."**

**Where self-generation is genuinely weak — probe, don't assume:**
- **Seamless hex tilesets.** Diffusion output drifts and often won't tile cleanly; true seamlessness needs a tileable LoRA + grid-aligned geometry + explicit seam verification. **Load-bearing here, because the overworld is hex tiles.**
- **Crisp UI chrome / fonts / 9-slice frames.** AI is strong at single-frame illustration (a card, an icon, a background) but not pixel-exact chrome or text — these are often better as vector/manual.
- **Animation frames.** Weak (details drift between frames) — N/A here since cards are static, which is part of why static was chosen.

For the asset types AI handles poorly, existing packs / vector / manual stay valid — but as the **exception**, restyled and verified for cohesion, not the default.

## 2. Hardware reality (Mac Studio, M2 Ultra, 96GB unified memory)

- **Unified memory is the headline advantage.** 96GB shared between CPU/GPU means large models (e.g. FLUX-class) fit comfortably where a similarly-priced discrete GPU would choke. Memory is not your constraint; **compute speed is.**
- **Apple Silicon runs image gen via Metal (MPS/MLX), at roughly one-third to one-fifth of an equivalent NVIDIA card.** Expect on the order of seconds for SDXL and up to ~a minute-ish for FLUX-class images at typical settings — **fast enough for batch exploration, not real-time.** Plan to generate batches and review, not single-shot interactively.
- **CUDA-only things won't run.** Some ComfyUI custom nodes and tooling assume NVIDIA/CUDA and will fail or fall back slowly on Mac. Prefer Metal/MLX-native paths; treat any CUDA-only dependency as a red flag.

## 3. Environment landscape — pick per task (agent's choice)

These are the verified Apple-Silicon options as of mid-2026. **Choose deliberately; you may use more than one** (e.g. one for fast human spot-checks, one for the scripted pipeline). Record what you chose and why.

- **ComfyUI (PyTorch MPS).** Most *programmable* and pipeline-grade: node graphs you can drive via its **local HTTP API with JSON workflows** — the most agent-friendly option. Broad ecosystem (LoRA, ControlNet, IP-Adapter). Caveats: MPS is slower; some custom nodes are CUDA-only; the `--use-pytorch-cross-attention` flag and GGUF-quantized models are common Mac optimizations. Best when you need a repeatable, parameterized pipeline.
- **mflux (MLX-native).** Apple-MLX implementation of FLUX-class models; **CLI-driven**, fast, native. Good agent fit for a FLUX-centric, scriptable flow with less node-graph overhead. Narrower scope than ComfyUI.
- **Draw Things.** Free Mac/App Store app, heavily optimized (Metal FlashAttention), often the **fastest and easiest**, with on-demand weight loading to cut memory. GUI-first (has scripting/gRPC paths if needed). Best for **fast human-eye style exploration**, less natural as the scripted backbone.

> Non-binding tilt: for the *agent-driven* pipeline lean **ComfyUI API** or **mflux CLI**; keep **Draw Things** around for quick human style spot-checks. Don't treat this as the answer — verify what's actually pleasant to drive on this machine.

**Post-processing & assets** (also agent's choice): a pixel editor (Aseprite/Piskel) for cleanup and palette work on the pixel track; community **LoRAs/checkpoints** for each style. Per the indie norm, expect a **human-in-the-loop refine step** (generate many, pick best, clean up) rather than fully hands-off output.

## 4. The art loop & the hard part (consistency)

Mirror the code loop's discipline:

```
prompt/params → generate (local) → agent VIEWS the image → check objective criteria → iterate
                                                              │
                                                   human judges aesthetics & picks style
```

The agent can *see* images, so it can self-check **objective** criteria and iterate prompts/params: readable at card-thumbnail size, clear silhouette, correct aspect/framing, intended resolution, background handled (transparent/consistent), palette cohesion, no obvious artifacts. The agent does **not** decide whether the art is *good* or *on-theme* — that's the human's call, same division as fun/balance in the code loop.

**The genuinely hard part is consistency**, and it must be an explicit probe, not an assumption: making 50+ cards look like one game, not 50 unrelated images. The known levers (try, don't assume which wins): **style/character LoRA** (train on ~15–30 curated references), **IP-Adapter** (zero-shot reference, fast but weaker on fine detail), **ControlNet** (pose/composition control, often stacked), or a **style-training service**. For the PoC, prove the *cheapest* lever that yields a coherent 3-card set; defer production-grade consistency.

## 5. Gates (intent + acceptance; you fill in the how)

**G0 — Environment proven.** A local model generates one image through an **agent-drivable interface** (CLI/API), no GUI clicks.
- *Gate:* prompt in → image file out, reproducibly (seed/params saved), at usable speed.

**G1 — Both-styles batch.** Same card subject rendered as a small batch in **painting** and in **pixel**, at a card-usable resolution.
- *Gate:* comparable artifacts exist for both styles, good enough for a human to judge direction.

**G2 — Consistency probe (across cards AND asset types).** A small set in one chosen style that reads as *one game*: at least a 3-card set **plus one different asset type** (a hex tile or a simple icon) drawn from the same style source.
- *Gate:* they share recognizable style via one documented lever (style LoRA / art-bible model / IP-Adapter / ControlNet); explicitly note whether cross-type cohesion held or drifted — that's the key signal for the self-generated-pack bet.

**G3 — Into Godot.** At least one generated asset imported into Godot as a 2D sprite/texture and shown at card size.
- *Gate:* it renders correctly in-engine at intended resolution (ties into the code PoC's Part B). If a hex tile was generated, also confirm it **tiles without visible seams** in-engine — this is the make-or-break check for the overworld.

**G4 — Capture learnings.** Record per style: tool used, rough speed, quality impression, consistency approach, blockers, and a tentative lean — for the later style decision.

Gates are dependency-ordered, not mandated phases; a dynamic workflow may interleave, but **don't claim a later gate before an earlier one holds.**

## 6. Non-negotiables (guardrails)

- **One self-generated, style-unified pack is the default.** Don't assemble third-party packs as the base — they won't match. Existing packs / vector / manual are reserved for the asset types AI handles poorly (fonts, crisp UI chrome, seamless tilesets *if* AI can't deliver them), and even then must be restyled and verified for cohesion.
- **Local-first on the Mac Studio.** Use the hardware you have; cloud APIs only as a fallback when a local path is blocked, and never for anything that must stay private.
- **Agent-drivable, not GUI-locked.** The pipeline backbone must be scriptable.
- **Both styles get a fair trial.** No silent narrowing before G1/G2 evidence exists.
- **Static art only.** No animation/spritesheets in this PoC — consistent with the locked 2D static-card direction; AI frame-to-frame animation is weak.
- **Licensing is load-bearing.** This game is intended to ship. **Verify the commercial-use license of every base model, checkpoint, and LoRA before its output touches a shippable asset** — some popular models (notably certain FLUX *dev* variants) are research/non-commercial only, while others (FLUX *schnell*, SDXL) are permissive. When unsure, treat as non-commercial and flag it.
- **Reproducible provenance.** Every kept asset has its prompt/seed/model/params saved next to it.
- **Human owns aesthetics and the style pick.** The agent checks objective criteria and surfaces options; it does not declare a winning style.
- **Don't treat exploration output as final.** Nothing generated here is committed as real game art without human sign-off.

## 7. Decisions the agent owns

Generation tool(s) and whether to run more than one; base model(s) per style; the consistency lever to trial first; resolutions and card aspect for the probe; the post-processing editor; batch sizes; prompt strategy; how much (if any) LoRA training to attempt in the PoC. Make reversible choices freely and note them; escalate anything hard to reverse or that would constrain the real pipeline.

## 8. Scope boundaries (out of scope)

No final art; no full card-frame/template/layout system; no complete UI/icon set (one sample asset for the cross-type probe is fine); no animation; no asset-management tooling. **Production-grade LoRA/style training is out of scope** — but a *quick, cheap* experimental style LoRA or art-bible model to test cross-type consistency (G2) is acceptable. Smallest evidence that lets the human compare painting vs pixel, judge whether one style source holds across asset types, and trust an agent can drive local gen into Godot.

## 9. When to stop and ask the human

- A local path can't be made to work on this machine after honest effort (report it — a negative result is useful).
- Licensing for a needed model is unclear or non-commercial and no permissive substitute is found.
- A style clearly can't reach card-usable quality locally — surface it rather than forcing it.
- Consistency can't be achieved with the cheap levers and would need significant training investment — that's a decision for the human, not a quiet escalation of effort.

## 10. References (fetched/verified 2026-06-17)
- ComfyUI on Apple Silicon (MPS speed, optimization flags): https://www.workflowlab.dev/deploy/comfyui-mac-apple-silicon-mps-speed · https://smartart.live/articles/258-flux-comfyui-on-apple-silicon-complete-2026-guide-to-hardware-acceleration-gguf-models-memory-optimization.html
- Mac tool benchmark (Draw Things vs ComfyUI, Flux timings): https://www.heyuan110.com/posts/ai/2026-02-15-mac-mini-local-image-generation/ · https://insiderllm.com/guides/stable-diffusion-mac-mlx/
- mflux (MLX-native FLUX): https://github.com/filipstrand/mflux
- Indie ComfyUI asset pipeline & pixel-art workflow: https://www.strayspark.studio/blog/comfyui-game-asset-pipeline-indie-2026 · https://www.seeles.ai/resources/blogs/ai-generate-pixel-art-game-assets
- Character/style consistency (LoRA / IP-Adapter / ControlNet): https://thinkpeak.ai/stable-diffusion-character-consistency-tutorial/ · https://www.lovart.ai/blog/complete-guide-consistent-ai-character-design
- Self-generating a coherent pack vs buying packs; consistency at scale via art-bible/style training: https://nilo.io/articles/ai-generated-assets-for-games
- Honest limits of AI 2D asset generation (single-frame strong; tilesets/animation weak): https://www.summerengine.com/blog/ai-2d-game-asset-generator

## Changelog
- **2026-06-17** — Guide created. Exploration/principle-level. Two style tracks (painting, pixel) to be compared. Targets local generation on Mac Studio (M2 Ultra, 96GB). No tool/style/model locked.
- **2026-06-17** — Amended: adopt a **self-generated, style-unified pack** as the default strategy (art bible → style source) instead of stitching third-party packs. G2 now probes consistency *across asset types*, G3 adds a hex-tile seam check, guardrails/scope updated. Flagged the weak spots: seamless hex tilesets, crisp UI chrome/fonts.
