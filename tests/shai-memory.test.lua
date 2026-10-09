package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_NONE,BOT_MODE_FARM,BOT_MODE_LANING,BOT_MODE_RETREAT,BOT_MODE_EVASIVE_MANEUVERS=0,1,2,3,4
BOT_MODE_DESIRE_NONE,DAMAGE_TYPE_PHYSICAL,DAMAGE_TYPE_ALL=0,1,0
UNIT_LIST_ENEMY_HEROES=2
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=1500
DotaTime,GameTime=function() return now end,function() return now end
local function hero(name,id,x)
    local h={name=name,id=id,loc=Vector(x,0),hp=1800,maxHp=1800,level=13,damage=100,interval=1,speed=300,range=500,visible=true,mods={}}
    local function visible(self) assert(self.visible,'Hidden enemy stats read') end
    function h:IsNull() return false end
    function h:IsAlive() visible(self); return self.hp>0 end
    function h:CanBeSeen() return self.visible end
    function h:IsBot() return not self.human end
    function h:IsHero() visible(self); return true end
    function h:IsIllusion() visible(self); return self.illusion or false end
    function h:IsStunned() visible(self); return false end
    function h:IsHexed() visible(self); return false end
    function h:IsInvulnerable() visible(self); return self.invulnerable or false end
    function h:GetPlayerID() visible(self); return self.id end
    function h:GetUnitName() visible(self); return self.name end
    function h:GetLocation() visible(self); if self.badLocation then return nil end; return self.loc end
    function h:GetHealth() visible(self); return self.hp end
    function h:GetMaxHealth() visible(self); return self.maxHp end
    function h:GetLevel() visible(self); return self.level end
    function h:GetAttackRange() visible(self); return self.range end
    function h:GetAttackDamage() visible(self); return self.damage end
    function h:GetSecondsPerAttack() visible(self); return self.interval end
    function h:GetCurrentMovementSpeed() visible(self); return self.speed end
    function h:GetActualIncomingDamage(raw) visible(self); return raw*0.75 end
    function h:GetEstimatedDamageToTarget(_,_,seconds) visible(self); return self.damage*seconds end
    function h:GetAttackTarget() visible(self); return self.target end
    function h:HasModifier(mod) visible(self); return self.mods[mod] or false end
    function h:IsFacingLocation() visible(self); return self.facing~=false end
    function h:IsCastingAbility() return false end
    function h:IsUsingAbility() return false end
    function h:WasRecentlyDamagedByHero() return false end
    function h:WasRecentlyDamagedByAnyHero() return false end
    function h:GetActiveMode() return self.mode or BOT_MODE_FARM end
    function h:SetTarget(t) self.target=t end
    function h:Action_MoveToLocation(p) self.action='move'; self.destination=p end
    return h
end
local bot,ally,enemy,team,enemies
local function reset()
    now=math.max(1500,now+20)
    bot=hero('npc_dota_hero_zuus',1,0); ally=hero('npc_dota_hero_lion',2,5000)
    enemy=hero('npc_dota_hero_silencer',10,600); enemy.level=23; enemy.damage=450; enemy.hp=3000
    local human=hero('human',0,5000); human.human=true
    team,enemies={human,bot,ally},{enemy}
end
GetTeamMember=function(slot) return team[slot] end
GetUnitList=function() return enemies end
GetUnitToUnitDistance=function(a,b) assert(a.visible and b.visible); return math.abs(a.loc.x-b.loc.x) end
GetTeam,GetOpposingTeam=function() return 2 end,function() return 3 end
GetBot=function() return bot end
RandomInt=function(a) return a end
IsLocationPassable=function() return true end
local J={Utils={NumHumanBotPlayersInTeam=function() return 1,4 end,BuggyHeroesDueToValveTooLazy={}}}
J.IsValidHero=function(h) return h~=nil and h:IsAlive() end
J.IsSuspiciousIllusion=function(h) return h:IsIllusion() end
J.GetNearbyHeroes=function(h,range,opponent)
    local list={}
    for _,u in pairs(opponent and enemies or team) do
        if u.visible and math.abs(h.loc.x-u.loc.x)<=range then list[#list+1]=u end
    end
    return list
end
J.GetModifierTime=function() return 0 end
J.CanNotUseAction=function(h) return h.busy or false end
J.VectorAway=function(a,b,d)
    local dx,dy=a.x-b.x,a.y-b.y; local len=math.sqrt(dx*dx+dy*dy)
    return Vector(a.x+dx/len*d,a.y+dy/len*d)
end
J.GetTeamFountain=function() return Vector(-6000,-6000) end
J.IsNoAbilityIllution=function() return true end
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/FunLib/utils']=J.Utils
package.loaded['bots/FunLib/version'],package.loaded['bots/FunLib/localization']={},{}
package.loaded['bots/Customize/general']={ThinkLess=0}
require('bots/Customize/shai').BehaviorTrace=false
local Memory=require('bots/FunLib/shai_threat_memory')
local Farm=require('bots/FunLib/shai_farm_safety')
reset(); Memory.Observe(bot,J); enemy.visible=false
local concern=Memory.GetConcern(bot,J,bot.loc)
assert(concern~=nil and concern.memory and concern.location.x==600,'Observed dominant hero persists after loss of vision')
enemy.loc.x=9000; enemy.hp=1; enemy.level=1; enemy.damage=1
now=now+1
local later=Memory.GetConcern(bot,J,bot.loc)
assert(later.location.x==600 and later.confidence<concern.confidence and later.uncertainty>concern.uncertainty,
    'Confidence decays and uncertainty grows without following hidden movement or changed stats')
now=now+5; assert(Memory.GetConcern(bot,J,bot.loc)==nil,'Caution expires before stale information blocks the map indefinitely')
reset(); enemy.loc.x=5000; Memory.Observe(bot,J)
assert(Memory.GetConcern(bot,J,bot.loc)==nil,'Far-away ward vision does not immediately interrupt local farm')
enemy.visible=false; now=now+0.3
assert(Memory.GetConcern(bot,J,Vector(4700,0))~=nil,'That observation protects a farm location near the last seen hero')
-- New module instance stands in for another bot VM; entity state is shared.
package.loaded['bots/FunLib/shai_threat_memory']=nil
local OtherVM=require('bots/FunLib/shai_threat_memory')
assert(OtherVM.GetConcern(ally,J,ally.loc)~=nil,'Another bot VM reads the team observation from the same owner entity')
bot.hp=0; assert(OtherVM.GetConcern(ally,J,ally.loc)~=nil,'Owner death does not erase observations for surviving teammates')
reset(); Memory.Observe(bot,J); enemy.visible=false; now=now+0.5
assert(Memory.GetConcern(bot,J,Vector(2000,0))==nil,'Possible movement radius is bounded')
reset(); enemy.level=14; enemy.damage=50; Memory.Observe(bot,J); enemy.visible=false
assert(Memory.GetConcern(bot,J,bot.loc)==nil,'Ordinary nearby opponent does not make farm permanently passive')
reset(); enemy.hp=70; Memory.Observe(bot,J); enemy.visible=false
assert(Memory.GetConcern(bot,J,bot.loc)==nil,'A nearly dead enemy is not treated as a fully healthy dominant threat')
reset(); Memory.Observe(bot,J); enemy.visible=false; now=now+1
assert(Memory.GetConcern(bot,J,bot.loc)~=nil)
enemy.visible=true; enemy.loc.x=7000; now=now+0.3; Memory.Observe(bot,J); enemy.visible=false
assert(Memory.GetConcern(bot,J,bot.loc)==nil,'New vision supersedes the old dangerous location immediately')
reset(); Memory.Observe(bot,J); enemy.hp=0; now=now+0.3; Memory.Observe(bot,J); enemy.visible=false
assert(Memory.GetConcern(bot,J,bot.loc)==nil,'A visibly confirmed death clears the old snapshot')
reset(); enemy.illusion=true; Memory.Observe(bot,J); enemy.visible=false
assert(Memory.GetConcern(bot,J,bot.loc)==nil,'Illusions are not recorded as real threat observations')
reset(); Memory.Observe(bot,J); local illusion=hero('illusion',10,800); illusion.illusion=true
enemy.visible=false; enemies[#enemies+1]=illusion; now=now+0.3; Memory.Observe(bot,J)
assert(Memory.GetConcern(bot,J,bot.loc)~=nil,'Visible clone sharing a player ID does not erase the real hero snapshot')
reset(); enemy.badLocation=true; Memory.Observe(bot,J); enemy.visible=false
assert(Memory.GetConcern(bot,J,bot.loc)==nil,'Missing location cannot become a malformed stored vector')
reset(); now=500; Memory.Observe(bot,J); enemy.visible=false; now=501
assert(Memory.GetConcern(bot,J,bot.loc)==nil,'Opening ten minutes retain the existing local safety policy')
reset(); Memory.Observe(bot,J); enemy.visible=false; now=900
assert(Memory.GetConcern(bot,J,bot.loc)==nil,'Clock rollback clears observations instead of borrowing them from an old game')
reset(); enemy.loc.x=1000; enemy.facing=false
assert(Farm.GetThreat(bot,J)~=nil,'Visible dominant enemy affects nearby farm even when facing away')
reset(); now=500; enemy.loc.x=1000; enemy.facing=false
assert(Farm.GetThreat(bot,J)==nil,'That extra precaution does not change the first ten minutes')
reset(); Memory.Observe(bot,J); enemy.visible=false; now=now+0.3
assert(Farm.GetThreat(bot,J).memory,'Actual farm guard uses remembered danger after loss of vision')
assert(Farm.InterruptFarm(bot,J) and bot.action=='move' and bot.destination.x<bot.loc.x,'Movement backs away from the observed location')
bot.action=nil; bot.busy=true
assert(Farm.InterruptFarm(bot,J) and bot.action==nil,'Memory does not interrupt an already active spell/channel')
bot.busy=false
local farm=dofile('bots/mode_farm_generic.lua')
assert(GetDesire()==0,'Actual farm mode yields to remembered danger')
Think(); assert(bot.action=='move','Actual farm Think cannot replace avoidance with a creep attack')
dofile('bots/mode_retreat_generic.lua')
assert(GetDesireHelper()==0.96,'Actual retreat can take priority over farming in a remembered danger area')
-- Actual ability callback observes team vision even when a tactical plan owns offense.
reset(); enemy.loc.x=5000; bot.frameProcessTime=0.1
local callback=dofile('.tools/lua/shai-ability-callback.lua')
local invoke=callback(bot,J,{TryControl=function() return true end,HoldOffense=function() return true end},
    {Observe=function() end},{BehaviorTrace=false},{ThinkLess=0},{},function() return false end,true,bot.name,
    {ReleaseObjective=function() end},nil,nil,nil,nil,nil,Memory)
invoke(); now=now+0.2; invoke(); enemy.visible=false; now=now+0.3
assert(Memory.GetConcern(ally,J,ally.loc)~=nil,'Generic callback records distant team vision before tactical offense returns')
print('PASS: team threat snapshots, distinct VM sharing, ward range, fog without hidden reads, decay/radius/reset, invalid vectors and actual farm/retreat/callback integration')
