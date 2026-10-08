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
for role = 1, 5 do
    local pool = SHAI.GetRolePool(restricted, role)
    assert(#pool == 3)
    for _, hero in ipairs(pool) do assert(hero == SHAI.RolePools[role][1]
        or hero == SHAI.RolePools[role][2] or hero == SHAI.RolePools[role][3]) end
end
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
for _ = 1, 25 do
    local seen = {}
    for _, namesForTeam in pairs(teamNames.generateTeams({})) do
        assert(#namesForTeam == 12)
        for _, name in ipairs(namesForTeam) do
            assert(name:match('^SHAI%.[%a]+$') and #name <= 11)
            assert(not seen[name], 'Duplicate bot name across teams')
            seen[name] = true
        end
    end
end
local customNames = teamNames.generateTeams({Radiant = {'MyBot', 'Random'}, Dire = {'SHAI.Nova'}})
assert(customNames.Radiant[1] == 'MyBot' and customNames.Dire[1] == 'SHAI.Nova')
for _, name in ipairs(customNames.Radiant) do assert(name ~= 'SHAI.Nova') end
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

local selected, human, pickedAt = {}, {}, {}
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
    pickedAt[id] = now
end
local originalPrint = print
print = function() end -- Upstream draft diagnostics are noisy.
local function draft(team)
    currentTeam = team
    local started = now
    dofile('bots/hero_selection.lua')
    for _ = 1, 32 do now = now + 0.25; Think() end
    for _, id in ipairs(GetTeamPlayers(team)) do
        if selected[id] and not human[id] then assert(pickedAt[id] - started <= 6) end
    end
end
for _ = 1, 25 do
    selected, human = {}, {}
    draft(2); draft(3)
    for id = 0, 9 do assert(selected[id], 'Unfilled bot slot') end
    for id = 0, 9 do
        local role = id % 5 + 1
        assert(contains(SHAI.RolePools[role], selected[id]), 'Bot assigned to wrong role pool')
    end
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
-- Lane aliases exercise the actual chat callback and returned engine lanes.
GAME_STATE_PRE_GAME, GAME_STATE_GAME_IN_PROGRESS = 5, 6
local state = GAME_STATE_PRE_GAME
GetGameState = function() return state end
InstallChatCallback = function() end
for _, team in ipairs({TEAM_RADIANT, TEAM_DIRE}) do
    currentTeam, mode = team, 1
    local ids = GetTeamPlayers(team)
    human = {[ids[3]]=true, [ids[4]]=true}
    local teamKey = team == 2 and 'TEAM_RADIANT' or 'TEAM_DIRE'
    local roles = package.loaded['bots/FunLib/aba_role'].RoleAssignment
    roles[teamKey] = {1,2,3,4,5}
    dofile('bots/hero_selection.lua')
    SelectHeroChatCallback(ids[3], '!mid', true)
    assert(roles[teamKey][3] == 2 and roles[teamKey][2] == 3)
    local lanes = UpdateLaneAssignments()
    assert(lanes[team == 2 and 3 or 1] == LANE_MID, 'human-first Dire lane mapping team='..team..' lanes='..table.concat(lanes, ','))
    -- Reset roles for two humans claiming a side lane: core first, support next.
    roles[teamKey] = {1,2,3,4,5}
    human = {[ids[2]]=true, [ids[4]]=true}
    dofile('bots/hero_selection.lua')
    local command = team == 2 and '!bottom' or '!top'
    SelectHeroChatCallback(ids[2], command, true)
    assert(roles[teamKey][2] == 1)
    SelectHeroChatCallback(ids[4], command, true)
    assert(roles[teamKey][4] == 5 and roles[teamKey][2] == 1)
    SelectHeroChatCallback(ids[4], command, true)
    assert(roles[teamKey][4] == 5, 'same claim must not evict human core')
    local before = deepcopy(roles[teamKey])
    SelectHeroChatCallback(team == 2 and 5 or 0, '!mid', false)
    SelectHeroChatCallback(ids[2], command..' unexpected', true)
    state = GAME_STATE_GAME_IN_PROGRESS
    SelectHeroChatCallback(ids[2], '!mid', true)
    state = GAME_STATE_PRE_GAME
    for i=1,5 do assert(roles[teamKey][i] == before[i]) end
    for _, sideCommand in ipairs({'!top', '!bottom'}) do
        roles[teamKey] = {1,2,3,4,5}
        human = {[ids[2]]=true}
        dofile('bots/hero_selection.lua')
        local safe = (team == 2 and sideCommand == '!bottom') or (team == 3 and sideCommand == '!top')
        local coreRole, supportRole = safe and 1 or 3, safe and 5 or 4
        local requested = sideCommand == '!top' and LANE_TOP or LANE_BOT
        local other = requested == LANE_TOP and LANE_BOT or LANE_TOP
        SelectHeroChatCallback(ids[2], sideCommand, true)
        assert(roles[teamKey][2] == coreRole)
        lanes = UpdateLaneAssignments()
        local supportIndex = supportRole -- human slot 2 moves first; later bot slots keep their index
        assert(lanes[supportIndex] == requested, 'first request keeps support')
        SelectHeroChatCallback(ids[2], sideCommand, true)
        lanes = UpdateLaneAssignments()
        assert(lanes[supportIndex] == other, 'repeat sends support to other side lane')
        assert(roles[teamKey][supportRole] == supportRole, 'support retains build role')
        SelectHeroChatCallback(ids[2], sideCommand, true)
        assert(UpdateLaneAssignments()[supportIndex] == other, 'third request must not toggle')
        SelectHeroChatCallback(ids[2], '!mid', true)
        assert(UpdateLaneAssignments()[supportIndex] == requested, 'changing lane clears solo request')
        SelectHeroChatCallback(ids[2], sideCommand, true)
        SelectHeroChatCallback(ids[2], sideCommand, true)
        SelectHeroChatCallback(ids[2], '!pos 2', true)
        assert(UpdateLaneAssignments()[supportIndex] == requested, 'numeric position clears solo relocation')
    end
end
print = originalPrint
print('PASS: SHAI draft, names, pool, 1v1; real lane chat aliases, two humans, solo repeat and Radiant/Dire assignments')
