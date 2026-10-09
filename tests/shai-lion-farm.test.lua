package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_NONE,BOT_ACTION_DESIRE_NONE,BOT_ACTION_DESIRE_HIGH=0,0,0.8
DAMAGE_TYPE_MAGICAL=1
UNIT_LIST_ENEMY_HEROES=2
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=1200
DotaTime=function() return now end
local bot,enemies,neutrals,lanes,towers,threat,concern
local function unit(x,y,hero)
    local h={location=Vector(x,y),visible=true,hp=500,mods={},hero=hero}
    local function seen(self) assert(self.visible,'Hidden creep/hero state read') end
    function h:IsNull() return false end
    function h:CanBeSeen() return self.visible end
    function h:IsAlive() seen(self); return self.hp>0 end
    function h:IsInvulnerable() seen(self); return self.invulnerable or false end
    function h:IsMagicImmune() seen(self); return self.immune or false end
    function h:HasModifier(m) seen(self); return self.mods[m] or false end
    function h:GetLocation() seen(self); return self.location end
    function h:GetExtrapolatedLocation(delay)
        seen(self); return Vector(self.location.x+(self.vx or 0)*delay,self.location.y+(self.vy or 0)*delay)
    end
    function h:GetHealth() seen(self); return self.hp end
    function h:GetActualIncomingDamage(damage) seen(self); return damage*0.75 end
    function h:GetAttackTarget() return self.target end
    function h:GetAttackRange() return 700 end
    return h
end
GetUnitToUnitDistance=function(a,b)
    local p,q=a:GetLocation(),b:GetLocation()
    return math.sqrt((p.x-q.x)^2+(p.y-q.y)^2)
end
GetUnitList=function() return enemies end
local function ability(name,cost,level)
    local a={name=name,cost=cost,level=level or 1,ready=true,values={width=140,damage=170,speed=2800}}
    function a:GetName() return self.name end
    function a:GetManaCost() return self.cost end
    function a:GetLevel() return self.level end
    function a:IsFullyCastable() return self.ready end
    function a:IsHidden() return false end
    function a:IsTrained() return false end
    function a:GetCastRange() return 650 end
    function a:GetCastPoint() return 0.3 end
    function a:GetSpecialValueInt(k) return self.values[k] or 0 end
    function a:GetAbilityDamage() return 0 end -- real feed stores Spike damage as a special
    return a
end
local q,w,e,r=ability('lion_impale',110,2),ability('lion_voodoo',80),ability('lion_mana_drain',0),ability('lion_finger_of_death',200)
local no=function() return false end
local J={Skill={},Item={},Role={},Chat={GetNormName=function() return 'enemy' end}}
J.Skill.GetTalentList=function() return {'t1','t2','t3','t4','t5','t6','t7','t8'} end
J.Skill.GetAbilityList=function() return {'lion_impale','lion_voodoo','lion_mana_drain','d','f','lion_finger_of_death'} end
J.Skill.GetRandomBuild=function(builds) return builds[1] end
J.Skill.GetTalentBuild,J.Skill.GetSkillList=function() return {} end,function() return {} end
J.Item.GetRoleItemsBuyList=function() return 'pos_4' end
J.Role.IsPvNMode,J.Role.IsAllShadow=no,no
J.SetUserHeroInit=function(...) return ... end
J.IsValidHero=function(h) return h~=nil and h.hero end
J.IsSuspiciousIllusion=no
J.GetProperTarget=function() return bot.target end
J.CanNotUseAbility=function() return bot.busy or false end
J.IsFarming=function() return bot.mode=='farm' end
J.IsPushing=function() return bot.mode=='push' end
J.IsDefending=function() return bot.mode=='defend' end
J.IsRetreating=function() return bot.mode=='retreat' end
J.IsGoingOnSomeone,J.IsAttacking,J.IsInTeamFight,J.IsDoingRoshan,J.IsDoingTormentor=no,no,no,no,no
J.GetAlliesNearLoc=function() return {} end
J.IsItemAvailable=function() return nil end
J.GetNearbyHeroes=function(_,range)
    local result={}
    for _,h in pairs(enemies) do if h:CanBeSeen() and GetUnitToUnitDistance(bot,h)<range then result[#result+1]=h end end
    return result
end
J.GetModifierTime=function() return 0 end
J.SetQueuePtToINT,J.SetReportMotive=function() end,function() end
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/FunLib/shai_farm_safety']={GetThreat=function() return threat end}
package.loaded['bots/FunLib/shai_threat_memory']={GetConcern=function() return concern end}
require('bots/Customize/shai').BehaviorTrace=false
local function reset()
    now=now+5; bot=unit(0,0,true); bot.hp=1000; bot.mana=800; bot.mode='farm'
    q.ready,w.ready,r.ready=true,true,true; q.level=2
    enemies,lanes,towers,threat,concern={},{},{},nil,nil
    neutrals={unit(300,0),unit(500,0)}
    function bot:GetUnitName() return 'npc_dota_hero_lion' end
    function bot:GetPlayerID() return 1 end
    function bot:GetAbilityByName(n) return n=='lion_impale' and q or n=='lion_voodoo' and w or n=='lion_mana_drain' and e or n=='lion_finger_of_death' and r or ability(n,0) end
    function bot:GetMana() return self.mana end
    function bot:GetMaxMana() return 1000 end
    function bot:GetMaxHealth() return 1000 end
    function bot:GetLevel() return 12 end
    function bot:GetSpellAmp() return 0 end
    function bot:GetAttackDamage() return 80 end
    function bot:IsInvisible() return false end
    function bot:IsChanneling() return false end
    function bot:GetActiveMode() return BOT_MODE_NONE end
    function bot:WasRecentlyDamagedByAnyHero() return self.damaged or false end
    function bot:GetNearbyTowers() return towers end
    function bot:GetNearbyNeutralCreeps() return neutrals end
    function bot:GetNearbyLaneCreeps() return lanes end
    function bot:FindAoELocation() return {count=0} end
    function bot:ActionQueue_UseAbilityOnLocation(a,loc) self.cast=a; self.destination=loc end
end
GetBot=function() return bot end
local realDofile=dofile
dofile=function(path) if path=='bots/FunLib/aba_minion' then return {} end; return realDofile(path) end
local Farm=require('bots/FunLib/shai_lion_farm')
reset(); local p=Farm.GetPlan(bot,J,q)
assert(p and p.count==2 and p.reserve==380,'Two aligned remaining neutrals justify a funded Spike using actual damage special')
neutrals[2].location=Vector(300,300)
assert(Farm.GetPlan(bot,J,q)==nil,'Nearby circular AoE count does not imply a useful straight-line Spike')
reset(); neutrals[2].vy=500
assert(Farm.GetPlan(bot,J,q)==nil,'Future lateral movement during cast and spike travel can invalidate the line')
reset(); neutrals[2].location=Vector(800,0)
assert(Farm.GetPlan(bot,J,q)==nil,'Out-of-range farm target never issues a cast that walks forward')
reset(); neutrals[2].visible=false
assert(Farm.GetPlan(bot,J,q)==nil,'Hidden creep stats/location are never read')
reset(); neutrals[2].immune=true
assert(Farm.GetPlan(bot,J,q)==nil,'Magic-immune creep does not count toward useful hits')
reset(); neutrals[2].mods.modifier_fountain_glyph=true
assert(Farm.GetPlan(bot,J,q)==nil,'Glyphed creep is not promised damage')
reset(); neutrals[1].hp,neutrals[2].hp=10,10
assert(Farm.GetPlan(bot,J,q)==nil,'Do not spend Spike on two trivial autoattack finishes')
reset(); bot.mana=400
assert(Farm.GetPlan(bot,J,q)==nil,'Ready Hex and Finger mana remain funded after the farm cast')
r.ready=false; assert(Farm.GetPlan(bot,J,q),'Finger on cooldown does not impose a nonexistent current combo reserve')
reset(); enemies={unit(1000,0,true)}
assert(Farm.GetPlan(bot,J,q)==nil,'Nearby visible hero keeps the stun for combat')
enemies[1].visible=false; assert(Farm.GetPlan(bot,J,q),'Unobserved hidden hero supplies no secret position')
concern={}; assert(Farm.GetPlan(bot,J,q)==nil,'Known memory concern can still preserve control after vision is lost')
reset(); threat={}; assert(Farm.GetPlan(bot,J,q)==nil,'Concrete farm danger rejects the optional spell')
reset(); towers={unit(750,0)}
assert(Farm.GetPlan(bot,J,q)==nil,'Lion under enemy tower reach does not stop to clear creeps')
towers[1].location=Vector(1500,0); assert(Farm.GetPlan(bot,J,q),'Safe current position may cast without approaching a distant tower')
towers[1].target=bot; assert(Farm.GetPlan(bot,J,q)==nil,'An actual tower attacker rejects the cast even outside nominal range')
reset(); bot.mods.modifier_silencer_curse_of_the_silent=true
assert(Farm.GetPlan(bot,J,q)==nil,'Creep Spike is optional farm under Curse, not protected hero control')
reset(); bot.mode='lane'; assert(Farm.GetPlan(bot,J,q)==nil,'Opening laning does not become indiscriminate wave push')
bot.mode='push'; neutrals={}; lanes={unit(300,0),unit(500,0)}
assert(Farm.GetPlan(bot,J,q),'Funded in-range lane clear is supported in push mode')
bot.mode='retreat'; assert(Farm.GetPlan(bot,J,q)==nil,'Retreat never turns into creep clear')
reset(); bot.busy=true; assert(Farm.GetPlan(bot,J,q)==nil,'Queued/casting/disabled guard remains authoritative')
reset(); bot.hp=300; assert(Farm.GetPlan(bot,J,q)==nil,'A vulnerable low-HP farmer does not stop to cast')
-- Load the actual hero and test its real dispatch order and native Q fallback.
reset(); local lion=dofile('bots/BotLib/hero_lion.lua')
local drainConsidered=false
lion.ConsiderE=function() drainConsidered=true; return 0.8,neutrals[1] end
lion.ConsiderR,lion.ConsiderW=function() return 0 end,function() return 0 end
lion.SkillsComplement()
assert(bot.cast==q and not drainConsidered,'Actual Lion casts a useful funded Spike before optional creep Drain')
local desire,location,reason,purpose=lion.ConsiderQ()
assert(desire>0 and location and purpose=='farm','Actual native Q consideration labels its creep cast as farm')
bot.cast=nil; bot.mods.modifier_silencer_curse_of_the_silent=true
assert(lion.ConsiderQ()==0,'Actual native Q has no duplicate farm branch bypassing Curse')
local enemy=unit(300,0,true); enemies={enemy}
J.CanCastOnNonMagicImmune=function() return true end
J.WillMagicKillTarget=function(_,_,damage) assert(damage==170,'Actual Q kill forecast must read the damage special'); return true end
assert(lion.ConsiderQ()>0,'Actual native hero Q kill forecast uses the real Spike damage field')
enemies={}
lion.ConsiderE=function() return 0 end
lion.ConsiderQ=function() return 0.8,Vector(300,0),'regression-farm','farm' end
lion.SkillsComplement(); assert(bot.cast==nil,'Actual dispatch rechecks the farm purpose and refuses Curse')
lion.ConsiderQ=function() return 0.8,Vector(300,0),'regression-control' end
lion.SkillsComplement(); assert(bot.cast==q,'Actual control dispatch is not turned into a universal Curse spell ban')
print('PASS: actual Lion Q farm geometry/value, two-creep camp, range/tower/fog/danger, mana/control reserve, Curse purpose and dispatch before creep Drain')
