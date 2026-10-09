package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_NONE,DAMAGE_TYPE_ALL,DAMAGE_TYPE_PHYSICAL,UNIT_LIST_ENEMY_HEROES=0,1,2,3
local now=1000
DotaTime,GameTime=function() return now end,function() return now end
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local bot={hp=1000,level=10,x=0}
function bot:GetPlayerID() return 0 end
function bot:GetUnitName() return 'npc_dota_hero_zuus' end
function bot:IsAlive() return true end
function bot:GetHealth() return self.hp end
function bot:GetLevel() return self.level end
function bot:GetAttackDamage() return 70 end
function bot:GetEstimatedDamageToTarget() return 140 end
function bot:GetActualIncomingDamage(raw) return raw end
GetBot=function() return bot end
GetTeamMember=function() return nil end
local enemy={hp=2500,level=20,x=1000,visible=true}
function enemy:IsNull() return false end
function enemy:CanBeSeen() return self.visible end
local function visible(self) assert(self.visible,'No hidden destination threat stats') end
function enemy:GetHealth() visible(self); return self.hp end
function enemy:GetLevel() visible(self); return self.level end
function enemy:GetAttackDamage() visible(self); return 400 end
function enemy:GetAttackRange() visible(self); return 150 end
function enemy:GetCurrentMovementSpeed() visible(self); return 300 end
function enemy:GetSecondsPerAttack() visible(self); return 1 end
function enemy:GetEstimatedDamageToTarget() visible(self); return 800 end
function enemy:GetUnitName() return 'npc_dota_hero_pudge' end
function enemy:GetLocation() visible(self); return Vector(self.x,0,0) end
function enemy:GetPlayerID() return 10 end
local enemies={enemy}
GetUnitList=function() return enemies end
local function location(x) return {cattr={location=Vector(x,0,0)}} end
local old,near=location(-2000),location(1000)
GetUnitToLocationDistance=function(unit,loc)
    assert(type(loc)=='table' and type(loc.x)=='number','Must validate vectors before engine calls')
    if unit==enemy then visible(unit) end
    return math.abs(unit.x-loc.x)
end
IsLocationPassable=function(loc) return loc.x~=900 end
local J={IsValidHero=function() return true end,IsSuspiciousIllusion=function() return false end,
    Role={availableCampTable={}},Site={GetClosestNeutralSpwan=function() return near end}}
require('bots/Customize/shai').BehaviorTrace=false
local Safety=require('bots/FunLib/shai_farm_safety')
assert(Safety.IsCampDangerous(bot,J,near),'Reject a distant camp beside a visible stronger enemy')
assert(not Safety.IsCampDangerous(bot,J,old),'Do not block a camp far from that enemy')
assert(Safety.ChooseCamp(bot,J,old,near)==old,'A shorter dangerous destination does not win')
local repick=dofile('.tools/lua/shai-camp-selection.lua')
assert(repick(bot,J,Safety,old,{})==old,'Actual farm selection must use the destination guard')
enemy.visible=false
bot.shaiThreatMemory=nil; now=now+1
assert(Safety.ChooseCamp(bot,J,old,near)==near,'An unseen hero without an observation is not tracked')
enemy.visible=true
local Memory=require('bots/FunLib/shai_threat_memory')
now=now+1
Memory.Observe(bot,J); enemy.visible=false; now=now+1
assert(Safety.IsCampDangerous(bot,J,near),'A recent team snapshot protects the destination')
enemy.x=-9000 -- hidden movement must not update the snapshot
assert(Safety.IsCampDangerous(bot,J,near),'Use the observed position, not actual hidden movement')
now=now+10
assert(not Safety.IsCampDangerous(bot,J,near),'Expired observations cannot lock a camp forever')
enemy.visible=true; enemy.x=1000; enemy.level=10; enemy.hp=100
assert(not Safety.IsCampDangerous(bot,J,near),'An easily killable opponent does not forbid the whole area')
assert(Safety.IsCampDangerous(bot,J,location(900)),'Reject an impassable camp')
assert(Safety.IsCampDangerous(bot,J,{cattr={}}),'Invalid camp locations are declined')
assert(Safety.ChooseCamp(bot,J,{cattr={}},near)==near,'An invalid current camp can be replaced safely')
assert(Safety.ChooseCamp(bot,J,nil,{cattr={}})==nil,'No unsafe fallback reintroduces a malformed camp')

-- Test the actual near-location helpers without loading unrelated game libraries.
local Runtime=require('bots/FunLib/shai_runtime')
GetTeamPlayers=function() return {} end
GetTeam=function() return 2 end
J.IsMeepoClone=function() return false end
enemy.HasModifier=function() return false end
dofile('.tools/lua/shai-location-helpers.lua')(J,Runtime)
local originalPrint,lines=print,{}
print=function(message) lines[#lines+1]=message end
assert(#J.GetEnemiesNearLoc(nil,1000)==0 and #J.GetAlliesNearLoc('invalid',1000)==0)
assert(#lines==2 and lines[1]:find('location.GetEnemiesNearLoc') and lines[1]:find('stack traceback'),
    'Invalid callers get source diagnostics before any engine distance call')
assert(not Runtime.Location(bot,'test.nan',{x=0/0,y=1}))
assert(not Runtime.Location(bot,'test.inf',{x=math.huge,y=1}))
print=originalPrint
assert(#J.GetEnemiesNearLoc(Vector(1000,0,0),100)==1)
enemy.visible=false
assert(#J.GetEnemiesNearLoc(Vector(1000,0,0),100)==0,'The helper must not inspect fogged heroes')
local bad=setmetatable({},{__tostring=function() error('broken tostring') end})
assert(Runtime.Call(bot,'test.bad-error',function() error(bad) end,17)==17,'Error reporting itself must tolerate a broken error object')
local savedDebug=debug
debug={traceback=function() error('broken traceback') end}
assert(Runtime.Call(bot,'test.bad-traceback',function() error('original') end,18)==18)
debug=savedDebug

-- Actual early roam + actual threat policy + actual hero intent predicates.
now=150; enemies={enemy}; enemy.visible=true; enemy.hp=2500; enemy.level=20; enemy.x=155
bot.IsInvulnerable=function() return false end
bot.IsHero=function() return true end
bot.IsIllusion=function() return false end
bot.HasModifier=function() return false end
bot.WasRecentlyDamagedByHero=function() return false end
bot.WasRecentlyDamagedByAnyHero=function() return false end
bot.GetLocation=function() return Vector(0,0,0) end
bot.GetActiveMode=function() return BOT_MODE_TEAM_ROAM end
bot.GetActiveModeDesire=function() return 0.8 end
bot.DistanceFromFountain=function() return 5000 end
bot.IsCastingAbility,bot.IsUsingAbility=function() return false end,function() return false end
bot.SetTarget=function(_,target) bot.target=target end
bot.Action_MoveToLocation=function(_,point) bot.destination=point end
enemy.IsStunned,enemy.IsHexed=function() return false end,function() return false end
enemy.GetAttackTarget=function() return bot end
enemy.IsFacingLocation=function() return true end
GetUnitToUnitDistance=function(a,b) return math.abs(a.x-b.x) end
BOT_MODE_TEAM_ROAM,BOT_MODE_LANING,BOT_MODE_RETREAT=10,11,12
J.GetNearbyHeroes=function(_,_,enemyTeam) return enemyTeam and enemies or {} end
J.GetHP=function() return 1 end
J.GetTeamFountain=function() return Vector(-6000,-6000,0) end
J.VectorAway=function(origin,threat,distance) return Vector(origin.x-distance,0,0) end
J.CanNotUseAction=function() return false end
J.Role.IsPvNMode=function() return false end
J.IsCore=function() return true end
J.CheckBotIdleState=function() return false end
J.GetMostPushLaneDesire,J.GetMostDefendLaneDesire=function() return 2 end,function() return 2 end
J.IsInLaningPhase,J.IsPushing=function() return true end,function() return false end
dofile('.tools/lua/shai-intent-helpers.lua')(J)
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/Customize/general']={Enable=true,ThinkLess=0}
package.loaded['bots/FunLib/localization']={}
package.loaded['bots/FunLib/utils']={SetFrameProcessTime=function() end}
package.loaded['bots/FunLib/enemy_role_estimation']={UpdateEnemyHeroPositions=function() end}
package.loaded['bots/FunLib/aba_item'],package.loaded['bots/FunLib/aba_role']={},{}
package.loaded['bots/FunLib/shai_combat_finish']={GetPlan=function() return nil end}
package.loaded['bots/FunLib/shai_defense']={GetDesire=function() return nil end}
package.loaded['bots/FunLib/shai_team_gank']={GetDesire=function() return nil end}
package.loaded['bots/FunLib/shai_tactical_travel']={HoldFade=function() return false end,ThinkFade=function() return false end}
local actualDofile=dofile
dofile=function(path)
    if path=='bots/FunLib/aba_special_units' then return {GetTombstoneDesire=function() error('Unsafe optional target must not be considered') end} end
    return actualDofile(path)
end
local roam=dofile('bots/mode_team_roam_generic.lua')
local optionalActions=0
ItemOpsDesire=function() end
ItemOpsThink=function() optionalActions=optionalActions+1 end
bot.target={name='courier'}
assert(GetDesire()==1.04,'Real early threat wins over a courier despite the lane soft cap')
roam.Think()
assert(bot.target==nil and bot.destination.x<0 and optionalActions==0,'Actual Think escapes instead of attacking the optional target')
assert(J.IsRetreating(bot) and not J.IsGoingOnSomeone(bot),'Hero spells interpret the selected roam intent as escape, not aggression')
now=now+1
assert(not J.IsRetreating(bot) and J.IsGoingOnSomeone(bot),'The intent classification expires without an executing escape')
GetDesire(); roam.Think(); OnEnd()
assert(bot.shaiEscapeUntil==nil,'Leaving roam clears the classification immediately')
print('PASS: actual camp selection, destination vision/memory/passability, finite vectors and resilient error diagnostics')
