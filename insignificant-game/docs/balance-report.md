# Balance report — v1 baseline knobs under simulation

**Measured at:** 2026-07-26, post-air-&-fortification delta (W14.5: ADR-0006 targeting matrix
+ 防空飛彈 destroy-on-hit, ADR-0007 fort disable/repair) on top of the battle-model rewrite
(W11–W13.5 + W12.5: rolled card instances with growth, wave/tick battles, played world wars,
起始人口 0), with the W14 tempo bot, 21 suites / 234 cases green. When rules or knobs change,
re-run the batch and refresh this report (and this stamp) before comparing.

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
| Final rank (mean, range over survivors) | 1.2 (1–2) | 1.6 (1–3) | 2.5 (2–4) |
| Collapse check armed | 20/20 | 20/20 | 20/20 |
| Final population (from 起始 0) | 108 (68–126) | 105 (4–136) | 112 (4–169) |
| World wars fought / won by player camp | 40 / 38 (95%) | 38 / 38 (100%) | 38 / **30 (79%)** |
| Medal levels on deck at gen 50 | 55 (29–81) | 51 (0–81) | 53 (0–92) |
| 兵營 medals left unassigned | 0 | 0 | 0 |
| Final happiness | 96 (22–100) | 94 (55–100) | 92 (22–100) |
| Unrest battles triggered / run | 5.2 | 5.7 | 4.9 |
| Deepest debt touched | −124 (to −329) | −131 (to −389) | −273 (to **−1065**) |
| Generations spent in debt | 7.1 | 9.3 | 8.4 |
| Final treasury (gen 50, survivors) | ~9140 | ~9190 | ~9140 |
| Buildings built (lifetime) | 11.2 | 10.8 | 11.0 |
| Policies completed | 9.3 | 8.6 | 8.6 |
| Deck size | 13.2 | 12.4 | 13.1 |
| Rivals alive at gen 50 | 1.7 | 2.0 | 1.7 |

## The three sensitive knobs

1. **BP curve** — unchanged behavior: era caps bind before `pop/10` once population passes
   ~50; ~9 policy nodes complete per run. The 起始人口 0 opening does NOT starve BP: the
   floor-1 rule plus the disband engine reaches double-digit population inside the tribal
   era. **No change suggested.**
2. **Escalating cost 0.25** — same window as before (debt clusters classical/faith); the
   rewrite didn't move it. Still runs out of things to price by industrial.
3. **Unrest weights** — triggers hold at 4.9–5.7/run and the 內亂 chain now **kills for the
   first time**: 2 of 60 runs end in 政權崩潰 (see below). The lethality that the previous
   two reports flagged as missing exists, and it is concentrated entirely in the opening.

## Air & fortification delta (W14.5) — what the new rules changed

- **The 空域 rules give hard difficulty its first real world-war wall.** Player-camp WW wins
  fell from 95% to **79% on hard** (30/38) while easy held at 95% and normal went to 100%.
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
  `battle_test`. Instrumenting a fort-playing bot archetype is the cheap next step if the PM
  wants those knobs measured before v1.
- **Melee-only remnants now stare at bombers, and the bot gives up the field.** Two hard
  gen-35 wars froze completely (one air unit per camp, zero events per round) because 空域 is
  unreachable from 近戰. The engine settles that as 僵局 once neither side can commit anything;
  the bot now also concedes when neither side can act, which is a legal 選擇不出 and keeps
  uncapped wars from burning empty rounds. Watch for this in the view: a frozen field is a
  legal battle state now, and `Battle.can_act()` is the read that explains an idle unit.
- Everything else moved only slightly and in the same direction (final treasury ~9,140–9,190
  vs ~9,190; debt deeper on hard, −1065 worst case vs −553). Battles resolving differently
  reshuffles the `battle` rng stream for the whole run, so per-seed comparisons against the
  2026-07-25 batch are not meaningful — only distributions are.

## The collapse chain finally fires (2/60) — and it is an opening-game fragility

Both collapses are the same seed (18, normal and hard) and both end at **generation 4**:

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

- **The player's camp still wins world wars comfortably outside hard** (106 of 116 overall,
  91%). Real veterans + medal growth against baseline 正規軍, plus the bounded catch-up, keep
  the shared table player-favored; reparations then feed the money pile.
- **Growth is highly active**: 51–55 medal levels on a ~13-card deck by gen 50, and the bot
  banks nothing (兵營 stock always spent). The design's standing flag — attack speed is
  uncapped and lane-routed to every melee carry — is now live in numbers; per-stat level
  telemetry (which lanes those levels sit on) is a cheap next instrument if the PM wants to
  see the 攻速 runaway before v1 numbers ship.
- **Happiness moves.** Pre-rewrite it pegged at 100 in all 60 runs; now means are 92–96 with
  minima of 22 — riot suppression costs plus a heavier unrest cadence bite mid-run. The <60
  penalty zone is reachable in real runs.
- **起始人口 0 works as designed past the opening**: every run arms the check, and every run
  that survives generation 5 finishes at pop 53–169. All the fragility is in the first four
  generations (above).

## Standing imbalances (unchanged from the pre-rewrite report)

- **Late-game money still has no sink** (~9,150 final treasury on every difficulty; WW
  reparations now add to it). If gen-50 wealth should mean something, the design needs a
  late sink or the ranking should weigh it.
- **Rival churn is high**: ~3 of 5 rivals die per run; WW camps are thin by gen 35.
- **隱藏災難 mitigation is a money wash** — flagged in docs/decisions.md (W2 gaps).
- **Difficulty channels work**: hard doubles debt depth (now ~2×, worst case −1065), drops
  mean rank to 2.5, costs ~0.7 policy nodes, and since W14.5 also owns the WW win-rate gap.
  Slopes remain usable as v1.

## Caveats

The bot is one archetype (balanced builder, strength-parity fielder). It never rushes
military, never plays skill or fortification cards, **never answers air deliberately** (it
fields the cheapest unit, so 弓箭團 only when the cheap 步兵團 are spent), never uses psyops,
and always accepts first-seen rewards. Extreme-archetype bots (all-military, all-culture,
debt-max, never-disband, **fort-and-engineer**) would stress different edges — cheap follow-up
if wanted, and the fort archetype is the only way to get the ADR-0006/0007 knobs (軍費 4,
同場上限 2, one repair per round) under measurement. Medal telemetry is total levels only;
per-stat/per-lane splits are not yet instrumented.
