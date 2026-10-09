-- Bounded combat credit from current attacks, available spells and one mana pool.
-- This is a conservative forecast, not a full engine fight simulation.
local X={}
local CastSafety=require(GetScriptDirectory()..'/FunLib/shai_cast_safety')
local Wraith=require(GetScriptDirectory()..'/FunLib/shai_wraith_form')
local profiles={
    {'lion_impale','point','damage'}, {'lion_finger_of_death','unit','damage'},
    {'skeleton_king_hellfire_blast','unit','damage'}, {'sven_storm_bolt','unit'},
    {'dragon_knight_dragon_tail','unit','damage'}, {'dragon_knight_breathe_fire','point','damage'},
    {'vengefulspirit_magic_missile','unit','magic_missile_damage'}, {'vengefulspirit_wave_of_terror','point','damage'},
    {'centaur_hoof_stomp','self','stomp_damage','radius'}, {'centaur_double_edge','unit','edge_damage',nil,'edge'},
    {'tidehunter_gush','unit','gush_damage'}, {'tidehunter_ravage','self',nil,'radius'},
    {'crystal_maiden_crystal_nova','point','nova_damage'}, {'crystal_maiden_frostbite','unit','damage_per_second',nil,'dot'},
    {'zuus_arc_lightning','unit','arc_damage'}, {'zuus_lightning_bolt','unit','damage'},
    {'zuus_thundergods_wrath','global','damage'}, {'luna_lucent_beam','unit','beam_damage'},
    {'sniper_assassinate','unit','damage'}, {'sniper_shrapnel','point','shrapnel_damage',nil,'zone'},
    {'lich_frost_nova','unit','damage',nil,'nova'}, {'lich_chain_frost','unit','damage'},
    {'witch_doctor_paralyzing_cask','unit','base_damage'}, {'witch_doctor_maledict','point',nil,nil,'maledict'},
    {'witch_doctor_death_ward','point','damage',nil,'ward'},
    {'warlock_rain_of_chaos','point','golem_dmg',nil,'golem'},
}
local profileByName={}
for _,p in ipairs(profiles) do profileByName[p[1]]=p end
local function Special(a,key)
    if key==nil then return 0 end
    return math.max(0,a:GetSpecialValueFloat(key))
end
local function DamageType(p)
    return p[5]=='golem' and DAMAGE_TYPE_PHYSICAL or p[5]=='ward' and DAMAGE_TYPE_PURE or DAMAGE_TYPE_MAGICAL
end
local function TargetVisible(target,J)
    return target~=nil and not target:IsNull() and target:CanBeSeen() and J.IsValidHero(target) and not J.IsSuspiciousIllusion(target)
end
function X.Member(h,target,J,options,context)
    context=context or {}
    local p={attacks=0,spells=0,summons=0,total=0,mana=0,castTime=0,available={},rejected={},control=0}
    if not TargetVisible(target,J) or not h:IsAlive() or h:IsStunned() or h:IsHexed() then return p end
    local horizon=context.horizon or 4
    if Wraith.Active(h) then horizon=math.min(horizon,Wraith.Remaining(h,J)) end
    local remainingMana=h:GetMana()
    local revive=h:GetAbilityByName('skeleton_king_reincarnation')
    if not Wraith.Active(h) and revive~=nil and revive:GetLevel()>0 and revive:GetCooldownTimeRemaining()<=3 then
        remainingMana=math.max(0,remainingMana-revive:GetManaCost())
    end
    local distance=GetUnitToUnitDistance(h,target)
    local moving=not context.future and math.max(0,distance-h:GetAttackRange()-50)/math.max(200,h:GetCurrentMovementSpeed()) or 0
    local seen={}
    local function Credit(a,spec,control)
        local name=a:GetName()
        local isItem=name:match('^item_')~=nil
        if seen[name] then return end
        seen[name]=true
        if spec and spec[2]=='unit' and context.block then p.rejected[name]='spell-block'; return end
        if not a:IsFullyCastable() or a:IsHidden() or (isItem and h:IsMuted())
            or (not isItem and h:IsSilenced()) then p.rejected[name]='unavailable'; return end
        local cost=a:GetManaCost()
        if cost>remainingMana then p.rejected[name]='mana'; return end
        local range=spec and (spec[2]=='self' and Special(a,spec[4]) or a:GetCastRange()) or control.range
        local walk=not context.future and math.max(0,distance-range)/math.max(200,h:GetCurrentMovementSpeed()) or 0
        if spec and spec[2]=='global' then walk=0 end
        local delay=a:GetCastPoint()+0.2+walk
        if p.castTime+delay>=horizon then p.rejected[name]='too-late'; return end
        if not isItem and not CastSafety.Allow(h,J,a,control and 'control' or spec and spec[5]=='ward' and 'channel' or 'teamfight') then p.rejected[name]='cast-penalty'; return end
        local raw=spec and (spec[3] and Special(a,spec[3]) or a:GetAbilityDamage()) or 0
        local kind=spec and spec[5]
        local uptime=math.max(0,horizon-p.castTime-delay)
        if kind=='edge' then
            raw=raw+h:GetAttributeValue(ATTRIBUTE_STRENGTH)*Special(a,'strength_damage')/100
            if h:GetHealth()-raw<h:GetMaxHealth()*0.4 then p.rejected[name]='self-damage'; return end
        elseif kind=='nova' then raw=raw+Special(a,'aoe_damage')
        elseif kind=='dot' then raw=raw*math.min(uptime,Special(a,'duration'))
        elseif kind=='zone' then
            -- No credit for a zone the victim can immediately walk out of.
            uptime=math.min(math.max(0,uptime-Special(a,'damage_delay')),context.controlSeconds or 0)
            raw=raw*uptime
        elseif kind=='maledict' then
            -- Credit the DoT only. Delayed burst depends on actual lost HP;
            -- don't recursively multiply predicted allied damage by Maledict.
            raw=a:GetAbilityDamage()*math.min(uptime,4)
        elseif kind=='ward' then
            if target:IsAttackImmune() then p.rejected[name]='attack-immune'; return end
            uptime=math.min(uptime,3,context.controlSeconds or 0)
            if uptime<1 or context.backups and context.backups>0
                or target:GetEstimatedDamageToTarget(true,h,delay+1,DAMAGE_TYPE_ALL)>=h:GetHealth()*0.6 then
                p.rejected[name]='unsafe-channel'; return
            end
            raw=raw*math.floor(uptime) -- credit at most one ward hit per second
            delay=delay+uptime
        elseif kind=='golem' then
            raw=raw*math.min(2,math.floor(uptime/1.5)) -- capped follow-up, no assumed full summon uptime
        end
        local dtype=spec and DamageType(spec) or DAMAGE_TYPE_MAGICAL
        if spec and dtype==DAMAGE_TYPE_MAGICAL and (target:IsMagicImmune() or context.bkb and not context.caught) then
            raw=0
        end
        if spec and dtype==DAMAGE_TYPE_PHYSICAL and target:IsAttackImmune() then raw=0 end
        local amp=(kind=='ward' or kind=='golem') and 1 or 1+h:GetSpellAmp()
        local damage=target:GetActualIncomingDamage(raw*amp,dtype)*0.75
        if damage<=0 and control==nil then return end -- don't spend hypothetical mana on a valueless spell
        remainingMana=remainingMana-cost; p.mana=p.mana+cost; p.castTime=p.castTime+delay
        p.available[name]=true
        if control~=nil then p.control=p.control+1 end
        if kind=='ward' or kind=='golem' then p.summons=p.summons+damage else p.spells=p.spells+damage end
    end
    -- Reserve the first viable opener before spending its mana on extra nukes.
    for _,opt in ipairs(not context.attacksOnly and options or {}) do
        Credit(opt.ability,profileByName[opt.ability:GetName()],opt)
        if p.available[opt.ability:GetName()] then break end
    end
    for _,spec in ipairs(not context.attacksOnly and not context.controlsOnly and profiles or {}) do
        local a=h:GetAbilityByName(spec[1]); if a~=nil then Credit(a,spec,nil) end
    end
    if not context.attacksOnly and not context.controlsOnly then
        for slot=0,5 do
            local item=h:GetItemInSlot(slot)
            if item~=nil and item:GetName():match('^item_dagon[2345]?$') then
                Credit(item,{item:GetName(),'unit','damage'},nil)
            end
        end
    end
    -- Physical attacks exclude uncast steroid abilities and spell estimates.
    local attackTime=math.max(0,horizon-moving-p.castTime)
    if not context.controlsOnly and not target:IsAttackImmune() then
        p.attacks=target:GetActualIncomingDamage(h:GetAttackDamage(),DAMAGE_TYPE_PHYSICAL)
            *math.floor(attackTime/math.max(0.2,h:GetSecondsPerAttack()))*0.65
    end
    p.total=p.attacks+p.spells+p.summons
    return p
end
function X.Team(members,target,J,optionsFor,context)
    local p={total=0,attacks=0,spells=0,summons=0,mana=0,members={}}
    for _,h in ipairs(members) do
        local m=X.Member(h,target,J,optionsFor(h),context)
        p.members[h:GetPlayerID()]=m
        for _,key in ipairs({'total','attacks','spells','summons','mana'}) do p[key]=p[key]+m[key] end
    end
    return p
end
return X
