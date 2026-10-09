-- Diagnostics must never throw a second error while reporting the first one.
local X={}
local printed={}
local function Message(err)
    local ok,value=pcall(tostring,err)
    return ok and value or '<unprintable error>'
end
local function Stack(message,level)
    if debug~=nil and type(debug.traceback)=='function' then
        local ok,value=pcall(debug.traceback,message,level)
        if ok and type(value)=='string' then return value end
    end
    return message
end
function X.Report(bot,source,err)
    local now=DotaTime()
    local id='-'
    if bot~=nil then
        local ok,value=pcall(function() return bot:GetPlayerID() end)
        if ok then id=Message(value) end
    end
    local key=source..':'..id
    if now-(printed[key] or -math.huge)<5 then return end
    printed[key]=now
    print('[SHAI] runtime t='..tostring(now)..'; source='..source..'; error='..Message(err))
end
function X.Call(bot,source,callback,fallback)
    local ok,result,b,c,d=xpcall(callback,function(err)
        return Stack(Message(err),2)
    end)
    if not ok then X.Report(bot,source,result); return fallback end
    return result,b,c,d
end
function X.Location(bot,source,loc)
    local kind=type(loc)
    local function Finite(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
    if kind=='table' or kind=='userdata' then
        local ok,valid=pcall(function() return Finite(loc.x) and Finite(loc.y) and (loc.z==nil or Finite(loc.z)) end)
        if ok and valid then return true end
    end
    X.Report(bot,source,Stack('missing or invalid location',3)); return false
end
return X
