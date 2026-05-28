ArtisanExtras = ArtisanExtras or {}

local M = ArtisanExtras
local _G = _G
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

M.initialized = false
M.slashWrapped = false
M.originalSlash = nil
M.skillButtonHooks = M.skillButtonHooks or {}

BINDING_NAME_ARTISAN_TOGGLE_FRAME = "Toggle Artisan"

local VENDOR_REAGENTS = {
    ["black dye"] = true,
    ["blue dye"] = true,
    ["coal"] = true,
    ["coarse thread"] = true,
    ["crystal vial"] = true,
    ["empty vial"] = true,
    ["fine thread"] = true,
    ["flint and tinder"] = true,
    ["green dye"] = true,
    ["heavy silken thread"] = true,
    ["heavy thread"] = true,
    ["hot spices"] = true,
    ["imbued vial"] = true,
    ["leaded vial"] = true,
    ["mild spices"] = true,
    ["orange dye"] = true,
    ["purple dye"] = true,
    ["red dye"] = true,
    ["refreshing spring water"] = true,
    ["rune thread"] = true,
    ["salt"] = true,
    ["shiny bauble"] = true,
    ["silken thread"] = true,
    ["simple flour"] = true,
    ["simple wood"] = true,
    ["soothing spices"] = true,
    ["strong flux"] = true,
    ["weak flux"] = true,
    ["yellow dye"] = true,
}

local function trim(s)
    if not s then
        return ""
    end
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

local function lower(s)
    return string.lower(s or "")
end

local function normalizeItemName(name)
    return lower(trim(name))
end

local function chat(message)
    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        _G.DEFAULT_CHAT_FRAME:AddMessage("|cffffd100ArtisanPlus:|r " .. message)
    end
end

local function status(parameter)
    if parameter then
        return "(" .. GREEN_FONT_COLOR_CODE .. "ON|r)"
    end

    return "(" .. GRAY_FONT_COLOR_CODE .. "OFF|r)"
end

local function getPanelInfo()
    return { area = "left", pushable = 4, whileDead = 1 }
end

local function getAuxFrame()
    return _G.AuxFrame or _G.aux_frame or _G.AUXFrame or _G.AuctionFrameAux
end

local function getAuxSearchTab()
    local loaded = _G.package and _G.package.loaded
    if loaded and type(loaded["aux.tabs.search"]) == "table" then
        return loaded["aux.tabs.search"]
    end

    if type(_G.require) == "function" then
        local ok, module = pcall(_G.require, "aux.tabs.search")
        if ok and type(module) == "table" then
            return module
        end
    end

    return nil
end

local function objectType(frame)
    if frame and frame.GetObjectType then
        return frame:GetObjectType()
    end
    return nil
end

local function findEditBox(frame, depth, visited)
    if not frame or depth > 6 then
        return nil
    end

    visited = visited or {}
    if visited[frame] then
        return nil
    end
    visited[frame] = true

    if objectType(frame) == "EditBox" and frame.SetText then
        return frame
    end

    if frame.search and objectType(frame.search) == "EditBox" then
        return frame.search
    end

    if frame.search_box and objectType(frame.search_box) == "EditBox" then
        return frame.search_box
    end

    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for i = 1, #children do
            local editBox = findEditBox(children[i], depth + 1, visited)
            if editBox then
                return editBox
            end
        end
    end

    return nil
end

local function triggerEditBoxSearch(editBox)
    if not editBox then
        return
    end

    local onTextChanged = editBox:GetScript("OnTextChanged")
    if onTextChanged then
        onTextChanged(editBox)
    end

    local onEnterPressed = editBox:GetScript("OnEnterPressed")
    if onEnterPressed then
        onEnterPressed(editBox)
    end
end

local function sendAuxQuery(query)
    local auxFrame = getAuxFrame()
    if not auxFrame then
        chat("Aux is not loaded, so no auction search was sent.")
        return false
    end

    if auxFrame.Show then
        auxFrame:Show()
    end

    local aux = _G.aux or _G.Aux
    local searchTab = getAuxSearchTab()
    if searchTab and type(searchTab.set_filter) == "function" and type(searchTab.execute) == "function" then
        if aux and type(aux.set_tab) == "function" then
            aux.set_tab(1)
        end

        local ok = pcall(function()
            searchTab.set_filter(query)
            searchTab.execute(nil, false)
        end)
        if ok then
            return true
        end
    end

    if aux then
        if type(aux.Search) == "function" then
            aux.Search(query)
            return true
        end

        if type(aux.search) == "function" then
            aux.search(query)
            return true
        end
    end

    local namedEditBox = _G.AuxFrameSearchBox or _G.AuxSearchBox or _G.aux_frame_search or _G.aux_search_box
    local editBox = namedEditBox or findEditBox(auxFrame, 0)
    if not editBox or not editBox.SetText then
        chat("Aux is loaded, but ArtisanPlus could not find its search box.")
        return false
    end

    editBox:SetText(query)
    if editBox.SetCursorPosition then
        editBox:SetCursorPosition(0)
    end
    if editBox.SetFocus then
        editBox:SetFocus()
    end
    triggerEditBoxSearch(editBox)

    return true
end

local function addSearchTerm(parts, seen, name, allowVendor)
    local normalized = normalizeItemName(name)
    if normalized == "" or seen[normalized] then
        return
    end

    if not allowVendor and VENDOR_REAGENTS[normalized] then
        return
    end

    seen[normalized] = true
    parts[#parts + 1] = normalized .. "/exact"
end

local function buildAuxRecipeQuery(skillIndex)
    if not skillIndex then
        return nil
    end

    local skillName, skillType = _G.GetTradeSkillInfo(skillIndex)
    if not skillName or skillType == "header" then
        return nil
    end

    local parts = {}
    local seen = {}
    local resultName = skillName

    if _G.GetTradeSkillItemLink and _G.GetItemInfo then
        local itemLink = _G.GetTradeSkillItemLink(skillIndex)
        if itemLink then
            local itemName = _G.GetItemInfo(itemLink)
            if itemName then
                resultName = itemName
            end
        end
    end

    addSearchTerm(parts, seen, resultName, true)

    local reagentCount = 0
    if _G.GetTradeSkillNumReagents then
        reagentCount = _G.GetTradeSkillNumReagents(skillIndex) or 0
    end

    for i = 1, reagentCount do
        local reagentName = _G.GetTradeSkillReagentInfo(skillIndex, i)
        addSearchTerm(parts, seen, reagentName, false)
    end

    if #parts == 0 then
        return nil
    end

    return table.concat(parts, "; ")
end

local function getItemNameFromLink(link)
    if not link then
        return nil
    end

    return string.match(link, "%[(.-)%]")
end

local function getRecipeResultLink(skillIndex, fallbackName)
    local link
    if _G.GetTradeSkillItemLink then
        link = _G.GetTradeSkillItemLink(skillIndex)
    end

    if link then
        return link
    end

    if _G.GetTradeSkillRecipeLink then
        link = _G.GetTradeSkillRecipeLink(skillIndex)
    end

    return link or fallbackName
end

local function getReagentLink(skillIndex, reagentIndex, fallbackName)
    if _G.GetTradeSkillReagentItemLink then
        local link = _G.GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
        if link then
            return link
        end
    end

    return fallbackName
end

local function buildMaterialsPreview(skillIndex)
    if not skillIndex then
        return nil
    end

    local skillName, skillType = _G.GetTradeSkillInfo(skillIndex)
    if not skillName or skillType == "header" then
        return nil
    end

    local resultLink = getRecipeResultLink(skillIndex, skillName)
    local resultName = getItemNameFromLink(resultLink) or skillName
    local lines = {
        "Materials required to craft " .. resultLink .. ":"
    }

    local reagentCount = 0
    if _G.GetTradeSkillNumReagents then
        reagentCount = _G.GetTradeSkillNumReagents(skillIndex) or 0
    end

    for i = 1, reagentCount do
        local reagentName, _, reagentQty = _G.GetTradeSkillReagentInfo(skillIndex, i)
        if reagentName then
            local reagentLink = getReagentLink(skillIndex, i, reagentName)
            lines[#lines + 1] = reagentLink .. " x" .. tostring(reagentQty or 1)
        end
    end

    return {
        resultName = resultName,
        lines = lines,
        preview = table.concat(lines, "\n"),
    }
end

local function getChatDestination()
    local editBox
    if _G.ChatEdit_GetActiveWindow then
        editBox = _G.ChatEdit_GetActiveWindow()
    end

    editBox = editBox or (_G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.editBox) or _G.ChatFrame1EditBox or _G.ChatFrameEditBox

    local chatType = "SAY"
    local target
    if editBox then
        if editBox.GetAttribute then
            chatType = editBox:GetAttribute("chatType") or chatType
            target = editBox:GetAttribute("tellTarget") or editBox:GetAttribute("channelTarget")
        end

        chatType = editBox.chatType or chatType
        target = editBox.tellTarget or editBox.channelTarget or target
    end

    if chatType == "WHISPER" and not target then
        chatType = "SAY"
    elseif chatType == "CHANNEL" and not target then
        chatType = "SAY"
    end

    return chatType, target
end

local function sendMaterialsToChat(lines)
    if type(lines) ~= "table" or not _G.SendChatMessage then
        return
    end

    local chatType, target = getChatDestination()
    for i = 1, #lines do
        _G.SendChatMessage(lines[i], chatType, nil, target)
    end
end

if _G.StaticPopupDialogs and not _G.StaticPopupDialogs["ARTISANPLUS_MATERIALS_PREVIEW"] then
    _G.StaticPopupDialogs["ARTISANPLUS_MATERIALS_PREVIEW"] = {
        text = "%s",
        button1 = "Post",
        button2 = _G.CANCEL or "Cancel",
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
        OnAccept = function(_, data)
            if data and data.lines then
                sendMaterialsToChat(data.lines)
            end
        end,
    }
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

local function saveFramePosition()
    local frame = _G.ArtisanFrame
    if not frame or not _G.ArtisanConfig then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
    _G.ArtisanConfig.point = point or "TOPLEFT"
    _G.ArtisanConfig.relativePoint = relativePoint or _G.ArtisanConfig.point
    _G.ArtisanConfig.X = xOfs or 0
    _G.ArtisanConfig.Y = yOfs or -104
end

local function restoreSavedFramePosition()
    local frame = _G.ArtisanFrame
    if not frame or not _G.ArtisanConfig then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        _G.ArtisanConfig.point or "TOPLEFT",
        _G.UIParent,
        _G.ArtisanConfig.relativePoint or _G.ArtisanConfig.point or "TOPLEFT",
        _G.ArtisanConfig.X or 0,
        _G.ArtisanConfig.Y or -104
    )
end

function M.ApplyFrameBehavior()
    local frame = _G.ArtisanFrame
    if not frame then
        return
    end

    ensureConfigPlaceholders()

    frame:SetClampedToScreen(_G.ArtisanConfig.movable == true)
    frame:SetMovable(_G.ArtisanConfig.movable == true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        if _G.ArtisanConfig and _G.ArtisanConfig.movable then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if _G.ArtisanConfig and _G.ArtisanConfig.movable then
            saveFramePosition()
        end
    end)

    if _G.ArtisanConfig.movable then
        _G.UIPanelWindows["ArtisanFrame"] = nil
        if _G.ArtisanConfig.X ~= nil or _G.ArtisanConfig.Y ~= nil then
            restoreSavedFramePosition()
        end
    else
        _G.UIPanelWindows["ArtisanFrame"] = getPanelInfo()
    end

    if frame:IsShown() and not _G.ArtisanConfig.movable and _G.UpdateUIPanelPositions then
        _G.UpdateUIPanelPositions(frame)
    end
end

function M.SetMovable(enabled)
    ensureConfigPlaceholders()

    if _G.ArtisanConfig.movable and not enabled then
        saveFramePosition()
    end

    _G.ArtisanConfig.movable = enabled and true or false
    M.ApplyFrameBehavior()

    if _G.ArtisanFrame and _G.ArtisanFrame:IsShown() then
        if not _G.ArtisanConfig.movable and _G.ShowUIPanel then
            _G.ShowUIPanel(_G.ArtisanFrame)
        elseif _G.ArtisanConfig.movable and (_G.ArtisanConfig.X ~= nil or _G.ArtisanConfig.Y ~= nil) then
            restoreSavedFramePosition()
        end
    end

    if _G.UpdateUIPanelPositions then
        _G.UpdateUIPanelPositions(_G.ArtisanFrame)
    end
end

local function getKnownProfessionName()
    ensureConfigPlaceholders()

    if _G.Artisan and _G.Artisan.currentTab then
        _G.ArtisanConfig.lastProfession = _G.Artisan.currentTab
        return _G.Artisan.currentTab
    end

    if _G.ArtisanConfig.lastProfession then
        return _G.ArtisanConfig.lastProfession
    end

    if _G.Artisan and _G.Artisan.UpdateTabs then
        _G.Artisan.UpdateTabs()
        if type(_G.Artisan.Tabs) == "table" then
            for i = 1, #_G.Artisan.Tabs do
                if _G.Artisan.Tabs[i] and _G.Artisan.Tabs[i].name then
                    return _G.Artisan.Tabs[i].name
                end
            end
        end
    end

    return nil
end

function M.ToggleFrame()
    local frame = _G.ArtisanFrame
    if frame and frame:IsShown() then
        if _G.HideUIPanel then
            _G.HideUIPanel(frame)
        else
            frame:Hide()
        end
        return
    end

    local professionName = getKnownProfessionName()
    if not professionName then
        chat("No learned profession was found to open.")
        return
    end

    if _G.InCombatLockdown and _G.InCombatLockdown() then
        chat("Cannot open " .. professionName .. " while in combat.")
        return
    end

    _G.CastSpellByName(professionName)
end

function Artisan_ToggleFrame()
    if _G.ArtisanExtras and _G.ArtisanExtras.ToggleFrame then
        _G.ArtisanExtras.ToggleFrame()
    end
end

function M.ApplyDefaultTweaks()
    -- Placeholder for non-invasive UI tweaks that should remain out of Artisan.lua.
    M.HookSkillButtons()
    M.ApplyFrameBehavior()

    if _G.Artisan and _G.Artisan.currentTab then
        ensureConfigPlaceholders()
        _G.ArtisanConfig.lastProfession = _G.Artisan.currentTab
    end
end

function M.SearchRecipeInAux(skillIndex)
    local query = buildAuxRecipeQuery(skillIndex)
    if not query then
        return false
    end

    return sendAuxQuery(query)
end

function M.ShowMaterialsPreview(skillIndex)
    local preview = buildMaterialsPreview(skillIndex)
    if not preview then
        return false
    end

    if _G.StaticPopup_Show then
        _G.StaticPopup_Show("ARTISANPLUS_MATERIALS_PREVIEW", preview.preview, nil, preview)
        return true
    end

    chat(preview.preview)
    return true
end

function M.HookSkillButton(button)
    if not button or M.skillButtonHooks[button] then
        return
    end

    if button.RegisterForClicks then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end

    local originalOnClick = button:GetScript("OnClick")
    button:SetScript("OnClick", function(self, mouseButton, ...)
        if mouseButton == "LeftButton" and _G.IsShiftKeyDown() and not _G.IsControlKeyDown() and not _G.IsAltKeyDown() then
            if not (_G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow()) then
                if M.ShowMaterialsPreview(self:GetID()) then
                    return
                end
            end
        end

        if mouseButton == "RightButton" and not _G.IsModifiedClick() then
            if M.SearchRecipeInAux(self:GetID()) then
                return
            end
        end

        if originalOnClick then
            return originalOnClick(self, mouseButton, ...)
        end
    end)

    M.skillButtonHooks[button] = true
end

function M.HookSkillButtons()
    local displayedSkills = 19
    if _G.ArtisanDoubleWidth and _G.ArtisanDoubleWidth.GetDisplayedSkills then
        displayedSkills = _G.ArtisanDoubleWidth.GetDisplayedSkills()
    end

    for i = 1, displayedSkills do
        M.HookSkillButton(_G["ArtisanFrameSkill" .. i])
    end
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

    if cmdLower == "movable" then
        ensureConfigPlaceholders()
        M.SetMovable(not _G.ArtisanConfig.movable)
        chat("movable window is now " .. status(_G.ArtisanConfig.movable))
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

    M.WrapSlash()
    M.ApplyDefaultTweaks()

    M.initialized = true
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
    if name ~= "Artisan" and name ~= "ArtisanPlus" then
        return
    end

    M.Initialize()
end)
