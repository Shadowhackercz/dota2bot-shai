BOT_MODE_LANING, BOT_MODE_RETREAT = 1, 2
local trace = dofile('bots/FunLib/shai_behavior_trace.lua')
local lines, mode, alive = {}, 1, true
print = function(line) table.insert(lines, line) end
local bot = {}
function bot:IsNull() return false end
function bot:IsIllusion() return false end
function bot:GetActiveMode() return mode end
function bot:IsAlive() return alive end
function bot:GetTarget() return nil end
function bot:GetAttackTarget() return nil end
function bot:GetLocation() return {x=100, y=200} end
function bot:GetTeam() return 2 end
function bot:GetPlayerID() return 3 end
function bot:GetUnitName() return 'npc_dota_hero_zuus' end
function bot:GetActiveModeDesire() return 0.6 end
function bot:GetHealth() return 500 end
function bot:GetMaxHealth() return 1000 end
function bot:GetMana() return 0 end
function bot:GetMaxMana() return 0 end
trace.Observe(bot, 0, false)
assert(#lines == 0)
trace.Observe(bot, 0, true)
assert(#lines == 1 and lines[1]:find('mode=BOT_MODE_LANING'))
mode = 2
trace.Observe(bot, 0.25, true)
mode = 1
trace.Observe(bot, 0.5, true)
assert(#lines == 1, 'rapid changes must not flood output')
trace.Observe(bot, 1, true)
assert(lines[2]:find('switches=2; rapid=2; reversals=1'))
trace.Observe(bot, 9, true)
assert(#lines == 2)
trace.Observe(bot, 10, true)
assert(#lines == 3, 'stable modes need heartbeat')
alive, mode = false, 2
trace.Observe(bot, 11, true)
assert(lines[4]:find('alive=false') and lines[4]:find('switches=2'))
trace.Observe(bot, -1, true)
assert(lines[5]:find('switches=0; rapid=0; reversals=0'), 'time reset must clear counters')
io.write('PASS: behavior trace throttling, reversals, heartbeat, death and reset\n')
