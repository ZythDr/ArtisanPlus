Artisan.EditorSelectionLeft = {}
Artisan.EditorSelectionRight = {}
Artisan.EditorLastSelectedIndexLeft = {}
Artisan.EditorLastSelectedIndexRight = {}

StaticPopupDialogs["ARTISAN_HEADER_CREATE"] = {
    text = "Enter category name:",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    OnShow = function(self)
        self.editBox:SetFocus()
        self.editBox:SetText("")
        StaticPopup_Hide("ARTISAN_HEADER_RENAME")
    end,
    EditBoxOnEnterPressed = function(self)
        Artisan.CreateHeader(self:GetText())
        self:SetText("")
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:SetText("")
        self:GetParent():Hide()
    end,
    OnAccept = function(self)
        Artisan.CreateHeader(self.editBox:GetText())
    end,
    timeout = 0,
	exclusive = 1,
	whileDead = 1,
    hideOnEscape = 1,
}

StaticPopupDialogs["ARTISAN_HEADER_RENAME"] = {
    text = "Enter category name:",
    button1 = OKAY,
    button2 = CANCEL,
    hasEditBox = 1,
    OnShow = function(self)
        self.editBox:SetFocus()
        self.editBox:SetText("")
        StaticPopup_Hide("ARTISAN_HEADER_CREATE")
    end,
    EditBoxOnEnterPressed = function(self)
        Artisan.RenameHeader(self:GetText())
        self:SetText("")
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:SetText("")
        self:GetParent():Hide()
    end,
    OnAccept = function(self)
        Artisan.RenameHeader(self.editBox:GetText())
    end,
    timeout = 0,
	exclusive = 1,
	whileDead = 1,
    hideOnEscape = 1,
}

local function tcontains(tbl, value)
    if type(tbl) ~= "table" then return nil end
    for k, v in pairs(tbl) do
        if v == value then return k end
    end
    return nil
end

local function GetSelectedHeader()
    if not Artisan.CustomCategories or not Artisan.EditorSelectionRight[Artisan.currentTab] then return nil, nil, nil end
    for i = #Artisan.CustomCategories, 1, -1 do
        if Artisan.CustomCategories[i].skillType == "header" then
            local index = tcontains(Artisan.EditorSelectionRight[Artisan.currentTab], Artisan.CustomCategories[i].skillName)
            if index then return Artisan.CustomCategories[i].skillName, i, index end
        end
    end
    return nil, nil, nil
end

local function ValidateSelection()
    local tab = Artisan.currentTab
    if not tab then return false, false, false, false end

    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = true, true, true, true
    local headersSelected = 0
    local nonheadersSelected = 0
    if #Artisan.EditorSelectionLeft[tab] == 0 or #Artisan.CustomCategories == 0 then
        canMoveRight = false
    end
    if #Artisan.EditorSelectionRight[tab] == 0 then
        canMoveLeft, canMoveUp, canMoveDown = false, false, false
    else
        for i = 1, #Artisan.CustomCategories do
            if tcontains(Artisan.EditorSelectionRight[tab], Artisan.CustomCategories[i].skillName) then
                local isHeader = Artisan.CustomCategories[i].skillType == "header"
                if isHeader then
                    headersSelected = headersSelected + 1
                else
                    nonheadersSelected = nonheadersSelected + 1
                end
                if i == #Artisan.CustomCategories then canMoveDown = false end
                if i < (isHeader and 2 or 3) then canMoveUp = false end
                if i == 1 and canMoveDown then
                    for j = 2, #Artisan.CustomCategories do
                        if not tcontains(Artisan.EditorSelectionRight[tab], Artisan.CustomCategories[j].skillName) then
                            canMoveDown = Artisan.CustomCategories[j].skillType == "header"
                            break
                        end
                    end
                end
            end
        end
        canMoveLeft = nonheadersSelected > 0
    end
    return canMoveLeft, canMoveRight, canMoveUp, canMoveDown, headersSelected, nonheadersSelected
end

function Artisan.EditorScrollFrameLeft_Update()
    if not Artisan.currentTab then return end
    local buttons = ArtisanEditorScrollFrameLeft.buttons
    local numButtons = #buttons
    local scrollOffset = HybridScrollFrame_GetOffset(ArtisanEditorScrollFrameLeft)
    local buttonHeight = buttons[1]:GetHeight()
    local numSkills = #Artisan.Uncategorized

    for i = 1, numButtons do
        local skillIndex = scrollOffset + i
        local skillButton = buttons[i]
        local data = Artisan.Uncategorized[skillIndex]
        if data and numSkills > 0 then
            local skillName, skillType = data.skillName, data.skillType
            skillButton:SetID(i)
            skillButton:SetText(skillName)

            skillButton.skillName = skillName
            skillButton.skillType = skillType
            skillButton.skillIndex = skillIndex
            local color = TradeSkillTypeColor[skillType]
            if color then
                skillButton:SetNormalFontObject(color.font)
                skillButton.r = color.r
                skillButton.g = color.g
                skillButton.b = color.b
                skillButton.Highlight:SetVertexColor(color.r, color.g, color.b, 0.5)
            end
            if ArtisanConfig.icons then
                skillButton.Icon:SetTexture(GetTradeSkillIcon(data.id))
                skillButton.Text:SetPoint("LEFT", skillButton.Icon, "RIGHT", 2, 1)
            else
                skillButton.Icon:SetTexture("")
                skillButton.Text:SetPoint("LEFT", skillButton, 2, 1)
            end
            if tcontains(Artisan.EditorSelectionLeft[Artisan.currentTab], skillName) then
                skillButton.Highlight:Show()
                skillButton:LockHighlight()
            else
                skillButton.Highlight:Hide()
                skillButton:UnlockHighlight()
            end
            skillButton:Show()
        else
            skillButton:Hide()
        end
    end
    HybridScrollFrame_Update(ArtisanEditorScrollFrameLeft, numSkills * buttonHeight, numButtons * buttonHeight)
end

function Artisan.EditorScrollFrameRight_Update()
    local tab = Artisan.currentTab
    if not tab then return end
    local buttons = ArtisanEditorScrollFrameRight.buttons
    local numButtons = #buttons
    local scrollOffset = HybridScrollFrame_GetOffset(ArtisanEditorScrollFrameRight)
    local buttonHeight = buttons[1]:GetHeight()
    local numSkills = #Artisan.CustomCategories

    for i = 1, numButtons do
        local skillIndex = scrollOffset + i
        local skillButton = buttons[i]
        local data = Artisan.CustomCategories[skillIndex]
        if data and numSkills > 0 then
            local skillName, skillType = data.skillName, data.skillType
            skillButton:SetID(i)
            skillButton.skillName = skillName
            skillButton.skillType = skillType
            skillButton.skillIndex = skillIndex
            local color = TradeSkillTypeColor[skillType]
            if color then
                skillButton:SetNormalFontObject(color.font)
                skillButton.r = color.r
                skillButton.g = color.g
                skillButton.b = color.b
                skillButton.Highlight:SetVertexColor(color.r, color.g, color.b, 0.5)
            end
            skillButton:SetText(skillName)
            if ArtisanConfig.icons then
                if skillType == "header" then
                    skillButton.Icon:SetTexture("")
                    skillButton.Text:SetPoint("LEFT", skillButton, 2, 1)
                else
                    skillButton.Icon:SetTexture(GetTradeSkillIcon(data.id))
                    skillButton.Icon:SetPoint("LEFT", skillButton, 12, 0)
                    skillButton.Text:SetPoint("LEFT", skillButton.Icon, "RIGHT", 2, 1)
                end
            else
                if skillType == "header" then
                    skillButton.Icon:SetTexture("")
                    skillButton.Text:SetPoint("LEFT", skillButton, 2, 1)
                else
                    skillButton.Icon:SetTexture("")
                    skillButton.Text:SetPoint("LEFT", skillButton, 12, 1)
                end
            end
            if tcontains(Artisan.EditorSelectionRight[tab], skillName) then
                skillButton.Highlight:Show()
                skillButton:LockHighlight()
            else
                skillButton.Highlight:Hide()
                skillButton:UnlockHighlight()
            end
            skillButton:Show()
        else
            skillButton:Hide()
        end
    end
    HybridScrollFrame_Update(ArtisanEditorScrollFrameRight, numSkills * buttonHeight, numButtons * buttonHeight)
end

function Artisan.UpdateEditor()
    local tab = Artisan.currentTab
    if not tab then return end

    Artisan.EditorScrollFrameLeft_Update()
    Artisan.EditorScrollFrameRight_Update()

    if not Artisan.EditorSelectionLeft[tab] then Artisan.EditorSelectionLeft[tab] = {} end
    if not Artisan.EditorSelectionRight[tab] then Artisan.EditorSelectionRight[tab] = {} end

    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown, headersSelected = ValidateSelection()
    if canMoveLeft then
        ArtisanEditorMoveLeft:Enable()
    else
        ArtisanEditorMoveLeft:Disable()
    end
    if canMoveRight then
        ArtisanEditorMoveRight:Enable()
    else
        ArtisanEditorMoveRight:Disable()
    end
    if canMoveUp then
        AdrtisanEditorMoveUp:Enable()
    else
        AdrtisanEditorMoveUp:Disable()
    end
    if canMoveDown then
        AdrtisanEditorMoveDown:Enable()
    else
        AdrtisanEditorMoveDown:Disable()
    end

    if headersSelected == 1 then
        ArtisanEditorDeleteHeader:Enable()
        ArtisanEditorRenameHeader:Enable()
    else
        ArtisanEditorDeleteHeader:Disable()
        ArtisanEditorRenameHeader:Disable()
    end

    Artisan.EditorSearchBox_OnTextChanged(ArtisanEditorSearchBox)
end

function Artisan.EditorButtonLeft_OnClick(self, button)
    local skillName = self.skillName
    local skillIndex = self.skillIndex
    local tab = Artisan.currentTab
    if not Artisan.EditorSelectionLeft[tab] then Artisan.EditorSelectionLeft[tab] = {} end
    local selectionIndex = tcontains(Artisan.EditorSelectionLeft[tab], skillName)
    local multipleSelected = #Artisan.EditorSelectionLeft[tab] > 1
    local lastSelectedIndex = Artisan.EditorLastSelectedIndexLeft[tab] or 1
    if selectionIndex then
        -- remove selection
        if IsControlKeyDown() then
            table.remove(Artisan.EditorSelectionLeft[tab], selectionIndex)
            Artisan.EditorLastSelectedIndexLeft[tab] = skillIndex
        elseif IsShiftKeyDown() then
            table.wipe(Artisan.EditorSelectionLeft[tab])
            for i = min(lastSelectedIndex, skillIndex), max(lastSelectedIndex, skillIndex) do
                table.insert(Artisan.EditorSelectionLeft[tab], Artisan.Uncategorized[i].skillName)
            end
        else
            table.wipe(Artisan.EditorSelectionLeft[tab])
            if multipleSelected then
                table.insert(Artisan.EditorSelectionLeft[tab], skillName)
            end
            Artisan.EditorLastSelectedIndexLeft[tab] = skillIndex
        end
    else
        -- add selection
        if IsControlKeyDown() then
            table.insert(Artisan.EditorSelectionLeft[tab], skillName)
            Artisan.EditorLastSelectedIndexLeft[tab] = skillIndex
        elseif IsShiftKeyDown() then
            table.wipe(Artisan.EditorSelectionLeft[tab])
            for i = min(lastSelectedIndex, skillIndex), max(lastSelectedIndex, skillIndex) do
                table.insert(Artisan.EditorSelectionLeft[tab], Artisan.Uncategorized[i].skillName)
            end
        else
            table.wipe(Artisan.EditorSelectionLeft[tab])
            table.insert(Artisan.EditorSelectionLeft[tab], skillName)
            Artisan.EditorLastSelectedIndexLeft[tab] = skillIndex
        end
    end

    Artisan.UpdateEditor()
end

function Artisan.EditorButtonRight_OnClick(self, button)
    local skillName = self.skillName
    local skillIndex = self.skillIndex
    local tab = Artisan.currentTab
    if not Artisan.EditorSelectionRight[tab] then Artisan.EditorSelectionRight[tab] = {} end
    local selectionIndex = tcontains(Artisan.EditorSelectionRight[tab], skillName)
    local multipleSelected = #Artisan.EditorSelectionRight[tab] > 1
    local lastSelectedIndex = Artisan.EditorLastSelectedIndexRight[tab] or 1
    if selectionIndex then
        -- remove selection
        if IsControlKeyDown() then
            table.remove(Artisan.EditorSelectionRight[tab], selectionIndex)
            Artisan.EditorLastSelectedIndexRight[tab] = skillIndex
        elseif IsShiftKeyDown() then
            table.wipe(Artisan.EditorSelectionRight[tab])
            for i = min(lastSelectedIndex, skillIndex), max(lastSelectedIndex, skillIndex) do
                table.insert(Artisan.EditorSelectionRight[tab], Artisan.CustomCategories[i].skillName)
            end
        else
            table.wipe(Artisan.EditorSelectionRight[tab])
            if multipleSelected then
                table.insert(Artisan.EditorSelectionRight[tab], skillName)
            end
            Artisan.EditorLastSelectedIndexRight[tab] = skillIndex
        end
    else
        -- add selection
        if IsControlKeyDown() then
            table.insert(Artisan.EditorSelectionRight[tab], skillName)
            Artisan.EditorLastSelectedIndexRight[tab] = skillIndex
        elseif IsShiftKeyDown() then
            table.wipe(Artisan.EditorSelectionRight[tab])
            for i = min(lastSelectedIndex, skillIndex), max(lastSelectedIndex, skillIndex) do
                table.insert(Artisan.EditorSelectionRight[tab], Artisan.CustomCategories[i].skillName)
            end
        else
            table.wipe(Artisan.EditorSelectionRight[tab])
            table.insert(Artisan.EditorSelectionRight[tab], skillName)
            Artisan.EditorLastSelectedIndexRight[tab] = skillIndex
        end
    end
    Artisan.UpdateEditor()
end

function Artisan.EditorMoveRight_OnClick(self, button)
    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = ValidateSelection()
    if not canMoveRight then return end
    local tab = Artisan.currentTab
    local insertionIndex = #Artisan.CustomCategories + 1
    for i = #Artisan.CustomCategories, 1, -1 do
        if tcontains(Artisan.EditorSelectionRight[tab], Artisan.CustomCategories[i].skillName) then
            insertionIndex = i + 1
            break
        end
    end
    for i = 1, #Artisan.Uncategorized do
        if tcontains(Artisan.EditorSelectionLeft[tab], Artisan.Uncategorized[i].skillName) then
            table.insert(Artisan.CustomCategories, insertionIndex, Artisan.Uncategorized[i])
            insertionIndex = insertionIndex + 1
        end
    end
    table.wipe(Artisan.EditorSelectionLeft[tab])
    Artisan.EditorLastSelectedIndexLeft[tab] = nil
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.EditorMoveLeft_OnClick(self, button)
    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = ValidateSelection()
    local tab = Artisan.currentTab
    if not canMoveLeft then return end
    for i = #Artisan.CustomCategories, 1, -1 do
        local index = tcontains(Artisan.EditorSelectionRight[tab], Artisan.CustomCategories[i].skillName)
        if index then
            if Artisan.CustomCategories[i].skillType ~= "header" then
                table.remove(Artisan.CustomCategories, i)
                table.remove(Artisan.EditorSelectionRight[tab], index)
            end
        end
    end
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.EditorMoveUp_OnClick(self, button)
    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = ValidateSelection()
    if not canMoveUp then return end
    local tab = Artisan.currentTab
    for i = 1, #Artisan.CustomCategories do
        local selected = tcontains(Artisan.EditorSelectionRight[tab], Artisan.CustomCategories[i].skillName)
        if selected then
            if i < 2 then return end
            Artisan.CustomCategories[i - 1], Artisan.CustomCategories[i] = Artisan.CustomCategories[i], Artisan.CustomCategories[i - 1]
        end
    end
    Artisan.EditorLastSelectedIndexRight[tab] = Artisan.EditorLastSelectedIndexRight[tab] - 1
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.EditorMoveDown_OnClick(self, button)
    local canMoveLeft, canMoveRight, canMoveUp, canMoveDown = ValidateSelection()
    if not canMoveDown then return end
    local tab = Artisan.currentTab
    for i = #Artisan.CustomCategories, 1, -1 do
        local selected = tcontains(Artisan.EditorSelectionRight[tab], Artisan.CustomCategories[i].skillName)
        if selected then
            if i == #Artisan.CustomCategories then return end
            Artisan.CustomCategories[i + 1], Artisan.CustomCategories[i] = Artisan.CustomCategories[i], Artisan.CustomCategories[i + 1]
        end
    end
    Artisan.EditorLastSelectedIndexRight[tab] = Artisan.EditorLastSelectedIndexRight[tab] + 1
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.CreateHeader(name)
    if string.trim(name) == "" then return end
    for i = #Artisan.CustomCategories, 1, -1 do
        if Artisan.CustomCategories[i].skillName == name then
            return
        end
    end
    local insertionIndex = #Artisan.CustomCategories + 1
    for i = #Artisan.CustomCategories, 1, -1 do
        if tcontains(Artisan.EditorSelectionRight[Artisan.currentTab], Artisan.CustomCategories[i].skillName) then
            insertionIndex = i + 1
            break
        end
    end
    table.insert(Artisan.CustomCategories, insertionIndex, { skillName = name, skillType = "header" })
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.DeleteHeader()
    local tab = Artisan.currentTab
    local selectedHeader, customIndex, selectionIndex = GetSelectedHeader()
    if not selectedHeader then return end
    local i = customIndex
    table.remove(Artisan.CustomCategories, i)
    while i <= #Artisan.CustomCategories do
        if Artisan.CustomCategories[i] and Artisan.CustomCategories[i].skillType == "header" then break end
        table.remove(Artisan.CustomCategories, i)
    end
    table.wipe(Artisan.EditorSelectionRight[tab])
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.RenameHeader(newName)
    local tab = Artisan.currentTab
    local selectedHeader, customIndex, selectionIndex = GetSelectedHeader()
    if not selectedHeader then return end
    Artisan.CustomCategories[customIndex].skillName = newName
    Artisan.EditorSelectionRight[tab][selectionIndex] = newName
    Artisan.EditorSaveChanges()
    Artisan.UpdateSkills()
    Artisan.UpdateEditor()
    Artisan.UpdateFrame()
end

function Artisan.EditorSaveChanges()
    local tab = Artisan.currentTab
    if not tab then return end
    if not ArtisanCustom[tab] then ArtisanCustom[tab] = {} end
    table.wipe(ArtisanCustom[tab])
    for i = 1, #Artisan.CustomCategories do
        table.insert(ArtisanCustom[tab], {
            skillName = Artisan.CustomCategories[i].skillName,
            isHeader = Artisan.CustomCategories[i].skillType == "header" or nil
        })
    end
end

function Artisan.EditorSearchBox_OnTextChanged(self, userInput)
    Artisan.UpdateSkills()
    local text = self:GetText()
    if text ~= "" then
        for i = #Artisan.Uncategorized, 1, -1 do
            if not string.find(string.lower(Artisan.Uncategorized[i].skillName), string.lower(text), 1, true) then
                table.remove(Artisan.Uncategorized, i)
            end
        end
    end
    Artisan.EditorScrollFrameLeft_Update()
end
