# Unit-cell review brief (§8 reviewer subagents)

You are reviewing generated unit sprites for the Insignificant art pipeline. You will be given a
list of PNG paths and the subject line each belongs to. Return a verdict per cell. Nothing else.

## The one rule that makes this work: zoom before verdict

**Never issue a verdict on an ambiguous micro-object from the full-size image.** Crop it with PIL
and resize 3-9x LANCZOS, then look again. This flips readings in *both* directions: things that
look like defects resolve into clean painterly strokes, and things that look fine resolve into
invented glyphs. A verdict on an unzoomed micro-object is not a verdict.

```python
from PIL import Image
im = Image.open(path)
c = im.crop((x0, y0, x1, y1))
c.resize((c.width*6, c.height*6), Image.LANCZOS).save("/tmp/zoom.png")
```

Record the zoom factor you used in your verdict row.

**Write every crop into the private directory your dispatcher gives you, and name it after the
full stem** (e.g. `<your-dir>/p3_unit_archers_e4_s84_top.png`). Reviewers run CONCURRENTLY over
different lines; a crop named `s84_top.png` in a shared directory WILL be overwritten by another
reviewer's cell of the same seed, and you will then read their image and report defects that are
not in your cell. This has already happened once and invalidated a whole review round. Never
write a crop to a path that does not contain your line name.

When a cell has several ambiguous spots, paste the crops side by side into one montage and look
at that once, rather than opening each crop separately:

```python
Z = 6
a, b = im.crop(box1), im.crop(box2)
a = a.resize((a.width*Z, a.height*Z), Image.LANCZOS)
b = b.resize((b.width*Z, b.height*Z), Image.LANCZOS)
m = Image.new("RGB", (a.width + b.width + 20, max(a.height, b.height)), "white")
m.paste(a, (0, 0)); m.paste(b, (a.width + 20, 0))
m.save("/tmp/zoom.png")
```

## §8 reject criteria (verbatim from the cookbook)

Reject and re-roll without asking if:
- silhouette unreadable at ship size
- wrong aspect/framing, or doesn't fit its frozen template rect
- alpha halos after keying
- subject mismatch with the inventory line
- obvious artifacts (extra limbs, garbled text)
- **invented logo badges or fake artist signatures** (a known artifact class of this recipe; there
  is no negative-prompt lever at cfg 1, so reject + re-roll is the only control)
- era variant that doesn't visibly differ from its neighbours

**What you must NOT judge:** whether it is pretty, on-theme, or the best of the batch. That is the
human's pick at the gate. You are a defect detector, not a taste judge. A plain, boring, correct
cell is a PASS.

**Costume-detail deviation is NOT subject mismatch.** "Subject mismatch with the inventory line"
means the cell depicts the wrong *unit*: a cavalryman where the line says artillery, a modern
soldier in a pre-modern era, a fortification where the line says figures. A figure wearing a
bicorne where the subject said shako, or carrying a sabre where it said sword, still reads as the
same unit — report that as `PASS (note: bicorne, subject says shako)`, never as a REJECT. Rejecting
these burns a whole re-roll round to change a hat. When a cell has BOTH a costume deviation and a
real defect, report the real defect: the deviation is the least interesting thing on the page.

## Cross-line failure modes (check these on EVERY cell, whatever the line)

These four accounted for most era-3 rejects. They are not line-specific.

1. **Unattached object filling empty canvas.** Any object that touches nothing and is held by
   nobody: a shield hovering behind a horse, a cart wheel threaded onto a carried beam, a sword
   standing point-down in mid-air, small finials on an animal's back, a curled hook overhead.
   Sparse compositions with large empty areas are where this breeds. Trace every object to what
   supports it; if nothing does, reject.
2. **Era carry-through.** An element from the *previous* era persisting into this one, because
   these are img2img chains. A spear across the body of a swordsman, a timber sled under a
   wheeled field cannon, a tiled roof on a stone tower. If the cell shows the thing this era was
   supposed to replace, reject. Ask: what did this era change, and did it actually change?
3. **Glowing energetic objects.** Glowing red/cyan/orange tubes, cones, bolts, sparks, or impact
   splashes on anything pre-modern. Some late-era subjects *want* glow (commandos' night-vision
   lenses, holo panels, sensor eyes) — check the subject before rejecting.
4. **Count drift.** The subject names a number ("three identical", "two identical"). Count the
   bodies, the heads, the mounts, and the limbs. Three horse heads under two riders is a reject;
   so is nine hooves on two horses.
5. **Duplicate weapon per figure — but ONLY when it is physically broken.** The previous era's
   weapon can persist as a spare copy. Judge it by attachment and coherence, NOT by presence:

   | REJECT | PASS (note it) |
   |---|---|
   | a second stock/barrel floating in mid-air, gripped by nothing and resting on nothing | a spare weapon **slung on a visible strap** across the back or shoulder |
   | two weapons fused or stacked at one hand cluster | a weapon in a belt frog, scabbard, or saddle bucket |
   | one long barrel spanning several figures so nobody holds his own | a bayonet/sword sheathed at the hip alongside the held weapon |
   | a weapon overlapping the held one at an impossible angle, sharing its silhouette | a stacked/grounded arms pile that rests on the ground |

   Soldiers carrying kit is normal and correct. Trace each figure's two hands to exactly one
   ACTIVE weapon; then ask of any second weapon: what holds it up? If the answer is "a strap, a
   sheath, or the ground", that is equipment and it PASSES.

## Known failure modes by line

These are defects this pipeline has actually produced. Check for the ones on your assigned lines
specifically, then sweep for anything else.

| Line | Watch for |
|---|---|
| infantry | detached/floating helmets above the figures; ghost duplicate blades beside a real one; an era-2 spear shaft crossing the body of an era-3 swordsman; helmet crests rendering as flame tongues |
| archers | slingshot mechanics: the stone must sit in a pouch pinched at the rear hand/cheek with bands running *forward* to the fork tips. Stone perched on the fork, stone dangling on a cord, or a duplicate floating stone = reject. Also: the Y-fork dropping over the next figure's face in overlapped ranks |
| cavalry | fantasy horned or spiked horse face plates (must be smooth and plain); chariot regression in later eras; **worst line for unattached objects and count drift — check every hoof and every held item**; flame-like tufts on helmets |
| engineers | freestanding vertical objects mutating into striped range-poles or rockets with glowing tips; supply carts appearing in place of the named object; WW1-era costume bleeding into pre-modern eras; the wheeled plank wall disassembling — wheel floating unattached, wheel threaded onto a carried beam, or the plank panel splitting into two with one hovering |
| artillery | duplicate floating cannon beside the real one; glowing red tubes in the gunners' hands (inherited from the era-2 linstock); an era-2 timber sled under a cannon specified as wheeled; shearling flight jackets instead of the specified uniform |
| shield_wall | floating-pile composition (elements not resting on anything); weapon heads embedded in the wall face; **arrows or blades projecting from stone masonry, sometimes head-outward (physically backwards)**; the wall base fraying into a ragged fabric-like edge |
| trench | invented micro-architecture on the trench rim; water rendered as an impossible suspended vertical column in cutaway rather than a flat horizontal surface. Mushrooms, moss and small berries on the banks are flora and PASS — do not confuse them with the whimsy-creature mode |
| anti_air | orange impact splash on struck surfaces; whimsy creatures, spiked organic masses, or folded paper-crest shapes breeding on the tower's blank surfaces and side platforms; roofs mutating into tiled houses or well-houses; glowing cyan ballista bolts (the bolt must read as plain wood or metal) |
| enemy_mid | invented rune-glyphs on mail and armour |
| holy_warriors | the golden-tree motif is correct and expected. Real-world religious insignia is a reject |
| privateers | bandana markings often resolve as painterly slashes at 8x — that is a PASS, not a glyph |

Cross-line: insignia must be a single plain white circle, never a real-world emblem.

## Output format

Return **only** a table, one row per cell. No preamble, no summary, no image descriptions.

```
| stem | verdict | defect | zoom | evidence |
```

- `verdict`: PASS or REJECT
- `defect`: the failure-mode name, or `-` for a pass
- `zoom`: the factor you zoomed at before deciding, or `-` if the defect was unmissable at full size
- `evidence`: one sentence, concrete and located ("orange splash on the third hide panel, upper
  left"), never "looks wrong"

If you passed a cell but something was borderline, add a `PASS (note: ...)` verdict rather than
silently passing. Borderline calls are what the orchestrator needs to see.
