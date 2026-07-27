# The battle scene is top-down

The battle scene is rendered from a top-down camera. The two forces still face each other and the
formation still reads front to back as the ordered cover chain of `ADR-0008` (近戰列 → 工事線 →
遠程列 → 空域); what changes is that the field is seen from above rather than from the side.

This **overturns the 2026-07-25 REFRAME**, which stopped the top-down direction and pinned the battle
screen as a locked side-view facing pair. The evidence that changed the decision is the presentation
work the sandbox produced after that stop: `insignificant-game/docs/explore-topdown-motion-demo.html`
put the full roster on a top-down field at real catalog stats and real roll order, and
`insignificant-game/docs/explore-topdown-battle-and-units.md` records that the top-down render came
out legible where the side-view rows could not show who was covering whom. The REFRAME's own
arbitration asked for the readability problem to be characterised before any camera change; the
sandbox is that characterisation, and the cover chain is the rule change it produced.

**Cover reads by spatial arrangement alone.** No cover indicator, no label, no badge on a screened
unit. The wall is drawn between the melee line and the ranged line, and that is the entire
explanation the player gets. This is the presentation half of ADR-0008 and the reason the camera
matters: from above, "this wall stands in front of those archers" is a fact you can see, which is
precisely what draw-order occlusion could not express.

## The cost is accepted knowingly

The audit that produced the REFRAME is deleted by human decision, so its cost evidence lives here
instead. It must not be lost, because it is what makes this decision an accepted expense rather than
an unexamined one.

**Sprite-count economics by perspective** (<https://cxong.github.io/2022/03/how-many-sprites-do-different-perspectives-need>,
WebFetch-verified): true overhead art rotated in software is **1x** sprite cost, side view **1 to
1.5x**, isometric 4-direction 2 to 2.5x, and illustrated **¾ oblique 3 to 3.5x**, because a ¾ view
needs at minimum a side set (mirrored L/R), a front set and a back set. Our renders are illustrated
¾, not true overhead, so the 1x top-down bargain does not apply to us. **This project is moving from
the cheapest sprite bucket toward the dearest, and discarding 76 already-approved pieces to do it.**
That is the price of the decision, stated plainly.

Two risks the audit raised are still open and are inherited by W14.8:

- **¾ top-down mirror-safety is untested.** Asymmetric costume, weapon hand and light direction all
  flip with the sprite. RimWorld's own modding documentation ships three unique facings and declines
  to blanket-mirror asymmetric apparel, so an L/R flip cannot be assumed to hold for our figures.
- **The camera splits by subject type.** Structures, emplacements, vehicles and aircraft render at a
  genuinely steep overhead angle, while multi-figure human groups and mounted figures drift back
  toward eye-level ¾ (`insignificant-game/docs/explore-topdown-battle-and-units.md`, §4 "Unsolved by
  prompt wording alone"). A single locked camera across the roster may need pose reference rather than
  prompt wording.

## Scope of the discard

**Discarded and re-rendered:** 69 sprites in `assets/approved/units/` (14 classes across their eras,
including `unit_shield_wall_*` and `unit_anti_air_*`, which are the fort line) and 7 side-view battle
backdrops `assets/approved/backgrounds/bg_battle_*.png`.

**Untouched:** 57 card illustrations, 76 building sprites, 75 UI icons, 15 portraits, 5 UI templates,
and the 10 non-battle backgrounds. **The city stays a side-view panorama by design**
(`insignificant-game/assets/pipeline/style-bible.md` §11): only the battlefield camera changes, and
the operations scene's living-city composition is unaffected.

## Consequences

- The art re-render is a wave of its own (W14.8) and runs **after** the core and demo wave, so the
  demo's top-down field informs the sprite brief: silhouette readability at battle zoom, whether
  mirroring holds, and the eye-level drift on mounted and multi-figure groups.
- `style-bible.md` §3's framing suffix splits: buildings keep `side view`, battlefield units and forts
  take a top-down prompt. The style recipe itself (Krea-2-Turbo + Moebius LoRA, no style words) is
  unchanged; only the framing clause moves.
- The battle core is unaffected. It gains no coordinates, no velocity and no movement. Station is a
  categorical place in the cover chain, and the view arranges the picture from it.
