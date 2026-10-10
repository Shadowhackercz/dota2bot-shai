package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
UNIT_LIST_ENEMY_HEROES=2
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=900
DotaTime=function() return now end
local bot,enemies,blocked,towers
local function hero(x,y)
    local h={location=Vector(x,y),visible=true}
    function h:IsNull() return false end
    function h:CanBeSeen() return self.visible end
    function h:IsAlive() assert(self.visible); return true end
    function h:GetLocation() assert(self.visible,'Hidden location read'); return self.location end
    function h:GetAttackRange() assert(self.visible,'Hidden range read'); return 500 end
    return h
end
local function reset()
    now=now+5; bot=hero(0,0); enemies={hero(200,0)}; towers={}; blocked=function() return false end
    bot.facing=0; bot.running=false
    function bot:GetFacing() return self.facing end
    function bot:GetPlayerID() return 1 end
    function bot:GetUnitName() return 'npc_dota_hero_zuus' end
    function bot:GetNearbyTowers() return towers end
    function bot:IsRooted() return self.rooted or false end
    function bot:IsFacingLocation(p,degrees)
        local dx,dy=p.x-self.location.x,p.y-self.location.y
        local a=self.facing*math.pi/180
        return (dx*math.cos(a)+dy*math.sin(a))/math.sqrt(dx*dx+dy*dy)>=math.cos(degrees*math.pi/180)
    end
    function bot:Action_MoveDirectly(p) self.action='align'; self.destination=p; self.moves=(self.moves or 0)+1 end
    function bot:Action_MoveToLocation(p) self.action='move'; self.destination=p end
    function bot:Action_ClearActions() self.action='clear'; self.clears=(self.clears or 0)+1 end
    function bot:Action_UseAbility(a) self.action='jump'; self.casts=(self.casts or 0)+1 end
end
GetUnitList=function() return enemies end
IsLocationPassable=function(p) return not blocked(p) end
local J={IsValidHero=function() return true end,IsSuspiciousIllusion=function() return false end,
    GetTeamFountain=function() return Vector(-6000,0) end,
    CanNotUseAbility=function(h) return h.busy or false end,CanNotUseAction=function(h) return h.busy or false end,
    IsRunning=function(h) return h.running end}
local cast={Allow=function() return true end}
local a={distance=450,ready=true}
function a:IsFullyCastable() return self.ready end
function a:IsHidden() return false end
function a:GetSpecialValueInt(key) return key=='hop_distance' and self.distance or 0 end
function a:GetSpecialValueFloat(key) return key=='hop_duration' and 0.5 or 0 end
require('bots/Customize/shai').BehaviorTrace=false
local Route=require('bots/FunLib/shai_escape_route')
local Farm=require('bots/FunLib/shai_farm_safety')
local function threat() return {location=Vector(200,0)} end
reset(); local p=Route.Plan(bot,J,threat(),650,false)
assert(p and p.point.x<0 and IsLocationPassable(p.point),'Ordinary escape increases separation toward home')
local old=p.point; now=now+0.1
assert(Route.Plan(bot,J,threat(),650,false).point==old,'Safe local direction is stable briefly')
blocked=function(v) return v.x< -150 and v.x> -500 and math.abs(v.y)<80 end
p=Route.Plan(bot,J,threat(),650,false)
assert(p and math.abs(p.point.y)>80,'A blocked straight segment forces a legal lateral route even with passable endpoint')
reset(); enemies[2]=hero(-650,0)
p=Route.Plan(bot,J,threat(),650,false)
assert(p and math.abs(p.point.y)>100,'Avoid escaping straight into another visible enemy')
enemies[2].visible=false
p=Route.Plan(bot,J,threat(),450,true)
assert(p and p.point.x<0,'Unseen unobserved enemy does not reveal its hidden location')
reset(); towers={hero(-650,0)}
p=Route.Plan(bot,J,threat(),650,false)
assert(p==nil or math.abs(p.point.y)>100,'Do not route farther into an enemy tower footprint')
reset(); blocked=function(v) return v.x< -150 and v.x> -300 end
local walk=Route.Plan(bot,J,threat(),450,false)
assert(walk==nil or walk.point.x>= -150,'Walk cannot cross a blocked strip; a legal detour is allowed')
p=Route.Plan(bot,J,threat(),450,true)
assert(p and p.terrain and p.point.x< -300,'Jump may cross blocked intermediate terrain to a clear landing and exit')
reset(); blocked=function(v) return v.x< -100 and v.x> -300 and v.y< -30 end
p=Route.Plan(bot,J,threat(),450,true)
assert(p and p.terrain,'A safe nearby terrain crossing can outrank a slightly longer straight escape')
blocked=function(v) return v.x*v.x+v.y*v.y>10000 end
assert(Route.Plan(bot,J,threat(),450,true)==nil,'No jump into blocked landing')
reset(); a.distance=375; p=Route.Plan(bot,J,threat(),a:GetSpecialValueInt('hop_distance'),true)
assert(math.abs(p.point.x+375)<0.01,'Jump range comes from the current learned ability')
assert(Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action=='align' and not bot.casts,'Facing the enemy issues alignment, never the jump')
assert(Route.HoldingAlignment(bot),'A selected alignment has a bounded reservation against ground path overwrite')
assert(Farm.InterruptFarm(bot,J) and bot.action=='align','Actual farm interrupt preserves alignment instead of issuing a ground detour')
bot.facing=180; bot.running=true; now=now+0.1
assert(Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action=='jump' and bot.casts==1,'Aligned moving bot releases the jump')
assert(Route.TryZeusJump(bot,J,a,threat(),cast) and bot.casts==1,'Release reservation prevents repeating the cast')
now=now+0.6; assert(not Route.HoldingJump(bot),'Jump reservation is bounded')
reset(); a.distance=450
blocked=function(v) return v.x< -100 and v.x> -300 end
assert(Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action=='align','Blocked intermediate cliff permits preparing the jump')
assert(bot.destination.x>= -80 and IsLocationPassable(bot.destination),'Alignment walks only on the takeoff side, never toward far-side landing')
bot.location=Vector(-40,0); bot.facing=180; bot.running=true; now=now+0.1
assert(Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action=='jump','Moving from takeoff rechecks and releases a crossing jump')
reset(); blocked=function(v) return v.x< -100 and v.x> -300 end
bot.facing=170; bot.running=true
-- The planned west landing is clear, but the actual heading lands in a small
-- blocked patch. A nominal 12-degree alignment must not authorize that cast.
blocked=function(v) return v.x< -100 and v.x> -300 or v.x< -420 and v.y>55 and v.y<100 end
assert(Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action=='align' and not bot.casts,'Actual heading landing is checked in addition to nominal facing tolerance')
reset(); blocked=function(v) return v.x< -10 and v.x> -300 end
assert(not Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action==nil,'No passable run-up rejects walking into a cliff')
bot.facing=180; bot.running=true; now=now+0.4
assert(Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action=='jump','Already moving and aligned can jump at the cliff edge without demanding a run-up')
reset(); a.distance=450
Route.TryZeusJump(bot,J,a,threat(),cast); now=now+0.7
assert(not Route.TryZeusJump(bot,J,a,threat(),cast) and not bot.casts,'Failed alignment expires and permits normal retreat instead of locking the bot')
now=10; assert(Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action=='align','Clock rollback clears an old retry/cast lease')
reset(); Route.TryZeusJump(bot,J,a,threat(),cast)
bot.facing=180; bot.running=true; blocked=function(v) return v.x*v.x+v.y*v.y>10000 end
assert(not Route.TryZeusJump(bot,J,a,threat(),cast) and not bot.casts,'Recheck rejects the landing when it becomes blocked during alignment')
reset(); bot.rooted=true
assert(not Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action==nil,'Root prevents alignment and jump')
bot.rooted=false; bot.busy=true
assert(not Route.TryZeusJump(bot,J,a,threat(),cast),'Channel/queued action is preserved')
bot.busy=false; cast.Allow=function() return false end
assert(not Route.TryZeusJump(bot,J,a,threat(),cast) and bot.action==nil,'Fatal casting penalty cannot be bypassed')
cast.Allow=function() return true end; a.distance=0
assert(not Route.TryZeusJump(bot,J,a,threat(),cast),'Unknown ability distance is not replaced by an invented value')
reset(); blocked=function() return true end
Route.Move(bot,J,threat()); Route.Move(bot,J,threat())
assert(bot.action=='clear' and bot.clears==1,'Blocked escape cancels stale attacks once without a clear-action loop')
now=now+2; bot.action='save-spell'
Route.Move(bot,J,threat())
assert(bot.action=='save-spell' and bot.clears==1,'Persistent blockage never periodically clears a rescue issued by another callback')
bot.busy=true; now=now+1; Route.Move(bot,J,threat())
assert(bot.action=='save-spell' and bot.clears==1,'Blocked path respects queued/channel action guard')
reset()
blocked=function(v) return v.x< -10 and math.abs(v.y)<120 or math.abs(v.y)>250 end
assert(Route.Plan(bot,J,threat(),650,false)==nil and Route.Plan(bot,J,threat(),300,false)==nil
    and Route.Plan(bot,J,threat(),150,false)==nil,'Fixture needs a sideways step before any separating leg')
Route.Move(bot,J,threat())
assert(bot.action=='move' and bot.shaiEscapeDetour,'A sampled two-leg path escapes the corner without arbitrary threat approach')
local detour=bot.shaiEscapeDetour
assert(math.abs(detour.point.y)>=120 and detour.exit.x< -100,'First step clears corner and second actually gains separation')
now=now+0.1; Route.Move(bot,J,threat())
assert(bot.destination==detour.point,'Selected sideways step remains stable while safe')
bot.location=detour.point; Route.Move(bot,J,threat())
assert(bot.destination.x<bot.location.x and bot.shaiEscapeDetour==nil,'After reaching waypoint normal retreat takes over')
reset(); blocked=function(v) return v.x< -10 and math.abs(v.y)<120 or math.abs(v.y)>250 end
Route.Move(bot,J,threat()); now=now+2.1; Route.Move(bot,J,threat())
assert(bot.action=='clear' and bot.shaiEscapeDetour==nil,'Unreached sideways waypoint expires instead of renewing forever')
local clears=bot.clears; now=now+0.5; Route.Move(bot,J,threat())
assert(bot.clears==clears and bot.shaiEscapeDetour==nil,'Expired detour has retry delay and no repeated clearing')
now=now-10; Route.Move(bot,J,threat())
assert(bot.shaiEscapeDetour,'Clock reset discards future detour retry')
reset(); blocked=function(v) return v.x< -10 and math.abs(v.y)<120 or math.abs(v.y)>250 end
Route.Move(bot,J,threat()); blocked=function() return true end
now=now+0.1; Route.Move(bot,J,threat())
assert(bot.action=='clear' and bot.shaiEscapeDetour==nil,'New terrain blockage invalidates cached two-leg path')
reset(); blocked=function(v) return v.x< -10 and math.abs(v.y)<120 or math.abs(v.y)>250 end
enemies[2]=hero(-100,150)
enemies[3]=hero(-100,-150)
Route.Move(bot,J,threat())
assert(bot.shaiEscapeDetour==nil,'No sideways shortcut into a second visible enemy')
enemies[2].visible=false; enemies[3].visible=false; now=now+3; Route.Move(bot,J,threat())
assert(bot.shaiEscapeDetour,'Hidden enemy stats are not read by new fallback')
Route.ResetGround(bot)
assert(bot.shaiEscapeDetour==nil and bot.shaiEscapeBlockedAt==nil and bot.shaiEscapeDetourRetry==nil,'New threat episode starts without old ground locks')
print('PASS: sampled escape routes, secondary visible threats/towers, fog, stable direction, terrain landing/exit, learned jump range, alignment/recheck/expiry, release and cast guards')
