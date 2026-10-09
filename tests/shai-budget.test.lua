package.path='./?.lua;'..package.path
GetScriptDirectory=function() return 'bots' end
DAMAGE_TYPE_ALL,DAMAGE_TYPE_PHYSICAL,DAMAGE_TYPE_MAGICAL,DAMAGE_TYPE_PURE,ATTRIBUTE_STRENGTH=0,1,2,4,0
local now=900
DotaTime=function() return now end
GetUnitToUnitDistance=function(a,b) assert(b.visible,'Hidden position read'); return math.abs(a.x-b.x) end
local function ability(name,cost,values)
    local a={name=name,cost=cost or 100,values=values or {},ready=true,range=700,point=0.2}
    function a:GetName() return self.name end
    function a:IsHidden() return false end
    function a:IsFullyCastable() return self.ready end
    function a:GetManaCost() return self.cost end
    function a:GetSpecialValueFloat(key) return self.values[key] or 0 end
    function a:GetAbilityDamage() return self.damage or 0 end
    function a:GetCastRange() return self.range end
    function a:GetCastPoint() return self.point end
    function a:GetLevel() return 1 end
    function a:GetCooldownTimeRemaining() return self.cooldown or 0 end
    return a
end
local function hero(x)
    local h={x=x,visible=true,hp=2000,mana=300,range=500,abilities={},items={}}
    local function visible(self) assert(self.visible,'Hidden stats read') end
    function h:IsNull() return false end
    function h:IsAlive() return self.hp>0 end
    function h:CanBeSeen() return self.visible end
    function h:IsStunned() return self.stunned or false end
    function h:IsHexed() return false end
    function h:IsMagicImmune() visible(self); return self.immune or false end
    function h:IsAttackImmune() visible(self); return self.attackImmune or false end
    function h:IsSilenced() return self.silenced or false end
    function h:IsMuted() return self.muted or false end
    function h:HasModifier() return false end
    function h:GetUnitName() return 'npc_dota_hero_skeleton_king' end
    function h:GetMana() return self.mana end
    function h:GetAbilityByName(name) return self.abilities[name] end
    function h:GetItemInSlot(slot) return self.items[slot] end
    function h:GetAttackRange() return self.range end
    function h:GetCurrentMovementSpeed() return 300 end
    function h:GetAttributeValue() return 100 end
    function h:GetAttackDamage() return 100 end
    function h:GetSecondsPerAttack() return 1 end
    function h:GetSpellAmp() return 0 end
    function h:GetActualIncomingDamage(raw,kind)
        visible(self); return raw*(kind==DAMAGE_TYPE_PHYSICAL and 0.5 or kind==DAMAGE_TYPE_MAGICAL and 0.75 or 1)
    end
    function h:GetHealth() return self.hp end
    function h:GetMaxHealth() return 2000 end
    function h:GetEstimatedDamageToTarget(_,_,time) return (self.incoming or 50)*time end
    return h
end
local J={IsValidHero=function(h) return h~=nil and h:IsAlive() end,IsSuspiciousIllusion=function() return false end}
require('bots/Customize/shai').BehaviorTrace=false
local Budget=require('bots/FunLib/shai_combat_budget')
local bot,target
local function reset() bot,target=hero(0),hero(300) end
local function forecast(opts,context) return Budget.Member(bot,target,J,opts,context or {horizon=5}) end
reset(); local base=forecast(); assert(base.spells==0 and base.attacks>0,'Basic attacks are modeled without hypothetical spells')
bot.abilities.zuus_arc_lightning=ability('zuus_arc_lightning',100,{arc_damage=300})
bot.abilities.zuus_lightning_bolt=ability('zuus_lightning_bolt',100,{damage=400})
local both=forecast()
assert(both.spells>0 and both.mana==200 and both.attacks<base.attacks,'Nukes consume mana and casting time replaces attacks')
assert(math.abs(both.spells-700*0.75*0.75)<0.001,'Damage uses the victim resistance before the forecast reserve')
bot.mana=100; local one=forecast()
assert(one.mana==100 and one.spells<both.spells and one.rejected.zuus_lightning_bolt=='mana','A single mana pool cannot pay twice')
bot.abilities.zuus_arc_lightning.ready=false
assert(forecast().available.zuus_arc_lightning==nil,'Cooldown spells do not count')
reset(); bot.mana=100
local hex=ability('lion_voodoo',75)
bot.abilities.lion_voodoo=hex; bot.abilities.lion_finger_of_death=ability('lion_finger_of_death',100,{damage=850})
local reserved=forecast({{ability=hex,range=700}})
assert(reserved.available.lion_voodoo and reserved.control==1 and reserved.spells==0 and reserved.mana==75,
    'Opening control is funded before optional damage')
bot.mana=300
local utility=forecast({{ability=hex,range=700}},{horizon=5,controlsOnly=true})
assert(utility.attacks==0 and utility.spells==0 and utility.available.lion_finger_of_death==nil,
    'A wounded utility-only participant does not promise optional nukes or an attack chase')
reset(); bot.mana=100; bot.abilities.skeleton_king_reincarnation=ability('skeleton_king_reincarnation',100)
local stun=ability('skeleton_king_hellfire_blast',75,{damage=140}); bot.abilities.skeleton_king_hellfire_blast=stun
assert(forecast({{ability=stun,range=700}}).available.skeleton_king_hellfire_blast==nil,'Forecast respects WK revival mana reservation')
function bot:HasModifier(m) return m=='modifier_skeleton_king_reincarnation_scepter_active' end
J.GetModifierTime=function() return 2 end
local ghost=forecast({{ability=stun,range=700}})
assert(ghost.available.skeleton_king_hellfire_blast and ghost.mana==75,'Temporary WK can spend mana on stun even with a ready R')
J.GetModifierTime=function() return 0 end
assert(forecast().total==0,'Unknown/expired ghost lifetime does not promise future group damage')
reset(); bot.abilities.lion_finger_of_death=ability('lion_finger_of_death',100,{damage=850})
assert(forecast(nil,{horizon=5,bkb=true}).spells==0,'Ready BKB cannot be ignored by a magic damage forecast')
assert(forecast(nil,{horizon=5,bkb=true,caught=true}).spells>0,'Caught BKB owner is a different opportunity')
assert(forecast(nil,{horizon=5,block=true}).spells==0,'No assumed targeted nuke through spell block')
target.x=3000; assert(forecast().total==0,'Walking beyond the fight window adds no promised damage')
assert(forecast(nil,{horizon=5,future=true}).spells>0,'Gathering forecast explicitly evaluates a future engage position')
reset(); bot.silenced=true; bot.items[0]=ability('item_dagon_5',100,{damage=800})
-- Engine internal names omit the underscore before the level.
bot.items[0].name='item_dagon5'
assert(forecast().spells>0 and forecast().control==0,'Active Dagon adds damage without inventing an extra stun; silence permits items')
bot.muted=true; assert(forecast().spells==0,'Muted offensive item is unavailable')
reset(); local edge=ability('centaur_double_edge',100,{edge_damage=300,strength_damage=100}); bot.abilities.centaur_double_edge=edge
bot.hp=1000; assert(forecast().rejected.centaur_double_edge=='self-damage','Suicidal Double Edge is not budgeted')
reset(); bot.abilities.warlock_rain_of_chaos=ability('warlock_rain_of_chaos',200,{golem_dmg=150})
local golem=forecast(); assert(golem.spells==0 and golem.summons>0 and golem.summons<=150,'Golem is capped physical follow-up, not a fictitious initial magic nuke')
reset(); bot.abilities.witch_doctor_death_ward=ability('witch_doctor_death_ward',200,{damage=100})
assert(forecast().summons==0,'Free-moving enemy gives no promised full channel damage')
local ward=forecast(nil,{horizon=5,controlSeconds=3})
assert(ward.summons==225 and ward.attacks<base.attacks,'Controlled Ward uses pure damage and its channel replaces own attacks')
assert(forecast(nil,{horizon=5,controlSeconds=3,backups=1}).summons==0,'Nearby enemy backup invalidates promised safe channel')
target.attackImmune=true; assert(forecast(nil,{horizon=5,controlSeconds=3}).summons==0,'Attack immunity prevents Ward credit')
reset(); bot.abilities.zuus_arc_lightning=ability('zuus_arc_lightning',100,{arc_damage=300})
local human=forecast(nil,{horizon=5,attacksOnly=true}); assert(human.spells==0 and human.mana==0,'Nearby human attack does not promise a spell combo')
bot.stunned=true; assert(forecast().total==0,'Incapacitated contributor is not immediately ready')
target.visible=false; assert(forecast().total==0,'No reads of hidden victim stats')
print('PASS: funded combat forecast, cast/attack time, revival mana, cooldowns/items, defenses/range/fog, self-damage and bounded summons')
