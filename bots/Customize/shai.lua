-- SHAI development pool. This file is pure Lua, not generated from TypeScript.
local SHAI = { Name = 'SHAI', HeroPoolEnabled = true, InitialPickDelay = 1, PickInterval = 1 }
-- Temporary development telemetry; set false for quiet normal play.
SHAI.BehaviorTrace = true

-- Three candidates per primary role; humans can still select any hero in Dota.
SHAI.RolePools = {
    {'npc_dota_hero_skeleton_king', 'npc_dota_hero_luna', 'npc_dota_hero_sven'},
    {'npc_dota_hero_zuus', 'npc_dota_hero_dragon_knight', 'npc_dota_hero_sniper'},
    {'npc_dota_hero_axe', 'npc_dota_hero_tidehunter', 'npc_dota_hero_centaur'},
    {'npc_dota_hero_lion', 'npc_dota_hero_vengefulspirit', 'npc_dota_hero_witch_doctor'},
    {'npc_dota_hero_crystal_maiden', 'npc_dota_hero_lich', 'npc_dota_hero_warlock'},
}
SHAI.HeroPool = {}
for _, pool in ipairs(SHAI.RolePools) do
    for _, hero in ipairs(pool) do table.insert(SHAI.HeroPool, hero) end
end

function SHAI.IsHeroEnabled(hero)
    if not SHAI.HeroPoolEnabled then return true end
    for _, enabled in ipairs(SHAI.HeroPool) do
        if enabled == hero then return true end
    end
    return false
end

function SHAI.FilterHeroPositions(positions)
    local result, count = {}, 0
    for hero, weights in pairs(positions) do
        if SHAI.IsHeroEnabled(hero) then
            result[hero] = weights
            count = count + 1
        end
    end
    assert(count > 0, '[SHAI] No supported heroes in the configured pool')
    return result
end

-- A finite pass is essential: the upstream recursive fill never terminates
-- when a restricted pool contains fewer than six candidates for a role.
function SHAI.GetRolePool(positions, position)
    local preferred = {}
    for _, hero in ipairs(SHAI.RolePools[position] or {}) do
        if positions[hero] and SHAI.IsHeroEnabled(hero) then table.insert(preferred, hero) end
    end
    if #preferred > 0 then return preferred end
    local ranked = {}
    for hero, weights in pairs(positions) do
        if SHAI.IsHeroEnabled(hero) then
            table.insert(ranked, { name = hero, weight = weights[position] or 0 })
        end
    end
    table.sort(ranked, function(a, b)
        if a.weight == b.weight then return a.name < b.name end
        return a.weight > b.weight
    end)
    local result = {}
    local minimumWeight = ranked[1] and math.min(25, ranked[1].weight) or 0
    for _, candidate in ipairs(ranked) do
        if candidate.weight > 0 and candidate.weight >= minimumWeight then
            table.insert(result, candidate.name)
        end
    end
    -- Keep the enabled pool closed even when it has no specialist for a role.
    if #result == 0 then
        for _, candidate in ipairs(ranked) do table.insert(result, candidate.name) end
    end
    return result
end

return SHAI
