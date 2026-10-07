package.path = './?.lua;'..package.path
GetScriptDirectory = function() return 'bots' end
UNIT_LIST_ENEMIES, DAMAGE_TYPE_PHYSICAL = 1, 1
local state = {hp=0.9, distance=400, enemyDistance=400, lethal=false}
local bot, enemy, tomb = {}, {}, {}
function bot:IsDisarmed() return state.disarmed end
function bot:GetAttackRange() return 600 end
function bot:GetAttackDamage() return 100 end
function bot:GetLocation() return {} end
function bot:Action_AttackUnit(target) state.attacked=target end
function tomb:GetUnitName() return 'npc_dota_unit_tombstone4' end
local otherTomb = {GetUnitName=tomb.GetUnitName}
GetUnitList = function() return {otherTomb, tomb} end
GetUnitToUnitDistance = function(_, unit)
    return unit == enemy and state.enemyDistance or (unit == otherTomb and 550 or state.distance)
end
local J = {}
J.CanNotUseAction = function() return false end
J.IsRetreating = function() return state.retreating end
J.GetHP = function() return state.hp end
J.IsValid = function(u) return u ~= nil end
J.IsValidHero = function(u) return u == bot or u == enemy end
J.CanBeAttacked = function(u) return u ~= nil and not state.immune end
J.IsInRange = function(a,b,range) return GetUnitToUnitDistance(a,b) <= range end
J.GetProperTarget = function() return enemy end
J.IsSuspiciousIllusion = function() return false end
J.CanKillTarget = function(target, damage, kind) assert(target==enemy and damage==100 and kind==DAMAGE_TYPE_PHYSICAL); return state.lethal end
J.HasMovableUndyingModifier = function() return state.saved end
J.GetAlliesNearLoc = function() return {bot,bot} end -- no double-counting self
J.GetEnemiesNearLoc = function() return state.outnumbered and {enemy, enemy, bot, {}} or {enemy} end
package.loaded['bots/FunLib/jmz_func'] = J
local units = dofile('bots/FunLib/aba_special_units.lua')
assert(units.GetTombstoneDesire(bot) > 0.9, 'Accessible Tombstone must beat ordinary attack priority')
units.Think(); assert(state.attacked == tomb, 'Choose nearest equally urgent Tombstone')
state.lethal = true
assert(units.GetTombstoneDesire(bot) == 0, 'Let hero attack finish a target killable in one hit')
state.saved = true
assert(units.GetTombstoneDesire(bot) > 0.9, 'Death-prevention target must not look like a secured finish')
state.saved, state.enemyDistance = false, 1000
assert(units.GetTombstoneDesire(bot) > 0.9, 'Do not chase a low-health hero instead of a reachable Tombstone')
state.retreating = true
assert(units.GetTombstoneDesire(bot) == 0, 'Do not interrupt retreat to attack Tombstone')
state.retreating, state.lethal, state.hp = false, false, 0.3
assert(units.GetTombstoneDesire(bot) == 0, 'Low-health bot must not commit')
state.hp, state.distance = 0.9, 1000
GetUnitList = function() return {tomb} end
assert(units.GetTombstoneDesire(bot) == 0, 'Do not pursue a distant Tombstone')
state.distance, state.immune = 400, true
assert(units.GetTombstoneDesire(bot) == 0, 'Do not attack an unavailable Tombstone')
state.immune = false
local enemy2 = {}
J.IsValidHero = function(u) return u == bot or u == enemy or u == enemy2 end
J.GetEnemiesNearLoc = function() return {enemy,enemy2} end
assert(units.GetTombstoneDesire(bot) == 0, 'Do not double-count self and commit into 1v2')
print('PASS: real Tombstone selection, secured finish, protection, range, retreat and threats')
