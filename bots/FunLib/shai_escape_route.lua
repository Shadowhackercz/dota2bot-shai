-- Bounded local escape choices. Passable samples are not a global pathfinder.
local X={}
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
function X.HoldingJump(bot)
    local p=bot.shaiJumpRelease
    if p==nil then return false end
    if not bot:IsAlive() or DotaTime()<p.created or DotaTime()>=p.untilTime then bot.shaiJumpRelease=nil; return false end
    return true
end
function X.HoldingAlignment(bot)
    local p=bot.shaiJumpAlign
    return p~=nil and bot:IsAlive() and DotaTime()>=p.created and DotaTime()-p.created<=0.65
end
local function Distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function Visible(h,J)
    return h~=nil and not h:IsNull() and h:CanBeSeen() and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
end
local function Context(bot,J,threat)
    local origin=bot:GetLocation()
    if not Runtime.Location(bot,'escape.origin',origin) or not Runtime.Location(bot,'escape.threat',threat.location) then return nil end
    local c={origin=origin,threat=threat.location,enemies={},towers={},fountain=J.GetTeamFountain()}
    if c.fountain~=nil and not Runtime.Location(bot,'escape.fountain',c.fountain) then c.fountain=nil end
    for _,h in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if Visible(h,J) then
            local location=h:GetLocation()
            if Runtime.Location(bot,'escape.enemy',location) then c.enemies[#c.enemies+1]={location=location,reach=h:GetAttackRange()+250} end
        end
    end
    if type(bot.GetNearbyTowers)=='function' then
        for _,h in pairs(bot:GetNearbyTowers(1600,true)) do
            if h~=nil and not h:IsNull() and h:CanBeSeen() and h:IsAlive() then
                local location=h:GetLocation()
                if Runtime.Location(bot,'escape.tower',location) then c.towers[#c.towers+1]={location=location,reach=h:GetAttackRange()+100} end
            end
        end
    end
    return c
end
local function Score(c,point,jump)
    if not IsLocationPassable(point) then return nil end
    local initial=Distance(c.origin,c.threat)
    local gain=Distance(point,c.threat)-initial
    if gain<100 then return nil end
    local steps=math.max(1,math.ceil(Distance(c.origin,point)/90))
    local terrain=false
    for i=1,steps do
        local p=Vector(c.origin.x+(point.x-c.origin.x)*i/steps,c.origin.y+(point.y-c.origin.y)*i/steps,c.origin.z)
        if not IsLocationPassable(p) then
            if not jump then return nil end
            terrain=true
        end
        if Distance(p,c.threat)<initial-25 then return nil end
        if not jump or i==steps then
            for _,h in ipairs(c.enemies) do
                if Distance(p,h.location)<h.reach and Distance(p,h.location)<Distance(c.origin,h.location)-50 then return nil end
            end
            for _,h in ipairs(c.towers) do
                if Distance(p,h.location)<h.reach and Distance(p,h.location)<Distance(c.origin,h.location)-25 then return nil end
            end
        end
    end
    if jump then
        -- Give the landing some room, including an exit, rather than targeting
        -- a single passable pixel on a cliff/tree boundary.
        local dx,dy=point.x-c.origin.x,point.y-c.origin.y
        local length=math.sqrt(dx*dx+dy*dy)
        for _,offset in ipairs({{45,0},{-45,0},{0,45},{0,-45},{dx/length*100,dy/length*100}}) do
            if not IsLocationPassable(Vector(point.x+offset[1],point.y+offset[2],point.z)) then return nil end
        end
    end
    local score=gain
    if c.fountain~=nil and type(c.fountain.x)=='number' and type(c.fountain.y)=='number' then
        score=score+(Distance(c.origin,c.fountain)-Distance(point,c.fountain))*0.35
    end
    for _,h in ipairs(c.enemies) do score=score-math.max(0,h.reach-Distance(point,h.location))*0.5 end
    return score,terrain
end
function X.Plan(bot,J,threat,distance,jump)
    if threat==nil or type(distance)~='number' or distance<100 or distance>1000 then return nil end
    local c=Context(bot,J,threat)
    if c==nil then return nil end
    local aligned=jump and bot.shaiJumpAlign and bot.shaiJumpAlign.plan or nil
    if aligned~=nil and Distance(c.threat,aligned.threat)<200 then
        local point=Vector(c.origin.x+aligned.dx*distance,c.origin.y+aligned.dy*distance,c.origin.z)
        local score,terrain=Score(c,point,true)
        if score~=nil then return {point=point,dx=aligned.dx,dy=aligned.dy,score=score,terrain=terrain,threat=aligned.threat,created=aligned.created} end
    end
    local lease=not jump and bot.shaiEscapeMove or nil
    if lease~=nil and DotaTime()>=lease.created and DotaTime()-lease.created<0.65
        and Distance(c.origin,lease.point)>100 and Distance(c.threat,lease.threat)<200
        and Score(c,lease.point,false)~=nil then return lease end
    local dx,dy=c.origin.x-c.threat.x,c.origin.y-c.threat.y
    local length=math.sqrt(dx*dx+dy*dy)
    if length<1 then
        if c.fountain==nil then return nil end
        dx,dy=c.fountain.x-c.origin.x,c.fountain.y-c.origin.y
        length=math.sqrt(dx*dx+dy*dy)
    end
    if length<1 then return nil end
    dx,dy=dx/length,dy/length
    local best
    for _,degrees in ipairs({0,30,-30,60,-60,90,-90,120,-120}) do
        local a=degrees*math.pi/180
        local ux,uy=dx*math.cos(a)-dy*math.sin(a),dx*math.sin(a)+dy*math.cos(a)
        local point=Vector(c.origin.x+ux*distance,c.origin.y+uy*distance,c.origin.z)
        local score,terrain=Score(c,point,jump)
        if score~=nil and (best==nil or score>best.score) then
            best={point=point,dx=ux,dy=uy,score=score,terrain=terrain,threat=Vector(c.threat.x,c.threat.y,c.threat.z),created=DotaTime()}
        end
    end
    if not jump then bot.shaiEscapeMove=best end
    return best
end
local function Trace(bot,reason,plan)
    if not SHAI.BehaviorTrace or bot.shaiEscapeReason==reason and DotaTime()-(bot.shaiEscapePrinted or -math.huge)<3 then return end
    bot.shaiEscapePrinted,bot.shaiEscapeReason=DotaTime(),reason
    print('[SHAI] escape t='..tostring(DotaTime())..'; hero='..bot:GetUnitName()..'; reason='..reason
        ..'; terrain='..tostring(plan and plan.terrain or false)
        ..'; x='..tostring(plan and plan.point.x or '-')..'; y='..tostring(plan and plan.point.y or '-'))
end
function X.Move(bot,J,threat)
    if bot.shaiEscapeBlockedAt~=nil and DotaTime()<bot.shaiEscapeBlockedAt then bot.shaiEscapeBlockedAt=nil end
    local plan=X.Plan(bot,J,threat,650,false) or X.Plan(bot,J,threat,300,false) or X.Plan(bot,J,threat,150,false)
    if plan~=nil then
        bot:Action_MoveToLocation(plan.point); Trace(bot,'local-retreat',plan)
    else
        -- Do not reinstate the very straight-line destination rejected above.
        -- Keep normal item/hero save callbacks available, cancel stale farming.
        if DotaTime()-(bot.shaiEscapeBlockedAt or -math.huge)>0.5 then
            bot:Action_ClearActions(false); bot.shaiEscapeBlockedAt=DotaTime()
        end
        Trace(bot,'no-safe-local-step')
    end
    return true
end
function X.TryZeusJump(bot,J,ability,threat,CastSafety)
    local now=DotaTime()
    if bot.shaiJumpChecked~=nil and now<bot.shaiJumpChecked then
        bot.shaiJumpAlign=nil; bot.shaiJumpRetry=nil; bot.shaiJumpRelease=nil
    end
    bot.shaiJumpChecked=now
    if X.HoldingJump(bot) then return true end
    if ability==nil or not ability:IsFullyCastable() or ability:IsHidden() or bot:IsRooted()
        or J.CanNotUseAbility(bot) or J.CanNotUseAction(bot) then return false end
    if threat==nil then bot.shaiJumpAlign=nil; return false end
    if now<(bot.shaiJumpRetry or -math.huge) then return false end
    local attempt=bot.shaiJumpAlign
    if attempt~=nil and (now<attempt.created or now-attempt.created>0.65) then
        bot.shaiJumpAlign=nil; bot.shaiJumpRetry=now+1; Trace(bot,'jump-align-timeout'); return false
    end
    local plan=X.Plan(bot,J,threat,ability:GetSpecialValueInt('hop_distance'),true)
    if plan==nil then bot.shaiJumpAlign=nil; Trace(bot,'no-safe-jump-landing'); return false end
    if not CastSafety.Allow(bot,J,ability,'escape') then bot.shaiJumpAlign=nil; return false end
    if bot:IsFacingLocation(plan.point,12) and J.IsRunning(bot) then
        -- Direct no-target dispatch preserves locomotion; a tread-switch queue
        -- or stationary optional nuke must not choose the jump direction.
        bot:Action_UseAbility(ability)
        local duration=ability:GetSpecialValueFloat('hop_duration')
        bot.shaiJumpRelease={created=now,untilTime=now+math.min(1,math.max(0.2,duration))}
        bot.shaiJumpAlign=nil; Trace(bot,'jump-issued',plan); return true
    end
    bot.shaiJumpAlign=attempt or {created=now,plan=plan}
    bot.shaiTacticalUntil=now+0.3
    bot:Action_MoveDirectly(plan.point)
    Trace(bot,'align-jump',plan)
    return true
end
return X
