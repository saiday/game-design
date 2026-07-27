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

Five cells out of 52. Treat drift as a **§8 reject on those cells only**, and re-roll on seed
before touching wording: the exploration proved the steep-angle clause works everywhere else in the
roster under identical wording, which makes this seed luck rather than a wording bug (cookbook §8.2,
overlapped-rank occlusion, same reasoning).

## The defect the audit did not name: orientation is not free

This is the camera-specific failure mode and the reason a top-down reviewer cannot just reuse the
side-view checklist. On a top-down field the two armies face each other across a **left-right**
axis, so a sprite pointing anywhere else is wrong for *both* sides, and an X-flip cannot rescue it:
flipping a figure that points at the top of the frame leaves it pointing at the top of the frame.

Three cells in the exploration set fail this way, and all three are cases where the orientation
clause sits only in the framing **suffix**:

- `bomber_e4`, `bomber_e5` render **nose-left** under a suffix that says `its nose pointing right`.
- `bomber_e6` renders nose-up.
- `privateers_e4`, `privateers_e5` render facing the **camera**, with no left-right heading at all.
  A lone figure has no rank geometry to imply a heading, so the suffix is the only cue and it is
  too weak.

`phase3_units_topdown_batch.py` carries the fix for all five: **front-load the heading into the
subject clause** ("the nose and cockpit at the right edge of the frame and the tail at the left
edge", "striding toward the right edge of the frame") rather than trusting the suffix. This is the
same fix the exploration itself needed for figures, recorded in
`docs/explore-topdown-battle-and-units.md` §4: *"appending 'facing toward the right' as a suffix
clause was not reliably obeyed — front-load the direction cue instead."* The fix was applied to the
prompts but has not been re-rendered yet, so **verify the heading on every bomber and privateer
cell of this wave before picking one.**

## What a reviewer checks that the side-view brief does not

Everything in `review-brief-units.md` still applies verbatim. Add these four, in this order:

1. **Heading.** Player lines point at the **right** edge; the three abstract enemy tiers point at
   the **left**. Barriers (`shield_wall`) are the exception and must run **vertically**, top edge to
   bottom edge — a wall lies across the field, it does not face along it. Emplacements
   (`anti_air_e1`–`e4`) have no heading and pass at any rotation.
   A cell with no readable heading is a reject, not an ambiguity.
2. **Camera.** Steep overhead. A cell that reads as eye-level or near-side-view is a reject even
   when the subject itself is clean. Judge against its own line's siblings, not against an absolute.
3. **Mirror.** X-flip the cell and look again. Reject only on a defect the flip *creates* —
   a hand-swap alone is not one.
4. **Footprint.** These sprites stand on a field seen from above, so the silhouette is read as a
   footprint. A subject whose bounding box is wildly out of family with its line (the side-view
   round's era-4 airship rendered at 3.59:1 against a 0.42–1.58 roster) crowds its station on the
   field. Framing words cannot fix this — only a subject change can — so flag it as a
   subject-wording question for the human, not a re-roll.

## Judge at battle zoom, not at sheet size

The units class had no equivalent of the icon rule (cookbook §8.4: icon expressiveness is judged at
44 px, never at sheet size), because a side-view sprite was read at a comfortable size. Top-down
sprites are smaller on screen and there are more of them at once. **Judge silhouette readability by
downscaling the cell to its on-field size and looking at that**, then zoom for the §8 micro-object
pass. A sprite that only reads at sheet size does not read on the field.
