-- Exercise the real mode with a changing, mocked game; run in a fresh Lua VM.
package.path = './?.lua;'..package.path
GetScriptDirectory = function() return 'bots' end
BOT_MODE_DESIRE_NONE, BOT_ACTION_DESIRE_NONE = 0, 0
BOT_MODE_DESIRE_MODERATE, BOT_MODE_DESIRE_ABSOLUTE = 0.5, 1
UNIT_LIST_ALLIED_HEROES = 1
local state = {hp = 1, enoughDPS = true, roshHP = 1, seenRoshan = false,
    enemies = 0, allyCount = 5, enemyCount = 5, alive = true}
local bot = {}
local pit={x=0,y=0}
BOT_MODE_ROSHAN=17
state.time=1200
function bot:GetUnitName() return 'npc_dota_hero_sven' end
function bot:IsInvulnerable() return false end
function bot:IsHero() return true end
function bot:IsAlive() return state.alive end
function bot:IsIllusion() return false end
function bot:HasModifier() return false end
function bot:GetTeam() return 2 end
function bot:GetLocation() return {x=100,y=0} end
function bot:GetActiveMode() return state.mode or BOT_MODE_ROSHAN end
function bot:GetPlayerID() return 1 end
function bot:SetTarget(target) state.target=target end
function bot:Action_ClearActions() state.clear=(state.clear or 0)+1 end
function bot:Action_MoveToLocation(loc) state.move=loc end
local roshan = {}
function roshan:IsNull() return state.null end
function roshan:CanBeSeen() return state.seenRoshan end
function roshan:IsAlive() return not state.deadRoshan end
function roshan:IsInvulnerable() return state.invulnerable end
function roshan:IsAttackImmune() return state.attackImmune end
function roshan:GetLocation() assert(state.seenRoshan,'Read hidden location'); return state.roshLocation or pit end
function roshan:GetUnitName() return 'npc_dota_roshan' end
function roshan:GetHealth() assert(state.seenRoshan,'Read hidden health'); return state.roshHP * 10000 end
function roshan:GetMaxHealth() return 10000 end
function bot:GetNearbyNeutralCreeps() return state.seenRoshan and {roshan} or {} end
local illusion = {IsAlive = function() return true end, IsIllusion = function() return true end}
GetBot = function() return bot end
DotaTime = function() return state.time end
GAME_STATE_GAME_IN_PROGRESS=7
GetGameState=function() return GAME_STATE_GAME_IN_PROGRESS end
GetAncient = function() return {} end
GetUnitList = function() return {bot, illusion} end
GetUnitToLocationDistance = function() return 5000 end
GetRoshanDesire = function() return 0.7 end
Clamp = function(value, low, high) return math.max(low, math.min(high, value)) end
RemapValClamped = function(value, a, b, low, high)
    return low + Clamp((value - a) / (b - a), 0, 1) * (high - low)
end
local J = {Utils = {IsTeamPushingSecondTierOrHighGround = function() return false end,
    IsValidUnit = function(unit) return unit ~= nil end, CountBackpackEmptySpace = function() return 6 end}}
J.GetHP = function(unit) return unit == bot and state.hp or 1 end
J.Utils.RadiantRoshanLoc,J.Utils.DireRoshanLoc=pit,{x=5000,y=5000}
J.GetDistance=function(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
J.GetCurrentRoshanLocation=function() return pit end
J.GetProperTarget=function() return state.target end
J.IsRoshan=function(u) return u==roshan end
J.IsValidHero=function(u) return u==bot end
J.CanNotUseAction=function() return state.busy end
J.GetTeamFountain=function() return {x=-5000,y=0} end
J.VectorAway=function(origin) return {x=origin.x+650,y=0} end
IsLocationPassable=function() return state.passable~=false end
J.GetEnemiesAroundAncient = function() return 0 end
J.CheckTimeOfDay = function() return 'day' end
J.GetTeamFightLocation = function() return nil end
J.GetLastSeenEnemiesNearLoc = function() return {} end
J.GetNumOfAliveHeroes = function(enemy) return enemy and state.enemyCount or state.allyCount end
J.IsCore = function() return false end
J.IsRoshanAlive = function() return true end
J.HasEnoughDPSForRoshan = function(heroes)
    assert(#heroes == 1 and heroes[1] == bot, 'Illusion counted towards Roshan readiness')
    return state.enoughDPS
end
J.IsRoshanCloseToChangingSides = function() return state.switch end
J.GetEnemiesNearLoc = function() return state.enemies > 0 and { { } } or {} end
J.GetHumanPing = function() return nil, nil end
package.loaded['bots/FunLib/jmz_func'] = J
package.loaded['bots/Customize/general'] = {}
dofile('bots/mode_roshan_generic.lua')
assert(GetDesireHelper() > 0, 'Healthy ready team should consider Roshan')
state.enoughDPS = false
assert(GetDesireHelper() == 0, 'Readiness persisted after damage was lost')
state.enoughDPS = true
state.hp = 0.39
assert(GetDesireHelper() == 0, 'Wounded bot should recover')
state.hp = 1
state.enemies = 1
assert(GetDesireHelper() == 0, 'Nearby enemy should prevent ordinary Roshan attempt')
state.enemies = 0
state.allyCount = 3
assert(GetDesireHelper() == 0, 'Outnumbered team should not start Roshan')
state.allyCount = 5
state.seenRoshan, state.roshHP = true, 0.49
local halfHealthDesire = GetDesireHelper()
state.roshHP = 0.01
local finishingDesire = GetDesireHelper()
assert(halfHealthDesire < 0.6 and finishingDesire > 0.95,
    'Finishing urgency must scale over fractional health rather than percent health')
bot.shaiRoshanVeto={issued=1200,untilTime=1260}
assert(GetDesireHelper()==0,'Player veto overrides autonomous finishing urgency')
bot.shaiRoshanVeto=nil
state.hp = 0.2
assert(GetDesireHelper() == 0, 'Nearly dead bot should not chase a finishing objective')
state.hp,state.target=1,roshan
local Safety=require('bots/FunLib/shai_roshan_safety')
state.switch=true
assert(GetDesireHelper()==0,'Low Roshan HP must not bypass the approaching day/night switch')
state.switch=false; state.invulnerable=true
assert(GetDesireHelper()==0,'Invulnerable Roshan cannot be finished')
assert(Safety.GuardActions(bot,J) and state.move~=nil and state.target==nil,'Cancel stale objective attacks')
state.invulnerable=false; state.attackImmune=true
assert(GetDesireHelper()==0,'Attack immune Roshan cannot be finished')
state.attackImmune=false; state.roshLocation={x=2500,y=2500}
assert(GetDesireHelper()==0,'After the calendar switch, off-pit Roshan remains unsafe')
state.time=state.time+1; state.target=roshan; state.busy=true; state.move=nil
assert(Safety.GuardActions(bot,J) and state.move==nil,'Preserve casts and channels already in progress')
state.busy=false; state.passable=false; state.time=state.time+1
assert(Safety.GuardActions(bot,J) and state.move.x==-5000,'Fall back when the escape point is impassable')
state.roshLocation=J.Utils.DireRoshanLoc
assert(GetDesireHelper()>0.95,'Visible attackable Roshan inside either pit is usable')
state.seenRoshan=false; state.target=roshan; state.enoughDPS=false
assert(GetDesireHelper()==0,'Stale hidden low HP cannot override current readiness')
state.target=bot; state.switch=true; state.move=nil
assert(not Safety.GuardActions(bot,J) and state.move==nil,'Never replace self defense against a hero')
state.target=nil; state.mode=0
assert(not Safety.GuardActions(bot,J),'Unrelated travel is not globally rerouted')
-- Exercise the actual generic ability and item dispatchers, not a copy.
local makeAbility=dofile('.tools/lua/shai-ability-callback.lua')
local makeItem=dofile('.tools/lua/shai-item-callback.lua')
local casts=0
bot.frameProcessTime=0.1
bot.lastAbilityFrameProcessTime,bot.lastItemFrameProcessTime=state.time-1,state.time-1
state.mode,state.switch,state.roshLocation,state.seenRoshan=BOT_MODE_ROSHAN,false,{x=2500,y=2500},true
state.passable=true
J.IsNoAbilityIllution=function() return false end
J.IsNoItemIllution=function() return false end
local callback=makeAbility(bot,J,{TryControl=function() return false end,HoldOffense=function() return false end},
    {Observe=function() end},{},{ThinkLess=1},{SkillsComplement=function() casts=casts+1 end},
    function() return false end,true,bot:GetUnitName(),{ReleaseObjective=function() end},nil,nil,nil,nil,nil,nil,Safety)
local itemCallback=makeItem(bot,J,{ThinkLess=1},function() return false end,
    {IsCommitting=function() return false end},function() casts=casts+1 end,bot:GetUnitName(),
    {ThinkFade=function() return false end,RecheckTeleport=function() return false end},Safety)
state.time=state.time+1; callback(); itemCallback()
assert(casts==0,'Actual dispatchers must not cast hero spells or items at a migrating Roshan')
state.roshLocation=pit; state.time=state.time+1; callback(); itemCallback()
assert(casts==2,'Actual dispatchers resume ordinary casts when Roshan is attackable in the pit')
GetBot = function() return nil end
assert(pcall(dofile, 'bots/mode_roshan_generic.lua'), 'Mode should handle missing bot')
print('PASS: real Roshan mode readiness changes, recovery, enemy pressure, illusions and finishing urgency')
