ArtisanQueue = ArtisanQueue or {}

local M = ArtisanQueue
local _G = _G
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

M.initialized = false

local function ensureConfig()
    if type(_G.ArtisanConfig) ~= "table" then
        _G.ArtisanConfig = {}
    end

    if _G.ArtisanConfig.queueEnabled == nil then
        _G.ArtisanConfig.queueEnabled = false
    end

    if _G.ArtisanConfig.queueCollapsed == nil then
        _G.ArtisanConfig.queueCollapsed = false
    end
end

function M.IsEnabled()
    ensureConfig()

    -- Future contract:
    -- Queue is only allowed when both queueEnabled and doubleWidth are true.
    return (_G.ArtisanConfig.queueEnabled == true) and (_G.ArtisanConfig.doubleWidth == true)
end

function M.Refresh()
    -- Stub only in v1; queue UI/logic intentionally deferred.
end

function M.Initialize()
    if M.initialized then
        return
    end

    ensureConfig()

    if _G.Artisan and hooksecurefunc then
        hooksecurefunc(_G.Artisan, "UpdateFrame", function()
            M.Refresh()
        end)
    end

    M.initialized = true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name ~= "Artisan" then
        return
    end

    M.Initialize()
end)
