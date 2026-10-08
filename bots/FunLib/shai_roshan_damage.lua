-- Conservative physical-damage proxy, not a simulation of tanking/spells/items.
local X = {}
function X.Ready(heroes, now, armorReduction)
    local minutes = math.floor(math.max(0, now) / 60)
    local health, total = 6000 + 260 * minutes, 0
    for _, hero in ipairs(heroes) do
        local armor = math.max(0, 30 + 0.375 * minutes - armorReduction(hero))
        -- Keep the inherited armor approximation; use actual attack interval.
        total = total + hero:GetAttackDamage() / math.max(0.2, hero:GetSecondsPerAttack())
            * (1 - armor / (armor + 20))
    end
    return total >= health / 60, total
end
return X
