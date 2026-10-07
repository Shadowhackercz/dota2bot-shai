if GetScriptDirectory == nil then GetScriptDirectory = function() return 'bots' end end
local SHAI = require(GetScriptDirectory()..'/Customize/shai')
local Dota2Teams = { defaultPostfix = SHAI.Name, maxTeamSize = 12 }

local nicknames = {
    'Nova', 'Rook', 'Nyx', 'Echo', 'Flux', 'Bolt', 'Rune', 'Ash',
    'Nox', 'Vex', 'Lynx', 'Onyx', 'Frost', 'Ember', 'Moss', 'Spark',
    'Atlas', 'Orion', 'Vega', 'Argo', 'Hex', 'Iris', 'Dusk', 'Dawn',
    'Drift', 'Pulse', 'Kite', 'Wolf', 'Raven', 'Hawk', 'Owl', 'Fox',
    'Jade', 'Opal', 'Ruby', 'Zinc', 'Cobalt', 'Slate', 'Flint', 'Quartz',
    'Aero', 'Comet', 'Solar', 'Lunar', 'Orbit', 'Apex', 'Zero', 'Pixel',
}

-- One shared shuffled pool keeps generated names unique across both teams.
-- Explicit names in Customize are preserved; "Random" requests a generated name.
function Dota2Teams.generateTeams(overrides)
    overrides = overrides or {}
    local reserved, pool = {}, {}
    for _, side in ipairs({'Radiant', 'Dire'}) do
        for i = 1, Dota2Teams.maxTeamSize do
            local name = (overrides[side] or {})[i]
            if name and name ~= 'Random' then reserved[name] = true end
        end
    end
    for _, nickname in ipairs(nicknames) do
        local name = SHAI.Name..'.'..nickname
        if not reserved[name] then table.insert(pool, name) end
    end
    for i = #pool, 2, -1 do
        local j = RandomInt(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local teams = { Radiant = {}, Dire = {} }
    for _, side in ipairs({'Radiant', 'Dire'}) do
        for i = 1, Dota2Teams.maxTeamSize do
            local name = (overrides[side] or {})[i]
            teams[side][i] = name and name ~= 'Random' and name or table.remove(pool)
        end
    end
    return teams
end

return Dota2Teams
