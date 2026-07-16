# Balance report — v1 baseline knobs under simulation

**Measured at:** 2026-07-16, post-W9 rules (includes 鎮壓的手段有代價, the −15 happiness cost for
mechanical units in riot battles), 21 suites / 192 cases green. When rules or knobs change,
re-run the batch and refresh this report (and this stamp) before comparing.

Source: `tools/balance_batch.gd`, 60 runs (20 seeds × easy/normal/hard), baseline bot
(`core/sim.gd`: greedy builder, fights everything, concedes unrest when affordable, enters
democracy at gen 38). Raw data: `reports/balance_batch.json`. These are **measurements and
surfaced questions — balance calls stay with the PM.**

## Headline numbers

| Metric (mean over 20 runs) | easy | normal | hard |
|---|---|---|---|
| Endings | 20× survived | 20× survived | 20× survived |
| Final rank distribution | mostly 1st | 1st–2nd | 2nd–4th |
| Deepest debt touched | −140 | −180 | −330 |
| Generations spent in debt | 5.8 | 7.4 | 9.3 |
| Unrest battles triggered / run | 3.8 | 4.0 | 3.5 |
| Final treasury (gen 50) | ~9060 | ~9080 | ~9290 |
| Final happiness | 100 | 100 | 100 |
| Buildings built (lifetime) | 10.9 | 10.9 | 12.2 |
| Final escalation coefficient | 3.7 | 3.7 | 4.1 |
| Policies completed | 10 | 10 | 9.2 |
| Rivals alive at gen 50 | 1.9 | 1.8 | 1.7 |

## The three sensitive knobs

1. **BP curve** — behaves as designed. Tribal era locks policy out (BP=1, keep-1-free rule);
   from classical on, the era caps (3/3/4/5/5) bind long before `pop/10` does (population
   passes 50 by mid-game). Policy budget lands at ~10 completed nodes ≈ 45–55 BP — exactly
   the corpus's "two mid-price terminals" estimate. **No change suggested.**
2. **Escalating cost 0.25** — bites in the intended window. Debt generations cluster in
   classical/faith exactly when the coefficient crosses ~2×; by industrial the brake is
   irrelevant because all 12 lines are built (~11 lifetime builds). The knob works early but
   **runs out of things to price** — see money finding below.
3. **Unrest weights** — the chain threatens but never kills: 3.5–3.9 triggers per run, all
   absorbed by concession/martial-law/winnable riots; **zero collapses in 60 runs**. The
   corpus target is "a run tolerates 1–2 unrest LOSSES" — the baseline bot never loses one.
   Either the v1 floor is safe-by-design (fine for a survival fantasy) or too safe (the only
   death never shows its teeth). *PM call.*

## Surfaced imbalances (measurements, not decisions)

- **Late-game money has no sink.** Final treasury ≈ 9,000 on every difficulty. The three
  designed caps (escalating cost + interest + capital-gains cap) all stop mattering once
  the 12 building lines are full and democracy halts BP: the last ~12 generations are pure
  accumulation (democracy auto-explore + candidate income + reparations). If gen-50 wealth
  should mean something, the design needs a late sink or the ranking should weigh it.
- **Happiness pegs at 100 in every run.** Medical + arts + legacy passives yield +4–5/gen
  against almost no recurring drains (debt −5 pre-國債司, a few event hits). Above 70 the
  good-draw bonus compounds the snowball. The <60 unrest entrance is effectively
  unreachable for any player who builds the two obvious lines. W9's suppression cost does not
  move the endpoint for the baseline bot (final happiness 100 in all 60 post-W9 runs): any −15
  hits are transient and re-climbed. A happiness *time-series* (not just the endpoint) would
  show whether the rule bites mid-run.
- **Rival churn is high.** ~3 of 5 rivals die (two-defeat exit or annex) per run because
  every injected civil war is fought and usually won; WW at 15/35 then has thin camps.
  If the "five great powers" fantasy should hold to gen 50, exit conditions may be too easy
  to trip from the player side.
- **隱藏災難 mitigation is a money wash** (endure −25×係數 vs pay 15×係數 + take 10×係數) —
  already flagged in decision-w2-gaps.md.
- **Difficulty channels work**: hard triples debt depth, drops final rank to 2nd–4th, and
  costs ~1 policy node — without killing anyone. Slopes look usable as v1.

## Caveats

The bot is one archetype (balanced builder). It never rushes military, never stays out of
democracy, never plays skill cards, never uses psyops. Extreme-archetype bots (all-military,
all-culture, debt-max) would stress different edges — cheap follow-up if wanted.
