-- Team vision snapshots. A hidden handle is used only for visibility checks;
-- position, HP, damage, level and movement speed come from the last observation.
local X={}
local lifetime=10
local function Visible(h,J)
    return h~=nil and not h:IsNull() and h:CanBeSeen() and J.IsValidHero(h) and not J.IsSuspiciousIllusion(h)
end
local function Owner(bot)
    local owner=bot
    for slot=1,5 do
        local h=GetTeamMember(slot)
        -- Keep the entity of a dead teammate eligible so his death doesn't
        -- discard the team's knowledge. Live bots can still update its fields.
        if h~=nil and not h:IsNull() and h:IsBot() and h:GetPlayerID()<owner:GetPlayerID() then owner=h end
    end
    return owner
end
function X.Observe(bot,J)
    if DotaTime()<600 then return nil end -- preserve existing opening decisions
    local now=DotaTime()
    local owner=Owner(bot)
    local state=owner.shaiThreatMemory
    if state==nil or now<state.checked then
        state={checked=-math.huge,entries={}}
        owner.shaiThreatMemory=state
    end
    if now-state.checked<0.25 then return state end
    state.checked=now
    for key,entry in pairs(state.entries) do
        if now-entry.seenAt>=lifetime or entry.unit:IsNull() then state.entries[key]=nil end
    end
    for _,h in pairs(GetUnitList(UNIT_LIST_ENEMY_HEROES)) do
        if Visible(h,J) then
            local p=h:GetLocation()
            if p~=nil and type(p.x)=='number' and type(p.y)=='number' and type(p.z)=='number' then
                state.entries[h:GetPlayerID()]={unit=h,name=h:GetUnitName(),seenAt=now,
                    location=Vector(p.x,p.y,p.z),hp=h:GetHealth(),level=h:GetLevel(),
                    speed=math.min(650,math.max(0,h:GetCurrentMovementSpeed())),range=h:GetAttackRange(),
                    attackDamage=h:GetAttackDamage(),attackInterval=math.max(0.2,h:GetSecondsPerAttack())}
            end
        elseif h~=nil and not h:IsNull() and h:CanBeSeen() then
            -- A confirmed death/invalid real unit supersedes its old snapshot.
            -- An illusion sharing a player ID must not erase the real hero.
            local entry=state.entries[h:GetPlayerID()]
            if entry~=nil and entry.unit==h then state.entries[h:GetPlayerID()]=nil end
        end
    end
    return state
end
function X.GetConcern(bot,J,location)
    local state=X.Observe(bot,J)
    if state==nil or location==nil or not bot:IsAlive() then return nil end
    local best
    for _,entry in pairs(state.entries) do
        if not entry.unit:IsNull() and not entry.unit:CanBeSeen() then
            local age=DotaTime()-entry.seenAt
            local confidence=math.max(0,1-age/lifetime)
            local damage=bot:GetActualIncomingDamage(entry.attackDamage*2/entry.attackInterval,DAMAGE_TYPE_PHYSICAL)
            -- A mage's complete burst isn't reconstructed from hidden spells.
            -- A large observed level gap remains a separate conservative signal.
            local dominant=entry.hp>bot:GetAttackDamage()*4 and
                (entry.level>=bot:GetLevel()+5 or damage>=math.max(200,bot:GetHealth()*0.55) and entry.level>bot:GetLevel())
            if dominant and confidence>=0.45 then
                local uncertainty=math.min(1200,entry.speed*age*0.65)
                local radius=math.min(1800,entry.range+250+uncertainty)
                local dx,dy=location.x-entry.location.x,location.y-entry.location.y
                local distance=math.sqrt(dx*dx+dy*dy)
                if distance<=radius then
                    local severity=math.max(damage/math.max(1,bot:GetHealth()),(entry.level-bot:GetLevel())/10)*confidence
                    if best==nil or severity>best.severity then
                        best={location=Vector(entry.location.x,entry.location.y,entry.location.z),name=entry.name,
                            reason='remembered-farm-threat',severity=severity,confidence=confidence,age=age,
                            uncertainty=uncertainty,radius=radius,seenAt=entry.seenAt,memory=true}
                    end
                end
            end
        end
    end
    return best
end
return X
