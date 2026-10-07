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
local location, ancient = {}, {GetLocation=function() return {} end}
local tormentor = {GetUnitName=function() return 'npc_dota_miniboss' end}
for i=1,5 do
    local member = {pos=i}
    member.IsAlive, member.CanBeSeen = function() return state.dead ~= i end, function() return true end
    member.IsBot = function() return i ~= 2 end -- human mid without a ping
    member.GetLevel, member.GetPlayerID = function() return 15 end, function() return i end
    member.GetLocation = function() return location end
    member.GetAttackDamage, member.GetAttackSpeed = function() return state.damage end, function() return 2 end
    member.GetActiveModeDesire = function() return 0 end
    member.GetNearbyNeutralCreeps = function() return {tormentor} end
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
GetUnitToLocationDistance = function(unit) return state.near and 100 or (unit == bot and 2000 or 4000) end
IsLocationVisible = no
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
