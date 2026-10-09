-- Regressions from the real Pudge lobby. Do not supply invented bot APIs.
package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_ACTION_DESIRE_NONE,BOT_ACTION_DESIRE_HIGH,ITEM_TARGET_TYPE_NONE=0,0.8,0
BOT_MODE_NONE=0
DotaTime=function() return 2400 end
local location={x=100,y=200}
local bot={GetLocation=function() return location end,GetUnitName=function() return 'npc_dota_hero_warlock' end,
    WasRecentlyDamagedByAnyHero=function() return false end,GetHealthRegen=function() return 0 end,
    GetIncomingTrackingProjectiles=function() return {} end,GetHealth=function() return 200 end}
assert(bot.GetCastRangeBonus==nil,'The bot contract must not fabricate this unavailable API')
local enemies={{HasModifier=function() return false end},{HasModifier=function() return false end}}
local J={GetEnemiesNearLoc=function(loc,radius)
    assert(loc==location and radius==600,'Pollen Bag passed an invalid or stale location')
    return enemies
end,IsInTeamFight=function() return true end,IsValidHero=function() return true end,
    CanBeAttacked=function() return true end,CanCastOnNonMagicImmune=function() return true end,
    IsGoingOnSomeone=function() return false end}
local pollen=dofile('.tools/lua/shai-pollen-helper.lua')(bot,J)
local item={GetSpecialValueInt=function(_,key) assert(key=='debuff_radius'); return 600 end}
assert(pollen(item)==0.8,'The actual item consideration runs with a current bot vector')
table.remove(enemies)
assert(pollen(item)==0,'Keep the original teamfight target count threshold')
local Survival=require('bots/FunLib/shai_cast_survival')
J.GetHP=function() return 0.4 end
J.GetNearbyHeroes=function() return {} end
J.GetModifierTime=function() return 0 end
local distance=600
GetUnitToLocationDistance=function(unit,loc)
    assert(unit==bot and loc==location,'Cast survival must receive a vector in the location argument')
    return distance
end
local ability={GetCastRange=function() return 500 end,GetCastPoint=function() return 0.2 end,
    GetName=function() return 'warlock_rain_of_chaos' end}
assert(not Survival.Allow(bot,J,ability,location,'control'),'Reject a cast requiring an unsafe walk without a bonus API')
distance=450
assert(Survival.Allow(bot,J,ability,location,'control'),'Allow an in-range survivable cast without a bonus API')
print('PASS: real Pollen Bag location and cast survival with the actual limited bot API contract')
