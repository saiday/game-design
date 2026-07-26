# Fortifications disable and repair; they are never removed

The 定稿 fort rules carried two competing removal paths that never composed: 「擋完即消耗」
(absorb once, then gone, unless an engineer happened to be on field at that instant) and
「可被攻城／空襲摧毀」 (demolition, implemented as outright removal that always preempted
the absorb, so 防空飛彈's promised 「擋一次…空襲」 never actually happened against a
bomber). The ambiguity surfaced in this design round's questioning and the human replaced
both paths with one lifecycle:

**A fortification hit once becomes 失效 (被禁用). It is never removed from the field, never
consumed. An engineer repairs one disabled fortification per round, in turn; engineers
deployed in later waves repair forts disabled before they arrived. Repaired forts work
again.**

Concretely:

- 盾陣 disables by intercepting one melee attack aimed at your ground units (its scope
  stays melee-only, closing the 盾陣 item left pending in wayfinder ticket #13); 防空飛彈
  disables only when struck by 攻城/空襲 (nothing else can reach a fort).
- 帶攻城/空襲 attackers prefer disabling an **active** enemy fortification (no accuracy
  roll) before hitting units; a disabled fort is inert and not a target. Fort-busting
  means suppression now, not demolition.
- The engineer-present-at-absorb conditional is gone: presence timing no longer matters,
  only that an engineer eventually stands on that side. One engineer works through a
  backlog at one fort per round.
- 同場上限 2 still counts every fielded fort, so a battle holds at most two fort
  deployments for its whole duration (slots never free up).
- Forts never count toward the field-empty half of exhaustion; a side whose units are gone
  is exhausted regardless of standing forts.

This supersedes the decisions.md W1-W9 row 「siege/air demolish fortifications first」 and
the 卡牌.md/戰鬥.md 「擋完即消耗」/「摧毀」 wording (rewritten in the same change).

## Consequences

- The 防空+工兵 loop becomes a durable air answer: a lone bomber that keeps re-disabling a
  repaired battery is locked in a suppression duel and stops killing units; breaking the
  cycle takes a second sieger or killing the engineer. This is intended texture, priced by
  the AA attack value and repair rate (calibration knobs).
- The battle view gains a clean two-state read for structures (運作中/被禁用) and the
  interception moment is the fort's visible action; 戰鬥.md §場景呈現 pins that reading
  (盾陣 materializes when it intercepts, 防空 visibly fires, repair plays out per round).
- `battle.gd`'s fort code changes shape: the demolish branch becomes a disable branch, the
  absorb consume/damage fork collapses into disable, `_repair_forts` loses its
  engineer-present precondition and gains round-robin order, and both changes ride the
  fixed deploy-order determinism contract unchanged.
