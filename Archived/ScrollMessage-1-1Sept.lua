-- ScrollMessage.lua (Malakh)
-- UPDATED: 01 Sep 2025
-- Lua 5.0 / Classic 1.12-friendly

Malakh = Malakh or {}
Malakh.ScrollMessage = Malakh.ScrollMessage or {}

-- Bail out early if Localizations didn't load
if not (Malakh.Localizations and Malakh.Localizations.loaded) then
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("Localizations.lua not loaded.", 1, 0, 0)
    end
    return
end

local core   = Malakh.Core or {}
local L      = Malakh.Localizations
local scroll = Malakh.ScrollMessage

----------------------------------------------------------------
-- Tuning knobs
----------------------------------------------------------------
-- SKILL is stationary at {+250, +300}
local SKILL_STARTX = 250
local SKILL_STARTY = 300
local SKILL_XDELTA = 0          -- px / frame (legacy)
local SKILL_YDELTA = 0          -- px / frame (legacy)

-- LOOT scrolls vertically upward on the left
local LOOT_STARTX = -SKILL_STARTX
local LOOT_STARTY = 100         -- you had 100 in your description; use what you like
local LOOT_XDELTA = 0           -- px / frame (legacy)
local LOOT_YDELTA = 6           -- px / frame (legacy) — tuned to avoid overlap with queue

-- Visuals
local FONT_PATH  = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE  = 24
local FONT_FLAGS = "OUTLINE"
local TEXT_R, TEXT_G, TEXT_B = 1.0, 0.0, 0.0
local SHADOW_X, SHADOW_Y = 1, -1

-- Lifetime & spacing
local LIFETIME_SEC       = 3.0     -- fade out duration
local LINE_PAD           = 4       -- extra pixels between lines
local MIN_SEPARATION_PX  = FONT_SIZE + LINE_PAD

----------------------------------------------------------------
-- Helpers: convert legacy "px per frame" into frame-rate independent px/s
----------------------------------------------------------------
local function ppf_to_pps(ppf)
    -- if you tuned at ~60fps, multiply by 60
    return (ppf or 0) * 60
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
    f.fx, f.fy = 0, 0        -- position (float)
    f.vx, f.vy = 0, 0        -- velocity (px/sec)
    f.t        = 0           -- life elapsed
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

-- init a small pool so first message is instant
do
    local f = createNewFrame()
    table.insert(framePool, f)
end

----------------------------------------------------------------
-- Spawner & LOOT queue (prevents overlap when events burst)
----------------------------------------------------------------
local lootQueue, lootCooldown = {}, 0

local Spawner = CreateFrame("Frame")
Spawner:SetScript("OnUpdate", function(_, dt)
    -- cool down between starts is derived from speed & desired separation
    if lootCooldown > 0 then
        lootCooldown = lootCooldown - dt
    end

    if lootCooldown <= 0 and lootQueue[1] then
        local msg = table.remove(lootQueue, 1)

        local f = acquireFrame()
        f.fx, f.fy = LOOT_STARTX, LOOT_STARTY
        f.vx, f.vy = ppf_to_pps(LOOT_XDELTA), ppf_to_pps(LOOT_YDELTA)
        f.t, f.life = 0, LIFETIME_SEC

        f.Text:SetText(msg)
        f:ClearAllPoints(); f:SetPoint("CENTER", f.fx, f.fy)

        f:SetScript("OnUpdate", function(self, dt2)
            -- integrate position
            self.t  = self.t + dt2
            self.fx = self.fx + self.vx * dt2
            self.fy = self.fy + self.vy * dt2

            self:ClearAllPoints()
            self:SetPoint("CENTER", self.fx, self.fy)

            -- fade out
            local a = 1 - (self.t / self.life)
            if a < 0 then a = 0 end
            self:SetAlpha(a)

            if self.t >= self.life then
                releaseFrame(self)
            end
        end)

        -- derive spawn cooldown so lines keep at least MIN_SEPARATION_PX apart
        local vy = math.abs(ppf_to_pps(LOOT_YDELTA))
        if vy < 1 then vy = 1 end
        lootCooldown = MIN_SEPARATION_PX / vy
    end
end)

----------------------------------------------------------------
-- Start a SKILL message (stationary fade, or moving if you give it velocity)
----------------------------------------------------------------
local function startSkillMessage(msg)
    local f = acquireFrame()
    f.fx, f.fy = SKILL_STARTX, SKILL_STARTY
    f.vx, f.vy = ppf_to_pps(SKILL_XDELTA), ppf_to_pps(SKILL_YDELTA)
    f.t, f.life = 0, LIFETIME_SEC

    f.Text:SetText(msg)
    f:ClearAllPoints(); f:SetPoint("CENTER", f.fx, f.fy)

    if f.vx == 0 and f.vy == 0 then
        -- stationary fade
        f:SetScript("OnUpdate", function(self, dt)
            self.t = self.t + dt
            local a = 1 - (self.t / self.life)
            if a < 0 then a = 0 end
            self:SetAlpha(a)
            if self.t >= self.life then
                releaseFrame(self)
            end
        end)
    else
        -- moving (if you ever want it)
        f:SetScript("OnUpdate", function(self, dt)
            self.t  = self.t + dt
            self.fx = self.fx + self.vx * dt
            self.fy = self.fy + self.vy * dt
            self:ClearAllPoints(); self:SetPoint("CENTER", self.fx, self.fy)

            local a = 1 - (self.t / self.life)
            if a < 0 then a = 0 end
            self:SetAlpha(a)
            if self.t >= self.life then
                releaseFrame(self)
            end
        end)
    end
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------
function scroll:message(event, msg)
    if event == "CHAT_MSG_SKILL" then
        startSkillMessage(msg)
        return
    elseif event == "CHAT_MSG_LOOT" then
        -- enqueue; Spawner staggers them to prevent overlap
        table.insert(lootQueue, msg)
        return
    end
    -- ignore other events silently
end

Malakh.ScrollMessage.loaded = true
