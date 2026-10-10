-- Prioritize existing self-save considerations in a freshly blocked escape.
local X={}
local Farm=require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local Escape=require(GetScriptDirectory()..'/FunLib/shai_escape_route')
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local Memory=require(GetScriptDirectory()..'/FunLib/shai_threat_memory')
X.Holding=Escape.HoldingSave
function X.AllowOrdinary(bot,J,item,target)
    local name=item:GetName()
    if target~=bot or (name~='item_force_staff' and name~='item_hurricane_pike') then return true end
    local threat=Farm.GetThreat(bot,J)
    return threat==nil or Escape.ForcePlan(bot,J,threat,item)~=nil
end
function X.TryGhostTeleport(bot,J,use)
    local p=bot.shaiGhostEscape
    if p==nil then return false end
    local now=DotaTime()
    if not bot:IsAlive() or now<p.created or now>=p.expires then bot.shaiGhostEscape=nil; return false end
    if X.Holding(bot) or J.CanNotUseAction(bot) or bot:IsMuted() or bot:IsRooted() then return false end
    if not bot:HasModifier('modifier_ghost_state') then
        if now-p.created>0.75 then bot.shaiGhostEscape=nil end
        return false
    end
    local scroll=bot:GetItemInSlot(15)
    if scroll==nil or scroll:GetName()~='item_tpscroll' or not J.CanCastAbility(scroll) then return false end
    local channel=scroll:GetChannelTime()
    if channel<=0 or channel>4 or J.GetModifierTime(bot,'modifier_ghost_state')<channel+0.4 then return false end
    local home=J.GetTeamFountain()
    if not Runtime.Location(bot,'ghost-tp.home',home) or GetUnitToLocationDistance(bot,home)<2200
        or Memory.GetConcern(bot,J,bot:GetLocation())~=nil or #bot:GetIncomingTrackingProjectiles()>0 then return false end
    local incoming=math.max(0,-bot:GetHealthRegen())*(channel+0.4)
    for _,enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if not enemy:IsNull() and enemy:CanBeSeen() and J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy)
            and enemy:IsAlive() and GetUnitToUnitDistance(bot,enemy)<1600 then
            -- No inference from the opponent's current cooldown: this first
            -- profile requires a visible stun covering the entire channel.
            if J.GetRemainStunTime(enemy)<channel+0.4 then return false end
            incoming=incoming+enemy:GetEstimatedDamageToTarget(true,bot,channel+0.4,DAMAGE_TYPE_MAGICAL)*2
                +enemy:GetEstimatedDamageToTarget(true,bot,channel+0.4,DAMAGE_TYPE_PURE)
        end
    end
    if incoming>=bot:GetHealth()*0.5 then return false end
    -- The normal dispatcher also checks the destination/structure footprint.
    if not use(scroll,home,'ground') then return false end
    bot.shaiGhostEscape=nil
    bot.shaiEscapeSave={created=now,expires=now+0.3}
    if SHAI.BehaviorTrace then print('[SHAI] escape-item t='..now..'; hero='..bot:GetUnitName()..'; reason=ghost-home-tp; channel='..channel..'; incoming='..incoming) end
    return true
end
function X.Try(bot,J,consider,use)
    if X.Holding(bot) then return true end
    local now=DotaTime()
    if bot.shaiEscapeBlockedAt==nil or bot.shaiEscapeChecked==nil
        or now<bot.shaiEscapeChecked or now-bot.shaiEscapeChecked>0.75
        or J.CanNotUseAction(bot) or bot:IsMuted() or bot:IsInvisible()
        or bot:HasModifier('modifier_skeleton_king_reincarnation_scepter_active') then return false end
    local threat=Farm.GetThreat(bot,J)
    if threat==nil then return false end
    local physical,magical=0,0
    for _,enemy in ipairs(J.GetNearbyHeroes(bot,1000,true,BOT_MODE_NONE)) do
        if not enemy:IsNull() and enemy:CanBeSeen() and J.IsValidHero(enemy)
            and not J.IsSuspiciousIllusion(enemy) and enemy:IsAlive() then
            physical=physical+enemy:GetEstimatedDamageToTarget(true,bot,1,DAMAGE_TYPE_PHYSICAL)
            magical=magical+enemy:GetEstimatedDamageToTarget(true,bot,1,DAMAGE_TYPE_MAGICAL)
        end
    end
    -- Avoid preferring ethereal protection in a mixed/magical threat. This is
    -- a conservative engine estimate, not a complete simulation of enemy spells.
    local ghostSafe=physical>=bot:GetHealth()*0.25 and magical<bot:GetHealth()*0.1 and physical>magical*4
    local names=ghostSafe and {'item_force_staff','item_hurricane_pike','item_ghost','item_glimmer_cape'} or {'item_force_staff','item_hurricane_pike','item_glimmer_cape'}
    for _,name in ipairs(names) do
        for slot=0,5 do
            local item=bot:GetItemInSlot(slot)
            if item~=nil and item:GetName()==name and J.CanCastAbility(item) then
                local force=name=='item_force_staff' or name=='item_hurricane_pike'
                local desire,target,cast=0,nil,nil
                if force then
                    if Escape.ForcePlan(bot,J,threat,item)~=nil then desire,target,cast=1,bot,'unit' end
                elseif consider[name]~=nil then
                    desire,target,cast=Runtime.Call(bot,'escape-item.'..name,function() return consider[name](item) end,0)
                end
                -- The original Glimmer logic can also save allies. This phase
                -- only prioritizes self saves, not an unrelated ally suggestion.
                if desire>0 and (name=='item_ghost' and cast=='none' or target==bot and cast=='unit')
                    and use(item,target,cast) then
                    bot.shaiEscapeSave={created=now,expires=now+math.min(0.7,math.max(0.2,item:GetCastPoint()+0.2))}
                    if name=='item_ghost' then bot.shaiGhostEscape={created=now,expires=now+5} end
                    if SHAI.BehaviorTrace then print('[SHAI] escape-item t='..now..'; hero='..bot:GetUnitName()..'; reason=blocked-self-save; item='..name..'; physical='..physical..'; magical='..magical) end
                    return true
                end
            end
        end
    end
    return false
end
return X
