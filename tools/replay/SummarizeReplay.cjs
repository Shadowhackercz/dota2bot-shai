const fs = require('node:fs');
const path = require('node:path');
const dir = process.argv[2];
if (!dir) throw new Error('Usage: node SummarizeReplay.cjs export-directory');
const completion = fs.readFileSync(path.join(dir, 'parse-summary.txt'), 'utf8');
if (!/^completed=true\r?$/m.test(completion)) throw new Error('Replay parse is incomplete; refusing a summary');
function tsv(name) {
  const lines = fs.readFileSync(path.join(dir, name), 'utf8').trimEnd().split(/\r?\n/);
  const keys = lines.shift().split('\t');
  return lines.map(line => Object.fromEntries(line.split('\t').map((v,i)=>[keys[i],v])));
}
const events = tsv('combat.tsv');
const positions = tsv('positions.tsv');
const start = +positions.at(-1).startTime;
const eventCount = /^events=(\d+)\r?$/m.exec(completion);
if (!eventCount || events.length !== +eventCount[1] || !(start > 0)) throw new Error('Export count or game-start alignment is invalid');
const fmt = t => `${t < 0 ? '-' : ''}${Math.floor(Math.abs(t)/60)}:${String(Math.floor(Math.abs(t)%60)).padStart(2,'0')}`;
for (const e of events) { e.t = +e.time - start; e.clock = fmt(e.t); }
for (const p of positions) p.t = +p.lastCombatTime - start;
const hero = 'npc_dota_hero_';
const h = name => name.replace(hero, '');
const actualTarget = e => e.targetHero === 'true' && e.targetIllusion !== 'true';
const deaths = events.filter(e=>e.type==='DOTA_COMBATLOG_DEATH' && actualTarget(e));
const cast = events.filter(e=>e.type==='DOTA_COMBATLOG_ABILITY');
const curse = 'modifier_silencer_curse_of_the_silent';
const active = new Map();
const curseCasts = [], intervals = [];
for (const e of events) {
  if (e.inflictor === curse && actualTarget(e)) {
    if (e.type==='DOTA_COMBATLOG_MODIFIER_ADD') active.set(e.target,e);
    if (e.type==='DOTA_COMBATLOG_MODIFIER_REMOVE') {
      const begin = active.get(e.target);
      if (begin) intervals.push({hero:h(e.target),start:begin.t,end:e.t,duration:e.t-begin.t,startHP:+begin.health,endHP:+e.health});
      active.delete(e.target);
    }
  }
  if (e.type==='DOTA_COMBATLOG_ABILITY' && active.has(e.attacker)) {
    curseCasts.push({clock:e.clock,t:e.t,hero:h(e.attacker),spell:e.inflictor,target:h(e.target),targetHP:e.health,sinceCurse:e.t-active.get(e.attacker).t});
  }
}
function group(items,key) { const m = {}; for(const i of items) m[key(i)] = (m[key(i)]||0)+1; return m; }
const warlockUlts = cast.filter(e=>e.attacker===hero+'warlock' && e.inflictor==='warlock_rain_of_chaos').map(e=>({clock:e.clock,t:e.t,target:h(e.target),nextDeath:deaths.find(d=>d.target===hero+'warlock' && d.t>=e.t)?.t-e.t}));
const runeRows = tsv('team-state.tsv');
const last = new Map();
const runeChanges = [];
const glyphChanges = [];
for(const row of runeRows) {
  const v = +row.value, old = last.get(row.key), t = +row.lastCombatTime-start;
  if(row.value && old!==undefined && v>old) {
    if(row.key.includes('Runes')) runeChanges.push({clock:fmt(t),t,key:row.key,from:old,to:v});
    if(row.key.includes('Glyph') && t>=0) glyphChanges.push({clock:fmt(t),t,key:row.key,from:old,to:v});
  }
  if(row.value) last.set(row.key,v);
}
const first10 = cast.filter(e=>e.t>=0 && e.t<=600 && e.attacker===hero+'zuus');
const roshanDamage = events.filter(e=>e.type==='DOTA_COMBATLOG_DAMAGE' && (e.target==='npc_dota_roshan'||e.attacker==='npc_dota_roshan'));
const summary = {
  startTime:start,lastEventGameTime:events.at(-1).t,events:events.length,
  deathsByHero:group(deaths,e=>h(e.target)),killsByHero:group(deaths,e=>h(e.attacker)),
  silencerDeaths:deaths.filter(e=>e.target===hero+'silencer').map(e=>({clock:e.clock,attacker:h(e.attacker),spell:e.inflictor})),
  curseCastsByHero:group(curseCasts,e=>e.hero),zeusFirst10Casts:group(first10,e=>e.inflictor),
  zeusFirst10CurseSpellCounts:group(curseCasts.filter(e=>e.hero==='zuus'&&e.t>=0&&e.t<=600),e=>e.spell),
  zeusFirst10CurseCasts:curseCasts.filter(e=>e.hero==='zuus'&&e.t>=0&&e.t<=600),
  zeusCurseIntervals:intervals.filter(e=>e.hero==='zuus'),warlockUlts,
  warlockDeaths:deaths.filter(e=>e.target===hero+'warlock').map(e=>({clock:e.clock,t:e.t,attacker:h(e.attacker)})),
  runeChanges,glyphChanges,
  xpReason4:events.filter(e=>e.type==='DOTA_COMBATLOG_XP'&&e.xpReason==='4').map(e=>({clock:e.clock,t:e.t,hero:h(e.target),xp:+e.value})),
  roshanDamage:roshanDamage.map(e=>({clock:e.clock,t:e.t,attacker:h(e.attacker),target:h(e.target),spell:e.inflictor,value:+e.value,health:+e.health}))
};
fs.writeFileSync(path.join(dir,'analysis.json'),JSON.stringify(summary,null,2));
console.log(JSON.stringify({...summary,zeusCurseIntervals:summary.zeusCurseIntervals.slice(0,7),roshanDamage:summary.roshanDamage.slice(0,20)},null,2));
