-- Cast penalties are advisory estimates from visible Silencer snapshots.
local X = {}
local SHAI = require(GetScriptDirectory()..'/Customize/shai')
local FarmSafety = require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local states = setmetatable({}, {__mode = 'k'})
local curse = 'modifier_silencer_curse_of_the_silent'
local lastWord = 'modifier_silencer_last_word'

local function Snapshot(bot, J)
    local now = DotaTime()
    local s = states[bot]
    if s == nil or now < s.checked then
        s = {checked = -math.huge, knownAt = -math.huge, printed = -math.huge}
        states[bot] = s
    end
    if now - s.checked >= 0.2 then
        s.checked = now
        for _, enemy in pairs(J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)) do
            if J.IsValidHero(enemy) and enemy:CanBeSeen() and not J.IsSuspiciousIllusion(enemy)
                and enemy:GetUnitName() == 'npc_dota_hero_silencer' then
                local q = enemy:GetAbilityByName('silencer_curse_of_the_silent')
                local e = enemy:GetAbilityByName('silencer_last_word')
                local amp = 1 + enemy:GetSpellAmp()
                s.curseCost = q ~= nil and q:GetSpecialValueInt('damage') * q:GetSpecialValueInt('penalty_duration') * amp or nil
                s.wordCost = e ~= nil and (e:GetSpecialValueInt('damage')
                    + math.max(0, enemy:GetAttributeValue(ATTRIBUTE_INTELLECT) - bot:GetAttributeValue(ATTRIBUTE_INTELLECT))
                        * e:GetSpecialValueFloat('int_multiplier')) * amp or nil
                s.knownAt = now
            end
        end
    end
    if now - s.knownAt > 15 then s.curseCost, s.wordCost = nil, nil end
    return s
end

function X.Allow(bot, J, ability, purpose)
    local hasCurse, hasWord = bot:HasModifier(curse), bot:HasModifier(lastWord)
    local unsafeFarm = (purpose == 'farm' or purpose == 'last-hit') and FarmSafety.GetThreat(bot, J) ~= nil
    if not hasCurse and not hasWord and not unsafeFarm then return true end
    local s = Snapshot(bot, J)
    local curseCost = hasCurse and s.curseCost and bot:GetActualIncomingDamage(s.curseCost, DAMAGE_TYPE_MAGICAL) or 0
    local wordCost = hasWord and s.wordCost and bot:GetActualIncomingDamage(s.wordCost, DAMAGE_TYPE_MAGICAL) or 0
    local protected = bot:IsInvulnerable()
        or J.GetModifierTime(bot, 'modifier_abaddon_borrowed_time') > ability:GetCastPoint() + 0.2
        or J.GetModifierTime(bot, 'modifier_dazzle_shallow_grave') > ability:GetCastPoint() + 0.2
    local reason = nil
    if unsafeFarm then
        reason = 'unsafe-farm-cast'
    elseif not protected and wordCost >= bot:GetHealth() then
        reason = 'last-word-lethal'
    elseif purpose == 'harass' or purpose == 'farm' then
        reason = 'optional-cast'
    elseif purpose == 'last-hit' and (hasWord or bot:WasRecentlyDamagedByAnyHero(2)
        or bot:GetHealth() - curseCost < bot:GetMaxHealth() * 0.65
        or FarmSafety.GetThreat(bot, J) ~= nil) then
        reason = 'unsafe-last-hit'
    elseif purpose == 'channel' and (hasWord or bot:WasRecentlyDamagedByAnyHero(2)
        or FarmSafety.GetThreat(bot, J) ~= nil) then
        reason = 'unsafe-channel'
    end
    if reason ~= nil then
        local now = DotaTime()
        if SHAI.BehaviorTrace and now - s.printed >= 5 then
            print(string.format('[SHAI] safety t=%.2f; hero=%s; reason=cast-penalty; spell=%s; purpose=%s; detail=%s; curseCost=%.0f; wordCost=%.0f; known=%s',
                now, bot:GetUnitName(), ability:GetName(), purpose, reason, curseCost, wordCost, tostring(now - s.knownAt <= 15)))
            s.printed = now
        end
        return false
    end
    return true
end

function X.DamagePurpose(bot, J, target, damage, castPoint, hasControl)
    if J.IsValidHero(target) then
        if J.WillMagicKillTarget(bot, target, damage, castPoint) then return 'kill' end
        if hasControl and target:IsChanneling() then return 'interrupt' end
        if hasControl and J.IsRetreating(bot)
            and (target:GetAttackTarget() == bot or bot:WasRecentlyDamagedByHero(target, 2)) then return 'control' end
        if J.IsInTeamFight(bot, 1200) then return 'teamfight' end
        return 'harass'
    end
    if J.IsValid(target) and J.WillKillTarget(target, damage, DAMAGE_TYPE_MAGICAL, castPoint) then return 'last-hit' end
    return 'farm'
end

-- Shared dispatch policy for the selected hero pool. Explicit control/save/escape
-- remains useful under Curse; optional damage is classified using the chosen unit.
function X.AllowDecision(bot,J,ability,target,kind)
    if not bot:HasModifier(curse) and not bot:HasModifier(lastWord) then return true end
    local purpose=kind
    if kind=='damage' or kind=='damage-control' or kind=='engage' then
        target=target or J.GetProperTarget(bot)
        if kind~='engage' and target~=nil then
            purpose=X.DamagePurpose(bot,J,target,ability:GetAbilityDamage(),ability:GetCastPoint(),kind=='damage-control')
        elseif J.IsRetreating(bot) and kind=='engage' then purpose='escape'
        elseif J.IsInTeamFight(bot,1200) or (kind=='engage' and J.IsGoingOnSomeone(bot)) then purpose='teamfight'
        else purpose='harass' end
    elseif kind=='control' and target~=nil and not J.IsValidHero(target) then purpose='farm'
    elseif kind=='swap' then purpose=target~=nil and target:GetTeam()==bot:GetTeam() and 'save' or 'control' end
    return X.Allow(bot,J,ability,purpose)
end

return X
