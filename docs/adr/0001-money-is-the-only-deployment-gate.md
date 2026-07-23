# Money is the only deployment gate (no hand)

`戰鬥.md` always ruled that 「出牌的唯一限制是軍費」, but `營運.md` gave 軍事區 a passive of
「戰鬥開場手牌 +1」 and 兵營 a line output of 「戰鬥開場部隊位 +1」, while `對手文明.md` gave 文化國 the
threat 「你的下場戰開場手牌 −1」. Three mutually exclusive deployment gates (軍費, 手牌, 部隊位)
coexisted in a 定稿 corpus, so an agent resolved the contradiction by building a full Slay-the-Spire
hand system (`OPENING_HAND = 4`, draw pile, discard, draw 1/round) and logging it in
the decision log (now `insignificant-game/docs/decisions.md`, W3–W5 section). **We removed the hand and the slots entirely: any unplayed card may be
deployed on any round, gated only by 軍費.** The per-battle constraint that makes holding a reserve
cost something was already in the design and did not need a hand: 用後去向「進棄牌區」 means each card
is playable once per battle.

## Consequences

- 軍事區 lost its only 基礎被動 and 兵營 lost its line output; both were re-specified (see
  ADR-0002's sibling decisions in `insignificant-game/docs/plan-battle-model-rewrite.md`, D14/D15).
- 文化國 lost its only player-facing threat and was re-specified as an accuracy debuff (D16).
- **手牌 and 部隊位 are retired vocabulary.** If a doc, comment, or test implies either exists, it
  is stale. Do not reintroduce them.
