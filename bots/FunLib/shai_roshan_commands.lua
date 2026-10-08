local X = {}
local function Real(unit)
    return unit ~= nil and not unit:IsNull() and unit:IsHero() and not unit:IsIllusion() and unit:IsAlive()
end

function X.RequestSafe(bot, J)
    if bot.shaiRoshanRequestUntil == nil or DotaTime() >= bot.shaiRoshanRequestUntil
        or bot.shaiRoshanParticipants == nil or #bot.shaiRoshanParticipants < 3 then return false end
    local pit = J.GetCurrentRoshanLocation()
    if not J.IsRoshanAlive() or J.IsRoshanCloseToChangingSides()
        or #(J.GetEnemiesNearLoc(pit, 1600) or {}) > 0
        or #J.GetLastSeenEnemiesNearLoc(pit, 1600) > 0 then return false end
    local tank = false
    for _, h in ipairs(bot.shaiRoshanParticipants) do
        if not Real(h) or J.GetHP(h) < 0.55 or GetUnitToLocationDistance(h, pit) > 4500
            or (IsPlayerBot(h:GetPlayerID()) and h:GetActiveMode() == BOT_MODE_RETREAT) then return false end
        if J.IsCore(h) and h:GetLevel() >= 12 and J.GetHP(h) >= 0.65 then tank = true end
    end
    return tank and J.HasEnoughDPSForRoshan(bot.shaiRoshanParticipants)
end

function X.Handle(bot, J, chat)
    local text = string.lower(chat.string or ''):match('^%s*(.-)%s*$')
    if text ~= '!roshan' and text ~= '!rosh' then return false end
    if GetGameState() ~= GAME_STATE_GAME_IN_PROGRESS or IsPlayerBot(chat.player_id)
        or GetTeamForPlayer(chat.player_id) ~= bot:GetTeam() then return true end
    local units, leader, requester = GetUnitList(UNIT_LIST_ALLIED_HEROES), nil, nil
    for _, h in ipairs(units) do
        if Real(h) then
            if h:GetPlayerID() == chat.player_id then requester = h end
            if IsPlayerBot(h:GetPlayerID()) and (leader == nil or h:GetPlayerID() < leader:GetPlayerID()) then leader = h end
        end
    end
    if leader ~= bot then return true end
    local now = DotaTime()
    if bot.shaiLastRoshanChat ~= nil and now >= bot.shaiLastRoshanChat and now - bot.shaiLastRoshanChat < 8 then return true end
    bot.shaiLastRoshanChat = now
    local function Reply(message)
        bot:ActionImmediate_Chat(message, false)
        print('[SHAI] roshan-request t='..now..'; player='..chat.player_id..'; reply='..message)
        return true
    end
    if requester == nil then return Reply('Not now - you need to be alive.') end
    if not J.IsRoshanAlive() then return Reply('Not now - Roshan is not available.') end
    if J.GetEnemiesAroundAncient(bot, 3200) > 0 or J.GetHP(GetAncient(bot:GetTeam())) < 0.8 then
        return Reply('Not now - defend our base.')
    end
    if J.IsRoshanCloseToChangingSides() then return Reply('Not now - Roshan is about to move.') end
    if J.GetNumOfAliveHeroes(false) < J.GetNumOfAliveHeroes(true) then
        return Reply('Not now - we are outnumbered.')
    end
    local pit = J.GetCurrentRoshanLocation()
    if #(J.GetEnemiesNearLoc(pit, 1600) or {}) > 0 or #J.GetLastSeenEnemiesNearLoc(pit, 1600) > 0 then
        return Reply('Not now - enemies are near Roshan.')
    end
    if J.GetHP(requester) < 0.55 or GetUnitToLocationDistance(requester, pit) > 4500 then
        return Reply('Not yet - recover and move closer to Roshan.')
    end
    local participants, bots, tank = {requester}, {}, false
    local seen = {[requester:GetPlayerID()] = true}
    for _, h in ipairs(units) do
        if Real(h) and IsPlayerBot(h:GetPlayerID()) and not seen[h:GetPlayerID()]
            and J.GetHP(h) >= 0.55 and GetUnitToLocationDistance(h, pit) <= 4500
            and h:GetActiveMode() ~= BOT_MODE_RETREAT and h.shaiRoshanCheck ~= nil
            and h.shaiRoshanCheck() > 0 then
            seen[h:GetPlayerID()] = true
            table.insert(participants, h)
            table.insert(bots, h)
            if J.IsCore(h) and h:GetLevel() >= 12 and J.GetHP(h) >= 0.65 then tank = true end
        end
    end
    if J.IsCore(requester) and requester:GetLevel() >= 12 and J.GetHP(requester) >= 0.65 then tank = true end
    if #bots < 2 or not tank then return Reply('Not yet - we need more healthy allies ready nearby.') end
    if not J.HasEnoughDPSForRoshan(participants) then return Reply('Not yet - we need more damage.') end
    for _, h in ipairs(bots) do
        h.shaiRoshanRequestUntil = now + 30
        h.shaiRoshanParticipants = participants
    end
    return Reply('Yes, we can try Roshan. Group up - I will reassess if it becomes unsafe.')
end
return X
