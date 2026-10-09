-- Completed item invisibility: preserve an escape, not every offensive windwalk.
local X={}
local Farm=require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local Escape=require(GetScriptDirectory()..'/FunLib/shai_escape_route')
local Travel=require(GetScriptDirectory()..'/FunLib/shai_tactical_travel')
local Finish=require(GetScriptDirectory()..'/FunLib/shai_combat_finish')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
local modifiers={'modifier_item_glimmer_cape','modifier_item_invisibility_edge_windwalk','modifier_item_silver_edge_windwalk'}
local detection={'modifier_item_dustofappearance','modifier_slardar_amplify_damage','modifier_bounty_hunter_track'}
local function Visible(h,J)
    return h~=nil and not h:IsNull() and h:CanBeSeen() and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
end
local function Trace(bot,reason)
    if not SHAI.BehaviorTrace or bot.shaiInvisibleReason==reason and DotaTime()-(bot.shaiInvisiblePrinted or -math.huge)<3 then return end
    bot.shaiInvisibleReason,bot.shaiInvisiblePrinted=reason,DotaTime()
    print('[SHAI] invis t='..DotaTime()..'; hero='..bot:GetUnitName()..'; reason='..reason)
end
function X.GetPlan(bot,J)
    local modifier
    for _,m in ipairs(modifiers) do if bot:HasModifier(m) then modifier=m; break end end
    if modifier==nil or not bot:IsAlive() or not bot:IsInvisible() or bot:HasModifier('modifier_teleporting')
        or bot:IsChanneling() or bot:HasModifier('modifier_skeleton_king_reincarnation_scepter_active') then return nil end
    for _,m in ipairs(detection) do if bot:HasModifier(m) then Trace(bot,'known-detection'); return nil end end
    local closest,distance
    for _,h in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if Visible(h,J) then
            local d=GetUnitToUnitDistance(bot,h)
            if d<1000 then
                for slot=0,5 do
                    local item=h:GetItemInSlot(slot)
                    if item and item:GetName()=='item_gem' then Trace(bot,'visible-gem'); return nil end
                end
            end
            if distance==nil or d<distance then closest,distance=h,d end
        end
    end
    for _,tower in pairs(bot:GetNearbyTowers(900,true)) do
        if tower:CanBeSeen() and tower:IsAlive() then Trace(bot,'enemy-tower'); return nil end
    end
    local threat=Farm.GetThreat(bot,J)
    if not J.IsRetreating(bot) and threat==nil and bot:GetHealth()>bot:GetMaxHealth()*0.55 then return nil end
    -- A concrete finishing action or already committed group may deliberately reveal.
    if Finish.IsCommitting(bot,J) or Finish.GetPlan(bot,J)~=nil then return nil end
    local group=bot.shaiGankPlan
    if group and group.phase=='engage' and DotaTime()>=group.created and DotaTime()<group.expires
        and DotaTime()-group.updated<1.2 then
        for _,h in ipairs(group.members) do if h==bot then return nil end end
    end
    if threat==nil and closest and distance<1800 then threat={location=closest:GetLocation()} end
    return {threat=threat,nearby=distance or math.huge,remaining=J.GetModifierTime(bot,modifier)}
end
function X.Think(bot,J)
    local p=X.GetPlan(bot,J)
    if p==nil then return false end
    if Escape.HoldingJump(bot) or Escape.HoldingAlignment(bot) then return true end
    if J.CanNotUseAction(bot) then return true end
    local lease=bot.shaiInvisibleTP
    if lease and DotaTime()>=lease.created and DotaTime()<lease.expires then return true end
    bot.shaiInvisibleTP=nil
    -- Don't wager a channel on invis while visible evidence can interrupt it.
    if type(p.remaining)=='number' and p.remaining>4 and p.remaining<120 and p.nearby>1100
        and not bot:WasRecentlyDamagedByAnyHero(2) and not bot:IsRooted() and not bot:IsMuted()
        and #bot:GetIncomingTrackingProjectiles()==0 then
        local scroll=bot:GetItemInSlot(15)
        local home=J.GetTeamFountain()
        if scroll and scroll:GetName()=='item_tpscroll' and scroll:IsFullyCastable()
            and Runtime.Location(bot,'invis.home',home) and GetUnitToLocationDistance(bot,home)>2000 then
            local destination=Travel.PrepareTeleport(bot,J,home)
            if destination then
                bot:Action_UseAbilityOnLocation(scroll,destination)
                bot.shaiInvisibleTP={created=DotaTime(),expires=DotaTime()+0.75}
                Trace(bot,'safe-home-tp'); return true
            end
        end
    end
    bot:SetTarget(nil)
    bot.shaiTacticalUntil=DotaTime()+0.4
    if p.threat then Escape.Move(bot,J,p.threat)
    else
        local home=J.GetTeamFountain()
        if Runtime.Location(bot,'invis.home',home) then bot:Action_MoveToLocation(home) end
    end
    Trace(bot,'preserve-escape'); return true
end
return X
