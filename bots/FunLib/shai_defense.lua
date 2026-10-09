-- Team-local siege response. Bot VMs share entity fields, not module globals.
local X={}
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local Gank=require(GetScriptDirectory()..'/FunLib/shai_team_gank')
local CastSafety=require(GetScriptDirectory()..'/FunLib/shai_cast_safety')
local Finish=require(GetScriptDirectory()..'/FunLib/shai_combat_finish')
local Budget=require(GetScriptDirectory()..'/FunLib/shai_combat_budget')
local Chain=require(GetScriptDirectory()..'/FunLib/shai_control_chain')
local function Visible(h,J)
    return h~=nil and not h:IsNull() and h:CanBeSeen() and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
end
local function Dist(a,b) return GetUnitToUnitDistance(a,b) end
local function Protected(h)
    return h:IsInvulnerable() or h:HasModifier('modifier_item_aeon_disk_buff')
        or h:HasModifier('modifier_dazzle_shallow_grave') or h:HasModifier('modifier_abaddon_borrowed_time')
end
local function Trace(bot,p)
    if not SHAI.BehaviorTrace then return end
    if DotaTime()-(bot.shaiDefensePrinted or -math.huge)<3 and bot.shaiDefenseReason==p.reason then return end
    bot.shaiDefensePrinted,bot.shaiDefenseReason=DotaTime(),p.reason
    print(string.format('[SHAI] defense t=%.2f; hero=%s; reason=%s; target=%s; members=%d; damage=%.0f; controls=%d; backups=%d; hp=%.0f; openerDelay=%.2f; ready=%s; excluded=%s; attacks=%.0f; spells=%.0f; summons=%.0f; mana=%.0f',
        DotaTime(),bot:GetUnitName(),p.reason,p.target:GetUnitName(),#p.members,p.damage,p.controls,p.backups,p.target:GetHealth(),p.openerDelay,p.available,p.excluded,p.budget.attacks,p.budget.spells,p.budget.summons,p.budget.mana))
end
local function Incoming(h,enemies,seconds)
    local n=0
    for _,enemy in ipairs(enemies) do n=n+enemy:GetEstimatedDamageToTarget(true,h,seconds,DAMAGE_TYPE_ALL) end
    return n
end
function X.GetPlan(bot,J)
    if DotaTime()<600 or not bot:IsAlive() then return nil end
    local ancient=GetAncient(bot:GetTeam())
    if ancient==nil or ancient:IsNull() or not ancient:IsAlive() or Dist(bot,ancient)>3800 then return nil end
    local allies=GetUnitList(UNIT_LIST_ALLIED_HEROES)
    local leader=bot
    for _,h in pairs(allies) do
        if Visible(h,J) and h:IsBot() and Dist(h,ancient)<3800 and h:GetPlayerID()<leader:GetPlayerID() then leader=h end
    end
    local previous=leader.shaiDefensePlan
    if previous~=nil and DotaTime()>=previous.checked and DotaTime()-previous.checked<0.2
        and Visible(previous.target,J) and not Protected(previous.target) then
        Trace(bot,previous); return Dist(bot,previous.target)<2200 and previous or nil
    end
    local enemies,target,score={},nil,nil
    for _,h in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if Visible(h,J) and Dist(h,ancient)<3200 then
            enemies[#enemies+1]=h
            local value=h:GetEstimatedDamageToTarget(true,ancient,3,DAMAGE_TYPE_ALL)
            if previous~=nil and h==previous.target then value=value+1000 end
            if not Protected(h) and (target==nil or value>score) then target,score=h,value end
        end
    end
    if target==nil then leader.shaiDefensePlan=nil; return nil end
    local p={target=target,members={},damage=0,controls=0,hard=0,backups=0,ancient=ancient,checked=DotaTime(),excluded='',available='',openerDelay=math.huge,leader=leader}
    p.budget={attacks=0,spells=0,summons=0,mana=0}
    local defenses=Gank.TargetDefenses(target)
    local controlSeconds=0
    local funded={}
    for _,h in ipairs(enemies) do if h~=target and Dist(h,target)<1600 then p.backups=p.backups+1 end end
    local seen={}
    local function Add(h)
        if not Visible(h,J) or seen[h:GetPlayerID()] then return end
        seen[h:GetPlayerID()]=true
        local reason
        if not h:IsBot() and h:GetAttackTarget()~=target then reason='human-not-attacking'
        elseif h:HasModifier('modifier_teleporting') then reason='teleporting'
        elseif h:GetHealth()<h:GetMaxHealth()*0.4 then reason='low-hp'
        elseif h:IsHexed() then reason='hexed'
        elseif h:IsStunned() then reason='stunned'
        elseif Dist(h,target)>1400 then reason='distant' end
        if reason then p.excluded=p.excluded..h:GetUnitName()..':'..reason..','; return end
        p.members[#p.members+1]=h
        if not h:IsStunned() and h:IsBot() then
            local options=Gank.LocalControlOptions(h,target,J,true)
            local m=Budget.Member(h,target,J,options,{horizon=5,bkb=defenses.bkb,block=defenses.block,caught=target:IsStunned() or target:IsHexed()})
            funded[h:GetPlayerID()]=options
            local accepted,hard=false,false
            local duration=0
            for _,opt in ipairs(options) do
                if m.available[opt.ability:GetName()] then
                    accepted=true
                    if not opt.dispellable then hard=true; duration=math.max(duration,opt.duration) end
                    p.available=p.available..h:GetUnitName()..'/'..opt.ability:GetName()..','
                    local delay=Chain.Delay(h,target,opt.ability,opt.kind)
                    p.openerDelay=math.min(p.openerDelay,delay)
                end
            end
            controlSeconds=controlSeconds+duration
            if accepted then
                p.controls=p.controls+1
                if hard then p.hard=p.hard+1 end
            end
        end
    end
    for _,h in pairs(allies) do Add(h) end
    Add(bot)
    for _,h in ipairs(p.members) do
        local m=Budget.Member(h,target,J,funded[h:GetPlayerID()],{horizon=5,bkb=defenses.bkb,
            block=defenses.block,caught=target:IsStunned() or target:IsHexed(),backups=p.backups,
            controlSeconds=math.min(5,controlSeconds),attacksOnly=not h:IsBot()})
        p.damage=p.damage+m.total
        for _,key in ipairs({'attacks','spells','summons','mana'}) do p.budget[key]=p.budget[key]+m[key] end
    end
    local nearBuilding=Dist(target,ancient)<1800
    p.building=ancient
    local closestBuilding=Dist(target,ancient)
    for _,index in ipairs({TOWER_TOP_3,TOWER_MID_3,TOWER_BOT_3}) do
        local tower=GetTower(bot:GetTeam(),index)
        if tower~=nil and tower:IsAlive() and Dist(target,tower)<900 then nearBuilding=true end
        if tower~=nil and tower:IsAlive() and Dist(target,tower)<closestBuilding then
            p.building,closestBuilding=tower,Dist(target,tower)
        end
    end
    local controlled=J.IsDisabled(target)
    local landing=false
    for _,h in ipairs(p.members) do
        if (h.shaiDefenseControlUntil or -math.huge)>DotaTime() then landing=true end
    end
    local followThrough=previous~=nil and previous.target==target and (previous.commitUntil or 0)>DotaTime()
    local control=p.hard>0 or controlled or landing
    if controlled or landing then p.openerDelay=0.35 end
    if p.openerDelay==math.huge then p.openerDelay=2 end
    local survivable=0
    for _,h in ipairs(p.members) do
        -- Assess surviving release of the opener, including retaliation before
        -- it lands. Don't demand two seconds of unopposed support tanking.
        if Incoming(h,enemies,control and p.openerDelay or 2)<h:GetHealth()*0.75 then survivable=survivable+1 end
    end
    local lethal=#p.members>=2 and p.damage>target:GetHealth()*1.2 and control and survivable>=2
    -- Pressure on an isolated diver under OUR buildings need not guarantee a
    -- kill. Require four healthy contributors and coordinated control.
    local pressure=#p.members>=4 and p.backups==0 and nearBuilding and survivable>=3
        and (p.controls>=2 and p.hard>=1 or (controlled or landing or followThrough) and control)
        and p.damage>=target:GetHealth()*0.5 and not target:IsMagicImmune()
        and not defenses.aeon and (not defenses.bkb or controlled or p.hard>=2)
    p.ready=not defenses.aeon and (lethal or pressure or (followThrough and #p.members>=3 and p.backups==0 and survivable>=2 and control))
    p.emergency=target:GetAttackTarget()==ancient
        and target:GetEstimatedDamageToTarget(true,ancient,6,DAMAGE_TYPE_ALL)>=ancient:GetHealth()
    p.reason=p.emergency and 'ancient-emergency' or p.ready and (lethal and 'group-ready' or 'group-pressure')
        or p.backups>0 and 'enemy-backup' or #p.members<2 and 'insufficient-members'
        or not control and 'no-opener' or survivable<2 and 'unsafe-opener' or 'insufficient-damage'
    p.hold=not p.ready and not p.emergency
    p.commitUntil=p.ready and DotaTime()+0.8 or 0
    leader.shaiDefensePlan=p
    Trace(bot,p)
    return Dist(bot,target)<2200 and p or nil
end
function X.GetDesire(bot,J)
    local p=X.GetPlan(bot,J)
    if p==nil then return nil end
    bot.shaiTacticalUntil=DotaTime()+0.5
    local participating=false
    for _,h in ipairs(p.members) do if h==bot then participating=true end end
    return p.emergency and 1.1 or p.ready and participating and 1.02 or 0.82
end
local function Current(bot,J)
    local p=X.GetPlan(bot,J)
    if p==nil or not Visible(p.target,J) or Protected(p.target) then return nil end
    return p
end
local function Member(p,bot)
    for _,h in ipairs(p.members) do if h==bot then return true end end
    return false
end
function X.Think(bot,J,anchor)
    if J.CanNotUseAction(bot) then return false end
    if Finish.IsCommitting(bot,J) then return true end
    local p=Current(bot,J)
    if p==nil then return false end
    bot.shaiTacticalUntil=DotaTime()+0.5
    if (p.ready and Member(p,bot)) or p.emergency then
        bot:SetTarget(p.target)
        if not Gank.TryLocalControl(bot,p.target,J,p.members) then bot:Action_AttackUnit(p.target,false) end
        return true
    end
    bot:SetTarget(nil)
    local building=p.building or anchor or p.ancient
    local destination=J.VectorAway(building:GetLocation(),J.GetTeamFountain(),-300)
    if Dist(bot,p.target)<p.target:GetAttackRange()+250 then destination=J.VectorAway(bot:GetLocation(),p.target:GetLocation(),500) end
    if destination~=nil and IsLocationPassable(destination) and GetUnitToLocationDistance(bot,destination)>100 then bot:Action_MoveToLocation(destination) end
    return true
end
local function CastPoint(bot,J,a,target,purpose)
    if a==nil or not a:IsFullyCastable() or a:IsHidden() or J.CanNotUseAbility(bot)
        or Dist(bot,target)>a:GetCastRange()-25
        or not CastSafety.Allow(bot,J,a,purpose) then return false end
    bot:Action_UseAbilityOnLocation(a,target:GetLocation()); return true
end
function X.GuardAbilities(bot,J)
    if Finish.IsCommitting(bot,J) then return true end
    if J.CanNotUseAction(bot) then return false end
    local p=Current(bot,J)
    if p==nil then return false end
    if (p.ready and Member(p,bot)) or p.emergency then
        bot:SetTarget(p.target)
        if Gank.TryLocalControl(bot,p.target,J,p.members) then return true end
        -- Native healthy Warlock requires two enemies for offensive R. A
        -- coordinated base fight against one dominant diver has team value too.
        if #p.members>=3 and not p.target:IsMagicImmune() then
            local golem=bot:GetAbilityByName('warlock_rain_of_chaos')
            if Incoming(bot,{p.target},golem~=nil and golem:GetCastPoint()+0.2 or 1)<bot:GetHealth()*0.7
                and CastPoint(bot,J,golem,p.target,'control') then return true end
            if CastPoint(bot,J,bot:GetAbilityByName('witch_doctor_maledict'),p.target,'engage') then return true end
            local ward=bot:GetAbilityByName('witch_doctor_death_ward')
            if ward~=nil and ward:IsFullyCastable() and not J.CanNotUseAbility(bot) and J.IsDisabled(p.target)
                and not p.target:IsAttackImmune() and p.backups==0
                and Incoming(bot,{p.target},ward:GetCastPoint()+1.5)<bot:GetHealth()*0.45
                and CastSafety.Allow(bot,J,ward,'channel') then
                -- The native decision unnecessarily excludes a large allied
                -- group. Place the ward in our cast range, within its attack
                -- reach of the caught diver, without walking into the fight.
                local range=ward:GetCastRange()
                local location=p.target:GetLocation()
                if Dist(bot,p.target)>range then location=J.VectorAway(bot:GetLocation(),location,-math.max(0,range-25)) end
                if GetUnitToLocationDistance(p.target,location)<580 then
                    bot:Action_UseAbilityOnLocation(ward,location); return true
                end
            end
        end
        return false -- original hero damage/heal dispatcher may follow up
    end
    bot:SetTarget(nil)
    if Incoming(bot,{p.target},0.7)<bot:GetHealth()*0.5 and Gank.TryLocalControl(bot,p.target,J,p.members,false) then return true end
    for _,name in ipairs({'warlock_shadow_word','lich_frost_shield'}) do
        local a=bot:GetAbilityByName(name)
        if a~=nil and a:IsFullyCastable() and not J.CanNotUseAbility(bot) and J.GetHP(bot)<0.65
            and CastSafety.Allow(bot,J,a,'save') then bot:Action_UseAbilityOnEntity(a,bot); return true end
    end
    -- Don't block every original spell while a healthy caster is safely back.
    return Dist(bot,p.target)<=p.target:GetAttackRange()+250
end
return X
