-- One short reservation per visible target; damage keeps flowing while a
-- control projectile lands. Entity fields also work across separate bot VMs.
local X={}
local instant={lion_voodoo=true,item_sheepstick=true,item_orchid=true,item_bloodthorn=true}
local speedKeys={lion_impale='speed',skeleton_king_hellfire_blast='blast_speed',sven_storm_bolt='bolt_speed',
    dragon_knight_dragon_tail='projectile_speed',vengefulspirit_magic_missile='magic_missile_speed',
    witch_doctor_paralyzing_cask='speed',tidehunter_ravage='speed'}
function X.Delay(bot,target,a,kind)
    local travel=0
    if not instant[a:GetName()] and (kind~='self' or a:GetName()=='tidehunter_ravage') then
        local key=speedKeys[a:GetName()]
        local speed=key and a:GetSpecialValueFloat(key) or 0
        travel=GetUnitToUnitDistance(bot,target)/(speed>0 and speed or 900)
    end
    if a:GetName()=='warlock_rain_of_chaos' then travel=a:GetSpecialValueFloat('stun_delay') end
    return a:GetCastPoint()+travel+0.12
end
function X.Pending(bot,target)
    local r=bot.shaiControlReservation
    return r~=nil and r.target==target and DotaTime()>=r.created and DotaTime()<r.untilTime and r or nil
end
function X.Remaining(target,J)
    local remaining=J.GetRemainStunTime and J.GetRemainStunTime(target) or 0
    if target:IsHexed() and J.GetModifierTime then
        for _,name in ipairs({'modifier_lion_voodoo','modifier_sheepstick_debuff'}) do
            remaining=math.max(remaining,J.GetModifierTime(target,name))
        end
    end
    return remaining
end
function X.Wait(bot,target,J,a,kind)
    if X.Pending(bot,target)~=nil then return true end
    if not J.IsDisabled(target) then return false end
    local remaining=X.Remaining(target,J)
    -- Unknown disable duration: don't pretend it will expire just now.
    return remaining<=0 or remaining>X.Delay(bot,target,a,kind)+0.12
end
function X.Reserve(bot,target,a,kind,members)
    local r={owner=bot,target=target,created=DotaTime(),untilTime=DotaTime()+X.Delay(bot,target,a,kind)}
    for _,h in ipairs(members) do h.shaiControlReservation=r end
    bot.shaiControlReservation=r
    return r
end
return X
