# Balance report — v1 baseline knobs under simulation

**Measured at:** 2026-08-03, post-cover-model (W14.9: ADR-0010 — 盾陣 absorbs *ranged* fire with a
3～5-shot budget instead of intercepting one melee attack, and barrier-bearing field scatter is
unowned cover both sides may fall back behind) on top of the cover chain (W14.7: ADR-0008), the air
& fortification delta (W14.5: ADR-0006/0007) and the battle-model rewrite (W11–W13.5 + W12.5:
rolled card instances with growth, wave/tick battles, played world wars, 起始人口 0), with the W14
tempo bot, 21 suites / 250 cases green. When rules or knobs change, re-run the batch and refresh
this report (and this stamp) before comparing.

Source: `tools/balance_batch.gd`, 60 runs (20 seeds × easy/normal/hard), W14 bot
(`core/sim.gd`: greedy builder; disbands personnel for population while pop < 20; routes all
兵營 medals to its strongest unit; fields cheapest units to strength parity per boundary,
personnel-first in riots; concedes unheld or frozen fields (W14.5) with a 200-round backstop;
enters democracy at gen 38). Raw data:
`reports/balance_batch.json`. These are **measurements and surfaced questions — balance
calls stay with the PM.**

## Headline numbers (mean over 20 runs; min–max where it matters)

| Metric | easy | normal | hard |
|---|---|---|---|
| Endings | 20× survived | 19× survived, **1× 政權崩潰** | 19× survived, **1× 政權崩潰** |
| Final rank (mean, range) | 1.3 (1–4) | 1.6 (1–4) | 2.6 (1–5) |
| Collapse check armed | 20/20 | 20/20 | 20/20 |
| Final population (from 起始 0) | 109 (39–126) | 104 (4–135) | 107 (4–169) |
| World wars fought / won by player camp | 40 / 39 (98%) | 38 / 37 (97%) | 38 / **28 (74%)** |
| Medal levels on deck at gen 50 | 52 (9–87) | 42 (0–74) | 36 (0–90) |
| 兵營 medals left unassigned | 0 | 0 | 0 |
| Final happiness | 95 (16–100) | 88 (36–100) | 92 (52–100) |
| Unrest battles triggered / run | 5.2 | 5.5 | 4.8 |
| Deepest debt touched | −127 (to −576) | −132 (to −383) | −303 (to **−1087**) |
| Generations spent in debt | 8.1 | 9.6 | 10.4 |
| Final treasury (gen 50, survivors) | ~9020 | ~9140 | ~9050 |
| Buildings built (lifetime) | 11.0 | 10.6 | 11.1 |
| Policies completed | 9.2 | 8.6 | 8.7 |
| Deck size | 13.2 | 12.2 | 12.1 |
| Rivals alive at gen 50 | 1.7 | 2.1 | 1.9 |

## The three sensitive knobs

1. **BP curve** — unchanged behavior: era caps bind before `pop/10` once population passes
   ~50; ~9 policy nodes complete per run. The 起始人口 0 opening does NOT starve BP: the
   floor-1 rule plus the disband engine reaches double-digit population inside the tribal
   era. **No change suggested.**
2. **Escalating cost 0.25** — same window as before (debt clusters classical/faith); the
   rewrite didn't move it. Still runs out of things to price by industrial.
3. **Unrest weights** — triggers hold at 4.6–5.8/run and the 內亂 chain **kills**: 3 of 60 runs
   end in 政權崩潰 (see below). The lethality earlier reports flagged as missing exists; two of
   the three are still the gen-4 opening trap, but one now lands at generation 13.

## Cover model delta (W14.9) — half of it is measured, and the measured half moved hard

ADR-0010 changed two things: a 盾陣 stopped intercepting one melee attack and started absorbing
3～5 **ranged** shots, and barrier-bearing field scatter became unowned cover a hurt land unit falls
back behind on its own. **The split in what this batch can see is the whole story of these numbers.**
Neutral cover is engine-placed, so every one of the 60 runs met it in every battle. The player's own
盾陣 still needs a card played, and `sim.gd::_pick_deploy` skips `class == &"fortification"` — so on
the player's side the inversion is pure loss and no gain: the enemy's 正規軍 screens went from
eating one melee swing to eating 3–5 of the bot's arrows, while the bot fields no wall of its own.
Read every number below through that asymmetry; it is a property of the bot, not of the rule.

- **Hard-difficulty world wars fell again, 86% → 74%** (28/38), while easy rose to 98% (39/40) and
  normal to 97% (37/38). This is the largest single-wave move in the hard WW figure since ADR-0006's
  air rules created the wall (95% → 79% → 86% → **74%**). Mechanism, in the order the effects bite:
  the enemy's screen now absorbs 3–5 of the bot's ranged shots instead of one melee swing; both
  camps' hurt survivors take neutral cover, which is symmetric on paper but favours the side with
  more bodies on the field (gen-35 正規軍 camps, and hard multiplies their stats by 1.2); and the
  bot's answer to bomber-heavy camps is ranged fire, which is exactly what cover absorbs. *PM call:
  74% on hard with 97–98% below it is the sharpest difficulty separation this report has ever
  measured. Is that the intended shape of gen 15/35, or has the wall gone from steep to unfair?*
- **The player's 盾陣 is still unmeasured, and now it is the biggest hole in the report.** Its
  3～5-shot budget is the strongest damage reduction in the game and the batch has never seen one on
  the player's side. **PLAN.md W16** is the scheduled fix (a fort branch in `_pick_deploy` plus an
  engineer-follows-wall rule); until it lands, treat the hard WW figure as "what happens to a player
  who never builds cover while the enemy has it", not as the rule's value.
- **Money went the other way from W14.7, and the debt clock did not.** Final treasury rose on normal
  (~8660 → ~9140) and hard (~8250 → ~9050) — longer battles kill fewer of the bot's units per
  round, so it refields less — but generations-in-debt still rose on hard (9.1 → 10.4) and its worst
  debt deepened to −1087. The late-game money pile this report has flagged as sink-less for four
  rounds is therefore back near its pre-W14.7 level. *PM call: the sink question stands.*
- **The gen-13 collapse did not reproduce.** Collapses are back to 2/60 (seed 18 on normal and hard,
  both the known gen-4 pop-5 opening trap); W14.7's mid-game collapse at gen 13 is gone. Battles
  resolving differently reshuffles the `battle` rng track for the whole run, so this is a
  distribution reading, not a repair: **per-seed comparison against the 2026-07-28 batch is
  meaningless.** The chain proved it can kill outside the opening once, and one batch not showing it
  is not evidence it cannot.
- **Hard's final rank slipped 2.2 → 2.6** (range now 1–5), consistent with losing a quarter of its
  world wars: reparations paid instead of collected.
- **Nothing in the 3～5 band was tuned to any of this**, per the standing rule at the foot of this
  file. The band came from the human's ruling (ADR-0010) and the tiers it is matched against.

## Cover-chain delta (W14.7) — measured, and mostly not measurable

Three rule changes landed: 盾陣 narrowed to the 遠程列, 工兵團 moved from the 近戰列 to the 遠程列,
and 正規軍 now field a 盾陣 of their own. Only the last two can show up in this batch at all.

- **盾陣's narrowing is still unmeasured, by construction.** The bot plays no fortification cards
  (`sim.gd::_pick_deploy` skips `class == &"fortification"`), so the player never fields a screen
  and the rescoped interception never fires on the player's side. Unchanged from W14.5: the knob
  has **zero batch coverage** and lives only in `battle_test`.
- **帶攻城 became a live rider for the first time.** `battle.enemy_forts` used to be declared and
  never filled, so 火砲's and 轟炸機's 「可癱瘓敵方工事」 was inert in every battle in the game.
  Enemy 正規軍 screens now exist, which means player siege/air units spend a shot disabling a wall
  instead of hitting a unit, and player melee that reaches an enemy 遠程列 can be intercepted once
  per wall. Both effects are small per battle and only in 文明戰爭 / 世界大戰.
- **The 近戰列 lost its free sponge.** An engineer in the melee row used to soak a full round of
  enemy attention without ever attacking (hp 3×係數, `no_attack`). Behind the wall it soaks
  nothing, and the enemy melee reaches a real carry a round earlier.
- **Aggregate movement is inside stream-reshuffle noise.** Hard-difficulty WW wins read 86% (31/36)
  against W14.5's 79% (30/38) — up, not down, i.e. the opposite sign to the two changes above, on a
  sample where two runs is 5 points. Normal reads 95% (36/38) against 100%. Battles resolving
  differently reshuffles the `battle` rng track for the whole run, so **per-seed comparison against
  the 2026-07-26 batch is meaningless and only distributions count.** Read this as "the cover chain
  did not move the world-war wall", not as a 7-point gain.
- **Money is the one clear directional move.** Final treasury fell on normal (~9190 → ~8660) and
  hard (~9140 → ~8250), generations-in-debt rose (9.3 → 10.5 normal, 8.4 → 9.1 hard) and normal's
  worst debt deepened to −1150. Consistent with battles costing more 軍費 to close: the bot refields
  more to replace what it loses. *PM call: this eats into the late-game money pile the report has
  flagged as sink-less for three rounds — is it enough, or does the sink question stand?*
- **A collapse fired outside the opening trap for the first time** (3/60 total, up from 2/60):
  seed 1 on hard ends at **generation 13** with 人口 4, where both previous collapses were the
  known gen-4 pop-5 trap (seed 18, normal and hard, both still present). A mid-game collapse means
  the 內亂 chain can now kill a state that had already got past its fragile opening. *PM call: is a
  gen-13 loss the intended teeth, or is it the same −20% riot loss landing on a population the
  disband engine keeps thin?*

## Air & fortification delta (W14.5) — what those rules changed

- **The 空域 rules gave hard difficulty its first real world-war wall.** Player-camp WW wins
  fell from 95% to **79% on hard** (30/38) while easy held at 95% and normal went to 100%
  (W14.7 re-measured these at 95%/95%/86% — see above; the mechanism below is unchanged).
  Mechanism: 正規軍 conversion is greedy strongest-first and 轟炸機 has the highest 攻+血, so
  gen-35 camps are bomber-heavy — and **melee can no longer touch them** (ADR-0006). Answering
  air now requires 遠程 or a 防空飛彈, and hard's ×1.2 enemy stats make a melee-only army lose
  the exchange. This is the closest the batch has come to the design's "gen 35 is a wall"
  anchor, and it arrived from targeting structure rather than from the sizing knobs (P×0.5,
  2 waves, 60/40) that the last report nominated. *PM call: is 79%/100%/95% the wall you
  want, or should the sizing knobs still move?*
- **Caveat on that number: the bot has no air policy.** `_pick_deploy` fields the *cheapest*
  unit card, which is 步兵團/弓箭團 in deck order, and it never plays fortifications — so it
  answers enemy bombers only by accident. A player who deliberately fields 弓箭團/火砲 or a
  防空飛彈+工兵團 pair should do markedly better than 79%. Read the hard-difficulty drop as
  "melee-only armies now lose to air", not as the ceiling for a competent player.
- **防空飛彈 and 盾陣 are unmeasured.** The bot plays no fort cards at all, so the
  disable/repair loop, the battery's destroy-on-hit exchange, and the 同場上限 2 pricing
  (軍費 4, one repair per round) have **zero batch coverage** — they are tested only in
  `battle_test`. **Now a scheduled task, not a suggestion: PLAN.md W16** teaches the bot to field
  forts and re-runs all three difficulties. It was deliberately kept out of W14.9 so that wave's
  gate stays about rule correctness, which means ADR-0010's 3～5-shot ranged budget on 盾陣 joins
  this list until W16 lands. Two limits W16 must state when it reports: the batch will measure the
  fort-playing heuristic we author rather than what a wall is worth to a human reading a wave
  schedule, and every baseline in this report shifts the moment the bot starts fielding walls, so
  the 60-run set has to be re-read rather than diffed.
- **Melee-only remnants now stare at bombers, and the bot gives up the field.** Two hard
  gen-35 wars froze completely (one air unit per camp, zero events per round) because 空域 is
  unreachable from 近戰. The engine settles that as 僵局 once neither side can commit anything;
  the bot now also concedes when neither side can act, which is a legal 選擇不出 and keeps
  uncapped wars from burning empty rounds. Watch for this in the view: a frozen field is a
  legal battle state now, and `Battle.can_act()` is the read that explains an idle unit.
- Battles resolving differently reshuffles the `battle` rng stream for the whole run, so per-seed
  comparisons across batches are never meaningful — only distributions are. That caveat has held
  through every round since and applies to the W14.7 numbers above too.

## The collapse chain fires (3/60) — mostly an opening-game fragility

Two of the three are the same seed (18, normal and hard) and both end at **generation 4**; the
third (seed 1, hard) reaches generation 13 first and is discussed in the W14.7 section above:

1. The 解散-for-population opening lifts 人口 to exactly **5** at gen 3, which is what **arms**
   the 政權崩潰 check (W13.5: it arms at first 人口 ≥ 5).
2. Gen 4 loses an 內部暴動戰 → 失去 1 區域 **and** 人口 −20% → 5 → **4** → below the threshold
   → run over, before the deck or the economy exists.

So the check arms exactly at the value where a single lost riot is lethal, and the bot lingers
there for a generation or two by design (it disbands up to pop 20 over several gens). The air
delta didn't create this — it only reshuffled which runs lose that early riot; the trap has
been reachable since 起始人口 0 landed. *PM calls: should the arming threshold sit above the
lethal one (arm at 人口 ≥ 8–10?), should the riot's −20% have a floor while the state is tiny,
or is "your first riot can end the run" the intended teeth of the opening?*

## Earlier-model findings (still current)

- **The player's camp still wins world wars comfortably outside hard** (105 of 114 overall,
  92%). Real veterans + medal growth against baseline 正規軍, plus the bounded catch-up, keep
  the shared table player-favored; reparations then feed the money pile.
- **Growth is highly active**: 43–52 medal levels on a ~12-card deck by gen 50, and the bot
  banks nothing (兵營 stock always spent). The design's standing flag — attack speed is
  uncapped and lane-routed to every melee carry — is now live in numbers; per-stat level
  telemetry (which lanes those levels sit on) is a cheap next instrument if the PM wants to
  see the 攻速 runaway before v1 numbers ship.
- **Happiness moves.** Pre-rewrite it pegged at 100 in all 60 runs; now means are 88–97 with
  minima of 24 — riot suppression costs plus a heavier unrest cadence bite mid-run. The <60
  penalty zone is reachable in real runs, and hard's mean has slid from 92 to 88.
- **起始人口 0 works as designed past the opening**: every run arms the check, and every run
  that survives generation 5 finishes at pop 53–169. All the fragility is in the first four
  generations (above).

## Standing imbalances (unchanged from the pre-rewrite report)

- **Late-game money still has no sink** (~9,000–9,150 final treasury; WW reparations add to it).
  If gen-50 wealth should mean something, the design needs a late sink or the ranking should
  weigh it. W14.7's heavier battles took the pile down ~10%; W14.9's longer ones put it back.
- **Rival churn is high**: ~3 of 5 rivals die per run; WW camps are thin by gen 35.
- **隱藏災難 mitigation is a money wash** — flagged in docs/decisions.md (W2 gaps).
- **Difficulty channels work**: hard drops mean rank to 2.6, costs ~1 policy node, carries the whole
  WW win-rate gap (74% against 97–98%), and keeps the deepest debt band (worst case −1087 hard,
  −576 easy — debt depth is no longer monotone in difficulty). Slopes remain usable as v1, but the
  hard WW gap is now wide enough to be a design question rather than a slope (see W14.9 above).

## Caveats

The bot is one archetype (balanced builder, strength-parity fielder). It never rushes
military, never plays skill or fortification cards, **never answers air deliberately** (it
fields the cheapest unit, so 弓箭團 only when the cheap 步兵團 are spent), never uses psyops,
and always accepts first-seen rewards. Extreme-archetype bots (all-military, all-culture,
debt-max, never-disband, **fort-and-engineer**) would stress different edges — cheap follow-up
if wanted, and the fort archetype (**PLAN.md W16**) is the only way to get the
ADR-0006/0007/0008/0010 knobs (軍費 3 and 4, 同場上限 2, one repair per round, and 盾陣's 3～5-shot
ranged budget) under measurement. Medal telemetry is total levels only;
per-stat/per-lane splits are not yet instrumented.
