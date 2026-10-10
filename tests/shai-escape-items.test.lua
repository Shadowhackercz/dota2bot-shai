package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_NONE,BOT_ACTION_DESIRE_NONE=0,0
DAMAGE_TYPE_PHYSICAL,DAMAGE_TYPE_MAGICAL=1,2
DAMAGE_TYPE_PURE=3
UNIT_LIST_ENEMY_HEROES=2
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=1000
DotaTime=function() return now end
local bot,enemy,threat
local no=function() return false end
GetUnitList=function() return {enemy} end
GetUnitToUnitDistance=function() return 200 end
GetUnitToLocationDistance=function(h,p) return math.sqrt((h:GetLocation().x-p.x)^2+(h:GetLocation().y-p.y)^2) end
local blocked=no
IsLocationPassable=function(p) return not blocked(p) end
local function item(name,ready)
    return {GetName=function() return name end,GetCastPoint=function() return 0 end,
        GetSpecialValueFloat=function() return 600 end,GetChannelTime=function() return 3 end,ready=ready~=false}
end
local function reset()
    now=now+5; threat={location=Vector(200,0)}; blocked=no
    bot={items={},mods={},hp=1000,shaiEscapeChecked=now,shaiEscapeBlockedAt=now}
    function bot:IsAlive() return not self.dead end
    function bot:IsMuted() return self.muted or false end
    function bot:IsInvisible() return self.invisible or false end
    function bot:IsInvulnerable() return false end
    function bot:IsHero() return true end
    function bot:IsIllusion() return false end
    function bot:IsHexed() return false end
    function bot:IsStunned() return false end
    function bot:IsChanneling() return self.busy or false end
    function bot:IsCastingAbility() return false end
    function bot:IsUsingAbility() return false end
    function bot:NumQueuedActions() return 0 end
    function bot:GetActiveMode() return 0 end
    function bot:GetNearbyTowers() return {} end
    function bot:HasModifier(m) return self.mods[m] or false end
    function bot:GetHealth() return self.hp end
    function bot:GetLocation() return Vector(0,0) end
    function bot:GetFacing() return self.facing or 180 end
    function bot:IsRooted() return self.rooted or false end
    function bot:GetHealthRegen() return 0 end
    function bot:GetIncomingTrackingProjectiles() return self.projectiles or {} end
    function bot:GetItemInSlot(slot) return self.items[slot] end
    function bot:GetUnitName() return 'npc_dota_hero_lion' end
    enemy={visible=true,physical=500,magical=0}
    function enemy:IsNull() return false end
    function enemy:CanBeSeen() return self.visible end
    function enemy:IsAlive() assert(self.visible); return true end
    function enemy:GetLocation() assert(self.visible); return Vector(200,0) end
    function enemy:GetAttackRange() assert(self.visible); return 500 end
    function enemy:GetEstimatedDamageToTarget(_,_,_,kind) assert(self.visible,'Hidden damage read'); return kind==DAMAGE_TYPE_PHYSICAL and self.physical or kind==DAMAGE_TYPE_MAGICAL and self.magical or 0 end
end
local J={CanNotUseAction=function(h) return h.busy or false end,
    GetNearbyHeroes=function() return {enemy} end,IsValidHero=function() return true end,IsSuspiciousIllusion=no,
    CanCastAbility=function(a) return a~=nil and a.ready end,GetProperTarget=function() return nil end,IsItemAvailable=function() return nil end,
    GetTeamFountain=function() return Vector(-6000,0) end,GetRemainStunTime=function(h) return h.stun or 0 end,
    GetModifierTime=function(h) return h.ghostRemaining or 4 end}
local memoryConcern=nil
package.loaded['bots/FunLib/shai_threat_memory']={GetConcern=function() return memoryConcern end}
package.loaded['bots/FunLib/shai_farm_safety']={GetThreat=function() return threat end}
require('bots/Customize/shai').BehaviorTrace=false
local Saves=require('bots/FunLib/shai_escape_items')
local consider={item_ghost=function() return 1,nil,'none' end,
    item_glimmer_cape=function() return 1,bot,'unit' end,
    item_offensive=function() return 1,nil,'none' end}
local uses=0
local function use(a,target,cast) uses=uses+1; bot.used=a:GetName(); return true end
reset(); bot.items[0]=item('item_ghost'); bot.items[5]=item('item_glimmer_cape')
assert(Saves.Try(bot,J,consider,use) and bot.used=='item_ghost','Physical blocked escape prefers approved Ghost independent of slot')
assert(Saves.Holding(bot)); local before=uses
assert(Saves.Try(bot,J,consider,use) and uses==before,'Short release lease prevents repeating item dispatch')
now=now+0.3; assert(not Saves.Holding(bot),'Release hold expires')
reset(); enemy.magical=400; bot.items[0]=item('item_ghost'); bot.items[1]=item('item_glimmer_cape')
assert(Saves.Try(bot,J,consider,use) and bot.used=='item_glimmer_cape','Mixed threat does not prioritize ethereal protection')
reset(); enemy.visible=false; bot.items[0]=item('item_ghost')
assert(not Saves.Try(bot,J,consider,use),'Hidden enemy cannot supply invented physical damage')
reset(); bot.items[0]=item('item_glimmer_cape',false)
assert(not Saves.Try(bot,J,consider,use),'Unavailable item is not requested')
reset(); bot.items[6]=item('item_glimmer_cape')
assert(not Saves.Try(bot,J,consider,use),'Backpack is not an active save')
reset(); bot.items[0]=item('item_glimmer_cape')
local ally={}; consider.item_glimmer_cape=function() return 1,ally,'unit' end
assert(not Saves.Try(bot,J,consider,use),'Ally suggestion cannot replace self-save priority')
consider.item_glimmer_cape=function() return 0,bot,'unit' end
assert(not Saves.Try(bot,J,consider,use),'Existing consideration veto is retained')
consider.item_glimmer_cape=function() return 1,bot,'unit' end
bot.busy=true; assert(not Saves.Try(bot,J,consider,use)); bot.busy=false
bot.muted=true; assert(not Saves.Try(bot,J,consider,use)); bot.muted=false
bot.invisible=true; assert(not Saves.Try(bot,J,consider,use)); bot.invisible=false
bot.mods.modifier_skeleton_king_reincarnation_scepter_active=true; assert(not Saves.Try(bot,J,consider,use)); bot.mods={}
now=now+1; assert(not Saves.Try(bot,J,consider,use),'Old blockage cannot take item priority')
bot.shaiEscapeChecked=now; threat=nil; assert(not Saves.Try(bot,J,consider,use),'No active threat leaves normal items alone')
reset(); bot.items[0]=item('item_glimmer_cape'); assert(Saves.Try(bot,J,consider,use)); now=now-1
assert(not Saves.Holding(bot),'Clock rollback clears save release lease')

reset(); bot.items[0]=item('item_force_staff')
assert(Saves.Try(bot,J,consider,use) and bot.used=='item_force_staff','Safe current facing enables self Force even when native team-roam consideration has no self branch')
reset(); bot.facing=0; bot.items[0]=item('item_force_staff')
assert(not Saves.Try(bot,J,consider,use),'Facing into threat vetoes force')
assert(not Saves.AllowOrdinary(bot,J,bot.items[0],bot),'Legacy self force cannot bypass landing guard')
assert(Saves.AllowOrdinary(bot,J,bot.items[0],{}),'Existing ally force is outside self profile')
reset(); bot.items[0]=item('item_hurricane_pike'); blocked=function(p) return p.x< -100 and p.x> -200 end
assert(not Saves.Try(bot,J,consider,use),'Passable endpoint cannot conceal an unsafe middle segment')
reset(); bot.items[0]=item('item_hurricane_pike'); bot.mods.modifier_bloodseeker_rupture=true
assert(not Saves.Try(bot,J,consider,use),'Rupture forbids this optional movement save')
local function ghostTP()
    reset(); bot.items[15]=item('item_tpscroll'); bot.mods.modifier_ghost_state=true
    bot.shaiGhostEscape={created=now,expires=now+5}; enemy.stun=4
end
ghostTP(); assert(Saves.TryGhostTeleport(bot,J,use) and bot.used=='item_tpscroll' and bot.shaiGhostEscape==nil,'Confirmed protection and full stun window permits Ghost then TP')
assert(not Saves.TryGhostTeleport(bot,J,use),'TP is issued once')
ghostTP(); enemy.stun=1; assert(not Saves.TryGhostTeleport(bot,J,use),'A recently used/short stun is not proof of safe channel')
ghostTP(); bot.ghostRemaining=2; assert(not Saves.TryGhostTeleport(bot,J,use),'Ghost must cover full channel and margin')
ghostTP(); enemy.magical=600; assert(not Saves.TryGhostTeleport(bot,J,use),'Magical survival veto remains under Ghost')
ghostTP(); bot.rooted=true; assert(not Saves.TryGhostTeleport(bot,J,use))
ghostTP(); bot.projectiles={{}}; assert(not Saves.TryGhostTeleport(bot,J,use),'Incoming projectiles veto new channel')
ghostTP(); memoryConcern={}; assert(not Saves.TryGhostTeleport(bot,J,use),'Recent hidden threat vetoes channel'); memoryConcern=nil
ghostTP(); assert(not Saves.TryGhostTeleport(bot,J,function() return false end) and bot.shaiGhostEscape~=nil,'Destination dispatcher rejection never claims successful TP')
-- Restore ordinary item fixture after the combo tests.
reset(); bot.items[0]=item('item_glimmer_cape')

-- Real item complement: rescue beats optional item in slot five only while blocked.
local X={SetStashItemTimeUpdate=function() end,WillBreakInvisible=no,IsItemInStash=no,
    ConsiderItemDesire=consider,SetUseItem=use}
local callback=dofile('.tools/lua/shai-item-complement.lua')(bot,J,X,Saves,require('bots/FunLib/shai_runtime'))
bot.items[5]=item('item_offensive'); now=now+1; bot.shaiEscapeChecked=now
assert(callback()==1 and bot.used=='item_glimmer_cape' and bot.shaiEscapeSave~=nil,'Actual complement dispatches protected self-save before generic item loop')
now=now+1; bot.shaiEscapeBlockedAt=nil; bot.items[0]=nil
local result=callback()
assert(result==6 and bot.used=='item_offensive','Unblocked complement retains existing slot behavior: '..tostring(result)..' / '..tostring(bot.used))
bot.shaiEscapeSave={created=now,expires=now+0.2}; bot.frameProcessTime=0.01; bot.lastItemFrameProcessTime=now-1
local callbackUses=0
local itemCallback=dofile('.tools/lua/shai-item-callback.lua')(bot,J,{ThinkLess=0},no,
    {IsCommitting=no},function() callbackUses=callbackUses+1 end,bot:GetUnitName(),
    {RecheckTeleport=no,ThinkFade=no},{GuardActions=no})
itemCallback(); assert(callbackUses==0,'Actual item callback preserves pending save release before generic items')
ghostTP(); bot.frameProcessTime=0.01; bot.lastItemFrameProcessTime=now-1
local comboCallback=dofile('.tools/lua/shai-item-callback.lua')(bot,J,{ThinkLess=0},no,
    {IsCommitting=no},function() error('Successful Ghost TP must precede generic items') end,bot:GetUnitName(),
    {RecheckTeleport=no,ThinkFade=no},{GuardActions=no},{SetUseItem=use})
comboCallback()
assert(bot.used=='item_tpscroll' and bot.shaiEscapeSave~=nil,'Actual item callback dispatches protected Ghost TP follow-up')
print('PASS: blocked self-save priority, visible damage filter, original vetoes, active slots, leases and actual item complement/callback')
