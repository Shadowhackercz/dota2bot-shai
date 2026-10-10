-- Short post-river return, not a replacement for ordinary lane micro.
local X={}
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
local Route=require(GetScriptDirectory()..'/FunLib/shai_route_safety')
local Safety=require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local function Distance(a,b) return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
function X.Arm(bot,J,rune)
    local now=DotaTime()
    if not bot:IsAlive() or now<0 or now>600 or J.GetPosition(bot)~=2
        or rune~=RUNE_POWERUP_1 and rune~=RUNE_POWERUP_2 then return end
    local origin,spot=bot:GetLocation(),GetRuneSpawnLocation(rune)
    if not Runtime.Location(bot,'rune-return.origin',origin) or not Runtime.Location(bot,'rune-return.spot',spot)
        or Distance(origin,spot)>650 then return end
    bot.shaiRuneReturn={created=now,progressAt=now,best=math.huge}
end
function X.GetDesire(bot,J)
    local p=bot.shaiRuneReturn
    if p==nil then return nil end
    local now=DotaTime()
    if not bot:IsAlive() or now<p.created or now-p.created>20 or now-p.progressAt>6
        or J.GetPosition(bot)~=2 then bot.shaiRuneReturn=nil; return nil end
    -- Do not turn a fresh nearby fight into mandatory travel back to creeps.
    if J.IsInTeamFight(bot,1200) or bot:WasRecentlyDamagedByAnyHero(2) then return nil end
    local destination=GetLaneFrontLocation(bot:GetTeam(),bot:GetAssignedLane(),-600)
    local origin=bot:GetLocation()
    if not Runtime.Location(bot,'rune-return.lane',destination) or not Runtime.Location(bot,'rune-return.origin',origin) then
        bot.shaiRuneReturn=nil; return nil
    end
    local distance=Distance(origin,destination)
    if distance<=450 then bot.shaiRuneReturn=nil; return nil end
    if distance<p.best-60 then p.best=distance; p.progressAt=now end
    p.destination=destination
    return 1.01
end
function X.Think(bot,J)
    if X.GetDesire(bot,J)==nil then return false end
    if J.CanNotUseAction(bot) or bot:IsCastingAbility() or bot:IsUsingAbility()
        or bot:GetCurrentActionType()==BOT_ACTION_TYPE_PICK_UP_RUNE then return true end
    if Safety.GetThreat(bot,J)~=nil then
        bot.shaiEscapeUntil=DotaTime()+0.75
        Safety.InterruptFarm(bot,J)
        return true
    end
    bot:SetTarget(nil)
    Route.Move(bot,J,bot.shaiRuneReturn.destination,'rune-return')
    return true
end
return X
