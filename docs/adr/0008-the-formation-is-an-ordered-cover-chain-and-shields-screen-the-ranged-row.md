# The formation is an ordered cover chain, and shields screen the ranged row

The 定稿 formation put the 工事線 at the very front, ahead of the 近戰列, and scoped 盾陣 to
intercept a melee attack aimed at any friendly **ground** unit. Both halves were wrong in the same
way: the wall stood in front of the whole army and belonged to nobody. It protected the row that was
already in front of it, and because 「掩體感由畫面的前後遮蔽表達，不用座標」 was the only statement
about cover, nothing in the model ever said which units a given wall covers. The human replaced it
with an ordered chain:

**自動佈陣 places four layers, front to back: 近戰列（最前）→ 工事線 → 遠程列 → 空域. Each layer
screens the one behind it. 盾陣 intercepts one melee attack aimed at a unit in the 遠程列, and
nothing else.** 玩家不指定位置 still holds, and the core still gains no coordinates.

Concretely:

- **This supersedes `ADR-0007`'s** 「盾陣 disables by intercepting one melee attack aimed at your
  ground units」. The scope narrows from any ground unit to the 遠程列. Everything else in that
  record stands unchanged: melee-only interception, one hit disables, never removed, never consumed,
  engineer round-robin repair, 同場上限 2, forts excluded from the field-empty check.
- **This amends `design/戰鬥.md`'s** 自動佈陣 order and its §場景呈現 前後即掩護 reading. 「不用座標」
  survives verbatim; what changes is that cover is now a fact the core states (a unit takes a
  station in the chain) rather than a property of draw order.
- **`ADR-0006` is left intact.** Its targeting matrix is unchanged: 近戰列 cannot attack 空域, 遠程列
  selects freely including 空域, 空襲 is ground-only, 防空飛彈 destroys on hit, and attacks aimed at
  空域 still bypass the 工事線 entirely. The reorder gives the battle core no spatial model, so no
  rule in ADR-0006 depends on where the fort line sits.
- **One card is one wall segment,** spanning the ranged row's frontage rather than covering one named
  unit. 同場上限 2 is unchanged, so a side can screen its ranged row twice over and no more, and the
  wall's owner never has to be chosen.
- **工兵團 relocates from the 近戰列 to the 遠程列,** and the repair cursor is its station: the
  engineer stands behind the wall it maintains and works along the fort line, one fort per round. This
  is what makes "moves beside the wall to fix it" a modelled fact instead of an animation, still with
  no coordinates.
- **正規軍 field 盾陣; 非正規軍 field no works.** Enemy screens are subject to the same 同場上限 2.
  Enemy 防空飛彈 is not introduced, so ADR-0006's "enemy civs still field no anti-air" stays true
  word for word.
- **Enemy screens never repair.** There is no enemy 工兵團, because the 正規軍 roster is built from
  the player's real card list minus its 不主動攻擊 members. The asymmetry is deliberate and it is the
  engineer line's whole value: your 帶攻城／空襲 units permanently strip an enemy screen, theirs only
  suppress yours until your engineer comes back round.

**Why the reorder is safe: no melee unit ever needs to reach a fort.** Fort-busting is gated on
`siege` / `air_strike`, and every carrier of those flags is already stationed behind or above the
melee line. 火砲 is 遠程列, 轟炸機 is 空域, and `design/戰鬥.md` places 帶攻城／空襲 irregulars in the
遠程／空域 rows for exactly this reason. Putting the melee line in front of the wall therefore
removes nothing from anyone's reach; it only stops the wall from being the first thing an enemy club
gang walks into.

## Consequences

- **盾陣 changes character from a first-swing absorber to a 買時間 backline saver.** It no longer eats
  the opening exchange; it fires only once the enemy melee has chewed through your 近戰列 and reached
  the 遠程列. `戰鬥.md`'s 「工事卡（買時間）遠比過去值錢」 reading gets sharper, not weaker: the wall now
  buys time for the units that were going to die next.
- **The 近戰列 loses a 3-HP sponge** when the engineer leaves it. An engineer in the melee row used to
  soak a full round of enemy attention without ever attacking; that free absorption is gone.
- **A 盾陣 with no 遠程列 unit behind it intercepts nothing.** The interception needs an attack aimed
  at the ranged row to exist, so an all-melee deck buys a wall that never fires. Logged in
  `insignificant-game/docs/decisions.md`.
- **Difficulty rises on two axes at once,** and both need re-calibration. Narrowing 盾陣 costs the
  player an absorb every battle, and giving 正規軍 screens makes `帶攻城`'s rider live for the first
  time (`battle.enemy_forts` was declared and read but never appended to, so 火砲 and 轟炸機 both
  advertised 「可癱瘓敵方工事」 against an empty array). Civ-war and world-war outcomes move on top of
  the 79% hard-difficulty world-war figure ADR-0006 already recorded. The balance batch cannot measure
  it: the sim bot skips every fort card, and `docs/balance-report.md` already records 盾陣 and 防空飛彈
  as having zero batch coverage.
