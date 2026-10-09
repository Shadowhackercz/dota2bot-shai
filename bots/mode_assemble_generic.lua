local bot = GetBot()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not string.find(bot:GetUnitName(), "hero") or bot:IsIllusion() then return end

local J = require( GetScriptDirectory()..'/FunLib/jmz_func' )
local Intent = require(GetScriptDirectory()..'/FunLib/shai_ping_intent')
local SHAI = require(GetScriptDirectory()..'/Customize/shai')

local ASSEMBLE_DURATION = 5    -- stay in assemble mode for this long after ping
local ASSEMBLE_DESIRE = 0.85   -- desire value when assembling
local ARRIVE_RADIUS = 500      -- close enough to ping location
local MAX_RESPOND_DIST = 3200  -- only respond if within this distance

local assembleLoc = nil
local assembleExpireTime = 0
local assembleCreated = 0

function GetDesire()
	if not bot:IsAlive() then assembleLoc=nil; return BOT_MODE_DESIRE_NONE end
	if assembleLoc~=nil and GameTime()<assembleCreated then assembleLoc=nil; assembleExpireTime=0 end

	local ping=Intent.Poll(bot,J)
	if J.IsRetreating(bot) or bot:WasRecentlyDamagedByAnyHero(2) or J.IsInTeamFight(bot,1200) then
		assembleLoc=nil; return BOT_MODE_DESIRE_NONE
	end
	if ping~=nil then
		local dist = GetUnitToLocationDistance(bot, ping.location)
		-- Only respond if we're not already very close and not too far away
		if dist > ARRIVE_RADIUS and dist < MAX_RESPOND_DIST then
			assembleLoc = ping.location
			assembleExpireTime = ping.expires
			assembleCreated = ping.time
			J.ModeAnnounce(bot, 'say_assemble', ASSEMBLE_DURATION)
			if SHAI.BehaviorTrace then
				print('[SHAI] ping-intent t='..DotaTime()..'; hero='..bot:GetUnitName()..'; reason=double-ping; player='..ping.player)
			end
			return ASSEMBLE_DESIRE
		end
	end

	-- Continue moving to assembly point if still active
	if assembleLoc ~= nil and GameTime() < assembleExpireTime then
		local dist = GetUnitToLocationDistance(bot, assembleLoc)
		if dist <= ARRIVE_RADIUS then
			assembleLoc = nil
			return BOT_MODE_DESIRE_NONE
		end
		return ASSEMBLE_DESIRE
	end

	assembleLoc = nil
	return BOT_MODE_DESIRE_NONE
end

function OnEnd()
	assembleLoc = nil
	assembleExpireTime = 0
end

function Think()
	if not bot:IsAlive() then assembleLoc=nil; return end
	if J.CanNotUseAction(bot) then return end
	if assembleLoc == nil then return end
	if GameTime()<assembleCreated or GameTime()>=assembleExpireTime or J.IsRetreating(bot) or bot:WasRecentlyDamagedByAnyHero(2)
		or J.IsInTeamFight(bot,1200) then assembleLoc=nil; return end

	local dist = GetUnitToLocationDistance(bot, assembleLoc)
	if dist <= ARRIVE_RADIUS then
		assembleLoc = nil
		return
	end

	bot:Action_MoveToLocation(assembleLoc)
end
