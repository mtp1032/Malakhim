-- EventHandler.lua (Malakhim)
-- UPDATED: 29 Aug 2025
-- Lua 5.0 / Classic 1.12-friendly

Malakhim = Malakhim or {}
Malakhim.EventHandler = Malakhim.EventHandler or {}

if not Malakhim.ScrollMessage.loaded then
    DEFAULT_CHAT_FRAME:AddMessage( "ScrollMessage.lua not loaded.", 1, 0, 0 ) -- @@ Localize
    return
end

local core   = Malakhim.Core
local scroll = Malakhim.ScrollMessage
local L      = Malakhim.Localizations.L

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_SKILL")             -- localized text
f:RegisterEvent("CHAT_MSG_LOOT")              -- localized text


f:SetScript("OnEvent", function()
    local e  = event
    local a1 = arg1
    local addonName = core:getAddonInfo()

    if e == "ADDON_LOADED" and a1 == addonName then
        DEFAULT_CHAT_FRAME:AddMessage( L["ADDON_LOADED_MESSAGE"], 0, 1, 0  )
        f:UnregisterEvent( "ADDON_LOADED")
        return
    end

if e == "CHAT_MSG_SKILL" or e == "CHAT_MSG_LOOT" then
    scroll:message( e, a1 )
end
end)

Malakhim.EventHandler.loaded = true
