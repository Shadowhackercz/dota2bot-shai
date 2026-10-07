-- Engine-independent checks; run with Fengari (Lua 5.3), then verify in Dota's Lua VM.
package.path = './?.lua;' .. package.path
GetScriptDirectory = function() return 'bots' end
TEAM_RADIANT, TEAM_DIRE = 2, 3
LANE_TOP, LANE_MID, LANE_BOT = 1, 2, 3
GAMEMODE_CM, GAMEMODE_REVERSE_CM, GAMEMODE_1V1MID = 2, 8, 21
local currentTeam, now, mode = 2, 100, 1
GetTeam = function() return currentTeam end
GetOpposingTeam = function() return currentTeam == 2 and 3 or 2 end
GetGameMode = function() return mode end
GameTime = function() return now end
RandomInt = function(a, b) return math.random(a, b) end
RandomFloat = function(a, b) return a + math.random() * (b - a) end
math.randomseed(731)

local SHAI = require('bots/Customize/shai')
local positions = require('bots/FunLib/aba_hero_pos_weights').GetHeroPositions()
assert(#SHAI.HeroPool == 15)
for _, hero in ipairs(SHAI.HeroPool) do
    assert(positions[hero], 'Unknown hero: ' .. hero)
    assert(loadfile('bots/BotLib/' .. hero:gsub('npc_dota_', '') .. '.lua'))
end
local restricted = SHAI.FilterHeroPositions(positions)
for hero in pairs(restricted) do assert(SHAI.IsHeroEnabled(hero)) end
assert(not restricted.npc_dota_hero_pudge)
for role = 1, 5 do assert(#SHAI.GetRolePool(restricted, role) > 0) end
local tiny = { npc_dota_hero_axe = {0, 0, 80, 0, 0} }
assert(#SHAI.GetRolePool(tiny, 3) == 1)
assert(SHAI.GetRolePool(tiny, 5)[1] == 'npc_dota_hero_axe')
assert(not pcall(SHAI.FilterHeroPositions, {npc_dota_hero_pudge = {1, 1, 1, 1, 1}}))
SHAI.HeroPoolEnabled = false
assert(SHAI.FilterHeroPositions(positions).npc_dota_hero_pudge)
SHAI.HeroPoolEnabled = true

local function contains(list, value)
    for _, item in ipairs(list) do if item == value then return true end end
    return false
end
local function deepcopy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = deepcopy(child) end
    return result
end
local utils = {HasValue = contains, TrimString = function(s) return s:match('^%s*(.-)%s*$') end,
    Deepcopy = deepcopy, IsHumanPlayerInTeam = function() return false end,
    IsHumanPlayerInAnyTeam = function() return true end}
utils.MergeLists = function(a, b)
    local result = deepcopy(a)
    for _, value in ipairs(b) do table.insert(result, value) end
    return result
end
package.loaded['bots/FunLib/utils'] = utils
local teamNames = require('bots/FunLib/aba_team_names')
assert(teamNames.defaultPostfix == 'SHAI')
for _, namesForTeam in pairs(teamNames.generateTeams({})) do
    for _, name in ipairs(namesForTeam) do assert(name:match('%.SHAI$')) end
end
package.loaded['bots/FunLib/aba_global_overrides'] = {}
package.loaded['bots/FretBots/matchups_data'] = {}
package.loaded['bots/FunLib/aba_matchups'] = {}
package.loaded['bots/FunLib/aba_role'] = {RoleAssignment = {
    TEAM_RADIANT = {1,2,3,4,5}, TEAM_DIRE = {1,2,3,4,5}}}
package.loaded['bots/FunLib/captain_mode'] = {}
package.loaded['bots/FunLib/localization'] = {}
local names = {en = {}}
for hero in pairs(positions) do names.en[hero] = hero end
package.loaded['bots/FretBots/HeroNames'] = names
local customize = {Enable = true, Ban = {}, Radiant_Names = {}, Dire_Names = {},
    Radiant_Heros = {'npc_dota_hero_pudge'}, Dire_Heros = {}, Allow_Repeated_Heroes = false}
package.loaded['bots/FunLib/custom_loader'] = customize

local selected, human = {}, {}
GetTeamPlayers = function(team)
    return team == 2 and {0,1,2,3,4} or {5,6,7,8,9}
end
GetSelectedHeroName = function(id) return selected[id] or '' end
GetTeamForPlayer = function(id) return id < 5 and 2 or 3 end
IsPlayerBot = function(id) return not human[id] end
IsPlayerInHeroSelectionControl = function() return true end
SelectHero = function(id, hero)
    assert(hero and SHAI.IsHeroEnabled(hero), 'Disabled/nil bot pick')
    for other, picked in pairs(selected) do
        assert(picked ~= hero or other == id or mode == GAMEMODE_1V1MID, 'Duplicate hero')
    end
    selected[id] = hero
end
local originalPrint = print
print = function() end -- Upstream draft diagnostics are noisy.
local function draft(team)
    currentTeam = team
    dofile('bots/hero_selection.lua')
    for _ = 1, 15 do now = now + 10; Think() end
end
for _ = 1, 25 do
    selected, human = {}, {}
    draft(2); draft(3)
    for id = 0, 9 do assert(selected[id], 'Unfilled bot slot') end
end
-- Human remains outside the pool and consumes a slot, not a bot whitelist entry.
selected, human = {[0] = 'npc_dota_hero_pudge'}, {[0] = true}
draft(2); draft(3)
assert(selected[0] == 'npc_dota_hero_pudge')
-- Banning the entire pool must not silently escape to unrestricted picks.
selected, human = {}, {}
customize.Ban = deepcopy(SHAI.HeroPool)
draft(2)
for id = 0, 4 do assert(selected[id] == nil) end
customize.Ban = {}
-- 1v1 may not mirror a disabled human hero.
selected, human = {[5] = 'npc_dota_hero_pudge'}, {[5] = true}
currentTeam, mode = 2, GAMEMODE_1V1MID
dofile('bots/hero_selection.lua')
Think()
local oneVOnePicked = false
for id = 0, 4 do
    if selected[id] then
        assert(SHAI.IsHeroEnabled(selected[id]))
        oneVOnePicked = true
    end
end
assert(oneVOnePicked) -- pairs() does not guarantee which empty slot is visited first.
-- Enabled heroes still retain the upstream 1v1 mirror behavior.
selected, human = {[5] = 'npc_dota_hero_zuus'}, {[5] = true}
dofile('bots/hero_selection.lua')
Think()
local mirrored = false
for id = 0, 4 do if selected[id] == 'npc_dota_hero_zuus' then mirrored = true end end
assert(mirrored)
print = originalPrint
print('PASS: SHAI names, 25 full drafts, mixed human draft, closed pool under bans, small pools, 1v1 and hero load syntax')
