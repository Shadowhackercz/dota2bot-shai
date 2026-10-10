-- Short, bounded recovery near our fountain; not a global retreat planner.
local X={}
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
local Farm=require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local Escape=require(GetScriptDirectory()..'/FunLib/shai_escape_route')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local function Distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function Trace(bot,reason)
    if not SHAI.BehaviorTrace or bot.shaiRecoveryReason==reason and DotaTime()-(bot.shaiRecoveryPrinted or -math.huge)<3 then return end
    bot.shaiRecoveryReason,bot.shaiRecoveryPrinted=reason,DotaTime()
    print('[SHAI] recovery t='..DotaTime()..'; hero='..bot:GetUnitName()..'; reason='..reason)
end
function X.GetPlan(bot,J)
    local now=DotaTime()
    local s=bot.shaiRecovery
    if s and now<s.checked then bot.shaiRecovery=nil; bot.shaiRecoveryRetry=nil; s=nil end
    if not bot:IsAlive() or now<0 or bot:IsInvulnerable()
        or bot:HasModifier('modifier_skeleton_king_reincarnation_scepter_active') then
        bot.shaiRecovery=nil; return nil
    end
    local hp=J.GetHP(bot)
    if hp>=0.8 then bot.shaiRecovery=nil; return nil end
    if s==nil and (hp>=0.4 or now<(bot.shaiRecoveryRetry or -math.huge)) then return nil end
    local home=J.GetTeamFountain()
    local origin=bot:GetLocation()
    if not Runtime.Location(bot,'recovery.home',home) or not Runtime.Location(bot,'recovery.origin',origin) then return nil end
    local distance=Distance(origin,home)
    if distance>2200 then
        bot.shaiRecovery=nil; return nil
    end
    if s==nil then
        s={checked=now,progress=now,best=distance,bestHP=hp,created=now}
        bot.shaiRecovery=s
    end
    s.checked=now
    if distance<s.best-60 then s.best=distance; s.progress=now end
    if bot:HasModifier('modifier_fountain_aura_buff') and hp>s.bestHP+0.05 then s.bestHP=hp; s.progress=now end
    if now-s.progress>=12 or now-s.created>=45 then
        bot.shaiRecovery=nil; bot.shaiRecoveryRetry=now+3
        Trace(bot,'no-progress-release'); return nil
    end
    s.home,s.origin=home,origin
    return s
end
function X.GetDesire(bot,J)
    if X.GetPlan(bot,J)==nil then return nil end
    bot.shaiEscapeUntil=DotaTime()+0.75
    return 1.03
end
local function Step(bot,J,p)
    local distance=Distance(p.origin,p.home)
    if distance<1 then return nil end
    local dx,dy=(p.home.x-p.origin.x)/distance,(p.home.y-p.origin.y)/distance
    local threats=Farm.LocationThreats(bot,J)
    local towers=bot:GetNearbyTowers(1600,true)
    local best,bestGain
    for _,length in ipairs({math.min(650,distance),math.min(300,distance),math.min(150,distance)}) do
        for _,degrees in ipairs({0,30,-30,60,-60}) do
            local angle=degrees*math.pi/180
            local ux,uy=dx*math.cos(angle)-dy*math.sin(angle),dx*math.sin(angle)+dy*math.cos(angle)
            local point=Vector(p.origin.x+ux*length,p.origin.y+uy*length,p.origin.z)
            local gain=distance-Distance(point,p.home)
            local safe=gain>25
            for i=1,math.ceil(length/90) do
                local sample=Vector(p.origin.x+ux*length*i/math.ceil(length/90),p.origin.y+uy*length*i/math.ceil(length/90),p.origin.z)
                if not IsLocationPassable(sample) or Farm.GetLocationConcern(bot,J,sample,threats)~=nil then safe=false; break end
                for _,tower in ipairs(towers) do
                    if not tower:IsNull() and tower:CanBeSeen() and tower:IsAlive()
                        and GetUnitToLocationDistance(tower,sample)<tower:GetAttackRange()+100 then safe=false; break end
                end
                if not safe then break end
            end
            if safe and (bestGain==nil or gain>bestGain) then best,bestGain=point,gain end
        end
    end
    return best
end
function X.Think(bot,J)
    local p=X.GetPlan(bot,J)
    if p==nil then return false end
    if J.CanNotUseAction(bot) or bot:IsCastingAbility() or bot:IsUsingAbility()
        or Escape.HoldingJump(bot) or Escape.HoldingAlignment(bot) then return true end
    bot.shaiEscapeUntil=DotaTime()+0.75
    bot.shaiTacticalUntil=DotaTime()+0.5
    local threat=Farm.GetThreat(bot,J)
    if threat~=nil then return Farm.InterruptFarm(bot,J) end
    local point=Step(bot,J,p)
    if point==nil then
        -- Release to native/save logic rather than clear actions forever.
        bot.shaiRecovery=nil; bot.shaiRecoveryRetry=DotaTime()+3
        bot.shaiEscapeUntil=nil; Trace(bot,'no-safe-home-step'); return false
    end
    bot:SetTarget(nil)
    bot:Action_MoveToLocation(point)
    Trace(bot,'return-to-fountain')
    return true
end
return X
