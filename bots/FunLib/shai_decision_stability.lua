-- Small decision memory; no engine calls or cached world state.
local X = {}

function X.NewRetreatGuard()
    local held, untilTime, previousTime = nil, nil, nil
    return function(desire, now, active, ordinary)
        if not active or not ordinary or (previousTime ~= nil and now < previousTime) then
            held, untilTime = nil, nil
        end
        previousTime = now
        if not active or not ordinary then return desire end
        -- Hold only a retreat already chosen by the engine, for at most 0.9s
        -- after its last equally strong signal. Rising danger applies immediately.
        if held == nil or now >= untilTime or desire >= held then
            held = desire >= 0.65 and desire or nil
            untilTime = now + 0.9
        end
        return held ~= nil and math.max(desire, held) or desire
    end
end

function X.SelectTarget(current, candidate, untilTime, now, valid)
    if not valid(candidate) then
        if valid(current) then return current, untilTime end
        return nil, -90
    end
    if current == candidate then return current, untilTime end
    if valid(current) and now < untilTime then return current, untilTime end
    return candidate, now + 1.2
end

return X
