local Runtime = require(GetScriptDirectory()..'/FunLib/shai_runtime')
local X = {}
local J = require(GetScriptDirectory()..'/FunLib/jmz_func')
local RuneShare = require(GetScriptDirectory()..'/FunLib/shai_rune_share')
local Route = require(GetScriptDirectory()..'/FunLib/shai_route_safety')
local FarmSafety = require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local Customize = require(GetScriptDirectory()..'/Customize/general')
Customize.ThinkLess = Customize.Enable and Customize.ThinkLess or 1

local bot = GetBot()
if bot == nil then return end

local minute = 0
local second = 0

local bBottle = false

local nRuneList = {
	RUNE_BOUNTY_1,
	RUNE_BOUNTY_2,
	RUNE_POWERUP_1,
	RUNE_POWERUP_2,
}

local botHP, botMP, botPos, botActiveMode, botActiveModeDesire, botAssignedLane
local nAllyHeroes, nEnemyHeroes

local function IsHumanClaimingRune(nRune)
	local vRuneLoc = GetRuneSpawnLocation(nRune)
	local botDistance = GetUnitToLocationDistance(bot, vRuneLoc)
	for i = 1, #GetTeamPlayers(GetTeam()) do
		local member = GetTeamMember(i)
		if member ~= nil and member:IsAlive() and not member:IsBot() then
			local distance = GetUnitToLocationDistance(member, vRuneLoc)
			if distance <= 600 and distance <= botDistance + 100
			and (distance <= 150 or member:IsFacingLocation(vRuneLoc, 30) and member:GetCurrentActionType()==BOT_ACTION_TYPE_MOVE_TO
				or member:GetCurrentActionType() == BOT_ACTION_TYPE_PICK_UP_RUNE) then
				return true
			end
		end
	end
	return false
end

local function IsRiverRune(rune)
	return rune == RUNE_POWERUP_1 or rune == RUNE_POWERUP_2
end

-- All Pick river cadence: prepare before the first and subsequent even minutes.
local function RiverCheckWindow()
	local now = DotaTime()
	return now >= 108 and (now % 120 >= 108 or now % 120 <= 20)
end

local function RiverPreSpawnWindow()
	return DotaTime() >= 108 and DotaTime() % 120 >= 108
end

local function RealHeroes(list)
	local result, seen = {}, {}
	for _, hero in pairs(list or {}) do
		if J.IsValidHero(hero) and not J.IsSuspiciousIllusion(hero) and not seen[hero] then
			seen[hero] = true
			table.insert(result, hero)
		end
	end
	return result, seen
end

-- Count the bot exactly once. Enemy presence alone is not a reason to concede 1v1.
function X.IsRuneSafe(rune)
	local location = GetRuneSpawnLocation(rune)
	local allies, seen = RealHeroes(J.GetAlliesNearLoc(location, 1200))
	if not seen[bot] then table.insert(allies, bot) end
	local enemies = RealHeroes(J.GetEnemiesNearLoc(location, 1200))
	local recentEnemies = J.GetLastSeenEnemiesNearLoc(location, 1200)
	local threatCount = math.max(#enemies, #recentEnemies)
	if threatCount == 0 then return true end
	if threatCount > #allies or J.GetHP(bot) < 0.45 then return false end
	local incoming = 0
	for _, enemy in ipairs(enemies) do
		incoming = incoming + math.max(0, enemy:GetEstimatedDamageToTarget(true, bot, 3, DAMAGE_TYPE_ALL))
	end
	return incoming < bot:GetHealth() * 0.8
end

local function HasImmediateLastHit()
	for _, creep in pairs(bot:GetNearbyLaneCreeps(650, true)) do
		if J.IsValid(creep) and J.CanBeAttacked(creep)
		and J.WillKillTarget(creep, bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL,
			J.GetAttackProDelayTime(bot, creep)) then return true end
	end
	return false
end

function X.CanFightRuneEnemy(enemy, rune)
	if not J.IsValidHero(enemy) or J.IsSuspiciousIllusion(enemy) or not J.CanBeAttacked(enemy)
	or not X.IsRuneSafe(rune) then return false end
	-- Evaluate damage against the enemy, not against the bot itself.
	-- With nearly empty mana, don't plan a fight around spell damage.
	local damageType = J.GetMP(bot) < 0.2 and DAMAGE_TYPE_PHYSICAL or DAMAGE_TYPE_ALL
	local ourDamage = bot:GetEstimatedDamageToTarget(true, enemy, 3, damageType)
	local theirDamage = enemy:GetEstimatedDamageToTarget(true, bot, 3, DAMAGE_TYPE_ALL)
	return ourDamage >= theirDamage * 0.8 and J.GetHP(bot) >= 0.5
end

function X.HasWaterRuneValue(rune, distance)
	if botHP < 0.9 or botMP < 0.85 or distance <= 250 then return true end
	if bBottle then
		local bottle = bot:GetItemInSlot(bot:FindItemSlot('item_bottle'))
		if bottle and bottle:GetCurrentCharges() < 3 then return true end
	end
	local location = GetRuneSpawnLocation(rune)
	-- Denying the opponent's refill is useful even with full resources.
	if #RealHeroes(J.GetEnemiesNearLoc(location, 1600)) > 0
		or #J.GetLastSeenEnemiesNearLoc(location, 1600) > 0 then return true end
	return false
end

-- Wisdom rune state
local radiantWRLocation = Vector(-7948.152344, 768.207825, 256.000000)
local direWRLocation = Vector(8029.234375, -1125.811768, 256.000000)
local wisdomRuneSpots = { [TEAM_RADIANT] = radiantWRLocation, [TEAM_DIRE] = direWRLocation }
local nShrineOfWisdomTime = 0
local nShrineOfWisdomTeam = TEAM_RADIANT
local collectingWisdom = false

--------------------------------------------------------------------
-- GetDesire  (reference structure, with local additions)
--------------------------------------------------------------------
local function ModeDesireInternal()
	collectingWisdom = false
	if not bot:IsAlive() then return BOT_MODE_DESIRE_NONE end
	X.InitRune()

	bBottle = bot:FindItemSlot('item_bottle') >= 0
	botHP = J.GetHP(bot)
	botMP = J.GetMP(bot)
	botPos = J.GetPosition(bot)
	botActiveMode = bot:GetActiveMode()
	botActiveModeDesire = bot:GetActiveModeDesire()
	botAssignedLane = bot:GetAssignedLane()
	nAllyHeroes = bot:GetNearbyHeroes(1600, false, BOT_MODE_NONE)
	nEnemyHeroes = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)

	if bot:IsInvulnerable() and botHP > 0.9 and bot:DistanceFromFountain() < 500 then
		return BOT_MODE_DESIRE_ABSOLUTE
	end

	-- Drop rune desire when outnumbered or taking damage so attack/retreat can take over.
	-- This prevents bots from walking into 5-man ambushes at rune spots.
	if #nEnemyHeroes > 0 then
		local allies, seen = RealHeroes(nAllyHeroes)
		if not seen[bot] then table.insert(allies, bot) end
		local enemies = RealHeroes(nEnemyHeroes)
		if #enemies > #allies then
			return BOT_MODE_DESIRE_NONE
		end
		if bot:WasRecentlyDamagedByAnyHero(2.0) and botHP < 0.45 then
			return BOT_MODE_DESIRE_NONE
		end
	end

	-- Critical team tasks take precedence over both river runes and Wisdom.
	if J.Utils.IsTeamPushingSecondTierOrHighGround(bot)
		or J.Utils.CountEnemyHeroesNear(GetAncient(GetTeam()):GetLocation(), 3200) >= 1 then
		return BOT_MODE_DESIRE_NONE
	end

	-- Wisdom Rune
	if bot:GetLevel() < 30 then
		nShrineOfWisdomTime = X.GetCurrentWisdomTime()
		X.UpdateWisdom()

		if  DotaTime() >= 7 * 60
		and not J.IsMeepoClone(bot)
		and not bot:HasModifier('modifier_arc_warden_tempest_double')
		and bot.rune and bot.rune.wisdom and bot.rune.wisdom[nShrineOfWisdomTime]
		then
			local wisdom = bot.rune.wisdom[nShrineOfWisdomTime]

			local nEnemyTowers = bot:GetNearbyTowers(700, true)
			local nInRangeEnemy = J.GetEnemiesNearLoc(bot:GetLocation(), 1200)
			if (#nEnemyTowers > 0 and bot:WasRecentlyDamagedByTower(1.0) and botHP < 0.3)
			or (#nInRangeEnemy > 0 and not J.IsRealInvisible(bot))
			then
				return 0
			end

			nShrineOfWisdomTeam = X.GetShrineOfWisdomTeam()
			if nShrineOfWisdomTeam then
				local bChecked  = wisdom.spot[nShrineOfWisdomTeam].status
				local vLocation = wisdom.spot[nShrineOfWisdomTeam].location
				if bChecked == false then
					if bot == X.GetWisdomAlly(vLocation) then
						local desire = X.GetWisdomDesire(vLocation)
						collectingWisdom = desire > 0
						if collectingWisdom and not wisdom.spot[nShrineOfWisdomTeam].announced then
							print('[SHAI] wisdom team='..tostring(GetTeam())..'; hero='..bot:GetUnitName()
								..'; cycle='..tostring(nShrineOfWisdomTime)..'; x='..tostring(vLocation.x)..'; y='..tostring(vLocation.y))
							wisdom.spot[nShrineOfWisdomTeam].announced = true
						end
						return desire
					end
				end
			end
		end
	end

	-- Core rune logic using bot.rune state (reference pattern)
	if bot.rune and bot.rune.normal then
		local nProximityRadius = 1600
		local rune = bot.rune.normal

		rune.location, rune.distance = X.GetBestRune()
		if rune.location ~= -1 then
			local now = GameTime()
			if rune.lastTraceTime == nil or (rune.lastTraceTarget ~= rune.location and now - rune.lastTraceTime >= 5) then
				print('[SHAI] rune team='..tostring(GetTeam())..'; hero='..bot:GetUnitName()
					..'; target='..tostring(rune.location)..'; distance='..tostring(math.floor(rune.distance))
					..'; status='..tostring(GetRuneStatus(rune.location)))
				rune.lastTraceTime, rune.lastTraceTarget = now, rune.location
			end
		end

		-- Pre-game: move toward rune with moderate desire
		if DotaTime() < 0 and not bot:WasRecentlyDamagedByAnyHero(10.0) then
			return BOT_MODE_DESIRE_MODERATE
		end

		if rune.location ~= -1 then
			rune.type = GetRuneType(rune.location)
			rune.status = GetRuneStatus(rune.location)

			local vRuneLocation = GetRuneSpawnLocation(rune.location)

			if rune.location == RUNE_BOUNTY_1 or rune.location == RUNE_BOUNTY_2 then
				if rune.status == RUNE_STATUS_AVAILABLE
				and (X.IsTeamMustSaveRune(rune.location) or not J.IsInLaningPhase() or GetUnitToLocationDistance(bot, vRuneLocation) <= 500)
				then
					if X.IsEnemyPickRune(rune.location) then return BOT_MODE_DESIRE_NONE end

					if bBottle or (botPos >= 4 and not X.IsThereAllyWithBottle(vRuneLocation, 1600)) then
						return X.GetScaledDesire(BOT_MODE_DESIRE_HIGH, rune.distance, 3500)
					else
						return X.GetScaledDesire(BOT_MODE_DESIRE_MODERATE, rune.distance, 3500)
					end
				elseif rune.status == RUNE_STATUS_UNKNOWN
					and rune.distance <= nProximityRadius * 1.5
					and DotaTime() > 3 * 60 + 50
					and ((minute % 4 == 0) or (minute % 4 == 3) and second > 45)
				then
					return X.GetScaledDesire(BOT_MODE_DESIRE_MODERATE, rune.distance, nProximityRadius)
				elseif rune.status == RUNE_STATUS_MISSING
					and rune.distance <= nProximityRadius * 1.5
					and DotaTime() > 3 * 60 + 50
					and ((minute % 4 == 3) or second > 52)
				then
					return X.GetScaledDesire(BOT_MODE_DESIRE_MODERATE, rune.distance, nProximityRadius * 2.5)
				end
			else
				-- Power rune / water rune
				if rune.status == RUNE_STATUS_AVAILABLE then
					if X.IsEnemyPickRune(rune.location) then return BOT_MODE_DESIRE_NONE end

					local nRuneType = rune.type
					-- Water rune support (local addition)
					if nRuneType == RUNE_WATER and (bBottle or botHP < 0.6 or botMP < 0.5) then
						return X.GetRiverDesire(BOT_MODE_DESIRE_HIGH, rune.distance, 3200)
					elseif nRuneType == RUNE_WATER and not bBottle then
						if not X.HasWaterRuneValue(rune.location, rune.distance) then return BOT_MODE_DESIRE_NONE end
						return X.GetRiverDesire(BOT_MODE_DESIRE_MODERATE, rune.distance, nProximityRadius)
					end

					if bBottle or (not J.IsEarlyGame() and botPos <= 3) then
						return X.GetRiverDesire(BOT_MODE_DESIRE_HIGH, rune.distance, nProximityRadius * 2.5)
					else
						return X.GetRiverDesire(BOT_MODE_DESIRE_MODERATE, rune.distance, nProximityRadius * 2.5)
					end
				elseif rune.status == RUNE_STATUS_UNKNOWN and RiverCheckWindow() then
					if bBottle or (not J.IsEarlyGame() and botPos <= 3) then
						return X.GetRiverDesire(BOT_MODE_DESIRE_HIGH, rune.distance, nProximityRadius * 2.5)
					else
						return X.GetRiverDesire(BOT_MODE_DESIRE_MODERATE, rune.distance, nProximityRadius)
					end
				elseif rune.status == RUNE_STATUS_MISSING and RiverPreSpawnWindow() then
					local desire = botPos == 2 and BOT_MODE_DESIRE_HIGH or BOT_MODE_DESIRE_MODERATE
					return X.GetRiverDesire(desire, rune.distance, nProximityRadius)
				end
			end
		end
	end

	return BOT_MODE_DESIRE_NONE
end

--------------------------------------------------------------------
-- OnStart / OnEnd
--------------------------------------------------------------------
local Bottle = nil
function OnStart()
	local nSlot = bot:FindItemSlot('item_bottle')
	if bot:GetItemSlotType(nSlot) == ITEM_SLOT_TYPE_MAIN then
		Bottle = bot:GetItemInSlot(nSlot)
	end
end

function OnEnd()
	Bottle = nil
	collectingWisdom = false
	local wisdom = bot.rune and bot.rune.wisdom and bot.rune.wisdom[nShrineOfWisdomTime]
	if wisdom then
		for _, spot in pairs(wisdom.spot) do spot.captureStart = nil end
	end
end

--------------------------------------------------------------------
-- Think  (reference structure)
--------------------------------------------------------------------
local fNextMovementTime = -math.huge
local function ModeThinkInternal()
	if not bot:IsAlive() then return end
	if bot:IsInvulnerable() and bot:DistanceFromFountain() < 500 then
		bot:Action_MoveToLocation(bot:GetLocation() + RandomVector(500))
		return
	end

	if J.CanNotUseAction(bot)
	or bot:GetCurrentActionType() == BOT_ACTION_TYPE_PICK_UP_RUNE
	then
		return
	end

	-- An interrupted capture must restart its dwell time on return.
	if DotaTime()>=0 and FarmSafety.InterruptFarm(bot,J) then
		local wisdom=bot.rune and bot.rune.wisdom and bot.rune.wisdom[nShrineOfWisdomTime]
		if wisdom then for _,spot in pairs(wisdom.spot) do spot.captureStart=nil end end
		return
	end
	-- Wisdom Rune
	if collectingWisdom and nShrineOfWisdomTeam and DotaTime() >= 7 * 60
	and bot.rune and bot.rune.wisdom and bot.rune.wisdom[nShrineOfWisdomTime]
	then
		local wisdom = bot.rune.wisdom[nShrineOfWisdomTime]
		if wisdom then
			local vLocation = wisdom.spot[nShrineOfWisdomTeam].location
			local spot = wisdom.spot[nShrineOfWisdomTeam]
			if not spot.status then
				if GetUnitToLocationDistance(bot, vLocation) < 250
					and #RealHeroes(J.GetEnemiesNearLoc(vLocation, 300)) == 0 then
					spot.captureStart = spot.captureStart or DotaTime()
					if DotaTime() >= spot.captureStart + 3.5 then spot.status = true end
					bot:Action_ClearActions(false)
					return
				end
				spot.captureStart = nil
				if #RealHeroes(J.GetEnemiesNearLoc(vLocation, 1200)) > 0 then return end
				bot.rune.location = vLocation
				Route.Move(bot,J,vLocation,'wisdom')
				return
			end
		end
	end

	-- Pre-game movement
	if DotaTime() < 0 then
		if J.IsModeTurbo() and DotaTime() < -50 then
			return
		end

		-- If outnumbered near rune spot, retreat to tower safety instead
		local preGameEnemies = bot:GetNearbyHeroes(1200, true, BOT_MODE_NONE)
		local preGameAllies = bot:GetNearbyHeroes(1200, false, BOT_MODE_NONE)
		if #preGameEnemies > #preGameAllies and #preGameEnemies >= 2 then
			local safeLoc = GetLaneFrontLocation(GetTeam(), botAssignedLane or bot:GetAssignedLane(), -1500)
			bot:Action_MoveToLocation(safeLoc)
			return
		end

		if DotaTime() < -10 then
			local vLocation = X.GetGoOutLocation()
			if GetUnitToLocationDistance(bot, vLocation) > 300 then
				bot:Action_MoveToLocation(vLocation)
				return
			else
				if DotaTime() >= fNextMovementTime then
					bot:Action_MoveToLocation(vLocation + RandomVector(150))
					fNextMovementTime = DotaTime() + RandomFloat(1, 3)
					return
				end
			end
			return
		end

		if GetTeam() == TEAM_RADIANT then
			if botAssignedLane == LANE_BOT then
				bot:Action_MoveToLocation(GetRuneSpawnLocation(RUNE_BOUNTY_2) + RandomVector(50))
				return
			else
				bot:Action_MoveToLocation(GetRuneSpawnLocation(RUNE_POWERUP_1) + RandomVector(50))
				return
			end
		else
			if botAssignedLane == LANE_TOP then
				bot:Action_MoveToLocation(GetRuneSpawnLocation(RUNE_BOUNTY_1) + RandomVector(50))
				return
			else
				bot:Action_MoveToLocation(GetRuneSpawnLocation(RUNE_POWERUP_2) + RandomVector(50))
				return
			end
		end
	end

	-- Post-horn rune pickup (reference pattern using bot.rune state)
	if bot.rune and bot.rune.normal then
		local botAttackRange = math.min(bot:GetAttackRange() + 150, 1200)
		local nInRangeEnemy = J.GetEnemiesNearLoc(bot:GetLocation(), botAttackRange)
		local nEnemyCreeps = bot:GetNearbyCreeps(botAttackRange, true)
		local rune = bot.rune.normal
		if rune.location == nil or rune.location == -1 or not X.IsRuneSafe(rune.location) then return end
		-- Refresh live state: a rune may be taken or spawn after GetDesire ran.
		rune.status = GetRuneStatus(rune.location)
		rune.distance = GetUnitToLocationDistance(bot, GetRuneSpawnLocation(rune.location))

		local vRuneLocation = GetRuneSpawnLocation(rune.location)
		if rune.status==RUNE_STATUS_AVAILABLE and RuneShare.Yield(bot,J,rune.location,vRuneLocation) then return end
		if rune.status == RUNE_STATUS_MISSING and not RiverPreSpawnWindow() then
			if rune.distance <= 250 then
				rune.checked = rune.checked or {}
				rune.checked[rune.location] = DotaTime()
			end
			return
		end

		if rune.status == RUNE_STATUS_AVAILABLE then
			if Bottle and J.CanCastAbility(Bottle) and rune.distance < 1200 and rune.distance > 250
			and #J.GetEnemiesNearLoc(vRuneLocation, 1200) == 0 then
				local nCharges = Bottle:GetCurrentCharges()
				if nCharges > 0 and (botHP ~= 1 or botMP ~= 1) then
					bot:Action_UseAbility(Bottle)
					return
				end
			end

			if rune.distance > 50 then
				-- Secure the rune first when already within a short pickup approach.
				if rune.distance <= 250 then
					bot:Action_PickUpRune(rune.location)
					return
				end
				for _, enemyHero in pairs(nInRangeEnemy) do
					if J.IsValidHero(enemyHero)
					and X.CanFightRuneEnemy(enemyHero, rune.location)
					then
						bot:Action_AttackUnit(enemyHero, true)
						return
					end
				end

				if J.IsValid(nEnemyCreeps[1])
				and J.CanBeAttacked(nEnemyCreeps[1])
				and J.CanKillTarget(nEnemyCreeps[1], bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
				then
					bot:Action_AttackUnit(nEnemyCreeps[1], true)
					return
				end

				bot.rune.location = vRuneLocation
				Route.Move(bot,J,vRuneLocation,'rune')
				return
			else
				bot:Action_PickUpRune(rune.location)
				return
			end
		else
			for _, enemyHero in pairs(nInRangeEnemy) do
				if J.IsValidHero(enemyHero)
					and X.CanFightRuneEnemy(enemyHero, rune.location)
				then
					bot:Action_AttackUnit(enemyHero, true)
					return
				end
			end

			if J.IsValid(nEnemyCreeps[1])
			and J.CanBeAttacked(nEnemyCreeps[1])
			and J.CanKillTarget(nEnemyCreeps[1], bot:GetAttackDamage(), DAMAGE_TYPE_PHYSICAL)
			then
				bot:Action_AttackUnit(nEnemyCreeps[1], true)
				return
			end

			bot.rune.location = vRuneLocation
			Route.Move(bot,J,vRuneLocation,'rune')
			return
		end
	end
end

--------------------------------------------------------------------
-- InitRune  (from reference — stores rune state on bot handle)
--------------------------------------------------------------------
function X.InitRune()
	if bot.rune == nil then
		bot.rune = {
			normal = {
				time = 0,
				type = nil,
				location = nil,
				distance = 0,
				status = RUNE_STATUS_MISSING,
			},
			wisdom = {},
			location = nil,
		}
	elseif bot.rune.wisdom == nil then
		bot.rune.wisdom = {}
	end
end

--------------------------------------------------------------------
-- IsSuitableToPickRune  (reference version — no last-seen check)
--------------------------------------------------------------------
function X.IsSuitableToPickRune()
	if X.IsNearRune(bot, 550) then return true end

	local vRuneLocation = GetRuneSpawnLocation(bot.rune.normal.location)

	if (J.IsRetreating(bot) and botActiveModeDesire > BOT_MODE_DESIRE_HIGH)
	or (#nEnemyHeroes >= 1 and #J.GetHeroesTargetingUnit(nEnemyHeroes, bot) > 0)
	or (bot:WasRecentlyDamagedByAnyHero(5.0) and J.IsRetreating(bot))
	or (GetUnitToUnitDistance(bot, GetAncient(GetTeam())) < 2500 and DotaTime() > 0)
	or GetUnitToUnitDistance(bot, GetAncient(GetOpposingTeam())) < 4000
	or bot:HasModifier('modifier_item_shadow_amulet_fade')
	then
		return false
	end

	return true
end

function X.IsNearRune(hUnit, nRadius)
	nRadius = nRadius or 600
	for _, rune in pairs(nRuneList) do
		local vRuneLocation = GetRuneSpawnLocation(rune)
		if GetUnitToLocationDistance(hUnit, vRuneLocation) <= nRadius then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------
-- GetBestRune  (reference version — simple closest ally check)
--------------------------------------------------------------------
function X.IsEligibleRuneCollector(hero, rune, location)
	if not IsRiverRune(rune) or J.IsCore(hero) then return true end
	for _, ally in pairs(J.GetAlliesNearLoc(location, 1200)) do
		if J.IsValidHero(ally) and ally:IsBot() and J.IsCore(ally)
		and not J.IsSuspiciousIllusion(ally) then return false end
	end
	return true
end

function X.GetBestRune()
	minute = math.floor(DotaTime() / 60)
	second = DotaTime() % 60

	local targetRune = -1
	local targetRuneDistance = math.huge
	local targetRuneScore = math.huge
	for _, rune in pairs(nRuneList) do
		local vRuneLocation = GetRuneSpawnLocation(rune)

		if X.IsTheClosestAlly(bot, vRuneLocation, rune)
		and not X.IsPingedByHumanPlayer(vRuneLocation, math.huge)
		and not IsHumanClaimingRune(rune)
		and not RuneShare.Yield(bot,J,rune,vRuneLocation)
		and not X.IsMissing(rune)
		and X.IsRuneSafe(rune)
		then
			if X.IsEligibleRuneCollector(bot, rune, vRuneLocation)
			then
				local dist = GetUnitToLocationDistance(bot, vRuneLocation)
				local status = GetRuneStatus(rune)
				local canCheck = true
				if IsRiverRune(rune) and DotaTime() >= 0 and status ~= RUNE_STATUS_AVAILABLE then
					canCheck = RiverCheckWindow() and (botPos == 2 or bBottle or dist <= 600)
					local checked = bot.rune.normal.checked and bot.rune.normal.checked[rune]
					if checked and checked >= math.floor(DotaTime() / 120) * 120 and not RiverPreSpawnWindow() then canCheck = false end
					if RiverPreSpawnWindow() and dist > 600 and HasImmediateLastHit() then canCheck = false end
				end
				if IsRiverRune(rune) and ((status == RUNE_STATUS_AVAILABLE and GetRuneType(rune) == RUNE_WATER)
					or (status ~= RUNE_STATUS_AVAILABLE and DotaTime() < 360))
					and not X.HasWaterRuneValue(rune, dist) then canCheck = false end
				-- Mid prioritizes a useful river rune over a slightly closer bounty.
				local score = dist
				if IsRiverRune(rune) and botPos == 2 and dist <= 2400 then score = score - 700 end
				if canCheck and score < targetRuneScore then
					targetRune = rune
					targetRuneDistance = dist
					targetRuneScore = score
				end
			end
		end
	end

	return targetRune, targetRuneDistance
end

--------------------------------------------------------------------
-- IsTheClosestAlly  (reference version — pure distance)
--------------------------------------------------------------------
function X.IsTheClosestAlly(hUnit, vLocation, rune)
	local targetAlly = hUnit
	local targetAllyDistance = GetUnitToLocationDistance(hUnit, vLocation)
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if J.IsValidHero(member) and member:IsBot() and not J.IsSuspiciousIllusion(member)
		and X.IsEligibleRuneCollector(member, rune, vLocation) then
			local memberDistance = GetUnitToLocationDistance(member, vLocation)
			if memberDistance < targetAllyDistance then
				targetAlly = member
				targetAllyDistance = memberDistance
			end
		end
	end
	return targetAlly == hUnit
end

function X.IsThereAllyWithBottle(vLocation, nRadius)
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if J.IsValidHero(member)
		and member ~= bot
		and GetUnitToLocationDistance(member, vLocation) <= nRadius
		and member:FindItemSlot('item_bottle') >= 0
		then
			return true
		end
	end
	return false
end

function X.IsTherePosition(nPos, nRuneLoc, nRadius)
	local vRuneLocation = GetRuneSpawnLocation(nRuneLoc)
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if J.IsValidHero(member) and J.GetPosition(member) == nPos and bot ~= member then
			local dist1 = GetUnitToLocationDistance(bot, vRuneLocation)
			local dist2 = GetUnitToLocationDistance(member, vRuneLocation)
			if dist1 <= nRadius and dist2 <= nRadius then
				return true
			end
		end
	end
	return false
end

--------------------------------------------------------------------
-- Utility functions
--------------------------------------------------------------------
local pingTimeDelta = 8
function X.IsPingedByHumanPlayer(vLocation, nRadius)
	for i = 1, 5 do
		local member = GetTeamMember(i)
		if J.IsValidHero(member)
		and not member:IsBot()
		and GetUnitToLocationDistance(member, vLocation) <= nRadius
		then
			local ping = member:GetMostRecentPing()
			if ping then
				if not ping.normal_ping
				and J.GetDistance(ping.location, vLocation) <= 800
					and GameTime() - ping.time >= 0 and GameTime() - ping.time < pingTimeDelta
				then
					return true
				end
			end
		end
	end
	return false
end

function X.IsPowerRune(nRuneLoc)
	local nRuneType = GetRuneType(nRuneLoc)
	if nRuneType == RUNE_DOUBLEDAMAGE
	or nRuneType == RUNE_HASTE
	or nRuneType == RUNE_ILLUSION
	or nRuneType == RUNE_INVISIBILITY
	or nRuneType == RUNE_REGENERATION
	or nRuneType == RUNE_ARCANE
	or nRuneType == RUNE_SHIELD
	then
		return true
	end
	return false
end

function X.IsMissing(nRune)
	if IsRiverRune(nRune) and RiverPreSpawnWindow() then return false end
	if second < 52 and GetRuneStatus(nRune) == RUNE_STATUS_MISSING then
		return true
	end
	return false
end

function X.IsEnemyPickRune(nRune)
	local vRuneLocation = GetRuneSpawnLocation(nRune)

	if GetUnitToLocationDistance(bot, vRuneLocation) < 600 then return false end

	for _, enemy in pairs(nEnemyHeroes) do
		if J.IsValidHero(enemy)
		and not J.IsSuspiciousIllusion(enemy)
		and GetUnitToLocationDistance(enemy, vRuneLocation) <= 180
		and GetUnitToLocationDistance(bot, vRuneLocation) > 900
		then
			return true
		end
	end

	return false
end

function X.IsUnitAroundLocation(vLoc, nRadius)
	for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
		if IsHeroAlive(id) then
			local info = GetHeroLastSeenInfo(id)
			if info ~= nil then
				local dInfo = info[1]
				if dInfo ~= nil and J.GetDistance(vLoc, dInfo.location) <= nRadius and dInfo.time_since_seen < 1.0 then
					return true
				end
			end
		end
	end
	return false
end

function X.GetScaledDesire(nBase, nCurrDist, nMaxDist)
	-- Local enhancement: cap desire for distant runes in late game
	local maxDesire = 0.92
	if nCurrDist > 2000 and (J.IsLateGame() or J.GetDistanceFromEnemyFountain(bot) < 5500) then
		maxDesire = 0.55
	elseif nCurrDist > 1200 then
		maxDesire = 0.85
	end
	local hp = J.GetHP(bot)
	local resDesire = Clamp(nBase * RemapValClamped(nCurrDist, 0, nMaxDist, 1, 0.5), 0, maxDesire)
	if hp < 0.6 then
		resDesire = RemapValClamped(hp, 0, 0.8, 0, resDesire)
	end
	return resDesire
end

function X.GetRiverDesire(base, distance, maxDistance)
	local desire = X.GetScaledDesire(base, distance, maxDistance)
	-- A positive desire below laning's 0.446 never wins arbitration for Sniper.
	-- Only boost a healthy nearby mid; earlier safety/claim gates still apply.
	if botPos == 2 and botHP >= 0.6 and distance <= 1800 then
		local floor = bot.rune.normal.status == RUNE_STATUS_AVAILABLE and 0.6 or 0.54
		desire = math.max(desire, floor)
	end
	return desire
end

local vGoOutLoc = nil
function X.GetGoOutLocation()
	if vGoOutLoc then return vGoOutLoc end

	if GetTeam() == TEAM_RADIANT then
		if botPos == 1 or botPos == 5 then
			local locs = { Vector(526.370239, -3893.405762, 256.000000), Vector(1999.415894, -4838.790039, 256.000000) }
			vGoOutLoc = locs[RandomInt(1, #locs)]
		elseif botPos == 2 or botPos == 3 or botPos == 4 then
			local locs = { Vector(-3456.702637, 649.725403, 256.000000), Vector(-1945.830322, 60.404663, 128.000000) }
			vGoOutLoc = locs[RandomInt(1, #locs)]
		end
	elseif GetTeam() == TEAM_DIRE then
		if botPos == 1 or botPos == 5 then
			local locs = { Vector(-1051.021973, 3384.059082, 256.000000), Vector(-2415.422119, 4641.448242, 256.000000) }
			vGoOutLoc = locs[RandomInt(1, #locs)]
		elseif botPos == 2 or botPos == 3 or botPos == 4 then
			local locs = { Vector(2734.819580, -1155.105225, 256.000000), Vector(1142.979614, -337.891663, 128.000000) }
			vGoOutLoc = locs[RandomInt(1, #locs)]
		end
	end

	return vGoOutLoc
end

function X.CouldBlink(vLocation)
	local blinkSlot = bot:FindItemSlot("item_blink")
	if bot:GetItemSlotType(blinkSlot) == ITEM_SLOT_TYPE_MAIN
	or (bot:GetUnitName() == "npc_dota_hero_antimage" or bot:GetUnitName() == "npc_dota_hero_queenofpain")
	then
		local blink = bot:GetItemInSlot(blinkSlot)
		if bot:GetUnitName() == "npc_dota_hero_antimage" then
			blink = bot:GetAbilityByName("antimage_blink")
		end
		if bot:GetUnitName() == "npc_dota_hero_queenofpain" then
			blink = bot:GetAbilityByName("queenofpain_blink")
		end
		if J.CanCastAbility(blink) then
			local bDist = GetUnitToLocationDistance(bot, vLocation)
			local maxBlinkLoc = J.Site.GetXUnitsTowardsLocation(bot, vLocation, 1199)
			if bDist <= 500 then
				return false
			elseif bDist < 1200 then
				bot:Action_UseAbilityOnLocation(blink, vLocation)
				return true
			elseif IsLocationPassable(maxBlinkLoc) then
				bot:Action_UseAbilityOnLocation(blink, maxBlinkLoc)
				return true
			end
		end
	end
	return false
end

function X.IsTeamMustSaveRune(nRune)
	if GetTeam() == TEAM_DIRE then
		return nRune == RUNE_BOUNTY_1
			or nRune == RUNE_POWERUP_2
			or (DotaTime() > 1 * 60 + 45 and nRune == RUNE_POWERUP_1)
			or (DotaTime() > 10 * 60 + 45 and nRune == RUNE_BOUNTY_2)
	else
		return nRune == RUNE_BOUNTY_2
			or nRune == RUNE_POWERUP_1
			or (DotaTime() > 1 * 60 + 45 and nRune == RUNE_POWERUP_2)
			or (DotaTime() > 10 * 60 + 45 and nRune == RUNE_BOUNTY_1)
	end
end

--------------------------------------------------------------------
-- Wisdom Rune helpers
--------------------------------------------------------------------
function X.UpdateWisdom()
	if nShrineOfWisdomTime >= 7 and nShrineOfWisdomTime % 7 == 0 and bot.rune then
		for i = 1, 5 do
			local member = GetTeamMember(i)
			if member and member == bot then
				if bot.rune.wisdom[nShrineOfWisdomTime] == nil then
					bot.rune.wisdom[nShrineOfWisdomTime] = {
						spot = {
							[TEAM_RADIANT] = { status = false, location = radiantWRLocation },
							[TEAM_DIRE] = { status = false, location = direWRLocation },
						},
						time = 0,
					}
				end
				if member.rune then member.rune.wisdom = bot.rune.wisdom end
			end

			if member and member.rune and member.rune.wisdom
			and member.rune.wisdom[nShrineOfWisdomTime]
			and bot.rune and bot.rune.wisdom
			and bot.rune.wisdom[nShrineOfWisdomTime]
			then
				for _, team in pairs({TEAM_RADIANT, TEAM_DIRE}) do
					if member.rune.wisdom[nShrineOfWisdomTime].spot[team].status == true then
						bot.rune.wisdom[nShrineOfWisdomTime].spot[team].status = true
					end
				end
			end
		end
	end
end

function X.GetCurrentWisdomTime()
	return math.max(0, math.floor(DotaTime() / 420) * 7)
end

function X.GetWisdomAlly(vLocation)
	local target = nil
	local targetDistance = math.huge
	for i = 1, 5 do
		local member = GetTeamMember(i)
		-- A human already controlling the circle has a clear claim; distance
		-- elsewhere must not silently assign the trip to a human.
		if J.IsValidHero(member) and member:IsAlive() and not member:IsBot()
			and GetUnitToLocationDistance(member, vLocation) < 300 then return nil end
		if J.IsValidHero(member) and member:IsAlive() and member:IsBot()
		and not J.IsSuspiciousIllusion(member) and not J.IsDoingTormentor(member) then
			local memberDistance = GetUnitToLocationDistance(member, vLocation)
			if memberDistance < targetDistance then
				target = member
				targetDistance = memberDistance
			end
		end
	end
	return target
end

function X.GetWisdomDesire(vLocation)
	if (J.IsDefending(bot) and botActiveModeDesire > 0.7)
	or J.IsInTeamFight(bot, 1600) then
		return 0
	end

	local nDesire = 0
	local botLevel = bot:GetLevel()
	local distance = GetUnitToLocationDistance(bot, vLocation)

	if botLevel < 12 then
		nDesire = RemapValClamped(distance, 6400, 3200, 0.75, 0.95)
	elseif botLevel < 18 then
		nDesire = RemapValClamped(distance, 6400, 3200, 0.65, 0.95)
	elseif botLevel < 25 then
		nDesire = RemapValClamped(distance, 6400, 2400, 0.55, 0.95)
	elseif botLevel < 30 then
		nDesire = RemapValClamped(distance, 6400, 2400, 0.45, 0.95)
	end

	return nDesire
end

function X.GetShrineOfWisdomTeam()
	local dist1 = GetUnitToLocationDistance(bot, radiantWRLocation)
	local dist2 = GetUnitToLocationDistance(bot, direWRLocation)

	if GetTeam() == TEAM_RADIANT then
		if dist1 < dist2 then
			return TEAM_RADIANT
		else
			local hTower = GetTower(GetOpposingTeam(), TOWER_BOT_1)
			if hTower == nil or not hTower:IsAlive() or dist2 <= 1600 then
				return TEAM_DIRE
			end
		end
	elseif GetTeam() == TEAM_DIRE then
		if dist1 > dist2 then
			return TEAM_DIRE
		else
			local hTower = GetTower(GetOpposingTeam(), TOWER_TOP_1)
			if hTower == nil or not hTower:IsAlive() or dist1 <= 1600 then
				return TEAM_RADIANT
			end
		end
	end

	return nil
end

function GetDesire() return Runtime.Call(bot,'rune.desire',ModeDesireInternal,0) end
function Think() Runtime.Call(bot,'rune.think',ModeThinkInternal,nil) end
