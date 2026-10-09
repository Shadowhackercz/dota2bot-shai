-- Shared fortification executor, including teams containing human players.
local X={}
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local function Heartbeat(bot,team,reason,cooldown)
    local now=DotaTime()
    if not SHAI.BehaviorTrace or bot.shaiGlyphTraceAt~=nil and now>=bot.shaiGlyphTraceAt and now-bot.shaiGlyphTraceAt<30 then return end
    bot.shaiGlyphTraceAt=now
    print(string.format('[SHAI] glyph t=%.2f; team=%s; hero=%s; reason=%s; cooldown=%s',
        now,tostring(team),bot:GetUnitName(),reason,tostring(cooldown)))
end
local function Valid(h) return h~=nil and not h:IsNull() end
local function Executor()
    local first,alive
    for slot=1,5 do
        local h=GetTeamMember(slot)
        if Valid(h) and h:IsBot() then
            if first==nil or h:GetPlayerID()<first:GetPlayerID() then first=h end
            if h:IsAlive() and (alive==nil or h:GetPlayerID()<alive:GetPlayerID()) then alive=h end
        end
    end
    return alive or first
end
function X.Try(bot,team)
    if DotaTime()<60 then return false end
    local leader=Executor()
    if leader~=bot then return false end
    if leader.shaiGlyphIssuedAt~=nil and DotaTime()>=leader.shaiGlyphIssuedAt and DotaTime()-leader.shaiGlyphIssuedAt<1 then return false end
    if leader.shaiGlyphCheckedAt~=nil and DotaTime()>=leader.shaiGlyphCheckedAt and DotaTime()-leader.shaiGlyphCheckedAt<0.25 then return false end
    leader.shaiGlyphCheckedAt=DotaTime()
    if type(GetGlyphCooldown)~='function' or type(bot.ActionImmediate_Glyph)~='function' then
        Heartbeat(bot,team,'api-unavailable','-'); return false
    end
    local cooldown=GetGlyphCooldown()
    if type(cooldown)~='number' or cooldown~=cooldown then
        Heartbeat(bot,team,'invalid-cooldown','-'); return false
    end
    if cooldown>0 then Heartbeat(bot,team,'cooldown',cooldown); return false end
    -- Vision and current attack orders only: don't infer a siege from hidden units.
    local attackers={}
    for _,kind in ipairs({UNIT_LIST_ENEMY_HEROES,UNIT_LIST_ENEMY_CREEPS}) do
        for _,h in pairs(GetUnitList(kind)) do
            if Valid(h) and h:IsAlive() and h:CanBeSeen() and not h:IsStunned() and not h:IsHexed() then attackers[#attackers+1]=h end
        end
    end
    local function Assess(building,kind)
        if not Valid(building) or not building:IsAlive() or not building:CanBeSeen() or building:IsInvulnerable() then return end
        local dps,count=0,0
        for _,h in ipairs(attackers) do
            if h:GetAttackTarget()==building and GetUnitToUnitDistance(h,building)<=h:GetAttackRange()+200 then
                dps=dps+building:GetActualIncomingDamage(h:GetAttackDamage(),DAMAGE_TYPE_PHYSICAL)/math.max(0.2,h:GetSecondsPerAttack())
                count=count+1
            end
        end
        if dps<=0 or count==0 then return end
        local fall=building:GetHealth()/dps
        local relief=false
        for slot=1,5 do
            local h=GetTeamMember(slot)
            if Valid(h) and h:IsAlive() and not h:IsStunned() and not h:IsHexed()
                and not h:HasModifier('modifier_teleporting') and h:GetHealth()>=h:GetMaxHealth()*0.4
                and GetUnitToUnitDistance(h,building)/math.max(200,h:GetCurrentMovementSpeed())<=4 then relief=true end
        end
        local urgent=fall<=6 or kind=='ancient' and fall<=10
        local rescue=fall<=12 and relief
        if urgent or rescue then return {building=building,kind=kind,fall=fall,dps=dps,count=count,reason=urgent and 'imminent-loss' or 'defense-window'} end
    end
    local best=Assess(GetAncient(team),'ancient')
    if best==nil then
        for _,index in ipairs({TOWER_TOP_1,TOWER_MID_1,TOWER_BOT_1,TOWER_TOP_2,TOWER_MID_2,TOWER_BOT_2,
            TOWER_TOP_3,TOWER_MID_3,TOWER_BOT_3,TOWER_BASE_1,TOWER_BASE_2}) do
            local p=Assess(GetTower(team,index),'tower')
            if p~=nil and (best==nil or p.fall<best.fall) then best=p end
        end
        for _,index in ipairs({BARRACKS_TOP_MELEE,BARRACKS_MID_MELEE,BARRACKS_BOT_MELEE}) do
            local p=Assess(GetBarracks(team,index),'barracks')
            if p~=nil and (best==nil or p.fall<best.fall) then best=p end
        end
    end
    if best==nil then Heartbeat(bot,team,'ready-no-siege',cooldown); return false end
    bot:ActionImmediate_Glyph()
    -- Replicate the short action reservation so executor failover cannot issue twice.
    for slot=1,5 do local h=GetTeamMember(slot); if Valid(h) and h:IsBot() then h.shaiGlyphIssuedAt=DotaTime() end end
    if SHAI.BehaviorTrace then
        print(string.format('[SHAI] glyph t=%.2f; hero=%s; reason=%s; building=%s; kind=%s; fall=%.2f; dps=%.0f; attackers=%d',
            DotaTime(),bot:GetUnitName(),best.reason,best.building:GetUnitName(),best.kind,best.fall,best.dps,best.count))
    end
    return true
end
return X
