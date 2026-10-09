package.path = './?.lua;'..package.path
GetScriptDirectory = function() return 'bots' end
GAME_STATE_GAME_IN_PROGRESS, BOT_MODE_RETREAT, UNIT_LIST_ALLIED_HEROES = 7, 4, 1
local now, nearbyEnemy, damage, available = 1000, false, true, true
local replies = {}
local function Hero(id, core)
    local h = {hp=0.9, alive=true, distance=1000, core=core}
    function h:IsNull() return false end
    function h:IsHero() return true end
    function h:IsIllusion() return false end
    function h:IsAlive() return self.alive end
    function h:GetPlayerID() return id end
    function h:GetTeam() return 2 end
    function h:GetUnitName() return 'npc_dota_hero_sven' end
    function h:IsInvulnerable() return false end
    function h:GetNearbyNeutralCreeps() return {} end
    function h:GetLocation() return {} end
    function h:GetLevel() return 15 end
    function h:GetActiveMode() return 1 end
    function h:ActionImmediate_Chat(message, all) assert(all == false); table.insert(replies, message) end
    function h:GetAttackDamage() return self.core and 600 or 100 end
    function h:GetSecondsPerAttack() return 1 end
    h.shaiRoshanCheck = function() return 0.7 end
    return h
end
local human, a, b = Hero(0, true), Hero(1, true), Hero(2, false)
local units = {human,a,b}
GetUnitList = function() return units end
GetGameState = function() return 7 end
GetTeamForPlayer = function(id) return id == 9 and 3 or 2 end
IsPlayerBot = function(id) return id ~= 0 and id ~= 9 end
DotaTime = function() return now end
GetAncient = function() return {} end
GetUnitToLocationDistance = function(h) return h.distance end
local J = {IsRoshanAlive=function() return available end,
    GetEnemiesAroundAncient=function() return 0 end,
    GetHP=function(h) return h.hp or 1 end,
    IsRoshanCloseToChangingSides=function() return false end,
    GetNumOfAliveHeroes=function() return 5 end,
    GetCurrentRoshanLocation=function() return {} end,
    GetEnemiesNearLoc=function() return nearbyEnemy and {{}} or {} end,
    GetLastSeenEnemiesNearLoc=function() return {} end,
    IsCore=function(h) return h.core end,
    HasEnoughDPSForRoshan=function(list) assert(#list == 3); return damage end}
J.GetProperTarget=function() return nil end
local commands = require('bots/FunLib/shai_roshan_commands')
local function Send(text, id)
    for _, bot in ipairs({a,b}) do commands.Handle(bot,J,{string=text,player_id=id or 0,team_only=true}) end
end
Send('roshan'); assert(#replies == 0)
Send('!roshan', 9); assert(#replies == 0)
Send('  !ROSHAN  ')
assert(#replies == 1 and replies[1]:find('Yes'))
assert(a.shaiRoshanRequestUntil == now+30 and b.shaiRoshanRequestUntil == now+30)
assert(commands.RequestSafe(a,J))
Send('!rosh'); assert(#replies == 1, 'cooldown must prevent repeated answers')
nearbyEnemy = true
assert(not commands.RequestSafe(a,J), 'new enemy must cancel request')
now = now+9; Send('!rosh'); assert(replies[2]:find('enemies'))
nearbyEnemy = false
b.alive = false; assert(not commands.RequestSafe(a,J))
b.alive = true; b.hp = 0.3; assert(not commands.RequestSafe(a,J))
b.hp = 0.9; damage = false
assert(not commands.RequestSafe(a,J))
now = now+9; Send('!roshan'); assert(replies[3]:find('damage'))
damage = true; now = now+31; assert(not commands.RequestSafe(a,J), 'request must expire')
available = false; Send('!roshan'); assert(replies[4]:find('not available'))
available = true; a.alive = false; now = now+9
Send('!roshan'); assert(#replies == 5 and replies[5]:find('healthy allies'), 'one new leader after death')
local estimate = require('bots/FunLib/shai_roshan_damage')
local reduce = function() return 0 end
local ready, total = estimate.Ready({human,a,b},1000,reduce)
local _, one = estimate.Ready({human},1000,reduce)
assert(ready and total > one, 'damage must be summed, not averaged')
local _, withSupport = estimate.Ready({human,b},1000,reduce)
assert(withSupport > one, 'adding support must not reduce team damage')
assert(not estimate.Ready({},1000,reduce))
-- Run the actual objective mode: accepted chat raises priority, safety remains first.
a.alive, available, damage, nearbyEnemy = true, true, true, false
BOT_MODE_DESIRE_NONE, BOT_ACTION_DESIRE_NONE = 0, 0
BOT_MODE_DESIRE_MODERATE, BOT_MODE_DESIRE_ABSOLUTE = 0.5, 1
J.Utils = {IsTeamPushingSecondTierOrHighGround=function() return false end,
    IsValidUnit=function(h) return h ~= nil end, CountBackpackEmptySpace=function() return 6 end}
J.CheckTimeOfDay=function() return 'day' end
J.GetTeamFightLocation=function() return nil end
J.GetHumanPing=function() return nil,nil end
package.loaded['bots/FunLib/jmz_func'] = J
package.loaded['bots/Customize/general'] = {}
GetBot=function() return a end
GetRoshanDesire=function() return 0.4 end
Clamp=function(v,low,high) return math.max(low,math.min(high,v)) end
RemapValClamped=function(v,low,high,a,b) return a+Clamp((v-low)/(high-low),0,1)*(b-a) end
dofile('bots/mode_roshan_generic.lua')
a.shaiRoshanRequestUntil, a.shaiRoshanParticipants = nil,nil
assert(GetDesireHelper() == 0.4)
now=now+9; Send('!roshan')
assert(GetDesireHelper() == 0.95, 'chat must actually raise Roshan mode priority')
nearbyEnemy=true
assert(GetDesireHelper() == 0, 'request must not override enemy danger')
nearbyEnemy=false; a.hp=0.3
assert(GetDesireHelper() == 0, 'request must not override recovery')
a.hp=0.9; now=now+31
assert(GetDesireHelper() < 0.95, 'expired chat must restore normal priority')
assert(loadfile('bots/FunLib/jmz_func.lua'))
assert(loadfile('bots/ability_item_usage_generic.lua'))
local protectedRoshan={IsNull=function() return false end,CanBeSeen=function() return true end,
    IsAlive=function() return true end,GetUnitName=function() return 'npc_dota_roshan' end,
    IsInvulnerable=function() return true end}
a.GetNearbyNeutralCreeps=function() return {protectedRoshan} end
now=now+9; Send('!roshan')
assert(replies[#replies]:find('cannot be attacked'),'Chat must not summon a team to a visible unattackable objective')
a.shaiRoshanRequestUntil=now+30; a.shaiRoshanParticipants={human,a,b}
assert(not commands.RequestSafe(a,J),'An accepted request must be rechecked against attackability')
print('PASS: one Roshan reply, request expiry/reassessment, enemy filtering, leader failover, summed damage and objective attackability')
