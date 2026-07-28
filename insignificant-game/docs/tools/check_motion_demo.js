#!/usr/bin/env node
// Renderer check for docs/explore-topdown-motion-demo.html.
//
// The page used to simulate the battle rules in its own JS, so this checker used to assert 46 of
// them. Since W14.7 the page is a REPLAYER: it holds no rule and can only be wrong about the
// picture. So this file checks two different things instead.
//
//   node insignificant-game/docs/tools/check_motion_demo.js
//
// 1. FRESHNESS. The embedded @TIMELINE block must carry the same values as
//    docs/fixtures/battle_timeline.json. Part A re-runs tools/export_timeline.gd and
//    docs/tools/build_motion_demo.py and diffs, so a rule change that moves the timeline cannot
//    leave the page replaying a stale battle. This catches the other half: an edited page.
// 2. THE RENDERER. It stubs out the DOM, boots the page headless, and replays every era
//    frame by frame with every draw call live, asserting that
//      - no rule code came back (no roll, no target choice, no outcome decision),
//      - every event in every fixture resolves to something on screen (unresolved === 0),
//      - each era plays to its recorded end and reports the core's own outcome,
//      - the 掩護鏈 stages front to back: 近戰列 → 工事線 → 遠程列 → 空域, mirrored per side,
//      - forts are never removed and never gain hit points,
//      - a stale field reference in a draw function throws here, not in someone's browser.

const fs = require('fs'), vm = require('vm'), path = require('path');

const PAGE = process.argv[2] ||
  path.join(__dirname, '..', 'explore-topdown-motion-demo.html');
const FIXTURE = path.join(__dirname, '..', 'fixtures', 'battle_timeline.json');
const RAW = fs.readFileSync(PAGE, 'utf8');
const BODY = RAW.split('<script>')[1].split('</script>')[0];

let fails = 0;
function check(name, ok, detail){
  if(ok) console.log('  ok    ' + name);
  else { fails++; console.log('  FAIL  ' + name + (detail ? '  — ' + detail : '')); }
}

// --- 1. freshness ---------------------------------------------------------------------------
console.log('embedded fixture');
const embedded = BODY.split('/* @TIMELINE-BEGIN */')[1].split('/* @TIMELINE-END */')[0];
const embeddedJson = embedded.slice(embedded.indexOf('const TIMELINE = ') + 17).trim().replace(/;$/, '');
// Compare the PARSED values, not the two texts: Python and V8 render floats differently, so a
// byte compare would fail on a fixture that is in fact identical.
const canon = (v) => JSON.stringify(v, (k, x) =>
  (x && typeof x === 'object' && !Array.isArray(x))
    ? Object.fromEntries(Object.keys(x).sort().map(kk => [kk, x[kk]])) : x);
check('the @TIMELINE block matches docs/fixtures/battle_timeline.json',
  canon(JSON.parse(embeddedJson)) === canon(JSON.parse(fs.readFileSync(FIXTURE, 'utf8'))),
  'rebuild it: python3 docs/tools/build_motion_demo.py');

// --- 2. no rule code ------------------------------------------------------------------------
// A replayer that starts rolling dice or choosing targets again is the exact regression this
// rewrite exists to prevent, so name the code that must stay gone.
const BANNED = [
  ['Math.random', 'a roll'],
  ['chooseTarget', 'target selection'],
  ['planAttack', 'attack planning'],
  ['firstActiveFort', 'fort selection'],
  ['canAct(', 'a reachability rule'],
  ['checkOutcome', 'an outcome rule'],
  ['settleDeadlock', 'a deadlock rule'],
  ['repairPass', 'a repair rule'],
  ['fireBatteries', 'a firing rule'],
  ['hasEngineer', 'a repair precondition'],
];
console.log('\nno rule code on the page');
for(const [needle, what] of BANNED)
  check(`no ${needle} (${what})`, !BODY.includes(needle));

// --- the thinnest DOM/canvas that lets the page boot -----------------------------------------
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

function drawOnce(){
  run(`drawField(); forts.forEach(drawFort);
       units.filter(u=>u.row!=='air').sort((a,b)=>a.y-b.y).forEach(drawUnit);
       units.filter(u=>u.row==='air').forEach(drawUnit);
       drawHealthBars(); drawStatTags(); drawProjectiles(); drawFlashes(); drawFloaters();
       drawHoverRing(); drawClock(); drawWinner(); paintTables();`);
}
// Replay one era at 60 fps with every draw call live, stopping when the page settles on its
// closing card. The cap is generous: a fixture round is 4.5 s and no era runs long.
function replay(seconds){
  for(let i=0; i<seconds*60; i++){
    run('step(1/60)');
    drawOnce();
    if(run('ended > 0.5')) return true;
  }
  return false;
}

// --- 3. every era replays -------------------------------------------------------------------
const eras = run('ERAS.map(e=>e.era)');
console.log('\nfull-roster replay, one per era');
for(const era of eras){
  run(`currentEra = ${era}; reset();`);
  const fixtureRounds = run('FX.rounds.length');
  const events = run('plan.length');
  const fortCount = run('forts.length');
  const staged = run('units.filter(u=>u.staged).length');
  const settled = replay(60);

  check(`era ${era}: the whole timeline plays out (${events} events, ${fixtureRounds} rounds)`,
    settled && run('cursor') === events, run('cursor') + '/' + events + ' consumed');
  check(`era ${era}: every event resolved to something on screen`, run('unresolved') === 0,
    run('unresolved') + ' unresolved');
  check(`era ${era}: nobody is staged before 自動佈陣 says so`, staged === 0, staged + ' pre-staged');
  check(`era ${era}: 工事永不移除 (count unchanged)`, run('forts.length') === fortCount);
  check(`era ${era}: 工事沒有血量 (state is 運作中／被禁用 only)`,
    run('forts.every(f=>f.hp===undefined && f.maxhp===undefined)'));
  check(`era ${era}: the closing card reports core's own outcome`,
    ['win', 'loss', 'retreat', 'defected'].includes(run('FX.outcome')), run('FX.outcome'));
}

// --- 4. the cover chain stages front to back ------------------------------------------------
console.log('\n掩護鏈 staging (ADR-0008), mirrored per side');
run('currentEra = 4; reset();');
const mid = run('W/2');
for(const side of [0, 1]){
  const depth = (row) => {
    const xs = run(`units.filter(u=>u.side===${side} && u.row==='${row}').map(u=>u.sx)`);
    return xs.length ? Math.abs(xs[0] - mid) : null;
  };
  const wallX = run(`forts.filter(f=>f.side===${side} && f.wall).map(f=>f.x)`);
  const wall = wallX.length ? Math.abs(wallX[0] - mid) : null;
  const melee = depth('melee'), ranged = depth('ranged'), air = depth('air');
  check(`side ${side}: 近戰列 is the front layer`, melee !== null && melee < wall,
    `melee ${melee} vs 工事線 ${wall}`);
  check(`side ${side}: 工事線 stands in front of the 遠程列`, wall !== null && wall < ranged,
    `工事線 ${wall} vs ranged ${ranged}`);
  if(air !== null)
    check(`side ${side}: 空域 sits behind the 遠程列`, ranged < air, `ranged ${ranged} vs air ${air}`);
  const sameSide = run(`units.filter(u=>u.side===${side}).every(u=>` +
    (side === 0 ? 'u.sx < W/2' : 'u.sx > W/2') + ')');
  check(`side ${side}: every station is on its own half of the field`, sameSide);
}
// A wall is a segment spanning the frontage of the row it screens, not a block on one unit.
const span = run(`forts.filter(f=>f.wall)[0].span`);
const rangedYs = run(`units.filter(u=>u.side===0 && u.row==='ranged').map(u=>u.sy)`);
check('a 盾陣 spans the frontage of the row it screens',
  span && span[0] <= Math.min(...rangedYs) && span[1] >= Math.max(...rangedYs),
  JSON.stringify(span) + ' vs ' + JSON.stringify(rangedYs));
check('a 防空飛彈 is an emplacement, not a segment',
  run(`forts.filter(f=>f.battery).every(f=>f.span === null)`));
run('step(1/60)');   // tick-0 &"take_station" events land on the first frame
check('the 遠程列 knows which wall covers it',
  run(`units.filter(u=>u.side===0 && u.row==='ranged').every(u=>u.screen === 'shield_wall')`));

console.log(fails === 0 ? '\nOK — the replayer stages the timeline it was given'
                        : `\n${fails} FAILED — the page has drifted from its fixture`);
process.exit(fails === 0 ? 0 : 1);
