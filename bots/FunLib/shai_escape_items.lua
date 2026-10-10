-- Prioritize existing self-save considerations in a freshly blocked escape.
local X={}
local Farm=require(GetScriptDirectory()..'/FunLib/shai_farm_safety')
local Escape=require(GetScriptDirectory()..'/FunLib/shai_escape_route')
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
local SHAI=require(GetScriptDirectory()..'/Customize/shai')
X.Holding=Escape.HoldingSave
function X.Try(bot,J,consider,use)
    if X.Holding(bot) then return true end
    local now=DotaTime()
    if bot.shaiEscapeBlockedAt==nil or bot.shaiEscapeChecked==nil
        or now<bot.shaiEscapeChecked or now-bot.shaiEscapeChecked>0.75
        or J.CanNotUseAction(bot) or bot:IsMuted() or bot:IsInvisible()
        or bot:HasModifier('modifier_skeleton_king_reincarnation_scepter_active') then return false end
    if Farm.GetThreat(bot,J)==nil then return false end
    local physical,magical=0,0
    for _,enemy in ipairs(J.GetNearbyHeroes(bot,1000,true,BOT_MODE_NONE)) do
        if not enemy:IsNull() and enemy:CanBeSeen() and J.IsValidHero(enemy)
            and not J.IsSuspiciousIllusion(enemy) and enemy:IsAlive() then
            physical=physical+enemy:GetEstimatedDamageToTarget(true,bot,1,DAMAGE_TYPE_PHYSICAL)
            magical=magical+enemy:GetEstimatedDamageToTarget(true,bot,1,DAMAGE_TYPE_MAGICAL)
        end
    end
    -- Avoid preferring ethereal protection in a mixed/magical threat. This is
    -- a conservative engine estimate, not a complete simulation of enemy spells.
    local ghostSafe=physical>=bot:GetHealth()*0.25 and magical<bot:GetHealth()*0.1 and physical>magical*4
    local names=ghostSafe and {'item_ghost','item_glimmer_cape'} or {'item_glimmer_cape'}
    for _,name in ipairs(names) do
        for slot=0,5 do
            local item=bot:GetItemInSlot(slot)
            if item~=nil and item:GetName()==name and J.CanCastAbility(item) and consider[name]~=nil then
                local desire,target,cast=Runtime.Call(bot,'escape-item.'..name,function() return consider[name](item) end,0)
                -- The original Glimmer logic can also save allies. This phase
                -- only prioritizes self saves, not an unrelated ally suggestion.
                if desire>0 and (name=='item_ghost' and cast=='none' or name=='item_glimmer_cape' and target==bot and cast=='unit')
                    and use(item,target,cast) then
                    bot.shaiEscapeSave={created=now,expires=now+math.min(0.7,math.max(0.2,item:GetCastPoint()+0.2))}
                    if SHAI.BehaviorTrace then print('[SHAI] escape-item t='..now..'; hero='..bot:GetUnitName()..'; reason=blocked-self-save; item='..name..'; physical='..physical..'; magical='..magical) end
                    return true
                end
            end
        end
    end
    return false
end
return X
