-- Compatibility entry for engines that still schedule the old side-shop mode.
local bot=GetBot()
if bot==nil then return end
local Tormentor=require(GetScriptDirectory()..'/FunLib/shai_tormentor')
local Runtime=require(GetScriptDirectory()..'/FunLib/shai_runtime')
function GetDesire() return Tormentor.GetDesire() end
function Think() Runtime.Call(bot,'tormentor.think',Tormentor.Think,nil) end
function OnEnd() Tormentor.OnEnd() end
return Tormentor
