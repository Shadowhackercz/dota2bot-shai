package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_NONE,BOT_MODE_FARM,BOT_MODE_RETREAT,BOT_MODE_EVASIVE_MANEUVERS=0,1,2,3
BOT_MODE_ROSHAN,BOT_MODE_TORMENTOR,BOT_MODE_TEAM_ROAM,BOT_MODE_LANING=4,5,6,7
BOT_MODE_DESIRE_NONE,DAMAGE_TYPE_ALL,DAMAGE_TYPE_PHYSICAL=0,0,1
UNIT_LIST_ALLIED_HEROES,UNIT_LIST_ENEMY_HEROES=1,2
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
local now,allies,enemies,passable=900,{},{},true
local baseThreat=false
DotaTime=function() return now end
IsLocationPassable=function() return passable end
GetUnitList=function(kind) return kind==UNIT_LIST_ALLIED_HEROES and allies or enemies end
IsPlayerBot=function(id) return id<10 end
GetUnitToLocationDistance=function(h,p) return math.sqrt((h.loc.x-p.x)^2+(h.loc.y-p.y)^2) end
GetUnitToUnitDistance=function(a,b) assert(b.visible,'Read hidden position'); return GetUnitToLocationDistance(a,b.loc) end
local function ability(name,range,radius)
    local a={name=name,ready=true,range=range or 700,radius=radius or 300,cooldown=0}
    function a:GetName() return self.name end
    function a:IsFullyCastable() return self.ready end
    function a:IsHidden() return false end
    function a:GetCastRange() return self.range end
    function a:GetSpecialValueInt() return self.radius end
    function a:GetCastPoint() return 0.3 end
    function a:GetCooldownTimeRemaining() return self.cooldown end
    return a
end
local function hero(name,id,x)
    local h={name=name,id=id,loc=Vector(x,0),hp=1800,maxHp=1800,level=15,dps=600,
        visible=true,abilities={},items={},mods={},mode=BOT_MODE_FARM,range=500}
    local function visible(self) assert(self.visible,'Read hidden enemy stats') end
    function h:IsNull() return false end
    function h:IsAlive() return self.hp>0 end
    function h:IsIllusion() return self.illusion or false end
    function h:IsHero() return true end
    function h:CanBeSeen() return self.visible end
    function h:GetPlayerID() return self.id end
    function h:GetUnitName() visible(self); return self.name end
    function h:GetLevel() visible(self); return self.level end
    function h:GetHealth() visible(self); return self.hp end
    function h:GetMaxHealth() visible(self); return self.maxHp end
    function h:GetHealthRegen() visible(self); return 5 end
    function h:GetEstimatedDamageToTarget(ready,_,seconds,kind)
        visible(self); assert(ready); return self.dps*seconds*(kind==DAMAGE_TYPE_PHYSICAL and (self.physical or 1) or 1)
    end
    function h:GetItemInSlot(slot) visible(self); return self.items[slot] end
    function h:GetAbilityByName(key) visible(self); return self.abilities[key] end
    function h:IsInvulnerable() visible(self); return self.invulnerable or false end
    function h:IsMagicImmune() visible(self); return self.immune or false end
    function h:IsStunned() return self.stunned or false end
    function h:IsHexed() return false end
    function h:IsSilenced() return self.silenced or false end
    function h:IsMuted() return self.muted or false end
    function h:HasModifier(key) visible(self); return self.mods[key] or false end
    function h:GetActiveMode() return self.mode end
    function h:GetActiveModeDesire() return 0.5 end
    function h:GetCurrentMovementSpeed() return 300 end
    function h:GetCastRangeBonus() return 0 end
    function h:GetLocation() visible(self); return self.loc end
    function h:GetNearbyTowers() visible(self); return self.towers or {} end
    function h:GetAttackRange() visible(self); return self.range end
    function h:WasRecentlyDamagedByAnyHero() return self.recent or false end
    function h:SetTarget(t) self.target=t end
    function h:GetTarget() return self.target end
    function h:Action_MoveToLocation(p) self.action='move'; self.destination=p end
    function h:Action_AttackUnit(t) self.action='attack'; self.attacked=t end
    function h:Action_UseAbility(a) self.action=a:GetName() end
    function h:Action_UseAbilityOnEntity(a,t) self.action=a:GetName(); self.castTarget=t end
    function h:Action_UseAbilityOnLocation(a,p) self.action=a:GetName(); self.castPoint=p end
    return h
end
local J={Utils={},Role={}}
J.IsValidHero=function(h) return h~=nil and h:IsAlive() end
J.IsSuspiciousIllusion=function(h) return h:IsIllusion() end
J.CanNotUseAction=function(h) return h.busy or false end
J.IsDisabled=function(h) return h.stunned or false end
J.VectorAway=function(a,b,d)
    local dx,dy=a.x-b.x,a.y-b.y; local len=math.sqrt(dx*dx+dy*dy)
    assert(len>0); return Vector(a.x+dx/len*d,a.y+dy/len*d)
end
J.GetTeamFountain=function() return Vector(-6000,-6000) end
J.GetEnemiesAroundAncient=function() return baseThreat and 1 or 0 end
package.loaded['bots/FunLib/jmz_func']=J
require('bots/Customize/shai').BehaviorTrace=false
local Gank=require('bots/FunLib/shai_team_gank')
local lion,sniper,axe,target
local function reset()
    now=math.max(900,now+50); passable=true; baseThreat=false
    lion=hero('npc_dota_hero_lion',1,-1800)
    sniper=hero('npc_dota_hero_sniper',2,-1700)
    axe=hero('npc_dota_hero_axe',3,-1600)
    target=hero('npc_dota_hero_silencer',10,0); target.level=23; target.dps=450; target.hp=3000; target.maxHp=3000
    lion.abilities.lion_voodoo=ability('lion_voodoo')
    axe.abilities.axe_berserkers_call=ability('axe_berserkers_call',0,300)
    allies,enemies={lion,sniper,axe},{target}
end
local function advance() now=now+0.5 end
reset()
assert(Gank.GetDesire(lion,J)==0.97)
local plan=lion.shaiGankPlan
assert(plan==sniper.shaiGankPlan and plan==axe.shaiGankPlan and plan.phase=='gather','One group plan')
Gank.Think(lion,J); Gank.Think(sniper,J)
assert(lion.action=='move' and sniper.action=='move' and lion.target==nil,'No solo initiation while gathering')
assert(Gank.HoldOffense(lion,J)); lion.recent=true; assert(not Gank.HoldOffense(lion,J),'Do not suppress self-defense'); lion.recent=false
lion.loc,sniper.loc,axe.loc=Vector(-1100,0),Vector(-1150,0),Vector(-1000,0)
advance(); Gank.GetDesire(sniper,J)
assert(plan.phase=='approach'); Gank.Think(axe,J); assert(axe.action=='move','Whole group approaches before engage')
lion.loc,sniper.loc,axe.loc=Vector(-550,0),Vector(-700,0),Vector(-220,0)
advance(); Gank.GetDesire(axe,J)
assert(plan.phase=='engage' and axe.target==target)
assert(Gank.TryControl(lion,J) and lion.action=='lion_voodoo','Prepared Hex opens')
assert(Gank.TryControl(axe,J) and axe.action=='move','Landing reservation prevents another cast immediately')
advance(); advance(); target.stunned=true
assert(not Gank.TryControl(axe,J),'Do not overlap a known active disable')
Gank.Think(sniper,J); assert(sniper.action=='attack' and sniper.attacked==target,'Damage member joins the same target')
target.stunned=false; lion.abilities.lion_voodoo.ready=false
assert(Gank.TryControl(axe,J) and axe.action=='axe_berserkers_call','Next ready controller can follow up')

reset(); allies={lion,sniper}; assert(Gank.GetDesire(lion,J)==nil,'Two bots cannot start dominant-target plan')
reset(); target.level=15; target.dps=700
assert(Gank.GetDesire(lion,J)==0.97,'Damage/health dominance can qualify even without level gap')
reset(); axe.abilities={}; assert(Gank.GetDesire(lion,J)==nil,'Single control source insufficient')
reset(); for _,h in ipairs(allies) do h.dps=150 end; assert(Gank.GetDesire(lion,J)==nil,'Reject inadequate damage')
-- Three is a minimum, not a ceiling: count the full available local group.
reset(); for _,h in ipairs(allies) do h.dps=350 end
assert(Gank.GetDesire(lion,J)==nil,'Three lack the required damage reserve')
local fourth=hero('npc_dota_hero_luna',4,-1900); fourth.dps=350; allies[#allies+1]=fourth
advance(); assert(Gank.GetDesire(lion,J)==0.97 and #lion.shaiGankPlan.members==4,
    'Fourth damage member enables a plan that three could not secure')
reset(); for _,h in ipairs(allies) do h.dps=270 end
fourth=hero('npc_dota_hero_luna',4,-1900); fourth.dps=270; allies[#allies+1]=fourth
assert(Gank.GetDesire(lion,J)==nil,'Four may still lack enough damage')
local fifth=hero('npc_dota_hero_zuus',5,-2000); fifth.dps=270; allies[#allies+1]=fifth
advance(); assert(Gank.GetDesire(lion,J)==0.97 and #lion.shaiGankPlan.members==5,
    'Full five-bot team may secure the plan')
assert(fourth.shaiGankPlan==lion.shaiGankPlan and fifth.shaiGankPlan==lion.shaiGankPlan,
    'Fourth and fifth participants receive the same coordinated plan')
reset(); axe.busy=true; assert(Gank.GetDesire(lion,J)==nil,'Casting/channel member not recruited')
reset(); axe.id=4; sniper.id=11; assert(Gank.GetDesire(lion,J)==nil,'Human presence is not a promise to participate')
reset(); target.visible=false; assert(Gank.GetDesire(lion,J)==nil,'No hidden inventory or position reads')
reset(); target.illusion=true; assert(Gank.GetDesire(lion,J)==nil,'No illusion bait')
reset(); target.towers={1}; assert(Gank.GetDesire(lion,J)==nil,'Do not dive tower')
reset(); enemies={target,hero('enemy1',12,200),hero('enemy2',13,300)}; assert(Gank.GetDesire(lion,J)==nil,'Abort into enemy backup')
reset(); target.items[0]=ability('item_aeon_disk'); assert(Gank.GetDesire(lion,J)==nil,'Ready Aeon rejects assumed secured kill')
reset(); target.items[0]=ability('item_sphere'); assert(Gank.GetDesire(lion,J)==nil,'Spell block removes targeted opener')
reset(); target.items[0]=ability('item_black_king_bar'); for _,h in ipairs(allies) do h.physical=0.1 end
assert(Gank.GetDesire(lion,J)==nil,'Ready BKB cannot be ignored by magic damage')
target.items[0].ready=false; advance(); assert(Gank.GetDesire(lion,J)==0.97,'Observed unavailable BKB is different')
reset(); target.items[0]=ability('item_black_king_bar')
assert(Gank.GetDesire(lion,J)==0.97,'Inactive BKB owner can be caught by two hard controllers with physical damage')
reset(); target.immune=true; assert(Gank.GetDesire(lion,J)==nil,'Active immunity requires piercing controls')
reset(); lion.abilities={}; lion.items[0]=ability('item_orchid'); target.items[0]=ability('item_manta')
assert(Gank.GetDesire(lion,J)==nil,'Ready Manta invalidates reliance on Orchid')
target.items[0].ready=false; advance(); assert(Gank.GetDesire(lion,J)==0.97,'Orchid counts when dispel unavailable and hard control present')
reset(); lion.abilities={}; lion.items[0]=ability('item_sheepstick'); target.items[0]=ability('item_manta')
assert(Gank.GetDesire(lion,J)==0.97,'Hex plus another controller viable despite Manta')
reset(); lion.abilities.lion_voodoo.ready=false; assert(Gank.GetDesire(lion,J)==nil,'Cooldown control not counted')
reset(); lion.silenced=true; assert(Gank.GetDesire(lion,J)==nil,'Silenced caster not counted')
reset(); passable=false; assert(Gank.GetDesire(lion,J)==nil,'Unreachable rally not published')
reset(); baseThreat=true; assert(Gank.GetDesire(lion,J)==nil,'Base emergency takes priority')
reset(); assert(Gank.GetDesire(lion,J)); target.visible=false; advance()
assert(Gank.GetDesire(sniper,J)==nil and lion.shaiGankPlan==nil,'Loss of vision cancels for whole group')
target.visible=true; advance(); assert(Gank.GetDesire(lion,J)==nil,'Abort has bounded cooldown')
reset(); Gank.GetDesire(lion,J); axe.hp=500; advance(); assert(Gank.GetDesire(lion,J)==nil and sniper.shaiGankPlan==nil,'Wounded participant cancels')
reset(); Gank.GetDesire(lion,J); now=now+19; assert(Gank.GetDesire(sniper,J)==nil,'Gathering cannot wait forever')
reset(); Gank.GetDesire(lion,J); now=2; assert(Gank.GetDesire(lion,J)==nil and lion.shaiGankPlan==nil,'Clock reset clears plan')

local function engaged()
    reset(); Gank.GetDesire(lion,J)
    lion.loc,sniper.loc,axe.loc=Vector(-550,0),Vector(-700,0),Vector(-220,0)
    advance(); Gank.GetDesire(lion,J)
    assert(lion.shaiGankPlan.phase=='engage')
end
engaged(); local survivorPlan=lion.shaiGankPlan
sniper.hp=100; target.hp=900; target.stunned=true; advance()
assert(Gank.GetDesire(lion,J)==0.97 and lion.shaiGankPlan==survivorPlan and sniper.shaiGankPlan==nil,
    'One wounded damage member leaves; two viable finishers continue together')
engaged(); target.hp=900; target.range=250; lion.hp=600; advance()
assert(Gank.GetDesire(lion,J)==0.97 and lion.shaiGankPlan==axe.shaiGankPlan,'Safe ranged low-HP controller may contribute')
assert(Gank.HoldOffense(lion,J),'Wounded controller does not dispatch optional damage chase')
assert(Gank.TryControl(lion,J) and lion.action=='lion_voodoo','Do not lose essential safe Hex just because caster wounded')
lion.abilities.lion_voodoo.ready=false; target.stunned=true; advance()
assert(Gank.GetDesire(sniper,J)==0.97 and lion.shaiGankPlan==nil,'Controller leaves after contribution without canceling viable kill')
engaged(); sniper.hp=100; lion.hp=100; advance()
assert(Gank.GetDesire(axe,J)==nil,'Actual loss of damage/control still aborts')
engaged(); baseThreat=true; advance(); assert(Gank.GetDesire(axe,J)==nil,'Abort group to defend base')
engaged(); lion.abilities.special_bonus_unique_lion_4={IsTrained=function() return true end}
assert(Gank.TryControl(lion,J) and lion.castPoint~=nil and lion.castTarget==nil,'AoE Hex talent uses location cast')

-- Real roam entry/Think must not replace the plan with incidental last hits or help.
reset(); GetBot=function() return lion end; GetTeam=function() return 2 end
function lion:GetTeam() return 2 end
J.GetMostPushLaneDesire,J.GetMostDefendLaneDesire=function() return 2 end,function() return 2 end
J.CheckBotIdleState,J.IsCore,J.Role.IsPvNMode=function() return false end,function() return false end,function() return false end
J.IsInLaningPhase,J.IsPushing=function() return false end,function() return true end
J.GetClosestCore=function() return nil end
J.Utils.IsValidUnit=J.IsValidHero
J.IsNoAbilityIllution=function() return false end
package.loaded['bots/FunLib/utils']={SetFrameProcessTime=function() end}
package.loaded['bots/FunLib/enemy_role_estimation']={UpdateEnemyHeroPositions=function() end}
for _,name in ipairs({'localization','aba_item','aba_role'}) do package.loaded['bots/FunLib/'..name]={} end
package.loaded['bots/Customize/general']={Enable=true,ThinkLess=0}
local originalDofile=dofile
dofile=function(path)
    if path=='bots/FunLib/aba_special_units' then return {GetTombstoneDesire=function() return 0 end} end
    return originalDofile(path)
end
local roam=dofile('bots/mode_team_roam_generic.lua')
ItemOpsDesire,ItemOpsThink=function() end,function() end
assert(GetDesire()==0.97,'Coordinated group priority survives old push soft cap')
roam.Think(); assert(lion.action=='move' and lion.target==nil,'Actual roam gather does not attack')
lion.loc,sniper.loc,axe.loc=Vector(-550,0),Vector(-700,0),Vector(-220,0)
advance(); assert(GetDesire()==0.97); roam.Think(); assert(lion.action=='lion_voodoo','Actual roam dispatches group control')
-- Execute the real generic callback body with its existing environment supplied.
local casts=0
local callback=dofile('.tools/lua/shai-ability-callback.lua') -- extracted from real source by Test-SHAI.ps1
local invoke=callback(lion,J,Gank,{Observe=function() end},{BehaviorTrace=false},{ThinkLess=0},
    {SkillsComplement=function() casts=casts+1 end},function() return false end,true,lion.name)
lion.lastAbilityFrameProcessTime=nil; lion.frameProcessTime=0.1
invoke(); assert(casts==0,'Generic callback honors control landing reservation')
advance(); advance(); target.stunned=true; invoke(); assert(casts==1,'Generic callback resumes damage dispatch on disabled target')
print('PASS: real team gank gather/approach/engage, group readiness, defenses, visibility, cancellation, roam and generic ability dispatch')
