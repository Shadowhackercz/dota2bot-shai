-- Spend the remaining temporary life; do not treat it as a normal low-HP hero.
local X={}
X.Modifier='modifier_skeleton_king_reincarnation_scepter_active'
local Chain=require(GetScriptDirectory()..'/FunLib/shai_control_chain')
local Safety=require(GetScriptDirectory()..'/FunLib/shai_cast_safety')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
function X.Active(bot)
    return bot:HasModifier(X.Modifier) and bot:IsAlive() and bot:GetUnitName()=='npc_dota_hero_skeleton_king'
end
function X.Remaining(bot,J)
    if not X.Active(bot) then return 0 end
    local seconds=J.GetModifierTime(bot,X.Modifier)
    return type(seconds)=='number' and seconds==seconds and seconds>0 and seconds<60 and seconds or 0
end
local function Visible(h)
    return h~=nil and not h:IsNull() and h:CanBeSeen() and h:IsAlive() and not h:IsInvulnerable()
end
local function Trace(bot,reason,target,seconds)
    if not SHAI.BehaviorTrace or bot.shaiWraithReason==reason and DotaTime()-(bot.shaiWraithPrinted or -math.huge)<3 then return end
    bot.shaiWraithReason,bot.shaiWraithPrinted=reason,DotaTime()
    print('[SHAI] wraith t='..DotaTime()..'; hero='..bot:GetUnitName()..'; reason='..reason..'; target='..target:GetUnitName()..'; remaining='..seconds)
end
function X.GetPlan(bot,J)
    local seconds=X.Remaining(bot,J)
    if seconds<=0 then return nil end
    local best,score
    local q=bot:GetAbilityByName('skeleton_king_hellfire_blast')
    local function Consider(h,hero)
        if not Visible(h) or hero and (not J.IsValidHero(h) or J.IsSuspiciousIllusion(h)) then return end
        local distance=GetUnitToUnitDistance(bot,h)
        local walk=math.max(0,distance-bot:GetAttackRange())/math.max(1,bot:GetCurrentMovementSpeed())
        local canHit=not h:IsAttackImmune() and walk+bot:GetAttackPoint()+0.15<seconds
        local canCast=hero and q~=nil and q:IsFullyCastable() and not q:IsHidden() and not bot:IsSilenced()
            and not h:IsMagicImmune() and J.CanCastOnNonMagicImmune(h) and J.CanCastOnTargetAdvanced(h)
            and distance<=q:GetCastRange() and Chain.Delay(bot,h,q)+0.1<seconds
        if not canHit and not canCast then return end
        local value=(hero and 10000 or 0)-distance
        if bot:GetAttackTarget()==h then value=value+250 end
        local shared=bot.shaiGankPlan
        if shared and shared.phase=='engage' and shared.target==h and DotaTime()>=shared.created
            and DotaTime()<shared.expires and DotaTime()-shared.updated<1.2 then value=value+500 end
        if best==nil or value>score then best={target=h,hero=hero,seconds=seconds,canHit=canHit,q=canCast and q or nil}; score=value end
    end
    for _,h in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do Consider(h,true) end
    if best==nil then
        for _,h in pairs(bot:GetNearbyLaneCreeps(1600,true)) do Consider(h,false) end
        for _,h in pairs(bot:GetNearbyNeutralCreeps(1600)) do Consider(h,false) end
    end
    return best
end
function X.Think(bot,J)
    if not X.Active(bot) then bot.shaiWraithCast=nil; return false end
    -- Never interrupt a release, queue, channel or real disable.
    local lease=bot.shaiWraithCast
    if lease and DotaTime()>=lease.created and DotaTime()<lease.expires then return true end
    bot.shaiWraithCast=nil
    if J.CanNotUseAction(bot) then return true end
    local p=X.GetPlan(bot,J)
    if p==nil then return false end -- unknown modifier duration must not freeze normal callbacks
    bot:SetTarget(p.target)
    if p.q and not J.CanNotUseAbility(bot) and J.CanCastOnNonMagicImmune(p.target)
        and J.CanCastOnTargetAdvanced(p.target) and not Chain.Wait(bot,p.target,J,p.q,'unit')
        and Safety.Allow(bot,J,p.q,'control') then
        bot:Action_UseAbilityOnEntity(p.q,p.target)
        bot.shaiWraithCast={created=DotaTime(),expires=DotaTime()+p.q:GetCastPoint()+0.2}
        Chain.Reserve(bot,p.target,p.q,'unit',{})
        Trace(bot,'stun',p.target,p.seconds); return true
    end
    if p.canHit then
        if bot:GetAttackTarget()~=p.target then bot:Action_AttackUnit(p.target,true) end
        Trace(bot,p.hero and 'attack-hero' or 'attack-creep',p.target,p.seconds); return true
    end
    return false
end
return X
