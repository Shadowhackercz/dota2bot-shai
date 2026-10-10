package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now=1000
DotaTime=function() return now end
local bot,blocked,concern,threat
local no=function() return false end
local function reset()
    now=now+50; blocked=no; concern=no; threat=nil
    bot={location=Vector(1000,0),hp=0.25,mods={}}
    function bot:IsAlive() return not self.dead end
    function bot:IsInvulnerable() return self.invulnerable or false end
    function bot:HasModifier(m) return self.mods[m] or false end
    function bot:GetLocation() return self.location end
    function bot:GetUnitName() return 'npc_dota_hero_skeleton_king' end
    function bot:GetPlayerID() return 1 end
    function bot:GetNearbyTowers() return self.towers or {} end
    function bot:IsCastingAbility() return self.cast or false end
    function bot:IsUsingAbility() return self.cast or false end
    function bot:SetTarget(t) self.target=t end
    function bot:Action_MoveToLocation(p) self.destination=p; self.action='move' end
    function bot:IsHero() return true end
    function bot:IsIllusion() return false end
end
IsLocationPassable=function(p) return not blocked(p) end
GetUnitToLocationDistance=function(h,p) return math.sqrt((h:GetLocation().x-p.x)^2+(h:GetLocation().y-p.y)^2) end
local J={GetHP=function(h) return h.hp end,GetTeamFountain=function() return Vector(0,0) end,
    CanNotUseAction=function(h) return h.busy or false end}
local farm={LocationThreats=function() return {} end,GetLocationConcern=function(_,_,p) return concern(p) and {} or nil end,
    GetThreat=function() return threat end,InterruptFarm=function(h) h.action='escape'; return true end}
package.loaded['bots/FunLib/shai_farm_safety']=farm
local escape={HoldingJump=function(h) return h.jump or false end,HoldingAlignment=function(h) return h.align or false end}
package.loaded['bots/FunLib/shai_escape_route']=escape
require('bots/Customize/shai').BehaviorTrace=false
local Recovery=require('bots/FunLib/shai_recovery')
reset(); assert(Recovery.GetDesire(bot,J)==1.03)
assert(Recovery.Think(bot,J) and bot.action=='move' and bot.destination.x<bot.location.x,'Wounded live WK actually walks toward home')
bot.hp=0.55; assert(Recovery.GetPlan(bot,J),'HP hysteresis prevents immediate return to roam')
bot.hp=0.8; assert(Recovery.GetPlan(bot,J)==nil,'Recovered member is released')
reset(); bot.mods.modifier_skeleton_king_reincarnation_scepter_active=true
assert(Recovery.GetPlan(bot,J)==nil,'Temporary ghost keeps offense, never recovery')
bot.mods={}; assert(Recovery.GetPlan(bot,J),'Same entity becomes eligible once alive outside ghost form')
reset(); bot.location.x=2300; assert(Recovery.GetPlan(bot,J)==nil,'No map-wide recovery takeover')
reset(); bot.hp=0.5; assert(Recovery.GetPlan(bot,J)==nil,'Healthy member does not enter recovery')
reset(); assert(Recovery.GetPlan(bot,J)); now=now+12
assert(Recovery.GetPlan(bot,J)==nil and Recovery.GetDesire(bot,J)==nil,'No progress expires and has bounded retry')
now=now+3; assert(Recovery.GetPlan(bot,J)); now=now+10; bot.location.x=900
assert(Recovery.GetPlan(bot,J)); now=now+5; assert(Recovery.GetPlan(bot,J),'Real homeward progress renews short attempt')
now=bot.shaiRecovery.created+45; assert(Recovery.GetPlan(bot,J)==nil,'Absolute timeout survives tiny progress')
reset(); assert(Recovery.GetPlan(bot,J)); now=now-1; assert(Recovery.GetPlan(bot,J),'Clock rollback resets attempt')
bot.dead=true; assert(Recovery.GetPlan(bot,J)==nil and bot.shaiRecovery==nil,'Death clears attempt')
reset(); blocked=function(p) return p.x>500 and p.x<800 and math.abs(p.y)<50 end
assert(Recovery.Think(bot,J) and math.abs(bot.destination.y)>50,'Samples detect middle obstacle and allow side approach')
reset(); blocked=function() return true end
assert(not Recovery.Think(bot,J) and bot.action==nil and Recovery.GetDesire(bot,J)==nil,'No safe step releases controller, not infinite clear loop')
reset(); concern=function(p) return p.x<400 end
assert(Recovery.Think(bot,J) and bot.destination.x>=400,'Shorter home approach avoids destination threat')
reset(); local tower={IsNull=no,CanBeSeen=function() return true end,IsAlive=function() return true end,
    GetLocation=function() return Vector(350,0) end,GetAttackRange=function() return 450 end}
bot.towers={tower}; assert(Recovery.Think(bot,J) and bot.destination.x>350,'Tower footprint is not crossed blindly')
tower.CanBeSeen=no; tower.GetLocation=function() error('Hidden tower location') end
assert(Recovery.Think(bot,J),'Hidden tower does not disclose stats')
reset(); threat={}; assert(Recovery.Think(bot,J) and bot.action=='escape','Immediate threat uses existing escape instead of straight home route')
reset(); bot.busy=true; assert(Recovery.Think(bot,J) and bot.action==nil,'Queued/channel action is preserved')
bot.busy=false; bot.cast=true; assert(Recovery.Think(bot,J) and bot.action==nil)
bot.cast=false; bot.jump=true; assert(Recovery.Think(bot,J) and bot.action==nil)
reset(); bot.mods.modifier_fountain_aura_buff=true; assert(Recovery.GetPlan(bot,J)); now=now+10; bot.hp=0.35
assert(Recovery.GetPlan(bot,J)); now=now+5; assert(Recovery.GetPlan(bot,J),'Actual fountain healing counts as recovery progress')

-- Execute actual team-roam callbacks with unrelated controllers isolated.
reset()
GetBot=function() return bot end; GetTeam=function() return 2 end
local finish={GetPlan=function() return bot.finish end,IsCommitting=function() return bot.committing or false end,
    TryAction=function(h) if h.finish then h.action='finish'; return true end return false end}
local defense={GetDesire=function() return bot.defense end,Think=function(h) h.action='defense'; return true end}
local travel={HoldFade=no,ThinkFade=no}
local wraith={GetPlan=function(h) return h.mods.modifier_skeleton_king_reincarnation_scepter_active and {} or nil end,
    Think=function(h) if h.mods.modifier_skeleton_king_reincarnation_scepter_active then h.action='ghost'; return true end return false end}
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/FunLib/utils']={SetFrameProcessTime=function() end}
package.loaded['bots/FunLib/enemy_role_estimation']={UpdateEnemyHeroPositions=function() end}
package.loaded['bots/FunLib/localization']={}
package.loaded['bots/Customize/general']={}
package.loaded['bots/FunLib/shai_team_gank']={GetDesire=function() error('Wounded recovery must precede new gank') end}
package.loaded['bots/FunLib/shai_combat_finish']=finish
package.loaded['bots/FunLib/shai_defense']=defense
package.loaded['bots/FunLib/shai_tactical_travel']=travel
package.loaded['bots/FunLib/shai_wraith_form']=wraith
package.loaded['bots/FunLib/shai_invisible_escape']={GetPlan=function() return nil end,Think=no}
package.loaded['bots/FunLib/shai_tormentor']={Probe=function() end,OnEnd=function() end}
package.loaded['bots/FunLib/aba_item']={}
package.loaded['bots/FunLib/aba_role']={}
J.GetMostPushLaneDesire=function() return 0 end; J.GetMostDefendLaneDesire=J.GetMostPushLaneDesire
J.CheckBotIdleState=no; J.Role={IsPvNMode=no}; J.IsCore=no; J.IsInLaningPhase=function() return true end
local realDofile=dofile
dofile=function(path) if path=='bots/FunLib/aba_special_units' then return {GetTombstoneDesire=function() return 0 end} end return realDofile(path) end
local roam=dofile('bots/mode_team_roam_generic.lua')
assert(roam.GetDesire()==1.03,'Actual roam bypasses lane soft cap for wounded recovery')
roam.Think(); assert(bot.action=='move','Actual roam Think issues recovery action')
bot.hp=0.55; bot.defense=0.99
assert(roam.GetDesire()==1.03,'Passive defense hold does not interrupt active healing hysteresis')
bot.defense=1.02; assert(roam.GetDesire()==1.02,'Viable group defense preserves its priority over recovery')
bot.defense=nil; assert(roam.GetDesire()==1.03)
bot.finish={}; bot.action=nil; roam.Think(); assert(bot.action=='finish','Newly available finish wins during recovery')
bot.finish=nil; bot.defense=1.1; roam.Think(); assert(bot.action=='defense','New Ancient emergency wins')
bot.defense=nil; bot.mods.modifier_skeleton_king_reincarnation_scepter_active=true
assert(roam.GetDesire()==1.07); roam.Think(); assert(bot.action=='ghost','Actual roam preserves ghost offense')
print('PASS: bounded fountain recovery, ghost exclusion, safe short approaches, healing and actual roam arbitration')
