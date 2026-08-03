# Cover absorbs ranged fire, and neutral scatter is cover too

`ADR-0008` left 盾陣 as a melee interceptor: one melee attack aimed at the 遠程列, absorbed once,
then disabled. `ADR-0009` then stripped the battle plates to bare ground, which forced the question
of what the loose objects standing on that ground are; `insignificant-game/docs/decisions.md`
answered "decoration only, no rule may read them" precisely to keep cover from forking into two
systems. The human has now reopened both halves at once, and the two answers compose into one
model:

**Cover stops bullets, not people. A 盾陣 absorbs *ranged* fire aimed at the 遠程列 and has a
multi-shot budget instead of a single interception; melee simply walks around it and engages.
Neutral field scatter is the same object without an owner: some props carry a barrier tier (weak
1-2 shots, medium 2-3, hard 3-5, the last being 盾陣's own band), a hurt land unit automatically
falls back behind an intact one, and it is never repaired — its last shot destroys it.**

Concretely:

- **This supersedes `ADR-0007`'s** 「盾陣 disables by intercepting one melee attack aimed at your
  ground units」 and **`ADR-0008`'s** narrowing of that same rule to the 遠程列. The *row* scope
  survives (a wall screens the 遠程列 and nothing else); the *attack type* inverts from melee to
  ranged, and 「hit once = disabled」 becomes 「budget exhausted = disabled」. Everything else in
  `ADR-0007` stands: never removed, never consumed, engineer round-robin repair, 同場上限 2, forts
  excluded from the field-empty check. A repaired wall rolls a fresh budget.
- **The ordered chain in `ADR-0008` is untouched.** 近戰列（最前）→ 工事線 → 遠程列 → 空域 still
  holds, 工兵團 still stations in the 遠程列 and works at the 工事線, and a station is still
  categorical rather than spatial. What changes is what a layer screens *against*, not where it
  stands.
- **`ADR-0006` is left intact.** Melee still cannot attack 空域, 遠程列 still selects freely, 空襲 is
  still ground-only, and attacks aimed at 空域 still bypass the 工事線. 防空飛彈 is unchanged in
  every respect, including that only 攻城/空襲 can disable it.
- **帶攻城／空襲 fort-busting is unchanged and does not read scatter.** A sieger still disables an
  active enemy *fortification* in one hit with no accuracy roll. Scatter is not a fortification, so
  nothing targets it deliberately; it only erodes by absorbing fire that was aimed at the unit
  behind it.
- **Which props carry which tier is fixed per battle type**, and it is a property of the art
  roster (`assets/pipeline/inventory.md`), not of the battle instance. That gives each of the seven
  battle types a distinct cover profile for free: 民主 fields one hard barrier, 世界大戰 two, and
  隱藏戰 none at all.
- **The core owns the barriers; the view owns the arrangement.** The core knows which barriers this
  battle has, how many shots each has left, and who is behind each one. It still holds no
  coordinates. Placement stays the view's, seeded from the battle's own seed and avoiding the
  stations, so a replay is identical every time.
- **Slowdown and detour are view-only.** Scatter slows land units and they path around it unless
  they are seeking cover, but no rule measures either. The core has no movement to slow, and giving
  it one is the spatial model `ADR-0006` and `ADR-0009` both refuse. If that behaviour ever needs to
  pay off mechanically, it needs its own record.

## Consequences

- **盾陣 changes character a second time,** and in the opposite direction from `ADR-0008`'s. It is
  no longer the answer to a melee push that has chewed through your 近戰列 — that push now reaches
  your archers untouched. It is the answer to an enemy 遠程列, and it answers it several times
  over. 「工事卡（買時間）」 still reads true, but the time it buys is bought from a different
  attacker.
- **Difficulty moves on two axes in opposite directions, and neither is measured.** Melee pressure
  on the 遠程列 rises (nothing absorbs it any more); ranged pressure falls (a wall now eats 3-5
  shots where it used to eat none, and scatter eats more on top). `docs/balance-report.md` already
  records 盾陣 as having zero batch coverage because the sim bot skips every fort card, so the sim
  cannot see either direction until that bot learns to play forts.
- **Neutral cover is the first field entity that belongs to nobody.** `battle.gd`'s state is
  organised as `player_*` / `enemy_*` pairs throughout; a shared array with per-barrier occupancy is
  a genuinely new shape, and "first come, either side" makes the tick order load-bearing for
  determinism in a place it was not before.
- **"Automatic when hurt" is a targeting rule, not an animation.** It gives the core its first
  conditional re-station, so `take_station` re-announcements (`ADR-0008`) now fire for a reason that
  has nothing to do with walls, and the timeline contract in
  `insignificant-game/docs/architecture.md` needs an event for taking and losing cover before the
  W15 view can draw it.
- **The art was rendered before the rule existed.** The 19 approved scatter props were commissioned
  as decoration, so their sizes were authored for looks. 「體積對應掩體等級」 is now a rule, and the
  approved set has to be checked against it rather than assumed to satisfy it.
