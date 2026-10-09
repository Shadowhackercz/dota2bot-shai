-- Player vetoes only voluntary objective plans; combat/escape callbacks remain active.
local X = {}
local names={roshan='Roshan',tormentor='Tormentor'}
local fields={roshan='shaiRoshanVeto',tormentor='shaiTormentorVeto'}
local function Real(h)
    return h~=nil and not h:IsNull() and h:IsHero() and not h:IsIllusion()
end
function X.IsBlocked(bot,objective)
    local key=fields[objective]
    if key==nil then return false end
    local state=bot[key]
    if state==nil then return false end
    local now=DotaTime()
    if GetGameState()~=GAME_STATE_GAME_IN_PROGRESS or now<state.issued or now>=state.untilTime then
        bot[key]=nil
        return false
    end
    return true
end

function X.Handle(bot,J,chat)
    local text=string.lower(chat.string or ''):match('^%s*(.-)%s*$')
    local objective=text:match('^!stop%s+(%a+)$')
    if objective=='rosh' then objective='roshan' end
    if text~='!normal' and objective~='roshan' and objective~='tormentor' and objective~='objectives' then return false end
    if GetGameState()~=GAME_STATE_GAME_IN_PROGRESS or chat.player_id==nil
        or IsPlayerBot(chat.player_id) or GetTeamForPlayer(chat.player_id)~=bot:GetTeam() then return true end
    local units,leader,fallback=GetUnitList(UNIT_LIST_ALLIED_HEROES),nil,nil
    for _,h in pairs(units) do
        if Real(h) and IsPlayerBot(h:GetPlayerID()) then
            if fallback==nil or h:GetPlayerID()<fallback:GetPlayerID() then fallback=h end
            if h:IsAlive() and (leader==nil or h:GetPlayerID()<leader:GetPlayerID()) then leader=h end
        end
    end
    leader=leader or fallback -- A team wipe must not discard an instruction for the next respawn.
    if leader~=bot then return true end
    local now=DotaTime()
    local signature=tostring(chat.player_id)..':'..text
    if bot.shaiObjectiveCommandSignature==signature and bot.shaiObjectiveCommandAt~=nil
        and now>=bot.shaiObjectiveCommandAt and now-bot.shaiObjectiveCommandAt<1 then return true end
    bot.shaiObjectiveCommandSignature,bot.shaiObjectiveCommandAt=signature,now
    for _,h in pairs(units) do
        -- Include dead bots so a respawn within the veto window keeps the instruction.
        if Real(h) and IsPlayerBot(h:GetPlayerID()) then
            if text=='!normal' then h.shaiRoshanVeto,h.shaiTormentorVeto=nil,nil
            else
                for key,field in pairs(fields) do
                    if objective=='objectives' or objective==key then
                        h[field]={issued=now,untilTime=now+60}
                        if key=='roshan' then h.shaiRoshanRequestUntil,h.shaiRoshanParticipants=nil,nil end
                    end
                end
            end
        end
    end
    local reply=text=='!normal' and 'Objective vetoes cleared. Normal decisions resumed.'
        or ((objective=='objectives' and 'Roshan and Tormentor' or names[objective])..' paused for 60 seconds. Use !normal to resume.')
    bot:ActionImmediate_Chat(reply,false)
    print(string.format('[SHAI] objective-command t=%.2f; player=%d; command=%s; until=%.2f',now,chat.player_id,text,
        text=='!normal' and now or now+60))
    return true
end

function X.ReleaseObjective(bot,J,objective)
    if objective==nil then
        -- Use the raw mode: the voluntary-objective helpers already respect the veto.
        if bot:GetActiveMode()==BOT_MODE_ROSHAN then objective='roshan'
        elseif bot:GetActiveMode()==BOT_MODE_SIDE_SHOP or bot:GetActiveMode()==BOT_MODE_TEAM_ROAM
            and bot.shaiTormentorActiveUntil~=nil and DotaTime()>=bot.shaiTormentorActiveUntil-0.75
            and DotaTime()<bot.shaiTormentorActiveUntil then objective='tormentor' end
    end
    if objective==nil or not X.IsBlocked(bot,objective) then return false end
    if J.CanNotUseAction(bot) then return true end -- Keep a spell, TP or channel already in progress.
    local target=J.GetProperTarget(bot)
    if target~=nil and J.IsValidHero(target) then return false end -- Preserve contact with an enemy hero.
    bot:SetTarget(nil)
    local destination=J.GetTeamFountain()
    if target~=nil and J.IsValid(target) and (J.IsRoshan(target) or J.IsTormentor(target)) then
        local origin,loc=bot:GetLocation(),target:GetLocation()
        if (origin.x-loc.x)^2+(origin.y-loc.y)^2>1 then
            local away=J.VectorAway(origin,loc,650)
            if IsLocationPassable(away) then destination=away end
        end
    end
    -- Replace the old objective movement/attack while the engine selects another mode.
    bot:Action_MoveToLocation(destination)
    return true
end
return X
