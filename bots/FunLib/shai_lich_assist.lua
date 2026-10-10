-- In-range protection for a visibly attacked ally, independent of lane mode.
local X={}
local Safety=require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local CastSafety=require(GetScriptDirectory()..'/FunLib/shai_cast_safety')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local function Visible(h,J)
    return h~=nil and not h:IsNull() and h:CanBeSeen() and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
end
local function Ready(a) return a~=nil and not a:IsHidden() and a:IsFullyCastable() end
function X.AllowGaze(bot,J,e,target,bonus)
    if not Ready(e) or J.CanNotUseAbility(bot) or J.CanNotUseAction(bot) or bot:IsInvisible()
        or not Visible(target,J) or GetUnitToUnitDistance(bot,target)>e:GetCastRange()+(bonus or 0)
        or not J.CanCastOnNonMagicImmune(target) or not J.CanCastOnTargetAdvanced(target)
        or J.IsDisabled(target) and not target:IsChanneling() then return false end
    local channel=e:GetChannelTime()
    if channel<=0 or channel>5 then return false end
    local window=channel+e:GetCastPoint()+0.2
    local incoming=math.max(0,-bot:GetHealthRegen())*window
    for _,h in pairs(J.GetNearbyHeroes(bot,1600,true,BOT_MODE_NONE)) do
        if Visible(h,J) then
            -- Only the selected, susceptible target is expected to be held.
            -- Count its exposure before control; all other heroes get the full
            -- channel window, even with Scepter (no assumed AoE catch).
            incoming=incoming+h:GetEstimatedDamageToTarget(true,bot,h==target and e:GetCastPoint()+0.2 or window,DAMAGE_TYPE_ALL)
        end
    end
    for _,tower in pairs(bot:GetNearbyTowers(1600,true)) do
        if tower~=nil and not tower:IsNull() and tower:CanBeSeen() and tower:IsAlive() then
            incoming=incoming+tower:GetEstimatedDamageToTarget(true,bot,window,DAMAGE_TYPE_ALL)
        end
    end
    if incoming>=bot:GetHealth()*0.45 or #bot:GetIncomingTrackingProjectiles()>0 then return false end
    return CastSafety.AllowDecision(bot,J,e,target,'control')
end
local function IssueGaze(bot,J,e,target)
    J.SetQueuePtToINT(bot,true)
    if bot:HasScepter() then bot:ActionQueue_UseAbilityOnLocation(e,target:GetLocation())
    else bot:ActionQueue_UseAbilityOnEntity(e,target) end
    local now=DotaTime()
    if SHAI.BehaviorTrace and (bot.shaiLichAssistPrinted==nil or now<bot.shaiLichAssistPrinted or now-bot.shaiLichAssistPrinted>=3) then
        bot.shaiLichAssistPrinted=now
        print('[SHAI] safety t='..now..'; hero='..bot:GetUnitName()..'; reason=ally-assist; spell='..e:GetName()..'; detail=gaze-control; channel='..e:GetChannelTime())
    end
    return true
end
function X.TryGaze(bot,J,e,bonus,interruptOnly)
    if not Ready(e) then return false end
    local enemies=J.GetNearbyHeroes(bot,1600,true,BOT_MODE_NONE)
    for _,enemy in pairs(enemies) do
        if Visible(enemy,J) and (enemy:IsChanneling() or J.IsCastingUltimateAbility(enemy))
            and X.AllowGaze(bot,J,e,enemy,bonus) then return IssueGaze(bot,J,e,enemy) end
    end
    if interruptOnly or Safety.GetThreat(bot,J)~=nil then return false end
    for _,ally in pairs(J.GetAlliesNearLoc(bot:GetLocation(),1200)) do
        if ally~=bot and Visible(ally,J) and ally:GetHealth()>0
            and not ally:HasModifier('modifier_skeleton_king_reincarnation_scepter_active') then
            for _,enemy in pairs(enemies) do
                if Visible(enemy,J) and (enemy:GetAttackTarget()==ally or ally:WasRecentlyDamagedByHero(enemy,1.5))
                    and GetUnitToUnitDistance(enemy,ally)<=enemy:GetAttackRange()+350
                    and X.AllowGaze(bot,J,e,enemy,bonus) then return IssueGaze(bot,J,e,enemy) end
            end
        end
    end
    return false
end
function X.GetPlan(bot,J,q,w,bonus)
    if J.CanNotUseAbility(bot) or J.CanNotUseAction(bot) or bot:IsInvisible()
        or Safety.GetThreat(bot,J)~=nil then return nil end
    local enemies=J.GetNearbyHeroes(bot,1200,true,BOT_MODE_NONE)
    local allies=J.GetAlliesNearLoc(bot:GetLocation(),1200)
    local best
    for _,ally in pairs(allies) do
        if ally~=bot and Visible(ally,J) and ally:GetHealth()>0
            and not ally:HasModifier('modifier_skeleton_king_reincarnation_scepter_active') then
            for _,enemy in pairs(enemies) do
                if Visible(enemy,J) and enemy:GetHealth()>0
                    and (enemy:GetAttackTarget()==ally or ally:WasRecentlyDamagedByHero(enemy,1.5))
                    and GetUnitToUnitDistance(enemy,ally)<=enemy:GetAttackRange()+350 then
                    local physical=enemy:GetEstimatedDamageToTarget(true,ally,2,DAMAGE_TYPE_PHYSICAL)
                    local plan
                    if Ready(w) and GetUnitToUnitDistance(bot,ally)<=w:GetCastRange()+(bonus or 0)
                        and not ally:HasModifier('modifier_lich_frost_shield')
                        and (physical>=ally:GetMaxHealth()*0.2 or physical>0 and ally:GetHealth()<ally:GetMaxHealth()*0.6) then
                        plan={ability=w,target=ally,purpose='save',reason='shield-attacked-ally',score=physical/ally:GetHealth()+2}
                    elseif Ready(q) and GetUnitToUnitDistance(bot,enemy)<=q:GetCastRange()+(bonus or 0)
                        and J.CanCastOnNonMagicImmune(enemy) and J.CanCastOnTargetAdvanced(enemy)
                        and not J.IsDisabled(enemy) and not enemy:HasModifier('modifier_lich_frostnova_slow') then
                        plan={ability=q,target=enemy,purpose='control',reason='slow-ally-attacker',score=physical/ally:GetHealth()}
                    end
                    if plan then
                        -- No walking into range. Even a useful ally save must
                        -- survive its cast; do not stop a threatened escape.
                        local incoming=0
                        for _,h in pairs(enemies) do
                            if Visible(h,J) then incoming=incoming+h:GetEstimatedDamageToTarget(true,bot,plan.ability:GetCastPoint()+0.2,DAMAGE_TYPE_ALL) end
                        end
                        if incoming<bot:GetHealth()*0.45 and CastSafety.Allow(bot,J,plan.ability,plan.purpose)
                            and (best==nil or plan.score>best.score) then best=plan end
                    end
                end
            end
        end
    end
    return best
end
function X.Try(bot,J,q,w,bonus)
    local plan=X.GetPlan(bot,J,q,w,bonus)
    if plan==nil then return false end
    J.SetQueuePtToINT(bot,true)
    bot:ActionQueue_UseAbilityOnEntity(plan.ability,plan.target)
    local now=DotaTime()
    if SHAI.BehaviorTrace and (bot.shaiLichAssistPrinted==nil or now<bot.shaiLichAssistPrinted or now-bot.shaiLichAssistPrinted>=3) then
        bot.shaiLichAssistPrinted=now
        print('[SHAI] safety t='..now..'; hero='..bot:GetUnitName()..'; reason=ally-assist; spell='..plan.ability:GetName()..'; detail='..plan.reason)
    end
    return true
end
return X
