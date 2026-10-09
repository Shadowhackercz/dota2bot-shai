-- Reject low-HP casts that cannot finish; distinguish escape and team contribution.
local X={}
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local function Trace(bot,ability,reason,incoming)
    if not SHAI.BehaviorTrace or DotaTime()-(bot.shaiCastSurvivalTrace or -math.huge)<3 then return end
    bot.shaiCastSurvivalTrace=DotaTime()
    print(string.format('[SHAI] cast-survival t=%.2f; hero=%s; spell=%s; reason=%s; incoming=%.0f; hp=%.0f',
        DotaTime(),bot:GetUnitName(),ability:GetName(),reason,incoming,bot:GetHealth()))
end
function X.Allow(bot,J,ability,location,kind)
    if ability==nil or ((kind=='golem' or kind=='channel') and location==nil) then return false end
    if J.GetHP(bot)>=0.5 and not bot:WasRecentlyDamagedByAnyHero(2) then return true end
    local delay=ability:GetCastPoint()+0.2
    if kind=='channel' then delay=delay+math.min(1.5,ability:GetChannelTime()) end
    local incoming=math.max(0,-bot:GetHealthRegen())*delay
    for _,enemy in pairs(J.GetNearbyHeroes(bot,1600,true,BOT_MODE_NONE)) do
        if enemy~=nil and enemy:CanBeSeen() and J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy) then
            incoming=incoming+enemy:GetEstimatedDamageToTarget(true,bot,delay,DAMAGE_TYPE_ALL)
        end
    end
    for _,p in pairs(bot:GetIncomingTrackingProjectiles()) do
        if p.caster==nil or p.caster:GetTeam()~=bot:GetTeam() then
            if not p.is_attack or p.caster==nil or not p.caster:CanBeSeen() then
                Trace(bot,ability,'unknown-projectile',incoming); return false
            end
            incoming=incoming+bot:GetActualIncomingDamage(p.caster:GetAttackDamage(),DAMAGE_TYPE_PHYSICAL)
        end
    end
    if location~=nil and GetUnitToLocationDistance(bot,location)>ability:GetCastRange()+25 then
        Trace(bot,ability,'cast-needs-walk',incoming); return false
    end
    local protected=J.GetModifierTime(bot,'modifier_dazzle_shallow_grave')>delay
        or J.GetModifierTime(bot,'modifier_abaddon_borrowed_time')>delay
    if not protected and incoming*1.25+20>=bot:GetHealth() then
        Trace(bot,ability,'cannot-finish-cast',incoming); return false
    end
    if kind=='golem' and J.GetHP(bot)<0.38 then
        local hits,helpers=0,0
        local radius=ability:GetSpecialValueInt('aoe')
        for _,enemy in pairs(J.GetNearbyHeroes(bot,1600,true,BOT_MODE_NONE)) do
            if J.IsValidHero(enemy) and enemy:CanBeSeen() and not J.IsSuspiciousIllusion(enemy)
                and GetUnitToLocationDistance(enemy,location)<=radius then hits=hits+1 end
        end
        for _,ally in pairs(J.GetNearbyHeroes(bot,1600,false,BOT_MODE_NONE)) do
            if ally~=bot and J.IsValidHero(ally) and ally:GetHealth()>ally:GetMaxHealth()*0.3
                and GetUnitToLocationDistance(ally,location)<1000 then helpers=helpers+1 end
        end
        local escaping=J.IsRetreating(bot) and bot:WasRecentlyDamagedByAnyHero(2) and hits>=1
        if hits<2 and helpers==0 and not escaping then Trace(bot,ability,'no-team-or-escape-value',incoming); return false end
    end
    Trace(bot,ability,'cast-can-land',incoming)
    return true
end
return X
