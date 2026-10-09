local Defend = require( GetScriptDirectory()..'/FunLib/aba_defend')
local Defense = require(GetScriptDirectory()..'/FunLib/shai_defense')
local J = require(GetScriptDirectory()..'/FunLib/jmz_func')
local Runtime = require(GetScriptDirectory()..'/FunLib/shai_runtime')

local bot = GetBot()
local botName = bot:GetUnitName()

if bot:IsInvulnerable() or not bot:IsHero() or not string.find(botName, "hero") or bot:IsIllusion() then
	return
end

function GetDesire() return Runtime.Call(bot,'defend.desire',function() return Defend.GetDefendDesire(bot, LANE_TOP) end,0) end
local function DefendThinkInternal()
    if Defense.Think(bot,J) then return end
    Defend.DefendThink(bot, LANE_TOP)
end

function Think() Runtime.Call(bot,'defend.think',DefendThinkInternal,nil) end
