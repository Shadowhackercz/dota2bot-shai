-- A funded, useful Earth Spike from the current position, not a circular AoE.
local X={}
local Farm=require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local Memory=require(GetScriptDirectory()..'/FunLib/shai_threat_memory')
local Safety=require(GetScriptDirectory()..'/FunLib/shai_cast_safety')
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local function Visible(h)
    return h~=nil and not h:IsNull() and h:CanBeSeen() and h:IsAlive()
end
local function Trace(bot,reason,p)
    if not SHAI.BehaviorTrace or reason~='lion-spike' and DotaTime()-(bot.shaiLionFarmPrinted or -math.huge)<3 then return end
    bot.shaiLionFarmPrinted=DotaTime(); p=p or {}
    print('[SHAI] farm-spell t='..DotaTime()..'; hero='..bot:GetUnitName()..'; reason='..reason..'; hits='..(p.count or '-')
        ..'; damage='..(p.damage or '-')..'; reserve='..(p.reserve or '-'))
end
function X.GetPlan(bot,J,q)
    if q==nil or q:IsHidden() or not q:IsFullyCastable() or q:GetLevel()<2
        or J.CanNotUseAbility(bot) or bot:IsInvisible() or J.IsRetreating(bot)
        or not (J.IsFarming(bot) or J.IsPushing(bot) or J.IsDefending(bot)) then return nil end
    -- A creep clear never takes priority over a real hero target or local danger.
    local target=J.GetProperTarget(bot)
    if target~=nil and target:CanBeSeen() and J.IsValidHero(target) then return nil end
    if bot:GetHealth()<bot:GetMaxHealth()*0.45 or bot:WasRecentlyDamagedByAnyHero(3)
        or Farm.GetThreat(bot,J)~=nil or Memory.GetConcern(bot,J,bot:GetLocation())~=nil then
        Trace(bot,'unsafe-farm'); return nil
    end
    for _,h in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if Visible(h) and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
            and GetUnitToUnitDistance(bot,h)<1600 then Trace(bot,'preserve-control-near-hero'); return nil end
    end
    for _,tower in pairs(bot:GetNearbyTowers(1600,true)) do
        if Visible(tower) and (tower:GetAttackTarget()==bot
            or GetUnitToUnitDistance(bot,tower)<tower:GetAttackRange()+100) then Trace(bot,'tower-danger'); return nil end
    end
    local reserve=100
    for _,name in ipairs({'lion_voodoo','lion_finger_of_death'}) do
        local a=bot:GetAbilityByName(name)
        if a~=nil and a:GetLevel()>0 and not a:IsHidden() and a:IsFullyCastable() then reserve=reserve+a:GetManaCost() end
    end
    if bot:GetMana()-q:GetManaCost()<reserve then Trace(bot,'reserve-control-mana',{reserve=reserve}); return nil end
    if not Safety.Allow(bot,J,q,'farm') then return nil end
    local origin=bot:GetLocation()
    if not Runtime.Location(bot,'lion-farm.origin',origin) then return nil end
    local range=math.max(0,q:GetCastRange()-25)
    local width=q:GetSpecialValueInt('width')
    local speed=q:GetSpecialValueInt('speed')
    local damage=q:GetSpecialValueInt('damage')*(1+bot:GetSpellAmp())
    if range<=0 or width<=0 or speed<=0 or damage<=0 then return nil end
    local creeps,seen={},{}
    local function Add(list)
        for _,c in pairs(list) do
            if not seen[c] and Visible(c) and not c:IsInvulnerable() and not c:IsMagicImmune()
                and not c:HasModifier('modifier_fountain_glyph') then
                local distance=GetUnitToUnitDistance(bot,c)
                if distance<=range then
                    local p=c:GetExtrapolatedLocation(q:GetCastPoint()+distance/speed)
                    if Runtime.Location(bot,'lion-farm.creep',p) then
                        local dx,dy=p.x-origin.x,p.y-origin.y
                        if dx*dx+dy*dy<=range*range then
                            seen[c]=true; creeps[#creeps+1]={unit=c,location=p}
                        end
                    end
                end
            end
        end
    end
    if J.IsFarming(bot) then Add(bot:GetNearbyNeutralCreeps(range)) end
    Add(bot:GetNearbyLaneCreeps(range,true))
    local best
    for _,candidate in ipairs(creeps) do
        local dx,dy=candidate.location.x-origin.x,candidate.location.y-origin.y
        local distance=math.sqrt(dx*dx+dy*dy)
        if distance>1 then
            local ux,uy=dx/distance,dy/distance
            local count,effective=0,0
            for _,c in ipairs(creeps) do
                local x,y=c.location.x-origin.x,c.location.y-origin.y
                local along=x*ux+y*uy
                -- Count only the conservative straight strip, without guessing
                -- cone talents, hull padding or the beyond-cast-range buffer.
                if along>=0 and along<=range and math.abs(x*uy-y*ux)<=width*0.75 then
                    local dealt=math.min(c.unit:GetHealth(),c.unit:GetActualIncomingDamage(damage,DAMAGE_TYPE_MAGICAL))
                    if dealt>0 then count=count+1; effective=effective+dealt end
                end
            end
            if count>=2 and effective>=bot:GetAttackDamage()*2.5 and (best==nil or effective>best.damage) then
                best={location=candidate.location,count=count,damage=effective,reserve=reserve}
            end
        end
    end
    if best==nil and #creeps>=2 then Trace(bot,'no-useful-line') end
    return best
end
function X.Trace(bot,p)
    Trace(bot,'lion-spike',p)
end
return X
