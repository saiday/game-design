# Balance report — v1 baseline knobs under simulation

**Measured at:** 2026-07-25, post-battle-model rewrite (W11–W13.5 + W12.5: rolled card
instances with growth, wave/tick battles, played world wars, 起始人口 0) with the W14 tempo
bot, 21 suites / 222 cases green. When rules or knobs change, re-run the batch and refresh
this report (and this stamp) before comparing.

Source: `tools/balance_batch.gd`, 60 runs (20 seeds × easy/normal/hard), W14 bot
(`core/sim.gd`: greedy builder; disbands personnel for population while pop < 20; routes all
兵營 medals to its strongest unit; fields cheapest units to strength parity per boundary,
personnel-first in riots; concedes unheld fields; enters democracy at gen 38). Raw data:
`reports/balance_batch.json`. These are **measurements and surfaced questions — balance
calls stay with the PM.**

## Headline numbers (mean over 20 runs; min–max where it matters)

| Metric | easy | normal | hard |
|---|---|---|---|
| Endings | 20× survived | 20× survived | 20× survived |
| Final rank (mean, range) | 1.2 (1–2) | 1.6 (1–4) | 2.6 (2–5) |
| Collapse check armed | 20/20 | 20/20 | 20/20 |
| Final population (from 起始 0) | 110 (86–127) | 110 (62–134) | 115 (48–167) |
| World wars fought / won by player camp | 2 / 1.9 | 2 / 1.9 | 2 / 1.9 |
| Medal levels on deck at gen 50 | 55 (11–81) | 54 (28–72) | 65 (6–94) |
| 兵營 medals left unassigned | 0 | 0 | 0 |
| Final happiness | 98 (63–100) | 95 (16–100) | 91 (28–100) |
| Unrest battles triggered / run | 4.8 | 6.2 | 6.3 |
| Deepest debt touched | −96 (to −381) | −130 (to −300) | −168 (to −553) |
| Generations spent in debt | 6.7 | 10 | 10 |
| Final treasury (gen 50) | ~9190 | ~9190 | ~9200 |
| Buildings built (lifetime) | 10.8 | 11.8 | 10.9 |
| Policies completed | 9.3 | 9.1 | 9.0 |
| Deck size | 13.4 | 12.9 | 12.6 |
| Rivals alive at gen 50 | 1.6 | 1.9 | 1.6 |

## The three sensitive knobs

1. **BP curve** — unchanged behavior: era caps bind before `pop/10` once population passes
   ~50; ~9 policy nodes complete per run. The 起始人口 0 opening does NOT starve BP: the
   floor-1 rule plus the disband engine reaches double-digit population inside the tribal
   era. **No change suggested.**
2. **Escalating cost 0.25** — same window as before (debt clusters classical/faith); the
   rewrite didn't move it. Still runs out of things to price by industrial.
3. **Unrest weights** — triggers rose (4.8–6.3/run vs 3.5–4.0 pre-rewrite) because
   happiness now actually moves (below), yet **zero collapses in 60 runs** and every run
   arms the pop ≥ 5 check. The 內亂 chain threatens more often and still never kills. *PM
   call whether "survival fantasy, rarely lethal" is the intent.*

## New-model findings (first measurement of the rewritten battle layer)

- **The player's camp wins ~95% of world wars** (114 of 120 fought). Real veterans + medal
  growth against baseline 正規軍, plus the bounded catch-up, make the shared table strongly
  player-favored; reparations then feed the money pile. If WW2 at gen 35 should be "a
  harder wall" (design anchor), the 正規軍 sizing knobs (P×0.5, 2 waves, 60/40) are the
  levers to revisit — structure supports it, values don't yet bite.
- **Growth is highly active**: 54–65 medal levels on a ~13-card deck by gen 50, and the bot
  banks nothing (兵營 stock always spent). The design's standing flag — attack speed is
  uncapped and lane-routed to every melee carry — is now live in numbers; per-stat level
  telemetry (which lanes those levels sit on) is a cheap next instrument if the PM wants to
  see the 攻速 runaway before v1 numbers ship.
- **Happiness finally moves.** Pre-rewrite it pegged at 100 in all 60 runs; now means are
  91–98 with minima of 16 (normal) and 28 (hard) — riot suppression costs plus heavier
  unrest cadence bite mid-run. The <60 penalty zone is reachable in real runs for the first
  time.
- **起始人口 0 works as designed**: every run crosses the arming threshold, no run ends
  anywhere near pop < 5 (minima 48–86 at gen 50). The 解散-for-population opening is
  load-bearing — a bot that never disbands would sit at pop ≈ building output only.

## Standing imbalances (unchanged from the pre-rewrite report)

- **Late-game money still has no sink** (~9,200 final treasury on every difficulty; WW
  reparations now add to it). If gen-50 wealth should mean something, the design needs a
  late sink or the ranking should weigh it.
- **Rival churn is high**: ~3 of 5 rivals die per run; WW camps are thin by gen 35.
- **隱藏災難 mitigation is a money wash** — flagged in docs/decisions.md (W2 gaps).
- **Difficulty channels work**: hard roughly doubles debt depth, drops mean rank to 2.6,
  and costs ~0.3 policy nodes. Slopes remain usable as v1.

## Caveats

The bot is one archetype (balanced builder, strength-parity fielder). It never rushes
military, never plays skill or fortification cards, never uses psyops, and always accepts
first-seen rewards. Extreme-archetype bots (all-military, all-culture, debt-max,
never-disband) would stress different edges — cheap follow-up if wanted. Medal telemetry is
total levels only; per-stat/per-lane splits are not yet instrumented.
