package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_DESIRE_NONE=0
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=1000
DotaTime,GameTime=function() return now end,function() return now end
local bot,human,second
local J={}
J.IsValidHero=function(h) return h~=nil end
J.IsRetreating=function(h) return h.retreat or false end
J.IsInTeamFight=function(h) return h.fighting or false end
J.CanNotUseAction=function(h) return h.busy or false end
J.GetDistance=function(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
J.ModeAnnounce=function(h) h.announces=(h.announces or 0)+1 end
package.loaded['bots/FunLib/jmz_func']=J
require('bots/Customize/shai').BehaviorTrace=false
local function hero(id,isBot)
    local h={id=id,location=Vector(-1000,0),alive=true}
    function h:GetPlayerID() return self.id end
    function h:IsAlive() return self.alive end
    function h:IsBot() return isBot end
    function h:IsHero() return true end
    function h:IsIllusion() return false end
    function h:IsInvulnerable() return false end
    function h:GetUnitName() return 'npc_dota_hero_lion' end
    function h:GetMostRecentPing() return self.ping end
    function h:WasRecentlyDamagedByAnyHero() return self.damaged or false end
    function h:Action_MoveToLocation(p) self.moved=p; self.moves=(self.moves or 0)+1 end
    return h
end
GetTeamMember=function(slot) return slot==1 and bot or slot==2 and human or slot==3 and second or nil end
GetUnitToLocationDistance=function(h,p) return J.GetDistance(h.location,p) end
GetBot=function() return bot end
local function reset()
    now=now+10; bot,human,second=hero(1,true),hero(2,false),hero(3,false)
    dofile('bots/mode_assemble_generic.lua')
end
local function ping(h,normal,p)
    h.ping={time=now,normal_ping=normal,location=p or Vector(0,0)}
    return GetDesire()
end
reset(); assert(ping(human,true)==0,'Single informational ping does not summon bots')
now=now+0.5; assert(ping(human,true)==0.85,'Two fresh same-player pings at one place form an assembly request')
Think(); assert(bot.moves==1,'Actual mode walks after deliberate request')
GetDesire(); GetDesire(); assert(bot.announces==1,'An unchanged latest ping cannot repeat announcements')
now=now+5.1; assert(GetDesire()==0,'Repeated observations never extend the original five-second deadline')
Think(); assert(bot.moves==1,'Expired request cannot still move from Think')
reset(); ping(human,true); now=now+0.5
assert(ping(second,true)==0,'Pings from two different people are not a single repeated instruction')
now=now+0.5; assert(ping(second,true)==0.85,'Every human can deliberately request, not just the first human slot')
reset(); ping(human,true); now=now+2
assert(ping(human,true)==0,'Widely separated informational pings do not combine')
reset(); ping(human,true); now=now+0.5
assert(ping(human,true,Vector(1200,0))==0,'Different locations do not combine')
reset(); ping(human,true); now=now+0.5
assert(ping(human,false)==0,'A danger ping is never a gather instruction')
now=now+0.5; assert(ping(human,true)==0,'Danger breaks the normal-ping pair')
reset(); human.ping={time=now+1,normal_ping=true,location=Vector(0,0)}
assert(GetDesire()==0,'Future timestamp is ignored')
human.ping={time=now,normal_ping=true,location={x=0,y=math.huge,z=0}}
assert(GetDesire()==0,'Malformed ping cannot reach a vector API')
reset(); ping(human,true); now=now+0.5; ping(human,true)
bot.retreat=true; assert(GetDesire()==0,'A deliberate request does not override a current retreat')
bot.retreat=false; assert(GetDesire()==0,'Aborted request does not rearm from the same ping')
reset(); ping(human,true); now=now+0.5; ping(human,true)
bot.busy=true; Think(); assert(not bot.moves,'Queue/channel/cast guard is respected')
bot.busy=false; bot.damaged=true; Think(); assert(not bot.moves,'New damage aborts movement before another desire evaluation')
reset(); ping(human,true); now=now+0.5; ping(human,true)
bot.alive=false; Think(); assert(not bot.moves and GetDesire()==0,'Dead bot cannot follow stale request')
reset(); ping(human,true); now=now+0.5; ping(human,true)
bot.location=Vector(-400,0); assert(GetDesire()==0,'Arrival consumes assembly request')
bot.location=Vector(-1000,0); assert(GetDesire()==0,'Leaving arrival radius cannot replay the same request')
reset(); ping(human,true); now=now+0.5; ping(human,true)
OnEnd(); assert(GetDesire()==0,'Leaving mode consumes the observed request instead of replaying it')
reset(); ping(human,true); now=now+0.5; ping(human,true)
now=10; assert(GetDesire()==0,'Game clock reset discards old assembly deadline')
print('PASS: actual assemble single/double/danger intent, multiple humans, vectors/time, finite lease, announce, arrival/exit and combat/action guards')
