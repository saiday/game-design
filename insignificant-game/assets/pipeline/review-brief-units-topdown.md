# Top-down unit re-render: roster audit and camera brief (W14.8)

Companion to `review-brief-units.md`, which stays the §8 reject checklist and is unchanged. This
file carries only what the **camera change** adds: the two risks ADR-0009 handed to W14.8, what the
evidence says about them, and the camera-specific defects a reviewer must look for that the
side-view brief never had to name.

The evidence is the top-down exploration set: 52 raws at `assets/exploration/topdown-demo/`,
one roll each, prompts and seeds in `docs/tools/topdown_demo_sprites.json`. They are exploratory
raws and none of them ships (`assets/approved/` is fed only by this wave's pick gate), but they are
a full-roster render under the exact locked recipe, so they answer the open risks with pictures
rather than argument.

## The two inherited risks, answered

**Risk 1 — "¾ top-down mirror-safety is untested" (ADR-0009).** Tested; it holds at battle zoom.
An X-flip of the vehicle subjects (tank, self-propelled gun, engineering vehicle, laser turret) is
clean: they are near-symmetric about their long axis, so the flip only reverses the heading, which
is the point. On figures the flip swaps the weapon hand, which RimWorld's modding docs decline to
do for asymmetric apparel — but our figures carry no asymmetric costume that survives at battle
zoom, and the one sanctioned surface mark on hulls is a plain white **disc**, which is
mirror-invariant. **No mirroring defect was found. Mirroring is approved for enemy-side reuse of
player sprites.** The golden-tree emblem on `holy_warriors`/`elite_forces_e3` is the one mark worth
re-checking per cell, since it is only roughly symmetric.

**Risk 2 — "the camera splits by subject type; mounted and multi-figure groups drift toward
eye-level ¾".** Partly real, and much narrower than feared. Structures, barriers, emplacements,
vehicles and aircraft come out genuinely overhead. **Multi-figure foot groups do not drift** — they
sit at a consistent steep high angle across all six eras of every foot line, which was the outcome
in doubt. The drift is confined to:

| Cells | What drifts |
|---|---|
| `cavalry_e3`, `cavalry_e4` | mounted figures; the horses read close to side-on |
| `artillery_e4` | the wheeled gun carriage reads side-on, wheels in profile |
| `anti_air_e1`, `anti_air_e2` | era-1/2 timber structures read ¾ rather than overhead |

Five cells out of 52 (`cavalry_e2`'s chariot is a mild sixth). **Drift on these cells is accepted by
human ruling and is not a reject.** Do not re-roll them, do not re-word them, and do not raise them
at the pick gate as defects.

The ruling rests on a measurement, not on taste alone. The W14.8 sweep rendered four fresh seeds of
each drifting cell under identical wording: **20 renders, 20 drifts, zero exceptions**, with the four
seeds of each cell near-identical to one another. That is cookbook §8.3 rung 4's stop signal — a
stable checkpoint preference, not seed luck — so more seeds and more wordings are both waste. The
mechanism: **the camera drifts wherever the subject's readable identity lives on a vertical face.** A
tank is identified by its roof outline and renders overhead happily; a horse from directly above is
an oval, a spoked wheel from above is a line, and a watchtower's whole point is its height. The model
is resolving a conflict between the camera and recognizability in favour of recognizability.

What the acceptance costs is **set coherence, not readability**: a side-on horse pointing right still
reads as cavalry at on-field size, it simply sits at a different camera from the tank beside it.
Reopening this needs a tooling lever (img2img pose reference, ControlNet region lock) as ADR-0009
anticipated — a §12 escalation, never another wording round.

The same line contains the counter-example that proves this is subject-driven rather than a limit of
the recipe: `anti_air_e3` renders a genuinely overhead circular tower top, because its prompt names
*the top* ("its top an open flat circle of bare stone paving"), while `anti_air_e2` names *height*
("a tall timber arrow tower"). Naming what is visible from above is what works — the accepted cells
are the ones where nothing useful is.

## The defect the audit did not name: orientation is not free

This is the camera-specific failure mode and the reason a top-down reviewer cannot just reuse the
side-view checklist. On a top-down field the two armies face each other across a **left-right**
axis, so a sprite pointing anywhere else is wrong for *both* sides, and an X-flip cannot rescue it:
flipping a figure that points at the top of the frame leaves it pointing at the top of the frame.

**The cells that fail this way are the single-figure ones.** `privateers_e4` and `privateers_e5`
render facing the **camera**, with no left-right heading at all: a lone figure has no rank geometry
to imply a heading, so the framing suffix is the only cue and it is too weak. Multi-figure groups
never fail it, because the rank itself states a direction.

`phase3_units_topdown_batch.py` fixes both by **front-loading the heading into the subject clause**
("striding toward the right edge of the frame") rather than trusting the suffix — the fix the
exploration itself needed for figures, recorded in `docs/explore-topdown-battle-and-units.md` §4:
*"appending 'facing toward the right' as a suffix clause was not reliably obeyed — front-load the
direction cue instead."* The W14.8 sweep confirms it: all four seeds of each privateer cell now
stride right.

**Do not cite the bombers here.** An earlier pass of this brief claimed `bomber_e4/e5/e6` rendered
nose-left under a nose-right suffix. That was a misread of a thumbnail in a 7-column sheet: at full
size the exploration rolls point nose-**right**, and so does every seed of the sweep. The bomber
cores carry the front-loaded clause anyway for roster consistency, but they are not evidence of
anything. The lesson is the cheap one — **verify an orientation call at full size, never from a
contact-sheet thumbnail**, which is the same zoom-before-verdict rule §8.1 already states for
micro-objects, applied to whole-subject geometry.

## What a reviewer checks that the side-view brief does not

Everything in `review-brief-units.md` still applies verbatim. Add these four, in this order:

1. **Heading.** Player lines point at the **right** edge; the three abstract enemy tiers point at
   the **left**. Emplacements (`anti_air_e1`–`e4`) have no heading and pass at any rotation.
   A cell with no readable heading is a reject, not an ambiguity.
   **Barriers (`shield_wall`) are judged on axis, not heading, and the axis is not the renderer's
   job.** On the field a wall lies **across** the lane, top edge to bottom edge; in the render it
   lies **along** the frame, left to right, and the view rotates it 90°. That split is deliberate:
   asking for a top-to-bottom segment is what tapered every wall to a vanishing point along its own
   length for three rounds, because a long axis stated against the short side of a 1:1 frame invites
   a viewer to stand at one end of it. So check a barrier for a straight, constant-width, both-ends-
   finished row running left to right, and read its on-field axis off the view, never off the sheet.
2. **Camera.** Steep overhead. A cell that reads as eye-level or near-side-view is a reject even
   when the subject itself is clean. Judge against its own line's siblings, not against an absolute.
3. **Mirror.** X-flip the cell and look again. Reject only on a defect the flip *creates* —
   a hand-swap alone is not one.
4. **Footprint.** These sprites stand on a field seen from above, so the silhouette is read as a
   footprint. A subject whose bounding box is wildly out of family with its line (the side-view
   round's era-4 airship rendered at 3.59:1 against a 0.42–1.58 roster) crowds its station on the
   field. Framing words cannot fix this — only a subject change can — so flag it as a
   subject-wording question for the human, not a re-roll.

## Two rules the first pick gate produced

Both came from the human's round-1 review and both are camera-specific, so they belong here rather
than in the side-view brief.

**A sprite must be a discrete object with visible ends.** The round-1 barrier suffix said the wall
ran "from the top edge to the bottom edge of the frame", which instructed it to bleed off both
edges. Five of the six `shield_wall` cells were rejected for exactly that: with no finished ends
there is nothing telling the player where one wall segment starts and stops. This is worse than a
composition wart, because freezing alpha-trims a sprite to its own bounding box — a subject that
touches the frame edge gets an arbitrary crop rather than its silhouette. `shield_wall_e6` passed
because its core said "a **segment** of modular barrier wall". The suffix now asks for a short row
of identical modules with an end cap at each end and bare ground on all four sides. **Check that
every cell's subject sits fully inside its frame**, and reject anything touching an edge.

**Battlefield units must read as mobile, not emplaced.** These sprites move between stations during
a battle, so a pose that only makes sense standing still is wrong regardless of how well it renders.
Round 1 rejected `archers_e5` (both snipers kneeling behind a bipod) and `artillery_e5` (a crewman
standing on a ladder against the hull) on this rule alone; both were clean by every other §8 check.
Prefer striding, carrying, and levelled-forward poses. Applying it needs the §8.3 rung-2 move rather
than a prohibition: `artillery_e5`'s crewman was removed by **occupying** the deck with lashed
stowage and a tarpaulin, not by naming the crew in order to banish them.

## Judge at battle zoom, not at sheet size

The units class had no equivalent of the icon rule (cookbook §8.4: icon expressiveness is judged at
44 px, never at sheet size), because a side-view sprite was read at a comfortable size. Top-down
sprites are smaller on screen and there are more of them at once. **Judge silhouette readability by
downscaling the cell to its on-field size and looking at that**, then zoom for the §8 micro-object
pass. A sprite that only reads at sheet size does not read on the field.
