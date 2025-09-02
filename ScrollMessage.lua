-- ScrollMessage.lua (Malakhim)
-- UPDATED: 01 Sep 2025
-- Lua 5.0 / Classic 1.12-friendly

Malakhim = Malakhim or {}
Malakhim.ScrollMessage = Malakhim.ScrollMessage or {}

if not Malakhim.Localizations.loaded then
    DEFAULT_CHAT_FRAME:AddMessage( "ScrollMessage.lua not loaded.", 1, 0, 0 ) -- @@ Localize
    return
end

local core   = Malakhim.Core or {}
local L   = Malakhim.Localizations or {}   -- don't hard-require
local scroll = Malakhim.ScrollMessage


----------------------------------------------------------------
-- Tuning knobs
----------------------------------------------------------------
-- SKILL: stationary at {+250, +300}
local SKILL_STARTX = 250
local SKILL_STARTY = 300
local SKILL_XDELTA = 0          -- px/frame (legacy)
local SKILL_YDELTA = 0          -- px/frame (legacy)

-- LOOT: scrolls vertically upward on the left
local LOOT_STARTX = -SKILL_STARTX
local LOOT_STARTY = 100
local LOOT_XDELTA = 0           -- px/frame (legacy)
local LOOT_YDELTA = 2           -- px/frame (legacy)

-- Visuals
local FONT_PATH  = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE  = 24
local FONT_FLAGS = "OUTLINE"
local TEXT_R, TEXT_G, TEXT_B = 1.0, 0.0, 0.0
local SHADOW_X, SHADOW_Y = 1, -1

-- Lifetime & spacing
local LIFETIME_SEC       = 3.0
local LINE_PAD           = 4
local MIN_SEPARATION_PX  = FONT_SIZE + LINE_PAD

----------------------------------------------------------------
-- Helpers: convert legacy "px/frame" to frame-rate independent px/s
----------------------------------------------------------------
local function ppf_to_pps(ppf)
    return (ppf or 0) * 60   -- tuned for ~60fps
end

----------------------------------------------------------------
-- Frame pool
----------------------------------------------------------------
local framePool = {}

local function createNewFrame()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(5, 5)
    f:SetPoint("CENTER", 0, 0)

    f.Text = f:CreateFontString(nil, "OVERLAY")
    f.Text:SetFont(FONT_PATH, FONT_SIZE, FONT_FLAGS)
    f.Text:SetPoint("CENTER")
    f.Text:SetTextColor(TEXT_R, TEXT_G, TEXT_B)
    f.Text:SetShadowOffset(SHADOW_X, SHADOW_Y)
    f.Text:SetText("")

    -- runtime fields
    f.fx, f.fy = 0, 0
    f.vx, f.vy = 0, 0
    f.t        = 0
    f.life     = LIFETIME_SEC

    return f
end

local function releaseFrame(f)
    f:SetScript("OnUpdate", nil)
    f.Text:SetText("")
    f:Hide()
    table.insert(framePool, f)
end

local function acquireFrame()
    local f = table.remove(framePool)
    if not f then f = createNewFrame() end
    f:Show()
    f:SetAlpha(1)
    return f
end

-- seed pool
do table.insert(framePool, createNewFrame()) end

----------------------------------------------------------------
-- Spawner & LOOT queue (prevents overlap when events burst)
----------------------------------------------------------------
local lootQueue, lootCooldown = {}, 0

local Spawner = CreateFrame("Frame")
Spawner:Show()
Spawner:SetScript("OnUpdate", function(_, dt)
    if lootCooldown > 0 then lootCooldown = lootCooldown - dt end
    if lootCooldown <= 0 and lootQueue[1] then
        local msg = table.remove(lootQueue, 1)

        local f = acquireFrame()
        f.fx, f.fy = LOOT_STARTX, LOOT_STARTY
        f.vx, f.vy = ppf_to_pps(LOOT_XDELTA), ppf_to_pps(LOOT_YDELTA)
        f.t, f.life = 0, LIFETIME_SEC

        f.Text:SetText(msg)
        f:ClearAllPoints(); f:SetPoint("CENTER", f.fx, f.fy)

        f:SetScript("OnUpdate", function(self, dt2)
            self.t  = self.t + dt2
            self.fx = self.fx + self.vx * dt2
            self.fy = self.fy + self.vy * dt2
            self:ClearAllPoints(); self:SetPoint("CENTER", self.fx, self.fy)

            local a = 1 - (self.t / self.life); if a < 0 then a = 0 end
            self:SetAlpha(a)

            if self.t >= self.life then
                releaseFrame(self)
            end
        end)

        local vy = math.abs(ppf_to_pps(LOOT_YDELTA)); if vy < 1 then vy = 1 end
        lootCooldown = MIN_SEPARATION_PX / vy
    end
end)

----------------------------------------------------------------
-- Start SKILL message (stationary fade; or moving if you set deltas)
----------------------------------------------------------------
local function startSkillMessage(msg)
    local f = acquireFrame()
    f.fx, f.fy = SKILL_STARTX, SKILL_STARTY
    f.vx, f.vy = ppf_to_pps(SKILL_XDELTA), ppf_to_pps(SKILL_YDELTA)
    f.t, f.life = 0, LIFETIME_SEC

    f.Text:SetText(msg)
    f:ClearAllPoints(); f:SetPoint("CENTER", f.fx, f.fy)

    f:SetScript("OnUpdate", function(self, dt)
        self.t = self.t + dt
        if self.vx ~= 0 or self.vy ~= 0 then
            self.fx = self.fx + self.vx * dt
            self.fy = self.fy + self.vy * dt
            self:ClearAllPoints(); self:SetPoint("CENTER", self.fx, self.fy)
        end
        local a = 1 - (self.t / self.life); if a < 0 then a = 0 end
        self:SetAlpha(a)
        if self.t >= self.life then
            releaseFrame(self)
        end
    end)
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------
local function handleMessage(event, msg)
    if event == "CHAT_MSG_SKILL" then
        startSkillMessage(msg)
    elseif event == "CHAT_MSG_LOOT" then
        table.insert(lootQueue, msg) -- Spawner staggers
    end
end

-- Colon-call friendly
function scroll:message(event, msg)
    handleMessage(event, msg)
end

-- Dot-call friendly
function scroll.message(_, event, msg)
    handleMessage(event, msg)
end

----------------------------------------------------------------
-- Slash Command
----------------------------------------------------------------
-- /mak speed <n>   e.g., /mak speed 8
-- /mak pad <n>     e.g., /mak pad 6
-- /mak life <sec>  e.g., /mak life 2.5
SLASH_MAK1 = "/mak"
SlashCmdList = SlashCmdList or {}
SlashCmdList["MAK"] = function(msg)
    msg = tostring(msg or "")
    local _,_,cmd,val = string.find(msg, "^(%S+)%s*(%S*)")
    if cmd == "speed" then
        local n = tonumber(val); if n then LOOT_YDELTA = n end
    elseif cmd == "pad" then
        local n = tonumber(val); if n then LINE_PAD = n end
    elseif cmd == "life" then
        local n = tonumber(val); if n then LIFETIME_SEC = n end
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffaa00/mak speed <n> | pad <n> | life <sec>|r")
        return
    end
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
        "|cffffaa00Malakhim|r speed=%s pad=%s life=%.1f",
        tostring(LOOT_YDELTA), tostring(LINE_PAD), LIFETIME_SEC))
end


Malakhim.ScrollMessage.loaded = true
