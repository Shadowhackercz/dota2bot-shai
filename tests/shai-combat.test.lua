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
function bot:HasModifier(m) return m=='modifier_skeleton_king_reincarnation_scepter_active' and state.ghost or false end
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
state.ghost=true
check('temporary ghost must not reserve mana for a nonexistent next reincarnation', function() assert(not wk.ShouldSaveMana(ability)) end)
state.ghost=false
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
-- Actual Lion ability dispatch: ready control must precede offensive drain.
function bot:IsChanneling() return false end
function bot:Action_ClearActions() end
function bot:GetTeam() return 2 end
function bot:GetAttackTarget() return enemy end
function enemy:GetTeam() return state.allied and 2 or 3 end
function enemy:CanBeSeen() return state.visible ~= false end
J.GetAlliesNearLoc = function() return {} end
J.IsItemAvailable = function() return nil end
J.SetReportMotive = function() end
J.IsAttacking = function() return state.attacking == true end
J.IsGoingOnSomeone = function() return state.engaging == true end
J.IsRetreating = function() return state.retreating == true end
J.IsSuspiciousIllusion = function() return state.illusion == true end
J.IsDisabled = function() return state.disabled == true end
J.IsTaunted = no
J.CanCastOnNonMagicImmune = function() return state.immune ~= true end
J.CanCastOnTargetAdvanced = function() return state.blocked ~= true end
J.GetProperTarget = function() return state.properTarget and enemy or nil end
function bot:ActionQueue_UseAbilityOnEntity(_, target) state.cast = 'entity'; state.castTarget = target end
function bot:ActionQueue_UseAbilityOnLocation(_, target) state.cast = 'location'; state.castTarget = target end
-- Other considerations are deliberately eligible, to expose order conflicts.
lion.ConsiderE = function() state.consideredDrain = true; return 0.8, enemy end
lion.ConsiderQ, lion.ConsiderR = function() return 0 end, function() return 0 end
state.engaging, state.properTarget = true, true
local function lionDecision()
    state.cast, state.castTarget, state.consideredDrain = nil, nil, false
    lion.SkillsComplement()
end
check('Lion should Hex before eligible Mana Drain on engagement', function()
    lionDecision(); assert(state.castTarget == enemy and not state.consideredDrain)
end)
state.engaging, state.properTarget, state.attacking = false, false, true
check('Lion should Hex its actual hero attack target outside offensive modes', function()
    lionDecision(); assert(state.castTarget == enemy and not state.consideredDrain)
end)
local function rejectOpening(name, field, value)
    state[field] = value
    check(name, function() lionDecision(); assert(state.consideredDrain, 'Opening Hex must yield to remaining spell decisions') end)
    state[field] = nil
end
rejectOpening('Lion must not chase with opening Hex outside cast range', 'distance', 700)
state.distance = 550
rejectOpening('Lion must not open Hex on a disabled target', 'disabled', true)
rejectOpening('Lion must not open Hex on an illusion', 'illusion', true)
rejectOpening('Lion must not open Hex on an unseen target', 'visible', false)
rejectOpening('Lion must not open Hex on immune target', 'immune', true)
rejectOpening('Lion must respect targeted spell protection', 'blocked', true)
rejectOpening('Lion must not open an engagement while retreating', 'retreating', true)
rejectOpening('Lion must not Hex an allied target', 'allied', true)
state.qReady = false
check('Lion must not open with unavailable Hex', function()
    lionDecision(); assert(state.consideredDrain)
end)
state.qReady = true
state.attacking = false
check('Lion must not Hex a hero just because it is nearby', function()
    lionDecision(); assert(state.consideredDrain)
end)
state.attacking = true
function ability:IsTrained() return state.aoe == true end
state.aoe = true
check('Lion AoE Hex talent must use a location action', function()
    lionDecision(); assert(state.cast == 'location' and not state.consideredDrain)
end)
state.aoe = false
-- Keep the existing short gap after an Impale command; no immediate CC stacking.
state.attacking = false
lion.ConsiderE = function() return 0 end
lion.ConsiderQ = function() return 0.8, {} end
lionDecision()
lion.ConsiderQ = function() return 0 end
lion.ConsiderE = function() state.consideredDrain = true; return 0.8, enemy end
state.attacking = true
check('Lion must not immediately stack opening Hex after Impale', function()
    lionDecision(); assert(state.consideredDrain)
end)
DotaTime = function() return 101 end
check('Lion opening Hex must become eligible after the Impale command gap', function()
    lionDecision(); assert(not state.consideredDrain)
end)
J.CanNotUseAbility = function() return true end
check('Lion must preserve the existing busy/silenced/queued-action guard', function()
    lionDecision(); assert(state.cast == nil and not state.consideredDrain)
end)
J.CanNotUseAbility = no
-- Take Aim decisions use the actual Sniper module, independently of other spells.
Vector = function(x,y,z) return {x=x,y=y,z=z} end
GetHeightLevel = function() return 0 end
function bot:IsDisarmed() return false end
function bot:GetAttackTarget() return enemy end
function bot:GetAttackRange() return 1000 end
function bot:GetAttackDamage() return 100 end
function enemy:IsAttackImmune() return false end
function enemy:IsStunned() return false end
function enemy:GetCurrentMovementSpeed() return 300 end
function enemy:IsFacingLocation() return state.approaching == true end
J.IsAttacking = function() return state.attacking ~= false end
J.IsRetreating = function() return state.retreating == true end
J.GetHP = function() return state.hp or 1 end
J.IsSuspiciousIllusion = no
local sniper = dofile('bots/BotLib/hero_sniper.lua')
state.distance = 400
check('Sniper must not use Take Aim next to an enemy', function() assert(sniper.ConsiderE() == 0) end)
state.distance, state.approaching = 700, true
check('Sniper must not use Take Aim against an approaching enemy', function() assert(sniper.ConsiderE() == 0) end)
state.distance = 900
check('Sniper should use Take Aim with enough approach buffer', function() assert(sniper.ConsiderE() > 0) end)
state.distance, state.approaching = 800, false
check('Sniper should use Take Aim at a safe distance', function() assert(sniper.ConsiderE() > 0) end)
state.hp = 0.4
check('Wounded Sniper must not use Take Aim', function() assert(sniper.ConsiderE() == 0) end)
state.hp, state.retreating = 1, true
check('Retreating Sniper must not use Take Aim', function() assert(sniper.ConsiderE() == 0) end)
state.retreating, state.attacking = false, false
check('Sniper must already be attacking before Take Aim', function() assert(sniper.ConsiderE() == 0) end)
state.attacking = true
local closeEnemy = setmetatable({}, {__index=enemy})
J.GetNearbyHeroes = function() return {enemy, closeEnemy} end
GetUnitToUnitDistance = function(_, target) return target == closeEnemy and 400 or state.distance end
check('A second close enemy must prevent Take Aim against a distant target', function() assert(sniper.ConsiderE() == 0) end)
for _, failure in ipairs(failures) do print('FAIL: '..failure) end
assert(#failures == 0, tostring(#failures)..' combat regressions failed')
print('PASS: real Wraith King mana reservation, interrupts, Lion engagement dispatch and Sniper Take Aim safety')
