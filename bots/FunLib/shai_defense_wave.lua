-- Clear an actual siege without walking out to meet a hero. No lane farming.
local X={}
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local CastSafety=require(GetScriptDirectory()..'/FunLib/shai_cast_safety')
function X.HoldingCast(bot)
    local lease=bot.shaiWaveCast
    if lease==nil then return false end
    if not bot:IsAlive() or DotaTime()<lease.issued or DotaTime()>=lease.untilTime then
        bot.shaiWaveCast=nil; return false
    end
    return true
end
local function Visible(h)
    return h~=nil and not h:IsNull() and h:CanBeSeen() and h:IsAlive()
end
local function Safe(bot,J,seconds)
    local incoming=0
    for _,h in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if Visible(h) and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h) then
            local distance=GetUnitToUnitDistance(bot,h)
            if distance<1600 then
                if distance<h:GetAttackRange()+250 and not J.IsDisabled(h) then return false end
                incoming=incoming+h:GetEstimatedDamageToTarget(true,bot,seconds,DAMAGE_TYPE_ALL)
            end
        end
    end
    return incoming<bot:GetHealth()*0.35
end
function X.GetTarget(bot,J)
    if DotaTime()<600 or not bot:IsAlive() or J.CanNotUseAction(bot) then return nil end
    local ancient=GetAncient(bot:GetTeam())
    if not Visible(ancient) or GetUnitToUnitDistance(bot,ancient)>2200 then return nil end
    local creeps={}
    for _,c in pairs(bot:GetNearbyLaneCreeps(1200,true)) do
        if Visible(c) and not c:IsInvulnerable() and not c:IsAttackImmune() then
            local building=c:GetAttackTarget()
            if Visible(building) and building:GetTeam()==bot:GetTeam() and building:IsBuilding()
                and GetUnitToUnitDistance(building,ancient)<2200 then
                creeps[#creeps+1]=c
            end
        end
    end
    -- Damage to the Ancient matters more than last-hit ownership.
    table.sort(creeps,function(a,b)
        return a:GetAttackDamage()*(a:GetAttackTarget()==ancient and 3 or 1)
            >b:GetAttackDamage()*(b:GetAttackTarget()==ancient and 3 or 1)
    end)
    return creeps[1],creeps
end
local profiles={
    {'zuus_arc_lightning','unit','radius'},
    {'crystal_maiden_crystal_nova','point','radius'},
    {'lich_frost_nova','unit','radius'},
    {'witch_doctor_paralyzing_cask','unit',400,'control'},
}
local function Trace(bot,reason,target)
    if not SHAI.BehaviorTrace or DotaTime()-(bot.shaiWavePrinted or -math.huge)<3 then return end
    bot.shaiWavePrinted=DotaTime()
    print('[SHAI] defense-wave t='..tostring(DotaTime())..'; hero='..bot:GetUnitName()..'; reason='..reason..'; target='..target:GetUnitName())
end
function X.GetAction(bot,J,spellsOnly)
    if X.HoldingCast(bot) then return nil end
    local target,creeps=X.GetTarget(bot,J)
    if target==nil then return nil end
    for _,target in ipairs(creeps) do
        if not J.CanNotUseAbility(bot) and not target:IsMagicImmune() then
            for _,profile in ipairs(profiles) do
                local ability=bot:GetAbilityByName(profile[1])
                if ability~=nil and not ability:IsHidden() and ability:IsFullyCastable()
                    and GetUnitToUnitDistance(bot,target)<=math.max(0,ability:GetCastRange()-25)
                    and Safe(bot,J,ability:GetCastPoint()+0.3) then
                    local radius=type(profile[3])=='number' and profile[3] or ability:GetSpecialValueInt(profile[3])
                    local count=0
                    for _,c in ipairs(creeps) do
                        if not c:IsMagicImmune() and GetUnitToUnitDistance(c,target)<=radius then count=count+1 end
                    end
                    local reserve=math.max(100,ability:GetManaCost())
                    for _,name in ipairs({'crystal_maiden_frostbite','lich_sinister_gaze'}) do
                        local a=bot:GetAbilityByName(name)
                        if a~=nil and not a:IsHidden() and a:IsFullyCastable() then reserve=math.max(reserve,a:GetManaCost()) end
                    end
                    local preserveControl=false
                    if profile[4]=='control' then
                        for _,h in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
                            if Visible(h) and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
                                and GetUnitToUnitDistance(bot,h)<1800 then preserveControl=true end
                        end
                        for _,name in ipairs({'witch_doctor_maledict','witch_doctor_death_ward'}) do
                            local a=bot:GetAbilityByName(name)
                            if a~=nil and not a:IsHidden() and a:IsFullyCastable() then reserve=reserve+a:GetManaCost() end
                        end
                    end
                    if count>=2 and not preserveControl and bot:GetMana()-ability:GetManaCost()>=reserve
                        and CastSafety.Allow(bot,J,ability,'defend-wave') then
                        return {target=target,ability=ability,kind=profile[2]}
                    end
                end
            end
        end
        if not spellsOnly and GetUnitToUnitDistance(bot,target)<=bot:GetAttackRange()
            and Safe(bot,J,0.8) then
            return {target=target,kind='attack'}
        end
    end
    return nil
end
function X.Think(bot,J,spellsOnly)
    if X.HoldingCast(bot) then return true end
    local action=X.GetAction(bot,J,spellsOnly)
    if action==nil then return false end
    bot:SetTarget(action.target)
    if action.kind=='attack' then
        bot:Action_AttackUnit(action.target,true)
        Trace(bot,'attack-siege-creep',action.target)
    else
        bot.shaiTacticalUntil=DotaTime()+action.ability:GetCastPoint()+0.3
        bot.shaiWaveCast={issued=DotaTime(),untilTime=DotaTime()+action.ability:GetCastPoint()+0.2}
        if action.kind=='point' then bot:Action_UseAbilityOnLocation(action.ability,action.target:GetLocation())
        else bot:Action_UseAbilityOnEntity(action.ability,action.target) end
        Trace(bot,action.ability:GetName(),action.target)
    end
    return true
end
return X
