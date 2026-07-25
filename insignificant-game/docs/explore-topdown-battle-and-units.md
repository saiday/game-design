# Exploration log: top-down battle + RimWorld-style unit art

> **STOPPED — a depandabot audit on 2026-07-25 returned `REFRAME`.** The founding premise below
> ("world war = many parties on a shared field, so side-view scales badly") is **false**:
> `design/世界大戰.md` pins world war at 恰兩營 — exactly two camps, no neutral — and the design
> already solves faction identification with civ colour tinting over existing art (不需新圖).
> `core/battle.gd` also holds no positions at all (units carry a categorical row), and battle is
> watch-only, so unit movement has no state to render. Do not resume this direction without a
> human decision. Full reasoning, evidence and the Codex verdict:
> `docs/depandabot/2026-07-25-topdown-battle-unit-motion.md`. What survives the audit is listed
> in that file's §6 "What survives". Falsified claims below are annotated in place with their
> objection IDs (O1-O5); the human's 2026-07-25 arbitration is the last entry in the session log.
> **One thing continues by explicit human decision: `explore-topdown-motion-demo.html`, now a
> presentation sandbox for unit stats and combat rolls. Its camera is a sandbox property, not a
> game-camera decision.**
>
> **Status: EXPLORATORY — nothing here is decided or locked.** This is a running thought log
> for a *possible* future direction, kept at the human's request. It deliberately does **not**
> edit any locked doc yet: `design/戰鬥.md` (場景呈現), `assets/pipeline/style-bible.md` §11, the
> inventory, and the frozen units/backgrounds all still describe the shipping side-view game.
> Treat this as a proposal-in-progress; promote pieces into the locked docs only through the
> normal design gate + §12 style escalation, and only when the human commits.

This is a purpose-built log (dated entries allowed, like `decisions.md` / cookbook §14), not a
current-state doc.

## Why this exists (the trigger)

The human asked to explore giving units a different art style, initially framed as "pixel art,"
with RimWorld as the reference. Investigation reframed the request:

- **RimWorld is not pixel art.** Its pawns are smooth, minimalist, flat 2D illustrations (clean
  simple shapes, soft/anti-aliased edges, light shading) — the Prison Architect limbless-bean
  lineage. Press/artists call it "minimalist / simplified 2D," explicitly not pixel art.
- **RimWorld is not 3D-on-2D / 2.5D.** Its multiple views are a small set of **pre-drawn 2D
  directional sprites** — 4 cardinal facings (west usually mirrors east), stacked paper-doll
  (body → head → hair → apparel as separate PNG layers, composited at runtime). Camera is ¾
  top-down. It is flat 2D with a handful of authored facings, not a rotating 3D rig.

So the pixel-art pipeline question is **moot**; the real reference is *flat-minimalist top-down*.

## The design motivation for going top-down (human's reasoning)

The pull toward RimWorld's top-down camera is not cosmetic. It is driven by a concrete gameplay
need:

> **世界大戰 (world war) involves multiple parties and many units sharing one battlefield.**

**[FALSIFIED by O1: `design/世界大戰.md` pins 恰兩營 (exactly two camps, 無中立), so world war is
still a two-sided fight. Multi-*civilization* is not multi-*side*. `core/world_war.gd:5-6, 26-34`
implements it that way. The whole motivation below rests on this false premise. It is kept here
because this is a log; do not carry it forward.]**

Our current battle presentation is **side-view**: two rows facing each other (fortification →
melee → ranged → air), one facing per unit, mirrored for the enemy. That composition is built
for a **two-sided** fight. It scales badly to *many factions × many units on one shared field*:
a side-on line has only "left vs right," so a 3+ party melee has nowhere to live spatially.
**[FALSIFIED by O1: a two-camp fight is exactly what this composition renders. There is no 3+
party melee in the design. The design also already solves faction identification without any new
art: per-unit civ colour/flag markers, 「沿用現有單位美術套色，不需新圖」.]**

A **top-down** field naturally holds many units and multiple factions positioned anywhere on a
2D plane — which is exactly why colony/tactics games (RimWorld, Prison Architect) use it. That
is the candidate this exploration is chasing.

## Scope of this round (human's guardrails)

- **Explore the unit ART STYLE for a top-down redesign. That is enough for now.**
- **Do NOT edit the locked docs** (`design/戰鬥.md`, style-bible §11, inventory) in this round.
- **Keep this log** as the future-plan record.

Explicitly *out of scope this round*: rewriting the battle-scene design, changing the
auto-deployment model, regenerating assets, or touching `core/battle.gd`.

## Consequences to keep in view (if this is ever adopted)

Recorded now so a future decision is informed, not to act on:

1. **The finished units class becomes obsolete.** All 52 player + 18 enemy unit sprites across
   6 eras (months of §8-gated work, pick-gates converged) are **side-view, single-facing**. A
   top-down multi-facing model cannot reuse them as-is.
2. **The 7 battlefield backgrounds become obsolete.** They are side-view compositions
   (`bg_battle_*`, frozen). A top-down field needs top-down ground plates.
3. **Asset count multiplies with facings.** 1 side sprite → up to 4 directional sprites per
   unit (or fewer if we choose 2, or a mirror trick). Paper-doll layering could offset this by
   generating parts once and composing, RimWorld-style — worth evaluating against our
   "structure-once, content-fresh" template doctrine (cookbook §6).
4. **Locked docs must change through the proper gate.** `design/戰鬥.md` 場景呈現 (side-view
   two rows) and style-bible §11 (three scenes, side-view battle) are the authority; changing
   the camera is a design-corpus decision + a §12 style escalation, human-owned.
5. **The auto-deployment spatial model** (fortification line → melee → ranged → air) is
   described spatially as facing rows. Top-down would re-express it as zones/rings, not lines.
   **[FALSIFIED by O2: there is no spatial model to re-express. `core/battle.gd` carries no
   coordinates, distance, velocity, or movement of any kind. A unit's `row` is a categorical
   `StringName` (`&"melee"` / `&"ranged"` / `&"air"`, e.g. `battle.gd:345`, `:422`, `:510`,
   `:571-573`) and targeting is row-based per tick. 「工事線 → 近戰列 → 遠程列 → 空域」 is screen
   *composition* (`design/戰鬥.md:59`), not state. Zones/rings would be inventing positions the
   core does not have.]**

## Unit art direction under exploration (top-down, flat-minimalist)

Derived starting position for the art style — to be validated with a sample board, not final:

- **Viewpoint:** ¾ top-down (RimWorld/Prison Architect angle), consistent across all units.
- **Facings:** start by evaluating **4 cardinal** (N/S/E/W, W mirrors E → effectively 3 draws)
  vs a cheaper **2 facings** or **1 + mirror**. The right number depends on whether battle
  units actually need to turn, which is a battle-design question deferred to a later round.
- **Silhouette language:** simple, readable, limbless-or-minimal-limb bean/oval bodies; dot
  faces; "read for clarity, not admired" (RimWorld's stated philosophy). Cheaper to produce
  than our detailed Moebius figures, which is part of the appeal.
- **Style engine — likely NO new model needed.** RimWorld's flat look is close in spirit to our
  existing **Krea-2-Turbo + Moebius LoRA** recipe (flat fills, clean lines). The change is
  mostly the **framing suffix** ("¾ top-down view" instead of "side view, centered") plus
  subject wording that asks for simpler, flatter figures. This avoids reinstalling any model
  (the pixel-art LoRAs removed in the July cleanup stay removed) and keeps one style voice
  across the game. To be confirmed by a board.
- **Native resolution (answers the human's "is 300×300 enough?" question):** for a flat
  illustrated pawn (not true pixel art), authoring resolution isn't the pixel-crispness
  constraint it would be for pixel art. Generate at the recipe's native ~1024² and scale
  in-engine (our standing rule, style-bible §4/§8); the on-screen pawn size in a top-down field
  is small (RimWorld pawns are tiny), so 300×300 as a *display* size is plausible but should be
  driven by the final battle zoom, not chosen up front. Decide display size from an in-engine
  mock, not a guess.

## Path-3 probe outcome (2026-07-24, prompt-only levers)

Sheet: `assets/contact-sheets/explore_topdown_probe2.png` (raws only). Two levers, both worked:
- **Steeper angle wording works and improves consistency.** Suffix
  `"steep high-angle view looking down from almost directly above"` steepened the angle and,
  critically, fixed the hard case: archers-e4 (near eye-level on the first board) came out
  clearly overhead in both seeds. Prompt-only can get materially closer to top-down; still not
  a pixel-locked camera, but far more consistent than the vague "three-quarter top-down".
- **Simplified-FORM wording works where style words failed.** Describing the subject's *form*
  ("simplified stylized figures with rounded chunky bodies and minimal facial detail") produced
  visibly chunkier, bigger-headed, less-rendered figures — a real step toward RimWorld's cheap
  look, staying in the Moebius idiom. This confirms cookbook §14's rule: describe the SUBJECT,
  not the art STYLE (style words fight the LoRA). The earlier "simplified readable shapes"
  (a style phrase) did nothing; the form description did.

**Conclusion: the top-down LOOK is achievable cheaply with the existing recipe (steep + simplified-
form wording, no new model).** What prompt-only still can NOT solve, and which remain the real
cost decisions: (1) a pixel-locked shared camera (seed variance remains); (2) the 4-facing
consistency wall (diffusion won't render "the same unit" from N/S/E/W); (3) count drift (routine
§8). These need Path-2 tooling (fixed camera via ControlNet/pose, dedicated facing rig) and only
matter if gameplay requires units turning/moving in all directions.

**[FALSIFIED by O3, the word "cheaply": a single render being cheap is not the same as the
perspective being cheap. By per-perspective sprite-count economics
(<https://cxong.github.io/2022/03/how-many-sprites-do-different-perspectives-need>), top-down
overhead art rotated in software is **1x**, **side view is 1-1.5x**, and **illustrated 3/4
oblique is 3-3.5x**. A 3/4 view needs "at the very least 3 sets of sprites: side view (mirrored
for left/right), front view and back view". Our renders are illustrated 3/4, not true overhead,
so this direction moves the project from the cheapest sprite bucket to nearly the dearest. The
1x top-down bargain does not apply to us. What is cheap here is one prompt swap; what is
expensive is the asset class that follows it. This inverts the cost motivation for the whole
exploration.]**

## Facing & movement on the battlefield (derived; view-layer only)

**Architectural pin (CORRECTED 2026-07-25, the original text was factually wrong):** facing and
movement are **VIEW concerns**, never core. `core/battle.gd` stays pure deterministic tick logic;
the view interpolates between logical states. How a unit *looks* moving must not leak into core
or determinism breaks.

The original wording claimed core provides "positions/zones per tick". **It does not, and never
did.** `core/battle.gd` holds no coordinates, no distance, no velocity and no movement. A unit's
only spatial attribute is a categorical `row` StringName (`&"melee"` / `&"ranged"` / `&"air"`,
`battle.gd:345`, `:422`, `:437`), and targeting is row-based per tick. What core emits per tick
is strike events plus row membership. Consequence (this is O2): **a view that moves units has no
logical state to interpolate.** Any movement here is pure decoration invented by the view, not a
rendering of something the game models. That is a legitimate thing for a *visualization sandbox*
to do (see the demo below), but it is not a battle-design proposal and it cannot be justified as
"showing what the core computes".

**Facing** — our units are drawn ¾-angled (not flat bird's-eye), so single-sprite rotation is
out (a rotated ¾ humanoid looks like it's lying down). Options, cheap→dear:
- **L/R flip (2 facings):** 1 sprite + mirror. Cheapest; fine if the field stays lanes-vs-lanes.
  **[FALSIFIED by O4: not a credible production assumption for illustrated 3/4 art. Mirroring
  flips asymmetric costume, weapon hand and light direction. Two independent sources say so:
  slynyrd's top-down animation post ("Due to asymmetry of the hair, and equipment, unique frames
  had to be created for all eight orientations") and RimWorld's own modding doc, which ships
  textures "one each for south, north, and east facings" with west auto-mirrored from east
  **only when** the apparel is symmetric, supplying a real `_west` texture otherwise. So the
  RimWorld precedent argues for **3 unique directions, not a 2-facing flip**, so it cannot be
  cited for the cheap option.]**
- **4 cardinal (N/S/E/W, W mirrors E = 3 draws/unit):** true RimWorld, but multiplies art ~3×
  per unit×era AND our AI pipeline can't reliably render "the same unit" from 4 angles
  (diffusion won't hold one character across renders — RimWorld hand-draws its facings). This is
  the real cost wall for the top-down direction.
- **8-direction:** ~6 draws/unit; almost certainly overkill.

**Movement — key insight: RimWorld barely frame-animates.** A walking pawn is the sprite
*translating* (position tween) + tiny procedural bob/lean; attacks are a lunge/recoil tween + a
weapon-swing or projectile sprite. Cost spectrum for us:
1. **Transform tween + procedural motion (recommended):** move the node's position, add
   bob/squash/lean via tweens/shader. Zero extra art, pipeline-friendly, matches RimWorld
   reality. Attacks = lunge tween + projectile/weapon sprite + hit particle.
2. **Skeletal/cutout rig** (Godot `Skeleton2D` + paper-doll layers, or Spine-style): real limb
   motion from the layered parts, one rig reused across units. Middle effort.
3. **Frame-by-frame walk cycles** (`AnimatedSprite2D`): most expensive AND hostile to our
   AI-generation pipeline (frame-to-frame consistency is diffusion's hardest problem; units ×
   eras × directions × frames explodes). Treat as out of scope at our scale.

**Recommendation:** discrete-sprite facing (start L/R flip, add N/S only if the field needs it)
+ position-tween movement with procedural bob + tween/projectile attacks. Defer skeletal rigging
until a specific unit demands limb motion; frame animation out of scope.

**[WITHDRAWN by O2 (and its facing half by O4): there is nothing to recommend a movement model
*for*. The battle is watch-only (`design/戰鬥.md:60`「戰鬥是用看的」) and resolved without positions,
so a motion tier answers a question the game never asks. Two implementation notes are preserved
in case a future round ever revives this: any per-unit tween/bob approach needs a field-count
performance threshold (Godot 2D node-count ceiling vs MultiMesh, which gives up per-instance
scripting), and a constant sine bob is specifically warned to read robotic, so it would need
variable timing and probably squash-stretch `scale` tweens. What survives unconditionally is the
narrower claim that **frame-by-frame walk cycles are the wrong default for an AI sprite
pipeline** (independently validated by Battle Brothers). That is an argument about animation, not
about camera.]**

**Interactive demo of this tier:** `explore-topdown-motion-demo.html` (this folder) — open it
directly in a browser. It runs a live top-down skirmish using the actual exploratory renders,
with each technique (flip / walk-tween / procedural bob / lunge / projectiles) as a toggle and a
"frames generated: 0" counter to make the point. Self-contained: sprites are embedded as data
URIs, no network or server needed. It illustrates the motion tier, not a battle-design proposal
(its unit pathing lets armies intermix — a demo shortcut, not intent).

**Status after the 2026-07-25 arbitration:** the demo continues to be developed, reclassified as a
**presentation sandbox**, a place to see unit stats, rosters and combat rolls resolve visually.
Its top-down camera is a property of the sandbox, **not** a camera recommendation for the game.
See the arbitration entry at the end of this log.

## Open questions (for future rounds, not now)

- Does a top-down battle actually improve the *core* two-sided battles, or only world war? If it
  only helps world war, is a mixed presentation (most battles side-view, world war top-down)
  coherent, or worse than committing to one camera?
- Facing count: do battle units need to turn at all, or do they just stand in zones? (Drives the
  art cost 1×→4×.)
- Paper-doll layering vs whole-figure generation under our template doctrine.
- Reuse: can any frozen side-view art inform the top-down set (palette, era read), or is it a
  clean restart?

## Next step

Produce a small **exploratory art board**: a handful of units rendered ¾ top-down in the
flat-minimalist style, using the existing recipe with a swapped framing suffix, so the human can
judge the look before any locked doc or asset is touched. (Requires bringing the ComfyUI service
up; it is installed but currently stopped.)

## Session log

- **2026-07-24 — board run.** Fidelity chosen by human: *halfway to Moebius* (top-down +
  simplified, keep some line/color richness). Recipe unchanged (Krea-2-Turbo + Moebius LoRA);
  only the framing suffix swapped to `"game unit sprite, three-quarter top-down view seen from
  above, simplified readable shapes, centered, isolated on a plain light gray background"`, and
  side-view pose language ("right-facing profile", "toward the right edge") stripped from each
  reused subject core. Board = infantry/archers/cavalry × era1/era4 × seeds 401/402.
  - **Probe finding (infantry_e1_s401):** the suffix yields a *mild elevated ¾ overhead angle*,
    NOT RimWorld's steep straight-down top-down — units are seen from above-and-front, readable
    for a dense field but not a true bird's-eye. `"simplified readable shapes"` barely registered
    (the LoRA resists style words, per style-bible §3 / cookbook §14) — output stays full-detail
    Moebius. Net: reads as *our style, viewed from above*, which matches "halfway to Moebius."
    Also observed: count drift (asked 3, got ~5) — expected, not chased in exploration.
  - **Follow-up levers if a steeper/flatter true top-down is wanted:** stronger angle wording
    ("directly overhead / steep bird's-eye"), and for genuine simplification a different
    approach than prompt words (a flatter model/LoRA, or accepting Moebius richness). Deferred
    until the human reacts to this board.
  - **Board outcome (12 cells, `assets/contact-sheets/explore_topdown_units.png`, raws only):**
    all 12 clean/on-style/keyable; era jumps accurate. Confirms the recipe produces overhead
    unit views with only a framing-suffix swap (no new model). BUT three findings: (1) **the
    camera angle is not lockable by wording** — infantry-e1 and cavalry-e1 read nicely overhead,
    while both archer rows and era-4 musketeers came out near eye-level ¾; a shared-camera
    top-down battlefield needs a fixed camera, which prompts don't give. (2) **"simplified"
    did not take** — output is full Moebius richness, so this is "our style, angled," not a
    cheaper/simpler look. (3) routine §8 noise: cavalry-e4 s402 framing crop, infantry count
    drift to ~5. **Conclusion: a consistent steep RimWorld-style top-down is NOT reachable by
    prompt-swap alone** — it needs a fixed camera (ControlNet/pose ref) or a dedicated
    top-down/flat model, a larger effort than this round. Awaiting human direction on whether
    the angled-Moebius look is the direction or a true steep top-down is wanted.

- **2026-07-25, depandabot audit: `REFRAME`.** Full artefact:
  `docs/depandabot/2026-07-25-topdown-battle-unit-motion.md`. Codex returned `OBJECT` with 7
  objections; the 5 conceptual ones (O1-O5) were accepted with no rebuttal, which terminated the
  loop at round 1 per the Bucket Rule. O1: the founding premise is false (世界大戰 is 恰兩營).
  O2: the battle core has no positions, so movement has no logical referent. O3: illustrated 3/4
  is 3-3.5x sprite cost against side view's 1-1.5x, inverting the cost motivation. O4: L/R flip is
  not credible for asymmetric illustrated art. O5: the design already solves world-war faction ID
  with colour tinting over existing art, so a camera change discards a solved cheaper solution and
  invalidates 69 approved unit PNGs + 7 side-view backdrops. O6/O7 (implementation) accepted as
  valid but moot. The falsified claims in this log's body are annotated in place with their
  objection IDs.

- **2026-07-25, human arbitration.** After reading the audit, the human ruled:
  - **The 5 reframes are accepted for the game direction.** Top-down as a *game camera* stays
    stopped. Do not resume it without a fresh human decision, and if the world-war readability
    intuition is revisited, characterise the actual problem first (units on screen per wave, what
    specifically fails to read) before proposing any camera or art change.
  - **The demo continues, as a presentation sandbox only.** `explore-topdown-motion-demo.html`
    stays top-down. This is an explicit human decision about a *visualization tool*, deliberately
    **not** a camera decision for the game, and it does not reopen O1-O5. It exists to watch unit
    stats and combat rolls resolve on screen.
  - **Four upgrade items requested for the demo:** (1) HP bars that are never covered by unit
    sprites; (2) visible attack / miss / dodge effects; (3) the full unit roster rather than a
    sample, with an era selector to switch between the 6 eras; (4) a live metrics table showing
    each unit's stats. The demo mirrors `core/battle.gd`'s roll order (accuracy then dodge, fort
    absorption, siege/air demolition, engineer repair) so the numbers on screen are the game's
    numbers, even though the movement carrying them is sandbox decoration.
  - **ComfyUI restarted solely to render the top-down sprites this demo needs**, then shut down
    again. The renders are exploratory raws under `assets/exploration/topdown-demo/`, never
    `assets/approved/`; style-bible and `inventory.md` are untouched.

- **2026-07-25, demo upgrade delivered.** `explore-topdown-motion-demo.html` now runs the full
  roster with an era selector, and takes its numbers from the game rather than from invented demo
  values.
  - **Stats are transcribed, not invented.** 攻/血 are the `core/data/cards.gd` catalog bases
    scaled by `core/era.gd` `COST_COEFF` (1/2/3/5/8/12); 命中率/閃避率/攻速 are the midpoints of
    each class's v1 medium quality band (`cards.gd` `QUALITY`). Era names are the catalog's six
    per-class form names. Verified at both ends of the range: era 1 shows 棍棒戰團 攻1/血2, era 6
    shows 動力裝甲兵 攻12/血24 and 電磁砲 攻48.
  - **Roll order mirrors `Battle._fire`.** Siege/air demolition of a standing fortification first
    (no roll, no repair), then fortification absorb (盾陣 one melee, 防空 one ranged/air, ignoring
    attack value, turning 待修 instead of consumed when an engineer lives), then accuracy roll,
    then dodge roll. Engineers never attack and repair one fortification per round starting the
    round after it was damaged. A side holding only air units cannot claim the field.
  - **Sprite set: 52 raws, no gaps.** One per class×era for the 11 classes the demo fields, all
    rendered fresh; the build script needed no era substitutions. Recipe unchanged
    (Krea-2-Turbo + Moebius LoRA @1.0, euler/simple, 8 steps, cfg 1.0, `ConditioningZeroOut`),
    subject wording taken from the approved manifest rows with side-view pose language rewritten
    to view-neutral phrasing and the steep-angle framing suffix appended. Seed 401 throughout,
    with six cells re-rolled at seed 402.
  - **Build tooling:** `docs/tools/build_motion_demo.py` keys the plain grey render background to
    transparent by flooding inward from the frame edges (so pale interior fills are not punched
    through), trims, downscales to 256px, quantises to 128 colours, and rewrites only the
    `@SPRITES` / `@CREDITS` marker blocks so hand-edited JS and CSS survive re-runs. The demo
    stays one self-contained double-clickable file at 1.24 MB.
  - **QC finding worth keeping: the camera splits by subject type.** Structures, emplacements,
    vehicles and aircraft come out genuinely steep overhead. Multi-figure human groups still
    drift toward eye-level three-quarter even with the steep-angle suffix that fixed archers-e4 in
    the probe. This reproduces the board finding above and matches the audit's position that a
    shared camera is not lockable by prompt wording. Acceptable for a stats sandbox; for any real
    top-down asset class it would need a fixed camera (ControlNet/pose reference), which O3
    already priced out.
  - **A prompt-cleanup bug worth recording:** the first pass rewrote several directional phrases
    but missed `"both facing right"`, so six cells (archers e5/e6, elite_forces e2/e3/e5/e6) were
    rendered with side-view pose language still in the prompt. Re-rolled at seed 402 with the
    wording fixed; all six came back equal or better, and two of them (elite_forces e2 and e5)
    also fixed genuine count drift, having rendered one figure where the prompt asked for two.
- **2026-07-25, round 2: sprites regenerated for facing, and a Codex review.** Human feedback
  found three defects, one of which exposed a mistake in the round-1 prompt work.
  - **The facing flip was broken, and the prompts caused it.** Round 1 stripped every
    right-facing phrase out of the subject wording to remove side-view language. That also
    removed the only thing an X-flip can mirror: sprites faced the camera, so flipping them did
    nothing legible. Round 2 pins orientation explicitly (`the whole group oriented toward the
    right edge of the frame, bodies and weapons pointing right`), which a steep overhead view
    supports well, since a near-overhead figure mirrors cleanly. Verified: every unit on the left
    faces right and every unit on the right faces left, with weapons, mounts and gun barrels all
    mirroring correctly.
  - **The simplified look now actually lands.** Round 1 used a truncated form phrase and the LoRA
    ignored it, leaving full-detail Moebius figures. Round 2 restores the full probe wording
    (`simplified stylized figures with rounded chunky bodies and no facial features`), which
    reproduces the `exp_td2_simple_*` look: chunky, big-headed, blank-faced.
  - **The bomber is no longer a horizontal shooter.** It was firing an arcing projectile like an
    archer. A bomber now has a 70px reach so it must fly over its target, and the bomb falls
    straight down from the fuselage. Bomber sprites no longer carry visible bombs, since the
    attack spawns one.
  - **Attack motion is per class**, not one shared lunge: melee lunges forward, cavalry charges
    with a roll, muskets and rifles recoil backward, artillery recoils hard with a scale kick,
    a bomber banks with no translation, engineers have none.
  - **Flying weapons are generated art.** Eight projectile sprites (stone, arrow, bolt, bullet,
    missile, cannonball, shell, bomb) mapped per class and era, authored pointing right, with the
    bomb authored nose-down for its vertical fall. Total set is 60 sprites at 1.12 MB.
  - **Unit metrics moved onto the field.** The stat block (era form name, live HP, 攻 / 命中率 /
    閃避率 / 攻速) is now a tag attached to each unit, with a collision pass that places tags in
    free lanes and draws a leader line back to its unit. The canvas took the full page width to
    keep the tags legible; the full table moved below the field.
  - **A Codex review found seven defects, all fixed.** Two mattered: an air strike targets a
    standing fortification first, but movement steered at the nearest *unit*, so a bomber could
    drop its bomb in empty field while demolishing a fort elsewhere; and `speedMul` was applied
    to projectiles both at creation and per frame, squaring it, so at 2.5x the slider arrows flew
    at 6.25x. Also fixed: in-flight shots silently evaporated when their target died before
    impact (core resolves atomically, so the shot now re-plans against current state); 「僅剩空軍」
    was labelled a draw when `battle.gd` does not call it one at all (with no land force nothing
    claims the field and the outcome simply stays unset, so it is now labelled a sandbox stop
    condition); projectiles spawned from the sprite centre instead of the facing side; the dodge
    side-step was not perpendicular to oblique attack vectors; and tag de-collision stacked tags
    at the bottom edge instead of trying upward lanes. Codex independently confirmed that every
    value in the demo's `CLASSES` table and `ERA_COEFF` matches `cards.gd` and `era.gd`, and that
    the roll order, fort selection, repair timing and melee row preference are faithful.
  - **A bug found by measurement, not by eye:** with only horizontal alignment gating the drop,
    a bomb whose target sat higher up the field rendered as travelling *upward*. Bombers now
    require 2D proximity and close on the vertical axis at full speed, and the release point is
    clamped to at least 90px above the impact point, so a bomb always falls.
  - **Known limits carried forward:** the camera still splits by subject type (structures,
    vehicles and aircraft come out straight down, mounted figures drift toward profile), negative
    prompt wording still does not reliably suppress insignia (a bomber came back with a roundel
    and tail flashes despite the prompt forbidding both), and a few cells drift in figure count.
    None of these block a stats sandbox; all of them are the same prompt-only limits the audit
    already established.

  - **Approximations are listed on the page itself** (its `.note` block), not hidden: continuous
    movement stands in for a model with no positions, nearest-enemy targeting stands in for
    deploy-order focus fire, both sides carry the quality triple where the real game gives it to
    player units only, engineer repair is symmetric where core grants it to the player side only,
    and there are no waves, 軍費, skills or growth. The round is stretched to 4.5 s on screen
    because 攻 and 血 scale by the same coefficient at every era, so a strike is worth one or two
    units' entire HP and the exchange is otherwise over before it can be watched.
