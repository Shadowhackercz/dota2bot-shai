-- Integration checks for the real retreat and generated push modules.
package.path = './?.lua;'..package.path
GetScriptDirectory = function() return 'bots' end
BOT_MODE_DESIRE_NONE, BOT_MODE_DESIRE_HIGH, BOT_MODE_DESIRE_ABSOLUTE = 0, 0.7, 1
BOT_MODE_DESIRE_VERYHIGH, BOT_MODE_DESIRE_MODERATE = 0.8, 0.5
BOT_MODE_NONE, BOT_MODE_ROSHAN, BOT_MODE_ITEM, BOT_MODE_EVASIVE_MANEUVERS = 0, 1, 2, 3
UNIT_LIST_ALL, TEAM_NEUTRAL, TEAM_NONE = 0, 4, 5
GetTeam, GetOpposingTeam = function() return 2 end, function() return 3 end
DotaTime, GameTime = function() return 1200 end, function() return 1200 end
Clamp = function(v, lo, hi) return math.max(lo, math.min(hi, v)) end
Min = math.min
RemapValClamped = function(v, a, b, lo, hi) return lo + Clamp((v-a)/(b-a), 0, 1)*(hi-lo) end
GetUnitList, GetDroppedItemList, GetTeamPlayers = function() return {} end, function() return {} end, function() return {} end
local state = {hp = 0.6, fountain = true, fight = true, rLevel = 0, rCost = 100, mana = 250}
local ultimate = {}
function ultimate:GetLevel() return state.rLevel end
function ultimate:GetCooldownTimeRemaining() return 0 end
function ultimate:GetManaCost() return state.rCost end
local bot = {}
function bot:GetActiveMode() return BOT_MODE_NONE end
function bot:GetActiveModeDesire() return 0.9 end
function bot:IsAlive() return true end
function bot:GetUnitName() return 'npc_dota_hero_skeleton_king' end
function bot:HasModifier(name) return name == 'modifier_fountain_aura_buff' and state.fountain end
function bot:GetNearbyTowers() return {} end
function bot:GetNearbyLaneCreeps() return {} end
function bot:GetNearbyCreeps() return {} end
function bot:GetLocation() return {} end
function bot:GetLevel() return 8 end
function bot:GetHealth() return state.hp * 1000 end
function bot:GetMaxHealth() return 1000 end
function bot:GetHealthRegen() return 0 end
function bot:GetManaRegen() return 0 end
function bot:GetMana() return state.mana end
function bot:GetMaxMana() return 500 end
function bot:GetAbilityByName() return ultimate end
function bot:DistanceFromFountain() return 5000 end
function bot:WasRecentlyDamagedByAnyHero() return false end
function bot:GetAssignedLane() return 2 end
function bot:GetAttackTarget() return nil end
GetBot = function() return bot end
local ancient = {GetLocation = function() return {} end}
GetAncient = function() return ancient end
local no = function() return false end
local J = {Utils = {}}
J.GetModifierTime = function() return 0 end
J.GetHP = function(u) return u == bot and state.hp or 1 end
J.GetMP = function() return 1 end
J.GetProperTarget = function() return nil end
J.WeAreStronger = function() return true end
J.IsInTeamFight = function() return state.fight end
J.GetNearbyHeroes = function() return {} end
J.GetCurrentRoshanLocation = function() return {} end
J.IsTargetedByEnemyWithModifier, J.IsValid = no, no
J.IsInLaningPhase = function() return true end
J.GetHeroesTargetingUnit = function() return {} end
J.CanCastAbility = no
J.IsValidBuilding = no
package.loaded['bots/FunLib/jmz_func'] = J
package.loaded['bots/Customize/general'] = {Enable = true, ThinkLess = 1}
local retreat = dofile('bots/mode_retreat_generic.lua')
assert(GetDesireHelper() > 0, 'Untrained reincarnation should not suppress recovery')
state.rLevel, state.mana = 1, 150
assert(GetDesireHelper() == 0, 'Ready reincarnation with sufficient actual mana should permit fighting')
state.rCost = 200
assert(GetDesireHelper() > 0, 'Insufficient reincarnation mana should not suppress recovery')
state.rCost, state.mana = 0, 0
assert(GetDesireHelper() == 0, 'Free reincarnation should be usable without mana')
state.rLevel, state.hp, state.fountain, state.fight = 0, 1, false, false
retreat.ShouldRun, retreat.ConsiderCompleteItem, retreat.RetreatWhenTowerTargetedDesire = function() return 0 end,
    function() return 0 end, function() return 0 end
assert(GetDesireHelper() == 0, 'Safe healthy bot must not return negative retreat desire')

-- Push caps must survive defense and allied attack pings.
local enums = {Lane = {Top=1, Mid=2, Bot=3}, Team = {Radiant=2},
    BotMode = {PushTowerTop=10, PushTowerMid=11, PushTowerBot=12},
    BotModeDesire = {None=0, ExtraLow=0.02, VeryLow=0.1}}
package.loaded['bots/ts_libs/dota/index'] = enums
package.loaded['bots/FunLib/utils'] = {GetLocationToLocationDistance = function() return state.highground and 1000 or 8000 end}
local game = {team=2, enemyTeam=3, ourAncient=ancient, enemyAncient=ancient,
    aliveAllyCount=5, aliveEnemyCount=3, aliveAllyCoreCount=3, aliveEnemyCoreCount=2,
    isEarlyGame=false, isMidGame=true, isLaningPhase=false, currentTime=1200,
    teamNetworth=40000, enemyNetworth=20000, averageLevel=15}
package.loaded['bots/FunLib/global_cache'] = {
    getGlobalGameState = function() return game end,
    getGlobalLocationState = function() return {} end,
    getCachedAlliesNearLoc = function() return state.highground and {bot, {}} or {bot, {}, {}} end,
    getCachedEnemiesNearLoc = function() return {} end, autoCleanupCache = function() end}
J.Utils.CountEnemyHeroesNear = function() return 0 end
J.Utils.GameStates = {defendPings = {pingedTime = 0}}
J.Utils.NumHumanBotPlayersInTeam = function() return 0 end
J.Utils.GetAllyIdsInTpToLocation = function() return {} end
J.IsCore = function() return true end
J.IsLateGame = no
J.IsDoingRoshan, J.IsDoingTormentor = no, no
J.GetAlliesNearLoc = function() return {} end
J.GetEnemiesAroundLoc = function() return state.baseThreat and 1 or 0 end
J.IsDefending = function() return state.defending end
J.GetHumanPing = function() return state.ping and bot or nil, state.ping and {normal_ping=false, time=1200} or nil end
J.IsPingCloseToValidTower = function() return true, 2 end
J.GetAverageLevel = function() return 13 end
J.IsValidBuilding, J.CanBeAttacked = no, no
GetLaneFrontLocation = function() return {} end
GetUnitToUnitDistance = function() return 8000 end
local push = dofile('bots/FunLib/aba_push.lua')
-- Objective selection/cooldown details are independent from the cap regressions.
push.WhichLaneToPush = function() return 2 end
push.ShouldWaitForImportantItemsSpells = function() return false end
state.hp, state.ping, state.defending = 0.3, true, true
assert(push.GetPushDesireHelper(bot, 2) <= 0.25, 'Defense and human ping must preserve wounded cap')
state.hp, state.highground, state.defending = 1, true, false
assert(push.GetPushDesireHelper(bot, 2) <= 0.08, 'Human ping must preserve unsafe high ground cap')
state.hp, state.highground, state.ping, state.baseThreat = 0.3, false, false, true
assert(push.GetPushDesireHelper(bot, 2) <= 0.25, 'Base threat adjustment must not raise wounded cap')
state.hp, state.baseThreat, state.ping = 1, false, true
assert(push.GetPushDesireHelper(bot, 2) > 0.5, 'Healthy grouped bot should still respond to a safe attack ping')
print('PASS: real retreat readiness and real push health/high ground caps under defense, pings and base threats')
