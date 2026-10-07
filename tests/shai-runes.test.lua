package.path = './?.lua;'..package.path
local originalPrint = print
print = function(first, ...)
    if type(first) == 'string' and first:sub(1,6) == '[SHAI]' then return end
    originalPrint(first, ...)
end
GetScriptDirectory = function() return 'bots' end
TEAM_RADIANT, TEAM_DIRE = 2, 3
RUNE_BOUNTY_1, RUNE_BOUNTY_2, RUNE_POWERUP_1, RUNE_POWERUP_2 = 0, 1, 2, 3
RUNE_STATUS_MISSING, RUNE_STATUS_AVAILABLE, RUNE_STATUS_UNKNOWN = 0, 1, 2
RUNE_WATER = 10
RUNE_HASTE = 11
BOT_MODE_DESIRE_NONE, BOT_MODE_DESIRE_HIGH, BOT_MODE_DESIRE_MODERATE = 0, 0.7, 0.5
BOT_ACTION_TYPE_IDLE, BOT_ACTION_TYPE_PICK_UP_RUNE, BOT_MODE_NONE = 0, 2, 0
DAMAGE_TYPE_ALL, DAMAGE_TYPE_PHYSICAL = 0, 1
local state = {}
Vector = function(x,y,z) return {x=x,y=y,z=z} end
DotaTime, GameTime = function() return state.time end, function() return state.time end
GetTeam = function() return TEAM_RADIANT end
GetRuneSpawnLocation = function(id) return {id=id} end
GetRuneStatus = function(id) return id == state.rune and state.status or RUNE_STATUS_MISSING end
GetRuneType = function() return state.time < 360 and RUNE_WATER or RUNE_HASTE end
Clamp = function(v,lo,hi) return math.max(lo,math.min(hi,v)) end
RemapValClamped = function(v,a,b,lo,hi) return lo+Clamp((v-a)/(b-a),0,1)*(hi-lo) end
local bot, human = {}, {}
local support = {IsBot=function() return true end}
function bot:GetLevel() return state.time >= 420 and 30 or 5 end -- isolate normal runes from Wisdom
function bot:GetUnitName() return 'npc_dota_hero_zuus' end
function bot:FindItemSlot() return state.bottle and 0 or -1 end
function bot:GetActiveMode() return BOT_MODE_NONE end
function bot:GetActiveModeDesire() return 0 end
function bot:GetAssignedLane() return 2 end
function bot:GetNearbyHeroes(_, enemy) return enemy and state.enemies or {} end
function bot:IsInvulnerable() return false end
function bot:WasRecentlyDamagedByAnyHero() return state.damaged end
function bot:GetCurrentActionType() return state.idle and BOT_ACTION_TYPE_IDLE or 1 end
function bot:IsAlive() return state.alive end
function bot:IsBot() return true end
function human:IsAlive() return true end
function human:IsBot() return false end
function human:GetMostRecentPing()
    return state.pingTime and {normal_ping=true, time=state.pingTime, location=GetRuneSpawnLocation(state.rune)} or nil
end
function human:IsFacingLocation() return state.claim end
function human:GetCurrentActionType() return state.claim and BOT_ACTION_TYPE_PICK_UP_RUNE or 1 end
function human:GetEstimatedDamageToTarget() return state.incoming end
function bot:GetHealth() return state.hp * 1000 end
function bot:GetAttackRange() return 600 end
function bot:GetAttackDamage() return 80 end
function bot:GetLocation() return {} end
function bot:GetNearbyCreeps() return {} end
function bot:GetNearbyLaneCreeps() return state.lastHit and {{}} or {} end
function bot:GetEstimatedDamageToTarget(_, target, _, damageType)
    assert(target == human, 'Rune fight estimated damage against self')
    return damageType == DAMAGE_TYPE_PHYSICAL and 40 or 200
end
function bot:Action_PickUpRune(id) state.action = 'pickup'; state.picked = id end
function bot:Action_MoveToLocation() state.action = 'move' end
function bot:Action_AttackUnit(unit) assert(unit == human); state.action = 'attack' end
GetBot = function() return bot end
GetTeamMember = function(i)
    return i==1 and bot or (i==2 and state.human and human or (i==3 and state.support and support or nil))
end
GetTeamPlayers = function() return state.human and {0,1} or {0} end
GetUnitToLocationDistance = function(unit,loc)
    return loc.id==state.rune and (unit==bot and state.distance or (unit==support and 200 or state.humanDistance)) or 5000
end
GetAncient = function() return {GetLocation=function() return {} end} end
local J = {Utils = {IsTeamPushingSecondTierOrHighGround=function() return state.pushing end,
    CountEnemyHeroesNear=function() return state.baseThreat and 1 or 0 end}}
J.GetHP, J.GetMP, J.GetPosition = function() return state.hp end, function() return state.mp end, function() return 2 end
J.IsCore = function(u) return u ~= support end
J.IsEarlyGame = function() return true end
J.IsValidHero = function(unit) return unit~=nil end
J.IsSuspiciousIllusion = function() return false end
J.GetAlliesNearLoc = function() return state.support and {bot, support} or {bot} end
J.GetEnemiesNearLoc = function() return state.enemies end
J.GetLastSeenEnemiesNearLoc = function() return state.recentEnemies or {} end
J.GetDistance = function(a,b) return a.id == b.id and 0 or 5000 end
J.IsValid, J.CanBeAttacked = function(u) return u ~= nil end, function(u) return u ~= nil end
J.WillKillTarget = function() return state.lastHit end
J.GetAttackProDelayTime = function() return 0.3 end
J.CanNotUseAction = function() return false end
J.IsLateGame = function() return false end
J.GetDistanceFromEnemyFountain = function() return 9000 end
package.loaded['bots/FunLib/jmz_func'] = J
package.loaded['bots/Customize/general'] = {Enable=true,ThinkLess=1}
local function setup(changes)
    state = {rune=RUNE_POWERUP_2, idle=false, human=false, claim=false, hp=1, alive=true,
        time=121, distance=40, humanDistance=1500, status=RUNE_STATUS_AVAILABLE,
        bottle=true, incoming=100, enemies={}, lastHit=false, damaged=false, mp=1}
    for key, value in pairs(changes or {}) do state[key] = value end
    bot.rune = nil
    dofile('bots/mode_rune_generic.lua')
end
setup()
assert(GetDesire() > 0, 'Second water rune spot must not be blocked')
Think(); assert(state.action == 'pickup' and state.picked == state.rune)
for _, time in ipairs({121, 241, 361, 481}) do
    for _, rune in ipairs({RUNE_POWERUP_1, RUNE_POWERUP_2}) do
        setup({time=time, rune=rune})
        assert(GetDesire() > 0, 'Both river spots must work through the first ten minutes')
        Think(); assert(state.action == 'pickup')
    end
end
setup({rune=RUNE_POWERUP_1, idle=true})
assert(GetDesire() > 0, 'Idle bot must be able to start rune mode')
setup({bottle=false, distance=1200})
assert(GetDesire() > 0.446, 'Healthy no-Bottle mid must prioritize available rune above early laning')
setup({bottle=false, distance=1200, status=RUNE_STATUS_UNKNOWN, time=110})
assert(GetDesire() > 0.446, 'Healthy no-Bottle mid must prepare above early laning priority')
setup({bottle=false, distance=1200, time=361, enemies={human}, humanDistance=600})
assert(GetDesire() > 0.446, 'No-Bottle mid must prioritize a safe power rune contest')
setup({bottle=false, distance=1200, enemies={human}, incoming=900})
assert(GetDesire() == 0, 'No-Bottle priority boost must not bypass lethal contest safety')
setup({bottle=false, distance=1200, status=RUNE_STATUS_UNKNOWN, time=110, lastHit=true})
assert(GetDesire() == 0, 'No-Bottle priority boost must preserve immediate pre-spawn last hits')
setup({human=true})
assert(GetDesire() > 0, 'Human merely present on mid must not claim a rune')
setup({human=true, distance=1700})
assert(GetDesire() > 0, 'Closer idle human must not enter automatic bot collector assignment')
setup({support=true, distance=800})
assert(GetDesire() > 0, 'Ineligible nearby support must not block eligible mid collector')
setup({human=true, claim=true, humanDistance=100})
assert(GetDesire() == 0, 'Respect clear allied pickup intent')
setup({human=true, pingTime=120})
assert(GetDesire() == 0, 'Respect fresh explicit allied rune ping')
setup({human=true, pingTime=100})
assert(GetDesire() > 0, 'Expired claim must not suppress pickup')
setup({enemies={human}})
assert(GetDesire() > 0, 'Safe 1v1 must not be conceded')
Think(); assert(state.action == 'pickup', 'Secure close rune before attacking')
setup({enemies={human}, distance=800, humanDistance=600})
assert(GetDesire() > 0, 'Nearby enemy must not veto a winnable contest')
Think(); assert(state.action == 'attack', 'Reasonable distant contest should fight using enemy damage estimate')
setup({enemies={human}, distance=800, humanDistance=600, mp=0.1})
assert(GetDesire() > 0)
Think(); assert(state.action == 'move', 'Nearly empty mana must not assume spell damage for fighting')
setup({enemies={human}, incoming=900})
assert(GetDesire() == 0, 'Do not contest lethal incoming damage')
setup({enemies={human}, hp=0.3, damaged=true})
assert(GetDesire() == 0, 'Wounded bot should not contest under pressure')
local secondEnemy = {GetEstimatedDamageToTarget=function() return 100 end}
setup({enemies={human, secondEnemy}})
assert(GetDesire() == 0, 'Do not count self twice and walk into 1v2')
setup({recentEnemies={6,7}})
assert(GetDesire() == 0, 'Recently seen ambush must remain a threat after losing vision')
setup({status=RUNE_STATUS_MISSING, time=110, distance=900})
assert(GetDesire() > 0, 'Prepare before first water spawn')
setup({status=RUNE_STATUS_MISSING, time=110, distance=900, lastHit=true})
assert(GetDesire() == 0, 'Do not lose immediate last hit for unspawned distant rune')
setup({status=RUNE_STATUS_UNKNOWN, time=190})
assert(GetDesire() == 0, 'Do not endlessly scout unknown rune between spawn windows')
setup({status=RUNE_STATUS_UNKNOWN, time=121})
assert(GetDesire() > 0)
state.status = RUNE_STATUS_MISSING
Think()
state.status = RUNE_STATUS_UNKNOWN
assert(GetDesire() == 0, 'Do not revisit a scouted empty spot in the same cycle')
state.status = RUNE_STATUS_AVAILABLE
assert(GetDesire() > 0, 'Newly available rune overrides empty scout memory')
setup({time=121})
assert(GetDesire() > 0)
state.status = RUNE_STATUS_MISSING
Think(); assert(state.action == nil, 'Stop pursuing rune taken after desire was evaluated')
bot.rune.normal.location = -1
assert(pcall(Think), 'Invalid target must not crash Think')
setup({alive=false})
assert(GetDesire() == 0 and pcall(Think), 'Dead bot must not run rune actions')
setup({pushing=true})
assert(GetDesire() == 0, 'Do not abandon high ground push')
setup({baseThreat=true})
assert(GetDesire() == 0, 'Defend ancient before runes')
originalPrint('PASS: real rune mode pickup, human claims, 1v1 contests, danger, spawn preparation, last hits and scout memory')
