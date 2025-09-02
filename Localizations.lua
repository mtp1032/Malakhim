-- Localizations.lua
-- UPDATED: 29 Aug 2025

Malakhim = Malakhim or {}
Malakhim.Localizations = Malakhim.Localizations or {}

-- Make sure the previous file was loaded.
if not Malakhim.Core.loaded then
    DEFAULT_CHAT_FRAME:AddMessage( "Core.lua not loaded.", 1, 0, 0 )
    return
end
local core = Malakhim.Core

local addonName, addonVersion, addonExpansion = core:getAddonInfo()
local L = setmetatable({}, { __index = function(t, k) 
    local v = tostring(k)
    rawset(t, k, v)
    return v
end })

Malakhim.Localizations.L = L

local LOCALE= GetLocale()
if LOCALE == "enUS" or LOCALE == "enGB" then
    local addonLoadedMessage = string.format("%s v%s (%s)", addonName, addonVersion, addonExpansion )
    L["ADDON_LOADED_MESSAGE"] = addonLoadedMessage
end


Malakhim.Localizations.loaded = true
