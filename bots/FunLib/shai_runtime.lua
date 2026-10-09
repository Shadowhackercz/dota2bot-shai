-- Diagnostics must never throw a second error while reporting the first one.
local X={}
local printed={}
function X.Report(bot,source,err)
    local now=DotaTime()
    local key=source..':'..tostring(bot~=nil and bot:GetPlayerID() or '-')
    if now-(printed[key] or -math.huge)<5 then return end
    printed[key]=now
    print('[SHAI] runtime t='..tostring(now)..'; source='..source..'; error='..tostring(err))
end
function X.Call(bot,source,callback,fallback)
    local ok,result,b,c,d=xpcall(callback,function(err)
        local message=tostring(err)
        if debug~=nil and type(debug.traceback)=='function' then message=debug.traceback(message,2) end
        return message
    end)
    if not ok then X.Report(bot,source,result); return fallback end
    return result,b,c,d
end
function X.Location(bot,source,loc)
    local kind=type(loc)
    if (kind=='table' or kind=='userdata') and loc.x~=nil and loc.y~=nil then return true end
    X.Report(bot,source,'missing location'); return false
end
return X
