-- Receding short travel steps around observed threats; no global path guarantee.
local X={}
local Safety=require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local function Distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function Trace(bot,reason,purpose,point)
    if not SHAI.BehaviorTrace then return end
    local now=DotaTime()
    if bot.shaiRoutePrinted and now>=bot.shaiRoutePrinted and now-bot.shaiRoutePrinted<3
        and bot.shaiRouteReason==reason then return end
    bot.shaiRoutePrinted,bot.shaiRouteReason=now,reason
    print('[SHAI] travel t='..now..'; hero='..bot:GetUnitName()..'; reason='..reason..'; purpose='..purpose
        ..'; x='..tostring(point and point.x or '-')..'; y='..tostring(point and point.y or '-'))
end
function X.Move(bot,J,destination,purpose)
    if not bot:IsAlive() then return end
    if J.CanNotUseAction(bot) or bot:IsCastingAbility() or bot:IsUsingAbility() then return end
    if Safety.InterruptFarm(bot,J) then return end
    local origin=bot:GetLocation()
    if not Runtime.Location(bot,'travel.route-origin',origin)
        or not Runtime.Location(bot,'travel.route-destination',destination) then return end
    local distance=Distance(origin,destination)
    if distance<1 then return end
    local threats=Safety.LocationThreats(bot,J)
    local function Safe(point)
        if not IsLocationPassable(point) then return false end
        local length=Distance(origin,point)
        local steps=math.max(1,math.ceil(length/120))
        for i=1,steps do
            local p=Vector(origin.x+(point.x-origin.x)*i/steps,origin.y+(point.y-origin.y)*i/steps,origin.z)
            -- Reject a sampled cliff/tree barrier; a passable endpoint alone
            -- could make engine pathing take an unexamined route around it.
            if not IsLocationPassable(p) then return false end
            if Safety.GetLocationConcern(bot,J,p,threats) then return false end
        end
        return true
    end
    local ux,uy=(destination.x-origin.x)/distance,(destination.y-origin.y)/distance
    local lease=bot.shaiRouteStep
    if lease and DotaTime()>=lease.created and DotaTime()-lease.created<0.65
        and Distance(lease.destination,destination)<150 and Distance(origin,lease.point)>100
        and distance-Distance(lease.point,destination)>=50 and Safe(lease.point) then
        bot.shaiRouteBlockedAt=nil; bot:Action_MoveToLocation(lease.point); return
    end
    bot.shaiRouteStep=nil
    local length=math.min(900,distance)
    local straight=distance<=900 and destination or Vector(origin.x+ux*length,origin.y+uy*length,origin.z)
    if Safe(straight) then
        bot.shaiRouteBlockedAt=nil; bot:Action_MoveToLocation(straight)
        if purpose=='rune-return' then Trace(bot,'return-step',purpose,straight) end
        return
    end
    local best,progress
    for _,step in ipairs({600,300}) do
        for _,degrees in ipairs({45,-45,70,-70,90,-90}) do
            local a=degrees*math.pi/180
            local dx,dy=ux*math.cos(a)-uy*math.sin(a),ux*math.sin(a)+uy*math.cos(a)
            local p=Vector(origin.x+dx*step,origin.y+dy*step,origin.z)
            local gain=distance-Distance(p,destination)
            if gain>=100 and (best==nil or gain>progress) and Safe(p) then best,progress=p,gain end
        end
    end
    if best then
        bot.shaiRouteBlockedAt=nil
        bot.shaiRouteStep={point=best,destination=Vector(destination.x,destination.y,destination.z),created=DotaTime()}
        bot:Action_MoveToLocation(best); Trace(bot,'route-detour',purpose,best)
    else
        -- Never fall through to the rejected direct move or an old pickup path.
        local now=DotaTime()
        if bot.shaiRouteBlockedAt==nil or now<bot.shaiRouteBlockedAt then
            bot:Action_ClearActions(false); bot.shaiRouteBlockedAt=now
        end
        Trace(bot,'route-blocked',purpose,destination)
    end
end
return X
