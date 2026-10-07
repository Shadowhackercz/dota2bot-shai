-- Exercise the real mode with a changing, mocked game; run in a fresh Lua VM.
package.path = './?.lua;'..package.path
GetScriptDirectory = function() return 'bots' end
BOT_MODE_DESIRE_NONE, BOT_ACTION_DESIRE_NONE = 0, 0
BOT_MODE_DESIRE_MODERATE, BOT_MODE_DESIRE_ABSOLUTE = 0.5, 1
UNIT_LIST_ALLIED_HEROES = 1
local state = {hp = 1, enoughDPS = true, roshHP = 1, seenRoshan = false,
    enemies = 0, allyCount = 5, enemyCount = 5, alive = true}
local bot = {}
function bot:GetUnitName() return 'npc_dota_hero_sven' end
function bot:IsInvulnerable() return false end
function bot:IsHero() return true end
function bot:IsAlive() return state.alive end
function bot:IsIllusion() return false end
function bot:GetTeam() return 2 end
function bot:GetLocation() return {} end
local roshan = {}
function roshan:GetUnitName() return 'npc_dota_roshan' end
function roshan:GetHealth() return state.roshHP * 10000 end
function roshan:GetMaxHealth() return 10000 end
function bot:GetNearbyNeutralCreeps() return state.seenRoshan and {roshan} or {} end
local illusion = {IsAlive = function() return true end, IsIllusion = function() return true end}
GetBot = function() return bot end
DotaTime = function() return 1200 end
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
J.IsRoshanCloseToChangingSides = function() return false end
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
state.hp = 0.2
assert(GetDesireHelper() == 0, 'Nearly dead bot should not chase a finishing objective')
GetBot = function() return nil end
assert(pcall(dofile, 'bots/mode_roshan_generic.lua'), 'Mode should handle missing bot')
print('PASS: real Roshan mode readiness changes, recovery, enemy pressure, illusions and finishing urgency')
