-- Actual finish helper, roam mode and generic dispatch; engine is mocked.
package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
BOT_MODE_NONE,BOT_MODE_RETREAT,BOT_MODE_EVASIVE_MANEUVERS=0,1,2
BOT_MODE_DESIRE_NONE=0
DAMAGE_TYPE_PHYSICAL,DAMAGE_TYPE_MAGICAL,DAMAGE_TYPE_ALL=1,2,3
local now=900
DotaTime=function() return now end
GetTeam=function() return 2 end
GetUnitToUnitDistance=function(a,b) return math.abs(a.x-b.x) end
local function hero(name,x)
    local h={name=name,x=x,z=0,hp=100,maxHp=1000,damage=100,dps=10,regen=0,range=550,
        visible=true,alive=true,mods={},items={},abilities={},actions=0,team=3,desire=1,mode=BOT_MODE_RETREAT}
    local function visible(self) assert(self.visible,'Hidden enemy state read') end
    function h:IsNull() return false end
    function h:IsAlive() return self.alive end
    function h:IsHero() return true end
    function h:IsIllusion() return self.illusion or false end
    function h:CanBeSeen() return self.visible end
    function h:GetUnitName() visible(self); return self.name end
    function h:GetHealth() visible(self); return self.hp end
    function h:GetMaxHealth() visible(self); return self.maxHp end
    function h:GetHealthRegen() visible(self); return self.regen end
    function h:GetLocation() visible(self); return {x=self.x,y=0,z=self.z} end
    function h:GetTeam() return self.team end
    function h:HasModifier(mod) visible(self); return self.mods[mod] or false end
    function h:IsInvulnerable() visible(self); return self.invulnerable or false end
    function h:GetEvasion() visible(self); return self.evasion or 0 end
    function h:IsStunned() return self.stun or false end
    function h:GetNetWorth() visible(self); return self.worth or 4000 end
    function h:GetActualIncomingDamage(raw,type) visible(self); return raw*(type==DAMAGE_TYPE_MAGICAL and 0.75 or 1) end
    function h:GetEstimatedDamageToTarget(ready,target,time) visible(self); assert(ready); return self.dps*time end
    function h:GetItemInSlot(slot) visible(self); return self.items[slot] end
    function h:GetAbilityByName(name) return self.abilities[name] end
    function h:GetAttackDamage() visible(self); return self.damage end
    function h:GetAttackRange() return self.range end
    function h:GetSecondsPerAttack() return 0.5 end
    function h:GetAttackProjectileSpeed() return 1000 end
    function h:GetAttackTarget() return self.target end
    function h:IsFacingLocation() return self.facing~=false end
    function h:IsDisarmed() return self.disarmed or false end
    function h:IsHexed() return self.hexed or false end
    function h:GetActiveMode() return self.mode end
    function h:GetActiveModeDesire() return self.desire end
    function h:GetIncomingTrackingProjectiles() return self.projectiles or {} end
    function h:GetNearbyTowers() return self.towers or {} end
    function h:GetNearbyCreeps() return self.creeps or {} end
    function h:GetSpellAmp() return 0 end
    function h:GetCastRangeBonus() return 0 end
    function h:SetTarget(t) self.target=t end
    function h:Action_AttackUnit(t,once) self.actions=self.actions+1; self.attacked=t; self.once=once end
    function h:Action_UseAbilityOnEntity(a,t) self.actions=self.actions+1; self.spell=a:GetName(); self.castTarget=t end
    return h
end
local function ability(name,damage,range)
    local a={ready=true,delay=0.2}
    function a:GetName() return name end
    function a:GetCooldownTimeRemaining() return self.ready and 0 or 5 end
    function a:IsFullyCastable() return self.ready end
    function a:IsHidden() return false end
    function a:GetCastPoint() return self.delay end
    function a:GetCastRange() return range or 700 end
    function a:GetSpecialValueInt() return damage or 200 end
    return a
end
local bot,target,enemies
local no=function() return false end
local J={Role={IsPvNMode=no},Utils={}}
J.GetHP=function(h) return h.hp/h.maxHp end
J.IsValidHero=function(h) return h~=nil and h.alive end
J.IsSuspiciousIllusion=function(h) return h.illusion or false end
J.GetNearbyHeroes=function() return enemies end
J.CanNotUseAction=function(h) return h.busy or false end -- queue/channel/casting engine guard
J.CanNotUseAbility=function(h) return h.silenced or h.busy or false end
J.CanBeAttacked=function(h) return not h.attackImmune end
J.CanCastOnNonMagicImmune=function(h) return not h.immune end
J.CanCastOnTargetAdvanced=function(h) return not h.block end
J.IsDisabled=function(h) return h.disabled or false end
J.GetRemainStunTime=function(h) return h.stunTime or 0 end
J.GetAttackProDelayTime=function(h,t) return h.delay or (0.2+GetUnitToUnitDistance(h,t)/1000) end
require('bots/Customize/shai').BehaviorTrace=false
local Finish=require('bots/FunLib/shai_combat_finish')
local function reset(name)
    now=now+10
    bot=hero(name or 'npc_dota_hero_lion',0); bot.team=2
    target=hero('npc_dota_hero_silencer',250); target.hp=50
    enemies={target}
end
local function reject(message) assert(Finish.GetPlan(bot,J)==nil,message) end
reset(); assert(Finish.GetPlan(bot,J).kind=='attack','Low HP 1v1 can finish one reliable hit')
assert(Finish.TryAction(bot,J) and bot.attacked==target and bot.once,'Actual single attack issued')
now=now+0.1; assert(Finish.TryAction(bot,J) and bot.actions==1,'No wind-up restart or second command')
now=now+0.3; reject('May escape after projectile release; do not wait through flight/backswing')
now=now+1; reject('Attempt expires even if damage failed'); now=now+1; assert(Finish.GetPlan(bot,J),'Retry only after finite cooldown')
reset(); bot.hp=700; reject('Healthy bots retain existing combat logic')
reset(); target.hp=180; reject('Do not assume two or three attacks will land')
target.stun=true; target.stunTime=2
assert(Finish.GetPlan(bot,J).hits==3 and Finish.TryAction(bot,J) and not bot.once,'Three attacks when control lasts and survival reserve passes')
now=now+0.1; assert(Finish.TryAction(bot,J) and bot.actions==1,'Do not interrupt/restart selected sequence')
target.stunTime=0.1; reject('Loss of needed control invalidates multi-attack promise')
reset(); target.hp=130; target.stun=true; target.stunTime=2
assert(Finish.GetPlan(bot,J).hits==2,'Two hits suffice; do not demand three')
reset(); target.hp=180; target.stun=true; target.stunTime=2; target.dps=100; reject('Control alone does not authorize dying before three hits')
reset(); target.x=600; reject('No chasing outside attack range')
reset(); bot.delay=0.9; reject('Long attack cooldown yields to retreat')
reset(); bot.facing=false; reject('No instant-turn timing assumption for attack')
reset(); target.z=100; reject('Ranged uphill miss risk is not a secured hit')
reset(); target.evasion=0.25; reject('No guaranteed hit against evasion')
reset(); bot.disarmed=true; reject('No attacks while disarmed')
reset(); bot.mods.modifier_tinker_laser_blind=true; reject('Known miss debuff invalidates reliable hit')
reset(); target.regen=120; reject('Regeneration before impact prevents assumed kill')
reset(); target.mods.modifier_dazzle_shallow_grave=true; reject('Death protection')
reset(); target.mods.modifier_item_blade_mail_reflect=true; reject('Reflection can reverse a low HP finish')
reset(); target.items[0]=ability('item_aeon_disk'); reject('Ready Aeon prevents secured kill')
reset(); target.items[0]=ability('item_aeon_disk'); target.items[0].ready=false; assert(Finish.GetPlan(bot,J),'Observed Aeon cooldown differs')
reset(); target.visible=false; reject('Fog without hidden stats reads')
reset(); target.illusion=true; reject('No illusion bait')
reset(); target.dps=180; reject('Lethal retaliation outweighs possible kill')
reset(); local backup=hero('npc_dota_hero_sven',450); backup.dps=180; enemies[#enemies+1]=backup; reject('Enemy backup counts')
reset(); bot.projectiles={{is_attack=false,caster=target}}; reject('Unknown spell projectile yields to escape')
reset(); target.damage=100; bot.projectiles={{is_attack=true,caster=target}}; reject('Already flying attack is not forgotten')
reset(); local creep=hero('creep',200); creep.dps=180; creep.target=bot; bot.creeps={creep}; reject('Creeps currently attacking bot count')
reset(); bot.towers={hero('tower',500)}; reject('No low HP tower dive')
reset(); bot.busy=true; reject('Do not interrupt queued/channel/cast action')
reset(); bot.desire=2.88; reject('Special escape retains priority')
reset(); bot.mods.modifier_jakiro_macropyre_burn=true; reject('Exit dangerous area first')
reset(); bot.shaiGankPlan={created=now,updated=now,expires=now+18,phase='gather'}; reject('Do not reveal a gathering group')
reset(); bot.shaiGankPlan={created=now,updated=now,expires=now+18,phase='engage',controlUntil=now+0.5}; reject('Keep gank opener landing window')
reset(); assert(Finish.TryAction(bot,J)); target.visible=false; now=now+0.1; reject('Lose vision during wind-up without hidden reads')
reset(); assert(Finish.TryAction(bot,J)); target.dps=300; now=now+0.1; reject('New danger breaks short hold immediately')
reset(); assert(Finish.TryAction(bot,J)); bot.hp=25; now=now+0.1
assert(Finish.TryAction(bot,J) and bot.actions==1,'Low HP alone does not discard a still-executable wind-up')
reset(); assert(Finish.TryAction(bot,J)); target.hp=300; now=now+0.1; reject('A healed enemy is no longer a lethal finish')

reset(); now=1500; bot.delay=0.55; target.x=500; target.stun=true; target.stunTime=1.2
target.worth=20000; bot.worth=6000; target.dps=210
local trade=Finish.GetPlan(bot,J)
assert(trade and trade.trade and Finish.TryAction(bot,J),'Can release lethal ranged hit before possible death to trade for much stronger target')
now=now+0.1; assert(Finish.TryAction(bot,J) and bot.actions==1,'Committed trade does not restart attack')
reset(); now=1600; bot.delay=0.55; target.x=500; target.stun=true; target.stunTime=1.2; target.dps=210
reject('Equal-value enemy does not justify deliberate risky trade')
target.worth=20000; target.dps=600; reject('Valuable enemy is insufficient if bot dies before releasing attack')
target.dps=210; target.items[0]=ability('item_aegis'); reject('Do not spend life trading into Aegis')
target.items={}; target.stunTime=0.1; reject('Risky projectile trade needs control until impact')
reset(); Finish.TryAction(bot,J); now=1; assert(Finish.GetPlan(bot,J),'Clock rollback clears old attempt')

reset('npc_dota_hero_zuus'); bot.disarmed=true; target.x=650
bot.abilities.zuus_arc_lightning=ability('zuus_arc_lightning')
assert(Finish.GetPlan(bot,J).kind=='spell' and Finish.TryAction(bot,J) and bot.spell=='zuus_arc_lightning','Actual immediate lethal Q in cast range')
bot.abilities.zuus_arc_lightning.ready=false; now=now+0.1
assert(Finish.TryAction(bot,J) and bot.actions==1,'Used spell cooldown does not trigger another cast')
reset('npc_dota_hero_luna'); bot.disarmed=true; bot.abilities.luna_lucent_beam=ability('luna_lucent_beam')
assert(Finish.GetPlan(bot,J).kind=='spell','Lucent Beam supported')
target.immune=true; reject('No magic kill into immunity')
target.immune=false; target.items[0]=ability('item_sphere'); reject('Spell block counted')
target.items={}; bot.mods.modifier_silencer_last_word=true; reject('No low HP spell into Last Word')
bot.mods={modifier_silencer_curse_of_the_silent=true}; reject('No low HP spell extending Curse')
bot.mods={}; target.items[0]=ability('item_manta'); reject('Ready dispel/dodge invalidates secured magic kill')
target.items={}; bot.abilities.luna_lucent_beam.ready=false; reject('Unavailable spell not counted')

-- Real mode beats ordinary retreat/push caps, but a stale choice issues no order.
reset(); GetBot=function() return bot end
J.GetMostPushLaneDesire,J.GetMostDefendLaneDesire=function() return 2 end,function() return 2 end
J.CheckBotIdleState,J.IsCore=no,no
J.IsInLaningPhase,J.IsPushing=function() return true end,function() return true end
package.loaded['bots/FunLib/jmz_func']=J
package.loaded['bots/FunLib/utils']={SetFrameProcessTime=function() end}
package.loaded['bots/FunLib/enemy_role_estimation']={UpdateEnemyHeroPositions=function() end}
for _,name in ipairs({'localization','aba_item','aba_role'}) do package.loaded['bots/FunLib/'..name]={} end
package.loaded['bots/Customize/general']={Enable=true,ThinkLess=0}
local actualDofile=dofile
package.loaded['bots/FunLib/shai_defense']={GetDesire=function() return nil end}
dofile=function(path)
    if path=='bots/FunLib/aba_special_units' then return {GetTombstoneDesire=function() return 0 end} end
    return actualDofile(path)
end
local roam=dofile('bots/mode_team_roam_generic.lua')
ItemOpsDesire,ItemOpsThink=function() end,function() end
assert(GetDesire()==1.05,'Actual immediate finish survives lane/push cap and ordinary retreat priority')
roam.Think(); assert(bot.actions==1 and bot.once,'Actual roam executes finish')
now=now+0.1; target.visible=false; roam.Think(); assert(bot.actions==1,'Stale mode cannot fall through to attack or farming')

-- Execute extracted real callback with the actual new helper, not a mirror.
reset(); local casts=0
J.IsNoAbilityIllution=no
bot.frameProcessTime=0.1
bot.lastAbilityFrameProcessTime=now-1
local invoke=dofile('.tools/lua/shai-ability-callback.lua')(bot,J,{TryControl=no,HoldOffense=no},
    {Observe=function() end},{BehaviorTrace=false},{ThinkLess=0},{SkillsComplement=function() casts=casts+1 end},
    no,true,bot.name,{ReleaseObjective=no},nil,nil,Finish)
invoke(); assert(bot.attacked==target and casts==0,'Actual generic dispatch secures finish before optional cast')
local itemCasts=0
J.IsNoItemIllution=no
bot.lastItemFrameProcessTime=now-1
local itemThink=dofile('.tools/lua/shai-item-callback.lua')(bot,J,{ThinkLess=0},no,Finish,
    function() itemCasts=itemCasts+1 end,bot.name)
itemThink(); assert(itemCasts==0,'Actual item callback does not cancel selected attack wind-up')
now=now+0.1; invoke(); assert(bot.actions==1 and casts==0,'Generic callback preserves attack wind-up')
now=now+1; invoke(); itemThink(); assert(casts==1 and itemCasts==1,'Normal hero/item dispatch resumes after bounded attempt')
reset(); local messages={}; local originalPrint=print
require('bots/Customize/shai').BehaviorTrace=true
print=function(message) messages[#messages+1]=message end
Finish.TryAction(bot,J); target.visible=false; now=now+0.1; Finish.GetPlan(bot,J)
print=originalPrint
assert(#messages==2 and string.find(messages[1],'reason=issued') and string.find(messages[2],'abort%-target%-changed'),
    'Log issued and abort once, with cached name and no fog stats reads')
print('PASS: immediate lethal finish, survival/projectiles/defenses, bounded revalidation, real roam and generic dispatch')
