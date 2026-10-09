-- Visible danger at a TP destination and a bounded Shadow Amulet fade hold.
local X={}
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local Memory=require(GetScriptDirectory()..'/FunLib/shai_threat_memory')
local function Visible(h,J)
    return h~=nil and not h:IsNull() and h:CanBeSeen() and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
end
local function Trace(bot,reason,detail)
    if not SHAI.BehaviorTrace or (bot.shaiTravelReason==reason and DotaTime()-(bot.shaiTravelPrinted or -math.huge)<5) then return end
    bot.shaiTravelReason,bot.shaiTravelPrinted=reason,DotaTime()
    print('[SHAI] travel t='..tostring(DotaTime())..'; hero='..bot:GetUnitName()..'; reason='..reason..'; detail='..(detail or '-'))
end
function X.SafeDestination(bot,J,loc)
    if not Runtime.Location(bot,'tp.destination',loc) then return false,'invalid-location' end
    local enemies={}
    for _,h in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if Visible(h,J) and GetUnitToLocationDistance(h,loc)<1400 then enemies[#enemies+1]=h end
    end
    -- Losing sight of a dominant hero is not evidence that his area is safe.
    -- Memory uses only the last visible snapshot and expires automatically.
    if Memory.GetConcern(bot,J,loc)~=nil then return false,'remembered-tp-threat' end
    if #enemies==0 then return true end
    local helpers,outgoing=0,{}
    for _,e in ipairs(enemies) do outgoing[e]=bot:GetEstimatedDamageToTarget(true,e,2,DAMAGE_TYPE_ALL) end
    for _,h in pairs(GetUnitList(UNIT_LIST_ALLIED_HEROES)) do
        if h~=bot and Visible(h,J) and h:GetHealth()>=h:GetMaxHealth()*0.4 and not h:IsHexed() and not h:IsStunned() then
            local joining=false
            local plan=h.shaiGankPlan
            for _,e in ipairs(enemies) do
                if h:GetAttackTarget()==e then joining=true end
                if h:IsBot() and plan~=nil and plan.phase=='engage' and plan.target==e
                    and DotaTime()>=plan.created and DotaTime()<plan.expires and DotaTime()-plan.updated<1.2 then
                    for _,member in ipairs(plan.members) do if member==h then joining=true end end
                end
            end
            -- A passer-by or a TP still in flight is not present fighting help.
            if joining and not h:HasModifier('modifier_teleporting') and not h:IsChanneling()
                and h:GetActiveMode()~=BOT_MODE_RETREAT and GetUnitToLocationDistance(h,loc)<1200 then
                local damage=0
                for _,e in ipairs(enemies) do damage=damage+e:GetEstimatedDamageToTarget(true,h,1,DAMAGE_TYPE_ALL) end
                if damage<h:GetHealth()*0.7 then
                    helpers=helpers+1
                    for _,e in ipairs(enemies) do outgoing[e]=outgoing[e]+h:GetEstimatedDamageToTarget(true,e,2,DAMAGE_TYPE_ALL) end
                end
            end
        end
    end
    local incoming,dominant=0,false
    for _,e in ipairs(enemies) do
        incoming=incoming+e:GetEstimatedDamageToTarget(true,bot,2,DAMAGE_TYPE_ALL)
        if e:GetLevel()>=bot:GetLevel()+5 then dominant=true end
    end
    if dominant or incoming>=bot:GetHealth()*0.55 then
        for _,e in ipairs(enemies) do
            if e:GetLevel()>=bot:GetLevel()+5 or e:GetEstimatedDamageToTarget(true,bot,2,DAMAGE_TYPE_ALL)>=bot:GetHealth()*0.55 then
                local controlled=J.IsDisabled(e)
                if (helpers<2 and not (helpers>=1 and controlled)) or outgoing[e]<e:GetHealth()*0.75 then return false,'insufficient-fighting-help' end
            end
        end
    end
    if #enemies>helpers+1 and incoming>=bot:GetHealth()*0.4 then return false,'outnumbered-arrival' end
    return true
end
function X.PrepareTeleport(bot,J,loc)
    local safe,reason=X.SafeDestination(bot,J,loc)
    if not safe then Trace(bot,'unsafe-tp-destination',reason); return nil end
    -- A scroll targets a structure near the cursor. Validate its likely landing
    -- footprint too, rather than a deceptively safe requested lane-front point.
    local closest,best
    for index=0,10 do
        local tower=GetTower(bot:GetTeam(),index)
        if tower~=nil and not tower:IsNull() and tower:IsAlive() then
            local d=GetUnitToLocationDistance(tower,loc)
            if closest==nil or d<closest then closest,best=d,tower:GetLocation() end
        end
    end
    -- Outposts are discoverable world units, sometimes absent from the allied
    -- building list. Only owned, live outposts join the possible landing set.
    for _,unit in pairs(GetUnitList(UNIT_LIST_ALL)) do
        if unit~=nil and not unit:IsNull() and unit:GetTeam()==bot:GetTeam() and unit:IsAlive()
            and string.find(unit:GetUnitName(),'OutpostName',1,true) then
            local location=unit:GetLocation()
            if Runtime.Location(bot,'tp.outpost',location) then
                local d=GetUnitToLocationDistance(unit,loc)
                if closest==nil or d<closest then closest,best=d,location end
            end
        end
    end
    if best~=nil and closest<2000 then
        safe,reason=X.SafeDestination(bot,J,best)
        if not safe then Trace(bot,'unsafe-tp-structure',reason); return nil end
    end
    local destination=best~=nil and closest<2000 and best or loc
    bot.shaiTeleportPlan={location=destination,expires=DotaTime()+10,issued=DotaTime()}
    return loc
end
function X.RecheckTeleport(bot,J)
    local p=bot.shaiTeleportPlan
    if p==nil then return false end
    if DotaTime()<p.issued or DotaTime()>=p.expires then bot.shaiTeleportPlan=nil; return false end
    if not bot:HasModifier('modifier_teleporting') then
        if DotaTime()-p.issued>0.75 then bot.shaiTeleportPlan=nil end
        return false
    end
    local safe,reason=X.SafeDestination(bot,J,p.location)
    if not safe then
        bot:Action_ClearActions(true); bot.shaiTeleportPlan=nil; Trace(bot,'abort-new-tp-danger',reason); return true
    end
    return false
end
local detection={'modifier_item_dustofappearance','modifier_slardar_amplify_damage','modifier_bounty_hunter_track'}
function X.HoldFade(bot,J)
    if not bot:IsAlive() or not bot:HasModifier('modifier_item_shadow_amulet_fade')
        or bot:HasModifier('modifier_teleporting') or bot:IsChanneling() then
        bot.shaiFadeHeld=nil; return false
    end
    for _,mod in ipairs(detection) do if bot:HasModifier(mod) then Trace(bot,'fade-detected'); return false end end
    local remaining=J.GetModifierTime(bot,'modifier_item_shadow_amulet_fade')
    if remaining<=0 or remaining>5 then return false end -- unknown duration must not lock movement
    for _,tower in pairs(bot:GetNearbyTowers(900,true)) do
        if tower:CanBeSeen() and tower:IsAlive() then Trace(bot,'fade-enemy-tower'); return false end
    end
    local incoming=math.max(0,-bot:GetHealthRegen())*remaining
    for _,enemy in pairs(J.GetNearbyHeroes(bot,1600,true,BOT_MODE_NONE)) do
        if Visible(enemy,J) then
            for slot=0,5 do
                local item=enemy:GetItemInSlot(slot)
                if item~=nil and item:GetName()=='item_gem' and GetUnitToUnitDistance(bot,enemy)<1000 then
                    Trace(bot,'fade-visible-gem'); return false
                end
            end
            incoming=incoming+enemy:GetEstimatedDamageToTarget(true,bot,remaining,DAMAGE_TYPE_ALL)
        end
    end
    for _,p in pairs(bot:GetIncomingTrackingProjectiles()) do
        if p.caster==nil or p.caster:GetTeam()~=bot:GetTeam() then
            if not p.is_attack or p.caster==nil or not p.caster:CanBeSeen() then Trace(bot,'fade-unknown-projectile'); return false end
            incoming=incoming+bot:GetActualIncomingDamage(p.caster:GetAttackDamage(),DAMAGE_TYPE_PHYSICAL)
        end
    end
    if incoming*1.2+20>=bot:GetHealth() then Trace(bot,'fade-lethal-before-invis'); return false end
    return true
end
function X.ThinkFade(bot,J)
    if not X.HoldFade(bot,J) then return false end
    if not bot.shaiFadeHeld then
        -- Stop a previous movement once; don't repeatedly reset the fade timer.
        bot:Action_ClearActions(false); bot.shaiFadeHeld=true; Trace(bot,'hold-amulet-fade')
    end
    bot.shaiTacticalUntil=DotaTime()+0.5
    return true
end
return X
