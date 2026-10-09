-- Bounded lethal action/short controlled attack sequence; never a chase.
local X = {}
local SHAI = require(GetScriptDirectory()..'/Customize/shai')
local protected = {
    'modifier_dazzle_shallow_grave', 'modifier_oracle_false_promise_timer',
    'modifier_abaddon_borrowed_time', 'modifier_item_aeon_disk_buff',
    'modifier_templar_assassin_refraction_absorb', 'modifier_medusa_mana_shield',
    'modifier_kunkka_ghost_ship_damage_delay', 'modifier_skeleton_king_reincarnation_scepter_active',
    'modifier_item_blade_mail_reflect', 'modifier_item_helm_of_the_undying_active',
}
-- No travel-time guesses, ultimates or talent-dependent targeting in this subset.
local spells = {{'zuus_arc_lightning','arc_damage'}, {'luna_lucent_beam','beam_damage'}}
local function Blind(bot)
    return bot:HasModifier('modifier_tinker_laser_blind')
        or bot:HasModifier('modifier_keeper_of_the_light_blinding_light')
        or bot:HasModifier('modifier_ringmaster_weightedpie_blind')
end

local function Visible(h,J)
    return h ~= nil and not h:IsNull() and h:CanBeSeen() and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
end
local function ItemReady(h,name)
    for slot=0,5 do
        local item=h:GetItemInSlot(slot)
        if item ~= nil and item:GetName()==name and item:GetCooldownTimeRemaining()<=0 then return true end
    end
    return false
end
local function Protected(h)
    if h:IsInvulnerable() then return true end
    for _,mod in ipairs(protected) do if h:HasModifier(mod) then return true end end
    return ItemReady(h,'item_aeon_disk')
end
local function Trace(bot,target,reason,option,incoming)
    if not SHAI.BehaviorTrace then return end
    local now=DotaTime()
    if reason~='issued' and not string.find(reason,'^abort%-') and now-(bot.shaiFinishTraceTime or -math.huge)<5 then return end
    bot.shaiFinishTraceTime=now
    print(string.format('[SHAI] finish t=%.2f; hero=%s; target=%s; reason=%s; action=%s; hits=%d; trade=%s; delay=%.2f; incoming=%.0f; hp=%.0f',
        now,bot:GetUnitName(),not target:IsNull() and target:CanBeSeen() and target:GetUnitName() or option.targetName or 'unavailable',reason,
        option.kind=='attack' and 'attack' or option.ability:GetName(),
        option.hits or 1,tostring(option.trade or false),option.delay,incoming or 0,bot:GetHealth()))
end

local function Incoming(bot,horizon,J)
    local incoming=math.max(0,-bot:GetHealthRegen())*horizon
    -- A spell projectile's damage/control is not reliably exposed: yield to escape.
    for _,p in pairs(bot:GetIncomingTrackingProjectiles()) do
        if p.caster==nil or p.caster:GetTeam()~=bot:GetTeam() then
            if not p.is_attack or p.caster==nil or not p.caster:CanBeSeen() then return nil,'unknown-projectile' end
            incoming=incoming+bot:GetActualIncomingDamage(p.caster:GetAttackDamage(),DAMAGE_TYPE_PHYSICAL)
        end
    end
    for _,enemy in pairs(J.GetNearbyHeroes(bot,1600,true,BOT_MODE_NONE)) do
        if Visible(enemy,J) then
            incoming=incoming+enemy:GetEstimatedDamageToTarget(true,bot,horizon,DAMAGE_TYPE_ALL)
        end
    end
    -- Do not replace escape with a finish under an enemy tower, even if not yet targeted.
    for _,tower in pairs(bot:GetNearbyTowers(900,true)) do
        if tower:CanBeSeen() and tower:IsAlive() then return nil,'enemy-tower' end
    end
    for _,creep in pairs(bot:GetNearbyCreeps(800,true)) do
        if creep:CanBeSeen() and creep:IsAlive() and creep:GetAttackTarget()==bot then
            incoming=incoming+creep:GetEstimatedDamageToTarget(true,bot,horizon,DAMAGE_TYPE_ALL)
        end
    end
    return incoming
end

local function WorthTrade(bot,target,option,J)
    -- Risking a death for a respawning/Aegis target is not this policy's trade.
    if DotaTime()<1200 or (option.hits or 1)>1 or not target:IsStunned()
        or J.GetRemainStunTime(target)<option.delay+0.1
        or target:GetNetWorth()<math.max(12000,bot:GetNetWorth()*1.6)
        or target:GetUnitName()=='npc_dota_hero_skeleton_king' then return false end
    for slot=0,5 do
        local item=target:GetItemInSlot(slot)
        if item~=nil and item:GetName()=='item_aegis' then return false end
    end
    -- We must survive releasing the lethal hit. A projectile may finish after our death.
    local beforeRelease=Incoming(bot,math.max(0.1,option.release or option.delay),J)
    return beforeRelease~=nil and beforeRelease*1.25+20<bot:GetHealth()
end

local function Safe(bot,target,option,J)
    local incoming,reason=Incoming(bot,option.delay+0.25,J)
    if incoming==nil then return false,0,reason end
    -- Leave both a proportional and a small absolute reserve; no regen/lifesteal credit.
    local reserve=option.committed and 10 or math.max(35,bot:GetHealth()*0.3)
    if incoming*1.25+reserve>=bot:GetHealth() then
        if WorthTrade(bot,target,option,J) then option.trade=true; return true,incoming end
        return false,incoming,'incoming-lethal'
    end
    return true,incoming
end

local function Options(bot,target,J)
    local options={}
    local distance=GetUnitToUnitDistance(bot,target)
    if not bot:IsDisarmed() and not bot:IsHexed() and J.CanBeAttacked(target)
        and not Blind(bot) and target:GetEvasion()<=0
        and (bot:GetAttackRange()<=320 or target:GetLocation().z<=bot:GetLocation().z+32)
        and bot:IsFacingLocation(target:GetLocation(),20) and distance<=bot:GetAttackRange()-15 then
        local damage=target:GetActualIncomingDamage(bot:GetAttackDamage()*0.85,DAMAGE_TYPE_PHYSICAL)
        local firstDelay=J.GetAttackProDelayTime(bot,target)+0.15
        for hits=1,3 do
            local delay=firstDelay+(hits-1)*bot:GetSecondsPerAttack()
            local controlled=hits==1 or (target:IsStunned() and J.GetRemainStunTime(target)>delay+0.15)
            if controlled and delay<=(hits==1 and 0.8 or 1.6)
                and damage*hits>target:GetHealth()+math.max(0,target:GetHealthRegen())*delay+5 then
                local flight=bot:GetAttackRange()>320 and distance/math.max(1,bot:GetAttackProjectileSpeed()) or 0
                options[#options+1]={kind='attack',hits=hits,delay=delay,range=bot:GetAttackRange()-15,
                    release=math.max(0.1,firstDelay-flight),damage=damage}
                break
            end
        end
    end
    if not J.CanNotUseAbility(bot) and not bot:HasModifier('modifier_silencer_last_word')
        and not bot:HasModifier('modifier_silencer_curse_of_the_silent')
        and J.CanCastOnNonMagicImmune(target) and J.CanCastOnTargetAdvanced(target)
        and not target:HasModifier('modifier_item_lotus_orb_active')
        and not ItemReady(target,'item_sphere')
        and (J.IsDisabled(target) or (not ItemReady(target,'item_black_king_bar') and not ItemReady(target,'item_manta'))) then
        for _,spec in ipairs(spells) do
            local ability=bot:GetAbilityByName(spec[1])
            if ability~=nil and not ability:IsHidden() and ability:IsFullyCastable() then
                local delay=ability:GetCastPoint()+0.25 -- turn/server allowance
                local range=ability:GetCastRange()-25
                local damage=target:GetActualIncomingDamage(ability:GetSpecialValueInt(spec[2])*(1+bot:GetSpellAmp())*0.9,DAMAGE_TYPE_MAGICAL)
                if delay<=0.8 and distance<=range
                    and damage>target:GetHealth()+math.max(0,target:GetHealthRegen())*delay+5 then
                    options[#options+1]={kind='spell',ability=ability,delay=delay,range=range,release=ability:GetCastPoint()+0.15,damage=damage}
                end
            end
        end
    end
    table.sort(options,function(a,b) return a.delay<b.delay end)
    return options
end

function X.GetPlan(bot,J)
    if J.GetHP(bot)>0.4 or not bot:IsAlive() then return nil end
    local now=DotaTime()
    if now<0 or bot:GetActiveMode()==BOT_MODE_EVASIVE_MANEUVERS or J.CanNotUseAction(bot)
        or (bot:GetActiveMode()==BOT_MODE_RETREAT and bot:GetActiveModeDesire()>1.05)
        or bot:IsHexed() or bot:HasModifier('modifier_teleporting') then return nil end
    for _,mod in ipairs({'modifier_jakiro_macropyre_burn','modifier_dark_seer_wall_slow',
        'modifier_sandking_sand_storm_slow','modifier_sand_king_epicenter_slow','modifier_warlock_upheaval'}) do
        if bot:HasModifier(mod) then return nil end
    end
    local gank=bot.shaiGankPlan
    if gank~=nil and now>=gank.created and now<gank.expires and now-gank.updated<=1.2
        and (gank.phase~='engage' or (gank.controlUntil~=nil and now<gank.controlUntil)) then return nil end
    local pending=bot.shaiFinishAttempt
    if pending~=nil and now<pending.issued then bot.shaiFinishAttempt=nil; pending=nil end
    if pending~=nil then
        if now<math.min(pending.untilTime,pending.holdUntil) then
            local hitsLeft=pending.kind=='attack' and math.min(pending.hits or 1,
                math.max(1,math.ceil((pending.untilTime-now)/bot:GetSecondsPerAttack()))) or 1
            if Visible(pending.target,J) and not Protected(pending.target)
                and GetUnitToUnitDistance(bot,pending.target)<=pending.range
                and pending.damage*hitsLeft>pending.target:GetHealth()
                    +math.max(0,pending.target:GetHealthRegen())*(pending.untilTime-now)+5
                and (pending.kind~='attack' or (not bot:IsDisarmed() and J.CanBeAttacked(pending.target)
                    and not Blind(bot) and pending.target:GetEvasion()<=0
                    and (bot:GetAttackRange()<=320 or pending.target:GetLocation().z<=bot:GetLocation().z+32)
                    and ((pending.hits or 1)==1 or (pending.target:IsStunned()
                        and J.GetRemainStunTime(pending.target)>pending.untilTime-now+0.15)))) then
                -- Recheck growing danger without demanding a just-used spell be ready again.
                local remaining={delay=math.max(0,pending.untilTime-now),kind=pending.kind,ability=pending.ability,
                    hits=pending.hits,committed=true,
                    targetName=pending.targetName,
                    release=math.max(0.1,(pending.release or pending.delay)-(now-pending.issued))}
                local safe,incoming,reason=Safe(bot,pending.target,remaining,J)
                if safe then return pending end
                Trace(bot,pending.target,'abort-'..reason,remaining,incoming)
            else
                Trace(bot,pending.target,'abort-target-changed',pending)
            end
            pending.untilTime=now -- no holding a stale intent through fog or new danger
        end
        if now<pending.retryUntil then return nil end
        bot.shaiFinishAttempt=nil
    end
    local best
    for _,target in pairs(J.GetNearbyHeroes(bot,1000,true,BOT_MODE_NONE)) do
        if Visible(target,J) and not Protected(target) then
            for _,option in ipairs(Options(bot,target,J)) do
                local safe,incoming,reason=Safe(bot,target,option,J)
                if safe then
                    option.target,option.incoming=target,incoming
                    if best==nil or option.delay<best.delay then best=option end
                    break
                end
                Trace(bot,target,reason,option,incoming)
            end
        end
    end
    return best
end

function X.IsCommitting(bot,J)
    local plan=X.GetPlan(bot,J)
    return plan~=nil and plan.issued~=nil
end

function X.TryAction(bot,J)
    local plan=X.GetPlan(bot,J)
    if plan==nil then return false end
    if plan.issued~=nil then return true end -- keep the wind-up, don't restart it each tick
    local now=DotaTime()
    plan.issued,plan.untilTime,plan.retryUntil=now,now+plan.delay,now+math.max(1.5,plan.delay+0.5)
    -- Preserve the last wind-up, then let escape/save logic resume while the
    -- launched projectile travels. Retreat after release cannot undo that hit.
    plan.holdUntil=now+(plan.release or plan.delay)
        +(plan.kind=='attack' and ((plan.hits or 1)-1)*bot:GetSecondsPerAttack() or 0)
    bot.shaiFinishAttempt=plan
    plan.targetName=plan.target:GetUnitName()
    bot:SetTarget(plan.target)
    if plan.kind=='attack' then bot:Action_AttackUnit(plan.target,(plan.hits or 1)==1)
    else bot:Action_UseAbilityOnEntity(plan.ability,plan.target) end
    Trace(bot,plan.target,'issued',plan,plan.incoming)
    return true
end
return X
