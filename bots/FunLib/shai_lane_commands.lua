-- Resolve geographic lane names to roles without taking another human's role.
local X = {}

function X.Resolve(command, team, playerID, players, roles, isBot)
    local candidates
    if command == '!mid' then candidates = {2}
    elseif command == '!top' then candidates = team == TEAM_RADIANT and {3,4} or {1,5}
    elseif command == '!bottom' or command == '!bot' then
        candidates = team == TEAM_RADIANT and {1,5} or {3,4}
    else return nil end
    local ownIndex
    for i, id in ipairs(players) do if id == playerID then ownIndex = i end end
    if ownIndex == nil or isBot(playerID) then return nil end
    for _, role in ipairs(candidates) do
        for i, id in ipairs(players) do
            if roles[i] == role and (id == playerID or isBot(id)) then
                return role
            end
        end
    end
    return nil
end

return X
