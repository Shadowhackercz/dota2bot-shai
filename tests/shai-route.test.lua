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
now=now+0.6; Route.Move(bot,J,destination,'rune'); assert(bot.clears==2)
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
