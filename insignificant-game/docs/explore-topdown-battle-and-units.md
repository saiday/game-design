# Exploration log: top-down battle + RimWorld-style unit art

> **Both halves of this exploration were adopted, on 2026-07-27, after both had been stopped.**
> 1. **Top-down as the GAME camera: ADOPTED** (`docs/adr/0009-the-battle-scene-is-top-down.md`),
>    overturning the 2026-07-25 REFRAME that had stopped it. The cost the audit priced is accepted
>    knowingly, not refuted: illustrated ¾ overhead art is the dearest sprite bucket, and 69 unit
>    sprites plus 7 battle backdrops are discarded to get there. That evidence now lives in ADR-0009,
>    because the audit artifact that held it was deleted by human decision in the same round.
> 2. **The cover proposal the sandbox surfaced: ADOPTED** as an ordered cover chain
>    (`docs/adr/0008-the-formation-is-an-ordered-cover-chain-and-shields-screen-the-ranged-row.md`).
>    The version rejected below needed coordinates; the adopted version needs none. 盾陣 screens the
>    遠程列 specifically, 工兵團 moves behind the wall it repairs, and 正規軍 field screens of their own.
>
> The locked docs this exploration deliberately left alone have now been edited: `design/戰鬥.md`
> §自動佈陣 and §場景呈現, `design/卡牌.md`, `style-bible.md` §3 and §11, and `inventory.md` (the 69
> unit sprites and 7 battle backdrops are marked superseded pending the W14.8 re-render, which is
> where the sprites actually get replaced).

This is a purpose-built log (dated entries allowed, like `decisions.md` / cookbook §14), not a
current-state doc. The rules live in the ADRs and the corpus; this file records how the exploration
reached them, including the round in which it was stopped.

## 1. What this was, and the objections the camera had to clear

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
annotated inline here have been removed as redundant.

**Human arbitration, 2026-07-25:** the 5 reframes were accepted and top-down as a game camera was
stopped. The arbitration set the condition for reopening it: characterise the actual readability
problem first (units on screen per wave, what specifically fails to read) before proposing any camera
or art change.

**Human decision, 2026-07-27: the camera is adopted.** That condition was met by the sandbox, not
argued around. Watching the roster resolve on a top-down field is what identified the real
presentation problem, and it was not the world-war crowding the exploration set out to fix: **shield
walls sat parked at the front of the field with nothing sheltering behind them**, because
`design/戰鬥.md` put the 工事線 ahead of the 近戰列 and scoped 盾陣 to *any* ground unit, while cover
itself was only ever described as draw order (「掩體感由畫面的前後遮蔽表達」). The wall belonged to
nobody. That is a rules defect the side-view composition could not have surfaced and cannot express,
and fixing it (ADR-0008) is what makes the camera worth its cost.

How each objection stands after the decision:

- **O1 and O5 stand as stated, and are not the basis of the adopted decision.** World war is still
  exactly two camps, and civ colour tinting is still the world-war identification answer. Top-down is
  adopted for the cover chain, not for world-war crowding. The founding premise of the *exploration*
  was indeed false; the direction it stumbled into was not.
- **O2 stands, and is honoured.** The battle core still has no coordinates, no distance, no velocity
  and no movement. A station is a categorical place in the cover chain, and ADR-0008 adds it without
  adding space. Unit motion in the view remains decoration over a position-less model, which is why
  the demo is now a replayer of the core's timeline rather than a simulator (W14.7).
- **O3 stands and is accepted as a cost, not refuted.** The multipliers are real and they are now
  recorded in ADR-0009 so the expense cannot be quietly forgotten.
- **O4 stands and is still open.** Mirror-safety on asymmetric illustrated figures is untested; it is
  carried into W14.8 as a named risk, not assumed away.

## 2. The sandbox that carried the exploration, and became the evidence

By explicit human decision, `explore-topdown-motion-demo.html` continued after the camera was
stopped, **reclassified as a presentation sandbox** for watching unit stats and combat rolls resolve
on screen. Its top-down camera was a property of the sandbox at the time, deliberately not a camera
recommendation. It became one: the sandbox is the characterisation the 2026-07-25 arbitration asked
for, and ADR-0009 cites it. Open it directly in a browser; it is one self-contained file at 1.12 MB
with 60 sprites embedded as data URIs.

**It was rewritten rather than patched (PLAN.md W14.7, closed 2026-07-28):** the sandbox
re-implemented the battle rules in JS, which is exactly how it drifted from them once before. It is
now a **replayer** of the timeline `core/battle.gd` exports (`tools/export_timeline.gd` →
`docs/fixtures/battle_timeline.json`), with all rule code deleted, so it cannot diverge again. The
roll-order description below is a record of the retired simulator, kept because the objections in §3
were raised against it.

What the simulator did:

- **Full roster, all 6 eras**, with an era selector. 11 classes.
- **Stats are transcribed from the game, not invented.** 攻/血 are `core/data/cards.gd` catalog
  bases scaled by `core/era.gd` `COST_COEFF` (1/2/3/5/8/12); 命中率/閃避率/攻速 are the midpoints
  of each class's v1 medium quality band (`cards.gd` `QUALITY`); era names are the catalog's six
  per-class form names. Verified at both ends: era 1 棍棒戰團 攻1/血2, era 6 動力裝甲兵 攻12/血24
  and 電磁砲 攻48.
- **Roll order mirrors `Battle._fire` as it stands after W14.5** (ADR-0006/0007): the round opens
  with every active 防空飛彈 firing at one aircraft, destroy-on-hit at the engine defaults; then
  siege/air disabling one **active** enemy fortification (no roll, and the fort is never removed);
  then target selection under the matrix (近戰 never reaches 空域, 遠程 selects freely, 空襲 is
  ground-only); then 盾陣 intercepting one melee attack aimed at a ground unit; then accuracy,
  then dodge. Engineers never attack and repair one disabled fortification per round, round-robin.
  Fortifications are the player side's alone, as in core, and 防空飛彈 exists from 工業 onward only.
  ADR-0008 then narrowed the interception to the 遠程列 and gave 正規軍 screens of their own, and
  W14.7 deleted this whole roll order from the page instead of patching it. What replaced it: the
  page reads a tick-stamped event list and animates each entry where it stands, and
  `docs/tools/check_motion_demo.js` became a renderer check — fixture freshness, cover-chain
  staging, and a grep that fails if any rule code comes back
  (`node insignificant-game/docs/tools/check_motion_demo.js`).
- **Per-unit metric tags on the field:** era form name, live HP, 攻/命中率/閃避率/攻速, placed in
  free lanes with a leader line back to the unit. The full table sits below the canvas.
- **Per-class attack motion:** melee lunges, cavalry charges with a roll, muskets and rifles
  recoil backward, artillery recoils hard with a scale kick, a bomber banks without translating,
  engineers have none. A bomber has a 70px reach so it must fly over its target, and its bomb
  falls straight down.
- **Flying weapons are generated art:** 8 projectile sprites (stone, arrow, bolt, bullet, missile,
  cannonball, shell, bomb) mapped per class and era, authored pointing right, the bomb nose-down.
- **Approximations were listed on the page itself** (its `.note` block), not hidden: continuous
  movement stands in for a model with no positions, nearest-enemy targeting stands in for
  deploy-order focus fire within each band of the matrix, both sides carry the quality triple
  where the real game gives it to player units only, the battery's shot is given flight time
  where core resolves it atomically on the window's first tick, a 僅剩空軍 field is settled by
  世界大戰's 僵局判定 because a sandbox with no waves cannot carry the battle on, and there are no
  waves, 軍費, skills or growth. The round is stretched to 4.5 s because 攻 and 血
  scale by the same coefficient at every era, so a strike is worth one or two units' entire HP and
  the exchange is otherwise over before it can be watched.

Sprites: 60 exploratory raws under `assets/exploration/topdown-demo/`, never `assets/approved/`,
with a README beside them saying so. Recipe unchanged (Krea-2-Turbo + Moebius LoRA @1.0,
euler/simple, 8 steps, cfg 1.0, `ConditioningZeroOut`): **55 at seed 501** (the round-2 pass that
turned every subject to face right) and **5 at seed 403** (the review re-rolls). Round 1, seeds
401 and 402, is superseded and no file on disk comes from it. The prompt and seed for all 60 live
in `docs/tools/topdown_demo_sprites.json`, and `docs/tools/render_topdown_sprites.py` renders any
subset from it, so the set is reproducible.
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

- **盾陣 and 防空飛彈 are 工事卡, not units.** `design/卡牌.md` and `design/戰鬥.md` pin
  them completely: 工事線 (frontmost *at the time*; ADR-0008 has since moved it behind the 近戰列),
  **無視攻擊力**, 留場, block exactly one attack, 同場上限 2,
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

**One reopened the decision that stopped the camera — and is now the adopted design, in its
non-spatial form.** Seed-generated destructible barriers with ranged units *choosing* cover requires
space in the battle core, which is exactly O2 and exactly what the arbitration closed; it also
contradicts 自動佈陣's 「玩家不指定位置」 (categorical 列, not coordinates). Both objections survive.
What the analysis got right is the sentence that became ADR-0008: **a destructible thing in front
that shelters the ranged line is 盾陣.** The card already existed; what it lacked was somebody to
cover. So the adopted version keeps every constraint the rejection rested on — no coordinates, no
player placement, no new card — and changes only who the wall belongs to: the formation becomes an
ordered chain (近戰列 → 工事線 → 遠程列 → 空域) and 盾陣's interception narrows from any ground unit to
the 遠程列. The related "ranged units dodge melee" idea stays unbuilt; its cheap non-spatial reading
(a 閃避率 modifier keyed on attacker kind) is not needed once the wall does the job.

**The stop reason:** patching targeting rules or terrain into the demo would make the demo assert
rules the core does not have. That is the same failure mode the audit already falsified (O2), so
design has to lead. Two of the five items also need a human decision on 定稿 text, which is not
the demo's to make. This reason is the whole argument for W14.7's rewrite: a demo that holds rules
will drift from them, so the demo stops holding rules.

**HANDOFF CLOSED 2026-07-26.** The design round ran as wayfinder tickets
[#18](https://github.com/saiday/game-design/issues/18)–[#22](https://github.com/saiday/game-design/issues/22)
and decided all four items below: air is countered by 遠程列 fire plus an actively-firing
防空飛彈 (工業 era onward), 近戰 can never hit 空域, 空襲 is ground-only, forts one-hit-disable
and never leave the field (engineer round-robin repair), and the battle core still gets no space.
See `docs/adr/0006`/`0007` and `design/戰鬥.md` §工事卡.

**SECOND HANDOFF CLOSED 2026-07-27.** The fifth item, the one this log recorded as rejected, came
back and was decided as the cover chain, and the camera came with it. The battle core still gets no
space: that ruling is unchanged and ADR-0008 was designed around it. See `docs/adr/0008`/`0009`,
`design/戰鬥.md` §自動佈陣 and §場景呈現, and PLAN.md W14.6 to W15 for what implements it.

**The demo was re-synced to those rules on 2026-07-26** (see §2's roll-order bullet). Two of the
five objections below are answered by the rules themselves rather than by the demo: 防空飛彈's
affordance problem is gone because the battery now genuinely fires, and air now has a counter.
The sandbox stopped being merely a sandbox on 2026-07-27: it is the evidence ADR-0009 rests on, and
W14.7 rebuilt it as a timeline replayer with no rules of its own. O1, O2, O4 and O5 all still stand as written
(see §1); the camera was adopted despite them, not by refuting them.

The original handoff, in cost order:

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
- **The subject's count and the style tail's count must agree, or the model invents a crowd.** The
  tail every other sprite shares is plural (`simplified stylized figures with rounded chunky
  bodies`, `the whole group oriented toward the right edge of the frame, bodies and weapons
  pointing right`). A lone subject under that tail contradicts it, and the model settles the
  contradiction by putting one hero in front of a mass of generic soldiers, which is what "a lone
  bandit / thief / cyber hacker" returned. Either count works once the whole prompt agrees on it:
  `privateers_e3/e4/e5` are the roster's only single-figure units and carry the tail singularised
  end to end (`a simplified stylized figure with a rounded chunky body...`, `the figure oriented
  toward the right edge of the frame, body and weapon pointing right`), each returning exactly one
  man with no crowd behind him.
- **A stated count buys three heads, not three bodies.** In a multi-figure prompt the count clause
  is satisfied by three heads and three weapons growing out of one fused torso column standing on a
  single pair of legs, which reads on the field as one big unit rather than a squad. `infantry_e4`
  carries the mild form: three shakos and three muskets over one torso, one pair of boots. Neither
  a fresh seed nor the arrangement wording the roster already uses ("standing in a tight rank", "in
  a staggered line") separates them; naming the per-figure anatomy does:
  `each man a separate complete body standing on his own two legs and boots`. Pin a direction in
  the same clause, because separated figures re-arrange themselves: told only to stand "spaced
  apart in a line" the model lays them left-to-right for a 2.27:1 landscape sprite, against a
  figure roster that otherwise runs 0.42–1.58. `the three men arranged in a staggered diagonal
  line, each man set lower and further right than the one before him` holds the separation and the
  frame together.
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
  eye-level three-quarter. A shared locked camera may need ControlNet/pose reference, which O3's
  multipliers price as expensive. **This is now a live production risk, not a reason to stop:**
  ADR-0009 carries it, and W14.8 has to resolve it for real across 69 sprites.
- **Negative wording does not reliably suppress insignia.** A bomber returned with a roundel and
  tail flashes despite the prompt forbidding both. More "no X" phrasing is the wrong lever.
- **Count drift** (asked 3, got 5) remains routine §8 noise.
