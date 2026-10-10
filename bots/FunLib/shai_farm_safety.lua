-- Visible local threats and bounded team snapshots; no hidden state queries.
local X = {}
local SHAI = require(GetScriptDirectory()..'/Customize/shai')
local Memory = require(GetScriptDirectory()..'/FunLib/shai_threat_memory')
local Runtime = require(GetScriptDirectory()..'/FunLib/shai_runtime')
local Escape = require(GetScriptDirectory()..'/FunLib/shai_escape_route')
local states = setmetatable({}, {__mode = 'k'})

local function VisibleHero(unit, J)
    return unit~=nil and not unit:IsNull() and unit:CanBeSeen() and J.IsValidHero(unit) and not J.IsSuspiciousIllusion(unit)
end

function X.GetThreat(bot, J)
    local now = DotaTime()
    if not bot:IsAlive() or now < 0 or bot:IsInvulnerable()
        or bot:HasModifier('modifier_skeleton_king_reincarnation_scepter_active')
        or bot:HasModifier('modifier_abaddon_borrowed_time')
        or bot:HasModifier('modifier_dazzle_shallow_grave') then
        states[bot] = nil
        Escape.ResetGround(bot)
        return nil
    end
    local s = states[bot]
    if s == nil or now < s.checked then
        s = {checked = -math.huge, untilTime = -math.huge, printed = -math.huge}
        states[bot] = s
    end
    if now - s.checked < 0.2 then return now < s.untilTime and s.threat or nil end
    s.checked = now
    Memory.Observe(bot,J)
    local enemies = J.GetNearbyHeroes(bot, 1400, true, BOT_MODE_NONE)
    local allies = nil
    local hp = bot:GetHealth()
    local threat = nil
    for _, enemy in pairs(enemies) do
        if VisibleHero(enemy, J) and not enemy:IsStunned() and not enemy:IsHexed() then
            local distance = GetUnitToUnitDistance(bot, enemy)
            local reach = math.min(1200, enemy:GetAttackRange() + enemy:GetCurrentMovementSpeed() * 0.6 + 150)
            local attacked = enemy:GetAttackTarget() == bot or bot:WasRecentlyDamagedByHero(enemy, 1.5)
            local approaching = enemy:IsFacingLocation(bot:GetLocation(), 75)
            local dominantNearby=now>=600 and enemy:GetLevel()>=bot:GetLevel()+5 and distance<=math.min(1100,reach+200)
            if distance <= 325 or (distance <= reach and (attacked or approaching)) or dominantNearby then
                local incoming = enemy:GetEstimatedDamageToTarget(true, bot, 2, DAMAGE_TYPE_ALL)
                local outgoing = bot:GetEstimatedDamageToTarget(true, enemy, 2, DAMAGE_TYPE_ALL)
                local outmatched = enemy:GetHealth() > outgoing * 1.15
                    and (incoming >= math.max(200, hp * 0.55)
                        or (incoming > outgoing * 1.5 and enemy:GetLevel() >= bot:GetLevel() + 3))
                if outmatched then
                    allies = allies or J.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE)
                    local groupDamage = outgoing
                    for _, ally in pairs(allies) do
                        if ally ~= bot and VisibleHero(ally, J) and ally:GetHealth() > ally:GetMaxHealth() * 0.3
                            and (ally:GetAttackTarget() == enemy or enemy:GetAttackTarget() == ally)
                            and GetUnitToUnitDistance(ally, enemy) <= math.min(1200, ally:GetAttackRange() + 250) then
                            groupDamage = groupDamage + ally:GetEstimatedDamageToTarget(true, enemy, 2, DAMAGE_TYPE_ALL)
                        end
                    end
                    if groupDamage < enemy:GetHealth() * 1.15 or incoming >= hp * 0.75 then
                        if threat == nil or incoming / hp > threat.severity then
                            -- Snapshot the last visible position; never track a hidden handle through fog.
                            local loc = enemy:GetLocation()
                            threat = {enemy = enemy, location = Vector(loc.x, loc.y, loc.z), severity = incoming / hp,
                                reason = 'unsafe-farm', name = enemy:GetUnitName()}
                        end
                    end
                end
            end
        end
    end
    if threat==nil then threat=Memory.GetConcern(bot,J,bot:GetLocation()) end
    if threat ~= nil then
        s.threat, s.untilTime = threat, threat.memory and math.min(now+0.75,threat.seenAt+5.5) or now+0.75
        if SHAI.BehaviorTrace and now - s.printed >= 5 then
            print(string.format('[SHAI] safety t=%.2f; hero=%s; reason=%s; enemy=%s; severity=%.2f; age=%.2f; confidence=%.2f; radius=%.0f; x=%.0f; y=%.0f',
                now, bot:GetUnitName(), threat.reason, threat.name, threat.severity,threat.age or 0,
                threat.confidence or 1,threat.radius or 0,threat.location.x,threat.location.y))
            s.printed = now
        end
    elseif now >= s.untilTime or s.threat~=nil and s.threat.memory then
        s.threat = nil
    end
    if s.threat==nil then Escape.ResetGround(bot) end
    return s.threat
end

function X.InterruptFarm(bot, J)
    local cast=bot.shaiCentaurEscapeCast
    if cast then
        if bot:IsAlive() and DotaTime()>=cast.created and DotaTime()<cast.expires then return true end
        bot.shaiCentaurEscapeCast=nil
    end
    if Escape.HoldingJump(bot) or Escape.HoldingAlignment(bot) then return true end
    local threat = X.GetThreat(bot, J)
    if threat == nil then bot.shaiEscapeMove=nil; return false end
    -- Do not cancel an ongoing escape, spell or teleport merely to issue a move.
    if J.CanNotUseAction(bot) or bot:IsCastingAbility() or bot:IsUsingAbility() then return true end
    bot:SetTarget(nil)
    return Escape.Move(bot,J,threat)
end

-- Visible destination risk, shared by camps and short travel segments.
function X.LocationThreats(bot,J)
    local threats={}
    for _,enemy in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if VisibleHero(enemy,J) then
            local reach=math.min(1300,enemy:GetAttackRange()+enemy:GetCurrentMovementSpeed()*1.5+250)
            local incoming=enemy:GetEstimatedDamageToTarget(true,bot,2,DAMAGE_TYPE_ALL)
            local outgoing=bot:GetEstimatedDamageToTarget(true,enemy,2,DAMAGE_TYPE_ALL)
            if enemy:GetHealth()>outgoing*1.15 and
                (incoming>=math.max(200,bot:GetHealth()*0.55)
                or enemy:GetLevel()>=bot:GetLevel()+5 and incoming>outgoing*1.5) then
                local p=enemy:GetLocation()
                if Runtime.Location(bot,'travel.visible-threat',p) then
                    threats[#threats+1]={location=Vector(p.x,p.y,p.z),radius=reach,name=enemy:GetUnitName()}
                end
            end
        end
    end
    return threats
end

function X.GetLocationConcern(bot,J,location,threats)
    for _,threat in ipairs(threats or X.LocationThreats(bot,J)) do
        local dx,dy=location.x-threat.location.x,location.y-threat.location.y
        if dx*dx+dy*dy<=threat.radius*threat.radius then return threat end
    end
    return Memory.GetConcern(bot,J,location)
end

-- Evaluate the destination, not merely the bot's current peaceful location.
function X.IsCampDangerous(bot,J,camp)
    local location=camp~=nil and camp.cattr~=nil and camp.cattr.location or nil
    if not Runtime.Location(bot,'farm.camp-destination',location) then return true end
    if not IsLocationPassable(location) then return true end
    return X.GetLocationConcern(bot,J,location)~=nil
end

function X.ChooseCamp(bot,J,current,candidate)
    local currentSafe=current~=nil and not X.IsCampDangerous(bot,J,current)
    if candidate==nil or X.IsCampDangerous(bot,J,candidate) then return currentSafe and current or nil end
    if not currentSafe then return candidate end
    if GetUnitToLocationDistance(bot,candidate.cattr.location)+200<GetUnitToLocationDistance(bot,current.cattr.location) then
        return candidate
    end
    return current
end

return X
