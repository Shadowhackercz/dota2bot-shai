package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_NONE,BOT_MODE_EVASIVE_MANEUVERS,BOT_MODE_RETREAT=0,1,2
DAMAGE_TYPE_ALL,DAMAGE_TYPE_PHYSICAL=1,2
DAMAGE_TYPE_MAGICAL,DAMAGE_TYPE_PURE,ATTRIBUTE_STRENGTH=3,4,0
UNIT_LIST_ALLIED_HEROES,UNIT_LIST_ENEMY_HEROES=1,2
TOWER_TOP_3,TOWER_MID_3,TOWER_BOT_3=2,5,8
LANE_MID=2
local now=1500
DotaTime=function() return now end
Vector=function(x,y,z) return {x=x,y=y,z=z or 0} end
GetUnitToUnitDistance=function(a,b) return math.abs(a.x-b.x) end
GetUnitToLocationDistance=function(a,b) assert(b~=nil); return math.abs(a.x-b.x) end
local function hero(name,id,x)
    local h={name=name,id=id,x=x,hp=1800,maxHp=2000,damage=400,range=600,stun=0,visible=true,mods={},abilities={},items={}}
    local function visible(self) assert(self.visible,'Read hidden enemy') end
    function h:IsNull() return false end
    function h:IsAlive() return self.hp>0 end
    function h:IsHero() return true end
    function h:CanBeSeen() return self.visible end
    function h:IsIllusion() return false end
    function h:IsBot() return not self.human end
    function h:GetPlayerID() return self.id end
    function h:GetTeam() return 2 end
    function h:GetLocation() visible(self); return Vector(self.x,0) end
    function h:GetHealth() visible(self); return self.hp end
    function h:GetMaxHealth() visible(self); return self.maxHp end
    function h:GetUnitName() visible(self); return self.name end
    function h:GetEstimatedDamageToTarget(_,target,time) visible(self); return self.damage*time end
    function h:GetAttackRange() visible(self); return self.range end
    function h:GetMana() return self.mana or 1000 end
    function h:GetAttackDamage() return self.damage end
    function h:GetSecondsPerAttack() return 1 end
    function h:GetCurrentMovementSpeed() return 300 end
    function h:GetSpellAmp() return 0 end
    function h:GetAttributeValue() return 40 end
    function h:GetActualIncomingDamage(raw) return raw end
    function h:GetAttackTarget() visible(self); return self.target end
    function h:GetStunDuration() return self.stun end
    function h:IsStunned() return self.stunned or false end
    function h:IsHexed() return false end
    function h:IsSilenced() return false end
    function h:IsMuted() return false end
    function h:IsInvulnerable() visible(self); return false end
    function h:IsMagicImmune() return false end
    function h:IsAttackImmune() return false end
    function h:HasModifier(name) visible(self); return self.mods[name] or false end
    function h:GetAbilityByName(name) return self.abilities[name] end
    function h:GetItemInSlot(slot) visible(self); return self.items[slot] end
    function h:GetNearbyLaneCreeps() return {} end
    function h:GetActiveMode() return BOT_MODE_NONE end
    function h:GetActiveModeDesire() return 0.9 end
    function h:GetCastRangeBonus() return 0 end
    function h:SetTarget(t) self.target=t end
    function h:Action_MoveToLocation(loc) self.action='move'; self.destination=loc end
    function h:Action_AttackUnit(t) self.action='attack'; self.attacked=t end
    function h:Action_UseAbilityOnEntity(a,t) self.action=a:GetName(); self.castTarget=t end
    function h:Action_UseAbilityOnLocation(a,t) self.action=a:GetName(); self.castLocation=t end
    function h:Action_UseAbility(a) self.action=a:GetName() end
    return h
end
local bot,enemy,ally,ancient,allies,enemies
local no=function() return false end
local J={}
J.IsValidHero=function(h) return h~=nil and h.hp>0 end
J.IsSuspiciousIllusion=no
J.GetNearbyHeroes=function(_,_,enemyTeam) return enemyTeam and enemies or allies end
J.CanNotUseAction=function(h) return h.busy or false end
J.CanNotUseAbility=no
J.IsDisabled=function(h) return h.stunned or false end
J.GetHP=function(h) return h.hp/h.maxHp end
J.GetTeamFountain=function() return Vector(-2000,0) end
J.VectorAway=function(a,b,d) return Vector(a.x+(a.x>b.x and d or -d),0) end
package.loaded['bots/FunLib/jmz_func']=J
require('bots/Customize/shai').BehaviorTrace=false
local Defense=require('bots/FunLib/shai_defense')
GetAncient=function() return ancient end
GetUnitList=function(kind) return kind==UNIT_LIST_ENEMY_HEROES and enemies or allies end
GetTower=function() return nil end
IsLocationPassable=function() return true end
local function reset()
    now=math.max(1500,now+10)
    bot=hero('npc_dota_hero_lion',1,0); bot.stun=2
    ally=hero('npc_dota_hero_sven',2,100)
    enemy=hero('npc_dota_hero_silencer',8,1000); enemy.hp=3000; enemy.damage=250; enemy.stunned=true
    ancient=hero('ancient',0,-700); ancient.hp=5000
    allies,enemies={bot,ally},{enemy}
end
reset(); assert(Defense.GetPlan(bot,J).hold,'Insufficient damage must hold instead of blindly running at a hero')
Defense.Think(bot,J); assert(bot.action=='move' and bot.target==nil,'Actual movement holds inside base')
assert(not Defense.GuardAbilities(bot,J),'A healthy caster safely behind the diver may dispatch native spells')
reset(); bot.damage,ally.damage=1200,1200
assert(Defense.GetPlan(bot,J).ready,'Two local healthy ready members can commit')
Defense.Think(bot,J); assert(bot.action=='attack' and bot.attacked==enemy,'Actual defend joins shared target')
assert(Defense.GetPlan(ally,J).target==enemy,'Other local member uses same published focus')
reset(); ally.human=true; bot.damage,ally.damage=1200,1200
assert(Defense.GetPlan(bot,J).hold,'A nearby human is not presumed to join')
ally.target=enemy; now=now+0.3; assert(Defense.GetPlan(bot,J).ready,'Actually attacking human contributes')
reset(); bot.damage,ally.damage=1200,1200; ally.mods.modifier_teleporting=true
assert(Defense.GetPlan(bot,J).hold,'Teleporting ally cannot justify commitment')
reset(); bot.damage,ally.damage=1200,1200; ally.hp=500
assert(Defense.GetPlan(bot,J).hold,'Wounded ally not counted as promised DPS')
reset(); bot.damage,ally.damage=1200,1200; ally.stunned=true
assert(Defense.GetPlan(bot,J).hold,'Currently incapacitated ally is not a ready damage member')
reset(); bot.damage,ally.damage=1200,1200; enemy.damage=5000
assert(Defense.GetPlan(bot,J).hold,'Lethal incoming damage still blocks attack')
reset(); enemy.target=ancient; ancient.hp=1000
assert(Defense.GetPlan(bot,J).emergency and Defense.GetDesire(bot,J)>1,'Imminent Ancient loss does not wait indefinitely')
Defense.Think(bot,J); assert(bot.action=='attack','Emergency actually responds')
reset(); enemy.visible=false; assert(Defense.GetPlan(bot,J)==nil,'No fog position/HP/inventory reads')
reset(); enemy.x=5000; assert(Defense.GetPlan(bot,J)==nil,'No global enemy tracking')
reset(); bot.busy=true; assert(not Defense.Think(bot,J) and bot.action==nil,'Do not cancel channel/queued actions')
reset(); Defense.GetPlan(bot,J); enemy.visible=false; assert(not Defense.Think(bot,J),'Cached plan rechecks vision before acting')
reset(); now=100; assert(Defense.GetPlan(bot,J)==nil,'No base defense policy during laning')

-- Actual lane wrapper prevents the generated fallback issuing the unsafe attack.
reset(); GetBot=function() return bot end
local fallback=0
package.loaded['bots/FunLib/aba_defend']={GetDefendDesire=function() return 0.8 end,
    GetFurthestBuildingOnLane=function() return {ancient,1,3} end,DefendThink=function() fallback=fallback+1 end}
dofile('bots/mode_defend_tower_mid_generic.lua')
Think(); assert(bot.action=='move' and fallback==0,'Actual defense wrapper intercepts unsafe fallback')
now=now+1; enemies={}; Think(); assert(fallback==1,'Normal defense resumes when no local siege')

-- Actual generic callback holds optional offense and resumes normal dispatch.
reset(); local casts=0
bot.frameProcessTime=0.1; bot.lastAbilityFrameProcessTime=now-1
J.IsNoAbilityIllution=no
local invoke=dofile('.tools/lua/shai-ability-callback.lua')(bot,J,{TryControl=no,HoldOffense=no},
    {Observe=function() end},{BehaviorTrace=false},{ThinkLess=0},{SkillsComplement=function() casts=casts+1 end},
    no,true,bot.name,{ReleaseObjective=no},nil,nil,nil,Defense)
invoke(); assert(casts==1,'Actual generic callback permits safe native spell follow-up')
now=now+1; enemies={}; invoke(); assert(casts==2,'Original hero dispatch resumes')
print('PASS: local defensive group, unsafe positioning, humans/HP/TP, Ancient emergency, fog, actual defend and ability callbacks')

local function ability(name,range,radius)
    local a={name=name,range=range or 600,ready=true}
    function a:GetName() return self.name end
    function a:IsFullyCastable() return self.ready end
    function a:IsHidden() return false end
    function a:GetCastRange() return self.range end
    function a:GetCastPoint() return 0.3 end
    function a:GetChannelTime() return 8 end
    function a:GetSpecialValueInt() return radius or 315 end
    function a:GetSpecialValueFloat(key) return (self.values and self.values[key]) or (key:find('duration') and 2) or 0 end
    function a:GetManaCost() return self.mana or 100 end
    function a:GetAbilityDamage() return 0 end
    return a
end
local warlock,wk,sniper
local function siege()
    reset(); enemy.stunned=false; enemy.x=300; enemy.hp=2103; enemy.damage=500
    bot.x=0; bot.name='npc_dota_hero_centaur'; bot.damage=115
    bot.abilities.centaur_hoof_stomp=ability('centaur_hoof_stomp',0,315)
    wk=hero('npc_dota_hero_skeleton_king',2,40); wk.damage=115
    wk.abilities.skeleton_king_hellfire_blast=ability('skeleton_king_hellfire_blast')
    sniper=hero('npc_dota_hero_sniper',3,-100); sniper.damage=115
    warlock=hero('npc_dota_hero_warlock',4,-130); warlock.damage=115; warlock.hp=1242
    warlock.abilities.warlock_rain_of_chaos=ability('warlock_rain_of_chaos',1000)
    allies={bot,wk,sniper,warlock}
end
siege(); local p=Defense.GetPlan(bot,J)
assert(p.ready and p.reason=='group-pressure' and #p.members==4,'Four ready bots pressure a single base diver despite uncertain lethal engine damage')
assert(Defense.GetPlan(warlock,J)==p,'Different bot observers see the same published roster and budget')
enemy.stunned=true
assert(Defense.GuardAbilities(warlock,J) and warlock.action=='warlock_rain_of_chaos','Ready healthy Warlock uses R against the single caught base diver')
warlock.abilities.warlock_rain_of_chaos.ready=false; bot.hp=250; now=now+0.3
p=Defense.GetPlan(wk,J)
assert(p.ready and #p.members==3,'One wounded member drops out without canceling a controlled viable follow-through')
assert(Defense.GetDesire(bot,J)<1,'Wounded excluded member is not forced to stand and autoattack')
siege(); for _,h in ipairs(allies) do h.abilities={} end
assert(Defense.GetPlan(bot,J).hold,'Four bodies alone are not sufficient without a ready opener')
siege(); local backup=hero('npc_dota_hero_kez',9,400); backup.hp=2500; backup.damage=300
enemies={enemy,backup}; assert(Defense.GetPlan(bot,J).hold,'Multiple attackers do not use the isolated-diver pressure exception')
siege(); warlock.hp=200; sniper.hp=200
assert(Defense.GetPlan(bot,J).hold,'Dying allies do not justify a new team commitment')
siege(); enemy.mods.modifier_item_aeon_disk_buff=true
assert(Defense.GetPlan(bot,J)==nil,'Do not spend the opener on an active protected target')
siege(); local doctor=hero('npc_dota_hero_witch_doctor',4,-130); doctor.damage=115
doctor.abilities.witch_doctor_paralyzing_cask=ability('witch_doctor_paralyzing_cask')
doctor.abilities.witch_doctor_maledict=ability('witch_doctor_maledict')
doctor.abilities.witch_doctor_death_ward=ability('witch_doctor_death_ward')
allies[4]=doctor; enemy.stunned=true; enemy.damage=100
assert(Defense.GuardAbilities(doctor,J) and doctor.action=='witch_doctor_maledict','Coordinated response applies Maledict first')
doctor.abilities.witch_doctor_maledict.ready=false
assert(Defense.GuardAbilities(doctor,J) and doctor.action=='witch_doctor_death_ward','Caught diver permits safe Death Ward even with four allied heroes')
print('PASS: shared four-bot siege response, single-target golem, wounded-member continuation, no-opener/backup/protection rejection and Maledict/Death Ward')
