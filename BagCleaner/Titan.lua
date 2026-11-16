-- BagCleaner 1.4.0: modern Titan Panel via LibDataBroker; legacy fallback.
local addonName, BC = ...
local ID, NAME = "BagCleaner", "TitanPanelBagCleanerButton"

function BagCleanerTitanText() return "BagCleaner" end
function BagCleanerTitanTooltip()
    return "BagCleaner: Taschen aufräumen\nLinks: Liste | Rechts: Optionen"
end

function BC:RegisterTitan()
    if self.titanRegistered then return end
    -- Modern Titan's LibDataBroker bridge supports an ordinary data source.
    if LibStub then
        local ok, broker = pcall(LibStub, "LibDataBroker-1.1", true)
        if not ok then broker = nil end
        if broker and type(broker.NewDataObject) == "function" then
            local obj = type(broker.GetDataObjectByName) == "function" and broker:GetDataObjectByName(ID) or nil
            if not obj then
                obj = broker:NewDataObject(ID, {
                    type = "data source", text = "BagCleaner", label = "BagCleaner",
                    icon = "Interface\\Icons\\INV_Misc_Bag_10",
                    OnClick = function(_, mouse)
                        if mouse == "RightButton" then BC:ToggleOptions()
                        else BC:OpenAndTogglePanel() end
                    end,
                    OnTooltipShow = function(tooltip)
                        tooltip:AddLine("BagCleaner")
                        tooltip:AddLine("Links: Aufräumliste; rechts: Optionen")
                    end,
                })
            end
            self.titanRegistered = obj ~= nil
            self.titanMode = "LDB"
            return
        end
    end

    -- Older Titan versions: register a native TitanPanelTextTemplate plugin.
    if type(_G.TitanPanelButton_OnLoad) ~= "function" then return end
    local frame = _G[NAME]
    if not frame then
        frame = CreateFrame("Button", NAME, UIParent, "TitanPanelTextTemplate")
        frame:SetSize(96, 16)
    end
    frame.registry = {
        id = ID, category = "Bags", version = "1.4.0",
        menuText = "BagCleaner", buttonTextFunction = "BagCleanerTitanText",
        tooltipTitle = "BagCleaner", tooltipTextFunction = "BagCleanerTitanTooltip",
        controlVariables = { ShowLabelText = true, DisplayOnRightSide = false },
        savedVariables = { ShowLabelText = 1 },
    }
    frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    frame:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then BC:ToggleOptions()
        else BC:OpenAndTogglePanel() end
    end)
    -- Templates have already queued the plug-in during OnLoad. If absent, queue once.
    if not frame.bagCleanerQueued and not _G.TitanPluginToBeRegistered then
        _G.TitanPanelButton_OnLoad(frame)
    end
    frame.bagCleanerQueued = true
    self.titanRegistered = true
    self.titanMode = "native"
end

function BC:PollTitan()
    if self.titanRegistered then return end
    local t = GetTime()
    if self.nextTitanTry and t < self.nextTitanTry then return end
    self.nextTitanTry = t + 1
    self:RegisterTitan()
end

BC:RegisterTitan()
