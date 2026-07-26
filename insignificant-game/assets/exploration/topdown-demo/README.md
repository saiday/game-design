# Exploratory top-down sprites

Demo-only art, and the sole consumer is `docs/explore-topdown-motion-demo.html`, a sandbox for
watching unit stats and combat rolls resolve on screen. **Nothing in this folder ships.** No
Godot code references it, and none of it belongs in `assets/approved/`.

## If you are looking for unit art for the game, this is not it

The game's unit art is the frozen side-view set in `assets/approved/units/`. Approved assets
resolve through the registry in `core/data/asset_paths.gd` (`UNIT_DIR`, `UNIT_COVERAGE`,
`unit()`, `has_unit()`), never a literal path; `docs/architecture.md` is where that rule lives.

Three reasons these files cannot stand in for it:

- **Wrong camera.** They are drawn top-down. The game is side-view, and top-down was explored and
  dropped as a game direction (`docs/explore-topdown-battle-and-units.md` §1). The camera here is
  a property of the sandbox, not a proposal.
- **Wrong format.** They are unkeyed 1024×1024 raws with the grey render backdrop still baked in.
  The transparency visible in the demo is produced at build time and stored nowhere.
- **Wrong roster.** Keyed to the card catalog's classes, so no `enemy_weak` / `enemy_mid` /
  `enemy_hard` tiers, which the approved set does carry.

## Contents

60 PNGs, 1024×1024.

| | Naming | Count |
|---|---|---|
| Unit sprites | `<class>_e<era>.png` | 52 across 11 classes |
| Flying weapons | `proj_<ammo>.png` | 8, no era of their own |

Not a full 11×6 grid: which class has a form in which era comes from `core/data/cards.gd`
`era_names`. The demo maps the projectiles onto classes and eras itself.

## Regenerating

`docs/tools/topdown_demo_sprites.json` records the prompt and seed behind every file here, and the
same row reproduces the same image. Recipe is the locked one, Krea-2-Turbo + Moebius LoRA @1.0,
euler/simple, 8 steps, cfg 1.0. With ComfyUI up on 127.0.0.1:8188, from `insignificant-game/`:

```sh
python3 docs/tools/render_topdown_sprites.py --list                        # the table
python3 docs/tools/render_topdown_sprites.py archers_e2                    # reproduce one
python3 docs/tools/render_topdown_sprites.py bomber_e4 --seed 404 --probe  # try a new roll
python3 docs/tools/build_motion_demo.py                                    # key, trim, re-embed
```

`--probe` writes candidates to `docs/tools/topdown-probe/` and leaves the accepted set untouched,
which is how a roll should be reviewed before it replaces a sprite. Accepting one means writing
its seed back into `topdown_demo_sprites.json`, otherwise the record stops describing the files.

Prompt wording these sprites depend on is in `docs/explore-topdown-battle-and-units.md` §4.
