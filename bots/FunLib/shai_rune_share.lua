-- A short opportunity for an approaching Bottle owner, never an indefinite claim.
local X={}
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
local function Bottle(h)
    local slot=h:FindItemSlot('item_bottle')
    if slot<0 or slot>5 then return nil end
    return h:GetItemInSlot(slot)
end
function X.Yield(bot,J,rune,location)
    bot.shaiBottleShare=bot.shaiBottleShare or {}
    local now=DotaTime()
    local cycle=math.floor(now/120)
    if now<0 or (rune~=RUNE_POWERUP_1 and rune~=RUNE_POWERUP_2)
        or GetRuneStatus(rune)~=RUNE_STATUS_AVAILABLE then bot.shaiBottleShare[rune]=nil; return false end
    local own=Bottle(bot)
    local water=GetRuneType(rune)==RUNE_WATER
    if own and (not water or own:GetCurrentCharges()<3) or J.GetHP(bot)<0.35 then return false end
    if #J.GetEnemiesNearLoc(location,1200)>0 or #J.GetLastSeenEnemiesNearLoc(location,1200)>0 then return false end
    local chosen,best
    for slot=1,5 do
        local h=GetTeamMember(slot)
        if h~=nil and h~=bot and J.IsValidHero(h) and h:IsAlive() and not J.IsSuspiciousIllusion(h) then
            local bottle=Bottle(h)
            if bottle and (not water or bottle:GetCurrentCharges()<3) then
                local distance=GetUnitToLocationDistance(h,location)
                local action=h:GetCurrentActionType()
                local approaching=action==BOT_ACTION_TYPE_PICK_UP_RUNE
                    or action==BOT_ACTION_TYPE_MOVE_TO and h:IsFacingLocation(location,30)
                    or h:IsBot() and h:GetActiveMode()==BOT_MODE_RUNE and h:IsFacingLocation(location,30)
                if distance<=900 and distance/math.max(1,h:GetCurrentMovementSpeed())<=2.5 and approaching
                    and not h:IsChanneling() and not h:IsStunned() and not h:IsHexed() and not h:IsRooted()
                    and J.GetHP(h)>=0.35 and (chosen==nil or distance<best) then chosen,best=h,distance end
            end
        end
    end
    if chosen==nil then return false end
    local lease=bot.shaiBottleShare[rune]
    if lease==nil or lease.cycle~=cycle or now<lease.created then
        lease={created=now,expires=now+3,cycle=cycle}; bot.shaiBottleShare[rune]=lease
    end
    if now>=lease.expires then return false end -- another ally cannot extend the same opportunity
    if SHAI.BehaviorTrace and not lease.printed then
        lease.printed=true
        print('[SHAI] rune-share t='..now..'; hero='..bot:GetUnitName()..'; reason=bottle-approach; target='..chosen:GetUnitName()..'; rune='..rune..'; until='..lease.expires)
    end
    return true
end
return X
