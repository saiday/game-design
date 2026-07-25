# Exploration log: top-down battle + RimWorld-style unit art

> **Both halves of this exploration are now stopped, at two different levels.**
> 1. **Top-down as a GAME camera: STOPPED** by a depandabot audit (`REFRAME`) plus human
>    arbitration on 2026-07-25. Do not resume without a fresh human decision.
> 2. **The presentation sandbox (`explore-topdown-motion-demo.html`): STOPPED** on 2026-07-25
>    after it surfaced five battle-rule questions that the design corpus does not answer. Those
>    are design work, not demo work. The demo stays as-is and playable; the next move is a design
>    round, not another demo pass.
>
> Nothing here is decided or locked. No locked doc was edited by this exploration:
> `design/戰鬥.md`, `assets/pipeline/style-bible.md` §11, `inventory.md` and the frozen
> units/backgrounds all still describe the shipping side-view game.

This is a purpose-built log (dated entries allowed, like `decisions.md` / cookbook §14), not a
current-state doc. Full audit reasoning and evidence live in
`docs/depandabot/2026-07-25-topdown-battle-unit-motion.md`; this file is the summary and the
handoff.

## 1. What this was, and why the camera direction died

The human asked to explore a different unit art style, framed as "pixel art" with RimWorld as
reference. Two corrections up front: RimWorld is not pixel art (it is flat-minimalist 2D
illustration, the Prison Architect limbless-bean lineage), and it is not 2.5D (it uses a few
hand-drawn directional sprites, not a rotating rig). So the real reference was
*flat-minimalist top-down*, and the pixel-art pipeline question was moot.

The motivation was gameplay, not cosmetics: the belief that 世界大戰 puts many parties and many
units on one shared field, which a side-view line composition cannot hold.

**A depandabot audit returned `REFRAME`. Codex objected with 7 points; the 5 conceptual ones were
accepted with no rebuttal, terminating the loop at round 1 per the Bucket Rule:**

| ID | Objection |
|---|---|
| O1 | The founding premise is false. `design/世界大戰.md` pins 恰兩營 (exactly two camps, 無中立) and `core/world_war.gd` implements it. Multi-*civilization* is not multi-*side*. |
| O2 | `core/battle.gd` has no positions at all: no coordinates, distance, velocity or movement. A unit's only spatial attribute is a categorical `row` StringName. So unit movement has no logical state to render. |
| O3 | Cost motivation inverted. True overhead art rotated in software is 1x sprite cost, side view 1-1.5x, illustrated 3/4 oblique 3-3.5x. Our renders are illustrated 3/4, so this direction moves us from the cheapest bucket toward the dearest. |
| O4 | L/R flip is not credible for asymmetric illustrated art (costume, weapon hand, light direction). RimWorld itself ships 3 unique facings and only auto-mirrors symmetric apparel, so it cannot be cited for the cheap option. |
| O5 | The design already solves world-war faction identification with civ colour tinting over existing art (「沿用現有單位美術套色，不需新圖」). A camera change discards a solved cheaper solution and invalidates 69 approved unit PNGs plus 7 side-view backdrops. |

O6/O7 (implementation) were accepted as valid but moot. The falsified claims that used to be
annotated inline here have been removed as redundant; the audit artifact holds them in full.

**Human arbitration, 2026-07-25:** the 5 reframes are accepted for the game direction. Top-down
as a game camera stays stopped. If the world-war readability intuition is ever revisited,
characterise the actual problem first (units on screen per wave, what specifically fails to read)
before proposing any camera or art change.

## 2. What survived: the presentation sandbox

By explicit human decision, `explore-topdown-motion-demo.html` continued, **reclassified as a
presentation sandbox** for watching unit stats and combat rolls resolve on screen. Its top-down
camera is a property of the sandbox, deliberately **not** a camera recommendation, and it does not
reopen O1-O5. Open it directly in a browser; it is one self-contained file at 1.12 MB with 60
sprites embedded as data URIs.

What it does:

- **Full roster, all 6 eras**, with an era selector. 11 classes.
- **Stats are transcribed from the game, not invented.** 攻/血 are `core/data/cards.gd` catalog
  bases scaled by `core/era.gd` `COST_COEFF` (1/2/3/5/8/12); 命中率/閃避率/攻速 are the midpoints
  of each class's v1 medium quality band (`cards.gd` `QUALITY`); era names are the catalog's six
  per-class form names. Verified at both ends: era 1 棍棒戰團 攻1/血2, era 6 動力裝甲兵 攻12/血24
  and 電磁砲 攻48.
- **Roll order mirrors `Battle._fire`:** siege/air demolition of a standing fortification first
  (no roll, no repair), then fortification absorb (盾陣 one melee, 防空 one ranged/air, ignoring
  attack value, turning 待修 instead of consumed while an engineer lives), then accuracy roll,
  then dodge roll. Engineers never attack and repair one fortification per round starting the
  round after it was damaged.
- **Per-unit metric tags on the field:** era form name, live HP, 攻/命中率/閃避率/攻速, placed in
  free lanes with a leader line back to the unit. The full table sits below the canvas.
- **Per-class attack motion:** melee lunges, cavalry charges with a roll, muskets and rifles
  recoil backward, artillery recoils hard with a scale kick, a bomber banks without translating,
  engineers have none. A bomber has a 70px reach so it must fly over its target, and its bomb
  falls straight down.
- **Flying weapons are generated art:** 8 projectile sprites (stone, arrow, bolt, bullet, missile,
  cannonball, shell, bomb) mapped per class and era, authored pointing right, the bomb nose-down.
- **Approximations are listed on the page itself** (its `.note` block), not hidden: continuous
  movement stands in for a model with no positions, nearest-enemy targeting stands in for
  deploy-order focus fire, both sides carry the quality triple where the real game gives it to
  player units only, engineer repair is symmetric where core grants it to the player side only,
  and there are no waves, 軍費, skills or growth. The round is stretched to 4.5 s because 攻 and 血
  scale by the same coefficient at every era, so a strike is worth one or two units' entire HP and
  the exchange is otherwise over before it can be watched.

Sprites: 60 exploratory raws under `assets/exploration/topdown-demo/`, never `assets/approved/`.
Recipe unchanged (Krea-2-Turbo + Moebius LoRA @1.0, euler/simple, 8 steps, cfg 1.0,
`ConditioningZeroOut`), seed 401 with re-rolls at 402 and 403.
`docs/tools/build_motion_demo.py` keys the grey render background to transparent in two passes:
inward from the frame edges, then one fill per pocket of background the subject seals off
(between an arm and a torso, inside the curve of a bow). A pocket is filled only when dark
linework runs around it, because a pale hull or a white surcoat matches the backdrop colour
exactly and punching those out is worse than the slab. It then trims, downscales to 256px,
quantises to 128 colours, and rewrites only the `@SPRITES` / `@CREDITS` marker blocks so
hand-edited JS and CSS survive re-runs.

## 3. Why the demo session stopped (2026-07-25)

**The sandbox did its job: seeing the numbers resolve produced five gameplay objections from the
human.** Verifying them against `design/` and `core/battle.gd` showed they are not one kind of
problem, and only one of the five is a demo change.

**Two rest on a premise the game does not have.**

- **盾陣 and 防空飛彈 are 工事卡, not units.** `design/卡牌.md:48-49` and `design/戰鬥.md:30` pin
  them completely: 工事線 (frontmost), **無視攻擊力**, 留場, block exactly one attack, 同場上限 2,
  工兵團 repair, plus full era skins. `battle.gd` keeps them in `player_forts`, an array separate
  from `player_units`, with no hp, attack, accuracy or dodge. The demo matches
  (`row:'fortification'`, atk 0, no stat tag). So "工事卡 feel out of place" is not a rules gap.
  Their **form promises something their rules do not do**: 防空飛彈 is drawn as a missile battery,
  so the eye expects it to fire, and by rule it never fires. That is an affordance problem.
- **There is no anti-air unit, and no air-to-air unit, anywhere in the roster.** "Anti-air
  attacking cavalry" cannot happen. 防空飛彈 has no attack stat.

**One is a real, undiscussed hole.** `_pick_target` (`core/battle.gd:638`) returns the first
living defender regardless of `row`; melee prefers the melee row then falls back to anything. So
棍棒戰團 can club a 轟炸機 out of the sky, and air's only counter is one absorb from 防空飛彈.
**Nothing in the game counters air units.** This is the same hole as the 僅剩空軍 outcome, which
`battle.gd` leaves unset rather than calling a draw.

**One contradicts locked design.** `design/卡牌.md:47` pins 轟炸機 as 空襲：**任選目標** and the
code implements exactly that. Restricting ground-attack aircraft to ground targets is an ADR-grade
change to a 定稿 line, not a tweak.

**One reopens the decision that stopped the camera.** Seed-generated destructible barriers with
ranged units preferring cover requires space in the battle core, which is exactly O2 and exactly
what the arbitration closed. It also contradicts `design/戰鬥.md:21` 自動佈陣
(「玩家不指定位置」, categorical 列, not coordinates). And it overlaps an existing card: a
destructible thing in front that shelters the ranged line **is** 盾陣. Note that the related
"ranged units dodge melee" has a cheap non-spatial reading (a 閃避率 modifier keyed on attacker
kind) that should be separated from the spatial one.

**The stop reason:** patching targeting rules or terrain into the demo would make the demo assert
rules the core does not have. That is the same failure mode the audit already falsified (O2), so
design has to lead. Two of the five items also need a human decision on 定稿 text, which is not
the demo's to make.

**Handoff to a design round**, in cost order:

1. **Air counters** (non-spatial, decidable now). Who may attack a unit in 空域? A row-plus-flags
   targeting matrix, promoting 防空飛彈 from 工事卡 to a firing 部隊卡, or adding a fighter class.
   Expect a load-bearing collision: promoting 防空飛彈 to a unit runs into
   「只有部隊卡有品質」 (`design/卡牌.md:64`) and the 成長軸 table (`design/營運.md:46`).
   Resolving it must also settle the 僅剩空軍 outcome.
2. **Restricting 空襲 to ground targets.** Needs an ADR naming `design/卡牌.md:47` as superseded,
   never a silent edit.
3. **Does the battle core get space?** If yes it is an ADR contradicting the audit reframe, and it
   invalidates the current watch-only battle presentation.
4. **How should a 工事卡 read on screen given it never attacks?** Re-skin toward passive
   interception, or promote it per item 1.

## 4. Known limits and findings worth carrying forward

**Prompt-craft findings (validated, reusable):**

- **Describe the SUBJECT's form, never the art STYLE** (cookbook §14). "simplified readable
  shapes" (a style phrase) did nothing; `simplified stylized figures with rounded chunky bodies
  and no facial features` produced visibly chunkier, blank-faced figures. A truncated version of
  the same phrase was ignored, so the full wording matters.
- **Steep-angle wording works:** `steep high-angle view looking straight down from directly above`
  fixed the hard cases the vague "three-quarter top-down" left near eye-level.
- **Orientation must be pinned explicitly if you want to flip sprites.** Round 1 stripped every
  right-facing phrase to remove side-view language, which also removed the only thing an X-flip
  can mirror; sprites faced the camera and flipping did nothing. Round 2 pins
  `the whole group oriented toward the right edge of the frame, bodies and weapons pointing right`
  and mirrors cleanly.
- **A singular subject contradicts the shared "...figures" clause, and the model settles it by
  inventing a crowd.** `privateers_e3/e4/e5` were the roster's only three figure prompts written as
  "a lone bandit / thief / cyber hacker", and all three returned one hero in front of a mass of
  generic soldiers. No prompt written as "two/three identical X" did. Stating the count fixed all
  three in one pass.
- **Pin the aim direction, not the carry position.** "held upright against his own shoulder" gave
  `holy_warriors_e4` nothing to aim at, so a shooting unit came back with muskets slung across the
  back, reading as idle. "levelled forward ... pointing toward the right edge of the frame", the
  wording `archers_e4` already uses, fixed it.
- **Framing words cannot change a sprite's proportions.** The build trims to the alpha bbox, so
  margin is discarded and only the subject's own silhouette survives. The era-4 airship rendered at
  3.59:1 against an otherwise portrait roster; only changing the subject moved it (a short
  deep-bodied airship with a gondola, 2.06:1).
- **Frame-by-frame walk cycles are the wrong default for an AI sprite pipeline** (frame-to-frame
  consistency is diffusion's hardest problem). This survives the audit unconditionally; it is an
  argument about animation, not about camera.

**Unsolved by prompt wording alone:**

- **The camera splits by subject type.** Structures, emplacements, vehicles and aircraft come out
  genuinely steep overhead; multi-figure human groups and mounted figures still drift toward
  eye-level three-quarter. A shared locked camera needs ControlNet/pose reference, which O3 priced
  out.
- **Negative wording does not reliably suppress insignia.** A bomber returned with a roundel and
  tail flashes despite the prompt forbidding both. More "no X" phrasing is the wrong lever.
- **Count drift** (asked 3, got 5) remains routine §8 noise.
