package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_NONE,DAMAGE_TYPE_ALL,DAMAGE_TYPE_PHYSICAL,UNIT_LIST_ENEMY_HEROES=0,1,2,3
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=1000
DotaTime,GameTime=function() return now end,function() return now end
local bot={location=Vector(0,0),alive=true}
function bot:GetLocation() return self.location end
function bot:GetPlayerID() return 0 end
function bot:GetUnitName() return 'npc_dota_hero_zuus' end
function bot:IsAlive() return self.alive end
function bot:IsInvulnerable() return false end
function bot:HasModifier() return false end
function bot:IsCastingAbility() return self.casting or false end
function bot:IsUsingAbility() return false end
function bot:GetHealth() return 1000 end
function bot:GetLevel() return 10 end
function bot:GetAttackDamage() return 70 end
function bot:GetEstimatedDamageToTarget() return 140 end
function bot:GetActualIncomingDamage(raw) return raw end
function bot:GetNearbyTowers() return {} end
function bot:SetTarget(t) self.target=t end
function bot:Action_MoveToLocation(p) self.moved=p; self.moves=(self.moves or 0)+1 end
function bot:Action_ClearActions() self.clears=(self.clears or 0)+1; self.moved=nil end
local enemy={location=Vector(1350,0),visible=true,hp=2500,level=20}
function enemy:IsNull() return false end
function enemy:CanBeSeen() return self.visible end
local function Seen(h) assert(h.visible,'Never read hidden enemy state') end
function enemy:GetLocation() Seen(self); return self.location end
function enemy:GetHealth() Seen(self); return self.hp end
function enemy:GetLevel() Seen(self); return self.level end
function enemy:GetAttackRange() Seen(self); return 150 end
function enemy:GetCurrentMovementSpeed() Seen(self); return 300 end
function enemy:GetAttackDamage() Seen(self); return 400 end
function enemy:GetSecondsPerAttack() Seen(self); return 1 end
function enemy:GetEstimatedDamageToTarget() Seen(self); return 800 end
function enemy:GetPlayerID() return 10 end
function enemy:GetUnitName() return 'npc_dota_hero_pudge' end
function enemy:IsStunned() return false end
function enemy:IsHexed() return false end
function enemy:GetAttackTarget() return nil end
function enemy:IsFacingLocation() return true end
function bot:WasRecentlyDamagedByHero() return false end
local enemies={enemy}
GetUnitList=function() return enemies end
GetTeamMember=function() return nil end
local function Dist(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
GetUnitToLocationDistance=function(h,p) return Dist(h:GetLocation(),p) end
GetUnitToUnitDistance=function(a,b) return Dist(a:GetLocation(),b:GetLocation()) end
local passable=function() return true end
IsLocationPassable=function(p) return passable(p) end
local J={IsValidHero=function() return true end,IsSuspiciousIllusion=function() return false end}
J.GetNearbyHeroes=function(_,_,foe) return foe and bot.localThreat and enemies or {} end
J.CanNotUseAction=function(h) return h.busy or false end
J.GetTeamFountain=function() return Vector(-7000,0) end
require('bots/Customize/shai').BehaviorTrace=false
local Route=require('bots/FunLib/shai_route_safety')
local destination=Vector(2500,0)
local function Reset()
    now=now+10; bot.location=Vector(0,0); bot.shaiThreatMemory=nil
    bot.shaiRouteStep=nil; bot.shaiEscapeMove=nil; bot.shaiRouteBlockedAt=nil
    bot.shaiCentaurEscapeCast=nil
    bot.moved=nil; bot.moves=0; bot.clears=0; bot.busy=false; bot.casting=false; bot.alive=true; bot.localThreat=false
    enemy.visible=true; enemy.location=Vector(1350,0); enemy.hp=2500; enemy.level=20
    enemies={enemy}; passable=function() return true end
end
Reset(); enemies={}
Route.Move(bot,J,destination,'rune')
assert(bot.moved.x==900 and bot.moved.y==0,'Long journeys advance only one checked short step')
Route.Move(bot,J,Vector(300,0),'wisdom')
assert(bot.moved.x==300,'Nearby safe goal is preserved')
Reset(); Route.Move(bot,J,destination,'rune')
assert(bot.moved and math.abs(bot.moved.y)>100 and bot.moved.x>0,'Strong visible enemy on direct leg causes a progressive detour')
local chosen=bot.moved
now=now+0.1; enemy.location=Vector(1400,0)
Route.Move(bot,J,destination,'rune')
assert(bot.moved==chosen,'Short stable detour is rechecked instead of switching side each tick')
now=now+0.1; passable=function(p) return Dist(p,chosen)>10 end
Route.Move(bot,J,destination,'rune')
assert(bot.moved~=chosen,'Newly blocked endpoint cannot survive the route lease')
Reset(); passable=function(p) return p.y==0 end
Route.Move(bot,J,destination,'rune')
assert(not bot.moved and bot.clears==1,'No safe progressive alternative cancels stale route rather than falling through')
Route.Move(bot,J,destination,'rune'); assert(bot.clears==1,'Blocked clears are throttled')
now=now+0.6; Route.Move(bot,J,destination,'rune'); assert(bot.clears==1,'Persistent blockage does not cancel rescue actions repeatedly')
Reset(); enemies={}; passable=function(p) return not (p.x>200 and p.x<500 and math.abs(p.y)<100) end
Route.Move(bot,J,destination,'rune')
assert(bot.moved and math.abs(bot.moved.y)>100,'Passable destination behind a blocked ground segment requires a sampled detour')
Reset(); passable=function(p) return p.y==0 end
Route.Move(bot,J,destination,'rune'); assert(bot.clears==1)
passable=function() return true end; enemies={}; Route.Move(bot,J,destination,'rune')
assert(bot.shaiRouteBlockedAt==nil,'Accepted movement resets the blocked episode')
enemies={enemy}; passable=function(p) return p.y==0 end
Route.Move(bot,J,destination,'rune'); assert(bot.clears==2,'A new blockage may cancel the newly stale movement once')
Reset(); enemies={}; Route.Move(bot,J,destination,'rune')
bot.shaiCentaurEscapeCast={created=now,expires=now+0.65}
local before=bot.moves; Route.Move(bot,J,destination,'rune')
assert(bot.moves==before,'Centaur escape wind-up is not overwritten by another guarded move')
now=now+0.7; Route.Move(bot,J,destination,'rune'); assert(bot.moves>before,'Cast release guard expires')
bot.busy=true; local moves=bot.moves; Route.Move(bot,J,destination,'rune'); assert(bot.moves==moves,'Channel/queue guard')
bot.busy=false; bot.casting=true; Route.Move(bot,J,destination,'rune'); assert(bot.moves==moves,'Cast guard')
bot.casting=false; bot.alive=false; Route.Move(bot,J,destination,'rune'); assert(bot.moves==moves,'Dead guard')
Reset(); enemy.hp=100
Route.Move(bot,J,destination,'rune'); assert(bot.moved.x==900 and bot.moved.y==0,'Easily killable enemy does not seal the route')
Reset(); enemy.visible=false
Route.Move(bot,J,destination,'rune'); assert(bot.moved.x==900,'Never-observed hidden hero does not obstruct travel')
Reset(); Route.Move(bot,J,destination,'rune'); enemy.visible=false; now=now+1
Route.Move(bot,J,destination,'rune')
assert(bot.moved and math.abs(bot.moved.y)>100,'Recent observed danger still affects route after vision loss')
enemy.location=Vector(-8000,0); now=now+0.1
Route.Move(bot,J,destination,'rune')
assert(bot.moved and math.abs(bot.moved.y)>100,'Actual hidden relocation is not read')
now=now+10; Route.Move(bot,J,destination,'rune'); assert(bot.moved.x==900 and bot.moved.y==0,'Old memory expires')
Reset(); enemy.location=Vector(200,0); bot.localThreat=true
Route.Move(bot,J,destination,'rune')
assert(bot.moved and bot.moved.x<0,'Immediate danger uses existing escape before optional travel')
Reset(); Route.Move(bot,J,destination,'rune'); now=10; enemies={}; enemy.visible=false
Route.Move(bot,J,destination,'rune'); assert(bot.moved.x==900,'Clock rollback cannot preserve an old detour')
print('PASS: real short route, visible/fog threats, detour recheck, blocked fallback, immediate escape, expiry and action guards')
Reset(); enemies={}; bot.shaiWisdomAttempt=nil
local Wisdom=require('bots/FunLib/shai_wisdom')
local shrine={location=Vector(500,0),status=false}
passable=function(p) return Dist(p,shrine.location)>50 end
local capturePoint=Wisdom.Point(bot,shrine,7)
assert(capturePoint and Dist(capturePoint,shrine.location)<250)
Route.Move(bot,J,capturePoint,'wisdom')
assert(bot.moved==capturePoint and bot.clears==0,'Real route reaches an in-circle passable endpoint rather than rejecting an impassable shrine center')

-- Actual bounded return controller and actual team-roam integration.
RUNE_POWERUP_1,RUNE_POWERUP_2=2,3
BOT_ACTION_TYPE_PICK_UP_RUNE=7
function bot:GetCurrentActionType() return self.actionType or 0 end
GetRuneSpawnLocation=function() return Vector(0,0) end
GetLaneFrontLocation=function() return destination end
function bot:GetTeam() return 2 end
function bot:GetAssignedLane() return 2 end
function bot:IsHero() return true end
function bot:IsIllusion() return false end
function bot:WasRecentlyDamagedByAnyHero() return false end
J.GetPosition=function() return bot.role or 2 end
J.IsInTeamFight=function() return bot.fighting or false end
local Return=require('bots/FunLib/shai_rune_return')
Reset(); now=200; enemies={}
Return.Arm(bot,J,RUNE_POWERUP_1)
assert(Return.GetDesire(bot,J)==1.01,'Early mid rune departure creates a short guarded return')
bot.fighting=true; assert(Return.GetDesire(bot,J)==nil,'An active local fight temporarily yields to combat instead of forcing lane travel')
bot.fighting=false
Return.Think(bot,J); assert(bot.moved.x==900,'Actual return uses real short route rather than full lane destination')
bot.actionType=BOT_ACTION_TYPE_PICK_UP_RUNE; local pickupMoves=bot.moves
Return.Think(bot,J); assert(bot.moves==pickupMoves,'Pending rune pickup is preserved across mode departure')
bot.actionType=0
bot.busy=true; local n=bot.moves; Return.Think(bot,J); assert(bot.moves==n,'Return preserves a channel')
bot.busy=false; now=now+6.1
assert(Return.GetDesire(bot,J)==nil,'No progress expires the task instead of permanent travel priority')
now=210; Return.Arm(bot,J,RUNE_POWERUP_1); now=215; bot.location=Vector(500,0)
assert(Return.GetDesire(bot,J)); now=220; bot.location=Vector(1000,0); assert(Return.GetDesire(bot,J))
now=231; assert(Return.GetDesire(bot,J)==nil,'Even progressing travel has a total lifetime limit')
bot.location=Vector(0,0); now=240; Return.Arm(bot,J,RUNE_POWERUP_1)
bot.location=Vector(2200,0); assert(Return.GetDesire(bot,J)==nil,'Arriving near lane releases ordinary micro')
bot.location=Vector(0,0); bot.role=4; Return.Arm(bot,J,RUNE_POWERUP_1)
assert(bot.shaiRuneReturn==nil,'Support rotations are not turned into forced mid returns')
bot.role=2; Return.Arm(bot,J,0); assert(bot.shaiRuneReturn==nil,'Bounty/Wisdom trips are excluded')
now=700; Return.Arm(bot,J,RUNE_POWERUP_1); assert(bot.shaiRuneReturn==nil,'Late game river trips are excluded')
now=250; Return.Arm(bot,J,RUNE_POWERUP_1); now=100
assert(Return.GetDesire(bot,J)==nil,'Clock reset discards a future return')

local no=function() return false end
GetBot=function() return bot end; GetTeam=function() return 2 end
J.GetMostPushLaneDesire=function() return 0 end; J.GetMostDefendLaneDesire=J.GetMostPushLaneDesire
J.CheckBotIdleState=no; J.Role={IsPvNMode=no}; J.IsCore=function() return true end
J.IsInLaningPhase=function() return true end
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/FunLib/utils']={SetFrameProcessTime=function() end}
package.loaded['bots/FunLib/enemy_role_estimation']={UpdateEnemyHeroPositions=function() end}
package.loaded['bots/FunLib/localization']={}
package.loaded['bots/Customize/general']={}
package.loaded['bots/FunLib/shai_team_gank']={GetDesire=function() return nil end}
package.loaded['bots/FunLib/shai_combat_finish']={GetPlan=function() return bot.finish end,
    TryAction=function(h) h.action='finish'; return true end}
package.loaded['bots/FunLib/shai_defense']={GetDesire=function() return bot.defense end,Think=function(h) h.action='defense' end}
package.loaded['bots/FunLib/shai_recovery']={GetDesire=function() return nil end}
package.loaded['bots/FunLib/shai_tactical_travel']={HoldFade=no,ThinkFade=no}
package.loaded['bots/FunLib/shai_wraith_form']={GetPlan=function() return nil end,Think=no}
package.loaded['bots/FunLib/shai_invisible_escape']={GetPlan=function() return nil end,Think=no}
package.loaded['bots/FunLib/shai_tormentor']={Probe=function() end,OnEnd=function() end}
package.loaded['bots/FunLib/aba_item']={}; package.loaded['bots/FunLib/aba_role']={}
local actualDofile=dofile
dofile=function(path) if path=='bots/FunLib/aba_special_units' then return {GetTombstoneDesire=function() return 0 end} end return actualDofile(path) end
local roam=dofile('bots/mode_team_roam_generic.lua')
Reset(); enemies={}; now=260; Return.Arm(bot,J,RUNE_POWERUP_1)
assert(roam.GetDesire()==1.01,'Actual roam gives guarded return priority over native lane/courier micro without lane cap')
roam.Think(); assert(bot.moved.x==900,'Actual roam dispatches return through real route')
bot.defense=1.02; assert(roam.GetDesire()==1.02,'Ready defense wins over optional lane return')
bot.defense=nil; bot.finish={}; assert(roam.GetDesire()==1.05,'Lethal finish keeps its higher priority')
bot.finish=nil; assert(roam.GetDesire()==1.01)
enemy.location=Vector(200,0); enemies={enemy}; bot.localThreat=true; now=now+0.3
roam.Think()
assert(bot.moved and bot.moved.x<0 and bot.shaiEscapeUntil>now,'New danger during return Think triggers escape and permits Zeus escape spells')
print('PASS: actual bounded early mid rune return, progress/arrival/expiry, roles, clock reset and actual roam combat/escape priorities')
