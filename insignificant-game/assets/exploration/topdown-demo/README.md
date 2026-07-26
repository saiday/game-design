# Top-down demo sprites (exploration only)

Demo-only raws. The sole consumer is `docs/explore-topdown-motion-demo.html`, a sandbox for
watching unit stats and combat rolls resolve on screen. **Nothing in this folder ships.** No
Godot code references it, and none of it belongs in `assets/approved/`. If you came here looking
for the game's unit art, read the last section first.

## Inventory

60 PNGs at 1024×1024, each with a `.png.import` sibling (Godot editor artifacts from the project
scan, not assets, and not tracked). `docs/tools/topdown_demo_sprites.json` is the machine-readable
index: one row per file, carrying `key`, `cls`, `era`, `kind`, `seed`, `prompt`.

| Group | Naming | Files |
|---|---|---|
| Unit sprites | `<class>_e<era>.png` | 52 over 11 classes |
| Flying weapons | `proj_<ammo>.png` | 8, no era of their own |

### Unit sprites

Not an 11×6 grid. A class gets a sprite only for an era where it has a form, and those come from
`era_names` in `core/data/cards.gd`, mirrored by the demo's own `CLASSES` table. `kind` is the
subject the prompt renders, which is why the camera reads differently across the set: structures
and vehicles come out genuinely overhead, human groups drift toward three-quarter.

| Class | zh | Row | Sprites | `kind` |
|---|---|---|---|---|
| `infantry` | 步兵團 | melee | e1–e6 | figure |
| `archers` | 弓箭團 | ranged | e1–e6 | figure |
| `cavalry` | 騎兵團 | melee | e1–e6 | figure, vehicle from e5 |
| `engineers` | 工兵團 | melee | e1–e6 | figure, except e5 (vehicle) |
| `elite_forces` | 菁英特種部隊 | melee | e2–e6 | figure |
| `artillery` | 火砲 | ranged | e3–e6 | vehicle |
| `bomber` | 轟炸機 | air | e4–e6 | air |
| `holy_warriors` | 聖戰士團 | melee | e4 only | figure |
| `privateers` | 私掠傭兵團 | melee | e3–e5 | figure |
| `shield_wall` | 盾陣 | fortification | e1–e6 | barrier |
| `anti_air` | 防空飛彈 | fortification | e1–e6, 3 stranded | emplacement, vehicle from e5 |

**`anti_air_e1/e2/e3` back no live form.** ADR-0006 starts 防空飛彈 at the industrial era
(有空軍才有防空), which retired the era 1–3 forms 擋箭棚 / 箭樓 / 城防塔 along with the
「攔一次遠程」 job they used to do. The renders stay on disk and stay embedded, and the demo's asset
table prints a dash in their cells. Leave them alone: deleting them is churn, and they are not
evidence that those forms are coming back.

So the counts differ on purpose: **60 files on disk, all 60 embedded, 57 displayed** (49 unit
forms + 8 ammo). `build_motion_demo.py --dry-run` prints the first number, the demo's own asset
table footer prints the last.

### Flying weapons

One sprite per ammo type, no era. The demo's `AMMO` table decides which class throws which, per
era, and every one of the 8 is in use:

| File | zh | Used by |
|---|---|---|
| `proj_stone.png` | 石彈 | archers e1, artillery e3 |
| `proj_arrow.png` | 箭 | archers e2 |
| `proj_bolt.png` | 弩矢 | archers e3 |
| `proj_bullet.png` | 彈丸 | archers e4, e5 |
| `proj_missile.png` | 飛彈 | archers e6 |
| `proj_cannonball.png` | 實心砲彈 | artillery e4 |
| `proj_shell.png` | 高爆砲彈 | artillery e5, e6 |
| `proj_bomb.png` | 炸彈 | bomber e4, e5, e6 |

A missing projectile is a warning, not an error: the demo falls back to a plain tracer line.

## How the demo consumes them

It never reads this folder at runtime. `docs/tools/build_motion_demo.py` keys the plain grey
render background to transparent, trims to the alpha bbox, downscales, quantises, and writes the
result into the HTML as base64 data URIs between the `@SPRITES` markers, so the page stays a
single double-clickable file. Hand-edited JS and CSS survive a re-run.

The build steps down a size ladder, `(256, 128) → (224, 96) → (192, 64) → (160, 48)` as
`(max side px, colours)`, until the page fits its 4.5 MB budget; it is on the first rung today.
So the transparency and the small sizes you see in the demo exist only inside the HTML. Nothing
in this folder is keyed or trimmed.

## Regenerating

Same row in `topdown_demo_sprites.json` reproduces the same image. The recipe is locked:
Krea-2-Turbo + Moebius LoRA @1.0, euler/simple, 8 steps, cfg 1.0. With ComfyUI up on
127.0.0.1:8188, from `insignificant-game/`:

```sh
python3 docs/tools/render_topdown_sprites.py --list                        # the index as a table
python3 docs/tools/render_topdown_sprites.py archers_e2                    # reproduce one
python3 docs/tools/render_topdown_sprites.py bomber_e4 --seed 404 --probe  # try a new roll
python3 docs/tools/build_motion_demo.py                                    # key, trim, re-embed
node docs/tools/check_motion_demo.js                                       # demo vs ADR-0006/0007
```

`--probe` writes candidates to `docs/tools/topdown-probe/` and leaves the accepted set untouched,
which is how a roll gets reviewed before it replaces a sprite. Accepting one means writing its
seed back into `topdown_demo_sprites.json`, otherwise the index stops describing the files.

Adding or dropping a class or era means three tables move together: `era_names` in
`core/data/cards.gd`, `CLASSES` in the demo, and `ERAS` in `build_motion_demo.py`. The `anti_air`
rows above are the one deliberate exception. Prompt wording these sprites depend on is in
`docs/explore-topdown-battle-and-units.md` §4.

## Why these cannot stand in for the game's unit art

Shipping unit art is the frozen side-view set in `assets/approved/units/`, resolved through the
registry in `core/data/asset_paths.gd` (`UNIT_DIR`, `UNIT_COVERAGE`, `unit()`, `has_unit()`) and
never a literal path. `docs/architecture.md` is where that rule lives. Three reasons this folder
is not a substitute:

- **Wrong camera.** Drawn top-down. The game is side-view, and top-down was explored and dropped
  as a game direction (`docs/explore-topdown-battle-and-units.md` §1). The camera here is a
  property of the sandbox, not a proposal.
- **Wrong format.** Unkeyed 1024×1024 raws with the grey render backdrop still baked in.
- **Wrong roster.** Keyed to the card catalog's classes, so no `enemy_weak` / `enemy_mid` /
  `enemy_hard` tiers, which the approved set does carry.
