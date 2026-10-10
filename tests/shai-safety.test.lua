-- Engine adapters mocked; real safety modules and real farm/retreat/hero dispatch run.
package.path = './?.lua;'..package.path
GetScriptDirectory = function() return 'bots' end
BOT_MODE_NONE, BOT_MODE_FARM, BOT_MODE_LANING, BOT_MODE_RETREAT = 0, 1, 2, 3
BOT_MODE_EVASIVE_MANEUVERS = 4
BOT_ACTION_DESIRE_NONE, BOT_ACTION_DESIRE_HIGH = 0, 0.8
BOT_MODE_DESIRE_NONE = 0
DAMAGE_TYPE_ALL, DAMAGE_TYPE_MAGICAL, DAMAGE_TYPE_PHYSICAL, ATTRIBUTE_INTELLECT = 0, 1, 2, 3
UNIT_LIST_ENEMY_HEROES=2
Vector = function(x,y,z) return {x=x,y=y,z=z or 0} end
RandomInt = function(a) return a end
GetTeam, GetOpposingTeam = function() return 2 end, function() return 3 end
local state = {now=900, enemies={}, allies={}, mode=BOT_MODE_FARM, recent=false, fight=false, action=nil}
IsLocationPassable = function() return state.passable~=false end
DotaTime, GameTime = function() return state.now end, function() return state.now end
local function hero(name, x)
    local h = {name=name, loc=Vector(x,0,0), hp=1800, maxHp=1800, level=13, dps=100, range=500, int=90, mods={}, visible=true, abilities={}}
    function h:IsNull() return false end
    function h:IsAlive() return self.hp > 0 end
    function h:IsHero() return not self.creep end
    function h:IsIllusion() return self.illusion or false end
    function h:CanBeSeen() return self.visible end
    local function visible(self) assert(self.visible, 'Read hidden enemy state') end
    function h:GetHealth() visible(self); return self.hp end
    function h:GetMaxHealth() visible(self); return self.maxHp end
    function h:GetLevel() visible(self); return self.level end
    function h:GetAttackRange() visible(self); return self.range end
    function h:GetAttackDamage() visible(self); return self.dps end
    function h:GetSecondsPerAttack() visible(self); return 1 end
    function h:GetPlayerID() return self.id or 10 end
    function h:IsBot() return self.team==2 end
    function h:GetCurrentMovementSpeed() visible(self); return 300 end
    function h:GetEstimatedDamageToTarget(ready,_,time) visible(self); assert(ready); return self.dps*time end
    function h:GetUnitName() visible(self); return self.name end
    function h:GetLocation() visible(self); return self.loc end
    function h:GetAttackTarget() visible(self); return self.target end
    function h:IsFacingLocation() visible(self); return true end
    function h:GetFacing() visible(self); return 180 end
    function h:IsStunned() visible(self); return false end
    function h:IsHexed() visible(self); return false end
    function h:IsInvulnerable() return false end
    function h:HasModifier(name) return self.mods[name] == true end
    function h:GetSpellAmp() visible(self); return 0 end
    function h:GetAttributeValue() visible(self); return self.int end
    function h:GetAbilityByName(name) visible(self); return self.abilities[name] end
    function h:IsChanneling() return self.channel or false end
    function h:IsCastingAbility() return false end
    function h:IsUsingAbility() return false end
    function h:IsInvisible() return false end
    function h:IsRooted() return false end
    function h:GetTeam() return self.team or 3 end
    return h
end
local bot = hero('npc_dota_hero_zuus',0); bot.team=2
local silencer = hero('npc_dota_hero_silencer',155); silencer.level=23; silencer.hp=1900; silencer.maxHp=1900
local ally = hero('npc_dota_hero_lion',200); ally.team=2; ally.dps=1200
function bot:WasRecentlyDamagedByHero(enemy) return state.recent and enemy==silencer end
function bot:WasRecentlyDamagedByAnyHero() return state.recent end
function bot:GetActiveMode() return state.mode end
function bot:GetMana() return 900 end
function bot:GetMaxMana() return 1000 end
function bot:GetAttackDamage() return 100 end
function bot:GetActualIncomingDamage(raw) return raw*0.75 end
function bot:SetTarget(target) state.target=target end
function bot:Action_MoveToLocation(loc) state.action='move'; state.location=loc end
function bot:Action_AttackUnit() state.action='attack' end
function bot:ActionQueue_UseAbility(a) state.action=a:GetName() end
function bot:Action_UseAbility(a) state.action=a:GetName() end
function bot:Action_MoveDirectly(loc) state.action='align'; state.location=loc end
function bot:Action_ClearActions() state.action='clear' end
function bot:ActionQueue_UseAbilityOnEntity(a,t) state.action=a:GetName(); state.castTarget=t end
function bot:ActionQueue_UseAbilityOnLocation(a) state.action=a:GetName() end
GetBot = function() return bot end
bot.id=1
GetTeamMember=function(slot) return slot==1 and bot or nil end
GetUnitList=function() return state.enemies end
GetUnitToUnitDistance = function(a,b) return math.abs(a.loc.x-b.loc.x) end
local no = function() return false end
local J = {Utils={}, Skill={}, Item={}, Role={IsPvNMode=no,IsAllShadow=no}}
J.IsValid = function(u) return u~=nil and u.visible and u.hp>0 end
J.IsValidHero = function(u) return J.IsValid(u) and not u.creep end
J.IsSuspiciousIllusion = function(u) return u.illusion==true end
J.GetNearbyHeroes = function(_,_,enemy) return enemy and state.enemies or state.allies end
J.CanNotUseAction = function() return bot.channel or false end
J.CanNotUseAbility = no
J.GetHP = function(h) return h:GetHealth()/h:GetMaxHealth() end
J.GetModifierTime = function(_,name) return bot.mods[name] and (state.protectionTime or 5) or 0 end
J.GetTeamFountain = function() return Vector(-6000,-6000,0) end
J.GetPosition = function() return 1 end
J.IsPosxHuman = function() return true end
J.IsRetreating = function() return state.mode==BOT_MODE_RETREAT end
J.IsInTeamFight = function() return state.fight end
J.WillMagicKillTarget = function(_,target,damage) return damage*0.75>=target.hp end
J.WillKillTarget = function(target,damage) return damage>=target.hp end
J.VectorAway = function(loc,enemy,distance) return Vector(loc.x-distance, loc.y, loc.z) end
J.Utils.NumHumanBotPlayersInTeam = function() return 1,4 end
J.Utils.BuggyHeroesDueToValveTooLazy = {}
J.Utils.IsBotThinkingMeaningfulAction = function() return false end
J.SetQueuePtToINT = function() end
J.IsRunning=function() return true end
J.IsItemAvailable = function() return nil end
J.SetUserHeroInit = function(...) return ... end
J.Skill.GetTalentList = function() return {'t1','t2','t3','t4','t5','t6','t7','t8'} end
J.Skill.GetAbilityList = function() return {'q','w','e','d','as','r'} end
J.Skill.GetRandomBuild = function(builds) return builds[1] end
J.Skill.GetTalentBuild, J.Skill.GetSkillList = function() return {} end, function() return {} end
J.Item.GetRoleItemsBuyList = function() return 'pos_2' end
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/FunLib/utils']=J.Utils
package.loaded['bots/FunLib/version']={}
package.loaded['bots/FunLib/localization']={}
package.loaded['bots/Customize/general']={ThinkLess=0}
require('bots/Customize/shai').BehaviorTrace=false
local Farm = require('bots/FunLib/shai_farm_safety')
local Cast = require('bots/FunLib/shai_cast_safety')
local function fresh() state.now=state.now+1; state.action=nil end
assert(Farm.GetThreat(bot,J)==nil, 'Quiet farm should continue')
state.enemies={silencer}; silencer.dps=450; silencer.target=bot; fresh()
assert(Farm.GetThreat(bot,J)~=nil, 'Dominant visible adjacent enemy must stop farming')
assert(Farm.InterruptFarm(bot,J) and state.action=='move' and state.location.x<bot.loc.x)
state.passable=false; assert(Farm.InterruptFarm(bot,J) and state.action=='clear', 'No legal sampled route must cancel farming instead of reinstating an unsafe rejected destination')
state.passable=true
ally.target=nil; state.allies={ally}; fresh()
assert(Farm.GetThreat(bot,J)~=nil, 'Passing ally is not committed help')
ally.target=silencer; fresh()
assert(Farm.GetThreat(bot,J)==nil, 'Sufficient nearby committed damage can make a fight viable')
state.allies={}; silencer.visible=false; fresh()
assert(Farm.GetThreat(bot,J).memory, 'Remember the previously observed threat without reading hidden stats')
silencer.visible=true; silencer.illusion=true; fresh()
assert(Farm.GetThreat(bot,J)==nil, 'Ignore suspicious illusions')
silencer.illusion=false; fresh(); assert(Farm.GetThreat(bot,J)~=nil)
silencer.visible=false; silencer.loc.x=1200; state.now=state.now+0.3
assert(Farm.GetThreat(bot,J).location.x==155, 'Retain snapshot without following hidden movement')
state.now=state.now+10; assert(Farm.GetThreat(bot,J)==nil, 'Remembered threat must eventually expire')
silencer.visible=true; silencer.loc.x=1300; fresh()
assert(Farm.GetThreat(bot,J)==nil, 'Distant strong visible hero is not an immediate farm retreat')
silencer.loc.x=155; silencer.level=13; silencer.dps=50; fresh()
assert(Farm.GetThreat(bot,J)==nil, 'An ordinary nearby opponent must not make the lane permanently passive')
silencer.level=23; silencer.dps=450
silencer.visible=true; silencer.loc.x=155; fresh()
bot.channel=true; assert(Farm.InterruptFarm(bot,J) and state.action==nil, 'Never cancel a teleport/channel for farm movement')
bot.channel=false; fresh()
local farmModule = dofile('bots/mode_farm_generic.lua')
assert(GetDesire()==0, 'Actual farm desire must yield to danger')
Think(); assert(state.action=='move', 'Actual farm Think must return before creep attacks')
local laneModule = dofile('bots/mode_laning_generic.lua')
PickOneAnnouncer, AnnounceMessages = function() end, function() end
assert(GetDesire()==0, 'Actual lane desire must yield before last hits/default lane actions')
state.action=nil; Think(); assert(state.action=='move', 'Custom lane Think must not overwrite an escape with a last hit')
local retreatModule = dofile('bots/mode_retreat_generic.lua')
assert(GetDesire()==0.96, 'Actual retreat must win over lane/farm desires')
local function ability(name, specials)
    local a={name=name,specials=specials or {}}
    function a:GetName() return self.name end
    function a:GetSpecialValueInt(k) return self.specials[k] or 0 end
    function a:GetSpecialValueFloat(k) return self.specials[k] or 0 end
    function a:GetAbilityDamage() return 200 end
    function a:GetCastPoint() return 0.3 end
    function a:IsTrained() return false end
    function a:IsFullyCastable() return true end
    function a:IsHidden() return false end
    function a:GetManaCost() return 50 end
    return a
end
silencer.abilities.silencer_curse_of_the_silent=ability('curse',{damage=40,penalty_duration=2})
silencer.abilities.silencer_last_word=ability('word',{damage=400,int_multiplier=0})
local q=ability('q',{arc_damage=100}); local w=ability('w'); local e=ability('e',{hop_distance=450,range=800}); local r=ability('r')
bot.abilities={q=q,w=w,e=e,d=ability('d'),as=ability('as'),r=r}
for i=1,8 do bot.abilities['t'..i]=ability('talent') end
local actualDofile=dofile
dofile=function(p) return p=='bots/FunLib/aba_minion' and {} or actualDofile(p) end
-- Safe last-hit remains possible; under recent pressure it yields.
silencer.dps=10; silencer.target=nil; bot.mods.modifier_silencer_curse_of_the_silent=true; fresh()
assert(not Cast.Allow(bot,J,q,'harass'))
assert(not Cast.Allow(bot,J,q,'farm'))
assert(Cast.Allow(bot,J,q,'last-hit'))
state.recent=true; assert(not Cast.Allow(bot,J,q,'last-hit'))
assert(Cast.Allow(bot,J,w,'interrupt') and Cast.Allow(bot,J,e,'escape'))
state.recent=false
bot.mods.modifier_silencer_last_word=true; bot.hp=280; fresh()
assert(not Cast.Allow(bot,J,r,'teamfight') and not Cast.Allow(bot,J,e,'escape'), 'Known fatal Last Word cannot be escaped by casting')
bot.mods.modifier_dazzle_shallow_grave=true
assert(Cast.Allow(bot,J,r,'teamfight'), 'Sufficient death protection permits useful casting')
state.protectionTime=0.1
assert(not Cast.Allow(bot,J,r,'teamfight'), 'Expiring protection cannot cover the cast point')
state.protectionTime=nil
bot.mods.modifier_dazzle_shallow_grave=nil; bot.hp=900; fresh()
assert(Cast.Allow(bot,J,w,'interrupt') and Cast.Allow(bot,J,e,'escape'))
silencer.visible=false; state.now=state.now+16
assert(Cast.Allow(bot,J,e,'escape'), 'Unknown expired cost must not become a fabricated lethal veto')
silencer.visible=true; fresh(); bot.mods.modifier_silencer_last_word=nil
local zeus=dofile('bots/BotLib/hero_zuus.lua')
zeus.ConsiderR, zeus.ConsiderW, zeus.ConsiderW2, zeus.ConsiderQ, zeus.ConsiderD, zeus.ConsiderE =
    function() return 0 end, function() return 0 end, function() return 0 end,
    function() return 0 end, function() return 0 end, function() return 0 end
zeus.ConsiderQ=function() return 0.8,silencer end
fresh(); zeus.SkillsComplement(); assert(state.action==nil, 'Actual Zeus must refuse optional Q harass under Curse')
silencer.hp=50; fresh(); zeus.SkillsComplement(); assert(state.action=='q', 'Actual Zeus keeps secured Q kills')
silencer.hp=1900; silencer.channel=true
zeus.ConsiderQ=function() return 0 end; zeus.ConsiderW=function() return 0.8,silencer end
fresh(); zeus.SkillsComplement(); assert(state.action=='w', 'Actual Zeus retains a useful interrupt')
silencer.channel=false; state.mode=BOT_MODE_RETREAT
silencer.target=bot
zeus.ConsiderE=function() return 0.8 end
zeus.ConsiderR=function() error('Escape should precede damage considerations') end
fresh(); zeus.SkillsComplement(); assert(state.action=='e')
assert(Farm.InterruptFarm(bot,J) and state.action=='e','Farm/roam movement must preserve the just-issued jump')
state.mode=BOT_MODE_FARM; zeus.ConsiderR=function() return 0 end; zeus.ConsiderE=function() return 0 end
local creep=hero('creep',100); creep.creep=true; creep.hp=17
zeus.ConsiderW=function() return 0 end; zeus.ConsiderQ=function() return 0.8,creep end
state.recent=true; fresh(); zeus.SkillsComplement(); assert(state.action==nil, 'Pressured Q last hit must not override cast safety')
state.recent=false; bot.hp=1800; fresh(); zeus.SkillsComplement(); assert(state.action=='q', 'Safe Q last hit survives new guards')
bot.mods={}; silencer.dps=450; silencer.target=bot; fresh()
zeus.SkillsComplement(); assert(state.action==nil, 'Unsafe farming spells must yield even without Curse')
silencer.dps=10; silencer.target=nil; fresh()
local warlock=dofile('bots/BotLib/hero_warlock.lua')
warlock.ConsiderRFR, warlock.ConsiderQ, warlock.ConsiderW, warlock.ConsiderE =
    function() return 0 end,function() return 0 end,function() return 0 end,function() return 0 end
warlock.ConsiderR=function() return 0.8,Vector(0,0,0) end
bot.mods.modifier_silencer_last_word=true; bot.hp=280; fresh()
warlock.SkillsComplement(); assert(state.action==nil, 'Actual Warlock must refuse lethal Last Word ulti')
bot.mods.modifier_silencer_last_word=nil; bot.mods.modifier_silencer_curse_of_the_silent=true; bot.hp=900; fresh()
warlock.SkillsComplement(); assert(state.action=='r', 'Useful team ulti remains permitted under Curse')
warlock.ConsiderR=function() return 0 end; warlock.ConsiderW=function() return 0.8,ally end
fresh(); warlock.SkillsComplement(); assert(state.action=='w', 'Helpful allied heal remains permitted')
warlock.ConsiderW=function() return 0 end; warlock.ConsiderE=function() return 0.8,Vector(0,0,0) end
state.recent=true; fresh(); warlock.SkillsComplement(); assert(state.action==nil, 'Unsafe channel under Curse must yield')
print('PASS: visible farm danger, committed help, fog snapshots, real farm/retreat, Zeus cast purposes/escape and Warlock penalty guards')
