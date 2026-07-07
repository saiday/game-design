# Difficulty design (formula + rationale)

> Required by `doc/poc-implementation-gudielines.md`. Implementation: `core/difficulty.gd`.
> The same formula is copied into the design corpus (對手文明 difficulty section, with
> pointers from 戰鬥 and 地圖與機會).

## The formula

One signed difficulty level **d** — easy −1, normal 0, hard +1 — drives three channels
with per-channel slopes. No per-encounter special cases; every difficulty effect in the
game is one of these three lines:

| Channel | Formula | easy | normal | hard |
|---|---|---|---|---|
| Enemy combat stats (attack & hp, every battle type) | ×(1 + 0.20·d), min 1, rounded | ×0.80 | ×1.00 | ×1.20 |
| Opportunity-event penalties (negative money outcomes + mitigation fees; rewards untouched) | ×(1 + 0.25·d), rounded | ×0.75 | ×1.00 | ×1.25 |
| Rival starting power | P0 ×(1 + 0.10·d) | ×0.90 | ×1.00 | ×1.10 |
| Rival growth rate | g + 0.02·d | −0.02 | ±0 | +0.02 |
| Rival aggression frequency | attack chance ×(1 + 0.25·d) | ×0.75 | ×1.00 | ×1.25 |

## Rationale

- **Slopes differ by how compounding the channel is.** Rival g gets the smallest slope
  (0.02) because it compounds over 50 generations (the corpus already pinned ±0.02 as
  "難度＝調曲線"); P0 gets 0.10 as a one-time shift; per-battle enemy stats get 0.20
  because they don't compound; event penalties get 0.25 because opportunities are rare
  enough that a stronger swing is needed to be felt.
- **Rewards never scale.** Difficulty makes the world harsher, not the player richer —
  scaling rewards down on easy would fight the learning purpose of easy mode, and scaling
  them up on hard would partly cancel the penalty channel.
- **Player-side knobs are untouched.** BP curve, build costs, tax, interest, unrest
  weights are identity-defining systems (the fail chain IS the game); difficulty must not
  rewrite what the player is learning to manage, only how hard the outside world pushes.

## Calibration notes (v1)

- All five numbers are baseline knobs; the sim harness (`core/sim.gd`) runs seeded
  full runs per difficulty for calibration.
- Target per the corpus: a normal run absorbs 1–2 unrest losses; easy should almost
  never collapse a player who engages the economy; hard should make WW2 (gen 35) a
  genuine wall without making the tribal era unwinnable (tribal-era enemy floor: stats
  never drop below 1, and the escalation to hard is +20%, roughly one extra weak unit's
  worth in early battles).
