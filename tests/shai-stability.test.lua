package.path = './?.lua;'..package.path
local Stability = require('bots/FunLib/shai_decision_stability')
local retreat = Stability.NewRetreatGuard()
assert(retreat(0.8, 100, false, true) == 0.8, 'Do not boost entry into retreat')
assert(retreat(0.8, 100.1, true, true) == 0.8)
assert(retreat(0.5, 100.4, true, true) == 0.8, 'Brief drop must not reverse an active retreat')
assert(retreat(0, 100.8, true, true) == 0.8, 'Subsecond loss of threat must not reverse retreat')
assert(retreat(0, 101.01, true, true) == 0, 'Calm situation must release the bounded hold')
assert(retreat(0.7, 102, true, true) == 0.7)
assert(retreat(0.95, 102.1, true, true) == 0.95, 'New danger must apply immediately')
assert(retreat(0, 102.2, true, false) == 0, 'Special exclusions must bypass and clear memory')
assert(retreat(0, 102.3, true, true) == 0)
retreat(0.9, 103, true, true)
assert(retreat(0, 103.1, false, true) == 0, 'Leaving retreat must clear memory')
assert(retreat(0, 103.2, true, true) == 0, 'Re-entry must not use old memory')
assert(retreat(0.6, 104, true, true) == 0.6)
assert(retreat(0, 104.1, true, true) == 0, 'Weak retreat signals must not acquire a hold')
retreat(0.9, 105, true, true)
assert(retreat(0, 1, true, true) == 0, 'Time reset must clear the hold')

local a, b = {alive=true, distance=900}, {alive=true, distance=800}
local valid = function(unit) return unit ~= nil and unit.alive and unit.distance <= 1800 end
local target, untilTime = Stability.SelectTarget(nil, a, -90, 100, valid)
assert(target == a and untilTime == 101.2)
target, untilTime = Stability.SelectTarget(target, a, untilTime, 100.5, valid)
assert(untilTime == 101.2, 'Same target must not renew the lock forever')
target, untilTime = Stability.SelectTarget(target, b, untilTime, 100.6, valid)
assert(target == a, 'Alternating candidate must not instantly change the target')
target, untilTime = Stability.SelectTarget(target, b, untilTime, 101.3, valid)
assert(target == b, 'Fresh target must be allowed after lock expiry')
b.alive = false
target, untilTime = Stability.SelectTarget(target, a, untilTime, 101.4, valid)
assert(target == a, 'Dead target must release immediately')
a.distance = 1900; b.alive = true
target, untilTime = Stability.SelectTarget(target, b, untilTime, 101.5, valid)
assert(target == b, 'Distant target must release immediately')
b.alive = false
assert(Stability.SelectTarget(target, nil, untilTime, 101.6, valid) == nil)
-- Exercise both help branches and the actual Think, so a caller cannot silently
-- overwrite the selected target after the helper returns.
local now, candidate, coreHelp, selected, attacked = 200, a, true, nil, nil
a.alive, a.distance, b.alive = true, 900, true
local bot = {GetUnitName=function() return 'npc_dota_hero_lion' end,
    IsInvulnerable=function() return false end, IsHero=function() return true end,
    IsAlive=function() return true end, IsIllusion=function() return false end,
    GetLocation=function() return {} end, GetActiveMode=function() return 0 end,
    SetTarget=function(_, unit) selected=unit end,
    Action_AttackUnit=function(_, unit) attacked=unit end}
GetBot, GetTeam = function() return bot end, function() return 2 end
GetScriptDirectory = function() return 'bots' end
DotaTime = function() return now end
GetUnitToUnitDistance = function(_, unit) return unit.distance end
BOT_MODE_DESIRE_NONE, BOT_MODE_LANING = 0, 1
RemapValClamped = function() return 0.98 end
local no = function() return false end
local J = {Role={IsPvNMode=no}, Utils={IsValidUnit=valid}}
J.IsCore, J.IsValid, J.IsValidHero, J.CanBeAttacked = no, valid, valid, valid
J.CheckBotIdleState, J.CanNotUseAction = no, no
J.GetMostPushLaneDesire, J.GetMostDefendLaneDesire = function() return 2 end, function() return 2 end
J.GetHP = function() return 1 end
J.GetAlliesNearLoc, J.GetEnemiesNearLoc = function() return {} end, function() return {} end
package.loaded['bots/FunLib/jmz_func'] = J
package.loaded['bots/FunLib/utils'] = {SetFrameProcessTime=function() end}
package.loaded['bots/FunLib/enemy_role_estimation'] = {UpdateEnemyHeroPositions=function() end}
for _, name in ipairs({'localization','aba_item','aba_role'}) do package.loaded['bots/FunLib/'..name] = {} end
package.loaded['bots/Customize/general'] = {Enable=true, ThinkLess=1}
local actualDofile = dofile
local specialDesire, tomb = 0, {}
dofile = function(path)
    if path == 'bots/FunLib/aba_special_units' then return {
        GetTombstoneDesire=function() return specialDesire end,
        Think=function() attacked=tomb end} end
    return actualDofile(path)
end
local roam = dofile('bots/mode_team_roam_generic.lua')
roam.ConsiderHelpWhenCoreIsTargeted = function() return candidate, coreHelp end
ConsiderHelpAlly = function() return candidate, true end
ItemOpsDesire, ItemOpsThink = function() end, function() end
roam.CanBeAttacked = valid
local function checkTarget(expected)
    assert(GetDesireHelper() > 0)
    roam.Think()
    assert(selected == expected and attacked == expected, 'Actual roam must use the locked target for both SetTarget and attack')
end
checkTarget(a)
now, candidate = 200.3, b
checkTarget(a)
now, coreHelp = 200.6, false
checkTarget(a) -- second help branch must also preserve the lock
now = 201.3
checkTarget(b)
b.alive, now, candidate = false, 201.4, a
checkTarget(a)
OnEnd()
b.alive, now, candidate = true, 201.5, b
checkTarget(b) -- leaving the mode must clear the old commitment
specialDesire = 0.98
assert(GetDesireHelper() == specialDesire, 'Tombstone must precede an eligible hero-help branch')
roam.Think()
assert(attacked == tomb, 'A prior hero target must not overwrite the selected Tombstone action')
specialDesire = 0
checkTarget(b) -- no stale special-unit flag after yielding to hero combat
print('PASS: bounded retreat stability, immediate danger/exclusions and real team-roam target lock')
