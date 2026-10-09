-- Use ready escape tools against one observed outmatching pursuer as well.
local X={}
local Safety=require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
function X.Try(bot,J,stomp,stampede,CastSafety)
    if not bot:IsAlive() or J.CanNotUseAction(bot) or J.CanNotUseAbility(bot) then return false end
    local now=DotaTime()
    local pending=bot.shaiCentaurEscapeCast
    if pending and now>=pending.created and now<pending.expires then return true end
    bot.shaiCentaurEscapeCast=nil
    if not J.IsRetreating(bot) and J.IsGoingOnSomeone(bot) then return false end
    local threat=Safety.GetThreat(bot,J)
    if threat==nil then return false end
    local enemy=threat.enemy
    local chosen,reason
    if not threat.memory and enemy and not enemy:IsNull() and enemy:CanBeSeen()
        and J.IsValidHero(enemy) and not J.IsSuspiciousIllusion(enemy)
        and stomp and stomp:IsFullyCastable() and not stomp:IsHidden()
        and J.CanCastOnNonMagicImmune(enemy) and not J.IsDisabled(enemy) then
        local point=stomp:GetCastPoint()
        local radius=stomp:GetSpecialValueInt('radius')
        -- Don't spend the wind-up on a target that can already leave the AoE.
        if GetUnitToUnitDistance(bot,enemy)+enemy:GetCurrentMovementSpeed()*point<=radius-25
            and enemy:GetEstimatedDamageToTarget(true,bot,point+0.15,DAMAGE_TYPE_ALL)<bot:GetHealth()*0.8
            and CastSafety.AllowDecision(bot,J,stomp,enemy,'control') then chosen,reason=stomp,'escape-stomp' end
    end
    if chosen==nil and stampede and stampede:IsFullyCastable() and not stampede:IsHidden()
        and not bot:IsRooted() and not bot:HasModifier('modifier_bloodseeker_rupture')
        and not bot:HasModifier('modifier_centaur_cart') and not bot:HasModifier('modifier_centaur_stampede')
        and CastSafety.AllowDecision(bot,J,stampede,nil,'escape') then chosen,reason=stampede,'escape-stampede' end
    if chosen==nil then return false end
    bot:Action_UseAbility(chosen)
    bot.shaiCentaurEscapeCast={created=now,expires=now+math.max(0.15,chosen:GetCastPoint()+0.15)}
    if SHAI.BehaviorTrace then
        print('[SHAI] escape t='..now..'; hero='..bot:GetUnitName()..'; reason='..reason..'; enemy='..threat.name)
    end
    return true
end
return X
