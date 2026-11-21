-- BagCleaner UI: no ElvUI files are modified; ElvUI is preferred when present.
local addonName, BC = ...
local floor, min, max = math.floor, math.min, math.max
local format = string.format
local ROWS, ROW_H = 10, 31
local PANEL_W, PANEL_H = 310, 495
local DARK = { 0.065, 0.075, 0.095, 0.96 }
local BORDER = { 0.25, 0.32, 0.41, 1 }
BC.uiPoll = 0
BC.mode = "standalone"

-- On WoW Forever, ordinary Frames do not always inherit SetBackdrop.
-- Skinning must therefore have a texture-based fallback that does not require
-- ElvUI, BackdropTemplate, or any other addon/library.
local function Fill(texture, rgba)
    if type(texture.SetColorTexture) == "function" then
        texture:SetColorTexture(rgba[1], rgba[2], rgba[3], rgba[4])
    else
        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        texture:SetVertexColor(rgba[1], rgba[2], rgba[3], rgba[4])
    end
end

local function SolidBackground(frame, color)
    if frame.BagCleanerBackground then return end
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    Fill(bg, color)
    bg:SetAllPoints(frame)
    frame.BagCleanerBackground = bg

    -- Four one-pixel edges: unlike SetBackdrop, these work on plain Frames.
    local edges = {}
    for i = 1, 4 do
        edges[i] = frame:CreateTexture(nil, "BORDER")
        Fill(edges[i], BORDER)
    end
    edges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    edges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    edges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    edges[4]:SetWidth(1)
    frame.BagCleanerBorder = edges
end

local function Skin(frame, color, requireSolid)
    local styled = false
    if type(frame.SetTemplate) == "function" then
        styled = pcall(frame.SetTemplate, frame, "Transparent")
    end
    if not styled and type(frame.SetBackdrop) == "function" then
        local ok = pcall(frame.SetBackdrop, frame, {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        if ok then
            frame:SetBackdropColor(unpack(color or DARK))
            frame:SetBackdropBorderColor(unpack(BORDER))
            styled = true
        end
    end
    if requireSolid or not styled then SolidBackground(frame, color or DARK) end
end

local function Label(parent, text, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 12, "")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetText(text or "")
    return fs
end

local function Button(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetWidth(width); btn:SetHeight(height)
    Skin(btn, {0.12, 0.14, 0.18, 0.98})
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    btn.text = Label(btn, text, 11)
    btn.text:SetPoint("CENTER", btn, "CENTER", 0, 0)
    return btn
end

local function Tip(button, lines)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for i, value in ipairs(lines) do GameTooltip:AddLine(value, 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Item protection is exclusively a right-click context-menu action.
-- An explicit Delete button must never change blacklist state, regardless
-- of keyboard modifiers or legacy SavedVariables shortcut settings.
function BC:OnItemListClick(item, mouse, anchor, deleteRequested)
    if not item then return end
    if mouse == "RightButton" then
        self:OpenItemMenu(item, anchor)
        return
    end
    if mouse ~= "LeftButton" or not deleteRequested then return end
    if item.protected then
        self.Print("Gegenstand geschützt (Option oder Blacklist).")
        return
    end
    if self.job or self.pending then
        self.Print("Ein anderer Löschvorgang ist bereits aktiv. Nutze 'Nächsten löschen'.")
        return
    end
    self:DeleteOne(item)
    -- With confirmation disabled, the same hardware click can perform deletion.
    if self.job then self:HardwareDeleteNext() end
end

-- A self-contained dropdown is used so it works in ElvUI and standalone
-- without taking over the game's ordinary inventory right-click actions.
function BC:MakeItemMenu()
    local menu = CreateFrame("Frame", "BagCleanerItemMenu", UIParent)
    menu:SetSize(190, 116)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(250)
    menu:SetToplevel(true)
    menu:SetClampedToScreen(true)
    Skin(menu)
    menu:Hide()
    self.itemMenu = menu
    local title = Label(menu, "Gegenstand", 11, 0.35, 0.75, 1)
    title:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -7)
    title:SetWidth(170)
    title:SetJustifyH("LEFT")
    menu.title = title
    menu.actionButtons = {}
    local actions = {
        { "Hide", function(item)
            BC:SetHiddenItem(item, true)
        end },
        { "Protect (Blacklist)", function(item)
            BC:SetProtectedItem(item, true)
        end },
        { "Hide + Protect", function(item)
            BC:HideAndProtectItem(item)
        end },
    }
    for i, action in ipairs(actions) do
        local button = Button(menu, action[1], 170, 24)
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -26 - (i-1)*27)
        menu.actionButtons[i] = button
        button:SetScript("OnClick", function()
            local item = menu.item
            menu:Hide()
            menu.item = nil
            if item then action[2](item) end
        end)
    end
end

function BC:OpenItemMenu(item, anchor)
    if not item or not self.itemMenu or not anchor then return end
    local menu = self.itemMenu
    if menu:IsShown() and menu.item and menu.item.id == item.id then
        menu:Hide()
        menu.item = nil
        return
    end
    menu.item = item
    menu.title:SetText(item.name)
    menu:ClearAllPoints()
    -- Custom dropdown opens to the left, and clamps if the screen is narrow.
    menu:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -5, 0)
    menu:Show()
end

function BC:GetElvBagFrame()
    -- Pick a currently visible candidate first: custom ElvUI forks may expose more than one.
    local candidates = {}
    local function candidate(frame)
        if frame and type(frame.IsShown) == "function" then
            if frame:IsShown() then return frame end
            table.insert(candidates, frame)
        end
    end
    local found = candidate(_G.ElvUI_ContainerFrame)
    if found then return found end
    local elv = _G.ElvUI and (_G.ElvUI[1] or _G.ElvUI)
    if elv and type(elv.GetModule) == "function" then
        local ok, bags = pcall(elv.GetModule, elv, "Bags")
        if ok and bags then
            found = candidate(bags.BagFrame)
            if found then return found end
        end
    end
    found = candidate(_G.ElvUIBagFrame)
    if found then return found end
    found = candidate(_G.ElvUI_BagFrame)
    if found then return found end
    return candidates[1]
end

function BC:GetBlizzardBagFrame()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined:IsShown() then return combined end
    local count = NUM_CONTAINER_FRAMES or 13
    for index = 1, count do
        local frame = _G["ContainerFrame" .. index]
        if frame and frame:IsShown() then return frame end
    end
    return nil
end

function BC:GetActiveBagFrame()
    local elvFrame = self:GetElvBagFrame()
    if elvFrame and elvFrame:IsShown() then return elvFrame, "elvui" end
    local blizzard = self:GetBlizzardBagFrame()
    if blizzard then return blizzard, "standalone" end
    return nil, elvFrame and "elvui" or "standalone"
end

function BC:DockPanel()
    if not self.panel or not self.anchor then return end
    local panel, anchor = self.panel, self.anchor
    panel:ClearAllPoints()
    local x = anchor:GetLeft()
    local minX = PANEL_W * (panel:GetEffectiveScale() or 1) + 10
    if x and x < minX then
        panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 5, 0)
    else
        panel:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -5, 0)
    end
end

function BC:TogglePanel()
    if not self.panel then return end
    if self.panel:IsShown() then
        if self.itemMenu then self.itemMenu:Hide() end
        self.panel:Hide(); return
    end
    local anchor = self:GetActiveBagFrame()
    if not anchor then
        self.Print("Bitte zuerst die Taschen öffnen.")
        return
    end
    self.anchor = anchor
    self:DockPanel()
    self.panel:Show()
    self:Refresh()
end

function BC:OpenAndTogglePanel()
    if self:GetActiveBagFrame() then
        self:TogglePanel()
        return
    end
    self.openRequested = true
    self.requestedAt = GetTime()
    if type(OpenAllBags) == "function" then OpenAllBags()
    elseif type(OpenBackpack) == "function" then OpenBackpack()
    elseif type(ToggleBackpack) == "function" then ToggleBackpack() end
    self:PollIntegration()
end

function BC:CheckVisibleBags()
    local frame, mode = self:GetActiveBagFrame()
    local wasOpen = self.bagsWereOpen
    local previousFrame = self.anchor
    local justOpened = frame and (not wasOpen or
        (previousFrame and previousFrame ~= frame and not previousFrame:IsShown()))
    self.bagsWereOpen = frame ~= nil
    if frame ~= self.anchor then
        self.anchor = frame
        if frame then
            self.mode = mode
            if self.panel and self.panel:IsShown() then self:DockPanel() end
        else
            if self.panel then self.panel:Hide() end
            if self.itemMenu then self.itemMenu:Hide() end
            if self.options then self.options:Hide() end
            if self.blacklistPanel then self.blacklistPanel:Hide() end
            if self.job and not self.job.allowClosed then self:StopJob("Taschen geschlossen; Aufräumen angehalten.") end
        end
    end
    if frame and ((self.db.autoOpen and justOpened) or self.openRequested) then
        self.openRequested = false
        if not self.panel:IsShown() then self.panel:Show() end
        self:DockPanel()
        self:Refresh()
    elseif not frame and self.openRequested and self.requestedAt and GetTime() - self.requestedAt > 3 then
        self.openRequested = false
    end
    if self.panel and self.panel:IsShown() and frame then self:DockPanel() end

    if self.standaloneButton then
        if frame and mode == "standalone" then
            self.standaloneButton:ClearAllPoints()
            self.standaloneButton:SetPoint("TOPRIGHT", frame, "TOPLEFT", -5, 0)
            self.standaloneButton:Show()
        else
            self.standaloneButton:Hide()
        end
    end
    -- The ElvUI launchers are UIParent-owned, so explicitly synchronize visibility.
    if self.elvButton then
        if frame and mode == "elvui" then self.elvButton:Show() else self.elvButton:Hide() end
    end
    if self.elvMenuButton then
        local holder = self.elvMenuHolder
        if frame and mode == "elvui" and holder and holder:IsShown() then
            self.elvMenuButton:Show()
        else self.elvMenuButton:Hide() end
    end
end

function BC:SyncOptions()
    if not self.options or not self.db then return end
    self.options.auto:SetChecked(self.db.autoOpen)
    self.options.protect:SetChecked(self.db.protectWhite)
    self.options.confirm:SetChecked(self.db.confirmDelete)
end

function BC:ShowOptions()
    if not self.options then return end
    -- Options always open centered above the BagCleaner list and ElvUI bags.
    -- They must not be anchored to an inventory button or holder frame.
    self.options:ClearAllPoints()
    self.options:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self:SyncOptions()
    self.options:Show()
    if type(self.options.Raise) == "function" then self.options:Raise() end
end

function BC:ToggleOptions()
    if not self.options then return end
    if self.options:IsShown() then
        self.options:Hide()
    else
        self:ShowOptions()
    end
end

function BC:ToggleBlacklist()
    if not self.blacklistPanel then return end
    if self.blacklistPanel:IsShown() then self.blacklistPanel:Hide()
    else
        if self.options and self.options:IsShown() then
            self.blacklistPanel:ClearAllPoints()
            self.blacklistPanel:SetPoint("TOPRIGHT", self.options, "TOPLEFT", -6, 0)
        end
        self:RefreshBlacklist()
        self.blacklistPanel:Show()
    end
end

function BC:MakeOptions()
    local f = CreateFrame("Frame", "BagCleanerOptions", UIParent)
    f:SetSize(310, 203)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:SetToplevel(true)
    f:EnableMouse(true)
    Skin(f)
    f:Hide()
    self.options = f
    f.title = Label(f, "BagCleaner – Taschenmenü", 12, 0.35, 0.75, 1)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    local close = Button(f, "x", 20, 18)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function()
        f:Hide()
    end)
    local function Check(name, caption, y, func)
        local cb = CreateFrame("CheckButton", name, f, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", f, "TOPLEFT", 7, y)
        local text = _G[name .. "Text"] or cb.Text
        if text then text:SetText(caption); text:SetFont(STANDARD_TEXT_FONT, 11) end
        cb:SetScript("OnClick", func)
        return cb
    end
    f.auto = Check("BagCleanerAutoOpen", "Mit den Taschen automatisch öffnen", -33, function(btn)
        BC.db.autoOpen = btn:GetChecked() and true or false
    end)
    f.protect = Check("BagCleanerProtectWhite", "Weiße Gegenstände schützen (optional)", -61, function(btn)
        BC.db.protectWhite = btn:GetChecked() and true or false
        BC:RequestRefresh()
    end)
    f.confirm = Check("BagCleanerConfirmDelete", "Vor dem Löschen bestätigen", -89, function(btn)
        BC.db.confirmDelete = btn:GetChecked() and true or false
    end)
    local blacklist = Button(f, "Hide / Protect verwalten ...", 273, 23)
    blacklist:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -130)
    blacklist:SetScript("OnClick", function()
        BC:ToggleBlacklist()
    end)
    local help = Label(f, "Links: Löschen  |  Rechts: Hide / Protect", 10, 0.65, 0.7, 0.77)
    help:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 11)
    self:SyncOptions()
end

function BC:BlacklistCount()
    local count = 0
    if not self.db then return 0 end
    local ids = {}
    for id in pairs(self.db.blacklist) do ids[id] = true end
    for id in pairs(self.db.hidden) do ids[id] = true end
    for _ in pairs(ids) do count = count + 1 end
    return count
end

function BC:RefreshBlacklist()
    local panel = self.blacklistPanel
    if not panel or not self.db then return end
    local data, ids = {}, {}
    for id in pairs(self.db.blacklist) do ids[id] = true end
    for id in pairs(self.db.hidden) do ids[id] = true end
    for key in pairs(ids) do
        local id = tonumber(key)
        if id then
            local name = self.db.blacklist[key] or self.db.hidden[key]
            table.insert(data, { id = id, name = tostring(name),
                hidden = self.db.hidden[key] ~= nil,
                protected = self.db.blacklist[key] ~= nil })
        end
    end
    table.sort(data, function(a,b) return a.id < b.id end)
    local count = #data
    panel.offset = math.min(panel.offset or 0, math.max(0, count - #panel.rows))
    local offset = panel.offset
    for i, row in ipairs(panel.rows) do
        local entry = data[offset + i]
        row.entry = entry
        if entry then
            local flag = (entry.hidden and "H" or "-") .. "/" .. (entry.protected and "P" or "-")
            row.text:SetText(entry.name .. "  [" .. flag .. "]  (#" .. entry.id .. ")")
            row:Show()
        else row:Hide() end
    end
    panel.count:SetText(count .. " Einträge (H=Hide, P=Protect)")
end

function BC:MakeBlacklistPanel()
    local f = CreateFrame("Frame", "BagCleanerBlacklist", UIParent)
    f:SetSize(365, 355)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    Skin(f)
    f:Hide()
    self.blacklistPanel = f
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    local title = Label(f, "Ausgeblendet & geschützt", 13, 0.35, 0.75, 1)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -13)
    local close = Button(f, "x", 20, 20)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -7, -8)
    close:SetScript("OnClick", function() f:Hide() end)
    local hint = Label(f, "Item-ID oder Item-Link schützen:", 11, 1, 1, 1)
    hint:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -45)
    local input = CreateFrame("EditBox", "BagCleanerBlacklistInput", f, "InputBoxTemplate")
    input:SetSize(195, 20)
    input:SetPoint("TOPLEFT", f, "TOPLEFT", 23, -69)
    input:SetAutoFocus(false)
    input:SetMaxLetters(255)
    local add = Button(f, "Protect", 94, 22)
    add:SetPoint("LEFT", input, "RIGHT", 8, 0)
    local function submit()
        if BC:AddBlacklist(input:GetText()) then input:SetText("") end
        input:ClearFocus()
    end
    add:SetScript("OnClick", submit)
    input:SetScript("OnEnterPressed", submit)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.count = Label(f, "", 11, 0.7, 0.8, 0.9)
    f.count:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -103)
    f.rows = {}
    f.offset = 0
    local function scrollBlacklist(_, delta)
        f.offset = max(0, min(max(0, BC:BlacklistCount() - 6), f.offset - delta))
        BC:RefreshBlacklist()
    end
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", scrollBlacklist)
    for i=1,6 do
        local row = Button(f, "", 337, 26)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 13, -129 - (i-1)*29)
        row.text:SetPoint("CENTER", row, "CENTER", 0, 0)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, mouse)
            local entry = self.entry
            if not entry then return end
            if mouse == "RightButton" then
                if entry.protected then BC:RemoveBlacklist(entry.id) end
            elseif entry.hidden then
                BC:UnhideItem(entry.id)
            elseif entry.protected then
                BC:RemoveBlacklist(entry.id)
            end
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", scrollBlacklist)
        f.rows[i] = row
    end
    local footer = Label(f, "Links: Hide entfernen | Rechts: Protect entfernen", 10, 0.66, 0.74, 0.83)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 13, 11)
end

function BC:SetupElvUI(frame)
    if not frame then return end
    if self.elvHooked ~= frame then
        self.elvHooked = frame
        if self.elvButton then self.elvButton:Hide() end
        -- Parent to UIParent, not the often-clipped ElvUI bag region.
        local toolbar = Button(UIParent, "Clean", 62, 23)
        toolbar:SetFrameStrata("FULLSCREEN")
        toolbar:SetFrameLevel(150)
        -- Outside the bag's header: cannot overlap search, currency or the existing ElvUI controls.
        toolbar:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -5)
        toolbar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        toolbar:SetScript("OnClick", function(_, mouse)
            if mouse == "RightButton" then BC:ToggleOptions() else BC:TogglePanel() end
        end)
        Tip(toolbar, {"BagCleaner", "Links: Seitenleiste öffnen/schließen", "Rechts: Einstellungen"})
        self.elvButton = toolbar
    end
    local holder = frame.ContainerHolder or _G.ElvUI_ContainerFrameContainerHolder
    if holder and self.elvMenuHolder ~= holder then
        self.elvMenuHolder = holder
        if self.elvMenuButton then self.elvMenuButton:Hide() end
        local menuButton = Button(UIParent, "Clean", 62, 22)
        menuButton:SetFrameStrata("FULLSCREEN")
        menuButton:SetFrameLevel(150)
        menuButton:SetPoint("LEFT", holder, "RIGHT", 6, 0)
        menuButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        menuButton:SetScript("OnClick", function(_, mouse)
            if mouse == "RightButton" then BC:ToggleOptions() else BC:TogglePanel() end
        end)
        Tip(menuButton, {"BagCleaner: links Liste, rechts Einstellungen"})
        self.elvMenuButton = menuButton
        menuButton:Hide()
        holder:HookScript("OnShow", function()
            -- The requested checkboxes become visible alongside ElvUI's small bag menu.
            BC:ShowOptions(holder)
            if BC.elvMenuButton then BC.elvMenuButton:Show() end
        end)
        holder:HookScript("OnHide", function()
            if BC.options then BC.options:Hide() end
            if BC.elvMenuButton then BC.elvMenuButton:Hide() end
        end)
        if holder:IsShown() then self:ShowOptions(holder) end
    end
end

function BC:MakeStandaloneButton()
    local btn = Button(UIParent, "Clean", 62, 23)
    btn:SetFrameStrata("HIGH")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, mouse)
        if mouse == "RightButton" then BC:ToggleOptions() else BC:TogglePanel() end
    end)
    Tip(btn, {"BagCleaner", "Links: Seitenleiste", "Rechts: Optionen"})
    btn:Hide()
    self.standaloneButton = btn
end

-- Always-visible fallback, even if the user's ElvUI fork has different frame names
-- or Titan Panel is not available. Drag with the left mouse button to reposition.
function BC:MakeMinimapButton()
    if self.minimapButton then return end
    local map = _G.Minimap
    if not map then return end
    local btn = CreateFrame("Button", "BagCleanerMinimapButton", map)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(15)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetMovable(true)
    btn:SetClampedToScreen(true)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10")
    icon:SetSize(19, 19)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(49, 49)
    border:SetPoint("CENTER", btn, "CENTER", 11, -10)
    btn:SetPoint("TOPLEFT", map, "TOPLEFT", 1, -12)
    btn:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then BC:ToggleOptions()
        else BC:OpenAndTogglePanel() end
    end)
    btn:SetScript("OnDragStart", function(self)
        if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
    end)
    btn:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    Tip(btn, {"BagCleaner", "Linksklick: Taschen & Clean-Liste", "Rechtsklick: Einstellungen", "Ziehen: Symbol verschieben"})
    self.minimapButton = btn
end

function BC:PollIntegration()
    if not self.panel then return end
    local now = GetTime()
    if now < self.uiPoll then return end
    self.uiPoll = now + 0.25
    local frame = self:GetElvBagFrame()
    if frame then
        self:SetupElvUI(frame)
        if self.elvButton then self.elvButton:SetShown(frame:IsShown()) end
    elseif self.elvButton then self.elvButton:Hide() end
    self:CheckVisibleBags()
end

function BC:RefreshUI()
    local panel = self.panel
    if not panel or not panel:IsShown() then return end
    local items = self.items or {}
    panel.offset = min(panel.offset or 0, max(0, #items - ROWS))
    local offset = panel.offset
    for index = 1, ROWS do
        local row = panel.rows[index]
        local item = items[index + offset]
        row.item = item
        if item then
            row.icon:SetTexture(item.icon)
            local color = item.quality == 0 and 0.62 or 1
            row.name:SetTextColor(color, color, color)
            row.name:SetText(item.name)
            row.amount:SetText("x" .. item.count)
            row.value:SetText(self:Money(item.total))
            row.value:SetTextColor(item.protected and 0.57 or 0.61,
                item.protected and 0.72 or 0.84, 1)
            -- Protection belongs to the right-click menu, not the row action.
            -- The left-click button remains "Löschen" even on protected rows;
            -- the existing protection guard prevents an accidental deletion.
            row.deleteButton.text:SetText("Löschen")
            if item.protected then
                row.deleteButton.text:SetTextColor(0.52, 0.57, 0.65)
            else
                row.deleteButton.text:SetTextColor(1, 0.53, 0.53)
            end
            row:Show()
        else
            row:Hide()
        end
    end
    panel.count:SetText(#items .. " Stapel  |  " .. self:GetFreeSlots() .. " freie Plätze")
    panel.sortButton.text:SetText("Gesamtwert aufsteigend")
    local job = self.job
    if job then
        panel.status:SetText("Gelöscht: " .. job.done .. "/" .. #job.items ..
            (job.waiting and " (warte auf Inventar)" or " (nächster Klick)"))
        panel.run.text:SetText(job.waiting and "Bitte warten" or "Nächsten löschen")
        if job.waiting then panel.run:Disable() else panel.run:Enable() end
    else
        panel.status:SetText((self.db.confirmDelete and "Bestätigung AN" or "Bestätigung AUS") ..
            (self.db.protectWhite and "  |  Weiß geschützt" or "  |  Weiß frei, außer Blacklist"))
        panel.run.text:SetText("Platz schaffen")
        panel.run:Enable()
    end
end

-- Dedicated, *addon-owned* delete confirmation. Unlike the Blizzard popup system,
-- this does not write to Blizzard's global secure popup registry. Closing the
-- window without accepting always discards the pending request.
function BC:MakeDeleteConfirmation()
    local frame = CreateFrame("Frame", "BagCleanerDeleteConfirmation", UIParent)
    frame:SetSize(490, 315)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(200)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    Skin(frame, DARK, true)
    frame:Hide()

    local title = Label(frame, "BagCleaner - Löschung bestätigen", 14, 0.35, 0.75, 1)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -15)

    local description = Label(frame, "", 11, 1, 1, 1)
    description:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -48)
    description:SetWidth(456)
    description:SetHeight(211)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    frame.description = description

    local cancel = Button(frame, "Abbrechen", 105, 28)
    cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
    cancel:SetScript("OnClick", function() frame:Hide() end)

    local accept = Button(frame, "Jetzt löschen", 120, 28)
    accept:SetPoint("RIGHT", cancel, "LEFT", -10, 0)
    accept:SetScript("OnClick", function()
        -- AcceptPending validates every live slot again; deletion is invoked
        -- directly by this hardware click, never by an OnUpdate callback.
        BC:AcceptPending()
        frame:Hide()
        if BC.job then BC:HardwareDeleteNext() end
    end)
    frame:SetScript("OnHide", function()
        -- Cancellation, closing and visibility changes fail closed.
        BC.pending = nil
    end)
    frame.acceptButton = accept
    frame.cancelButton = cancel
    self.deleteConfirmation = frame
end

function BC:ShowDeleteConfirmation(message)
    local frame = self.deleteConfirmation
    if not frame or type(message) ~= "string" then return false end
    frame.description:SetText(message)
    frame:Show()
    return true
end

function BC:MakePanel()
    local panel = CreateFrame("Frame", "BagCleanerPanel", UIParent)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    Skin(panel, DARK, true) -- Opaque even without ElvUI/SetBackdrop.
    panel:Hide()
    self.panel = panel
    local title = Label(panel, "BagCleaner", 14, 0.3, 0.75, 1)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 13, -13)
    local close = Button(panel, "x", 22, 21)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function()
        if BC.itemMenu then BC.itemMenu:Hide() end
        panel:Hide()
    end)
    local sortBtn = Button(panel, "Gesamtwert aufsteigend", 152, 21)
    sortBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -42)
    sortBtn:SetScript("OnClick", function()
        -- Re-scan and return to the cheapest item, never switch to unit price.
        panel.offset = 0
        BC:Refresh()
    end)
    Tip(sortBtn, {"Günstigster Stapel zuerst (Gesamtwert)",
        "Klick: neu sortieren und nach ganz oben springen.",
        "Anzahl pro Stapel × Händlerpreis pro Stück."})
    panel.sortButton = sortBtn
    local settings = Button(panel, "Optionen", 75, 21)
    settings:SetPoint("LEFT", sortBtn, "RIGHT", 7, 0)
    settings:SetScript("OnClick", function() BC:ToggleOptions() end)

    local amountLabel = Label(panel, "Plätze:", 11)
    amountLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 13, -80)
    local amount = CreateFrame("EditBox", "BagCleanerAmount", panel, "InputBoxTemplate")
    amount:SetSize(38, 20)
    amount:SetPoint("LEFT", amountLabel, "RIGHT", 9, 0)
    amount:SetAutoFocus(false)
    amount:SetNumeric(true)
    amount:SetMaxLetters(3)
    amount:SetText(tostring(BC.db.lastSlots))
    amount:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    amount:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(BC.db.lastSlots)); self:ClearFocus()
    end)
    amount:SetScript("OnEditFocusLost", function(self)
        local number = tonumber(self:GetText())
        if number then BC.db.lastSlots = max(1, min(128, floor(number))) end
        self:SetText(tostring(BC.db.lastSlots))
    end)
    local run = Button(panel, "Platz schaffen", 105, 25)
    run:SetPoint("LEFT", amount, "RIGHT", 10, 0)
    run:SetScript("OnClick", function()
        if BC.job then BC:HardwareDeleteNext(); return end
        amount:ClearFocus()
        BC:Cleanup(tonumber(amount:GetText()) or BC.db.lastSlots)
        -- With confirmation off, the user's real click can delete the first item.
        if BC.job then BC:HardwareDeleteNext() end
        amount:SetText(tostring(BC.db.lastSlots))
    end)
    local runAll = Button(panel, "Alle", 48, 25)
    runAll:SetPoint("LEFT", run, "RIGHT", 7, 0)
    runAll:SetScript("OnClick", function()
        if BC.job then BC:HardwareDeleteNext(); return end
        BC:Cleanup(nil, true)
        if BC.job then BC:HardwareDeleteNext() end
    end)
    Tip(runAll, {"Alle geeigneten Stapel auswählen", "Zum Löschen ist bei Forever je Stapel ein Klick nötig."})
    panel.run = run
    panel.runAll = runAll
    panel.amount = amount

    panel.count = Label(panel, "", 10, 0.74, 0.8, 0.86)
    panel.count:SetPoint("TOPLEFT", panel, "TOPLEFT", 13, -111)
    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(0.25, 0.32, 0.4, 0.85)
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -130)
    divider:SetSize(PANEL_W - 23, 1)

    panel.offset = 0
    local function scrollItems(_, delta)
        panel.offset = max(0, min(max(0, #(BC.items or {}) - ROWS), panel.offset - delta))
        BC:RefreshUI()
    end
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", scrollItems)
    panel.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Button", nil, panel)
        row:SetSize(PANEL_W - 36, ROW_H - 2)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -139 - (i - 1) * ROW_H)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(25, 25)
        row.icon:SetPoint("LEFT", row, "LEFT", 1, 0)
        row.name = Label(row, "", 11)
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 33, -3)
        row.name:SetWidth(170); row.name:SetJustifyH("LEFT")
        row.amount = Label(row, "", 10, 0.61, 0.84, 1)
        row.amount:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 33, 3)
        row.value = Label(row, "", 10, 0.61, 0.84, 1)
        row.value:SetWidth(118)
        row.value:SetJustifyH("RIGHT")
        row.value:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -61, 3)
        -- Explicit clickable button. The old non-clickable 'X' / '[S]' label
        -- looked like a stray number and gave no visible deletion affordance.
        row.deleteButton = Button(row, "Löschen", 56, 22)
        row.deleteButton:SetPoint("RIGHT", row, "RIGHT", -1, 0)
        row.deleteButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.deleteButton:SetScript("OnClick", function(self, mouse)
            -- Keep a left click strictly as a delete request (never Protect).
            BC:OnItemListClick(row.item,
                mouse == "RightButton" and "RightButton" or "LeftButton", row, true)
        end)
        Tip(row.deleteButton, {
            "Linksklick: genau diesen Stapel löschen", "Geschützte Stapel sind nicht löschbar.",
            "Rechtsklick: Hide / Protect / Hide + Protect",
        })
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, mouse)
            BC:OnItemListClick(self.item, mouse, self, false)
        end)
        row:SetScript("OnEnter", function(self)
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.item.link)
            GameTooltip:AddLine("Löschen-Button: diesen Stapel löschen", 0.8, 0.9, 1)
            GameTooltip:AddLine("Rechtsklick: Hide / Protect / Beides", 0.8, 0.9, 1)
            if self.item.protected then GameTooltip:AddLine("Geschützt", 1, 0.65, 0.35) end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", scrollItems)
        panel.rows[i] = row
    end
    panel.status = Label(panel, "", 10, 0.75, 0.8, 0.85)
    panel.status:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 13, 16)
end

function BC:CreateUI()
    -- Make each independent entry point resilient to errors in another section.
    -- Previously an error in the panel could prevent all launchers from appearing.
    local sections = {"MakeOptions", "MakeBlacklistPanel", "MakePanel", "MakeDeleteConfirmation", "MakeItemMenu", "MakeStandaloneButton", "MakeMinimapButton"}
    for _, name in ipairs(sections) do
        local ok, err = pcall(self[name], self)
        if not ok then self.Print(name .. " fehlgeschlagen: " .. tostring(err)) end
    end
    if self.panel then self:PollIntegration() end
end
