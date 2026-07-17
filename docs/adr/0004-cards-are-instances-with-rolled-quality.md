# Cards are instances with rolled quality

`卡牌總表` gives every card fixed 攻/血 scaled only by 時代係數, which made two 弓箭團 identical and
made 解散 a footnote in the economy table. **Each card instance now rolls three innate quality
stats (accuracy, dodge, speed) within a per-type distribution at acquisition, and grows them
through per-stat XP.** 攻 and 血 remain fixed per type and era, exactly as the table says: 血 is how
many men the regiment has, 攻 is how hard the type hits, and the innate three are how good these
particular men are.

The gacha is at acquisition, not at level-up. Rolling a 弓箭團 with high accuracy and high speed is
the moment worth caring about, and it makes 解散 a considered operational action rather than a
line item.

## Consequences

- **The art pipeline is unaffected.** Names stay in the era evolution table and 攻/血 stay in
  卡牌總表, so the era-1 units art (`c64270c`, 15 lineage lines keyed to card identity × era)
  remains valid. Only invisible quality stats roll. Randomising names or 攻/血 per instance *would*
  have invalidated it; that is why it was not done.
- 就地演化 carries both the innate three and earned medals forward, so a bad roll is a permanent
  companion for the run unless replaced via the paid 解散 → 解卡費 loop.
- `Cards.CardInstance` is no longer just id + tier, and `state.deck` holds histories rather than
  types.
