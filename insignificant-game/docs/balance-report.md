# Balance report — v1 baseline knobs under simulation

**Measured at:** 2026-08-05, first batch in which the player fields 工事卡 (W16: `sim.gd` grew a
fort policy, so ADR-0007's disable/repair lifecycle, ADR-0008's 遠程列 scope and ADR-0010's
3～5-shot ranged budget are measured from the paying side for the first time), on top of the cover
model (W14.9: ADR-0010), the cover chain (W14.7: ADR-0008), the air & fortification delta
(W14.5: ADR-0006/0007) and the battle-model rewrite (W11–W13.5 + W12.5), 21 suites / 267 cases
green. When rules or knobs change, re-run the batch and refresh this report (and this stamp)
before comparing.

Source: `tools/balance_batch.gd`, 60 runs (20 seeds × easy/normal/hard), W16 bot
(`core/sim.gd`: greedy builder; disbands personnel for population while pop < 20, keeping its last
工兵團 while it holds a 工事卡; routes all 兵營 medals to its strongest unit; fields cheapest units
to strength parity per boundary, personnel-first in riots; then buys cover — 防空飛彈 against enemy
air, 盾陣 for a 遠程列 under 遠程 fire, 工兵團 behind either; concedes unheld or frozen fields with a
200-round backstop; enters democracy at gen 38). Raw data: `reports/balance_batch.json`. These are
**measurements and surfaced questions — balance calls stay with the PM.**

## Two limits on everything in the fort section

Both were written into the W16 task before the numbers existed, and both survive it:

1. **The batch measures a heuristic we authored, not what a wall is worth.** The bot buys a 盾陣
   when it has a 遠程列 to screen and the enemy has someone shooting into it. That is a reading of
   the rules, not of a wave schedule — a human sees the schedule at 開戰前情報 and can buy cover
   *before* the fire arrives. Every fort figure below is a lower bound on a competent player's use
   of the card and an exact measure of this bot's.
2. **Every baseline in this report shifted the moment the bot started fielding walls.** Extra
   deploys consume the `battle` rng track, so per-seed comparison against the 2026-08-03 batch is
   meaningless and the 60-run set has to be **re-read, not diffed**. Where a W14.9 number appears
   below it is there as a distribution, never as a paired sample.

## Headline numbers (mean over 20 runs; min–max where it matters)

| Metric | easy | normal | hard |
|---|---|---|---|
| Endings | 20× survived | 19× survived, **1× 政權崩潰** | 19× survived, **1× 政權崩潰** |
| Final rank (mean, range) | 1.3 (1–3) | 1.7 (0–3) | 2.5 (0–4) |
| Collapse check armed | 20/20 | 20/20 | 20/20 |
| Final population (from 起始 0) | 110 (40–126) | 107 (4–135) | 114 (4–169) |
| World wars fought / won by player camp | 40 / 38 (95%) | 38 / 37 (97%) | 38 / **28 (74%)** |
| Medal levels on deck at gen 50 | 54 (5–82) | 40 (0–74) | 41 (0–86) |
| 兵營 medals left unassigned | 0 | 0 | 0 |
| Final happiness | 98 (61–100) | 92 (42–100) | 92 (52–100) |
| Unrest battles triggered / run | 4.9 | 5.5 | 4.7 |
| Deepest debt touched | −133 (to −832) | −137 (to −350) | −209 (to −676) |
| Generations spent in debt | 8.1 | 8.9 | 9.9 |
| Final treasury (gen 50, survivors) | ~8830 | ~8750 | ~9030 |
| Buildings built (lifetime) | 10.8 | 10.8 | 11.2 |
| Policies completed | 9.4 | 8.7 | 8.3 |
| Deck size | 13.4 | 12.1 | 12.2 |
| Rivals alive at gen 50 | 1.8 | 2.2 | 1.8 |

## The three sensitive knobs

1. **BP curve** — unchanged behavior: era caps bind before `pop/10` once population passes ~50;
   8–9 policy nodes complete per run. The 起始人口 0 opening does not starve BP. **No change
   suggested.**
2. **Escalating cost 0.25** — same window as before (debt clusters classical/faith). Still runs
   out of things to price by industrial.
3. **Unrest weights** — triggers hold at 4.7–5.5/run and the 內亂 chain still **kills**: 2 of 60
   runs end in 政權崩潰, both the gen-4 opening trap (below). Unchanged by cover: a riot is fought
   by 非正規軍 in the 近戰列, which is precisely what a wall does not stop.

## The fort delta (W16) — what a bot that builds cover actually does

| Measure | easy | normal | hard | total |
|---|---|---|---|---|
| Battles driven | 629 | 624 | 601 | 1854 |
| …opening with a 盾陣 in the deck | 505 (80%) | 477 (76%) | 463 (77%) | 1445 (78%) |
| …opening with a 防空飛彈 in the deck | 63 | 56 | 68 | 187 (10%) |
| …with a living enemy 空域 unit at any boundary | 0 | 1 | 19 | **20 (1%)** |
| 盾陣 fielded | 59 | 82 | 65 | 206 |
| 防空飛彈 fielded | 0 | 0 | 9 | 9 |
| 工兵團 fielded by the follow-the-wall rule | 13 | 13 | 2 | 28 |
| 軍費 spent on cover, per run | 44 | 58 | 51 | 51 |
| Ranged shots absorbed by the player's walls | 179 | 138 | 48 | 365 |
| …per wall fielded | **3.03** | **1.68** | **0.74** | 1.77 |
| Player forts suppressed by 帶攻城／空襲 (`disable`) | 48 | 56 | 64 | 168 |
| 工兵團 repairs | 77 | 71 | 65 | 213 |
| Aircraft destroyed by the player's 防空飛彈 | 0 | 0 | 12 | 12 |

- **A wall's value collapses across the difficulty band, and the mechanism is ADR-0007, not
  ADR-0010.** Shots absorbed per wall runs **3.03 → 1.68 → 0.74** from easy to hard while
  suppressions rise 48 → 56 → 64 against a nearly flat number of walls. On hard the wall is
  knocked into 待修 by a sieger or a bomber faster than it can spend its 3～5-shot budget, so the
  budget is a soft number on easy and close to irrelevant on hard. *PM call: is "cover is the
  first thing the enemy shoots" the intended shape, or does a wall that eats less than one arrow
  on hard make 3 軍費 a trap at exactly the difficulty that needs it?*
- **Teaching the bot to build cover did not move the world-war wall. Hard holds at 74%** (28/38),
  the same figure W14.9 measured with no player cover at all; easy reads 95% and normal 97%. This
  is the cleanest negative result in the report and it follows from the rules: a 盾陣 absorbs
  **ranged** fire aimed at the 遠程列, and hard's world-war problem is **air** (ADR-0006 — melee
  cannot reach 空域, and gen-35 正規軍 are bomber-heavy). The card that answers air is 防空飛彈,
  and it was fielded 9 times in 60 runs.
- **防空飛彈 is still effectively unmeasured, and the reason is opportunity, not policy.** The bot
  held one in 10% of battles (it enters the reward pool only at era 4, and this bot acquires cards
  only by being handed them) and **met a living enemy aircraft in 1% of them** — 0 battles on
  easy, 1 on normal, 19 on hard. The 9 batteries and 12 shootdowns all come from 7 hard runs.
  Air is a 正規軍 phenomenon confined to 文明戰爭 and 世界大戰 at era 4+, and outside hard those
  fields are cleared without the bomber wave ever mattering. **Getting the destroy-on-hit exchange
  under measurement needs a bot that *buys* the card (an unlock branch), not one that plays what it
  is dealt** — a cheap follow-up if the PM wants that knob covered.
- **The repair lifecycle went from zero coverage to the best-covered fort rule in the batch:**
  168 suppressions and 213 restorations. Repairs exceed suppressions because a wall also goes 待修
  by exhausting its budget, which the timeline reports as an `intercept` with `shots_left: 0` and
  not as a `disable`.
- **The engineer-follows-wall rule barely fires, and that is fine.** It accounts for 28 of those
  deploys because 工兵團 costs 2 軍費 — the same as 步兵團 and 弓箭團 — so the tempo policy already
  fields it most of the time. The rule is the backstop for the battles where it does not.
- **The bot held a 盾陣 in 78% of battles and fielded one in 11%**, which is a fact about the bot,
  not about the card. It buys a wall only when both halves of the rule are on the field, and
  neither is common under this policy: the tempo bot fields the *cheapest* unit and 步兵團 ties
  with 弓箭團 at 2 軍費 while sitting earlier in the deck, so its 遠程列 is often empty; and
  非正規軍 stand in the 近戰列 unless they carry 帶攻城, so most small battles contain no ranged
  fire for a wall to eat at all. A player who fields archers on purpose meets the precondition far
  more often. 17 of 20 runs at every difficulty fielded at least one wall, so this is not a deck
  problem.
- **Cover costs about 51 軍費 per run** and final treasury reads ~8830/8750/9030 against W14.9's
  ~9020/9140/9050. Generations-in-debt improved on normal (9.6 → 8.9) and hard (10.4 → 9.9).
  Neither move is attributable to cover on its own — battles resolving differently reshuffles the
  whole run — but the money pile did not grow, and it remains the standing imbalance below.
- **Nothing in the 3～5 band was tuned to any of this.** The band is the human's ruling (ADR-0010)
  matched to the neutral-cover tiers; the standing rule at the foot of this file applies.

## What the earlier deltas established (still current)

- **The 空域 rules are what makes hard difficulty hard** (W14.5, ADR-0006). Player-camp world-war
  wins have sat at 95% → 79% → 86% → 74% → **74%** on hard across the last five batches while easy
  and normal stay at 95–98%. 正規軍 conversion is greedy strongest-first and 轟炸機 carries the
  highest 攻+血, so gen-35 camps are bomber-heavy and **melee cannot touch them**. Answering air
  needs 遠程 fire or a 防空飛彈. This is the closest the batch has come to the design's "gen 35 is a
  wall" anchor, and it arrived from targeting structure rather than from the sizing knobs (P×0.5,
  2 waves, 60/40). *PM call: is a 20-point difficulty gap at gen 35 the wall you want?*
- **The enemy's 盾陣 is worth more than the player's** (W14.9, ADR-0010). Enemy 正規軍 screens went
  from eating one melee swing to eating 3–5 ranged shots when the model inverted, and W16 shows the
  player's own wall does not repay that: the bot's walls absorb 1.77 shots each, and on hard 0.74.
  The asymmetry is structural rather than unfair — the enemy's screen arrives free with the wave,
  the player's costs 3 軍費 and a fort slot — but it is the largest single asymmetry the report
  measures.
- **帶攻城 is a live rider** (W14.7). `battle.enemy_forts` used to be declared and never filled, so
  火砲's and 轟炸機's 「可癱瘓敵方工事」 was inert in every battle in the game. It now fires on both
  sides, and the 168 suppressions above are its player-side half.
- **Melee-only remnants stare at bombers and the bot gives up the field.** A frozen field is a legal
  battle state; the engine settles it as 僵局 once neither side can commit anything, and the bot
  concedes rather than burn empty rounds. `Battle.can_act()` is the read that explains an idle unit.
- **Growth is highly active**: 40–54 medal levels on a ~12-card deck by gen 50, and the bot banks
  nothing (兵營 stock always spent). The design's standing flag — attack speed is uncapped and
  lane-routed to every melee carry — is live in the numbers; per-stat level telemetry is a cheap
  next instrument if the PM wants to see the 攻速 runaway before v1 ships.
- **Happiness moves.** Pre-rewrite it pegged at 100 in all 60 runs; means are now 92–98 with minima
  of 42. The <60 penalty zone is reachable in real runs.
- **起始人口 0 works as designed past the opening**: every run arms the collapse check, and every run
  that survives generation 5 finishes at pop 40–169.

## The collapse chain fires (2/60) — an opening-game fragility

Both are seed 18 (normal and hard) and both end at **generation 4**:

1. The 解散-for-population opening lifts 人口 to exactly **5** at gen 3, which is what **arms** the
   政權崩潰 check (W13.5: it arms at first 人口 ≥ 5).
2. Gen 4 loses an 內部暴動戰 → 失去 1 區域 **and** 人口 −20% → 5 → **4** → below the threshold → run
   over, before the deck or the economy exists.

So the check arms exactly at the value where a single lost riot is lethal, and the bot lingers there
for a generation or two by design. Cover changes nothing here: a riot is 非正規軍 in the 近戰列, and
at generation 4 the bot owns no 工事卡 yet. W14.7 saw one mid-game collapse (gen 13, hard) that has
not reproduced in the two batches since; the chain has proved it can kill outside the opening once,
and two clean batches are not evidence it cannot. *PM calls: should the arming threshold sit above
the lethal one (arm at 人口 ≥ 8–10?), should the riot's −20% have a floor while the state is tiny, or
is "your first riot can end the run" the intended teeth of the opening?*

## Standing imbalances

- **Late-game money still has no sink** (~8750–9030 final treasury; WW reparations add to it).
  Cover took ~51 軍費 per run out of it and did not dent the shape. If gen-50 wealth should mean
  something, the design needs a late sink or the ranking should weigh it.
- **Rival churn is high**: ~3 of 5 rivals die per run; WW camps are thin by gen 35.
- **隱藏災難 mitigation is a money wash** — flagged in docs/decisions.md (W2 gaps).
- **Difficulty channels work**: hard drops mean rank to 2.5, costs ~1 policy node, carries the whole
  WW win-rate gap (74% against 95–97%), and now also carries the fort gap (0.74 shots absorbed per
  wall against easy's 3.03). Slopes remain usable as v1; the world-war gap is wide enough to be a
  design question rather than a slope.

## Caveats

The bot is one archetype (balanced builder, strength-parity fielder, opportunistic fort builder). It
never rushes military, never plays skill cards, **never buys a card it was not handed** (`_unlock_cards`
buys four ids and stops, which is why 防空飛彈 reaches the deck in only 10% of battles), never uses
psyops, and always accepts first-seen rewards. Extreme-archetype bots (all-military, all-culture,
debt-max, never-disband, **air-denial**) would stress different edges — cheap follow-up if wanted, and
an air-denial archetype that *unlocks* 防空飛彈 is the only way left to get ADR-0006's destroy-on-hit
exchange under measurement. Medal telemetry is total levels only; per-stat/per-lane splits are not
yet instrumented.

## Standing rule

Numbers in `design/` are **v1 baseline knobs**. The sim exists to *measure* them, not to tune them:
findings and PM calls belong in this file, and the human calibrates by playing. No value in the
corpus has ever been moved to make a batch look better, and this report is where that promise is
kept (`docs/PLAN.md` §Standing rules).
