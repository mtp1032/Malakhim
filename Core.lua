-- Core.lua
-- CREATED: 31 August, 2025

Malakhim = Malakhim or {}
Malakhim.Core = Malakhim.Core or {}
local core = Malakhim.Core

local addonName = "Malakhim"
local addonVersion = GetAddOnMetadata( addonName, "Version" )
local addonExpansion = GetAddOnMetadata( addonName, "X-Expansion" )
print( addonName, addonVersion, addonExpansion )


-- Public API: always returns (AddonName, AddonTitle, Version, Expansion)
function core:getAddonInfo()
    return addonName, addonVersion, addonExpansion
end

Malakhim.Core.loaded = true

