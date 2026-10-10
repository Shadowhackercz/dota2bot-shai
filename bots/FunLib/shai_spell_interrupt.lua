-- Immediate unit-target interrupts. Do not walk into range for a channel.
local X = {}
local CastSafety = require(GetScriptDirectory()..'/FunLib/shai_cast_safety')

function X.Try(bot, J, ability, bonusRange)
    if J.CanNotUseAbility(bot) or bot:IsInvisible() or not J.CanCastAbility(ability) then return false end
    local range = ability:GetCastRange() + (bonusRange or 0)
    for _, enemy in ipairs(J.GetNearbyHeroes(bot, math.min(1600, range), true, BOT_MODE_NONE)) do
        if J.IsValidHero(enemy) and enemy:CanBeSeen() and not J.IsSuspiciousIllusion(enemy)
            and enemy:IsChanneling() and J.IsInRange(bot, enemy, range)
            and J.CanCastOnNonMagicImmune(enemy) and J.CanCastOnTargetAdvanced(enemy)
            and CastSafety.Allow(bot, J, ability, 'interrupt') then
            J.SetQueuePtToINT(bot, false)
            bot:ActionQueue_UseAbilityOnEntity(ability, enemy)
            return true
        end
    end
    return false
end

return X
