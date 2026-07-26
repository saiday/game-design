# Air is countered by ranged fire and anti-air, never by melee; air strikes hit ground only

The battle model had no air rules beyond a row name. `_pick_target` let melee fall back to
any living defender, so a tribal club gang could beat a bomber out of the sky, and nothing
else in the game answered air: 防空飛彈 was a passive one-shot absorber, no anti-air or
air-to-air unit existed, and the 僅剩空軍 outcome was left unset. The human closed the gap
with a categorical targeting matrix, keeping the battle core free of coordinates (the
2026-07-25 REFRAME stands; no spatial model was added):

- **近戰列 cannot attack 空域.** Melee fights the enemy melee row, then the enemy's ground
  backline once that row is clear. The old anything-goes fallback is gone.
- **遠程列 keeps free target selection, explicitly including 空域.** Ranged fire is the
  baseline air answer every roster and wave can carry.
- **空襲 hits ground targets only.** This supersedes `卡牌.md`'s 定稿 line 「空襲：任選目標」
  (the 轟炸機 row): the card's designed role, fort-busting plus backline strikes, is fully
  preserved; only air-to-air is removed. Bombers stop being the game's accidental anti-air.
- **防空飛彈 becomes the dedicated active air counter and stays a 工事卡** (ADR-0007 holds
  its lifecycle): from 工業 era it fires at one 空域 unit per round at the engine defaults
  (命中 100% / 攻速 1.0, no 品質三項, same precedent as every enemy unit; its attack value
  is a v1 baseline knob in the card table). Its former 「擋一次遠程／空襲」 absorb is
  removed, and its era 1-3 forms (擋箭棚/箭樓/城防塔) are retired with that job: no air
  exists before 工業, so no anti-air exists either. Six approved art pieces (3 battlefield
  sprites, 3 card illustrations, era 1-3) are stranded knowingly; nothing is regenerated.
- **Attacks aimed at 空域 bypass the 工事線 entirely.** Interception shields ground rows
  only; a wall on the ground cannot absorb a shot at the sky (and 盾陣 plus engineer
  repair must not make air untouchable).

## Consequences

- **僅剩空軍 is now pinned, symmetrically:** an exhausted side's opponent wins only with
  陸軍 afield; if the opponent holds only air, the battle continues (either side may still
  land ground forces: the player by deploying, the enemy by pending waves) until land
  claims the field or the round cap rules 判輸. Air can never take the field, for either
  side. Forts never count toward field-empty checks.
- **世界大戰 needed a deadlock clause:** with air-vs-air unreachable, the 定稿 claim that
  watch mode 「每 tick 必有傷害…必然收斂」 was false. `世界大戰.md` now resolves the war
  immediately once the battle can no longer change (mutually unreachable remnants, or an
  air-only survivor with no land left to commit): the camp with 陸軍 wins, neither camp
  with 陸軍 = the player's camp loses (conservative, matching the mutual-exhaustion
  ruling). `sim.gd`'s unguarded battle loop stops hanging as a side effect.
- Irregular wave tables (5 of 7 battle types) currently field no ranged members in several
  schedules, so a player bomber is priced by round caps rather than counters there;
  `戰鬥.md` already sanctions 帶攻城/空襲 wave markers, so adding ranged or air presence to
  a schedule is calibration, not structure. Measured solo-bomber margins at era 4:
  一般地圖戰 ≈ 6 rounds vs cap 8, 民主血戰 ≈ 10 rounds vs cap 8 (not soloable).
- The roster gains no fighter class and 防空飛彈 is not promoted to a unit: no new art, no
  new 品質分布 row, no 成長軸 change, no 正規軍 conversion change, and enemy civs still
  field no anti-air (their air answer is their ranged 正規軍).
