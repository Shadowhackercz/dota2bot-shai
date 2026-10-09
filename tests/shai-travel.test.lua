package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
UNIT_LIST_ALLIED_HEROES,UNIT_LIST_ENEMY_HEROES=1,2
DAMAGE_TYPE_ALL,DAMAGE_TYPE_PHYSICAL=1,2
BOT_MODE_NONE,BOT_MODE_RETREAT,BOT_MODE_FARM,BOT_MODE_ITEM=0,1,2,3
BOT_ACTION_TYPE_IDLE=0
local now=1000
DotaTime=function() return now end
GetTeam=function() return 2 end
local function loc(x) return {x=x,y=0,z=0} end
local function hero(id,x,level)
    local h={id=id,x=x,level=level or 12,hp=2000,maxHp=2000,dps=100,visible=true,mods={},items={},projectiles={},actions=0,queue=0}
    local function visible(self) assert(self.visible,'Read hidden enemy') end
    function h:IsNull() return false end
    function h:IsAlive() return self.hp>0 end
    function h:CanBeSeen() return self.visible end
    function h:GetUnitName() return 'hero-'..self.id end
    function h:GetPlayerID() return self.id end
    function h:GetTeam() return 2 end
    function h:GetLocation() visible(self); return loc(self.x) end
    function h:GetHealth() visible(self); return self.hp end
    function h:GetMaxHealth() return self.maxHp end
    function h:GetHealthRegen() return self.regen or 0 end
    function h:GetLevel() visible(self); return self.level end
    function h:GetEstimatedDamageToTarget(_,_,t) visible(self); return self.dps*t end
    function h:GetAttackTarget() return self.target end
    function h:GetAttackDamage() return 100 end
    function h:GetActualIncomingDamage(d) return d end
    function h:IsBot() return not self.human end
    function h:IsStunned() return self.stunned or false end
    function h:IsHexed() return false end
    function h:IsChanneling() return self.channel or false end
    function h:IsUsingAbility() return self.using or false end
    function h:IsCastingAbility() return self.casting or false end
    function h:GetActiveMode() return self.mode or BOT_MODE_FARM end
    function h:GetAssignedLane() return 2 end
    function h:GetCurrentActionType() return BOT_ACTION_TYPE_IDLE end
    function h:WasRecentlyDamagedByAnyHero() return self.recent or false end
    function h:NumQueuedActions() return self.queue end
    function h:HasModifier(name) visible(self); return self.mods[name] or false end
    function h:GetItemInSlot(slot) visible(self); return self.items[slot] end
    function h:GetNearbyTowers() return self.towers or {} end
    function h:GetIncomingTrackingProjectiles() return self.projectiles end
    function h:Action_ClearActions(stop) self.clears=(self.clears or 0)+1; self.actions=self.actions+1; self.stopped=stop end
    function h:ActionQueue_AttackMove(where) assert(where~=nil); self.actions=self.actions+1 end
    function h:Action_UseAbilityOnLocation(a,where) assert(where~=nil); self.cast=a; self.castLocation=where; self.actions=self.actions+1 end
    function h:Action_UseAbilityOnEntity(a,target) self.cast=a; self.castTarget=target end
    return h
end
GetUnitToLocationDistance=function(h,p) assert(p~=nil,'Void vector'); return math.abs(h.x-p.x) end
GetUnitToUnitDistance=function(a,b) return math.abs(a.x-b.x) end
local bot,enemy,ally,allies,enemies,tower
local J={IsValidHero=function(h) return h.hp>0 end,IsSuspiciousIllusion=function() return false end}
J.GetLocationToLocationDistance=function(a,b) return math.abs(a.x-b.x) end
J.GetNearbyHeroes=function() return enemies end
J.GetModifierTime=function(h) return h.remaining or 2 end
J.IsTryingtoUseAbility=function(h) return h.channel or h.casting or h.using end
J.IsAttacking=function(h) return h.attacking end
GetUnitList=function(kind) return kind==UNIT_LIST_ENEMY_HEROES and enemies or allies end
GetTower=function(_,index) return index==0 and tower or nil end
GetBot=function() return bot end
GetLaneFrontLocation=function() return loc(4000) end
require('bots/Customize/shai').BehaviorTrace=false
local Runtime=require('bots/FunLib/shai_runtime')
local Travel=require('bots/FunLib/shai_tactical_travel')
local function reset()
    now=now+10
    bot=hero(1,0); enemy=hero(8,4000,24); ally=hero(2,0)
    allies,enemies,tower={bot,ally},{enemy},nil
end
reset(); assert(not Travel.SafeDestination(bot,J,loc(4000)),'Full HP alone cannot justify landing beside a vastly stronger enemy')
assert(Travel.PrepareTeleport(bot,J,loc(4000))==nil,'Unsafe TP is rejected before the scroll is spent')
ally.x=4200; assert(Travel.PrepareTeleport(bot,J,loc(4000))~=nil,'An actual local healthy helper can permit the landing')
bot.mods.modifier_teleporting=true; bot.channel=true; ally.x=0; now=now+1
assert(Travel.RecheckTeleport(bot,J) and bot.stopped,'Loss of actual landing support cancels an unsafe channel')
reset(); enemies={}; assert(Travel.PrepareTeleport(bot,J,loc(4000)))
bot.mods.modifier_teleporting=true; bot.channel=true
assert(not Travel.RecheckTeleport(bot,J) and bot.actions==0,'Safe channels are left alone')
enemy.visible=false; enemies={enemy}; assert(Travel.SafeDestination(bot,J,loc(4000)),'No enemy HP/position/inventory reads through fog')
reset(); enemy.x=1500; tower=hero(0,1600); tower.visible=true
assert(Travel.PrepareTeleport(bot,J,loc(3000))==nil,'Safe cursor location does not conceal an unsafe nearby TP structure')
reset(); enemy.level=12; enemy.dps=5; bot.mods.modifier_item_shadow_amulet_fade=true
assert(Travel.ThinkFade(bot,J) and bot.clears==1 and not bot.stopped,'Safe fade stops the preceding move once')
assert(Travel.ThinkFade(bot,J) and bot.clears==1,'Fade hold does not keep clearing actions')
bot.mods.modifier_item_dustofappearance=true
assert(not Travel.ThinkFade(bot,J),'Confirmed detection releases the hold')
bot.mods.modifier_item_dustofappearance=nil; bot.hp=100; enemy.dps=200
assert(not Travel.HoldFade(bot,J),'Do not stand through lethal damage until invisibility')
bot.hp=2000; enemy.dps=5; bot.projectiles={{is_attack=false}}
assert(not Travel.HoldFade(bot,J),'Unknown incoming spell cannot be assumed harmless')
bot.projectiles={}; bot.channel=true
assert(not Travel.ThinkFade(bot,J) and bot.clears==1,'Amulet cannot interrupt another channel')
bot.channel=false; bot.mods.modifier_item_shadow_amulet_fade=nil
assert(not Travel.HoldFade(bot,J) and bot.shaiFadeHeld==nil,'Fade reservation ends with its modifier')
reset(); enemies={}; local idle=dofile('.tools/lua/shai-idle-helper.lua')(J,Runtime)
assert(not idle()); now=now+3.1; assert(idle() and bot.clears==1)
now=now+0.1; assert(not idle() and bot.clears==1,'Watchdog updates its timestamp before early return')
now=now+4; bot.queue=2; assert(not idle() and bot.clears==1,'Queued cast sequence is not idle')
bot.queue=0; now=now+4; bot.shaiTacticalUntil=now+0.5
assert(not idle() and bot.clears==1,'Bounded rally intention is not idle')
now=now+4; bot.mods.modifier_item_shadow_amulet_fade=true
assert(not idle() and bot.clears==1,'Fade is not idle')
bot.mods={}; bot.shaiTacticalUntil=nil; now=now+4; bot.channel=true
assert(not idle() and bot.clears==1,'Channel is not idle')
bot.channel=false; now=now+4; GetLaneFrontLocation=function() return nil end
assert(not idle() and bot.clears==1,'Invalid recovery destination does not cancel a valid current order')
reset(); local cast=dofile('.tools/lua/shai-item-cast.lua')(bot,J,Travel,Runtime)
local scroll={GetName=function() return 'item_tpscroll' end}
assert(not cast(scroll,nil,'ground') and bot.actions==0,'Actual item dispatcher rejects a void ground target')
assert(not cast(scroll,loc(4000),'ground') and bot.actions==0,'Actual scroll dispatcher consults landing safety')
enemies={}; assert(cast(scroll,loc(4000),'ground') and bot.cast==scroll,'Actual safe scroll still dispatches')
assert(not Runtime.Location(bot,'test.invalid',12),'Invalid vector type fails safely')
local a,b,c=Runtime.Call(bot,'test.multi',function() return 1,nil,3 end,0)
assert(a==1 and b==nil and c==3,'Runtime boundary preserves multiple return values and nil holes')
assert(Runtime.Call(bot,'test.error',function() error({reason='bad'}) end,42)==42,'Non-string errors cannot break error reporting')
local survival=require('bots/FunLib/shai_cast_survival')
assert(not survival.Allow(bot,J,{},nil,'golem'),'Nil golem location is rejected before invoking vector APIs')
print('PASS: actual TP dispatcher, safe/unsafe/new threats, fog, safe fade/release/projectiles, watchdog early return and reservations, invalid locations and runtime diagnostics')
