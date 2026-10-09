local X = {}

local bot = GetBot()
if bot == nil then return end
local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )
local Localization = require( GetScriptDirectory()..'/FunLib/localization' )
local Customize = require( GetScriptDirectory()..'/Customize/general' )
local ObjectiveCommands = require(GetScriptDirectory()..'/FunLib/shai_objective_commands')

local Tormentor = nil
local TormentorLocation = 0
local vWaitingLocation = 0
local nRestForSeconds = 5

local tormentorMessageTime = 0
local canDoTormentor = false

if bot.tormentor_state == nil then bot.tormentor_state = false end
if bot.tormentor_kill_time == nil then bot.tormentor_kill_time = 0 end

local nCoreCountInLoc = 0
local nSuppCountInLoc = 0
local lastTraceTime, lastTraceReason = -math.huge, nil
local decisionReason = 'not-ready'
local readiness = {}
local function Decline(reason)
    decisionReason = reason
    return BOT_MODE_DESIRE_NONE
end

function GetDesire()
	-- local cacheKey = 'GetSideShopDesire'..tostring(bot:GetPlayerID())
	-- local cachedVar = J.Utils.GetCachedVars(cacheKey, 0.6 * (1 + Customize.ThinkLess))
	-- if DotaTime() > 30 and cachedVar ~= nil then return cachedVar end
	local res = GetDesireHelper()
	if DotaTime() >= (J.IsModeTurbo() and 450 or 900)
        and (DotaTime() >= lastTraceTime + 30 or (decisionReason ~= lastTraceReason and DotaTime() >= lastTraceTime + 10)) then
		local position = TormentorLocation ~= 0 and ('; x='..tostring(TormentorLocation.x)..'; y='..tostring(TormentorLocation.y)) or ''
		local details=''
        for _,key in ipairs({'alive','healthy','localCores','localSupports','coreLevel','supportLevel','damageIndex','distance','waitSeconds','availability'}) do
            details=details..'; '..key..'='..tostring(readiness[key] or '-')
        end
		print('[SHAI] tormentor t='..tostring(DotaTime())..'; team='..tostring(GetTeam())..'; hero='..bot:GetUnitName()..'; reason='..decisionReason..'; desire='..tostring(res)..details..position)
		lastTraceTime, lastTraceReason = DotaTime(), decisionReason
	end
	-- J.Utils.SetCachedVars(cacheKey, res)
	return res
end
function GetDesireHelper()
	decisionReason = 'not-ready'
    readiness = {}
	if not bot:IsAlive() then return Decline('dead') end
	if ObjectiveCommands.IsBlocked(bot,'tormentor') then
		canDoTormentor,bot.tormentor_team_healthy=false,false
		return Decline('player-veto')
	end
	nCoreCountInLoc, nSuppCountInLoc = 0, 0
	canDoTormentor = false
	bot.tormentor_team_healthy = false
	-- 如果在打高地 就别撤退去干别的
	if J.Utils.IsTeamPushingSecondTierOrHighGround(bot) then
		return Decline('team-push')
	end
	local enemiesAtAncient = J.Utils.CountEnemyHeroesNear(GetAncient(GetTeam()):GetLocation(), 3200)
    if enemiesAtAncient >= 1 then
        return Decline('base-threat')
    end

    if DotaTime() > 300 and DotaTime() - bot.tormentor_kill_time <= nRestForSeconds then
        decisionReason = 'post-kill-rest'
		return BOT_MODE_DESIRE_VERYHIGH
    end

    J.Utils['GameStates'] = J.Utils['GameStates'] or {}
    J.Utils['GameStates']['defendPings'] = J.Utils['GameStates']['defendPings'] or { pingedTime = GameTime() }
    if GameTime() - J.Utils['GameStates']['defendPings'].pingedTime <= 5.0 then
		return Decline('defend-ping')
	end

    -- update vars for tormentor
    TormentorLocation = J.GetTormentorLocation(GetTeam())
    vWaitingLocation = J.GetTormentorWaitingLocation(GetTeam())
    -- Only a directly observed dead unit establishes a kill timestamp. A unit
    -- disappearing in fog or being absent at a guessed spawn does not.
    if Tormentor ~= nil and not Tormentor:IsNull() and Tormentor:CanBeSeen() and not Tormentor:IsAlive() then
        for i=1,#GetTeamPlayers(GetTeam()) do
            local ally=GetTeamMember(i)
            if ally ~= nil then ally.tormentor_kill_time=DotaTime(); ally.tormentor_state=false end
        end
        Tormentor=nil
        return Decline('observed-death')
    end
    readiness.distance=math.floor(GetUnitToLocationDistance(bot,TormentorLocation))
    local observedAlive=X.IsTormentorAlive()
    local missing=bot.shaiTormentorMissing
    local missingHere=missing ~= nil and DotaTime()>=missing.observedAt and DotaTime()<missing.untilTime
        and (missing.x-TormentorLocation.x)^2+(missing.y-TormentorLocation.y)^2<400^2
    readiness.availability=observedAlive and 'visible-alive' or (missingHere and 'visible-empty' or 'unknown')
    if missingHere and not observedAlive then return Decline('objective-unavailable') end

    local tAllyInTormentorLocation = J.GetAlliesNearLoc(TormentorLocation, 900)
    local tAllyInTormentorWaitLocation = J.GetAlliesNearLoc(vWaitingLocation, 900)
    local tInRangeEnemy = J.GetEnemiesNearLoc(bot:GetLocation(), 1600)
    local nAliveAlly = 0

    local nTormentorSpawnInterval = J.IsModeTurbo() and 5 or 10
    local nTormentorSpawnTime = J.IsModeTurbo() and 7.5 or 15
    readiness.waitSeconds=math.max(0,nTormentorSpawnTime*60-DotaTime(),
        bot.tormentor_kill_time>0 and bot.tormentor_kill_time+nTormentorSpawnInterval*60-DotaTime() or 0)

    local nHumanCountInLoc = 0
    local nAttackingTormentorCount = 0

    local nAveCoreLevel = 0
    local nAveSuppLevel = 0
    local coreCount, supportCount = 0, 0

    local nInRangeEnemy = J.GetLastSeenEnemiesNearLoc(bot:GetLocation(), 1200)
    if #nInRangeEnemy > 0 and not J.IsInLaningPhase() then
        return Decline('nearby-enemies')
    end
    local tAliveAllies = {}
    for i = 1, #GetTeamPlayers( GetTeam() ) do
        local member = GetTeamMember(i)
        if member ~= nil then
            local memberLevel = member:GetLevel()

            if member:IsAlive() then
                nAliveAlly = nAliveAlly + 1
                table.insert(tAliveAllies, member)

                if not member:IsBot() then
                    if bot.tormentor_state == false and J.IsValidHero(member) then
                        if GetUnitToLocationDistance(member, TormentorLocation) <= 1300
                        and IsLocationVisible(TormentorLocation)
                        then
                            local nNeutralCreeps = member:GetNearbyNeutralCreeps(1300)
                            for j = #nNeutralCreeps, 1, -1 do
                                if J.IsValid(nNeutralCreeps[j]) and string.find(nNeutralCreeps[j]:GetUnitName(), 'miniboss') then
                                    bot.tormentor_state = true
                                end
                            end
                        end
                    end

                    if GetUnitToLocationDistance(member, TormentorLocation) <= 1600
                    or GetUnitToLocationDistance(member, vWaitingLocation) <= 1600
                    then
                        nHumanCountInLoc = nHumanCountInLoc + 1
                    end
                end

                -- attacking tormentor count
                local memberTarget = J.GetProperTarget(member)
                if J.IsTormentor(memberTarget) and J.IsAttacking(member) then
                    nAttackingTormentorCount = nAttackingTormentorCount + 1
                end


                if J.IsCore(member) then
                    if GetUnitToLocationDistance(member, TormentorLocation) <= 900
                    or GetUnitToLocationDistance(member, vWaitingLocation) <= 900
                    then
                        nCoreCountInLoc = nCoreCountInLoc + 1
                    end
                else
                    if GetUnitToLocationDistance(member, TormentorLocation) <= 900
                    or GetUnitToLocationDistance(member, vWaitingLocation) <= 900
                    then
                        nSuppCountInLoc = nSuppCountInLoc + 1
                    end
                end
            end

            -- get average levels
            if member:IsAlive() then
                if J.IsCore(member) then
                    nAveCoreLevel, coreCount = nAveCoreLevel + memberLevel, coreCount + 1
                else
                    nAveSuppLevel, supportCount = nAveSuppLevel + memberLevel, supportCount + 1
                end
            end

            -- update tormentor state
            if member.tormentor_state == true then
                bot.tormentor_state = true
            end

            --update kill time
            if member.tormentor_kill_time ~= nil
            and member.tormentor_kill_time > 0
            and member.tormentor_kill_time > bot.tormentor_kill_time
            then
                bot.tormentor_kill_time = member.tormentor_kill_time
            end

        end
    end

    if #tAllyInTormentorLocation <= 1 and nHumanCountInLoc == 0
    and DotaTime() > (J.IsModeTurbo() and (25 * 60) or (40 * 60)) then
        return Decline('late-and-distant')
    end

    local hEnemyAncient = GetAncient(GetOpposingTeam())
    if #tAllyInTormentorLocation <= 1 and nHumanCountInLoc == 0
    and GetUnitToLocationDistance(bot, TormentorLocation) > 1600
    and (GetUnitToUnitDistance(bot, hEnemyAncient) < 4000
        and J.GetEnemiesAroundAncient(bot, 4000) > 0
        or (J.IsDoingRoshan(bot) and bot:GetActiveModeDesire() >= BOT_MODE_DESIRE_HIGH)
    ) then
        return Decline('more-important-objective')
    end

    if #J.GetEnemiesNearLoc(GetAncient(GetTeam()):GetLocation(), 2000) >= 2
    then
        return Decline('base-threat')
    end

    nAveCoreLevel = coreCount > 0 and nAveCoreLevel / coreCount or 0
    nAveSuppLevel = supportCount > 0 and nAveSuppLevel / supportCount or 0
    readiness.alive,readiness.localCores,readiness.localSupports=nAliveAlly,nCoreCountInLoc,nSuppCountInLoc
    readiness.coreLevel,readiness.supportLevel=nAveCoreLevel,nAveSuppLevel
    X.IsTeamHealthy()
    local bGoodRightClickDamage = X.IsGoodRighClickDamage()

    if nAveSuppLevel < 11 then
        return Decline('support-level')
    end

    if not bGoodRightClickDamage then return Decline('damage') end
    if nAveCoreLevel < 13 then return Decline('core-level') end

    -- TODO: reduce wasting time waiting for someone as the location is very far now
    -- Someone go check Tormentor
    if DotaTime() >= nTormentorSpawnTime * 60 and (DotaTime() - bot.tormentor_kill_time) >= nTormentorSpawnInterval * 60 then
        if not observedAlive and bot.tormentor_state ~= true then
            if (nAveCoreLevel >= 13 and nAveSuppLevel >= 11)
            and GetUnitToUnitDistance(bot, hEnemyAncient) > 4000
            and bGoodRightClickDamage
            then
                local ally = nil
                local allyDist = 100000
                for i = 1, #GetTeamPlayers( GetTeam() ) do
                    local member = GetTeamMember(i)
                    if J.IsValidHero(member) and member:IsBot() and not J.IsCore(member) then
                        local memberDist = GetUnitToLocationDistance(member, TormentorLocation)
                        if memberDist < allyDist then
                            ally = member
                            allyDist = memberDist
                        end
                    end
                end

                if ally ~= nil and bot == ally and bot.tormentor_state == false then
                    local tInRangeAlly = J.GetAlliesNearLoc(bot:GetLocation(), 1200)
                    if not J.IsRealInvisible(bot) and (#tInRangeEnemy > #tInRangeAlly) then
                        decisionReason = 'scout-outnumbered'
                        return BOT_MODE_DESIRE_LOW
                    else
                        decisionReason = 'scout'
                        return BOT_MODE_DESIRE_VERYHIGH
                    end
                end
            end
        else
            bot.tormentor_state = true
        end
    else
        bot.tormentor_state = false
    end

    if bot.tormentor_state == true
    and bGoodRightClickDamage
    and nAveCoreLevel >= 13
    and nAveSuppLevel >= 11
    and (  (bot.tormentor_kill_time == 0 and nAliveAlly >= 4 and J.GetAliveAllyCoreCount() >= 2)
        or (bot.tormentor_kill_time > 0 and nAliveAlly >= 3 and J.GetAliveAllyCoreCount() >= 2)
        or (nAttackingTormentorCount >= 2 and nCoreCountInLoc >= 2)
    ) then
        bot.tormentor_team_healthy = X.IsTeamHealthy()

        if bot.tormentor_team_healthy == false then
            return Decline('health')
        end

        canDoTormentor = true

        if J.GetHP(bot) < 0.3
        and not bot:HasModifier('modifier_item_crimson_guard_extra')
        and J.IsTormentor(Tormentor)
        and J.GetHP(Tormentor) > 0.3 then
            return Decline('wounded-attacker')
        end

        local nDesire = 0.9

        if (#tAllyInTormentorLocation >= 2 or #tAllyInTormentorWaitLocation >= 2)
        or nCoreCountInLoc >= 1
        or nSuppCountInLoc >= 2
        or nHumanCountInLoc >= 1 then
            nDesire = 0.9
        else
            nDesire = 0.75
        end

        local nInRangeEnemy = J.GetEnemiesNearLoc(bot:GetLocation(), 1200)

        decisionReason = 'assemble-or-attack'
        return nDesire - (#nInRangeEnemy * (0.9 / 5))
    end

    if bot.tormentor_state == false then
        bot.tormentor_team_healthy = false
    end

    canDoTormentor = false
    return Decline(bot.tormentor_state and 'available-allies' or 'spawn-or-scout-pending')
end

local fNextMovementTime = 0
local fStillAlive = 0
local bTormentorAlive = false
function Think()
    if J.CanNotUseAction(bot) then return end
    if ObjectiveCommands.ReleaseObjective(bot,J,'tormentor') then return end
    local missing=bot.shaiTormentorMissing
    if missing ~= nil and DotaTime()>=missing.observedAt and DotaTime()<missing.untilTime
        and TormentorLocation ~= 0
        and (missing.x-TormentorLocation.x)^2+(missing.y-TormentorLocation.y)^2<400^2 then
        bot.tormentor_state=false
        bot:Action_MoveToLocation(J.GetTeamFountain())
        return
    end
    if J.Utils.IsBotThinkingMeaningfulAction(bot, Customize.ThinkLess, "side_shop") then return end
    if DotaTime() - bot.tormentor_kill_time <= nRestForSeconds then
        bot:Action_MoveToLocation(TormentorLocation + RandomVector(50))
        return
    end

    if bot.tormentor_state == true and GetUnitToLocationDistance(bot, TormentorLocation) > 800 and GetUnitToLocationDistance(bot, TormentorLocation) < 1800 then
        local nLaneCreeps = bot:GetNearbyLaneCreeps(Min(1600, bot:GetAttackRange() + 300), true)
        if J.IsValid(nLaneCreeps[1])
        and J.CanBeAttacked(nLaneCreeps[1])
        then
            bot:Action_AttackUnit(nLaneCreeps[1], true)
            return
        end
    end

    if bot.tormentor_state == true and not X.IsEnoughAllies(vWaitingLocation, 1600) then
        if X.GetClosestBot() == bot and DotaTime() > fStillAlive + 15.0 then
            if GetUnitToLocationDistance(bot, TormentorLocation) <= 350 then
                bTormentorAlive = false
                local nNeutralCreeps = bot:GetNearbyNeutralCreeps(900)
                for i = #nNeutralCreeps, 1, -1 do
                    if J.IsValid(nNeutralCreeps[i]) and string.find(nNeutralCreeps[i]:GetUnitName(), 'miniboss') then
                        fStillAlive = DotaTime()
                        bTormentorAlive = true
                    end
                end
                if not bTormentorAlive and IsLocationVisible(TormentorLocation) then
                    X.MarkUnavailable()
                    bot:Action_MoveToLocation(J.GetTeamFountain())
                    return
                end
            end

            bot:Action_MoveToLocation(TormentorLocation)
            return
        end

        if DotaTime() >= fNextMovementTime then
            bot:Action_MoveToLocation(vWaitingLocation + RandomVector(300))
            fNextMovementTime = DotaTime() + RandomFloat(2, 3)
            return
        end
    else
        if GetUnitToLocationDistance(bot, TormentorLocation) > bot:GetAttackRange() + 50 then
            bot:Action_MoveToLocation(TormentorLocation)
            return
        else
            local tCreeps = bot:GetNearbyNeutralCreeps(900)
            for _, c in pairs(tCreeps) do
                if J.IsValid(c) and string.find(c:GetUnitName(), 'miniboss') then
                    Tormentor = c
                    if GetUnitToUnitDistance(bot, c) > bot:GetAttackRange() + 50 then
                        bot:Action_MoveDirectly(TormentorLocation)
                        return
                    else
                        if X.IsEnoughAllies(TormentorLocation, 900) or J.GetHP(c) < 0.25 then
                            bot:Action_AttackUnit(c, true)
                            return
                        end
                    end

                    if J.GetFirstBotInTeam() == bot and canDoTormentor and (DotaTime() > tormentorMessageTime + 15) then
                        tormentorMessageTime = DotaTime()
                        bot:ActionImmediate_Chat(Localization.Get('can_try_tormentor'), false)
                        bot:ActionImmediate_Ping(c:GetLocation().x, c:GetLocation().y, true)
                        return
                    end
                end
            end
        end
    end
end

function X.IsTormentorAlive()
    if IsLocationVisible(TormentorLocation) then
        for i = 1, #GetTeamPlayers( GetTeam() ) do
            local member = GetTeamMember(i)
            if member ~= nil and member:IsAlive() then
                if GetUnitToLocationDistance(member, TormentorLocation) <= 350 then
                    local nNeutralCreeps = member:GetNearbyNeutralCreeps(900)
                    for j = #nNeutralCreeps, 1, -1 do
                        if J.IsValid(nNeutralCreeps[j]) and string.find(nNeutralCreeps[j]:GetUnitName(), 'miniboss') then
                            Tormentor=nNeutralCreeps[j]
                            for k=1,#GetTeamPlayers(GetTeam()) do
                                local ally=GetTeamMember(k)
                                if ally ~= nil then ally.shaiTormentorMissing=nil; ally.tormentor_state=true end
                            end
                            return true
                        end
                    end

                    -- Empty vision is not proof of a kill or a respawn time.
                    X.MarkUnavailable()
                    return false
                end
            end
        end
	end

	return false
end

function X.MarkUnavailable()
    local missing={observedAt=DotaTime(),untilTime=DotaTime()+15,x=TormentorLocation.x,y=TormentorLocation.y}
    for i=1,#GetTeamPlayers(GetTeam()) do
        local ally=GetTeamMember(i)
        if ally ~= nil then ally.tormentor_state=false; ally.shaiTormentorMissing=missing end
    end
    canDoTormentor=false
end

function X.IsEnoughAllies(vLocation, nRadius)
    local nAllyCount = 0
    local nCoreCountInLoc2 = 0
    local nSuppCountInLoc2 = 0
	for i = 1, #GetTeamPlayers( GetTeam() ) do
		local member = GetTeamMember(i)
		if member ~= nil and member:IsAlive() then
            if GetUnitToLocationDistance(member, vLocation) <= nRadius then
                nAllyCount = nAllyCount + 1
                if J.IsCore(member) then
                    nCoreCountInLoc2 = nCoreCountInLoc2 + 1
                else
                    nSuppCountInLoc2 = nSuppCountInLoc2 + 1
                end
            end
		end
	end

	return ((bot.tormentor_kill_time == 0 and nAllyCount >= 5)
         or (bot.tormentor_kill_time == 0 and nAllyCount >= 4 and nCoreCountInLoc2 >= 2 and nSuppCountInLoc2 >= 1)
         or (bot.tormentor_kill_time > 0 and nAllyCount >= 3))
    and nCoreCountInLoc2 >= 2
end

function X.GetClosestBot()
    local hUnitList = J.GetAlliesNearLoc(vWaitingLocation, 2800)
    local hTarget = nil
    local hTargetDistance = math.huge
    for _, unit in pairs(hUnitList) do
        if J.IsValidHero(unit) and unit:IsBot() and GetUnitToLocationDistance(unit, TormentorLocation) < 2000 then
            local unitDistance = GetUnitToLocationDistance(unit, TormentorLocation)
            if hTargetDistance > unitDistance then
                hTargetDistance = unitDistance
                hTarget = unit
            end
        end
    end

    if hTarget ~= nil then
        return hTarget
    end
    return nil
end

function X.IsTeamHealthy()
	local nHealthyAlly = 0
	for i = 1, #GetTeamPlayers( GetTeam() ) do
		local member = GetTeamMember(i)
		if J.IsValid(member) and member:IsAlive() and (J.GetHP(member) > 0.5 or not member:IsBot()) then
			nHealthyAlly = nHealthyAlly + 1
		end
	end

    readiness.healthy=nHealthyAlly
	return nHealthyAlly >= J.GetNumOfAliveHeroes(false)
end

-- just some threshold
local tTeamDamage = {}
local fThresholdChatTime = 0
function X.IsGoodRighClickDamage()
    tTeamDamage = {}

    for i = 1, #GetTeamPlayers( GetTeam() ) do
		local member = GetTeamMember(i)
		if member ~= nil
        and member:CanBeSeen()
        and member:IsAlive()
        and J.IsCore(member)
        and not J.DoesUnitHaveTemporaryBuff(member)
        then
            local attackDamage = member:GetAttackDamage() * member:GetAttackSpeed()

            local id = member:GetPlayerID()
			if tTeamDamage[id] == nil then tTeamDamage[id] = 0 end
            if tTeamDamage[id] < attackDamage then
                tTeamDamage[id] = attackDamage
            end
		end
	end

    local totalAttackDamage = 0
    for _, damage in pairs(tTeamDamage) do totalAttackDamage = totalAttackDamage + damage end
    readiness.damageIndex=totalAttackDamage -- Existing heuristic, not measured DPS.

    if not J.IsDoingTormentor(bot) and J.GetFirstBotInTeam() == bot and bot.tormentor_state == true and DotaTime() - fThresholdChatTime >= 30 and totalAttackDamage >= 400.0 then
        bot:ActionImmediate_Chat("Tormentor threshold met..", false)
        fThresholdChatTime = DotaTime()
    end

    -- if math.floor(DotaTime()) % 5 == 0 then
    --     if GetTeam() == TEAM_RADIANT then
    --         print(bot.tormentor_team_healthy, 'RADIANT:', totalAttackDamage)
    --     else
    --         print(bot.tormentor_team_healthy, 'DIRE:', totalAttackDamage)
    --     end
    -- end

    return totalAttackDamage >= 400.0
end

local bHumanPinged = false
function X.DidHumanPingedOrAtLocation()
    local human, ping = J.GetHumanPing()
    if bot.tormentor_state == true and human and ping and not bHumanPinged then
        if J.GetDistance(ping.location, vWaitingLocation) <= 800
        or J.GetDistance(ping.location, TormentorLocation) <= 800
        then
            if GameTime() < ping.time + 15 then
                bHumanPinged = true
            end
        end
    end

    if bot.tormentor_state == false then
        bHumanPinged = false
    elseif bot.tormentor_state == true and bHumanPinged then
        return true
    end

    return false
end

return X
