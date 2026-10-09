-- Use current visible evidence. A remembered health value never authorizes
-- finishing a hidden, invulnerable or migrating Roshan.
local X = {}
local function Visible(unit)
    return unit ~= nil and not unit:IsNull() and unit:CanBeSeen()
        and unit:IsAlive() and unit:GetUnitName() == 'npc_dota_roshan'
end
function X.Check(bot,J)
    local roshan
    for _,unit in pairs(bot:GetNearbyNeutralCreeps(1600)) do
        if Visible(unit) then roshan=unit; break end
    end
    if roshan == nil then
        local target=J.GetProperTarget(bot)
        if Visible(target) then roshan=target end
    end
    if roshan ~= nil then
        if roshan:IsInvulnerable() or roshan:IsAttackImmune() then
            return false,'unattackable',roshan
        end
        local loc=roshan:GetLocation()
        if J.GetDistance(loc,J.Utils.RadiantRoshanLoc)>900
            and J.GetDistance(loc,J.Utils.DireRoshanLoc)>900 then
            return false,'outside-pit',roshan
        end
    end
    if J.IsRoshanCloseToChangingSides() then return false,'switch-soon',roshan end
    return true,roshan ~= nil and 'visible-in-pit' or 'unseen',roshan
end
function X.Trace(bot,reason)
    local now=DotaTime()
    if now-(bot.shaiRoshanSafetyTraceAt or -math.huge)<10 then return end
    bot.shaiRoshanSafetyTraceAt=now
    print(string.format('[SHAI] roshan-safety t=%.2f; team=%d; hero=%s; reason=%s',
        now,bot:GetTeam(),bot:GetUnitName(),reason))
end
function X.GuardActions(bot,J)
    local target=J.GetProperTarget(bot)
    -- Do not take control of unrelated travel or combat against a hero.
    if bot:GetActiveMode()~=BOT_MODE_ROSHAN and not J.IsRoshan(target) then return false end
    if J.IsValidHero(target) then return false end
    local safe,reason,roshan=X.Check(bot,J)
    if safe then return false end
    X.Trace(bot,reason)
    if J.CanNotUseAction(bot) then return true end
    local now=DotaTime()
    if now-(bot.shaiRoshanReleaseAt or -math.huge)<0.4 then return true end
    bot.shaiRoshanReleaseAt=now
    bot:SetTarget(nil)
    bot:Action_ClearActions(false)
    local destination=J.GetTeamFountain()
    if roshan ~= nil then
        local origin,loc=bot:GetLocation(),roshan:GetLocation()
        if J.GetDistance(origin,loc)>1 then
            local away=J.VectorAway(origin,loc,650)
            if IsLocationPassable(away) then destination=away end
        end
    end
    bot:Action_MoveToLocation(destination)
    return true
end
return X
