-- Observations only: never issues actions or changes mode desires.
local X = {}
local states = setmetatable({}, { __mode = 'k' })
local modeNames = {}
for key, value in pairs(_G) do
    if type(value) == 'number' and string.match(key, '^BOT_MODE_[A-Z_]+$')
        and not string.find(key, 'DESIRE') then modeNames[value] = key end
end

local function Name(unit)
    if unit == nil or unit:IsNull() then return 'none' end
    return unit:GetUnitName()
end

function X.Observe(bot, now, enabled)
    if not enabled or bot == nil or bot:IsNull() or bot:IsIllusion() then return end
    local s = states[bot]
    if s == nil or now < s.sample then
        s = {sample = -math.huge, output = -math.huge, summary = now,
            switches = 0, rapid = 0, reversals = 0, changed = now}
        states[bot] = s
    end
    if now - s.sample < 0.25 then return end
    s.sample = now
    local mode, alive = bot:GetActiveMode(), bot:IsAlive()
    local target = Name(bot:GetTarget())
    local changed = s.mode ~= mode or s.alive ~= alive or s.target ~= target
    if s.mode ~= nil and s.mode ~= mode and alive and s.alive then
        s.switches = s.switches + 1
        if now - s.changed <= 1 then s.rapid = s.rapid + 1 end
        if mode == s.previous and now - s.changed <= 2 then
            s.reversals = s.reversals + 1
        end
        s.previous, s.changed = s.mode, now
    elseif s.alive ~= alive then
        s.previous, s.changed = nil, now
    end
    s.mode, s.alive, s.target = mode, alive, target
    s.pending = s.pending or changed
    local summary = now - s.summary >= 10
    if (s.pending and now - s.output >= 1) or summary then
        local loc = bot:GetLocation()
        print(string.format('[SHAI] behavior t=%.2f; team=%s; player=%s; hero=%s; mode=%s; desire=%.2f; alive=%s; hp=%.2f; mana=%.2f; x=%.0f; y=%.0f; target=%s; attack=%s; switches=%d; rapid=%d; reversals=%d',
            now, tostring(bot:GetTeam()), tostring(bot:GetPlayerID()), bot:GetUnitName(), modeNames[mode] or tostring(mode),
            bot:GetActiveModeDesire(), tostring(alive), bot:GetHealth() / math.max(1, bot:GetMaxHealth()),
            bot:GetMana() / math.max(1, bot:GetMaxMana()), loc.x, loc.y, target, Name(bot:GetAttackTarget()),
            s.switches, s.rapid, s.reversals))
        s.output, s.pending = now, false
        if summary then s.summary = now end
    end
end

return X
