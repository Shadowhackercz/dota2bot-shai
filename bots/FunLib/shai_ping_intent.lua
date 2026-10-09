-- Two observed fresh normal pings form a request; a single ping is information.
local X={}
local function Location(p)
    return p~=nil and type(p.x)=='number' and type(p.y)=='number' and type(p.z)=='number'
        and p.x==p.x and p.y==p.y and math.abs(p.x)<100000 and math.abs(p.y)<100000 and math.abs(p.z)<100000
end
function X.Poll(bot,J)
    local now=GameTime()
    local s=bot.shaiPingIntent
    if s==nil or now<s.checked then s={checked=now,humans={}}; bot.shaiPingIntent=s end
    s.checked=now
    local newest
    for slot=1,5 do
        local h=GetTeamMember(slot)
        if h~=nil and J.IsValidHero(h) and h:IsAlive() and not h:IsBot() then
            local p=h:GetMostRecentPing()
            if p~=nil and type(p.time)=='number' and p.time>0 and now>=p.time and now-p.time<=3 and Location(p.location) then
                local id=h:GetPlayerID()
                local old=s.humans[id]
                if old==nil or p.time~=old.time then
                    if p.normal_ping and old and old.normal and p.time>old.time and p.time-old.time<=1.5
                        and J.GetDistance(p.location,old.location)<=400 then
                        if newest==nil or p.time>newest.time then
                            newest={location=Vector(p.location.x,p.location.y,p.location.z),time=p.time,player=id,expires=p.time+5}
                        end
                    end
                    s.humans[id]={time=p.time,normal=p.normal_ping,location=Vector(p.location.x,p.location.y,p.location.z)}
                end
            end
        end
    end
    return newest
end
return X
