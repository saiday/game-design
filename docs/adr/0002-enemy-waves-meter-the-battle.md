# Enemy waves meter the battle, and defeat is exhaustion

With money as the only gate (ADR-0001), a solvent player would deploy everything on round 1, and
`_add_enemies()` already delivered the enemy's whole force at setup, so every battle resolved in
one or two rounds and the 回合上限 of 6 to 12 was decoration. The 最小軍費取勝 gamble that `戰鬥.md`
calls the core 博弈 had collapsed into a single arithmetic step. **The enemy now arrives in waves,
rolled per battle from an authored per-type schedule via a `state.rng` track, and a side is
defeated only when its field is empty AND it has nothing left to commit** (enemy: no waves remain;
player: no unplayed affordable card).

Field-empty could not remain the win condition: with waves bolted onto it, an alpha strike on
round 1 would clear the field and end the battle before wave 2 existed, making waves decorative.

## Consequences

- Survivors persist across waves on both sides, so an uncleared wave stacks on its remnant.
  Under-committing lets the enemy drown you; over-committing burns 軍費 you did not need. That
  tempo tension is the point.
- 開戰前情報 (國策 偵查線) gains real value for the first time: it sells the *roll*. Previously it
  revealed a static force the player would see on round 1 regardless.
- 回合上限 per battle type must be at least last-wave + time-to-clear, or the player times out
  while winning.
