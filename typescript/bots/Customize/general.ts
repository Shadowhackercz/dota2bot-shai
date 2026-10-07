// Re-export the hand-written Lua module. SHAI defaults (including no GPT chat)
// live in bots/Customize/general.lua; this wrapper does not generate settings.
const CustomizeLua = require("../../../bots/Customize/general");
export = CustomizeLua;
