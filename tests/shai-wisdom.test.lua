package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
package.loaded['bots/Customize/shai']={BehaviorTrace=false}
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=420
DotaTime=function() return now end
local bot={location=Vector(1000,0),alive=true}
function bot:GetLocation() return self.location end
function bot:IsAlive() return self.alive end
function bot:GetUnitName() return 'npc_dota_hero_axe' end
local pass=function(p) return p.x~=0 or p.y~=0 end
IsLocationPassable=function(p) return pass(p) end
local W=require('bots/FunLib/shai_wisdom')
local function spot() return {location=Vector(0,0),status=false} end
local s=spot()
local p=W.Point(bot,s,7)
assert(p and math.sqrt(p.x*p.x+p.y*p.y)<250 and IsLocationPassable(p),'Blocked center has a legal point strictly inside the existing capture area')
assert(W.Point(bot,s,7)==p,'Chosen reachable approach stays stable across callbacks')
pass=function() return false end
assert(W.Point(bot,s,7)==nil and s.retryAt==440,'Blocked alternative invalidates lease and defers')
now=430; assert(not W.Available(bot,s,7),'Cooldown does not repeatedly retry the same impassable destination')
now=440; pass=function() return true end
assert(W.Point(bot,s,7),'Retry resumes after fixed cooldown')
now=452.1; assert(not W.Available(bot,s,7),'No actual progress expires even when move commands are repeatedly issued')
now=480; bot.shaiWisdomAttempt=nil; s=spot(); W.Point(bot,s,7)
now=488; bot.location=Vector(850,0); assert(W.Available(bot,s,7),'Actual approach renews the progress window')
now=499; assert(W.Available(bot,s,7)); now=500.1; assert(not W.Available(bot,s,7),'Repeated oscillation without net progress cannot renew the attempt')
now=520; bot.location=Vector(100,0); s=spot()
assert(not W.ObserveCapture(bot,s,true)); now=522; W.ObserveCapture(bot,s,false)
now=525; assert(not W.ObserveCapture(bot,s,true)); now=528.6
assert(W.ObserveCapture(bot,s,true) and s.status,'Contested dwell restarts before completing')
assert(not bot.shaiWisdomAttempt and not W.Available(bot,s,7),'Completed spot is released')
now=550; s=spot(); W.ObserveCapture(bot,s,true)
local other={GetLocation=function() return Vector(100,0) end,IsAlive=function() return true end}
now=552; assert(not W.ObserveCapture(other,s,true),'A different collector cannot inherit another bot dwell')
W.ResetCapture(bot,s); assert(s.captureOwner==other,'Old collector cannot reset new collector dwell')
now=560; bot.location=Vector(400,0); W.ResetCapture(other,s)
now=570; s=spot(); bot.location=Vector(100,0); W.ObserveCapture(bot,s,true)
bot.location=Vector(400,0); W.Available(bot,s,7)
assert(s.captureStart==nil,'Desire evaluation notices actual departure even while another mode owns movement')
now=600; s=spot(); bot.location=Vector(1000,0); W.Point(bot,s,7)
now=590; assert(W.Available(bot,s,7) and not bot.shaiWisdomAttempt,'Clock rollback clears old attempt')
now=700; s=spot(); bot.location=Vector(1000,0); W.Point(bot,s,7)
for i=1,9 do now=700+i*10; bot.location=Vector(1000-i*70,0); if i<9 then assert(W.Available(bot,s,7)) end end
assert(not W.Available(bot,s,7),'Absolute attempt deadline bounds a long repeated approach')
print('PASS: Wisdom passable capture points, progress deadlines, cooldown, collector ownership and dwell')
