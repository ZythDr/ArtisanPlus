ArtisanDoubleWidth = ArtisanDoubleWidth or {}

local M = ArtisanDoubleWidth
local _G = _G
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local unpack = unpack

local SINGLE_WIDTH = 384
local DOUBLE_WIDTH = 695
local DOUBLE_HEIGHT = 512
local SINGLE_DISPLAYED_SKILLS = 12
local WIDE_DISPLAYED_SKILLS = 19
local SINGLE_RANK_WIDTH = 252
local SINGLE_SEARCH_WIDTH = 252
local DOUBLE_RANK_WIDTH = 561
local DOUBLE_RANK_OFFSET_X = 2
local WIDE_RANK_BORDER_HEIGHT = 22

local WIDE_TEXTURE_PATH = "Interface\\AddOns\\Artisan\\Textures\\DoubleWideProfession\\"
local WIDE_TOP_TEXTURE = WIDE_TEXTURE_PATH .. "Top.tga"
local WIDE_BOT_TEXTURE = WIDE_TEXTURE_PATH .. "Bot.tga"
local WIDE_BAR_BORDER_TEXTURE = WIDE_TEXTURE_PATH .. "BarBorder.tga"
local DEFAULT_BAR_BORDER_TEXTURE = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
local RANK_TEXT_RIGHT_PAD = 8
local TITLE_LINK_GAP = 2
local EDITOR_BUTTON_GAP = 8

local ICON_NEXT_UP = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up"
local ICON_NEXT_DOWN = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down"
local ICON_NEXT_DISABLED = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled"
local ICON_PREV_UP = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up"
local ICON_PREV_DOWN = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down"
local ICON_PREV_DISABLED = "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled"

local trackedFrameNames = {
    "ArtisanFrame",
    "ArtisanRankFrame",
    "ArtisanRankFrameBorder",
    "ArtisanFrameSearchBox",
    "ArtisanListScrollFrame",
    "ArtisanDetailScrollFrame",
    "ArtisanDetailScrollChildFrame",
    "ArtisanFrameCreateAllButton",
    "ArtisanFrameDecrementButton",
    "ArtisanFrameInputBox",
    "ArtisanFrameIncrementButton",
    "ArtisanFrameCreateButton",
    "ArtisanFrameCancelButton",
}

M.hooksInstalled = false
M.state = {
    captured = false,
    original = {},
    hiddenRegions = {},
    wideHiddenRegions = {},
    wideHiddenCaptured = false,
    active = false,
}

local function getFrame(name)
    return _G[name]
end

local function addHiddenRegion(region, bucket)
    if not region then
        return
    end

    bucket[#bucket + 1] = {
        region = region,
        shown = region:IsShown(),
    }
end

local function textureContains(texture, value)
    return type(texture) == "string" and string.find(texture, value, 1, true) ~= nil
end

local function isHorizontalDividerTexture(texture, name)
    return texture == "Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar"
        or texture == "Interface\\TradeSkillFrame\\UI-TradeSkill-SkillBorder"
        or (type(name) == "string" and string.find(name, "HorizontalBar", 1, true) ~= nil)
end

local function captureWideHiddenRegions()
    if M.state.wideHiddenCaptured then
        return
    end

    local seen = {}

    local function addOnce(region)
        if region and not seen[region] then
            seen[region] = true
            addHiddenRegion(region, M.state.wideHiddenRegions)
        end
    end

    local function scan(frameName, predicate)
        local frame = getFrame(frameName)
        if not frame or not frame.GetRegions then
            return
        end

        for _, region in ipairs({frame:GetRegions()}) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                local texture = region.GetTexture and region:GetTexture()
                if predicate(texture, region) then
                    addOnce(region)
                end
            end
        end
    end

    -- Match DoubleWideProfession/vcTST: do not hide scroll/detail panel art.
    -- Those template textures provide the dark list/detail backgrounds. Only
    -- remove the horizontal divider bars that visually conflict with wide mode.
    scan("ArtisanFrame", function(texture)
        return texture == "Interface\\ClassTrainerFrame\\UI-ClassTrainer-HorizontalBar"
    end)

    M.state.wideHiddenCaptured = true
end

local function trim(s)
    if not s then
        return ""
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function ensureExtraSkillButtons()
    local frame = getFrame("ArtisanFrame")
    if not frame or getFrame("ArtisanFrameSkill" .. WIDE_DISPLAYED_SKILLS) then
        return
    end

    for i = SINGLE_DISPLAYED_SKILLS + 1, WIDE_DISPLAYED_SKILLS do
        local previous = getFrame("ArtisanFrameSkill" .. (i - 1))
        if previous then
            local button = CreateFrame("Button", "ArtisanFrameSkill" .. i, frame, "ArtisanSkillButtonTemplate")
            button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, 0)
            button:Hide()
        end
    end
end

local function hideExtraSkillButtons()
    for i = SINGLE_DISPLAYED_SKILLS + 1, WIDE_DISPLAYED_SKILLS do
        local button = getFrame("ArtisanFrameSkill" .. i)
        if button then
            button:Hide()
        end
    end
end

local function ensureConfig()
    if type(_G.ArtisanConfig) ~= "table" then
        _G.ArtisanConfig = {}
    end

    if _G.ArtisanConfig.doubleWidth == nil then
        _G.ArtisanConfig.doubleWidth = false
    end
end

local function capturePoints(frame)
    local points = {}
    local numPoints = frame:GetNumPoints() or 0
    for i = 1, numPoints do
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(i)
        if point then
            points[#points + 1] = {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint,
                xOfs = xOfs or 0,
                yOfs = yOfs or 0,
            }
        end
    end
    return points
end

local function copyTextureCoords(source, target)
    if not (source.GetTexCoord and target.SetTexCoord) then
        return
    end

    local coords = {source:GetTexCoord()}
    if #coords > 0 then
        target:SetTexCoord(unpack(coords))
    end
end

local function applyClonedPoint(source, target, parent, sourceParent, cloneByRegion)
    target:ClearAllPoints()

    local point, relativeTo, relativePoint, xOfs, yOfs = source:GetPoint(1)
    if not point then
        target:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        return
    end

    if relativeTo == sourceParent or relativeTo == nil then
        target:SetPoint(point, parent, relativePoint, xOfs or 0, yOfs or 0)
        return
    end

    local clonedRelative = cloneByRegion[relativeTo]
    if clonedRelative then
        target:SetPoint(point, clonedRelative, relativePoint, xOfs or 0, yOfs or 0)
        return
    end

    target:SetPoint(point, parent, relativePoint, xOfs or 0, yOfs or 0)
end

local function restorePoints(frame, points)
    frame:ClearAllPoints()
    if not points then
        return
    end

    for _, p in ipairs(points) do
        frame:SetPoint(p.point, p.relativeTo, p.relativePoint, p.xOfs, p.yOfs)
    end
end

local function ensureNativeFrameTextures()
    local frame = getFrame("ArtisanFrame")
    local tradeSkillFrame = getFrame("TradeSkillFrame")
    if not (frame and tradeSkillFrame and tradeSkillFrame.GetRegions) then
        return false
    end

    if M.nativeTexturesCreated then
        return true
    end

    M.nativeTextures = {}
    M.nativeTextureBySource = {}
    M.nativeTextureByName = {}

    local regions = {tradeSkillFrame:GetRegions()}
    for i, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            local texture = region.GetTexture and region:GetTexture()
            local name = region:GetName()
            if texture and name ~= "TradeSkillFramePortrait" and not isHorizontalDividerTexture(texture, name) then
                local clone = frame:CreateTexture("ArtisanDoubleWidthNativeTexture" .. i, "BACKGROUND")
                clone:SetTexture(texture)
                clone:SetWidth(region:GetWidth() or 1)
                clone:SetHeight(region:GetHeight() or 1)
                copyTextureCoords(region, clone)
                clone:Hide()

                M.nativeTextures[#M.nativeTextures + 1] = clone
                M.nativeTextureBySource[region] = clone

                if name then
                    M.nativeTextureByName[name] = clone
                end
            end
        end
    end

    for _, region in ipairs(regions) do
        local clone = M.nativeTextureBySource[region]
        if clone then
            applyClonedPoint(region, clone, frame, tradeSkillFrame, M.nativeTextureBySource)
        end
    end

    M.nativeTexturesCreated = true
    return true
end

local function captureOriginalLayout()
    if M.state.captured then
        return
    end

    for _, name in ipairs(trackedFrameNames) do
        local frame = getFrame(name)
        if frame then
            M.state.original[name] = {
                width = frame:GetWidth(),
                height = frame:GetHeight(),
                points = capturePoints(frame),
            }
        end
    end

    local frame = getFrame("ArtisanFrame")
    if frame then
        local regions = {frame:GetRegions()}
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                if region:GetName() ~= "ArtisanFramePortrait" then
                    M.state.hiddenRegions[#M.state.hiddenRegions + 1] = {
                        region = region,
                        shown = region:IsShown(),
                    }
                end
            end
        end
    end

    M.state.captured = true
end

local function ensureWideTextures()
    local frame = getFrame("ArtisanFrame")
    if not frame then
        return
    end

    ensureNativeFrameTextures()

    if not M.wideTop then
        local top = frame:CreateTexture("ArtisanDoubleWidthTopTexture", "BORDER")
        top:SetTexture(WIDE_TOP_TEXTURE)
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", 256, 0)
        top:SetWidth(311)
        top:SetHeight(256)
        top:Hide()
        M.wideTop = top
    end

    if not M.wideBottom then
        local bottom = frame:CreateTexture("ArtisanDoubleWidthBottomTexture", "BORDER")
        bottom:SetTexture(WIDE_BOT_TEXTURE)
        local bottomLeft = M.nativeTextureByName and M.nativeTextureByName.TradeSkillFrameBottomLeftTexture
        if bottomLeft then
            bottom:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT", 0, 0)
        else
            bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 256, 0)
        end
        bottom:SetWidth(311)
        bottom:SetHeight(256)
        bottom:Hide()
        M.wideBottom = bottom
    end

    if not M.scrollBarFix then
        local list = getFrame("ArtisanListScrollFrame")
        if list then
            local scrollBarFix = list:CreateTexture("ArtisanDoubleWidthScrollBarFix", "BACKGROUND")
            scrollBarFix:SetTexture("Interface\\ClassTrainerFrame\\UI-ClassTrainer-ScrollBar")
            scrollBarFix:SetWidth(30)
            scrollBarFix:SetHeight(97.4)
            scrollBarFix:SetPoint("LEFT", list, "RIGHT", -3, 0)
            scrollBarFix:SetTexCoord(0, 0.46875, 0.2, 0.9609375)
            scrollBarFix:Hide()
            M.scrollBarFix = scrollBarFix
        end
    end
end

local function showWideTextures(show)
    if M.nativeTextures then
        for _, texture in ipairs(M.nativeTextures) do
            if show then texture:Show() else texture:Hide() end
        end
    end

    if M.wideTop then
        if show then M.wideTop:Show() else M.wideTop:Hide() end
    end

    if M.wideBottom then
        if show then M.wideBottom:Show() else M.wideBottom:Hide() end
    end

    if M.scrollBarFix then
        if show then M.scrollBarFix:Show() else M.scrollBarFix:Hide() end
    end
end

local function setRankWidth(width, isWide)
    local rank = getFrame("ArtisanRankFrame")
    local border = getFrame("ArtisanRankFrameBorder")

    if rank then
        rank:SetWidth(width)
    end

    if border then
        border:SetWidth(width + 8)
        if isWide then
            border:SetHeight(WIDE_RANK_BORDER_HEIGHT)
        elseif M.state.original.ArtisanRankFrameBorder and M.state.original.ArtisanRankFrameBorder.height then
            border:SetHeight(M.state.original.ArtisanRankFrameBorder.height)
        end
        if border.SetNormalTexture then
            border:SetNormalTexture(isWide and WIDE_BAR_BORDER_TEXTURE or DEFAULT_BAR_BORDER_TEXTURE)
        end
    end
end

local function applyControlSizing(isWide)
    local search = getFrame("ArtisanFrameSearchBox")
    local rank = getFrame("ArtisanRankFrame")

    if isWide then
        setRankWidth(DOUBLE_RANK_WIDTH, true)
        if rank and M.state.original.ArtisanRankFrame and M.state.original.ArtisanRankFrame.points then
            restorePoints(rank, M.state.original.ArtisanRankFrame.points)
            rank:ClearAllPoints()
            rank:SetPoint("TOPLEFT", getFrame("ArtisanFrame"), "TOPLEFT", 71 + DOUBLE_RANK_OFFSET_X, -17)
        end
    else
        setRankWidth(SINGLE_RANK_WIDTH, false)
        if rank and M.state.original.ArtisanRankFrame and M.state.original.ArtisanRankFrame.points then
            restorePoints(rank, M.state.original.ArtisanRankFrame.points)
        end
        if search then
            search:SetWidth(SINGLE_SEARCH_WIDTH)
        end
    end
end

local function getTextWidth(fontString, fallback)
    if fontString and fontString.GetStringWidth then
        local width = fontString:GetStringWidth()
        if width and width > 0 then
            return width
        end
    end
    return fallback or 80
end

local function applyTitleBarLayout(isWide)
    local rank = getFrame("ArtisanRankFrame")
    local skillName = getFrame("ArtisanRankFrameSkillName")
    local skillRank = getFrame("ArtisanRankFrameSkillRank")
    local linkButton = getFrame("ArtisanLinkButton")
    local editorButton = getFrame("ArtisanToggleEditorButton")
    local sortCustomText = _G.ArtisanSortCustomText
    local sortCustom = getFrame("ArtisanSortCustom")

    if rank and skillRank then
        skillRank:ClearAllPoints()
        skillRank:SetWidth(80)
        skillRank:SetJustifyH("RIGHT")
        skillRank:SetPoint("RIGHT", rank, "RIGHT", -RANK_TEXT_RIGHT_PAD, 1)
    end

    if rank and skillName then
        local nameWidth = getTextWidth(skillName, 110)
        skillName:SetWidth(nameWidth + 2)
        skillName:ClearAllPoints()

        if isWide then
            local linkWidth = linkButton and linkButton.GetWidth and linkButton:GetWidth() or 32
            local totalWidth = nameWidth + TITLE_LINK_GAP + linkWidth
            skillName:SetPoint("LEFT", rank, "CENTER", -(totalWidth / 2), 1)
        else
            skillName:SetPoint("LEFT", rank, "LEFT", 6, 1)
        end

        if linkButton then
            linkButton:ClearAllPoints()
            linkButton:SetWidth(32)
            linkButton:SetHeight(16)
            linkButton:SetPoint("LEFT", skillName, "RIGHT", TITLE_LINK_GAP, 0)
            linkButton:SetFrameLevel(rank:GetFrameLevel() + 5)
            linkButton:EnableMouse(true)
        end
    end

    if editorButton and (sortCustomText or sortCustom) then
        editorButton:ClearAllPoints()
        editorButton:SetPoint("LEFT", sortCustomText or sortCustom, "RIGHT", EDITOR_BUTTON_GAP, 0)
    end
end

local function setArtisanFrameArtShown(shown)
    for _, data in ipairs(M.state.hiddenRegions) do
        if data.region then
            if shown and data.shown ~= false then
                data.region:Show()
            else
                data.region:Hide()
            end
        end
    end
end

local function setWideChildArtShown(shown)
    for _, data in ipairs(M.state.wideHiddenRegions) do
        if data.region then
            if shown and data.shown ~= false then
                data.region:Show()
            else
                data.region:Hide()
            end
        end
    end
end

local function applyDoubleLayout()
    ensureConfig()
    ensureExtraSkillButtons()
    captureOriginalLayout()
    ensureWideTextures()
    captureWideHiddenRegions()

    local frame = getFrame("ArtisanFrame")
    local list = getFrame("ArtisanListScrollFrame")
    local detail = getFrame("ArtisanDetailScrollFrame")
    local detailChild = getFrame("ArtisanDetailScrollChildFrame")
    local createAll = getFrame("ArtisanFrameCreateAllButton")
    local dec = getFrame("ArtisanFrameDecrementButton")
    local input = getFrame("ArtisanFrameInputBox")
    local inc = getFrame("ArtisanFrameIncrementButton")
    local create = getFrame("ArtisanFrameCreateButton")
    local cancel = getFrame("ArtisanFrameCancelButton")

    if not (frame and list and detail) then
        return
    end

    frame:SetWidth(DOUBLE_WIDTH)
    frame:SetHeight(DOUBLE_HEIGHT)

    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -96)
    list:SetWidth(296)
    list:SetHeight(310)

    detail:ClearAllPoints()
    detail:SetPoint("TOPLEFT", list, "TOPRIGHT", 35, -2)
    detail:SetWidth(298)
    detail:SetHeight(310)

    if detailChild then
        detailChild:SetWidth(298)
        detailChild:SetHeight(310)
    end

    if createAll and dec and input and inc then
        createAll:ClearAllPoints()
        createAll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 80)

        dec:ClearAllPoints()
        dec:SetPoint("LEFT", createAll, "RIGHT", 3, 0)

        input:ClearAllPoints()
        input:SetPoint("LEFT", dec, "RIGHT", 4, 0)

        inc:ClearAllPoints()
        inc:SetPoint("LEFT", input, "RIGHT", 4, 0)
    end

    if create then
        create:ClearAllPoints()
        create:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -125, 80)
    end

    if cancel then
        cancel:ClearAllPoints()
        cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, 80)
    end

    applyControlSizing(true)
    applyTitleBarLayout(true)
    setArtisanFrameArtShown(false)
    setWideChildArtShown(false)
    showWideTextures(true)

    M.state.active = true
end

local function applySingleLayout()
    ensureConfig()
    ensureExtraSkillButtons()
    captureOriginalLayout()

    for _, name in ipairs(trackedFrameNames) do
        local frame = getFrame(name)
        local saved = M.state.original[name]
        if frame and saved then
            if saved.width then frame:SetWidth(saved.width) end
            if saved.height then frame:SetHeight(saved.height) end
            if name ~= "ArtisanFrame" then
                restorePoints(frame, saved.points)
            end
        end
    end

    setArtisanFrameArtShown(true)
    setWideChildArtShown(true)
    showWideTextures(false)
    applyControlSizing(false)
    applyTitleBarLayout(false)
    hideExtraSkillButtons()

    M.state.active = false
end

function M.GetDisplayedSkills()
    if M.IsEnabled() then
        ensureExtraSkillButtons()
        return WIDE_DISPLAYED_SKILLS
    end
    return SINGLE_DISPLAYED_SKILLS
end

function M.IsEnabled()
    ensureConfig()
    return _G.ArtisanConfig.doubleWidth == true
end

function M.SetEnabled(enabled, silent)
    ensureConfig()
    _G.ArtisanConfig.doubleWidth = not not enabled
    M.ApplyCurrentLayout()
    M.UpdateToggleButtonIcon()

    if _G.Artisan and _G.Artisan.UpdateFrame and getFrame("ArtisanFrame") and getFrame("ArtisanFrame"):IsShown() then
        _G.Artisan.UpdateFrame()
    end

    if not silent and _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        local state = M.IsEnabled() and "ON" or "OFF"
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cff0070de[Artisan]|r double width is now " .. state)
    end
end

function M.Toggle(silent)
    M.SetEnabled(not M.IsEnabled(), silent)
end

function M.ApplyCurrentLayout()
    if M.IsEnabled() then
        applyDoubleLayout()
    else
        applySingleLayout()
    end
end

function M.UpdateToggleButtonIcon()
    if not M.toggleButton then
        return
    end

    if M.IsEnabled() then
        M.toggleButton:SetNormalTexture(ICON_PREV_UP)
        M.toggleButton:SetPushedTexture(ICON_PREV_DOWN)
        M.toggleButton:SetDisabledTexture(ICON_PREV_DISABLED)
    else
        M.toggleButton:SetNormalTexture(ICON_NEXT_UP)
        M.toggleButton:SetPushedTexture(ICON_NEXT_DOWN)
        M.toggleButton:SetDisabledTexture(ICON_NEXT_DISABLED)
    end
end

function M.EnsureToggleButton()
    if M.toggleButton then
        M.UpdateToggleButtonIcon()
        return
    end

    local frame = getFrame("ArtisanFrame")
    local closeButton = getFrame("ArtisanFrameCloseButton")
    if not frame then
        return
    end

    local btn = CreateFrame("Button", "ArtisanDoubleWidthToggleButton", frame)
    btn:SetWidth(25)
    btn:SetHeight(25)
    if closeButton then
        btn:SetPoint("TOPRIGHT", closeButton, "BOTTOMRIGHT", -4, 8)
    else
        btn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -52, -50)
    end
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    btn:SetScript("OnClick", function()
        M.Toggle(false)
    end)

    M.toggleButton = btn
    M.UpdateToggleButtonIcon()
end

function M.HandleSlash(arg)
    local mode = trim(string.lower(arg or ""))

    if mode == "debug" or mode == "dump" then
        M.DebugDumpTextures()
        return true
    end

    if mode == "" then
        if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
            local state = M.IsEnabled() and "ON" or "OFF"
            _G.DEFAULT_CHAT_FRAME:AddMessage("|cff0070de[Artisan]|r double width is " .. state .. ". Use '/artisan width on|off|toggle'.")
        end
        return true
    end

    if mode == "toggle" then
        M.Toggle(false)
        return true
    end

    if mode == "on" or mode == "enable" then
        M.SetEnabled(true, false)
        return true
    end

    if mode == "off" or mode == "disable" then
        M.SetEnabled(false, false)
        return true
    end

    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cff0070de[Artisan]|r unknown width option. Use '/artisan width on|off|toggle|debug'.")
    end
    return true
end

function M.DebugDumpTextures()
    local frame = getFrame("ArtisanFrame")
    if not (frame and _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage) then
        return
    end

    local chat = _G.DEFAULT_CHAT_FRAME
    chat:AddMessage("|cff0070de[Artisan]|r ArtisanFrame texture dump:")
    chat:AddMessage(string.format("frame size=%sx%s shown=%s double=%s", tostring(frame:GetWidth()), tostring(frame:GetHeight()), tostring(frame:IsShown()), tostring(M.IsEnabled())))

    local index = 0
    for _, region in ipairs({frame:GetRegions()}) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            index = index + 1
            local point, relativeTo, relativePoint, x, y = region:GetPoint(1)
            local relName = relativeTo and relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)
            local layer = region.GetDrawLayer and region:GetDrawLayer() or "?"
            local texture = region.GetTexture and region:GetTexture() or "nil"
            chat:AddMessage(string.format(
                "%02d %s layer=%s shown=%s size=%sx%s point=%s rel=%s/%s %.1f %.1f tex=%s",
                index,
                region:GetName() or "(unnamed)",
                tostring(layer),
                tostring(region:IsShown()),
                tostring(region:GetWidth()),
                tostring(region:GetHeight()),
                tostring(point),
                tostring(relName),
                tostring(relativePoint),
                tonumber(x) or 0,
                tonumber(y) or 0,
                tostring(texture)
            ))
        end
    end
end

function M.InstallHooks()
    if M.hooksInstalled then
        return
    end

    if not (_G.Artisan and hooksecurefunc) then
        return
    end

    hooksecurefunc(_G.Artisan, "Initialize", function()
        ensureConfig()
        ensureExtraSkillButtons()
        M.EnsureToggleButton()
        M.ApplyCurrentLayout()
    end)

    hooksecurefunc(_G.Artisan, "UpdateFrame", function()
        M.ApplyCurrentLayout()
        M.UpdateToggleButtonIcon()
    end)

    hooksecurefunc(_G.Artisan, "SetSelection", function()
        M.ApplyCurrentLayout()
    end)

    M.hooksInstalled = true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name ~= "Artisan" then
        return
    end

    ensureConfig()
    M.InstallHooks()
end)
