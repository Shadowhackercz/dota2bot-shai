package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_NONE,BOT_ACTION_DESIRE_NONE=0,0
DAMAGE_TYPE_PHYSICAL,DAMAGE_TYPE_ALL=1,2
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=900
DotaTime=function() return now end
local bot,ally,enemy,allies,enemies,threat
local function unit(x)
    local h={x=x,hp=1000,visible=true,mods={}}
    local function seen(self) assert(self.visible,'Hidden state read') end
    function h:IsNull() return false end
    function h:CanBeSeen() return self.visible end
    function h:GetHealth() seen(self); return self.hp end
    function h:GetMaxHealth() seen(self); return 1000 end
    function h:GetLocation() seen(self); return Vector(self.x,0) end
    function h:GetUnitName() seen(self); return 'npc_dota_hero_pudge' end
    function h:GetAttackRange() seen(self); return 150 end
    function h:GetAttackTarget() seen(self); return self.target end
    function h:GetEstimatedDamageToTarget(_,target,time,kind)
        seen(self); return (target==bot and (self.botDps or 0) or (self.dps or 200))*time
    end
    function h:WasRecentlyDamagedByHero(other) return self.recent==other end
    function h:HasModifier(m) seen(self); return self.mods[m] or false end
    return h
end
GetUnitToUnitDistance=function(a,b) return math.abs(a:GetLocation().x-b:GetLocation().x) end
local function ability(name,range)
    local a={name=name,range=range,ready=true}
    function a:GetName() return self.name end
    function a:IsHidden() return false end
    function a:IsFullyCastable() return self.ready end
    function a:GetCastRange() return self.range end
    function a:GetCastPoint() return 0.3 end
    function a:IsTrained() return false end
    return a
end
local q,w=ability('lich_frost_nova',600),ability('lich_frost_shield',800)
local no=function() return false end
local J={Skill={},Item={},Role={IsPvNMode=no,IsAllShadow=no}}
J.IsValidHero=function(h) return h~=nil and not h.creep end
J.IsSuspiciousIllusion=function(h) return h.illusion or false end
J.IsDisabled=function(h) return h.disabled or false end
J.CanCastOnNonMagicImmune=function(h) return not h.immune end
J.CanCastOnTargetAdvanced=function(h) return not h.protected end
J.GetNearbyHeroes=function() return enemies end
J.GetAlliesNearLoc=function() return allies end
J.CanNotUseAbility,J.CanNotUseAction=function() return bot.busy end,function() return bot.busy end
J.SetQueuePtToINT=function() end
J.GetModifierTime=function() return 0 end
package.loaded['bots/FunLib/shai_farm_safety']={GetThreat=function() return threat end}
require('bots/Customize/shai').BehaviorTrace=false
local Assist=require('bots/FunLib/shai_lich_assist')
local function reset()
    now=now+10; bot,ally,enemy=unit(0),unit(250),unit(350)
    bot.busy=false; allies={ally}; enemies={enemy}; enemy.target=ally; threat=nil
    q.ready,w.ready=true,true
    function bot:IsInvisible() return self.invisible or false end
    function bot:IsInvulnerable() return false end
    function bot:GetMana() return 800 end
    function bot:GetActualIncomingDamage(damage) return damage end
    function bot:GetMaxMana() return 1000 end
    function bot:GetLevel() return 12 end
    function bot:GetUnitName() return 'npc_dota_hero_lich' end
    function bot:GetPlayerID() return 1 end
    function bot:ActionQueue_UseAbilityOnEntity(a,t) self.cast=a; self.castTarget=t end
end
reset(); local p=Assist.GetPlan(bot,J,q,w,0)
assert(p and p.ability==w and p.target==ally,'Visible physical attack prompts an in-range ally shield')
w.ready=false; p=Assist.GetPlan(bot,J,q,w,0)
assert(p and p.ability==q and p.target==enemy and p.purpose=='control','Without shield, Nova slows the actual ally attacker')
enemy.target=nil; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'Nearby enemy alone is not a forced assist')
ally.recent=enemy; assert(Assist.GetPlan(bot,J,q,w,0),'Recent visible attack still counts when enemy attack target changes')
enemy.x=1000; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'No pursuit just to get the spell into range')
reset(); w.ready=false; enemy.x=650; ally.x=550
assert(Assist.GetPlan(bot,J,q,w,0)==nil and Assist.GetPlan(bot,J,q,w,100),'Range bonus is respected without invented extra range')
reset(); w.ready=false; enemy.mods.modifier_lich_frostnova_slow=true
assert(Assist.GetPlan(bot,J,q,w,0)==nil,'No immediate reapplication of active Nova slow')
enemy.mods={}; enemy.disabled=true; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'Existing disable is not overwritten with optional slow')
enemy.disabled=false; enemy.immune=true; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'Magic immune attacker is not promised a slow')
reset(); enemy.visible=false; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'Hidden attackers reveal no state')
reset(); ally.visible=false; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'Hidden ally state is not read')
reset(); enemy.illusion=true; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'Suspicious illusions are not promoted to a real hero threat')
reset(); ally.mods.modifier_skeleton_king_reincarnation_scepter_active=true
assert(Assist.GetPlan(bot,J,q,w,0)==nil,'Temporary WK ghost does not consume a new survival shield')
reset(); enemy.botDps=1000; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'Dangerous cast exposure refuses optional ally help')
reset(); bot.busy=true; assert(not Assist.Try(bot,J,q,w,0) and not bot.cast,'Queued actions remain protected')
bot.busy=false; threat={}; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'Concrete self escape has priority')
reset(); allies={}; assert(Assist.GetPlan(bot,J,q,w,0)==nil,'No ally means no new assist path')

-- Load actual Lich SkillsComplement, isolate only ordinary considerations.
reset()
J.Skill.GetTalentList=function() return {'t1','t2','t3','t4','t5','t6','t7','t8'} end
J.Skill.GetAbilityList=function() return {'q','w','e','as','f','r'} end
J.Skill.GetRandomBuild=function(builds) return builds[1] end
J.Skill.GetTalentBuild,J.Skill.GetSkillList=function() return {} end,function() return {} end
J.Item.GetRoleItemsBuyList=function() return 'pos_5' end
J.SetUserHeroInit=function(...) return ... end
J.GetProperTarget=function() return nil end
J.IsItemAvailable=function() return nil end
J.SetReportMotive=function() end
function bot:GetAbilityByName(n) return n=='q' and q or n=='w' and w or ability(n,600) end
GetBot=function() return bot end
package.loaded['bots/FunLib/jmz_func']=J
local actualDofile=dofile
dofile=function(path) if path=='bots/FunLib/aba_minion' then return {} end return actualDofile(path) end
local lich=dofile('bots/BotLib/hero_lich.lua')
local creepConsidered=false
lich.ConsiderR=function() return 0 end
lich.ConsiderQ=function() creepConsidered=true; return 1,unit(100) end
lich.SkillsComplement()
assert(bot.cast==w and bot.castTarget==ally and not creepConsidered,'Actual dispatch shields ally before ordinary creep Nova')
bot.cast=nil; w.ready=false; lich.SkillsComplement()
assert(bot.cast==q and bot.castTarget==enemy and not creepConsidered,'Actual dispatch helps with Nova independently of the native combat mode')
bot.cast=nil; bot.mods.modifier_silencer_curse_of_the_silent=true; lich.SkillsComplement()
assert(bot.cast==q,'Useful ally control remains available under Curse')
bot.cast=nil; bot.mods={}; bot.busy=true; lich.SkillsComplement(); assert(bot.cast==nil,'Actual hero respects action guard')
print('PASS: actual Lich ally shield/Nova dispatch before creep cast, range, visibility, attack evidence, self safety and Curse purpose')
