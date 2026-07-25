# depandabot audit — top-down battle redesign + cheap-tier unit motion

Date: 2026-07-25 · Invoked by: human (self-declared non-expert in game UI/UX) · Host: `saiday/game-design`

## 1. Current State

1. **The battle core has no spatial model.** `insignificant-game/core/battle.gd` (33.6 KB) gives every
   unit a categorical `row` StringName — `&"melee"` / `&"ranged"` / `&"air"` (e.g. `battle.gd:345`,
   `:422`, `:510`, `:571-573`) — and contains no coordinates, distance, velocity, or movement of any
   kind. Targeting is row-based per tick. There is no position data for a top-down field to render.
2. **World war is exactly TWO camps, not a multi-party free-for-all.** `design/世界大戰.md` rule table:
   分營 splits every living civilization into **恰兩營** ("exactly two camps"), **無中立** (no neutral,
   everyone picks a side). `core/world_war.gd:5-6, 26-34` implements it: "camps — no neutral — …
   every living civ (player included) is in exactly one camp."
3. **The design explicitly says world war needs NO new unit art.** `design/世界大戰.md` 戰場模型,
   文明顏色標記: each unit carries a civ colour/flag marker, "**沿用現有單位美術套色，不需新圖**"
   (reuse existing unit art with colour tinting, no new images needed).
4. **The battle screen structure is locked (定稿) as a side-view facing pair.** `design/戰鬥.md:59`:
   自動佈陣 directly determines screen structure — 雙方相對 (the two sides face each other), each ordered
   front-to-back 工事線 → 近戰列 → 遠程列 → 空域.
5. **Battle is watch-only; the player never moves a unit.** `design/戰鬥.md:60`: 「戰鬥是用看的」 — within
   a turn window units act on their own attack speed and the player does not operate; they watch the
   window resolve, then choose what to commit next. `design/世界大戰.md`: 盟友與敵營的正規軍全自動作戰.
6. **Frozen art that a camera change would invalidate:** 69 approved unit PNGs
   (`assets/approved/units/`) across 6 eras, and 7 side-view battle backdrops
   (`assets/approved/backgrounds/bg_battle_*.png`), all human-picked through closed asset gates.
7. **This session's output is exploratory only:** two contact sheets
   (`explore_topdown_units.png`, `explore_topdown_probe2.png`), a log doc
   (`insignificant-game/docs/explore-topdown-battle-and-units.md`), and a motion demo
   (`insignificant-game/docs/explore-topdown-motion-demo.html`). No locked doc or asset was edited.

## 2. Intended Goal

Decide whether to move the battle presentation from the locked side-view to a top-down camera with a
cheap-tier unit-motion model — such that the decision is justified by a real presentation problem in the
game as designed, and its cost against the 69 frozen unit sprites and 7 frozen battle backdrops is
accepted knowingly.

## 3. Current Plan (as it stood when the audit was invoked)

1. Keep the existing ComfyUI recipe (Krea-2-Turbo + Moebius LoRA); switch the unit framing suffix to
   `"steep high-angle view looking down from almost directly above"` and describe simplified *form*
   (chunky bodies, minimal facial detail) rather than art style.
2. Render a wider top-down board across more unit lines and eras to confirm the look holds.
3. Render facing as discrete sprites: start with L/R horizontal flip (2 facings), add N/S sprites only
   if the field demands vertical movement.
4. Render movement as position tweens (sprite slides toward its target), plus procedural sine-wave bob
   and slight rotation while moving.
5. Render attacks as a lunge/recoil tween for melee and a tweened projectile + impact flash for ranged.
6. Defer skeletal rigging (Godot `Skeleton2D` / cutout over paper-doll layers) until a specific unit
   demands real limb motion; declare frame-by-frame walk cycles out of scope as incompatible with the
   AI sprite pipeline.
7. Keep all of the above in the view layer; leave the deterministic tick core untouched.
8. Only after human commitment, edit the locked docs (`design/戰鬥.md` 場景呈現, style-bible §11,
   inventory) through the normal design gate + §12 style escalation.

## 4. Missing Directional Confirmations

1. `assumption` — **"World war = many parties on a shared field, which side-view handles badly."** This
   premise, which originated the whole exploration, is contradicted by §1.2: the design pins world war
   at **exactly two camps** with no neutral. Multi-*civilization* is not multi-*side*; the screen still
   has two opposing forces, which is precisely what the locked side-view composition renders. Neither
   the assistant nor the human checked `design/世界大戰.md` before the exploration began.
2. `risk` — **The design already solved the world-war identification problem without new art.** §1.3
   specifies civ colour/flag markers over existing sprites, explicitly "no new images needed". A camera
   change would discard a solved, cheaper solution and invalidate 69 sprites + 7 backdrops (§1.6).
3. `unknown` — **Whether units need to move at all.** Battle is watch-only with row-based, position-less
   resolution (§1.1, §1.5). Movement, facing and pathing may be pure decoration with no logical
   referent; the cheap-tier motion model may be answering a question the game never asks.
4. `assumption` — **A ¾ top-down illustrated sprite can be mirrored L/R without reading wrong.** Untested.
   Asymmetric costume, weapon hand and lighting all flip with the sprite.
5. `risk` — **The AI pipeline cannot hold character identity across facings.** Established across six
   era waves of this project's own findings log (cookbook §14): diffusion will not reproduce "the same
   unit" from a new angle. Any N/S facing requirement is therefore a hard production wall, not a cost
   curve.
6. `assumption` — **"RimWorld doesn't frame-animate its pawns."** Asserted from a search summary, not
   from primary rendering documentation; later RimWorld versions reportedly added pawn animation.
7. `unknown` — **Whether a top-down camera would even improve readability** for the number of units the
   game actually fields per wave, versus the locked side-view rows.

## 5. Evidence & Arguments

Search was run with `agy` (Antigravity CLI) per the user's global instruction, which supersedes the
skill's `gemini` default. **Tooling caveat worth recording:** in one sweep, 10 of 13 URLs `agy` returned
were fabricated (plausible slugs 404ing at pcgamer, kotaku, vice, gamesradar, futurism,
gamesindustry.biz). Every citation below was independently re-verified; unverifiable ones were dropped.

1. **Sprite-count economics by perspective** — <https://cxong.github.io/2022/03/how-many-sprites-do-different-perspectives-need>
   (WebFetch-verified). Multipliers: top-down **1x**, side view **1–1.5x**, isometric 4-dir **2–2.5x**,
   **3/4 oblique 3–3.5x**; a 3/4 view needs "at the very least 3 sets of sprites: side view (mirrored
   for left/right), front view and back view." The 1x top-down bargain applies only to true overhead art
   rotated in software, not illustrated 3/4 figures. → **CONTRADICTS §3.1 and §3.3**: switching from
   side view to 3/4 top-down moves the project from the cheapest sprite bucket to nearly the dearest,
   which inverts the "simpler/cheaper" motivation.
2. **Constant sine motion and mirror-safety** — <https://www.slynyrd.com/blog/2025/3/24/pixelblog-55-top-down-character-animation>
   (WebFetch-verified). States "constant sine wave motion, which looks a bit robotic", and "Due to
   asymmetry of the hair, and equipment, unique frames had to be created for all eight orientations."
   → **CONTRADICTS §3.4** (names the exact proposed bob technique as the failure mode) **and §4.4**
   (asymmetric characters cannot simply be mirrored).
3. **Godot 4 Tween is the idiomatic runtime-movement tool** — <https://docs.godotengine.org/en/stable/classes/class_tween.html>
   (WebFetch-verified). Created via `create_tween()`, and "more suited than AnimationPlayer for
   animations where you don't know the final values in advance." → **SUPPORTS §3.4/§3.7**: position
   tweening runtime-computed targets is correct Godot 4 practice and needs no frame art.
4. **Cutting walk animation is a validated shipped choice — with a precondition** — <https://battlebrothersgame.com/dev-blog-5-concept-art-explaining-battle-brothers-character-art-style/>
   (WebFetch-verified). Overhype cut "character animations like walking and turning" because in 2D they
   "require an immense amount of work", and used bust framing plus per-part layering ("Each part like
   head, helmet or weapon can be individually swapped"). → **SUPPORTS §3.6** (no walk cycles is
   shippable) **but qualifies §4.5**: their saving depends on a layered paper-doll pipeline and framing
   the legs out — neither of which flat AI-generated whole-figure sprites provide.
5. **The RimWorld precedent is misapplied** — <https://rimworldwiki.com/wiki/Modding_Tutorials/Textures>
   (live; returns 403 to automated fetchers, curl-verified 200 with a browser UA — open in a browser to
   confirm). The official modding doc specifies textures "one each for south, north, and east facings",
   with west auto-mirrored from east *unless* the apparel is asymmetric, in which case a real `_west`
   texture is supplied. → **CONTRADICTS §3.3 and §4.6**: RimWorld ships **3 unique directions**, not a
   2-facing L/R flip. It supports "no walk cycles" but cannot be cited to justify 2 facings; even it
   declines to blanket-mirror asymmetric art.
6. **Scale ceiling for per-unit nodes in Godot 2D** — <https://forum.godotengine.org/t/performance-problems-when-rendering-many-2d-sprites/85055>
   (reported by the evidence sweep; treat as a community datapoint, not doctrine). A dev hit
   rendering-bound framedrops around 500 nodes × 3 sprites on Godot 4.3 compatibility renderer and moved
   to MultiMesh. → **Qualifies §3.7**: MultiMesh is the escalation for hundreds+, but it gives up
   per-instance scripting, which conflicts with per-unit tweens and per-unit bob.

**Dissent summary (requirement satisfied):** citations 1, 2 and 5 each contradict a stated plan step —
the perspective switch raises rather than lowers art cost, the named bob technique reads robotic, and
the RimWorld precedent argues for 3 directions rather than 2.

## 6. Second Opinion (Codex)

### Round 1 — Codex verdict: `OBJECT` (7 objections; 5 conceptual/high, 2 implementation/medium)

| ID | Sev | Category | Summary |
|---|---|---|---|
| O1 | high | conceptual | The camera exploration is founded on a false problem framing: world war is multi-civilization but still exactly a two-camp conflict. |
| O2 | high | conceptual | The proposed movement system has no gameplay referent in the designed battle model and would be decorative complexity rather than a solution to a demonstrated presentation problem. |
| O3 | high | conceptual | The claimed cheap-tier sprite strategy reverses the actual production-cost advantage of the current side-view approach. |
| O4 | high | conceptual | Two mirrored L/R facings are not a credible production assumption for the proposed perspective. |
| O5 | high | conceptual | The proposal discards locked, human-approved art despite an existing world-war identification solution that requires no new unit art. |
| O6 | medium | implementation | The proposed always-moving per-unit view layer has an unresolved rendering-scale risk (Godot 2D node-count ceiling vs MultiMesh's loss of per-instance scripting). |
| O7 | medium | implementation | The specified sine-wave bob is directly warned to look robotic and has no alternative or test threshold. |

Codex detail, condensed: O1 cites §1.2/§4.1 (exactly two camps, no neutral) against §1.4's locked
side-view pair — "a shared field does not require a many-sided presentation, so the original reason for
replacing the camera is invalid." O2 cites §1.1/§1.5 (row-only targeting, watch-only resolution) — the
plan "creates implied movement, targets, and facing requirements absent from the rules." O3 cites §5.1's
multipliers — plan steps 1/3 specify illustrated high-angle art with discrete facings, i.e. the 3–3.5x
bucket, "without budget or asset acceptance." O4 cites §5.1/§5.5 plus §4.4/§4.5 — mirroring reverses
asymmetric hands, weapons and lighting, and new N/S renders hit the identity-consistency wall. O5 cites
§1.3/§1.6/§4.2 — the camera change discards a solved inexpensive solution and invalidates frozen assets
"before a demonstrated presentation benefit or explicit commitment exists."

### Claude's response

**O1, O2, O3, O5 — conceptual, ACCEPTED.** No rebuttal offered; these are correct and decisive.
O1 is the same defect this audit found independently at §4.1, and its provenance matters: the assistant
adopted the human's "many parties on a shared field" framing and began generating art without opening
`design/世界大戰.md`, which pins 恰兩營. O2 is the sharper of the two — even granting a top-down camera,
`core/battle.gd` holds no positions (§1.1), so unit movement would be animating state the game does not
model. O3 and O5 together invert the economics that motivated the whole exploration.

**O4 — conceptual, ACCEPTED** (Codex's tag upheld; it decides approach shape, not an implementation
detail). The L/R-flip assumption was already tagged `assumption` at §4.4 and is now contradicted by two
independent sources (§5.2, §5.5).

**O6, O7 — implementation, ACCEPTED as valid but MOOT.** Both concern how to execute a motion tier whose
premise has just been withdrawn. Recorded so they are not lost if a future round revives the direction:
any per-unit tween/bob approach needs a field-count performance threshold, and the bob needs variable
timing (and probably squash-stretch `scale` tweens) rather than a constant sine.

**Loop terminated at round 1** per the Bucket Rule: a conceptual objection that Claude agrees with ends
the loop immediately. No amendments were made, because amending the plan would presume the framing that
O1/O2 invalidate.

### What survives

Not everything in the session is discarded. These findings stand on their own and are independent of the
camera question:

- The RimWorld reference was mischaracterised at the outset (it is not pixel art, not 3D-on-2D) — that
  correction remains correct and useful.
- The prompt-craft finding is reusable for the *existing* side-view pipeline: describing a subject's
  **form** ("chunky bodies, minimal facial detail") works where art-**style** words fail, matching
  cookbook §14's standing rule.
- "No frame-by-frame walk cycles" is independently validated by Battle Brothers (§5.4) and remains the
  right default for this project's AI pipeline — but it is an argument about animation, not about camera.
- The exploratory artefacts (two contact sheets, the motion demo) are harmless raws; nothing was frozen,
  approved, or written into a locked doc.

### Open question the audit hands back to the human

The exploration was triggered by a real intuition — that world-war battles feel crowded or hard to read.
That intuition was **not** validated here, and the design already answers the identification half with
civ colour tinting (§1.3). If the readability concern is genuine, the next step is to characterise the
actual problem (how many units on screen per wave, what specifically fails to read) **before** any camera
or art proposal — not to redesign the presentation first.

---

REFRAME
