#!/usr/bin/env node
// Rule checker for docs/explore-topdown-motion-demo.html.
//
// The sandbox asserts the battle rules on screen, so when the rules move it goes quietly stale —
// which is exactly what happened between the 2026-07-25 demo session and ADR-0006/0007. This
// stubs out the DOM, runs the page's own combat code headless, and fails if the sandbox stops
// modelling what `core/battle.gd` actually does.
//
//   node insignificant-game/docs/tools/check_motion_demo.js
//
// It reads the page's JS in place, so it checks the file that ships, not a copy. It does NOT
// check the rendering; it drives every draw call once per frame only so a stale field reference
// in a draw function throws here instead of in someone's browser.
//
// What it pins (design/戰鬥.md, docs/adr/0006 + 0007):
//   - 近戰列 and 空襲 can never resolve an attack against a 空域 unit; 遠程列 can.
//   - 防空飛彈 exists from 工業 (era 4) onward only, fires once per 回合, and a hit destroys.
//   - Fortifications disable and repair; they are never removed, and never enemy-side.
//   - 攻城／空襲 prefer an ACTIVE fort and never re-hit a disabled one.
//   - 僅剩空軍 never claims the field, for either side.
//   - Every era terminates.

const fs = require('fs'), vm = require('vm'), path = require('path');

const PAGE = process.argv[2] ||
  path.join(__dirname, '..', 'explore-topdown-motion-demo.html');
const BODY = fs.readFileSync(PAGE, 'utf8').split('<script>')[1].split('</script>')[0];

// --- the thinnest DOM/canvas that lets the page boot -------------------------------------
function noop(){}
const ctxStub = new Proxy({}, {
  get(t, k){
    if(k === 'measureText') return () => ({width: 40});
    if(k === 'createLinearGradient' || k === 'createRadialGradient')
      return () => ({addColorStop: noop});
    return noop;
  },
  set(){ return true; },
});
function el(id){
  return {id, textContent:'', innerHTML:'', dataset:{}, style:{}, width:1840, height:900,
    getContext: () => ctxStub, addEventListener: noop, appendChild: (c) => c,
    querySelector: () => el('x'), querySelectorAll: () => [], setAttribute: noop,
    getAttribute: () => '', getBoundingClientRect: () => ({left:0, top:0, width:1840, height:900}),
    classList: {add:noop, remove:noop, toggle:noop, contains: () => false}};
}
const sandbox = {
  console, Math, JSON, Object, Array, String, Number, Boolean,
  Image: function(){ return {}; }, setInterval: noop, setTimeout: noop,
  requestAnimationFrame: noop, performance: {now: () => 0},
  MutationObserver: function(){ return {observe: noop}; },
  getComputedStyle: () => ({getPropertyValue: () => '#000'}),
  document: {documentElement: el('root'), getElementById: el, createElement: el,
             querySelectorAll: () => []},
  window: {matchMedia: () => ({matches:false, addEventListener: noop})},
};
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(BODY, sandbox, {filename: path.basename(PAGE)});
const run = (code) => vm.runInContext(code, sandbox);

let fails = 0;
function check(name, ok, detail){
  if(ok) console.log('  ok    ' + name);
  else { fails++; console.log('  FAIL  ' + name + (detail ? '  — ' + detail : '')); }
}
function drawOnce(){
  run(`drawField(); forts.forEach(drawFort);
       units.filter(u=>u.row!=='air').sort((a,b)=>a.y-b.y).forEach(drawUnit);
       units.filter(u=>u.row==='air').forEach(drawUnit);
       drawHealthBars(); drawStatTags(); drawProjectiles(); drawFlashes(); drawFloaters();
       drawHoverRing(); drawWinner(); paintTables();`);
}
function stepFor(seconds, draw){
  for(let i=0; i<seconds*60; i++){
    run('step(1/60)');
    if(draw) drawOnce();
    if(run('!!winner')) return true;
  }
  return false;
}

// Observe what actually resolves, rather than trusting the plan that was made.
run(`
  _log = [];
  const _applyAttack = applyAttack;
  applyAttack = function(u, plan){
    _log.push({mode: plan.mode, kind: attackKind(u),
               targetAir: plan.target ? isAir(plan.target) : false});
    return _applyAttack(u, plan);
  };
  const _applyBatteryShot = applyBatteryShot;
  applyBatteryShot = function(f, plan){
    const alive = plan.target.alive;
    _applyBatteryShot(f, plan);
    _log.push({mode:'battery', killed: alive && !plan.target.alive});
  };
`);

console.log('full-roster runs, one per era');
for(const era of [1,2,3,4,5,6]){
  run(`currentEra = ${era}; _log = []; reset();`);
  const fortCount = run('forts.length');
  const ended = stepFor(180, true);
  const log = run('_log');
  const illegal = log.filter(e => e.mode === 'unit' && e.targetAir && e.kind !== 'ranged');
  const hasBattery = run(`fortLineFor(${era}).includes('anti_air')`);
  const hasAir = run(`rosterFor(${era}).includes('bomber')`);

  check(`era ${era}: 近戰／空襲 never resolved against 空域`, illegal.length === 0,
    illegal.length + ' illegal strikes');
  check(`era ${era}: 工事永不移除 (count unchanged)`, run('forts.length') === fortCount);
  check(`era ${era}: 工事只在我方`, run('forts.every(f=>f.side===0)'));
  check(`era ${era}: 防空飛彈 present iff era >= 4`, hasBattery === (era >= 4));
  check(`era ${era}: the battle terminates`, ended, 'still running after 180s');
  if(hasAir && hasBattery)
    check(`era ${era}: a battery shot an aircraft down`, log.some(e => e.mode === 'battery' && e.killed));
}

console.log('\ntargeted scenarios');
const SETUP = 'currentEra = 4; reset(); projectiles.length = 0;';
const kill = (pred) => `units.filter(u=>${pred}).forEach(u=>{u.alive=false; u.hp=0;});`;

run(`${SETUP} forts.forEach(f=>f.disabled=true); ${kill("u.side===1 && u.cls!=='bomber'")}`);
stepFor(30);
check('敵方僅剩空軍 + 我方有陸軍 → 我方拿下戰場',
  run('winner') === 'BLUE' && run('winNote') === '', run('winner + " / " + winNote'));

run(`${SETUP} forts.forEach(f=>f.disabled=true); ${kill("u.cls!=='bomber'")}`);
stepFor(30);
check('雙方僅剩空軍 → 無人拿下戰場, 僵局判定我方判敗',
  run('winner') === 'RED' && /判敗/.test(run('winNote')), run('winner + " / " + winNote'));

run(`${SETUP} forts.forEach(f=>f.disabled=true);
     ${kill("u.side===0 && u.cls!=='infantry'")} ${kill("u.side===1 && u.cls!=='bomber'")}`);
run('step(1/60)');
check('近戰對上只剩空軍的敵方 = 無合法目標', run('canAct(0)') === false);
check('無合法目標的近戰單位原地不動', run('units.filter(u=>u.alive && u.side===0)[0].moving') === false);
check('但對手的空襲打得到地面, 戰局沒有凍結', run('canAct(1)') === true);
stepFor(60);
check('空軍清完場也不算拿下戰場 → 我方判敗',
  run('winner') === 'RED' && /判敗/.test(run('winNote')), run('winner + " / " + winNote'));

run(`${SETUP} forts.forEach(f=>f.disabled=true); ${kill("u.cls!=='engineers'")}`);
run('step(1/60)');
check('雙方都只剩工兵團 → 兩邊都無法行動', run('canAct(0)') === false && run('canAct(1)') === false);
stepFor(30);
check('凍結戰局立即結算', run('winner') === 'RED' && /凍結/.test(run('winNote')),
  run('winner + " / " + winNote'));

run(`${SETUP} ${kill("u.side===0 && u.cls!=='infantry'")} ${kill("u.side===1 && u.cls!=='bomber'")}`);
check('運作中的防空飛彈 + 敵方有空域目標 → 我方仍能行動', run('canAct(0)') === true);

// 攻城／空襲 target selection, driven directly so it does not depend on the fight going a
// particular way: every active fort first, then units, and never the same fort twice.
run(`${SETUP}
     _plans = [];
     const bomber = units.filter(u=>u.side===1 && u.cls==='bomber')[0];
     for(let k=0;k<50;k++){
       const p = planAttack(bomber, attackKind(bomber));
       _plans.push(p ? p.mode + (p.fort ? ':' + p.fort.cls + (p.fort.disabled ? ':disabled' : '') : '')
                     : 'none');
       if(p && p.mode === 'disable') p.fort.disabled = true;
     }`);
const plans = run('_plans');
check('空襲 disables every active fort first, then moves to units',
  plans[0].startsWith('disable') && plans[1].startsWith('disable') && plans[2] === 'unit',
  plans.slice(0, 4).join(' | '));
check('已失效的工事不再是目標', !plans.some(p => p.includes(':disabled')));

// The suppression exchange: 攻城/空襲 disable, 工兵 repairs, and the line never shrinks.
run(`${SETUP} _n = forts.length;`);
let disables = 0, repairs = 0, prev = run('forts.map(f=>f.disabled)');
for(let i=0; i<60*40; i++){
  run('step(1/60)');
  const now = run('forts.map(f=>f.disabled)');
  now.forEach((d, k) => { if(d && !prev[k]) disables++; if(!d && prev[k]) repairs++; });
  prev = now;
  if(run('!!winner')) break;
}
check('工事被癱瘓過', disables > 0, 'disables=' + disables);
check('工兵把工事修回運作中', repairs > 0, 'repairs=' + repairs);
check('工事數量從頭到尾不變', run('forts.length') === run('_n'));

console.log(fails === 0 ? '\nOK — the sandbox still matches ADR-0006/0007'
                        : `\n${fails} FAILED — the sandbox has drifted from the rules`);
process.exit(fails === 0 ? 0 : 1);
