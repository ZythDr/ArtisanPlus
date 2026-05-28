ArtisanExtras = ArtisanExtras or {}

local M = ArtisanExtras
local _G = _G
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

M.initialized = false
M.slashWrapped = false
M.originalSlash = nil

local function trim(s)
    if not s then
        return ""
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function lower(s)
    return string.lower(s or "")
end

local function ensureConfigPlaceholders()
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

function M.ApplyDefaultTweaks()
    -- Placeholder for non-invasive UI tweaks that should remain out of Artisan.lua.
    -- Intentionally no behavior changes in v1.
end

function M.HandleExtendedSlash(rawCmd)
    local cmd = trim(rawCmd)
    local cmdLower = lower(cmd)

    local widthArg = string.match(cmdLower, "^width%s*(.*)$")
    if widthArg ~= nil then
        if _G.ArtisanDoubleWidth and _G.ArtisanDoubleWidth.HandleSlash then
            return _G.ArtisanDoubleWidth.HandleSlash(widthArg)
        end
        return true
    end

    return false
end

function M.WrapSlash()
    if M.slashWrapped then
        return
    end

    local current = _G.SlashCmdList and _G.SlashCmdList["ARTISAN"]
    if type(current) ~= "function" then
        return
    end

    M.originalSlash = current
    _G.SlashCmdList["ARTISAN"] = function(rawCmd)
        if M.HandleExtendedSlash(rawCmd) then
            return
        end

        if M.originalSlash then
            M.originalSlash(rawCmd)
        end
    end

    M.slashWrapped = true
end

function M.Initialize()
    if M.initialized then
        return
    end

    ensureConfigPlaceholders()

    if _G.Artisan and hooksecurefunc then
        hooksecurefunc(_G.Artisan, "Initialize", function()
            ensureConfigPlaceholders()
            M.WrapSlash()
            M.ApplyDefaultTweaks()
        end)

        hooksecurefunc(_G.Artisan, "UpdateFrame", function()
            M.ApplyDefaultTweaks()
        end)

        hooksecurefunc(_G.Artisan, "SetSelection", function()
            M.ApplyDefaultTweaks()
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
