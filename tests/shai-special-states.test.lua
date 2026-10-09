package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
UNIT_LIST_ENEMY_HEROES,UNIT_LIST_ALLIED_HEROES,UNIT_LIST_ALL=2,3,4
BOT_MODE_NONE,BOT_MODE_RETREAT=0,1
DAMAGE_TYPE_ALL,DAMAGE_TYPE_MAGICAL,DAMAGE_TYPE_PHYSICAL=0,1,2
GAME_STATE_GAME_IN_PROGRESS=7
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=900
DotaTime=function() return now end
GetGameState=function() return 7 end
GetTeam=function() return 2 end
GetTower=function() return nil end
GetTeamMember=function() return nil end
IsLocationPassable=function() return true end
local enemies,bot
GetUnitList=function(kind) return kind==UNIT_LIST_ENEMY_HEROES and enemies or {} end
GetUnitToUnitDistance=function(a,b) return math.abs(a.x-b.x) end
GetUnitToLocationDistance=function(a,b) return math.abs(a.x-b.x) end
local function unit(x)
    local h={x=x,visible=true,mods={},hp=500,maxhp=1000,items={},name='npc_dota_hero_skeleton_king',attackRange=150}
    function h:IsNull() return false end
    function h:CanBeSeen() return self.visible end
    function h:IsAlive() assert(self.visible); return self.hp>0 end
    function h:IsInvulnerable() return self.invulnerable or false end
    function h:IsAttackImmune() assert(self.visible); return self.attackImmune or false end
    function h:IsMagicImmune() assert(self.visible); return self.magicImmune or false end
    function h:IsSilenced() return self.silenced or false end
    function h:IsRooted() return self.rooted or false end
    function h:IsMuted() return self.muted or false end
    function h:IsInvisible() return self.invisible or false end
    function h:IsChanneling() return self.channel or false end
    function h:IsHero() return true end
    function h:IsIllusion() return false end
    function h:IsHexed() return false end
    function h:IsStunned() return false end
    function h:IsCastingAbility() return false end
    function h:IsUsingAbility() return false end
    function h:IsNightmared() return false end
    function h:HasModifier(m) return self.mods[m] or false end
    function h:GetUnitName() assert(self.visible); return self.name end
    function h:GetPlayerID() return 1 end
    function h:GetTeam() return 2 end
    function h:GetLocation() assert(self.visible,'Hidden location'); return Vector(self.x,0) end
    function h:GetHealth() assert(self.visible); return self.hp end
    function h:GetMaxHealth() return self.maxhp end
    function h:GetAttackRange() return self.attackRange end
    function h:GetCurrentMovementSpeed() return 300 end
    function h:GetAttackPoint() return 0.3 end
    function h:GetAttackTarget() return self.attack end
    function h:GetItemInSlot(i) assert(self.visible,'Hidden inventory'); return self.items[i] end
    function h:GetAbilityByName(n) return n=='skeleton_king_hellfire_blast' and self.q or nil end
    function h:GetNearbyTowers() return self.towers or {} end
    function h:GetNearbyLaneCreeps() return self.creeps or {} end
    function h:GetNearbyNeutralCreeps() return {} end
    function h:GetIncomingTrackingProjectiles() return self.projectiles or {} end
    function h:WasRecentlyDamagedByAnyHero() return self.damaged or false end
    function h:SetTarget(t) self.target=t end
    function h:Action_AttackUnit(t) self.action='attack'; self.attack=t; self.attacks=(self.attacks or 0)+1 end
    function h:Action_UseAbilityOnEntity(a,t) self.action='cast'; self.cast=a; self.target=t; self.casts=(self.casts or 0)+1 end
    function h:Action_UseAbilityOnLocation(a,t) self.action='tp'; self.destination=t; self.casts=(self.casts or 0)+1 end
    function h:Action_MoveToLocation(t) self.action='move'; self.destination=t end
    function h:Action_ClearActions() self.action='clear' end
    return h
end
local J={CanNotUseAction=function(h) return h.busy or h.channel or false end,
    CanNotUseAbility=function(h) return h.busy or h.silenced or false end,
    IsValidHero=function(h) return h~=nil end,IsSuspiciousIllusion=function() return false end,
    IsDisabled=function(h) return h.disabled or false end,GetRemainStunTime=function(h) return h.stunTime or 0 end,
    CanCastOnNonMagicImmune=function(h) return not h:IsMagicImmune() end,
    CanCastOnTargetAdvanced=function(h) return not h.blocked end,
    GetModifierTime=function(h,m) return h:HasModifier(m) and (h.remaining or 6) or 0 end,
    GetTeamFountain=function() return Vector(-6000,0) end,
    IsRetreating=function(h) return h.retreat or false end}
local farm={GetThreat=function(h) return h.threat end}
local finish={GetPlan=function(h) return h.finish end,IsCommitting=function(h) return h.committing or false end}
package.loaded['bots/FunLib/shai_farm_safety']=farm
package.loaded['bots/FunLib/shai_combat_finish']=finish
require('bots/Customize/shai').BehaviorTrace=false
local Wraith=require('bots/FunLib/shai_wraith_form')
local Invis=require('bots/FunLib/shai_invisible_escape')
local function reset()
    now=now+5; bot=unit(0); bot.frameProcessTime=0.01; enemies={unit(200)}
    bot.lastAbilityFrameProcessTime,bot.lastItemFrameProcessTime=now-1,now-1
    bot.mods[Wraith.Modifier]=true; bot.hp=1; bot.invulnerable=true
end
local q={GetName=function() return 'skeleton_king_hellfire_blast' end,IsFullyCastable=function() return true end,
    IsHidden=function() return false end,GetCastPoint=function() return 0.2 end,GetCastRange=function() return 600 end,
    GetSpecialValueFloat=function() return 900 end}
reset(); bot.q=q
assert(Wraith.Think(bot,J) and bot.action=='cast','Ghost at 1 HP uses ready stun, no survival/mana reserve')
assert(Wraith.Think(bot,J) and bot.casts==1,'Cast-point lease prevents replacing or repeating the stun')
now=now+0.5; assert(Wraith.Think(bot,J) and bot.action=='attack','Damage follows stun without retreat')
assert(Wraith.Think(bot,J) and bot.attacks==1,'Continuing attack is not restarted each frame')
reset(); bot.q=q; enemies[1].disabled=true; enemies[1].stunTime=4
assert(Wraith.Think(bot,J) and bot.action=='attack' and not bot.casts,'Long allied disable keeps damage flowing without wasted stun')
reset(); bot.q=q; enemies[1].magicImmune=true
assert(Wraith.Think(bot,J) and bot.action=='attack' and not bot.casts,'Magic immunity prevents stun but permits physical damage')
reset(); bot.q=q; enemies[1].attackImmune=true
assert(Wraith.Think(bot,J) and bot.action=='cast','Physical attack immunity still permits a legal ghost stun')
reset(); bot.q=q; bot.silenced=true
assert(Wraith.Think(bot,J) and bot.action=='attack','Silence does not prevent the ghost attacking')
reset(); bot.remaining=0.3; enemies[1].x=1200
assert(Wraith.GetPlan(bot,J)==nil,'Do not waste last instant chasing an unreachable target')
reset(); enemies[1].visible=false; bot.creeps={unit(100)}
assert(Wraith.Think(bot,J) and bot.target==bot.creeps[1],'No hidden target stats; reachable creep gets remaining damage')
reset(); bot.remaining=0
assert(Wraith.GetPlan(bot,J)==nil and not Wraith.Think(bot,J),'Unknown/expired modifier duration cannot lock ordinary actions')
reset(); bot.busy=true
assert(Wraith.Think(bot,J) and bot.action==nil,'An ongoing queue/channel/disable is preserved')
local function invisible()
    reset(); bot.mods={modifier_item_glimmer_cape=true}; bot.name='npc_dota_hero_witch_doctor'
    bot.hp=500; bot.invulnerable=false; bot.invisible=true; bot.retreat=true
end
invisible(); assert(Invis.Think(bot,J) and bot.action=='move' and bot.destination.x<0,'Completed Glimmer escapes without offensive reveal')
invisible(); bot.mods.modifier_item_dustofappearance=true
assert(not Invis.Think(bot,J) and bot.action==nil,'Detection restores native saves and control instead of blindly preserving invis')
invisible(); enemies[1].items[0]={GetName=function() return 'item_gem' end}
assert(not Invis.Think(bot,J),'Visible gem releases the hold')
enemies[1].visible=false
assert(Invis.Think(bot,J),'Hidden inventory/location is never read to infer detection')
invisible(); bot.towers={unit(300)}
assert(not Invis.Think(bot,J),'Visible enemy tower releases invis guard')
invisible(); bot.channel=true
assert(not Invis.Think(bot,J) and bot.action==nil,'Existing TP/channel is left untouched')
invisible(); bot.finish={}; assert(not Invis.Think(bot,J),'A selected concrete finishing opportunity may reveal')
invisible(); bot.shaiGankPlan={phase='engage',created=now,updated=now,expires=now+3,members={bot}}
assert(not Invis.Think(bot,J),'Current committed group may deliberately reveal')
bot.shaiGankPlan.phase='gather'; assert(Invis.Think(bot,J),'An unready gathering plan does not cause a lone reveal')
invisible(); bot.retreat=false; bot.hp=1000
assert(not Invis.Think(bot,J),'Healthy offensive windwalk is unaffected')
invisible(); enemies={}; bot.items[15]={GetName=function() return 'item_tpscroll' end,IsFullyCastable=function() return true end}
assert(Invis.Think(bot,J) and bot.action=='tp' and bot.destination.x==-6000,'Sufficient invis, no nearby enemy/projectile and safe home permit TP')
assert(Invis.Think(bot,J) and bot.casts==1,'TP dispatch reservation prevents repeating scroll before channel starts')
invisible(); enemies={}; bot.items[15]={GetName=function() return 'item_tpscroll' end,IsFullyCastable=function() return true end}
bot.projectiles={{is_attack=false}}
assert(Invis.Think(bot,J) and bot.action=='move' and not bot.casts,'Incoming spell forbids speculative TP but keeps movement')
bot.projectiles={}; bot.remaining=2
assert(Invis.Think(bot,J) and not bot.casts,'Short remaining invis cannot justify TP')
invisible(); bot.shaiJumpRelease={created=now,untilTime=now+0.4}
assert(Invis.Think(bot,J) and bot.action==nil,'Invis route does not overwrite a released Zeus jump')
-- Actual callback bodies: special-state dispatch must precede ordinary spells/items.
reset(); bot.q=q
local native=0
local cb=dofile('.tools/lua/shai-ability-callback.lua')(bot,J,{TryControl=function() return false end,HoldOffense=function() return false end},
    {Observe=function() end},{BehaviorTrace=false},{ThinkLess=0},{SkillsComplement=function() native=native+1 end},function() return false end,true,bot.name,{}, {},{})
cb(); assert(bot.action=='cast' and native==0,'Actual ability callback permits active invulnerable WK ghost and dispatches its stun')
local item=dofile('.tools/lua/shai-item-callback.lua')(bot,J,{ThinkLess=0},function() return false end,finish,function() native=native+1 end,bot.name)
item(); assert(native==0,'Actual item callback does not spend temporary ghost life on survival TP/items')
invisible()
item=dofile('.tools/lua/shai-item-callback.lua')(bot,J,{ThinkLess=0},function() return false end,finish,function() native=native+1 end,bot.name)
item(); assert(bot.action=='move' and native==0,'Actual item callback preserves completed invisible escape')
reset()
local guards={HasQueuedAction=function() return false end}
dofile('.tools/lua/shai-action-guards.lua')(guards)
assert(not guards.CanNotUseAction(bot) and not guards.CanNotUseAbility(bot),'Actual J guards let the temporary invulnerable ghost act')
bot.silenced=true
assert(not guards.CanNotUseAction(bot) and guards.CanNotUseAbility(bot),'Actual guard still respects silence')
bot.silenced=false; bot.mods={}
assert(guards.CanNotUseAction(bot) and guards.CanNotUseAbility(bot),'Ordinary invulnerability is not treated as an active ghost')
bot.mods[Wraith.Modifier]=true; bot.hp=0
assert(guards.CanNotUseAction(bot),'Dead units remain blocked despite a stale ghost modifier')
-- Actual team-roam selection and Think, rather than just generic callbacks.
reset()
GetBot=function() return bot end
package.loaded['bots/FunLib/jmz_func']=J
for _,name in ipairs({'utils','enemy_role_estimation','localization','aba_item','aba_role'}) do
    package.loaded['bots/FunLib/'..name]={}
end
package.loaded['bots/Customize/general']={Enable=true,ThinkLess=0}
package.loaded['bots/FunLib/shai_team_gank']={}
package.loaded['bots/FunLib/shai_defense']={}
package.loaded['bots/FunLib/shai_tormentor']={}
local realDofile=dofile
dofile=function(path)
    if path=='bots/FunLib/aba_special_units' then return {} end
    return realDofile(path)
end
local roam=dofile('bots/mode_team_roam_generic.lua')
assert(roam and roam.GetDesire()==1.07,'Actual roam loads for active invulnerable WK and prioritizes his temporary attack')
roam.Think(); assert(bot.action=='attack','Actual roam dispatches damage before native retreat/optional orders')
invisible(); roam=dofile('bots/mode_team_roam_generic.lua')
assert(roam.GetDesire()==1.06,'Actual roam prioritizes invisible escape')
roam.Think(); assert(bot.action=='move','Actual roam cannot replace invisible escape with ordinary roam attacks')
print('PASS: temporary WK lifetime/control/damage/expiry, completed invis detection/routes/TP/group exceptions, actual ability/item callbacks')
