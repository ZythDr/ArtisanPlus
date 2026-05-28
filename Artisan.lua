Artisan = {}
Artisan.version = GetAddOnMetadata("Artisan", "Version")
Artisan.initialized = false
Artisan.currentTab = nil
Artisan.selectedSkill = 0
Artisan.Tabs = {}
Artisan.Skills = {}
Artisan.Uncategorized = {}
Artisan.CustomCategories = {}
Artisan.CollapsedHeaders = {}

ArtisanConfig = {}
ArtisanCustom = {}

BINDING_HEADER_ARTISAN = "Artisan+"
BINDING_HEADER_ARTISAN_TITLE = "Artisan Bindings"
BINDING_NAME_ARTISAN_TOGGLE = "Toggle Artisan"
BINDING_NAME_ARTISAN_CREATE = CREATE
BINDING_NAME_ARTISAN_CREATE_ALL = CREATE_ALL

local BLUE_FONT_COLOR_CODE = "|cff0070de"
local MAX_TABS = 7
local MAX_SKILLS = 12

local function GetMaxVisibleSkills()
    if ArtisanDoubleWidth and ArtisanDoubleWidth.GetDisplayedSkills then
        return ArtisanDoubleWidth.GetDisplayedSkills()
    end
    return MAX_SKILLS
end

local TabsOrder = {
    (GetSpellInfo(2259)),  -- "Alchemy"
    (GetSpellInfo(2018)),  -- "Blacksmithing"
    (GetSpellInfo(7411)),  -- "Enchanting"
    (GetSpellInfo(4036)),  -- "Engineering"
    (GetSpellInfo(2108)),  -- "Leatherworking"
    (GetSpellInfo(3908)),  -- "Tailoring"
    (GetSpellInfo(45357)), -- "Inscription"
    (GetSpellInfo(25229)), -- "Jewelcrafting"
    (GetSpellInfo(2656)),  -- "Smelting"
    (GetSpellInfo(3273)),  -- "First Aid"
    (GetSpellInfo(2550)),  -- "Cooking"
}

EnableAddOn("Blizzard_TradeSkillUI")
LoadAddOn("Blizzard_TradeSkillUI")
TradeSkillFrame:UnregisterAllEvents()
UIParent:UnregisterEvent("TRADE_SKILL_SHOW")
UIParent:UnregisterEvent("TRADE_SKILL_CLOSE")

function Artisan.OnLoad(self)
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_PORTRAIT_UPDATE")
    self:RegisterEvent("UPDATE_TRADESKILL_RECAST")
    self:RegisterEvent("TRADE_SKILL_SHOW")
    self:RegisterEvent("TRADE_SKILL_CLOSE")
    self:RegisterEvent("TRADE_SKILL_UPDATE")
    self:RegisterEvent("TRADE_SKILL_FILTER_UPDATE")
    self:RegisterEvent("REPLACE_ENCHANT")
    self:RegisterEvent("TRADE_REPLACE_ENCHANT")
    self:RegisterEvent("SKILL_LINES_CHANGED")
    tinsert(UISpecialFrames, "ArtisanFrame")
    ArtisanRankFrame:SetStatusBarColor(0.0, 0.0, 1.0, 0.5)
    ArtisanRankFrameBackground:SetVertexColor(0.0, 0.0, 0.75, 0.5)
end

function Artisan.OnEvent(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "Artisan" then return end
        self:UnregisterEvent("ADDON_LOADED")
        if not ArtisanConfig then ArtisanConfig = {} end
        if ArtisanConfig.auto == nil then ArtisanConfig.auto = true end
        if ArtisanConfig.icons == nil then ArtisanConfig.icons = true end
        if ArtisanConfig.movable == nil then ArtisanConfig.movable = false end
        if type(Artisan.Skills) ~= "table" then Artisan.Skills = {} end
        if type(ArtisanCustom) ~= "table" then ArtisanCustom = {} end
        if type(ArtisanConfig.sorting) ~= "table" then ArtisanConfig.sorting = {} end
        if type(ArtisanConfig.reagents) ~= "table" then ArtisanConfig.reagents = {} end
        if not ArtisanConfig.auto then
            self:UnregisterEvent("REPLACE_ENCHANT")
            self:UnregisterEvent("TRADE_REPLACE_ENCHANT")
        end
        if not ArtisanConfig.movable then
            UIPanelWindows["ArtisanFrame"] = { area = "left", pushable = 4 }
        else
            self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", ArtisanConfig.X or 0, ArtisanConfig.Y or -104)
        end
    elseif event == "SKILL_LINES_CHANGED" then
        Artisan.UpdateTabs()
        if self:IsShown() then
            Artisan.UpdateFrame()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        SetPortraitTexture(ArtisanFramePortrait, "player")
        Artisan.Initialize()
    elseif event == "UNIT_PORTRAIT_UPDATE" then
        if not self:IsShown() then return end
        if arg1 == "player" then
            SetPortraitTexture(ArtisanFramePortrait, "player")
        end
    elseif event == "TRADE_SKILL_UPDATE" or event == "TRADE_SKILL_FILTER_UPDATE" then
        if not self:IsShown() then return end
        Artisan.currentTab = GetTradeSkillLine()
        if not ArtisanConfig.sorting[Artisan.currentTab] then ArtisanConfig.sorting[Artisan.currentTab] = "DEFAULT" end
        if ArtisanConfig.sorting[Artisan.currentTab] == "CUSTOM" then
            Artisan.UpdateSkills()
        else
            ArtisanEditor:Hide()
        end
        ArtisanFrameCreateButton:Disable()
        ArtisanFrameCreateAllButton:Disable()
        local selectionIndex = Artisan.GetTradeSkillSelectionIndex()
        if event ~= "TRADE_SKILL_FILTER_UPDATE" and selectionIndex > 1 and selectionIndex <= Artisan.GetNumTradeSkills() then
            Artisan.SetSelection(selectionIndex)
        else
            Artisan.SetSelection(Artisan.GetFirstTradeSkill())
            FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
            ArtisanListScrollFrameScrollBar:SetValue(0)
        end
        Artisan.UpdateFrame()
        if ArtisanEditor:IsShown() then
            Artisan.UpdateEditor()
        end
    elseif event == "TRADE_SKILL_SHOW" then
        ShowUIPanel(self)
        if not self:IsShown() then return end
        Artisan.currentTab = GetTradeSkillLine()
        if ArtisanConfig.sorting[Artisan.currentTab] == "CUSTOM" then
            Artisan.UpdateSkills()
        else
            ArtisanEditor:Hide()
        end
        ArtisanFrameCreateButton:Disable()
        ArtisanFrameCreateAllButton:Disable()
        local selectionIndex = Artisan.GetTradeSkillSelectionIndex()
        if selectionIndex == 0 then
            Artisan.SetSelection(Artisan.GetFirstTradeSkill())
        else
            Artisan.SetSelection(selectionIndex)
        end
        FauxScrollFrame_SetOffset(ArtisanListScrollFrame, 0)
        ArtisanListScrollFrameScrollBar:SetMinMaxValues(0, 0)
        ArtisanListScrollFrameScrollBar:SetValue(0)
        SetPortraitTexture(ArtisanFramePortrait, "player")
        Artisan.UpdateFrame()
        TradeSkillOnlyShowMakeable(ArtisanConfig.reagents[Artisan.currentTab])
        TradeSkillFilter_OnTextChanged(ArtisanFrameSearchBox)
    elseif event == "TRADE_SKILL_CLOSE" then
        HideUIPanel(self)
    elseif event == "UPDATE_TRADESKILL_RECAST" then
        if not self:IsShown() then return end
        ArtisanFrameInputBox:SetNumber(GetTradeskillRepeatCount())
    elseif event == "REPLACE_ENCHANT" then
        ReplaceEnchant()
        StaticPopup_Hide("REPLACE_ENCHANT")
    elseif event == "TRADE_REPLACE_ENCHANT" then
        ReplaceTradeEnchant()
        StaticPopup_Hide("TRADE_REPLACE_ENCHANT")
    end
end

function Artisan.Initialize()
    if Artisan.initialized then return end

    for i = 1, MAX_TRADE_SKILL_REAGENTS do
        _G["ArtisanReagent"..i]:SetScript("OnMouseUp", _G["TradeSkillReagent"..i]:GetScript("OnMouseUp"))
    end

    local function status(parameter)
        local str = ""
        if parameter then
            str = "("..GREEN_FONT_COLOR_CODE.."ON|r)"
        else
            str = "("..GRAY_FONT_COLOR_CODE.."OFF|r)"
        end
        return str
    end

    SLASH_ARTISAN1 = "/artisan"

    SlashCmdList["ARTISAN"] = function(cmd)
        cmd = string.lower(string.trim(cmd))
        if cmd == "auto" then
            if ArtisanConfig.auto then
                ArtisanConfig.auto = false
                ArtisanFrame:UnregisterEvent("REPLACE_ENCHANT")
                ArtisanFrame:UnregisterEvent("TRADE_REPLACE_ENCHANT")
            else
                ArtisanConfig.auto = true
                ArtisanFrame:RegisterEvent("REPLACE_ENCHANT")
                ArtisanFrame:RegisterEvent("TRADE_REPLACE_ENCHANT")
            end
            DEFAULT_CHAT_FRAME:AddMessage(BLUE_FONT_COLOR_CODE.."[Artisan]|r auto confirmation is now "..status(ArtisanConfig.auto))
        elseif cmd == "icons" then
            if ArtisanConfig.icons then
                ArtisanConfig.icons = false
            else
                ArtisanConfig.icons = true
            end
            DEFAULT_CHAT_FRAME:AddMessage(BLUE_FONT_COLOR_CODE.."[Artisan]|r skill icons is now "..status(ArtisanConfig.icons))
        elseif cmd == "movable" then
            HideUIPanel(ArtisanFrame)
            if ArtisanConfig.movable then
                ArtisanConfig.movable = false
                UIPanelWindows["ArtisanFrame"] = { area = "left", pushable = 3 }
                ArtisanFrame:ClearAllPoints()
                ArtisanFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
            else
                ArtisanConfig.movable = true
                UIPanelWindows["ArtisanFrame"] = nil
                local point, relativeTo, relativePoint, offsetX, offsetY = ArtisanFrame:GetPoint()
                ArtisanConfig.X = offsetX
                ArtisanConfig.Y = offsetY
            end
            DEFAULT_CHAT_FRAME:AddMessage(BLUE_FONT_COLOR_CODE.."[Artisan]|r movable window is now "..status(ArtisanConfig.movable))
        else
            DEFAULT_CHAT_FRAME:AddMessage(BLUE_FONT_COLOR_CODE.."[Artisan]|r version "..GetAddOnMetadata("Artisan", "version"))
            DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR_CODE.."/artisan auto|r - auto confirmation of enchant replacements "..status(ArtisanConfig.auto))
            DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR_CODE.."/artisan icons|r - icons next to skill names "..status(ArtisanConfig.icons))
            DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR_CODE.."/artisan movable|r - movable window "..status(ArtisanConfig.movable))
        end
    end
    Artisan.initialized = true
end

function Artisan.UpdateTabs()
    local name, texture, offset, numSpells = SpellBook_GetTabInfo(1)
    local numTabs = 0
    
    for i = 1, #TabsOrder do
        for spell = 1, numSpells do
            local spellName = GetSpellName(spell, BOOKTYPE_SPELL)
            if spellName == TabsOrder[i] then
                numTabs = numTabs + 1
                if not Artisan.Tabs[numTabs] then Artisan.Tabs[numTabs] = {} end
                Artisan.Tabs[numTabs].name = spellName
                Artisan.Tabs[numTabs].texure = GetSpellTexture(spell, BOOKTYPE_SPELL)
                break
            end
        end
    end

    -- in case we abandoned skills
    for i = #Artisan.Tabs, numTabs + 1, -1 do table.remove(Artisan.Tabs, i) end

    for i = 1, MAX_TABS do
        local tabButton = _G["ArtisanFrameTab"..i]
        if i <= numTabs then
            tabButton.name = Artisan.Tabs[i].name
            tabButton:SetNormalTexture(Artisan.Tabs[i].texure)
            tabButton:Show()
            Artisan.Tabs[i].frame = tabButton
        else
            tabButton:Hide()
        end
    end
    
    if not ArtisanConfig.sorting then ArtisanConfig.sorting = {} end
    
    for _, v in pairs(Artisan.Tabs) do
        ArtisanConfig.sorting[v.name] = ArtisanConfig.sorting[v.name] or "DEFAULT"
        ArtisanConfig.reagents[v.name] = ArtisanConfig.reagents[v.name] or false
    end
end

function Artisan.UpdateFrame()
    local numTradeSkills = Artisan.GetNumTradeSkills()
    local skillOffset = FauxScrollFrame_GetOffset(ArtisanListScrollFrame)
    local selectionIndex = Artisan.GetTradeSkillSelectionIndex()
    local maxSkills = GetMaxVisibleSkills()
    Artisan.currentTab = GetTradeSkillLine()
    if IsTradeSkillLinked() then
        ArtisanConfig.sorting[Artisan.currentTab] = "DEFAULT"
    end
    
    if numTradeSkills == 0 then
        ArtisanSkillName:Hide()
        ArtisanSkillIcon:Hide()
        ArtisanRequirementLabel:Hide()
        ArtisanRequirementText:SetText("")
        ArtisanCollapseAllButton:Disable()
        for i = 1, MAX_TRADE_SKILL_REAGENTS do
            _G["ArtisanReagent"..i]:Hide()
        end
    else
        ArtisanSkillName:Show()
        ArtisanSkillIcon:Show()
        ArtisanCollapseAllButton:Enable()
    end

    local scrollBarShown = FauxScrollFrame_Update(ArtisanListScrollFrame, numTradeSkills, maxSkills, TRADE_SKILL_HEIGHT, nil, nil, nil, ArtisanHighlightFrame, 293, 316)

    ArtisanHighlightFrame:Hide()

    local skillName, skillType, numAvailable, isExpanded, altVerb
    local skillIndex, skillButton, skillButtonText, skillButtonCount, skillButtonIcon
    local indent = ArtisanConfig.icons and "   " or " "

    for i = 1, maxSkills do
        skillIndex = i + skillOffset
        skillName, skillType, numAvailable, isExpanded, altVerb = Artisan.GetTradeSkillInfo(skillIndex)
        skillButton = _G["ArtisanFrameSkill"..i]
        skillButtonText = _G["ArtisanFrameSkill"..i.."Text"]
        skillButtonCount = _G["ArtisanFrameSkill"..i.."Count"]
        skillButtonIcon = _G["ArtisanFrameSkill"..i.."Icon"]
        if skillIndex <= numTradeSkills then
            if scrollBarShown then
                skillButton:SetWidth(293)
            else
                skillButton:SetWidth(323)
            end
            local color = TradeSkillTypeColor[skillType]
            if color then
                skillButton:SetNormalFontObject(color.font)
                skillButtonCount:SetVertexColor(color.r, color.g, color.b)
                skillButton.r = color.r
                skillButton.g = color.g
                skillButton.b = color.b
            end
            skillButton:SetID(skillIndex)
            skillButton:Show()
            -- skillButton.skillType = skillType
            if skillType == "header" then
                skillButton:SetText(skillName)
                skillButtonText:SetWidth(TRADE_SKILL_TEXT_WIDTH)
                skillButtonCount:SetText("")
                if isExpanded then
                    skillButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                else
                    skillButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                end
                _G["ArtisanFrameSkill"..i.."Highlight"]:SetTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
                skillButton:UnlockHighlight()
                skillButtonIcon:SetTexture("")
            else
                if skillName then
                    skillButton:SetNormalTexture("")
                    _G["ArtisanFrameSkill"..i.."Highlight"]:SetTexture("")
                    if numAvailable == 0 then
                        skillButton:SetText(indent..skillName)
                    else
                        skillButton:SetText(indent..skillName.." ["..numAvailable.."]")
                    end
                    if ArtisanConfig.icons then
                        skillButtonIcon:SetTexture(Artisan.GetTradeSkillIcon(skillIndex))
                    else
                        skillButtonIcon:SetTexture("")
                    end
                end
                if selectionIndex == skillIndex then
                    ArtisanHighlightFrame:SetPoint("TOPLEFT", "ArtisanFrameSkill"..i, "TOPLEFT", 0, 0)
                    ArtisanHighlightFrame:Show()
                    skillButtonCount:SetVertexColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                    skillButton:LockHighlight()
                    skillButton.isHighlighted = true
                else
                    skillButton:UnlockHighlight()
                    skillButton.isHighlighted = false
                end
            end
        else
            skillButton:Hide()
        end
    end

    local numHeaders = 0
    local notExpanded = 0
    for i = 1, numTradeSkills do
        skillName, skillType, numAvailable, isExpanded, altVerb = Artisan.GetTradeSkillInfo(i)
        if skillName and skillType == "header" then
            numHeaders = numHeaders + 1
            if not isExpanded then
                notExpanded = notExpanded + 1
            end
        end
        if selectionIndex == i then
            ArtisanFrame.numAvailable = math.abs(numAvailable or 0)
        end
    end

    if notExpanded ~= numHeaders then
        ArtisanCollapseAllButton.collapsed = false
        ArtisanCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    else
        ArtisanCollapseAllButton.collapsed = true
        ArtisanCollapseAllButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
    end

    for i = 1, #Artisan.Tabs do
        _G["ArtisanFrameTab"..i]:SetChecked(IsSelectedSpell(Artisan.Tabs[i].name))
    end

    local sorting =  ArtisanConfig.sorting[Artisan.currentTab] or "DEFAULT"
    ArtisanSortDefault:SetChecked(sorting == "DEFAULT")
    ArtisanSortCustom:SetChecked(sorting == "CUSTOM")
    ArtisanHaveReagents:SetChecked(ArtisanConfig.reagents[Artisan.currentTab])
    if sorting == "CUSTOM" then
        ArtisanToggleEditorButton:Show()
    else
        ArtisanToggleEditorButton:Hide()
    end

    Artisan.EnableControls(not ArtisanEditor:IsShown())
end

function Artisan.SetSelection(id)
    if not id then return end
    
    local isLinked = IsTradeSkillLinked()
    if isLinked then
        ArtisanConfig.sorting[Artisan.currentTab] = "DEFAULT"
    end
    
    local skillName, skillType, numAvailable, isExpanded, altVerb = Artisan.GetTradeSkillInfo(id)
    
    if skillType == "header" then
        ArtisanHighlightFrame:Hide()
        if isExpanded then
            Artisan.CollapseTradeSkillSubClass(id)
        else
            Artisan.ExpandTradeSkillSubClass(id)
        end
        return
    end
    ArtisanHighlightFrame:Show()

    -- using the actual trade skill index in this function from this point
    id = Artisan.SelectTradeSkill(id)
    Artisan.selectedSkill = id
    if id > GetNumTradeSkills() then
        return
    end
    
    local color = TradeSkillTypeColor[skillType]
    if color then
        ArtisanHighlightFrameTexture:SetVertexColor(color.r, color.g, color.b)
    end

    local skillLineName, skillLineRank, skillLineMaxRank = GetTradeSkillLine()
    ArtisanRankFrameSkillName:SetFormattedText(TRADE_SKILL_TITLE, skillLineName)
    ArtisanRankFrame:SetMinMaxValues(0, skillLineMaxRank)
    ArtisanRankFrame:SetValue(skillLineRank)
    ArtisanRankFrameSkillRank:SetText(skillLineRank.."/"..skillLineMaxRank)
    -- ArtisanRankFrameGlow:SetPoint("RIGHT", ArtisanRankFrame, "LEFT", skillLineRank/skillLineMaxRank * ArtisanRankFrame:GetWidth()+6, 0)
    -- ArtisanRankFrameGlow:SetAlpha(0.1)
    -- ArtisanRankFrameSpark:SetPoint("RIGHT", ArtisanRankFrame, "LEFT", skillLineRank/skillLineMaxRank * ArtisanRankFrame:GetWidth()+15, 0)
    -- ArtisanRankFrameSpark:SetAlpha(0.05)
    ArtisanSkillName:SetText(skillName)
    ArtisanSkillIcon:SetNormalTexture(GetTradeSkillIcon(id))
    ArtisanSkillIconCount:SetText("")

    local cooldown = GetTradeSkillCooldown(id)
    if cooldown then
        ArtisanSkillCooldown:SetText(COOLDOWN_REMAINING.." "..SecondsToTime(cooldown))
    else
        ArtisanSkillCooldown:SetText("")
    end

    local minMade, maxMade = GetTradeSkillNumMade(id)
    if maxMade > 1 then
        if minMade == maxMade then
            ArtisanSkillIconCount:SetText(minMade)
        else
            ArtisanSkillIconCount:SetText(minMade.."-"..maxMade)
        end
        if ArtisanSkillIconCount:GetWidth() > 39 then
            ArtisanSkillIconCount:SetText("~"..floor((minMade + maxMade)/2))
        end
    else
        ArtisanSkillIconCount:SetText("")
    end

    local creatable = skillName and true or false
    local numReagents = GetTradeSkillNumReagents(id)
    if numReagents > 0 then
        ArtisanReagentLabel:Show()
    else
        ArtisanReagentLabel:Hide()
    end
    for i = 1, MAX_TRADE_SKILL_REAGENTS do
        local reagentName, reagentTexture, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(id, i)
        local reagent = _G["ArtisanReagent"..i]
        local name = _G["ArtisanReagent"..i.."Name"]
        local count = _G["ArtisanReagent"..i.."Count"]
        if i <= numReagents then
            if not (reagentName and reagentTexture) then
                creatable = false
                reagent:Hide()
            else
                reagent:Show()
                SetItemButtonTexture(reagent, reagentTexture)
                name:SetText(reagentName)
                if playerReagentCount < reagentCount then
                    SetItemButtonTextureVertexColor(reagent, 0.5, 0.5, 0.5)
                    name:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
                    creatable = false
                else
                    SetItemButtonTextureVertexColor(reagent, 1.0, 1.0, 1.0)
                    name:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
                end
                if playerReagentCount >= 100 then
                    playerReagentCount = "*"
                end
                count:SetText(playerReagentCount.." /"..reagentCount)
            end
        else
            reagent:Hide()
        end
    end

    if creatable then
        ArtisanFrameCreateButton:Enable()
        ArtisanFrameCreateAllButton:Enable()
    else
        ArtisanFrameCreateButton:Disable()
        ArtisanFrameCreateAllButton:Disable()
    end

    local spellFocus = BuildColoredListString(GetTradeSkillTools(id))
    if spellFocus then
        ArtisanRequirementLabel:Show()
        ArtisanRequirementText:SetText(spellFocus)
    else
        ArtisanRequirementLabel:Hide()
        ArtisanRequirementText:SetText("")
    end

    -- local description = GetTradeSkillDescription(id)
    -- if description then
    --     ArtisanSkillDescription:SetText(description)
    --     ArtisanReagentLabel:SetPoint("TOPLEFT", "ArtisanSkillDescription", "BOTTOMLEFT", 3, -5)
    -- else
    --     ArtisanSkillDescription:SetText("")
    --     ArtisanReagentLabel:SetPoint("TOPLEFT", "ArtisanSkillIcon", "BOTTOMLEFT", 0, -5)
    -- end
    
    -- Reset the number of items to be created
    ArtisanFrameInputBox:SetNumber(GetTradeskillRepeatCount())
    
    -- Hide inapplicable buttons if we are inspecting. Otherwise show them
    if isLinked then
        ArtisanFrameCreateButton:Hide()
        ArtisanFrameCreateAllButton:Hide()
        ArtisanFrameDecrementButton:Hide()
        ArtisanFrameInputBox:Hide()
        ArtisanFrameIncrementButton:Hide()
        ArtisanLinkButton:Hide()
        ArtisanEditor:Hide()
        ArtisanSortingLabel:Hide()
        ArtisanSortDefault:Hide()
        ArtisanSortCustom:Hide()
        for i = 1, #Artisan.Tabs do
            if Artisan.Tabs[i].frame then Artisan.Tabs[i].frame:Hide() end
        end
        ArtisanFrameBottomLeftTexture:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomLeft3")
        ArtisanFrameBottomRightTexture:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomRight2")
    else
        ArtisanSortingLabel:Show()
        ArtisanSortDefault:Show()
        ArtisanSortCustom:Show()
        for i = 1, #Artisan.Tabs do
            if Artisan.Tabs[i].frame then Artisan.Tabs[i].frame:Show() end
        end
        -- Change button names and show/hide them depending on if this tradeskill creates an item or casts something
        if not altVerb then
            -- Its an item with 'Create'
            ArtisanFrameCreateAllButton:Show()
            ArtisanFrameDecrementButton:Show()
            ArtisanFrameInputBox:Show()
            ArtisanFrameIncrementButton:Show()
            ArtisanFrameBottomLeftTexture:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomLeft")
            ArtisanFrameBottomRightTexture:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomRight")
        else
            -- Its something else
            ArtisanFrameCreateAllButton:Hide()
            ArtisanFrameDecrementButton:Hide()
            ArtisanFrameInputBox:Hide()
            ArtisanFrameIncrementButton:Hide()
            ArtisanFrameBottomLeftTexture:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomLeft2")
            ArtisanFrameBottomRightTexture:SetTexture("Interface\\AddOns\\Artisan\\Textures\\BottomRight")
        end
        if GetTradeSkillListLink() then
            ArtisanLinkButton:Show()
        else
            ArtisanLinkButton:Hide()
        end
        ArtisanFrameCreateButton:SetText(altVerb or CREATE)
        ArtisanFrameCreateButton:Show()
    end

    -- if using aux addon, setup total reagent cost
    if AuxFrame then
        local info = require("aux.util.info")
        local cache = require("aux.core.cache")
        local money = require("aux.util.money")
        local history = require("aux.core.history")
        local total_cost = 0
        local function cost_label(cost)
            local label = LIGHTYELLOW_FONT_COLOR_CODE .. '(Total Cost: ' .. FONT_COLOR_CODE_CLOSE
            label = label .. (cost and money.to_string2(cost, nil, LIGHTYELLOW_FONT_COLOR_CODE) or GRAY_FONT_COLOR_CODE .. '?' .. FONT_COLOR_CODE_CLOSE)
            label = label .. LIGHTYELLOW_FONT_COLOR_CODE .. ')' .. FONT_COLOR_CODE_CLOSE
            return label
        end
        for i = 1, numReagents do
            local link = GetTradeSkillReagentItemLink(id, i)
            if not link then
                total_cost = nil
                break
            end
            local item_id, suffix_id = info.parse_link(link)
            local count = select(3, GetTradeSkillReagentInfo(id, i))
            local _, price, limited = cache.merchant_info(item_id)
            local value = price and not limited and price or history.value(item_id .. ':' .. suffix_id)
            if not value then
                total_cost = nil
                break
            else
                total_cost = total_cost + value * count
            end
        end
        ArtisanReagentLabel:SetText(string.gsub(SPELL_REAGENTS, "|n", "")..cost_label(total_cost))
    end
end

function Artisan.UpdateSkills()
    local tab = Artisan.currentTab
    local sorting = ArtisanConfig.sorting[tab]
    if not (tab and sorting) then return end
    if not Artisan.CollapsedHeaders[tab] then Artisan.CollapsedHeaders[tab] = {} end
    if not ArtisanCustom[tab] then ArtisanCustom[tab] = {} end
    
    local numSkills = GetNumTradeSkills()
    local selectionName = Artisan.GetTradeSkillInfo(Artisan.GetTradeSkillSelectionIndex())

    table.wipe(Artisan.Skills)
    table.wipe(Artisan.CustomCategories)
    -- 1. copy custom headers
    for i = 1, #ArtisanCustom[tab] do
        local data = ArtisanCustom[tab][i]
        if data.isHeader then
            local isExpanded = not Artisan.CollapsedHeaders[tab][data.skillName] and 1 or nil
            table.insert(Artisan.Skills, {
                skillName = data.skillName,
                skillType = "header",
                numAvailable = 0,
                isExpanded = isExpanded,
                altVerb = nil,
                id = nil,
            })
            table.insert(Artisan.CustomCategories, Artisan.Skills[#Artisan.Skills])
        else
            for skill = 1, numSkills do
                local skillName, skillType, numAvailable, isExpanded, altVerb = GetTradeSkillInfo(skill)
                if skillName == data.skillName then
                    table.insert(Artisan.Skills, {
                        skillName = skillName,
                        skillType = skillType,
                        numAvailable = numAvailable,
                        isExpanded = nil,
                        altVerb = altVerb,
                        id = skill,
                    })
                    table.insert(Artisan.CustomCategories, Artisan.Skills[#Artisan.Skills])
                    break
                end
            end
        end
    end

    -- 2. put remaining skills into uncategorized header
    table.insert(Artisan.Skills, {
        skillName = "Uncategorized",
        skillType = "header",
        numAvailable = 0,
        isExpanded = not Artisan.CollapsedHeaders[tab]["Uncategorized"] and 1 or nil,
        altVerb = nil,
        id = nil,
    })
    table.wipe(Artisan.Uncategorized)
    for skill = 1, numSkills do
        local skillName, skillType, numAvailable, isExpanded, altVerb = GetTradeSkillInfo(skill)
        if skillType ~= "header" then
            local addToUncategorized = true
            for k, v in pairs(Artisan.Skills) do
                if v.skillName == skillName then addToUncategorized = false break end
            end
            if addToUncategorized then
                table.insert(Artisan.Skills, {
                    skillName = skillName,
                    skillType = skillType,
                    numAvailable = numAvailable,
                    isExpanded = nil,
                    altVerb = altVerb,
                    id = skill,
                })
                table.insert(Artisan.Uncategorized, Artisan.Skills[#Artisan.Skills])
            end
        end
    end

    -- 3. remove headers that dont contain any skills
    local remove
    local i = 1
    while i <= #Artisan.Skills do
        if Artisan.Skills[i].skillType == "header" then
            remove = not Artisan.Skills[i].isExpanded
            if (Artisan.Skills[i+1] and Artisan.Skills[i+1].skillType == "header") or not Artisan.Skills[i+1] then
                table.remove(Artisan.Skills, i)
            else
                i = i + 1
            end
        else
            if remove then
                table.remove(Artisan.Skills, i)
            else
                i = i + 1
            end
        end
    end

    -- 4. update selection index
    if selectionName then
        for i = 1, #Artisan.Skills do
            if Artisan.Skills[i].skillName == selectionName then
                Artisan.SelectTradeSkill(i)
                return
            end
        end
    end
    Artisan.SelectTradeSkill(0)
end

function Artisan.DetailScrollFrame_OnScrollRangeChanged(self, xrange, yrange)
    local name = self:GetName()
    local scrollbar = _G[name.."ScrollBar"]
    local top = _G[name.."Top"]
    local bottom = _G[name.."Bottom"]
    if GetTradeSkillNumReagents(Artisan.selectedSkill) <= 4 then
        yrange = 0
    end
    scrollbar:SetValue(0)
    ScrollFrame_OnScrollRangeChanged(self, 0, yrange)
    if yrange == 0 then
        top:Hide()
        bottom:Hide()
    else
        top:Show()
        bottom:Show()
    end
end

function Artisan.SkillButton_OnClick(self, button)
    if IsModifiedClick() then
        HandleModifiedItemClick(GetTradeSkillRecipeLink(self:GetID()))
    elseif button == "LeftButton" then
        Artisan.SetSelection(self:GetID())
        Artisan.UpdateFrame()
    end
end

function Artisan.IncrementButton_OnClick(self, button)
    if ArtisanFrameInputBox:GetNumber() < 100 then
        ArtisanFrameInputBox:SetNumber(ArtisanFrameInputBox:GetNumber() + 1)
    end
    ArtisanFrameSearchBox:ClearFocus()
end

function Artisan.DecrementButton_OnClick(self, button)
    if ArtisanFrameInputBox:GetNumber() > 0 then
        ArtisanFrameInputBox:SetNumber(ArtisanFrameInputBox:GetNumber() - 1)
    end
    ArtisanFrameSearchBox:ClearFocus()
end

function Artisan.CollapseAllButton_OnClick(self, button)
    if self.collapsed then
        self.collapsed = false
        Artisan.ExpandTradeSkillSubClass(0)
    else
        self.collapsed = true
        ArtisanListScrollFrameScrollBar:SetValue(0)
        Artisan.CollapseTradeSkillSubClass(0)
    end
end

function Artisan.Tab_OnCLick(self, button)
    if not self.name then return end
    if self.name == Artisan.currentTab then
        self:SetChecked(true)
        return
    end
    if self.name ~= Artisan.currentTab then
        Artisan.currentTab = self.name
        CastSpellByName(self.name)
    end
    PlaySound("igCharacterInfoTab")
end

function Artisan.HaveReagents_OnClick(self, button)
    ArtisanFrameSearchBox:ClearFocus()
    local checked = self:GetChecked() and true or false
    ArtisanConfig.reagents[Artisan.currentTab] = checked
    TradeSkillOnlyShowMakeable(checked)
    PlaySound("igMainMenuOptionCheckBoxOn")
    Artisan.UpdateFrame()
end

function Artisan.SortDefault_OnClick(self, button)
    ArtisanFrameSearchBox:ClearFocus()
    local checked = self:GetChecked() and true or false
    if not checked then
        self:SetChecked(true)
        return
    end
    ArtisanConfig.sorting[Artisan.currentTab] = "DEFAULT"
    PlaySound("igMainMenuOptionCheckBoxOn")
    Artisan.UpdateFrame()
    ArtisanEditor:Hide()
end

function Artisan.SortCustom_OnClick(self, button)
    ArtisanFrameSearchBox:ClearFocus()
    local checked = self:GetChecked() and true or false
    if not checked then
        self:SetChecked(true)
        return
    end
    ArtisanConfig.sorting[Artisan.currentTab] = "CUSTOM"
    PlaySound("igMainMenuOptionCheckBoxOn")
    ExpandTradeSkillSubClass(0)
    Artisan.UpdateSkills()
    Artisan.UpdateFrame()
end

function Artisan.ToggleEditorButton_OnClick(self, button)
    ArtisanFrameSearchBox:ClearFocus()
    if ArtisanEditor:IsShown() then
        ArtisanEditor:Hide()
    else
        ArtisanEditor:Show()
    end
end




function Artisan.GetNumTradeSkills()
    local numTradeSkills = 0
    if ArtisanConfig.sorting[Artisan.currentTab] == "CUSTOM" then
        numTradeSkills = #Artisan.Skills
    else
        numTradeSkills = GetNumTradeSkills()
    end
    return numTradeSkills
end

function Artisan.GetFirstTradeSkill()
    local id = 0
    if ArtisanConfig.sorting[Artisan.currentTab] == "CUSTOM" then
        for i = 1, #Artisan.Skills do
            if Artisan.Skills[i].skillType and Artisan.Skills[i].skillType ~= "header" then
                return i
            end
        end
    else
        id = GetFirstTradeSkill()
    end
    return id
end

function Artisan.SelectTradeSkill(id)
    id = max(0, id)
    if ArtisanConfig.sorting[Artisan.currentTab] == "CUSTOM" then
        id = Artisan.Skills[id] and Artisan.Skills[id].id or 0
    end
    SelectTradeSkill(id)
    return id
end

function Artisan.GetTradeSkillSelectionIndex()
    local trueIndex = GetTradeSkillSelectionIndex()
    local selectionIndex = trueIndex
    if ArtisanConfig.sorting[Artisan.currentTab] == "CUSTOM" then
        for index, data in pairs(Artisan.Skills) do
            if data.id == selectionIndex then return index end
        end
    end
    return selectionIndex, trueIndex
end

function Artisan.GetTradeSkillInfo(id)
    local skillName, skillType, numAvailable, isExpanded, altVerb
    if id > 0 and ArtisanConfig.sorting[Artisan.currentTab] == "CUSTOM" then
        local data = Artisan.Skills[id]
        if data then
            skillName, skillType, numAvailable, isExpanded, altVerb = data.skillName, data.skillType, data.numAvailable, data.isExpanded, data.altVerb
        end
    else
        skillName, skillType, numAvailable, isExpanded, altVerb = GetTradeSkillInfo(id)
    end
    return skillName, skillType, numAvailable, isExpanded, altVerb
end

function Artisan.GetTradeSkillIcon(id)
    if ArtisanConfig.sorting[Artisan.currentTab] == "CUSTOM" then
        id = Artisan.Skills[id].id
    end
    return GetTradeSkillIcon(id)
end

function Artisan.CollapseTradeSkillSubClass(id)
    local tab = Artisan.currentTab
    if ArtisanConfig.sorting[tab] == "CUSTOM" then
        if not Artisan.CollapsedHeaders[tab] then Artisan.CollapsedHeaders[tab] = {} end
        if id <= 0 then
            for i = 1, #Artisan.Skills do
                if Artisan.Skills[i].skillType == "header" then
                    Artisan.CollapsedHeaders[tab][Artisan.Skills[i].skillName] = true
                end
            end
            Artisan.UpdateSkills()
            Artisan.SetSelection(0)
            Artisan.UpdateFrame()
        else
            if Artisan.Skills[id].skillType ~= "header" then return end
            Artisan.CollapsedHeaders[tab][Artisan.Skills[id].skillName] = true
            Artisan.UpdateSkills()
            local allCollapsed = true
            for i = 1, #Artisan.Skills do
                if Artisan.Skills[i].isExpanded then
                    allCollapsed = false
                    break
                end
            end
            if allCollapsed then
                Artisan.SetSelection(0)
            else
                local selection = Artisan.GetTradeSkillSelectionIndex()
                if selection > 1 and selection <= Artisan.GetNumTradeSkills() and Artisan.Skills[selection] and Artisan.Skills[selection].skillType ~= "header" then
                    Artisan.SetSelection(selection)
                else
                    Artisan.SetSelection(Artisan.GetFirstTradeSkill())
                end
            end
            Artisan.UpdateFrame()
        end
    else
        return CollapseTradeSkillSubClass(id)
    end
end

function Artisan.ExpandTradeSkillSubClass(id)
    local tab = Artisan.currentTab
    if ArtisanConfig.sorting[tab] == "CUSTOM" then
        if not Artisan.CollapsedHeaders[tab] then Artisan.CollapsedHeaders[tab] = {} end
        if id <= 0 then
            for i = 1, #Artisan.Skills do
                if Artisan.Skills[i].skillType == "header" then
                    Artisan.CollapsedHeaders[tab][Artisan.Skills[i].skillName] = false
                end
            end
            Artisan.UpdateSkills()
            Artisan.SetSelection(Artisan.GetFirstTradeSkill())
            Artisan.UpdateFrame()
        else
            if Artisan.Skills[id].skillType ~= "header" then return end
            Artisan.CollapsedHeaders[tab][Artisan.Skills[id].skillName] = false
            Artisan.UpdateSkills()
            local selection = Artisan.GetTradeSkillSelectionIndex()
            if selection > 1 and selection <= Artisan.GetNumTradeSkills() and Artisan.Skills[selection] and Artisan.Skills[selection].skillType ~= "header" then
                Artisan.SetSelection(selection)
            else
                Artisan.SetSelection(Artisan.GetFirstTradeSkill())
            end
            Artisan.UpdateFrame()
        end
    else
        return ExpandTradeSkillSubClass(id)
    end
end

function Artisan.EnableControls(enable)
    local maxSkills = GetMaxVisibleSkills()
    if enable then
        TradeSkillOnlyShowMakeable(ArtisanConfig.reagents[Artisan.currentTab])
        ArtisanHaveReagents:Enable()
        ArtisanFrameSearchBox:EnableMouse(true)
        ArtisanFrameSearchBox:SetTextColor(1, 1, 1)
        TradeSkillFilter_OnTextChanged(ArtisanFrameSearchBox)
        for i = 1, maxSkills do
            _G["ArtisanFrameSkill"..i]:EnableMouse(true)
            _G["ArtisanFrameSkill"..i]:SetAlpha(1)
        end
        ArtisanCollapseAllButton:EnableMouse(true)
        ArtisanCollapseAllButton:SetAlpha(1)
        ArtisanListScrollFrameScrollBar:Enable()
        ArtisanListScrollFrameScrollBarScrollUpButton:Enable()
        ArtisanListScrollFrameScrollBarScrollDownButton:Enable()
        ArtisanListScrollFrame:EnableMouseWheel(true)
    else
        TradeSkillOnlyShowMakeable(false)
        ArtisanHaveReagents:Disable()
        ArtisanFrameSearchBox:EnableMouse(false)
        ArtisanFrameSearchBox:SetTextColor(GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
        SetTradeSkillItemLevelFilter(0, 0)
        SetTradeSkillItemNameFilter("")
        for i = 1, maxSkills do
            _G["ArtisanFrameSkill"..i]:EnableMouse(false)
            _G["ArtisanFrameSkill"..i]:SetAlpha(0.5)
        end
        ArtisanCollapseAllButton:EnableMouse(false)
        ArtisanCollapseAllButton:SetAlpha(0.5)
        ArtisanListScrollFrameScrollBar:Disable()
        ArtisanListScrollFrameScrollBarScrollUpButton:Disable()
        ArtisanListScrollFrameScrollBarScrollDownButton:Disable()
        ArtisanListScrollFrame:EnableMouseWheel(false)
    end
end
