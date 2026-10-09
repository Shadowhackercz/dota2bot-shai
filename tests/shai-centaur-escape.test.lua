package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_ACTION_DESIRE_NONE,BOT_ACTION_DESIRE_HIGH,BOT_MODE_NONE,DAMAGE_TYPE_ALL=0,0.8,0,1
local now=1000
DotaTime=function() return now end
RandomInt=function() return 1 end
local state={}
local function Ability(name,point)
    local a={name=name,point=point}
    function a:GetName() return self.name end
    function a:IsFullyCastable() return state[self.name]~=false end
    function a:IsHidden() return false end
    function a:GetCastPoint() return self.point end
    function a:GetSpecialValueInt() return 315 end
    return a
end
local stomp,stampede=Ability('centaur_hoof_stomp',0.5),Ability('centaur_stampede',0)
local bot={}
function bot:IsAlive() return true end
function bot:GetUnitName() return 'npc_dota_hero_centaur' end
function bot:GetHealth() return 1000 end
function bot:IsRooted() return state.rooted or false end
function bot:HasModifier(m) return state.modifier==m end
function bot:GetAbilityByName(name) return name==stomp.name and stomp or name==stampede.name and stampede or nil end
function bot:Action_UseAbility(a) self.cast=a:GetName(); self.count=(self.count or 0)+1 end
local enemy={}
function enemy:IsNull() return false end
function enemy:CanBeSeen() return state.visible~=false end
function enemy:GetCurrentMovementSpeed() assert(state.visible~=false); return 300 end
function enemy:GetEstimatedDamageToTarget() assert(state.visible~=false); return state.incoming or 100 end
GetBot=function() return bot end
GetUnitToUnitDistance=function() assert(state.visible~=false); return state.distance or 100 end
local no=function() return false end
local J={Skill={},Item={},Role={}}
J.Skill.GetTalentList=function() return {} end
J.Skill.GetAbilityList=function() return {} end
J.Skill.GetRandomBuild=function(b) return b[1] end
J.Skill.GetTalentBuild=function() return {} end
J.Skill.GetSkillList=function() return {} end
J.Item.GetRoleItemsBuyList=function() return 'pos_3' end
J.Role.IsPvNMode,J.Role.IsAllShadow=no,no
J.SetUserHeroInit=function(...) return ... end
J.CanNotUseAbility=function() return state.silenced or false end
J.CanNotUseAction=function() return state.busy or false end
J.IsRetreating=function() return state.retreat or false end
J.IsGoingOnSomeone=function() return state.engage or false end
J.IsValidHero=function(h) return h~=nil end
J.IsSuspiciousIllusion=function() return state.illusion or false end
J.IsDisabled=function() return state.disabled or false end
J.CanCastOnNonMagicImmune=function() return not state.immune end
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/FunLib/shai_farm_safety']={GetThreat=function()
    return state.threat and {enemy=enemy,name='pudge',memory=state.memory} or nil
end}
local CastSafety={AllowDecision=function(_,_,a,_,purpose)
    state.purpose=purpose; return state.reject~=a:GetName()
end}
package.loaded['bots/FunLib/shai_cast_safety']=CastSafety
require('bots/Customize/shai').BehaviorTrace=false
local originalDofile=dofile
dofile=function(path) if path=='bots/FunLib/aba_minion' then return {} end; return originalDofile(path) end
local hero=dofile('bots/BotLib/hero_centaur.lua')
local Escape=require('bots/FunLib/shai_centaur_escape')
local function Reset(changes)
    now=now+10; state={threat=true,retreat=true}; bot.cast=nil; bot.count=0; bot.shaiCentaurEscapeCast=nil
    for k,v in pairs(changes or {}) do state[k]=v end
end
Reset(); hero.SkillsComplement()
assert(bot.cast==stomp.name and state.purpose=='control','Actual hero dispatch uses safe close Stomp before other escape/offense')
hero.SkillsComplement(); assert(bot.count==1,'Release lease preserves issued cast before engine flags update')
Reset({distance=500}); hero.SkillsComplement()
assert(bot.cast==stampede.name,'One strong pursuer is enough for Stampede; no two-enemy or low-HP threshold')
Reset({incoming=900}); assert(Escape.Try(bot,J,stomp,stampede,CastSafety) and bot.cast==stampede.name,'Unsafe Stomp wind-up yields to instant escape')
Reset({reject=stomp.name}); assert(Escape.Try(bot,J,stomp,stampede,CastSafety) and bot.cast==stampede.name,'Cast penalty can decline control and allow escape')
Reset({memory=true,visible=false}); assert(Escape.Try(bot,J,stomp,stampede,CastSafety) and bot.cast==stampede.name,'Memory permits escape without hidden target stat reads')
Reset({threat=false}); assert(not Escape.Try(bot,J,stomp,stampede,CastSafety) and not bot.cast,'No automatic ulti without actual threat')
Reset({engage=true,retreat=false}); assert(not Escape.Try(bot,J,stomp,stampede,CastSafety),'Committed offense is left to existing group logic')
Reset({centaur_hoof_stomp=false,rooted=true}); assert(not Escape.Try(bot,J,stomp,stampede,CastSafety),'Rooted Centaur does not waste speed-only escape')
Reset({centaur_hoof_stomp=false,modifier='modifier_bloodseeker_rupture'}); assert(not Escape.Try(bot,J,stomp,stampede,CastSafety),'Rupture declines voluntary speed-only escape')
Reset({distance=500,reject=stampede.name}); assert(not Escape.Try(bot,J,stomp,stampede,CastSafety),'Fatal spell penalty can reject Stampede')
Reset({busy=true}); assert(not Escape.Try(bot,J,stomp,stampede,CastSafety),'Existing queue/channel not interrupted')
Reset({silenced=true}); assert(not Escape.Try(bot,J,stomp,stampede,CastSafety),'Silence guard')
Reset(); Escape.Try(bot,J,stomp,stampede,CastSafety); now=10; state.distance=500
Escape.Try(bot,J,stomp,stampede,CastSafety); assert(bot.cast==stampede.name,'Clock rollback invalidates cast release lease')
print('PASS: actual Centaur escape dispatch, safe Stomp, single-pursuer Stampede, fog, cast survival, leases and action guards')
