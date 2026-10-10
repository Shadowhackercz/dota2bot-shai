-- Actual hero modules and interrupt policy; engine observations are fixtures.
-- Survival, retreat routing and channel safety have separate integration suites.
package.path = './?.lua;'..package.path
GetScriptDirectory = function() return 'bots' end
BOT_ACTION_DESIRE_NONE, BOT_ACTION_DESIRE_LOW, BOT_ACTION_DESIRE_HIGH, BOT_ACTION_DESIRE_VERYHIGH = 0,.3,.8,.95
BOT_ACTION_DESIRE_MODERATE = .5
BOT_MODE_NONE, BOT_MODE_LANING, BOT_MODE_RETREAT, BOT_MODE_ATTACK = 0,1,2,3
DAMAGE_TYPE_PHYSICAL, DAMAGE_TYPE_MAGICAL, DAMAGE_TYPE_PURE, DAMAGE_TYPE_ALL = 1,2,4,7
UNIT_LIST_ENEMY_HEROES, TEAM_RADIANT, TEAM_DIRE, TEAM_NEUTRAL = 2,2,3,4
local state = {now=900, units={}, mode=0, fight=false, go=false, target=nil, actions={}}
DotaTime, GameTime = function() return state.now end, function() return state.now end
local vectorMeta={__add=function(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end}
Vector = function(x,y,z) return setmetatable({x=x,y=y,z=z or 0},vectorMeta) end
RandomVector=function() return Vector(0,0) end
RandomInt = function(a) return a end
local function no() return false end
local function empty() return {} end
local function distance(a,b) return math.abs(a.x-b.x) end
GetUnitToUnitDistance = function(a,b) return distance(a.loc,b.loc) end
GetUnitToLocationDistance = function(a,b) return distance(a.loc,b) end
local function spell(name)
    local a={name=name, ready=false, trained=false, level=1, range=600, cost=80, special={}}
    function a:GetName() return self.name end
    function a:IsNull() return false end
    function a:IsPassive() return false end
    function a:IsHidden() return false end
    function a:IsActivated() return true end
    function a:IsTrained() return self.trained end
    function a:IsFullyCastable() return self.ready end
    function a:GetLevel() return self.level end
    function a:GetCastRange() return self.range end
    function a:GetManaCost() return self.cost end
    function a:GetCastPoint() return .2 end
    function a:GetChannelTime() return 2 end
    function a:GetSpecialValueInt(k) return self.special[k] or 0 end
    function a:GetSpecialValueFloat(k) return self.special[k] or 0 end
    function a:GetAbilityDamage() return self.damage or 0 end
    function a:GetAOERadius() return self.radius or 250 end
    function a:GetCooldownTimeRemaining() return self.ready and 0 or 30 end
    function a:GetCurrentCharges() return 3 end
    function a:GetToggleState() return false end
    return a
end
local J={Skill={},Item={},Role={},Chat={GetNormName=function(u) return u.name end},Utils={}}
local function unit(name,x,team)
    local u={name=name,loc=Vector(x,0),team=team or 3,hp=1800,maxHp=2000,mana=1500,range=150,mods={},spells={},regen=0}
    function u:IsNull() return false end
    function u:IsAlive() return self.hp>0 end
    function u:IsHero() return not self.creep end
    function u:IsIllusion() return self.illusion or false end
    function u:CanBeSeen() return self.visible~=false end
    function u:IsBot() return self.team==2 end
    function u:GetTeam() return self.team end
    function u:GetPlayerID() return 1 end
    function u:GetUnitName() return self.name end
    function u:GetLocation() return self.loc end
    function u:GetExtrapolatedLocation() return self.loc end
    function u:GetHealth() return self.hp end
    function u:GetMaxHealth() return self.maxHp end
    function u:GetHealthRegen() return self.regen end
    function u:GetMana() return self.mana end
    function u:GetMaxMana() return 1500 end
    function u:GetLevel() return 14 end
    function u:GetAttackDamage() return 100 end
    function u:GetAttackRange() return self.range end
    function u:GetOffensivePower() return 300 end
    function u:GetCurrentMovementSpeed() return 300 end
    function u:GetEstimatedDamageToTarget(_,_,time) return 100*time end
    function u:GetActualIncomingDamage(raw,kind) return kind==DAMAGE_TYPE_MAGICAL and raw*.75 or raw end
    function u:GetSpellAmp() return 0 end
    function u:GetAttributeValue() return 100 end
    function u:GetAttackTarget() return self.target end
    function u:GetTarget() return self.target end
    function u:SetTarget(t) self.target=t; if self==GetBot() then state.target=t end end
    function u:IsChanneling() return self.channel or false end
    function u:IsCastingAbility() return false end
    function u:IsUsingAbility() return false end
    function u:IsInvisible() return self.invis or false end
    function u:IsInvulnerable() return self.invulnerable or false end
    function u:IsMagicImmune() return self.immune or false end
    function u:IsAttackImmune() return false end
    function u:IsDisarmed() return false end
    function u:IsRooted() return false end
    function u:IsFacingLocation() return false end
    function u:WasRecentlyDamagedByAnyHero() return false end
    function u:WasRecentlyDamagedByHero() return false end
    function u:HasModifier(k) return self.mods[k] or false end
    function u:HasScepter() return self.scepter or false end
    function u:HasShard() return false end
    function u:GetActiveMode() return state.mode end
    function u:GetActiveModeDesire() return .8 end
    function u:DistanceFromFountain() return 5000 end
    function u:GetAbilityByName(k) if not self.spells[k] then self.spells[k]=spell(k) end; return self.spells[k] end
    function u:GetNearbyHeroes(r,e) return J.GetNearbyHeroes(self,r,e) end
    u.GetNearbyLaneCreeps,u.GetNearbyNeutralCreeps,u.GetNearbyCreeps,u.GetNearbyTowers=empty,empty,empty,empty
    function u:FindAoELocation(_,hero) return {count=hero and (state.aoe or 0) or 0,targetloc=Vector(400,0)} end
    function u:Action_ClearActions() end
    local function action(self,a,t) state.actions[#state.actions+1]={spell=a.name,target=t} end
    u.ActionQueue_UseAbilityOnEntity,u.ActionQueue_UseAbilityOnLocation,u.ActionQueue_UseAbility=action,action,action
    u.Action_UseAbilityOnEntity,u.Action_UseAbilityOnLocation,u.Action_UseAbility=action,action,action
    function u:Action_MoveToLocation(loc) state.actions[#state.actions+1]={move=loc} end
    return u
end
local bot
GetBot=function() return bot end
J.Skill.GetTalentList=function() return {'t1','t2','t3','t4','t5','t6','t7','t8'} end
J.Skill.GetAbilityList=function() return {'q','w','e','d','as','r'} end
J.Skill.GetRandomBuild=function(b) return b[1] end
J.Skill.GetTalentBuild,J.Skill.GetSkillList=empty,empty
J.Item.GetRoleItemsBuyList=function() return 'pos_1' end
J.Role.IsPvNMode,J.Role.IsAllShadow=no,no
J.SetUserHeroInit=function(...) return ... end
J.IsValid=function(u) return u~=nil and not u:IsNull() and u:IsAlive() end
J.IsValidHero=function(u) return J.IsValid(u) and u:IsHero() end
J.IsValidTarget,J.CanBeAttacked=J.IsValidHero,J.IsValid
J.IsSuspiciousIllusion=function(u) return u.illusion or false end
J.CanCastOnNonMagicImmune=function(u) return J.IsValid(u) and not u.immune end
J.CanCastOnMagicImmune=J.IsValid
J.CanCastOnTargetAdvanced=function(u) return J.IsValid(u) and not u.blocked end
J.CanCastAbility=function(a) return a~=nil and a:IsTrained() and a:IsFullyCastable() end
J.CanNotUseAbility=function() return state.busy or false end
J.GetNearbyHeroes=function(center,r,enemy)
    local list={}
    for _,u in ipairs(state.units) do
        if u~=center and u:IsAlive() and ((u.team~=center.team)==enemy)
            and GetUnitToUnitDistance(center,u)<=r then list[#list+1]=u end
    end
    return list
end
J.GetEnemiesNearLoc=function(loc,r)
    local list={}; for _,u in ipairs(state.units) do
        if u.team~=bot.team and distance(loc,u.loc)<=r then list[#list+1]=u end
    end; return list
end
J.GetAlliesNearLoc=function(loc,r)
    local list={}; for _,u in ipairs(state.units) do
        if u.team==bot.team and distance(loc,u.loc)<=r then list[#list+1]=u end
    end; return list
end
J.GetEnemyList=function(b,r) return J.GetNearbyHeroes(b,r,true) end
J.GetAroundEnemyHeroList=function(r) return J.GetNearbyHeroes(bot,r,true) end
J.IsInRange=function(a,b,r) return GetUnitToUnitDistance(a,b)<=r end
J.GetProperTarget=function() return state.target end
J.GetHP=function(u) return u.hp/u.maxHp end
J.IsInTeamFight=function() return state.fight end
J.IsGoingOnSomeone=function() return state.go end
J.IsRetreating=function() return state.mode==BOT_MODE_RETREAT end
J.IsLaning,J.IsFarming,J.IsPushing,J.IsDefending,J.IsAttacking,J.IsInLaningPhase=no,no,no,no,no,no
J.IsDoingRoshan=function() return state.objective=='roshan' end
J.IsDoingTormentor=function() return state.objective=='tormentor' end
J.IsRoshan=function(u) return u~=nil and u.name=='roshan' end
J.IsTormentor=function(u) return u~=nil and u.name=='tormentor' end
J.IsDisabled=function(u) return u.disabled or false end
J.IsTaunted,J.IsChasingTarget,J.IsCastingUltimateAbility,J.IsCore,J.IsRunning,J.IsRealInvisible=no,no,no,no,no,no
J.IsItemAvailable=function(name) return state.items and state.items[name] or nil end
J.GetModifierTime,J.GetModifierCount=function() return 0 end,function() return 0 end
J.IsHaveAegis=no
J.IsOtherAllyCanKillTarget=no
J.GetCenterOfUnits=function(list) return list[1].loc end
GetUnitList=function() local list={}; for _,u in ipairs(state.units) do if u.team~=bot.team then list[#list+1]=u end end; return list end
J.GetProperCastRange=function(_,_,r) return r end
J.GetManaAfter=function(cost) return (bot.mana-cost)/1500 end
J.GetManaThreshold=function() return 0 end
J.GetCastLocation=function(_,t) return t.loc end
J.GetAoeEnemyHeroLocation=function(_,_,_,count) return (state.aoe or 0)>=count and Vector(400,0) or nil end
J.GetStrongestUnit=function(list) return list[1] end
J.GetInLocLaneCreepCount=function() return 0 end
J.CombineTwoTable=function(a,b) local c={}; for _,v in ipairs(a) do c[#c+1]=v end; for _,v in ipairs(b) do c[#c+1]=v end; return c end
J.GetLocationToLocationDistance=distance
J.GetCorrectLoc=function(u) return u.loc end
J.SetQueuePtToINT,J.SetReportMotive,J.ConsiderForMkbDisassembleMask=function() end,function() end,function() end
J.ConsiderTarget=function() end
J.WillKillTarget=function(u,damage,kind,delay) return u:GetActualIncomingDamage(damage,kind)>=u.hp+u.regen*(delay or 0) end
J.WillMagicKillTarget=function(_,u,damage,delay) return J.WillKillTarget(u,damage,DAMAGE_TYPE_MAGICAL,delay) end
J.CanKillTarget=function(u,damage,kind) return J.WillKillTarget(u,damage,kind,0) end
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/FunLib/shai_cast_survival']={Allow=function() return true end}
package.loaded['bots/FunLib/shai_centaur_escape']={Try=no}
package.loaded['bots/FunLib/shai_lich_assist']={Try=no,TryGaze=no,AllowGaze=function() return true end}
package.loaded['bots/FunLib/shai_escape_route']={HoldingJump=no,HoldingAlignment=no,TryZeusJump=no}
local originalDofile=dofile
dofile=function(path) if path=='bots/FunLib/aba_minion' then return {} end; return originalDofile(path) end
local heroes={}
for _,name in ipairs({'skeleton_king','luna','sven','zuus','dragon_knight','sniper','axe','tidehunter','centaur','lion','vengefulspirit','witch_doctor','crystal_maiden','lich','warlock'}) do
    bot=unit('npc_dota_hero_'..name,0,2)
    heroes[name]={bot=bot,x=dofile('bots/BotLib/hero_'..name..'.lua')}
end
local passed,failures=0,{}
local function setup(name)
    state={now=state.now+10,units={},mode=0,fight=false,go=false,target=nil,actions={}}
    bot=heroes[name].bot; bot.mods={}; bot.hp=1800; bot.mana=1500; bot.invis=false; bot.scepter=false; bot.target=nil
    for _,a in pairs(bot.spells) do a.ready=false; a.trained=false; a.special={}; a.damage=nil end
    state.units={bot}
    return heroes[name].x
end
local function ready(name,special)
    local a=bot:GetAbilityByName(name); a.ready=true; a.trained=true; a.special=special or {}; return a
end
local function enemy(x,hp)
    local u=unit('npc_dota_hero_pudge',x or 400); u.hp=hp or 1800
    state.units[#state.units+1]=u; return u
end
local function test(name,f)
    local ok,err=pcall(f); if ok then passed=passed+1 else failures[#failures+1]=name..': '..tostring(err) end
end
local function initialize(x)
    x.SkillsComplement(); state.actions={}
end
test('all 15 enabled hero modules load',function() local n=0; for _,h in pairs(heroes) do assert(type(h.x.SkillsComplement)=='function'); n=n+1 end; assert(n==15) end)
local urgent={luna='luna_lucent_beam',sven='q',dragon_knight='dragon_knight_dragon_tail',vengefulspirit='vengefulspirit_magic_missile',witch_doctor='q'}
for name,stun in pairs(urgent) do
    test(name..' interrupts before otherwise eligible buffs/damage',function()
        local x=setup(name); ready(stun); local e=enemy(); e.channel=true
        -- Keep actual dispatch; force a competing, lower-priority decision.
        local key=({luna='ConsiderLunarOrbit',sven='ConsiderR',dragon_knight='ConsiderElderDragonForm',vengefulspirit='ConsiderNetherSwap',witch_doctor='ConsiderAS'})[name]
        local old=x[key]; x[key]=function() error('Ordinary spell preempted urgent interrupt') end
        local ok,err=pcall(x.SkillsComplement); x[key]=old; assert(ok,err)
        assert(#state.actions==1 and state.actions[1].spell==stun and state.actions[1].target==e)
    end)
end
local Interrupt=require('bots/FunLib/shai_spell_interrupt')
for _,reason in ipairs({'range','hidden','illusion','immune','blocked','busy','invisible','cooldown'}) do
    test('interrupt rejects '..reason,function()
        setup('sven'); local a=ready('q'); local e=enemy(); e.channel=true
        if reason=='range' then e.loc.x=700 elseif reason=='hidden' then e.visible=false
        elseif reason=='illusion' then e.illusion=true elseif reason=='immune' then e.immune=true
        elseif reason=='blocked' then e.blocked=true elseif reason=='busy' then state.busy=true
        elseif reason=='invisible' then bot.invis=true else a.ready=false end
        assert(not Interrupt.Try(bot,J,a) and #state.actions==0)
    end)
end
test('Luna does not beam a solo target with three enemy reinforcements',function()
    local x=setup('luna'); initialize(x); ready('luna_lucent_beam',{beam_damage=300})
    state.go=true; state.target=enemy(); enemy(450); enemy(500)
    assert(x.ConsiderLucentBeam()==0)
end)
test('Luna Eclipse works against healthy heroes in a teamfight',function()
    local x=setup('luna'); ready('luna_eclipse',{radius=675}); ready('luna_lucent_beam',{beam_damage=300})
    state.fight=true; enemy(); enemy(450); assert(x.ConsiderEclipse()>0)
    bot.spells.luna_lucent_beam.trained=false; assert(x.ConsiderEclipse()==0)
end)
test('Tide Anchor Smash reaches a hero inside attack range plus additional range',function()
    local x=setup('tidehunter'); initialize(x); ready('e',{additional_range=225,attack_damage=200})
    state.go=true; state.target=enemy(300); initialize(x); assert(x.ConsiderE()>0)
end)
test('Centaur Double Edge supplies a real objective target',function()
    local x=setup('centaur'); ready('centaur_double_edge',{edge_damage=100,strength_damage=100})
    for _,name in ipairs({'roshan','tormentor'}) do
        local u=unit(name,100,4); u.creep=true; state.target=u; state.objective=name
        local old=J.IsAttacking; J.IsAttacking=function() return true end
        local desire,target=x.ConsiderDoubleEdge(); J.IsAttacking=old
        assert(desire>0 and target==u,'Positive desire without target for '..name)
    end
end)
test('Axe can Cull a debuff-immune target inside the runtime execution threshold',function()
    local x=setup('axe'); ready('r',{damage=275}); local e=enemy(400,260); e.immune=true
    local desire,target=x.ConsiderR(); assert(desire>0 and target==e)
    e.mods.modifier_item_lotus_orb_active=true; assert(x.ConsiderR()==0)
end)
test('Axe Call interrupts through debuff immunity',function()
    local x=setup('axe'); ready('q',{radius=350}); local e=enemy(200); e.immune=true; e.channel=true
    assert(x.ConsiderQ()>0)
end)
test('Lion Finger uses runtime damage, including values supplied by upgrades',function()
    local x=setup('lion'); initialize(x); ready('r',{damage=1000,damage_per_kill=40})
    local e=enemy(500,700); local desire,target=x.ConsiderR(); assert(desire>0 and target==e)
end)
test('Sniper uses multi-hero Shrapnel without a current attack target',function()
    local x=setup('sniper'); initialize(x); ready('q',{radius=450,damage=50}); state.aoe=2; enemy(); enemy(500)
    assert(x.ConsiderQ()>0)
end)
test('Witch Doctor ready unused Cask/Maledict do not starve Death Ward',function()
    local x=setup('witch_doctor'); initialize(x)
    ready('q',{base_damage=100,bounce_range=575,speed=1200}); ready('e'); ready('r')
    state.go=true; state.target=enemy(400,1000); state.target.disabled=true
    for i=1,4 do state.units[#state.units+1]=unit('ally',100+i*10,2) end
    initialize(x); assert(x.ConsiderR()>0)
end)
test('Witch Doctor does not assume a guaranteed Cask return bounce',function()
    local x=setup('witch_doctor'); initialize(x); ready('q',{base_damage=100,bounce_range=575,speed=1200}); enemy(400,100)
    assert(x.ConsiderQ()==0)
    state.units[2].hp=60; assert(x.ConsiderQ()>0)
end)
test('Warlock can channel Upheaval after other ready spells decline their targets',function()
    local x=setup('warlock'); initialize(x); ready('q'); ready('w'); ready('r'); ready('e',{aoe=500})
    state.fight=true; state.aoe=2; assert(x.ConsiderE()>0)
end)
test('Warlock Shadow Word can heal its own caster',function()
    local x=setup('warlock'); ready('w'); bot.hp=1000
    local desire,target=x.ConsiderW(); assert(desire>0 and target==bot)
end)
test('Warlock casts Offering when ready Bonds has no useful target',function()
    local x=setup('warlock'); ready('q'); ready('r',{aoe=600}); state.aoe=2; enemy(); enemy(500)
    local old=x.ConsiderQ; x.ConsiderQ=function() return 0 end
    local ok,err=pcall(x.SkillsComplement); x.ConsiderQ=old; assert(ok,err)
    assert(#state.actions==1 and state.actions[1].spell=='r')
end)
test('CM Frostbite does not promise a kill before its DoT finishes against regeneration',function()
    local x=setup('crystal_maiden'); initialize(x); ready('w',{damage_per_second=100,duration=3})
    local e=enemy(400,200); e.regen=20
    assert(x.ConsiderW()==0)
    e.hp=140; assert(x.ConsiderW()>0)
end)
test('WK Blast kills using its real damage over time but accounts for regeneration',function()
    local x=setup('skeleton_king'); initialize(x)
    ready('skeleton_king_hellfire_blast',{damage=80,blast_dot_damage=20,blast_dot_duration=2,blast_speed=1200})
    local e=enemy(400,80); e.disabled=true -- suppress optional harass, retain kill consideration
    assert(x.ConsiderQ()>0)
    e.regen=20; assert(x.ConsiderQ()==0)
end)
test('Lich Nova does not overestimate its primary target damage',function()
    local x=setup('lich'); initialize(x); ready('q',{damage=40,aoe_damage=80,radius=200}); enemy(400,95)
    assert(x.ConsiderQ()==0)
    state.units[2].hp=80; assert(x.ConsiderQ()>0)
end)
test('Sven Hammer uses its actual spell damage to secure a kill',function()
    local x=setup('sven'); initialize(x); local a=ready('q'); a.damage=320
    local e=enemy(400,230); local desire,target=x.ConsiderQ(); assert(desire>0 and target==e)
end)
test('DK can stun after Breathe Fire in a teamfight',function()
    local x=setup('dragon_knight'); local e=enemy(400); e.mods.modifier_dragonknight_breathefire_reduction=true
    initialize(x); ready('dragon_knight_dragon_tail',{damage=100,projectile_speed=1600})
    state.fight=true; local desire,target=x.ConsiderDragonTail(); assert(desire>0 and target==e)
end)
test('Venge Wave uses runtime damage rather than an empty GetAbilityDamage value',function()
    local x=setup('vengefulspirit'); ready('vengefulspirit_wave_of_terror',{damage=120,wave_width=300})
    enemy(400,85); assert(x.ConsiderWaveOfTerror()>0)
end)
test('Venge does not dispatch an enemy Swap through targeted spell protection',function()
    local x=setup('vengefulspirit'); local e=enemy(400); e.blocked=true
    local old=x.ConsiderNetherSwap; x.ConsiderNetherSwap=function() return .8,e end
    local ok,err=pcall(x.SkillsComplement); x.ConsiderNetherSwap=old; assert(ok,err); assert(#state.actions==0)
end)
test('Zeus global kill forecast uses current innate percentage instead of old Lightning Hands proxy',function()
    local x=setup('zuus'); initialize(x)
    ready('zuus_static_field',{damage_health_pct=3.45}); ready('as'); ready('r',{damage=500})
    local e=enemy(1000,390); initialize(x)
    assert(x.ConsiderR()==0,'Old 9% estimate would falsely predict a kill')
    e.hp=370; assert(x.ConsiderR()>0)
end)
test('Sniper Assassinate recognizes its runtime magic damage',function()
    local x=setup('sniper'); initialize(x); local a=ready('r',{damage=500}); a.range=3000
    local e=enemy(1400,300); local desire,target=x.ConsiderR(); assert(desire>0 and target==e)
end)
test('Warlock prepares actual Bonds before actual useful Offering',function()
    local x=setup('warlock'); ready('q'); ready('r',{aoe=600}); state.aoe=2
    local e=enemy(); enemy(500); local old=x.ConsiderQ; x.ConsiderQ=function() return .8,e end
    local ok,err=pcall(x.SkillsComplement); x.ConsiderQ=old; assert(ok,err)
    assert(#state.actions==1 and state.actions[1].spell=='q')
end)
test('Warlock cancellation must not be overwritten by a new spell in the same callback',function()
    local x=setup('warlock'); bot.channel=true; bot.hp=700; enemy()
    local old=bot.WasRecentlyDamagedByAnyHero; bot.WasRecentlyDamagedByAnyHero=function() return true end
    J.GetTeamFountain=function() return Vector(-6000,0) end
    local ok,err=pcall(x.SkillsComplement); bot.WasRecentlyDamagedByAnyHero=old; bot.channel=false; assert(ok,err)
    assert(#state.actions==1 and state.actions[1].move.x==-6000)
end)
test('Sven target switch reads this callback target, not the previous one',function()
    local x=setup('sven'); state.target=enemy(800); local near=enemy(180)
    local old=J.IsRunning; J.IsRunning=function() return true end
    local ok,err=pcall(x.SkillsComplement); J.IsRunning=old; assert(ok,err); assert(bot.target==near)
end)
for _,name in ipairs({'witch_doctor','crystal_maiden'}) do
    test(name..' channel dispatch respects survival veto',function()
        local x=setup(name); ready('r'); local old=x.ConsiderR
        x.ConsiderR=function() return .8,Vector(400,0) end
        local survival=package.loaded['bots/FunLib/shai_cast_survival']; survival.Allow=function() return false end
        local ok,err=pcall(x.SkillsComplement); assert(#state.actions==0)
        survival.Allow=function() return true end
        if ok then ok,err=pcall(x.SkillsComplement) end
        x.ConsiderR=old; assert(ok,err); assert(#state.actions==1 and state.actions[1].spell=='r')
    end)
end
test('Tide does not slow its escape with Kraken against a spell-damage pursuer',function()
    local x=setup('tidehunter'); ready('tidehunter_kraken_shell'); state.mode=BOT_MODE_RETREAT; bot.hp=600
    local e=enemy(200)
    function e:GetEstimatedDamageToTarget(_,_,_,kind) return kind==DAMAGE_TYPE_PHYSICAL and 50 or kind==DAMAGE_TYPE_MAGICAL and 500 or 0 end
    local oldChase,oldRecent=J.IsChasingTarget,bot.WasRecentlyDamagedByHero
    J.IsChasingTarget=function() return true end; bot.WasRecentlyDamagedByHero=function() return true end
    local ok,err=pcall(function()
        assert(x.ConsiderW()==0)
        function e:GetEstimatedDamageToTarget(_,_,_,kind) return kind==DAMAGE_TYPE_PHYSICAL and 600 or 0 end
        assert(x.ConsiderW()>0)
        e.loc.x=600; assert(x.ConsiderW()==0)
    end)
    J.IsChasingTarget=oldChase; bot.WasRecentlyDamagedByHero=oldRecent; assert(ok,err)
end)
test('Warlock keeps the funded double Offering when Bonds would break its mana budget',function()
    local x=setup('warlock'); local q=ready('q'); local r=ready('r',{aoe=600}); r.cost=100
    local ref=spell('item_refresher'); ref.ready=true; ref.cost=100; state.items={item_refresher=ref}
    state.go=true; local e=enemy(); enemy(450); enemy(500); state.target=e
    local old=x.ConsiderQ; x.ConsiderQ=function() return .8,e end
    local ok,err=pcall(function()
        bot.mana=400; x.SkillsComplement(); assert(#state.actions==1 and state.actions[1].spell=='q')
        bot.mana=360; state.actions={}; x.SkillsComplement()
        assert(#state.actions==3 and state.actions[1].spell=='r' and state.actions[2].spell=='item_refresher' and state.actions[3].spell=='r')
    end)
    x.ConsiderQ=old; r.cost=80; assert(ok,err)
end)
test('CM can use Field on a disabled target with four allies nearby',function()
    local x=setup('crystal_maiden'); initialize(x); local a=ready('r'); a.radius=810
    state.go=true; state.target=enemy(150,600); state.target.disabled=true
    for i=1,4 do state.units[#state.units+1]=unit('ally',200+i*10,2) end
    local old=bot.GetOffensivePower; bot.GetOffensivePower=function() return 1000 end
    local ok,err=pcall(function() assert(x.ConsiderR()>0) end)
    bot.GetOffensivePower=old; assert(ok,err)
end)
if #failures>0 then error(table.concat(failures,'\n')) end
print('SHAI hero review: '..passed..' scenarios passed (15 real hero modules loaded)')
