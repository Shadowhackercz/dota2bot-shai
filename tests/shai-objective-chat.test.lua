package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
GAME_STATE_GAME_IN_PROGRESS,UNIT_LIST_ALLIED_HEROES=7,1
BOT_MODE_ROSHAN,BOT_MODE_SIDE_SHOP,BOT_MODE_NONE=4,5,0
local now,game,replies=1000,7,{}
DotaTime=function() return now end
GetGameState=function() return game end
GetTeamForPlayer=function(id) return id==9 and 3 or 2 end
IsPlayerBot=function(id) return id~=0 and id~=9 end
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
IsLocationPassable=function() return true end
local function Hero(id)
    local h={id=id,alive=true,loc=Vector(100,0),mode=BOT_MODE_NONE}
    function h:IsNull() return false end
    function h:IsHero() return true end
    function h:IsIllusion() return self.illusion or false end
    function h:HasModifier() return false end
    function h:IsAlive() return self.alive end
    function h:GetPlayerID() return self.id end
    function h:GetTeam() return 2 end
    function h:GetLocation() return self.loc end
    function h:GetUnitName() return 'npc_dota_hero_sven' end
    function h:GetActiveMode() return self.mode end
    function h:SetTarget(t) self.target=t end
    function h:Action_MoveToLocation(loc) self.moved=loc; self.actions=(self.actions or 0)+1 end
    function h:ActionImmediate_Chat(message,all) assert(not all); replies[#replies+1]=message end
    return h
end
local human,a,b,dead=Hero(0),Hero(1),Hero(2),Hero(3)
dead.alive=false
local units={human,a,b,dead}
GetUnitList=function() return units end
local roshan={name='npc_dota_roshan',loc=Vector(0,0)}
function roshan:GetLocation() return self.loc end
local tormentor={name='npc_dota_miniboss',GetLocation=roshan.GetLocation,loc=Vector(0,0)}
local J={}
J.IsDoingRoshan=function(h) return h.mode==BOT_MODE_ROSHAN end
J.IsDoingTormentor=function(h) return h.mode==BOT_MODE_SIDE_SHOP end
J.CanNotUseAction=function(h) return h.busy or false end
J.GetProperTarget=function(h) return h.target end
J.GetTeamFountain=function() return Vector(-6000,-6000) end
J.IsValid=function(h) return h~=nil and h.visible~=false end
J.IsValidHero=function(h) return h~=nil and h.id~=nil and h:IsAlive() end
J.IsRoshan=function(h) return h==roshan end
J.IsTormentor=function(h) return h==tormentor end
J.VectorAway=function(origin) return Vector(origin.x+650,0) end
local commands=require('bots/FunLib/shai_objective_commands')
dofile('.tools/lua/shai-objective-helpers.lua')(J,commands) -- actual objective helper bodies from jmz_func
local function Send(text,id)
    -- A nonleader callback arriving first must still produce one eventual reply.
    local handled=true
    for _,h in ipairs({b,a}) do handled=commands.Handle(h,J,{string=text,player_id=id or 0,team_only=false}) and handled end
    return handled
end
assert(not Send('stop roshan') and not Send('!stop nonsense'))
Send('!stop objectives',9); Send('!stop objectives',2); assert(#replies==0,'Enemy and bot commands ignored')
game=6; Send('!stop objectives'); assert(#replies==0,'No pregame veto')
game=7
a.shaiRoshanRequestUntil,b.shaiRoshanRequestUntil=now+30,now+30
a.shaiRoshanParticipants,b.shaiRoshanParticipants={human,a,b},{human,a,b}
assert(Send('  !STOP   ROSHAN  ') and #replies==1)
for _,h in ipairs({a,b,dead}) do
    assert(commands.IsBlocked(h,'roshan') and not commands.IsBlocked(h,'tormentor'))
    assert(h.shaiRoshanRequestUntil==nil and h.shaiRoshanParticipants==nil,'Cancel accepted request for every participant')
end
assert(human.shaiRoshanVeto==nil,'Never write a human bot override')
Send('!stop   roshan'); assert(#replies==1,'Duplicate delivery suppressed')
assert(Send('!normal') and #replies==2,'Resume works immediately after stop, without Roshan chat cooldown')
assert(not commands.IsBlocked(a,'roshan') and a.shaiRoshanRequestUntil==nil,'Resume does not resurrect old request')
now=now+2; Send('!stop tormentor')
assert(commands.IsBlocked(a,'tormentor') and not commands.IsBlocked(a,'roshan'),'Selective Tormentor veto')
now=now+2; Send('!stop objectives')
assert(commands.IsBlocked(a,'tormentor') and commands.IsBlocked(a,'roshan'))
a.mode,a.target=BOT_MODE_ROSHAN,roshan
assert(not J.IsDoingRoshan(a),'Hero/item objective helpers must not reissue a vetoed Roshan cast')
assert(commands.ReleaseObjective(a,J) and a.target==nil and a.moved.x>100,'Release ongoing Roshan attack away from contact')
b.mode,b.target=BOT_MODE_SIDE_SHOP,tormentor
assert(not J.IsDoingTormentor(b),'Hero/item objective helpers must respect Tormentor veto')
assert(commands.ReleaseObjective(b,J) and b.target==nil,'Release Tormentor attack')
b.busy=true; b.target=tormentor; local actions=b.actions
commands.ReleaseObjective(b,J); assert(b.actions==actions and b.target==tormentor,'Do not cancel TP/channel/queued spell')
b.busy=false; b.mode=BOT_MODE_NONE; assert(not commands.ReleaseObjective(b,J),'No interference with ordinary combat/escape modes')
a.mode,a.target=BOT_MODE_ROSHAN,human
assert(not commands.ReleaseObjective(a,J) and a.target==human,'Do not clear a hero combat target to enforce objective veto')
a.mode,a.target=BOT_MODE_ROSHAN,roshan; roshan.visible=false
commands.ReleaseObjective(a,J); assert(a.moved.x==-6000,'No location query of unseen objective')
roshan.visible=true
now=now+60; assert(not commands.IsBlocked(dead,'roshan') and not commands.IsBlocked(a,'tormentor'),'Exact expiry includes respawning bots')
assert(J.IsDoingRoshan(a),'Ordinary objective helper resumes after expiry')
now=now+2; a.alive=false
Send('!stop rosh'); assert(commands.IsBlocked(a,'roshan') and replies[#replies]:find('Roshan'),'New leader handles command after death')
now=1; assert(not commands.IsBlocked(a,'roshan'),'Clock rollback clears veto')
a.alive,b.alive=false,false; now=1200
local beforeWipe=#replies; Send('!stop objectives')
assert(commands.IsBlocked(a,'roshan') and commands.IsBlocked(dead,'tormentor') and #replies==beforeWipe+1,
    'All-dead team retains the command once for respawns')
b.alive=true
a.alive=true; now=1300; Send('!stop objectives'); game=6
assert(not commands.IsBlocked(a,'roshan') and not commands.IsBlocked(a,'tormentor'),'Pregame clears old veto')
game=7; now=1400; Send('!stop roshan')
local roshCommands=require('bots/FunLib/shai_roshan_commands')
assert(not roshCommands.RequestSafe(a,J),'Veto rejects manual request even before other checks')
local count=#replies
for _,h in ipairs({a,b}) do roshCommands.Handle(h,J,{string='!roshan',player_id=0}) end
assert(#replies==count+1 and replies[#replies]:find('paused'),'Roshan call respects veto with one reply')

-- Actual generic callback routes chat and releases an objective without blocking hero self-defense.
local registered,casts=nil,0
InstallChatCallback=function(fn) registered=fn end
J.IsNoAbilityIllution=function() return false end
function a:IsInvulnerable() return false end
function a:IsHero() return true end
a.frameProcessTime=0.1
a.mode,a.target=BOT_MODE_ROSHAN,roshan
local callback=dofile('.tools/lua/shai-ability-callback.lua')
local invoke=callback(a,J,{TryControl=function() return false end,HoldOffense=function() return false end},
    {Observe=function() end},{BehaviorTrace=false},{ThinkLess=0},{SkillsComplement=function() casts=casts+1 end},
    function() return false end,false,a:GetUnitName(),commands,roshCommands,{SetReplyHumanTime=function() end})
invoke(); now=now+0.2; invoke()
assert(registered~=nil and casts==1 and a.target==nil,'Hero actions still evaluated after leaving vetoed objective')
now=now+2; registered({string='!normal',player_id=0})
assert(not commands.IsBlocked(a,'roshan'),'Actual chat registration routes resume')
print('PASS: objective chat authorization, one reply, selective veto, request cancellation, expiry/reset, dead bots and real generic callback')
