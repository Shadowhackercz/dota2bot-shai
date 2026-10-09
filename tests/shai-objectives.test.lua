package.path = './?.lua;'..package.path
GetScriptDirectory = function() return 'bots' end
BOT_MODE_DESIRE_NONE, BOT_MODE_DESIRE_LOW, BOT_MODE_DESIRE_HIGH = 0, 0.2, 0.7
BOT_MODE_DESIRE_VERYHIGH, BOT_ACTION_DESIRE_NONE, BOT_ACTION_DESIRE_HIGH = 0.8, 0, 0.8
BOT_MODE_NONE, BOT_MODE_LANING = 0, 1
DAMAGE_TYPE_MAGICAL = 1
local state = {time=900, near=false, damage=250, hp=0.9}
DotaTime, GameTime = function() return state.time end, function() return state.time end
GetTeam, GetOpposingTeam = function() return 2 end, function() return 3 end
local no = function() return false end
local members = {}
local location, ancient = setmetatable({x=0,y=0},{__add=function(a) return a end}), {GetLocation=function() return {} end}
local tormentor = {GetUnitName=function() return 'npc_dota_miniboss' end}
tormentor.IsNull=no
tormentor.CanBeSeen=function() return state.visible end
tormentor.IsAlive=function() return not state.bossDead end
for i=1,5 do
    local member = {pos=i}
    member.IsAlive, member.CanBeSeen = function() return state.dead ~= i end, function() return true end
    member.IsBot = function() return i ~= 2 end -- human mid without a ping
    member.GetLevel, member.GetPlayerID = function() return 15 end, function() return i end
    member.GetLocation = function() return location end
    member.GetAttackDamage, member.GetAttackSpeed = function() return state.damage end, function() return 2 end
    member.GetActiveModeDesire = function() return 0 end
    member.GetNearbyNeutralCreeps = function() return state.empty and {} or {tormentor} end
    member.GetNearbyLaneCreeps = function() return {} end
    member.GetAttackRange = function() return 600 end
    member.HasModifier = no
    member.Action_MoveToLocation = function() state.action='move' end
    member.Action_AttackUnit = function(_, target) assert(target == tormentor); state.action='attack' end
    members[i]=member
end
local bot = members[4]
bot.GetUnitName = function() return 'npc_dota_hero_lion' end
GetBot = function() return bot end
GetTeamPlayers = function() return {1,2,3,4,5} end
GetTeamMember = function(i) return members[i] end
GetAncient = function() return ancient end
GetTower = function() return {} end
GetUnitToUnitDistance = function(_, unit) return unit == tormentor and 100 or 9000 end
GetUnitToLocationDistance = function(unit)
    if state.closestProbe then return unit==members[2] and 10 or (unit==members[1] and 100 or (unit==bot and 200 or 3000)) end
    if state.groupThree then return (unit.pos==2 or unit.pos==5) and 4000 or 100 end
    return state.near and 100 or (unit == bot and 2000 or 4000)
end
IsLocationVisible = function() return state.visible end
local J = {Utils={GameStates={defendPings={pingedTime=0}}}}
J.Utils.IsTeamPushingSecondTierOrHighGround = function() return state.pushing end
J.Utils.CountEnemyHeroesNear = function() return state.baseThreat and 1 or 0 end
J.Utils.IsBotThinkingMeaningfulAction = no
J.GetCoresAverageNetworth = function() return 10000 end
J.GetTormentorLocation, J.GetTormentorWaitingLocation = function() return location end, function() return location end
J.GetAlliesNearLoc = function() return state.near and members or {} end
J.GetEnemiesNearLoc = function() return {} end
J.GetLastSeenEnemiesNearLoc = function() return state.ambush and {6} or {} end
J.IsModeTurbo, J.IsInLaningPhase, J.IsRealInvisible, J.IsDoingRoshan = no, no, no, no
J.IsAttacking, J.DoesUnitHaveTemporaryBuff, J.CanNotUseAction = no, no, no
J.IsDoingTormentor = no
J.IsValid, J.IsValidHero = function(u) return u ~= nil end, function(u) return u ~= nil end
J.IsCore = function(u) return u.pos <= 3 end
J.GetPosition = function(u) return u.pos end
J.GetProperTarget = function() return nil end
J.IsTormentor = function(u) return u == tormentor end
J.GetHP = function() return state.hp end
J.GetAliveAllyCoreCount = function() return state.dead and state.dead <= 3 and 2 or 3 end
J.GetNumOfAliveHeroes = function() return state.dead and 4 or 5 end
J.GetFirstBotInTeam = function() return members[1] end
package.loaded['bots/FunLib/jmz_func'] = J
package.loaded['bots/FunLib/localization'] = {}
package.loaded['bots/Customize/general'] = {ThinkLess=1}
local objective = dofile('bots/mode_side_shop_generic.lua')
state.time = 899
assert(GetDesire() == 0, 'No Tormentor scout before first spawn')
state.time = 900
assert(GetDesire() >= 0.8, 'Strong team should assign a scout from minute fifteen')
bot.tormentor_state, state.near = true, true
assert(GetDesire() > 0.7, 'Human elsewhere without a ping must not veto a healthy team attempt')
Think(); assert(state.action == 'attack', 'A sufficiently grouped team should attack the visible objective')
GAME_STATE_GAME_IN_PROGRESS=7
GetGameState=function() return GAME_STATE_GAME_IN_PROGRESS end
J.GetTeamFountain=function() return location end
bot.SetTarget=function() end
bot.shaiTormentorVeto={issued=state.time,untilTime=state.time+60}
assert(GetDesire()==0,'Player veto overrides autonomous Tormentor readiness')
state.action=nil; Think(); assert(state.action=='move','Stale active Tormentor Think must yield after veto')
bot.shaiTormentorVeto=nil
assert(GetDesire() > 0.7, 'Repeated evaluations must retain valid readiness')
GetTower = function() return nil end
J.GetCoresAverageNetworth = function() return 30000 end
state.time = 2100
assert(GetDesire() > 0.7, 'Safe strong team must remain eligible after T3 loss and high net worth')
state.dead = 2
assert(GetDesire() > 0.7, 'Four healthy allies with two cores can plan the first attempt')
state.action = nil
Think(); assert(state.action == 'attack', 'Four sufficiently grouped allies with two cores can attack')
state.dead = nil
state.hp = 0.2
assert(GetDesire() == 0, 'Cached healthy flag must not survive current low health')
state.hp, state.damage = 0.9, 10
assert(not objective.IsGoodRighClickDamage(), 'Damage readiness must not remember stronger historical items/buffs')
state.damage, state.ambush = 250, true
assert(GetDesire() == 0, 'Known nearby ambush overrides objective')
state.ambush, state.baseThreat = false, true
assert(GetDesire() == 0, 'Base defense overrides objective')
state.baseThreat=false; state.visible=true; state.empty=true; state.time=2130
members[1].tormentor_state=true
assert(GetDesire()==0,'Visible empty objective must clear stale team availability')
for _,member in ipairs(members) do
    assert(member.tormentor_kill_time==nil or member.tormentor_kill_time==0,'Absence must not fabricate a kill time')
    assert(not member.tormentor_state and member.shaiTormentorMissing,'Share absence with the whole team')
end
state.empty=false
assert(GetDesire()>0.7,'A visible spawn immediately overrides the short absence backoff')
state.empty=true; GetDesire(); state.visible=false; state.time=2146; state.near=false
assert(GetDesire()>=0.8,'Without fresh vision the scout retries after fifteen seconds, not ten minutes')
state.near,state.visible,state.empty=true,true,false
GetDesire() -- Observe the actual live unit again.
state.closestProbe=true
assert(objective.GetClosestBot()==members[1],'Pick the nearest actual bot, not a human or a farther bot via mismatched health weighting')
state.closestProbe=false
state.groupThree=true
RandomVector=function() return location end
RandomFloat=function() return 2.5 end
state.action=nil; Think(); assert(state.action=='move','Wait for enough nearby teammates instead of attacking alone')
state.action=nil; state.time=state.time+0.1; Think()
assert(state.action==nil,'Waiting does not select a new random point every fraction of a second')
state.groupThree=false
state.bossDead=true; state.time=2150
assert(GetDesire()==0 and bot.tormentor_kill_time==2150,'A directly observed death records the real kill time')
state.bossDead=false
local originalPrint,lines=print,{}
print=function(line) table.insert(lines,line) end
state.baseThreat=true; state.time=2200; GetDesire()
state.time=2210; GetDesire(); assert(#lines==1,'Unchanged objective reason is throttled')
state.time=2230; GetDesire(); assert(#lines==2,'Persistent objective rejection gets a periodic heartbeat')
assert(lines[2]:find('t=2230') and lines[2]:find('reason=base%-threat'),'The heartbeat retains time and actual decision reason')
print=originalPrint
GetBot=function() return nil end
assert(pcall(dofile,'bots/mode_side_shop_generic.lua'),'Objective mode tolerates a missing bot')
GetBot=function() return bot end
assert(loadfile('bots/FunLib/jmz_func.lua'))

-- Actual Zeus Q: secure a killable creep during early pressure even when the
-- engine has switched away from laning; never spend Q on a healthy creep here.
local arc = {IsFullyCastable=function() return state.castable ~= false end,
    GetCastRange=function() return 600 end, GetCastPoint=function() return 0.2 end,
    GetManaCost=function() return 80 end, GetSpecialValueInt=function(key) return key == 'arc_damage' and 100 or 500 end}
bot.GetAbilityByName = function() return arc end
bot.GetActiveMode = function() return state.mode or BOT_MODE_NONE end
bot.WasRecentlyDamagedByAnyHero = function() return state.pressure end
local creep = {HasModifier=no}
bot.GetNearbyLaneCreeps = function(_, range) return state.creepDistance <= range and {creep} or {} end
J.Skill, J.Item, J.Role = {}, {}, {IsPvNMode=no, IsAllShadow=no}
J.Skill.GetTalentList = function() return {'t1','t2','t3','t4','t5','t6','t7','t8'} end
J.Skill.GetAbilityList = function() return {'q','w','e','d','f','r'} end
J.Skill.GetTalentBuild, J.Skill.GetSkillList = function() return {} end, function() return {} end
J.Item.GetRoleItemsBuyList = function() return 'pos_2' end
J.SetUserHeroInit = function(...) return ... end
J.GetNearbyHeroes = function() return {} end
J.IsInLaningPhase = function() return state.laning end
J.IsEnemyTargetUnit = no
J.WillKillTarget = function(unit) assert(unit == creep); return state.lethal end
J.IsRetreating, J.IsInTeamFight, J.IsPushing, J.IsDefending, J.IsGoingOnSomeone, J.IsFarming = no, no, no, no, no, no
local actualDofile = dofile
dofile = function(path) return path == 'bots/FunLib/aba_minion' and {} or actualDofile(path) end
local zeus = dofile('bots/BotLib/hero_zuus.lua')
state.laning, state.pressure, state.lethal, state.creepDistance = true, true, true, 500
local desire, target = zeus.ConsiderQ()
assert(desire > 0 and target == creep, 'Pressured Zeus should secure Q last hit outside laning mode')
state.lethal = false
assert(zeus.ConsiderQ() == 0, 'No pressure-driven spam on healthy creeps')
state.lethal, state.pressure = true, false
assert(zeus.ConsiderQ() == 0, 'No new indiscriminate lane push without pressure')
state.pressure, state.creepDistance = true, 620
assert(zeus.ConsiderQ() == 0, 'Do not chase outside Q cast range for a pressured last hit')
state.creepDistance, state.castable = 500, false
assert(zeus.ConsiderQ() == 0, 'Cooldown or insufficient mana must still prevent Q')
print('PASS: real Tormentor readiness and safety; real Zeus pressured Q last hits')
