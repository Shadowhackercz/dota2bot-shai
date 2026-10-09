package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
DAMAGE_TYPE_PHYSICAL=1
UNIT_LIST_ENEMY_HEROES,UNIT_LIST_ENEMY_CREEPS=1,2
TOWER_TOP_1,TOWER_MID_1,TOWER_BOT_1,TOWER_TOP_2,TOWER_MID_2,TOWER_BOT_2=1,2,3,4,5,6
TOWER_TOP_3,TOWER_MID_3,TOWER_BOT_3,TOWER_BASE_1,TOWER_BASE_2=7,8,9,10,11
BARRACKS_TOP_MELEE,BARRACKS_MID_MELEE,BARRACKS_BOT_MELEE=1,2,3
local now,cooldown=1000,0
DotaTime=function() return now end
GetGlyphCooldown=function() return cooldown end
GetUnitToUnitDistance=function(a,b) assert(a.visible and b.visible,'Hidden position read'); return math.abs(a.x-b.x) end
local function unit(name,id,x)
    local h={name=name,id=id,x=x,hp=2000,maxHp=2000,damage=100,visible=true,range=500}
    local function visible(self) assert(self.visible,'Hidden stats read') end
    function h:IsNull() return false end
    function h:IsAlive() return self.hp>0 end
    function h:IsBot() return not self.human end
    function h:CanBeSeen() return self.visible end
    function h:IsStunned() return self.stunned or false end
    function h:IsHexed() return self.hexed or false end
    function h:IsInvulnerable() return self.invulnerable or false end
    function h:HasModifier() return self.teleport or false end
    function h:GetPlayerID() return self.id end
    function h:GetUnitName() return self.name end
    function h:GetHealth() visible(self); return self.hp end
    function h:GetMaxHealth() return self.maxHp end
    function h:GetAttackTarget() visible(self); return self.target end
    function h:GetAttackRange() return self.range end
    function h:GetAttackDamage() visible(self); return self.damage end
    function h:GetSecondsPerAttack() return 1 end
    function h:GetCurrentMovementSpeed() return 300 end
    function h:GetActualIncomingDamage(raw) return raw*0.5 end
    function h:ActionImmediate_Glyph() self.glyphs=(self.glyphs or 0)+1 end
    return h
end
local team,heroes,creeps,tower,ancient,barracks,bot,second,enemy
GetTeamMember=function(slot) return team[slot] end
GetUnitList=function(kind) return kind==UNIT_LIST_ENEMY_HEROES and heroes or creeps end
GetTower=function(_,index) return index==TOWER_MID_3 and tower or nil end
GetAncient=function() return ancient end
GetBarracks=function(_,index) return index==BARRACKS_MID_MELEE and barracks or nil end
require('bots/Customize/shai').BehaviorTrace=false
local Glyph=require('bots/FunLib/shai_glyph')
local function reset()
    now=now+20; cooldown=0
    team={}
    for slot=1,3 do team[slot]=unit('human',slot-1,5000); team[slot].human=true end
    bot=unit('bot-3',3,5000); second=unit('bot-4',4,5000); team[4],team[5]=bot,second
    tower=unit('tower-mid-3',20,0); tower.hp=1000; tower.maxHp=8000
    enemy=unit('enemy',10,200); enemy.damage=500; enemy.target=tower
    heroes,creeps={enemy},{}; ancient,barracks=nil,nil
end
reset(); assert(not Glyph.Try(second,2),'Only the elected bot uses the shared resource')
assert(Glyph.Try(bot,2) and bot.glyphs==1,'Three human teammates no longer disable automatic glyph')
assert(not Glyph.Try(bot,2),'Do not issue again before engine cooldown replication')
bot.hp=0; assert(not Glyph.Try(second,2),'Executor failover retains the shared issue reservation')
now=now+1.1; assert(Glyph.Try(second,2),'Alive backup takes over when the original executor dies')
reset(); cooldown=1; assert(not Glyph.Try(bot,2),'Available cooldown is mandatory')
reset(); enemy.visible=false; assert(not Glyph.Try(bot,2),'Hidden siege is not read')
reset(); enemy.target=nil; assert(not Glyph.Try(bot,2),'Nearby enemies without an attack order do not trigger glyph')
reset(); tower.invulnerable=true; assert(not Glyph.Try(bot,2),'Already protected building needs no glyph')
reset(); tower.hp=1500; enemy.damage=50
assert(not Glyph.Try(bot,2),'Low HP percentage alone is not a reason to spend glyph')
reset(); tower.hp,tower.maxHp=1000,1000; enemy.damage=1000
assert(Glyph.Try(bot,2),'Fast incoming siege is recognized before a fixed low-HP threshold')
reset(); heroes={}; local creep=unit('siege-creep',15,100); creep.damage=500; creep.target=tower; creeps={creep}
assert(Glyph.Try(bot,2),'Creep-only siege can also threaten a building')
reset(); tower.hp=2500 -- ten seconds until fall; no help currently within reach
assert(not Glyph.Try(bot,2),'Slow unrelieved tower siege does not waste glyph automatically')
team[1].x=100; now=now+0.3; assert(Glyph.Try(bot,2),'A real nearby defender gives a short rescue window')
reset(); ancient=unit('ancient',21,0); ancient.hp=2000; enemy.target=ancient
assert(Glyph.Try(bot,2),'Ancient receives priority at eight seconds until loss')
reset(); tower=nil; barracks=unit('melee-barracks',22,0); barracks.hp=500; enemy.target=barracks
assert(Glyph.Try(bot,2),'Barracks siege is considered')
reset(); team[4]=nil; assert(Glyph.Try(second,2),'Missing slots are safe and do not require five bot teammates')
reset(); bot.hp,second.hp=0,0; assert(Glyph.Try(bot,2),'Dead bot executor can still call the team fortification action')
reset(); now=30; assert(not Glyph.Try(bot,2),'Pregame protection is preserved')
reset(); for _,h in pairs(team) do h.human=true end; assert(not Glyph.Try(bot,2),'All-human team has no bot executor')
-- Verify the actual generic entry is connected and goes through runtime diagnostics.
reset(); local called,source=0,nil
local callback=dofile('.tools/lua/shai-glyph-callback.lua')(bot,2,Glyph,{Call=function(_,s,fn) source=s; called=called+1; return fn() end})
callback(); assert(bot.glyphs==1 and called==1 and source=='glyph','Actual generic callback delegates to the tested shared helper')
print('PASS: real glyph callback, mixed teams, executor/failover, cooldown, fog, damage timing, relief and hero/creep/Ancient siege')
