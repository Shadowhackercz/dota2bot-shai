-- Bounded team plans against a visible, locally dominant enemy. Pure Lua.
local X = {}
local SHAI = require(GetScriptDirectory()..'/Customize/shai')
local CastSafety = require(GetScriptDirectory()..'/FunLib/shai_cast_safety')
local Budget = require(GetScriptDirectory()..'/FunLib/shai_combat_budget')
local Chain = require(GetScriptDirectory()..'/FunLib/shai_control_chain')
local durationKeys={lion_voodoo='duration',lion_impale='duration',skeleton_king_hellfire_blast='blast_stun_duration',
    sven_storm_bolt='bolt_stun_duration',dragon_knight_dragon_tail='stun_duration',vengefulspirit_magic_missile='magic_missile_stun',
    centaur_hoof_stomp='stun_duration',axe_berserkers_call='duration',tidehunter_ravage='duration',
    crystal_maiden_frostbite='duration',witch_doctor_paralyzing_cask='hero_duration',warlock_rain_of_chaos='stun_duration',
    item_sheepstick='sheep_duration',item_orchid='silence_duration',item_bloodthorn='silence_duration'}
-- Conservative subset: no guessed spell targeting flags or blink combos.
local spells = {
    {'lion_voodoo','unit'}, {'lion_impale','point'},
    {'skeleton_king_hellfire_blast','unit'}, {'sven_storm_bolt','unit'},
    {'dragon_knight_dragon_tail','unit'}, {'vengefulspirit_magic_missile','unit'},
    {'centaur_hoof_stomp','self','radius'}, {'axe_berserkers_call','self','radius',true},
    {'tidehunter_ravage','self','radius'}, {'crystal_maiden_frostbite','unit',nil,false,true},
    {'witch_doctor_paralyzing_cask','unit'}, {'warlock_rain_of_chaos','point'},
}
local items = {{'item_sheepstick','unit'}, {'item_orchid','unit',nil,false,true},
    {'item_bloodthorn','unit',nil,false,true}}

local function Real(h, J)
    return J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
end
local function Visible(h, J) return Real(h, J) and h:CanBeSeen() end
local function FindItem(h, name)
    for slot = 0, 5 do
        local item = h:GetItemInSlot(slot)
        if item ~= nil and item:GetName() == name then return item end
    end
end
local function Defenses(target)
    local bkb, manta, linken, aeon = FindItem(target,'item_black_king_bar'), FindItem(target,'item_manta'),
        FindItem(target,'item_sphere'), FindItem(target,'item_aeon_disk')
    local immune=target:IsMagicImmune()
    return {bkb = immune or (bkb ~= nil and bkb:IsFullyCastable()), immune=immune,
        dispel = manta ~= nil and manta:IsFullyCastable(),
        block = target:HasModifier('modifier_item_sphere_target') or target:HasModifier('modifier_item_lotus_orb_active')
            or (linken ~= nil and linken:GetCooldownTimeRemaining() <= 0),
        aeon = target:HasModifier('modifier_item_aeon_disk_buff') or (aeon ~= nil and aeon:GetCooldownTimeRemaining() <= 0)}
end

local function Controls(h, target, defenses, inRange)
    local options = {}
    local function Add(spec, ability, isItem)
        if ability == nil or not ability:IsFullyCastable() or ability:IsHidden()
            or (not isItem and h:IsSilenced()) or (isItem and h:IsMuted()) then return end
        if defenses.immune and not spec[4] then return end
        if defenses.dispel and spec[5] then return end -- Orchid alone cannot secure a Manta target.
        if defenses.block and spec[2] == 'unit' then return end
        local range = spec[2] == 'self' and ability:GetSpecialValueInt(spec[3])
            or ability:GetCastRange() + h:GetCastRangeBonus()
        if range <= 0 or (inRange and GetUnitToUnitDistance(h,target) > range - 25) then return end
        local kind=spec[2]
        if spec[1]=='lion_voodoo' then
            local aoeTalent=h:GetAbilityByName('special_bonus_unique_lion_4')
            if aoeTalent~=nil and aoeTalent:IsTrained() then kind='point' end
        end
        options[#options+1] = {ability=ability, kind=kind, range=range, item=isItem, dispellable=spec[5],
            duration=math.max(0,ability:GetSpecialValueFloat(durationKeys[spec[1]]))*0.65,
            ultimate=spec[1]=='warlock_rain_of_chaos' or spec[1]=='tidehunter_ravage'}
    end
    for _, spec in ipairs(spells) do Add(spec,h:GetAbilityByName(spec[1]),false) end
    for _, spec in ipairs(items) do Add(spec,FindItem(h,spec[1]),true) end
    return options
end

local function Healthy(h, J, initial)
    return Real(h,J) and IsPlayerBot(h:GetPlayerID()) and h:GetHealth() >= h:GetMaxHealth()*0.55
        and not h:IsStunned() and not h:IsHexed() and not h:HasModifier('modifier_teleporting')
        and h:GetActiveMode() ~= BOT_MODE_EVASIVE_MANEUVERS
        and (not initial or (not J.CanNotUseAction(h) and h:GetActiveMode() ~= BOT_MODE_RETREAT
            and h:GetActiveMode() ~= BOT_MODE_ROSHAN and h:GetActiveMode() ~= BOT_MODE_SIDE_SHOP))
end

local function CombatReady(h,target,J,engaged)
    if Healthy(h,J,false) then return true,false end
    if not engaged or not Real(h,J) or not IsPlayerBot(h:GetPlayerID()) or h:IsStunned() or h:IsHexed()
        or h:GetHealth()<h:GetMaxHealth()*0.2 or h:HasModifier('modifier_teleporting')
        or h:GetActiveMode()==BOT_MODE_EVASIVE_MANEUVERS then return false end
    -- A wounded ranged controller may contribute one safe spell, not frontline DPS.
    if GetUnitToUnitDistance(h,target)<=target:GetAttackRange()+200 then return false end
    for _,opt in ipairs(Controls(h,target,Defenses(target),true)) do
        if target:GetEstimatedDamageToTarget(true,h,opt.ability:GetCastPoint()+0.4,DAMAGE_TYPE_ALL)<h:GetHealth()*0.6 then
            return true,true
        end
    end
    return false
end

local function Assess(members, target, J, close, engaged, landing)
    if not Visible(target,J) or target:IsInvulnerable() then return false,'target-unavailable' end
    local defenses = Defenses(target)
    if defenses.aeon or target:HasModifier('modifier_dazzle_shallow_grave')
        or target:HasModifier('modifier_abaddon_borrowed_time') then return false,'target-protected' end
    local damage, controls, hard, opener, count = 0,0,0,nil,0
    local otherEnemies=0
    for _,e in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if e~=target and Visible(e,J) and GetUnitToUnitDistance(e,target)<1600 then otherEnemies=otherEnemies+1 end
    end
    local controlSeconds=0
    local paid={}
    for _,h in ipairs(members) do
        local best=0
        local opts=Controls(h,target,defenses,false)
        local funded=Budget.Member(h,target,J,opts,{horizon=5,future=not close,bkb=defenses.bkb,
            block=defenses.block,caught=target:IsStunned() or target:IsHexed()})
        paid[h:GetPlayerID()]=funded
        for _,opt in ipairs(opts) do
            if funded.available[opt.ability:GetName()] and not opt.dispellable then best=math.max(best,opt.duration) end
        end
        controlSeconds=controlSeconds+best
    end
    local breakdown={attacks=0,spells=0,summons=0,mana=0}
    local openerDelay=math.huge
    for _,h in ipairs(members) do
        for _,opt in ipairs(Controls(h,target,defenses,close)) do
            if paid[h:GetPlayerID()].available[opt.ability:GetName()] then
                openerDelay=math.min(openerDelay,Chain.Delay(h,target,opt.ability,opt.kind))
            end
        end
    end
    if J.IsDisabled(target) or landing then openerDelay=0.35 end
    for _, h in ipairs(members) do
        local ready,utility=CombatReady(h,target,J,engaged)
        if not ready or GetUnitToUnitDistance(h,target) > (close and 1100 or 2600) then
            return false,'group-not-ready'
        end
        if not utility then
            count = count+1
        end
        local opts = Controls(h,target,defenses,false)
        local m=Budget.Member(h,target,J,opts,{horizon=5,future=not close,bkb=defenses.bkb,
            block=defenses.block,caught=target:IsStunned() or target:IsHexed(),backups=otherEnemies,controlsOnly=utility,controlSeconds=math.min(5,controlSeconds)})
        damage=damage+m.total
        for _,key in ipairs({'attacks','spells','summons','mana'}) do breakdown[key]=breakdown[key]+m[key] end
        local funded,hardFunded=false,false
        for _,opt in ipairs(opts) do
            if m.available[opt.ability:GetName()] then funded=true; if not opt.dispellable then hardFunded=true end end
        end
        if funded then controls=controls+1 end
        if hardFunded then hard=hard+1 end
        if opener==nil then
            for _,opt in ipairs(Controls(h,target,defenses,true)) do if m.available[opt.ability:GetName()] then opener=h; break end end
        end
        local delay=openerDelay~=math.huge and openerDelay or 2
        local retaliation=target:GetEstimatedDamageToTarget(true,h,delay,DAMAGE_TYPE_ALL)
        if retaliation>=h:GetHealth()*0.85 then return false,'member-too-fragile' end
    end
    if count < (engaged and 2 or 3) then return false,'group-not-ready' end
    if otherEnemies >= 2 then return false,'enemy-backup' end
    if #target:GetNearbyTowers(1000,false) > 0 then return false,'enemy-tower' end
    if damage < (target:GetHealth()+target:GetHealthRegen()*5)*1.15*(1+otherEnemies*0.4) then
        return false,'insufficient-damage',nil,breakdown
    end
    -- Once caught, consumed controls must not abort a viable ongoing kill.
    if not J.IsDisabled(target) and not landing
        and (controls<2 or hard<(defenses.bkb and 2 or 1)) then return false,'insufficient-control',nil,breakdown end
    return true,nil,opener,breakdown
end

local function Trace(leader, plan, reason)
    if not SHAI.BehaviorTrace then return end
    local key = (plan and plan.phase or 'abort')..':'..(reason or '')
    if leader.shaiGankTraceKey~=key or DotaTime()-(leader.shaiGankTraceTime or -math.huge)>=5 then
        local b=plan and plan.budget or {}
        print(string.format('[SHAI] gank t=%.2f; leader=%s; phase=%s; reason=%s; target=%s; members=%d; attacks=%.0f; spells=%.0f; summons=%.0f; mana=%.0f',
            DotaTime(),leader:GetUnitName(),plan and plan.phase or 'abort',reason or 'ready',
            plan and plan.name or '-',plan and #plan.members or 0,b.attacks or 0,b.spells or 0,b.summons or 0,b.mana or 0))
        leader.shaiGankTraceKey,leader.shaiGankTraceTime=key,DotaTime()
    end
end
local function Cancel(leader,plan,reason)
    plan.phase='abort'
    Trace(leader,plan,reason)
    for _, h in ipairs(plan.members) do
        if h.shaiGankPlan==plan then
            h.shaiGankPlan=nil
            if h:GetTarget()==plan.target then h:SetTarget(nil) end
        end
    end
    leader.shaiTeamGank=nil
    leader.shaiGankRetry=DotaTime()+20
end

local function Reinforce(plan,allies,J,reason)
    if reason~='insufficient-damage' and reason~='insufficient-control' and reason~='group-not-ready' then return false end
    local engaged=plan.phase=='engage'
    local selected,seen,candidates={},{},{}
    for _,h in ipairs(plan.members) do selected[#selected+1]=h; seen[h:GetPlayerID()]=true end
    local defenses=Defenses(plan.target)
    for _,h in pairs(allies) do
        if Healthy(h,J,true) and not seen[h:GetPlayerID()]
            and GetUnitToUnitDistance(h,plan.target)<=(engaged and 1100 or 2400)
            and GetUnitToUnitDistance(h,plan.target)/math.max(200,h:GetCurrentMovementSpeed())<=8
            and (h.shaiGankPlan==nil or h.shaiGankPlan==plan) then
            local retaliation=plan.target:GetEstimatedDamageToTarget(true,h,2,DAMAGE_TYPE_ALL)
            if retaliation<h:GetHealth()*0.85 or #Controls(h,plan.target,defenses,false)>0 then
                candidates[#candidates+1]=h
            end
        end
    end
    table.sort(candidates,function(a,b)
        local da,db=GetUnitToUnitDistance(a,plan.target),GetUnitToUnitDistance(b,plan.target)
        if da==db then return a:GetPlayerID()<b:GetPlayerID() end
        return da<db
    end)
    for _,h in ipairs(candidates) do
        if #selected>=5 then break end
        selected[#selected+1]=h
        if Assess(selected,plan.target,J,engaged,engaged) then
            local oldCount=#plan.members
            plan.members=selected
            for _,member in ipairs(selected) do member.shaiGankPlan=plan end
            if SHAI.BehaviorTrace then
                print(string.format('[SHAI] gank-reinforce t=%.2f; target=%s; reason=%s; old=%d; members=%d; phase=%s',
                    DotaTime(),plan.name,reason,oldCount,#selected,plan.phase))
            end
            return true
        end
    end
    -- Do not publish reservations for extra bots unless the expanded plan is viable.
    return false
end

function X.Update(bot,J)
    local now=DotaTime()
    if now<600 then bot.shaiGankPlan=nil; bot.shaiTeamGank=nil; bot.shaiGankChecked=nil; bot.shaiGankRetry=nil; return end
    local allies,leader=GetUnitList(UNIT_LIST_ALLIED_HEROES),nil
    for _, h in pairs(allies) do
        if Real(h,J) and IsPlayerBot(h:GetPlayerID()) and (leader==nil or h:GetPlayerID()<leader:GetPlayerID()) then leader=h end
    end
    if leader==nil then return end
    -- Entity fields match the existing Roshan protocol; no assumption of shared module globals.
    if leader.shaiGankChecked~=nil and now>=leader.shaiGankChecked and now-leader.shaiGankChecked<0.4 then return end
    leader.shaiGankChecked=now
    local plan=leader.shaiTeamGank
    if J.GetEnemiesAroundAncient(leader,2500)>0 then
        if plan~=nil then Cancel(leader,plan,'defend-base') end
        return
    end
    if plan~=nil then
        if now<plan.created or now>=plan.expires then Cancel(leader,plan,'expired'); return end
        if not Visible(plan.target,J) then Cancel(leader,plan,'target-unavailable'); return end
        local remaining={}
        for _,h in ipairs(plan.members) do
            if CombatReady(h,plan.target,J,plan.phase=='engage') and GetUnitToUnitDistance(h,plan.target)<=2600 then
                remaining[#remaining+1]=h
            else
                if SHAI.BehaviorTrace then
                    print(string.format('[SHAI] gank-member t=%.2f; hero=%s; reason=wounded-unready-or-distant',now,h:GetUnitName()))
                end
                h.shaiGankPlan=nil
                if h:GetTarget()==plan.target then h:SetTarget(nil) end
            end
        end
        plan.members=remaining
        local landing=plan.controlUntil~=nil and now<plan.controlUntil
        local safe,reason,_,breakdown=Assess(plan.members,plan.target,J,plan.phase=='engage',plan.phase=='engage',landing)
        if not safe and Reinforce(plan,allies,J,reason) then
            safe,reason,_,breakdown=Assess(plan.members,plan.target,J,plan.phase=='engage',plan.phase=='engage',landing)
        end
        if not safe then Cancel(leader,plan,reason); return end
        plan.budget=breakdown
        plan.updated=now
        local close,_,closeOpener=Assess(plan.members,plan.target,J,true,plan.phase=='engage',landing)
        if plan.phase=='gather' then
            local together=true
            for _, h in ipairs(plan.members) do
                if GetUnitToLocationDistance(h,plan.rally)>450 then together=false end
            end
            if together then plan.phase='approach' end
        end
        if close and closeOpener~=nil then plan.phase='engage'; plan.opener=closeOpener
        elseif plan.phase=='engage' and not J.IsDisabled(plan.target) and not landing then
            Cancel(leader,plan,'group-separated'); return
        end
        Trace(leader,plan)
        return
    end
    if leader.shaiGankRetry~=nil and now>=leader.shaiGankRetry-20 and now<leader.shaiGankRetry then return end
    for _, target in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if Visible(target,J) and not target:IsInvulnerable() then
            local dominant=false
            local members={}
            for _, h in pairs(allies) do
                if Healthy(h,J,true) and GetUnitToUnitDistance(h,target)<=2400
                    and GetUnitToUnitDistance(h,target)/math.max(200,h:GetCurrentMovementSpeed())<=8 then
                    members[#members+1]=h
                    local incoming=target:GetEstimatedDamageToTarget(true,h,2,DAMAGE_TYPE_ALL)
                    local outgoing=h:GetEstimatedDamageToTarget(true,target,2,DAMAGE_TYPE_ALL)
                    if incoming>=h:GetHealth()*0.45 and (target:GetLevel()>=h:GetLevel()+3
                        or (incoming>=h:GetHealth()*0.7 and target:GetHealth()>outgoing*1.5)) then dominant=true end
                end
            end
            table.sort(members,function(a,b) return a:GetPlayerID()<b:GetPlayerID() end)
            local viable,reason,_,breakdown=false,nil,nil,nil
            if dominant then
                viable,reason,_,breakdown=Assess(members,target,J,false)
                if not viable and SHAI.BehaviorTrace and now-(leader.shaiGankRejectedTime or -math.huge)>=5 then
                    local b=breakdown or {}
                    print(string.format('[SHAI] gank t=%.2f; leader=%s; phase=declined; reason=%s; target=%s; members=%d; attacks=%.0f; spells=%.0f; summons=%.0f; mana=%.0f',
                        now,leader:GetUnitName(),reason or 'group-not-ready',target:GetUnitName(),#members,b.attacks or 0,b.spells or 0,b.summons or 0,b.mana or 0))
                    leader.shaiGankRejectedTime=now
                end
            end
            if viable then
                local cx,cy,cz=0,0,0
                for _, h in ipairs(members) do local p=h:GetLocation(); cx=cx+p.x; cy=cy+p.y; cz=cz+p.z end
                local centroid=Vector(cx/#members,cy/#members,cz/#members)
                local targetLoc=target:GetLocation()
                if (targetLoc.x-centroid.x)^2+(targetLoc.y-centroid.y)^2<1 then centroid=J.GetTeamFountain() end
                local rally=J.VectorAway(targetLoc,centroid,-1100)
                if IsLocationPassable(rally) then
                    plan={target=target,name=target:GetUnitName(),members=members,phase='gather',
                        rally=rally,created=now,updated=now,expires=now+18,budget=breakdown}
                    leader.shaiTeamGank=plan
                    for _, h in ipairs(members) do h.shaiGankPlan=plan; h:SetTarget(nil) end
                    Trace(leader,plan)
                    return
                end
            end
        end
    end
end

local function Current(bot,J)
    local p=bot.shaiGankPlan
    if p==nil or DotaTime()<p.created or DotaTime()>=p.expires or DotaTime()-p.updated>1.2
        or not Visible(p.target,J) or not CombatReady(bot,p.target,J,p.phase=='engage') then return nil end
    return p
end
function X.GetDesire(bot,J)
    X.Update(bot,J)
    local p=Current(bot,J)
    if p==nil then return nil end
    if p.phase=='engage' then bot:SetTarget(p.target) else bot:SetTarget(nil) end
    return 0.97
end
function X.HoldOffense(bot,J)
    local p=Current(bot,J)
    if p~=nil and p.phase=='engage' then
        local _,utility=CombatReady(bot,p.target,J,true)
        if utility then return true end -- Only the evaluated safe control; no low-HP damage chase.
    end
    return p~=nil and p.phase~='engage' and not bot:WasRecentlyDamagedByAnyHero(2)
        and GetUnitToUnitDistance(bot,p.target)>p.target:GetAttackRange()+250
end
function X.TryControl(bot,J)
    local p=Current(bot,J)
    if p==nil or p.phase~='engage' or J.CanNotUseAction(bot) then return false end
    local pending=Chain.Pending(bot,p.target)
    if pending~=nil then return pending.owner==bot end
    local defenses=Defenses(p.target)
    if defenses.aeon then return false end
    for _, opt in ipairs(Controls(bot,p.target,defenses,true)) do
        if not Chain.Wait(bot,p.target,J,opt.ability,opt.kind) and (opt.item or CastSafety.Allow(bot,J,opt.ability,'control')) then
            local r=Chain.Reserve(bot,p.target,opt.ability,opt.kind,p.members)
            p.controlUntil=r.untilTime
            if opt.kind=='self' then bot:Action_UseAbility(opt.ability)
            elseif opt.kind=='point' then bot:Action_UseAbilityOnLocation(opt.ability,p.target:GetLocation())
            else bot:Action_UseAbilityOnEntity(opt.ability,p.target) end
            return true
        end
    end
    return false
end
function X.Think(bot,J)
    X.Update(bot,J)
    local p=Current(bot,J)
    if p==nil then return false end
    bot.shaiTacticalUntil=DotaTime()+0.5
    if J.CanNotUseAction(bot) then return true end
    if p.phase=='gather' then bot:Action_MoveToLocation(p.rally)
    elseif p.phase=='approach' then
        local loc=J.VectorAway(p.target:GetLocation(),bot:GetLocation(),-math.max(250,bot:GetAttackRange()-50))
        if IsLocationPassable(loc) then bot:Action_MoveToLocation(loc) end
    elseif not X.TryControl(bot,J) then
        local _,utility=CombatReady(bot,p.target,J,true)
        if utility then bot:SetTarget(nil); bot:Action_MoveToLocation(J.VectorAway(bot:GetLocation(),p.target:GetLocation(),500))
        else bot:Action_AttackUnit(p.target,false) end
    end
    return true
end
-- Same evaluated control subset for local defense, without starting a map gank.
function X.HasLocalControl(bot,target,J)
    return not J.CanNotUseAction(bot) and Visible(target,J) and #Controls(bot,target,Defenses(target),true)>0
end
-- Assessment may inspect a teammate already casting, but action issuance may not.
function X.LocalControlOptions(bot,target,J,inRange)
    if not Visible(target,J) then return {} end
    return Controls(bot,target,Defenses(target),inRange)
end
function X.TargetDefenses(target) return Defenses(target) end
function X.TryLocalControl(bot,target,J,members,allowUltimate)
    if J.CanNotUseAction(bot) or not Visible(target,J) then return false end
    local pending=Chain.Pending(bot,target)
    if pending~=nil then return pending.owner==bot end
    if Defenses(target).aeon then return false end
    for _,opt in ipairs(Controls(bot,target,Defenses(target),true)) do
        if not Chain.Wait(bot,target,J,opt.ability,opt.kind) and (allowUltimate~=false or not opt.ultimate) and (opt.item or CastSafety.Allow(bot,J,opt.ability,'control')) then
            local untilTime=Chain.Reserve(bot,target,opt.ability,opt.kind,members).untilTime
            for _,h in ipairs(members) do h.shaiDefenseControlUntil=untilTime end
            bot.shaiDefenseControlUntil=untilTime
            if opt.kind=='self' then bot:Action_UseAbility(opt.ability)
            elseif opt.kind=='point' then bot:Action_UseAbilityOnLocation(opt.ability,target:GetLocation())
            else bot:Action_UseAbilityOnEntity(opt.ability,target) end
            return true
        end
    end
    return false
end
return X
