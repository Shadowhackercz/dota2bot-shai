-- Bounded Wisdom approaches. Dwell completion is an inference, not an XP event.
local X={}
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local function Distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function Trace(bot,spot,reason)
    if not SHAI.BehaviorTrace then return end
    print('[SHAI] wisdom t='..DotaTime()..'; hero='..bot:GetUnitName()..'; reason='..reason
        ..'; x='..spot.location.x..'; y='..spot.location.y)
end
local function Defer(bot,spot)
    spot.retryAt=DotaTime()+20
    spot.captureStart,spot.captureOwner=nil,nil
    bot.shaiWisdomAttempt=nil
    Trace(bot,spot,'no-progress-deferred')
end
function X.Available(bot,spot,cycle)
    local now=DotaTime()
    if spot.captureOwner==bot and (not bot:IsAlive() or Distance(bot:GetLocation(),spot.location)>=250) then
        X.ResetCapture(bot,spot)
    end
    if spot.retryAt then
        if now<spot.retryAt and now>=spot.retryAt-20 then return false end
        spot.retryAt=nil
    end
    local a=bot.shaiWisdomAttempt
    if a and a.spot==spot and a.cycle==cycle then
        if now<a.started then bot.shaiWisdomAttempt=nil
        else
            local distance=Distance(bot:GetLocation(),spot.location)
            if distance<250 then a.progressAt=now
            elseif distance<a.best-60 then a.best,a.progressAt=distance,now end
            if now-a.progressAt>=12 or now-a.started>=90 then Defer(bot,spot); return false end
        end
    end
    return not spot.status
end
function X.Point(bot,spot,cycle)
    if not X.Available(bot,spot,cycle) then return nil end
    local a=bot.shaiWisdomAttempt
    if not a or a.spot~=spot or a.cycle~=cycle then
        a={spot=spot,cycle=cycle,started=DotaTime(),progressAt=DotaTime(),
            best=Distance(bot:GetLocation(),spot.location)}
        bot.shaiWisdomAttempt=a
    end
    if a.point and IsLocationPassable(a.point) then return a.point end
    local center,origin=spot.location,bot:GetLocation()
    local best,score
    -- Keep every candidate strictly inside the existing 250-unit capture policy.
    -- A blocked shrine center must not force an impossible exact-center move.
    for _,radius in ipairs({0,160,220}) do
        for i=0,(radius==0 and 0 or 15) do
            local angle=i*math.pi/8
            local p=Vector(center.x+radius*math.cos(angle),center.y+radius*math.sin(angle),center.z)
            if IsLocationPassable(p) then
                local distance=Distance(origin,p)
                if not best or distance<score then best,score=p,distance end
            end
        end
    end
    a.point=best
    if not best then Defer(bot,spot); return nil end
    Trace(bot,spot,'approach-point')
    return best
end
function X.ResetCapture(bot,spot)
    if spot.captureOwner==nil or spot.captureOwner==bot then spot.captureStart,spot.captureOwner=nil,nil end
end
function X.ObserveCapture(bot,spot,safe)
    if not safe or not bot:IsAlive() or Distance(bot:GetLocation(),spot.location)>=250 then
        X.ResetCapture(bot,spot); return false
    end
    if spot.captureOwner~=bot or spot.captureStart==nil or DotaTime()<spot.captureStart then
        spot.captureStart,spot.captureOwner=DotaTime(),bot
    end
    if DotaTime()-spot.captureStart>=3.5 then
        spot.status=true
        spot.captureStart,spot.captureOwner=nil,nil
        bot.shaiWisdomAttempt=nil
        Trace(bot,spot,'capture-dwell-complete')
        return true
    end
    return false
end
return X
