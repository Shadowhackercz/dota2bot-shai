package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_DESIRE_NONE,BOT_MODE_LANING,BOT_MODE_RETREAT,BOT_MODE_TEAM_ROAM,BOT_MODE_SIDE_SHOP=0,1,2,3,4
BOT_MODE_NONE,BOT_MODE_ROSHAN=0,5
GAME_STATE_GAME_IN_PROGRESS=7
local now=1000
DotaTime,GameTime=function() return now end,function() return now end
GetTeam=function() return 2 end
GetGameState=function() return GAME_STATE_GAME_IN_PROGRESS end
RemapValClamped=function() return 0.98 end
GetUnitToUnitDistance=function() return 100 end
local bot={frameProcessTime=0.1,mode=BOT_MODE_TEAM_ROAM}
function bot:GetUnitName() return 'npc_dota_hero_lion' end
function bot:GetPlayerID() return 1 end
function bot:IsInvulnerable() return false end
function bot:IsHero() return true end
function bot:IsAlive() return not self.dead end
function bot:IsIllusion() return false end
function bot:HasModifier() return false end
function bot:GetActiveMode() return self.mode end
function bot:GetCurrentActionType() return 0 end
function bot:GetLocation() return {x=0,y=0,z=0} end
function bot:SetTarget(target) self.target=target end
function bot:WasRecentlyDamagedByAnyHero() return self.damaged or false end
GetBot=function() return bot end
local no=function() return false end
local J={Role={IsPvNMode=no},Utils={IsValidUnit=function() return true end}}
J.IsCore,J.CheckBotIdleState,J.CanNotUseAction,J.IsModeTurbo=no,no,no,no
J.IsInLaningPhase,J.IsPushing=no,no
J.IsRetreating=function() return bot.retreat or false end
J.GetMostPushLaneDesire,J.GetMostDefendLaneDesire=function() return 2 end,function() return 2 end
J.GetHP=function() return 1 end
J.IsValid,J.IsValidHero,J.CanBeAttacked=function(h) return h~=nil end,function(h) return h~=nil end,function() return true end
J.GetAlliesNearLoc,J.GetEnemiesNearLoc=function() return {} end,function() return {} end
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/Customize/general']={Enable=true,ThinkLess=1}
package.loaded['bots/FunLib/localization']={}
-- Loading the real controller must not overwrite the engine's other callbacks.
GetDesire,GetDesireHelper,Think=function() return 1 end,function() return 2 end,function() return 3 end
local savedDesire,savedHelper,savedThink=GetDesire,GetDesireHelper,Think
local actual=require('bots/FunLib/shai_tormentor')
assert(actual.GetDesire and actual.Think and GetDesire==savedDesire and GetDesireHelper==savedHelper and Think==savedThink)
local desire,actions,ended=0.8,0,0
local controller={Probe=function() end,GetDesire=function() return desire end,Think=function() actions=actions+1 end,
    OnEnd=function() ended=ended+1; bot.shaiTormentorActiveUntil=nil end}
package.loaded['bots/FunLib/shai_tormentor']=controller
package.loaded['bots/FunLib/utils']={SetFrameProcessTime=function() end}
package.loaded['bots/FunLib/enemy_role_estimation']={UpdateEnemyHeroPositions=function() end}
package.loaded['bots/FunLib/aba_item'],package.loaded['bots/FunLib/aba_role']={},{}
local finish,defense,gank=false,nil,nil
package.loaded['bots/FunLib/shai_combat_finish']={GetPlan=function() return finish and {} or nil end,TryAction=function() end}
package.loaded['bots/FunLib/shai_defense']={GetDesire=function() return defense end,Think=function() end}
package.loaded['bots/FunLib/shai_team_gank']={GetDesire=function() return gank end,Think=function() return true end}
package.loaded['bots/FunLib/shai_tactical_travel']={HoldFade=no,ThinkFade=no}
local threat,escapeActions=nil,0
package.loaded['bots/FunLib/shai_farm_safety']={GetThreat=function() return threat end,
    InterruptFarm=function() escapeActions=escapeActions+1; bot.target=nil; return threat~=nil end}
local realDofile=dofile
dofile=function(path)
    if path=='bots/FunLib/aba_special_units' then return {GetTombstoneDesire=function() return 0 end,GetDesire=function() return 0 end} end
    return realDofile(path)
end
local roam=dofile('bots/mode_team_roam_generic.lua')
local itemActions=0
ItemOpsDesire=function() end
ItemOpsThink=function() itemActions=itemActions+1 end
roam.ConsiderHelpWhenCoreIsTargeted=function() return {},true end
local commands=require('bots/FunLib/shai_objective_commands')
dofile('.tools/lua/shai-objective-helpers.lua')(J,commands)
assert(GetDesire()==0.8 and bot.shaiTormentorActiveUntil==nil,'Evaluating a candidate does not claim active objective combat')
roam.Think()
assert(actions==1 and itemActions==0 and J.IsDoingTormentor(bot),'Selected team-roam routes objective actions and hero/item helpers')
now=now+1
assert(not J.IsDoingTormentor(bot),'Objective lease expires without a fresh Think')
GetDesire(); roam.Think(); OnEnd()
assert(not J.IsDoingTormentor(bot) and ended==1,'Leaving team roam clears the objective lease')
finish=true; assert(GetDesire()==1.05,'Immediate secured finish takes priority'); finish=false
defense=0.99; assert(GetDesire()==0.99,'Base defense takes priority'); defense=nil
gank=0.97; assert(GetDesire()==0.97,'An active group gank takes priority'); gank=nil
assert(GetDesire()==0.8)
bot.damaged=true; local before=actions; roam.Think()
assert(actions==before and not J.IsDoingTormentor(bot),'New hero damage cancels a stale voluntary objective before movement')
assert(GetDesire()==0.98,'Do not recruit to Tormentor while threatened'); bot.damaged=false
bot.retreat=true; assert(GetDesire()==0.98,'Retreat takes priority'); bot.retreat=false
assert(GetDesire()==0.8); desire=0; before=actions; roam.Think()
assert(actions==before,'A now-rejected objective cannot execute an old Think')
desire=0.8; GetDesire(); roam.Think()
bot.shaiTormentorVeto={issued=now,untilTime=now+60}
assert(not J.IsDoingTormentor(bot),'The shared hero helper honors veto in team-roam as well')
J.GetProperTarget=function() return nil end
J.GetTeamFountain=function() return bot:GetLocation() end
bot.Action_MoveToLocation=function() bot.released=true end
assert(commands.ReleaseObjective(bot,J) and bot.released,'The generic objective release detects active team-roam Tormentor')
bot.shaiTormentorVeto=nil

-- Early rune/courier/ward distractions cannot win against concrete danger.
now=150; threat={}; bot.shaiTormentorActiveUntil=nil
assert(GetDesire()==1.04,'Early danger bypasses the optional target branches')
local savedActions,itemBefore=actions,itemActions
roam.Think()
assert(escapeActions==1 and actions==savedActions and itemActions==itemBefore and bot.target==nil and bot.shaiEscapeUntil>now)
finish=true; assert(GetDesire()==1.05 and bot.shaiEscapeUntil==nil,'A secured short lethal finish may still win'); finish=false
defense=0.99; assert(GetDesire()==0.99,'A valid team defense remains available'); defense=nil
gank=0.97; assert(GetDesire()==0.97,'A viable coordinated gank remains available'); gank=nil
GetDesire(); threat=nil; itemBefore=itemActions; roam.Think()
assert(itemActions==itemBefore and bot.shaiEscapeUntil==nil,'Losing the threat does not revive a stale optional order in Think')
now=1000; GetDesire(); roam.Think(); OnEnd()
assert(bot.shaiEscapeUntil==nil,'Leaving the mode releases escape classification')

-- Glyph must be invoked from a known-running callback before dead-hero and
-- offensive guards, and before a failing buyback implementation.
local glyphCalls=0
local glyph=function() glyphCalls=glyphCalls+1 end
local callback=dofile('.tools/lua/shai-ability-callback.lua')(bot,J,
    {TryControl=no,HoldOffense=no},{Observe=function() end},{BehaviorTrace=false},{ThinkLess=0},nil,
    no,true,bot:GetUnitName(),commands,{},nil,nil,nil,nil,nil,nil,glyph)
bot.dead=true
callback(); assert(glyphCalls==1,'Even a dead hero receives the fortification callback')
bot.dead=false
J.IsNoAbilityIllution=no
now=now+1; callback(); assert(glyphCalls==2,'The regular live-hero callback also invokes glyph')
local buyback=dofile('.tools/lua/shai-buyback-callback.lua')(bot,no,glyph,function() error('buyback failure') end)
bot.lastBuybackFrameProcessTime=now-3
assert(not pcall(buyback) and glyphCalls==3,'Buyback failure cannot skip the preceding glyph check')
print('PASS: shared Tormentor integration/priority/lease/veto, isolated globals and glyph through actual ability/buyback callbacks')
