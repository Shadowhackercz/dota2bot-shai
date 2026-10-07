-- Real hero modules, with only engine/helper dependencies mocked.
package.path = './?.lua;'..package.path
GetScriptDirectory = function() return 'bots' end
BOT_ACTION_DESIRE_NONE, BOT_ACTION_DESIRE_HIGH = 0, 0.8
BOT_MODE_NONE, BOT_MODE_LANING, BOT_MODE_RETREAT, BOT_MODE_ROSHAN = 0, 1, 2, 3
DAMAGE_TYPE_MAGICAL, DAMAGE_TYPE_PHYSICAL = 1, 2
DotaTime = function() return 100 end
local state = {qReady = false, rLevel = 0, rCooldown = 0, rCost = 200, mana = 150, distance = 700}
local ability = {}
function ability:IsFullyCastable() return state.qReady end
function ability:GetLevel() return 1 end
function ability:GetCastRange() return 600 end
function ability:GetCastPoint() return 0.2 end
function ability:GetManaCost() return 80 end
function ability:GetAbilityDamage() return 100 end
function ability:GetSpecialValueInt() return 100 end
function ability:IsTrained() return false end
function ability:IsHidden() return false end
function ability:GetName() return 'spell' end
local ultimate = {}
function ultimate:GetLevel() return state.rLevel end
function ultimate:GetCooldownTimeRemaining() return state.rCooldown end
function ultimate:GetManaCost() return state.rCost end
local bot = {}
function bot:GetAbilityByName(name) return name == 'skeleton_king_reincarnation' and ultimate or ability end
function bot:GetLevel() return 8 end
function bot:GetMana() return state.mana end
function bot:GetMaxMana() return 500 end
function bot:GetHealth() return 900 end
function bot:GetMaxHealth() return 1000 end
function bot:IsInvisible() return false end
function bot:GetActiveMode() return BOT_MODE_NONE end
function bot:WasRecentlyDamagedByAnyHero() return false end
function bot:GetLocation() return {} end
function bot:HasModifier() return false end
function bot:ActionQueue_UseAbilityOnEntity() end
local enemy = {}
function enemy:IsChanneling() return true end
function enemy:IsCastingAbility() return false end
function enemy:GetLocation() return {} end
function enemy:IsFacingLocation() return false end
function enemy:GetAttackRange() return 150 end
GetBot = function() return bot end
GetUnitToUnitDistance = function() return state.distance end
local no = function() return false end
local J = {Skill = {}, Item = {}, Role = {}, Chat = {GetNormName = function() return 'enemy' end}}
J.Skill.GetTalentList = function() return {'t1','t2','t3','t4','t5','t6','t7','t8'} end
J.Skill.GetAbilityList = function() return {'q','w','e','d','f','r'} end
J.Skill.GetRandomBuild = function(builds) return builds[1] end
J.Skill.GetTalentBuild = function() return {} end
J.Skill.GetSkillList = function() return {} end
J.Item.GetRoleItemsBuyList = function() return 'pos_1' end
J.Role.IsPvNMode, J.Role.IsAllShadow = no, no
J.SetUserHeroInit = function(...) return ... end
J.CanNotUseAbility, J.IsInTeamFight, J.IsGoingOnSomeone, J.IsRetreating = no, no, no, no
J.IsFarming, J.IsPushing, J.IsDefending, J.IsDoingRoshan, J.CanKillTarget = no, no, no, no, no
J.IsValid, J.IsValidHero, J.CanCastOnNonMagicImmune, J.CanCastOnTargetAdvanced = function(u) return u ~= nil end,
    function(u) return u ~= nil end, function() return true end, function() return true end
J.GetNearbyHeroes = function(_, range) return state.distance <= range and {enemy} or {} end
J.IsInRange = function(_, _, range) return state.distance <= range end
J.GetProperTarget = function() return nil end
J.GetHP = function() return 1 end
J.SetQueuePtToINT = function() end
package.loaded['bots/FunLib/jmz_func'] = J
local actualDofile = dofile
dofile = function(path)
    if path == 'bots/FunLib/aba_minion' then return {} end
    return actualDofile(path)
end
local wk = dofile('bots/BotLib/hero_skeleton_king.lua')
wk.SkillsComplement() -- initialize cached level/mana, with Q unavailable
local failures = {}
local function check(name, run)
    local ok, err = pcall(run)
    if not ok then table.insert(failures, name..': '..tostring(err)) end
end
check('untrained reincarnation must not reserve mana', function()
    assert(not wk.ShouldSaveMana(ability))
end)
state.rLevel = 1
check('trained ready reincarnation must reserve mana', function() assert(wk.ShouldSaveMana(ability)) end)
state.rCost = 0
check('free reincarnation must not reserve mana', function() assert(not wk.ShouldSaveMana(ability)) end)
state.rCost, state.rCooldown = 200, 20
check('distant cooldown must not reserve mana', function() assert(not wk.ShouldSaveMana(ability)) end)
state.qReady = true
check('Wraith King must not chase an out of range interrupt', function() assert(wk.ConsiderQ() == 0) end)
state.distance = 550
check('Wraith King should interrupt in range', function() assert(wk.ConsiderQ() > 0) end)
state.distance = 700
local lion = dofile('bots/BotLib/hero_lion.lua')
check('Lion must not chase an out of range interrupt', function() assert(lion.ConsiderW() == 0) end)
state.distance = 550
check('Lion should interrupt in range', function() assert(lion.ConsiderW() > 0) end)
for _, failure in ipairs(failures) do print('FAIL: '..failure) end
assert(#failures == 0, tostring(#failures)..' combat regressions failed')
print('PASS: real Wraith King mana reservation and Wraith King/Lion interrupt decisions')
