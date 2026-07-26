# Exploratory top-down sprites (NOT pipeline assets)

**Do not ship these, do not reference them from `core/` or `view/`, do not promote them to
`assets/approved/`.** They exist for exactly one consumer:
`docs/explore-topdown-motion-demo.html`, the presentation sandbox for watching unit stats and
combat rolls resolve on screen.

They are deliberately absent from `assets/pipeline/manifest.jsonl`, `inventory.md`, the style
bible and `core/data/asset_paths.gd`. Nothing in the game knows they exist, and that is correct:
the shipping game uses the 69 frozen side-view units in `assets/approved/units/`. The top-down
camera these were drawn for was **stopped** as a game direction; see
`docs/explore-topdown-battle-and-units.md` §1 for the audit that stopped it, and §2 for why the
sandbox survived anyway.

## What is here

60 PNGs at 1024×1024, on a plain light-grey background that the build keys to transparent.

- **52 unit sprites**, `<class>_e<era>.png` across 11 classes. Which classes have a form in
  which era comes from `core/data/cards.gd` `era_names`, so this is not a full 11×6 grid.
- **8 flying weapons**, `proj_<ammo>.png`. No era of their own; the demo maps them onto classes
  and eras itself.

## Provenance and how to regenerate

`docs/tools/topdown_demo_sprites.json` holds the prompt, seed and class/era for all 60. It is the
record of what is on disk, not a wishlist:

- **55 sprites at seed 501**, the round-2 authoring pass that made every subject face right so
  the demo's X-flip works.
- **5 sprites at seed 403**: `bomber_e4`, `holy_warriors_e4`, `privateers_e3/e4/e5`, re-rolled
  after a human review rejected them. Round 1 (seeds 401/402) is entirely superseded and no file
  here comes from it.

Recipe is the locked one, Krea-2-Turbo + Moebius LoRA @1.0, euler/simple, 8 steps, cfg 1.0,
`ConditioningZeroOut` (`assets/pipeline/workflows/krea2_lora_txt2img.json`). With ComfyUI up on
127.0.0.1:8188:

```sh
cd insignificant-game
python3 docs/tools/render_topdown_sprites.py --list          # the whole table
python3 docs/tools/render_topdown_sprites.py archers_e2      # reproduce one exactly
python3 docs/tools/render_topdown_sprites.py bomber_e4 --seed 404 --probe   # try a new roll
python3 docs/tools/build_motion_demo.py                      # re-embed into the demo
```

**A re-roll is a new seed, and the seed must be written back into
`topdown_demo_sprites.json` when the roll is accepted.** Otherwise the record stops describing
the files, which is what happened to the 401/402 numbers.

Review candidates with `--probe` before overwriting a sprite: `--probe` writes to
`docs/tools/topdown-probe/` and leaves the accepted set alone.

## Prompt-craft rules these sprites paid for

Full list in `docs/explore-topdown-battle-and-units.md` §4. The two that bite hardest here:

- Name the subject's **count**. The three prompts written "a lone bandit / thief / hacker"
  contradicted the shared "...figures" clause and each came back as one hero in front of a
  hallucinated crowd of generic soldiers.
- Pin the **aim direction**, not the carry position, or a shooting unit renders idle with its
  weapon slung.
