# Core emits a per-round tick timeline; the view replays it

Units act on their own attack speed, so 同時結算 is retired and combat inside a 回合 is continuous
and watchable. The non-negotiable that `core/` is pure and 「the view computes nothing」 means the
view cannot be handed a before/after snapshot and left to invent the animation. **A 回合 is a fixed
tick window, and `core/battle.gd` resolves it into a complete, ordered, tick-stamped event
timeline (every hit, dodge, death, kill credit, medal award) before the view animates a frame. The
view is a replay device and decides nothing.** Same seed, same timeline, same show.

## Considered options

- **Per-battle precomputation** was rejected: it is impossible while the player deploys each round,
  because round N+1's timeline cannot exist until they have decided what to commit against wave N.
  The battle is a chain of precomputed blocks, re-formed at each boundary.
- **Resolving mid-round on player input** was rejected: it makes the stop point depend on human
  click timing, which introduces reaction speed as a skill in a game whose every other decision
  rewards untimed planning, and requires an input log rather than a seed to replay.

## Consequences

- Anything a unit earns mid-round (勳章, XP) is shown live at its tick but applies from the next
  round's block. This is a rule, not a limitation.
- Attack speed becomes the strongest stat in the game. This is the standard autobattler trap;
  measure it before committing v1 numbers.
