-- BagCleaner 1.4.1 - WoW Forever 1.60.1 (Lua 5.1)
-- Standalone by default, with an automatic ElvUI bags integration.
local addonName, BC = ...
_G.BagCleaner = BC

local floor, max, min = math.floor, math.max, math.min
local format = string.format
local insert, sort = table.insert, table.sort
local unpack = unpack
local DEFAULTS = { autoOpen = false, protectWhite = true, confirmDelete = true, lastSlots = 3, sortBy = "stack", blacklistShortcut = "CTRL-SHIFT" }
local eventFrame = CreateFrame("Frame")
BC.frame = eventFrame
BC.items = {}
BC.pending = nil
BC.job = nil
BC.needsRefresh = false
BC.refreshAt = 0
BC.elapsed = 0

local function say(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff59bfffBagCleaner:|r " .. tostring(message)) end
end
BC.Print = say

function BC:InitDB()
    if type(BagCleanerDB) ~= "table" then BagCleanerDB = {} end
    for key, value in pairs(DEFAULTS) do
        if BagCleanerDB[key] == nil then BagCleanerDB[key] = value end
    end
    -- Previous builds allowed unit-price sorting. Always prioritize the total
    -- vendor value of one stack; migrate previous account settings as well.
    BagCleanerDB.sortBy = "stack"
    BagCleanerDB.lastSlots = max(1, min(128, floor(tonumber(BagCleanerDB.lastSlots) or 3)))
    -- Existing SavedVariables migrate without losing hidden / protected items.
    local allowedShortcuts = {
        ["CTRL-SHIFT"] = true, ["ALT-SHIFT"] = true, ["CTRL-ALT"] = true,
        ["CTRL"] = true, ["SHIFT"] = true, ["ALT"] = true, ["OFF"] = true,
    }
    if not allowedShortcuts[BagCleanerDB.blacklistShortcut] then
        BagCleanerDB.blacklistShortcut = DEFAULTS.blacklistShortcut
    end
    if type(BagCleanerDB.blacklist) ~= "table" then BagCleanerDB.blacklist = {} end
    if type(BagCleanerDB.hidden) ~= "table" then BagCleanerDB.hidden = {} end
    self.db = BagCleanerDB
end

function BC:Money(copper)
    copper = max(0, floor(tonumber(copper) or 0))
    local g, s, c = floor(copper / 10000), floor((copper % 10000) / 100), copper % 100
    if g > 0 then return format("%dg %02ds %02dc", g, s, c) end
    if s > 0 then return format("%ds %02dc", s, c) end
    return format("%dc", c)
end

function BC:GetMaxBagIndex()
    -- Forever is a modern client: optionally include the reagent bag (5).
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
        return 5
    end
    return 4
end

function BC:Loaded(name)
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        return C_AddOns.IsAddOnLoaded(name)
    end
    return type(IsAddOnLoaded) == "function" and IsAddOnLoaded(name) or false
end

function BC:GetContainerCount(bag)
    if C_Container and type(C_Container.GetContainerNumSlots) == "function" then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    if type(GetContainerNumSlots) == "function" then return GetContainerNumSlots(bag) or 0 end
    return 0
end

function BC:ContainerInfo(bag, slot)
    if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if not info then return nil end
        return info.iconFileID or info.icon, info.stackCount or 1, info.isLocked,
            info.quality, info.hyperlink
    end
    if type(GetContainerItemInfo) == "function" then
        local icon, count, locked, quality, _, _, link = GetContainerItemInfo(bag, slot)
        if not icon then return nil end
        return icon, count or 1, locked, quality, link
    end
    return nil
end

function BC:GetLink(bag, slot)
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        return C_Container.GetContainerItemLink(bag, slot)
    end
    if type(GetContainerItemLink) == "function" then return GetContainerItemLink(bag, slot) end
end

function BC:GetItemID(bag, slot, link)
    local id
    if type(GetContainerItemID) == "function" then id = GetContainerItemID(bag, slot) end
    if not id and C_Container and type(C_Container.GetContainerItemID) == "function" then
        id = C_Container.GetContainerItemID(bag, slot)
    end
    if not id and link then id = tonumber(string.match(link, "item:(%d+)")) end
    return id
end

function BC:IsQuestItem(bag, slot)
    if C_Container and type(C_Container.GetContainerItemQuestInfo) == "function" then
        local result = C_Container.GetContainerItemQuestInfo(bag, slot)
        if type(result) == "table" then
            return result.isQuestItem or (result.questID and result.questID ~= 0) or result.isActiveQuest or result.isActive
        end
    end
    if type(GetContainerItemQuestInfo) == "function" then
        local quest, questID, active = GetContainerItemQuestInfo(bag, slot)
        return quest or (questID and questID ~= 0) or active
    end
    -- No quest API: white items must NOT be deleted without a reliable quest check.
    return nil
end

function BC:HasQuestAPI()
    return type(GetContainerItemQuestInfo) == "function" or
        (C_Container and type(C_Container.GetContainerItemQuestInfo) == "function")
end

-- Hearthstones are not cleanup candidates even on custom servers which assign
-- them a positive sell price. IDs cover the standard, garrison and Dalaran stones.
local HEARTHSTONE_IDS = { [6948] = true, [110560] = true, [140192] = true }

-- Conjured items use a localized, dedicated tooltip line on Forever.
-- Reading TooltipInfo is preferred over parsing an English item name.
function BC:IsConjuredItem(bag, slot, id)
    if not C_TooltipInfo then return false end
    local getBag = C_TooltipInfo.GetBagItem
    local getID = C_TooltipInfo.GetItemByID
    local data
    if type(getBag) == "function" then
        local ok, result = pcall(getBag, bag, slot)
        if ok then data = result end
    end
    if (not data or type(data.lines) ~= "table") and type(getID) == "function" then
        local ok, result = pcall(getID, id)
        if ok then data = result end
    end
    if not data or type(data.lines) ~= "table" then return false end
    local localized = _G.ITEM_CONJURED
    local function normalized(value)
        if type(value) ~= "string" then return "" end
        return value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            :gsub("^%s+", ""):gsub("%s+$", ""):lower()
    end
    local word = normalized(localized)
    for _, line in ipairs(data.lines) do
        local shown = normalized(line.leftText)
        if shown ~= "" and (shown == word and word ~= "" or
            shown == "conjured item" or shown == "herbeigezauberter gegenstand") then
            return true
        end
    end
    return false
end

function BC:IsHidden(id)
    return self.db and self.db.hidden[tostring(id)] ~= nil
end

function BC:SetHiddenItem(item, hidden)
    if not item or not item.id then return false end
    local key = tostring(item.id)
    if hidden then self.db.hidden[key] = item.name or ("Item " .. key)
    else self.db.hidden[key] = nil end
    self:ItemRulesChanged()
    return true
end

function BC:UnhideItem(id)
    local key = tostring(id)
    if not self.db.hidden[key] then return false end
    self.db.hidden[key] = nil
    self:ItemRulesChanged()
    return true
end

function BC:SetProtectedItem(item, protected)
    if not item or not item.id then return false end
    local key = tostring(item.id)
    if protected then self.db.blacklist[key] = item.name or ("Item " .. key)
    else self.db.blacklist[key] = nil end
    self:ItemRulesChanged()
    return true
end

function BC:HideAndProtectItem(item)
    if not item or not item.id then return false end
    local key = tostring(item.id)
    local name = item.name or ("Item " .. key)
    self.db.hidden[key], self.db.blacklist[key] = name, name
    self:ItemRulesChanged()
    return true
end

function BC:ItemRulesChanged()
    -- Rebuild visible entries immediately so hidden items disappear without reload.
    self:RequestRefresh()
    if self.panel and self.panel:IsShown() then self:Refresh() end
    if self.RefreshBlacklist then self:RefreshBlacklist() end
end

function BC:ReadSlot(bag, slot)
    local icon, count, locked, quality, link = self:ContainerInfo(bag, slot)
    if not icon or locked then return nil end
    link = link or self:GetLink(bag, slot)
    if not link then return nil end
    local id = self:GetItemID(bag, slot, link)
    if not id or HEARTHSTONE_IDS[id] or self:IsHidden(id) then return nil end

    local itemInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(itemInfo) ~= "function" then return nil end
    local name, _, itemQuality, _, _, itemType, _, _, _, itemTexture, vendorValue, classID = itemInfo(link)
    -- A value of 0 means WoW will not buy the item. Exclude it entirely.
    if not name or type(vendorValue) ~= "number" or vendorValue <= 0 then return nil end
    quality = quality or itemQuality
    if quality ~= 0 and quality ~= 1 then return nil end
    -- Quest-item class and objective markers: never allow deleting these, even when all guards are off.
    local localizedType = type(itemType) == "string" and string.lower(itemType) or ""
    local questClass = classID == 12 or (_G.ITEM_CLASS_12 and itemType == _G.ITEM_CLASS_12)
        or localizedType:find("quest", 1, true) ~= nil
    local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if type(instant) == "function" then
        local _, _, _, _, _, instantClass = instant(link)
        if instantClass == 12 then questClass = true end
    end
    if questClass then return nil end
    if self:IsConjuredItem(bag, slot, id) then return nil end
    local questCheck = self:IsQuestItem(bag, slot)
    if questCheck then return nil end
    count = max(1, tonumber(count) or 1)
    -- Protect/Blacklist is independent of rarity. A hidden item is not scanned.
    local blacklisted = self.db.blacklist[tostring(id)] ~= nil
    local protected = blacklisted or (quality == 1 and (self.db.protectWhite or not self:HasQuestAPI()))
    return {
        bag = bag, slot = slot, id = id, link = link, name = name,
        quality = quality, count = count, icon = icon or itemTexture,
        unit = vendorValue, total = count * vendorValue,
        protected = protected, blacklisted = blacklisted,
    }
end

function BC:Scan(by)
    local entries = {}
    for bag = 0, (self:GetMaxBagIndex()) do
        for slot = 1, self:GetContainerCount(bag) do
            local item = self:ReadSlot(bag, slot)
            if item then insert(entries, item) end
        end
    end
    -- Identical priority for the displayed list, /clean n and /clean all:
    -- the CHEAPEST whole stack is always first, never the cheapest single unit.
    sort(entries, function(a, b)
        if a.total ~= b.total then return a.total < b.total end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return entries
end

function BC:GetFreeSlots()
    local free = 0
    if C_Container and type(C_Container.GetContainerNumFreeSlots) == "function" then
        for bag = 0, (self:GetMaxBagIndex()) do
            free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)
        end
        return free
    end
    if type(GetContainerNumFreeSlots) == "function" then
        for bag = 0, (self:GetMaxBagIndex()) do
            free = free + (GetContainerNumFreeSlots(bag) or 0)
        end
        return free
    end
    for bag = 0, (self:GetMaxBagIndex()) do
        for slot = 1, self:GetContainerCount(bag) do
            local icon = self:ContainerInfo(bag, slot)
            if not icon then free = free + 1 end
        end
    end
    return free
end

function BC:Refresh()
    if not self.db then return end
    self.items = self:Scan("stack")
    -- Whenever bags update or the sidebar reopens, begin at the cheapest item.
    if self.panel then self.panel.offset = 0 end
    if self.RefreshUI then self:RefreshUI() end
end

function BC:RequestRefresh()
    self.needsRefresh = true
    self.refreshAt = GetTime() + 0.08
end

function BC:RawSlotStillMatches(expected)
    local icon, count, locked, quality, link = self:ContainerInfo(expected.bag, expected.slot)
    if not icon then return false end
    link = link or self:GetLink(expected.bag, expected.slot)
    local id = self:GetItemID(expected.bag, expected.slot, link)
    return id == expected.id and count == expected.count and link == expected.link
end

function BC:SameSlot(expected, actual)
    return actual and actual.id == expected.id and actual.count == expected.count and
        actual.link == expected.link and actual.unit == expected.unit and
        actual.quality == expected.quality and not actual.protected
end

local function CursorInfo()
    if type(GetCursorInfo) == "function" then return GetCursorInfo() end
    return nil
end
local function CursorEmpty()
    return type(GetCursorInfo) == "function" and GetCursorInfo() == nil
end

function BC:DeleteSelected(items, allowClosed)
    if self.job then self.Print("Es läuft bereits ein Löschvorgang."); return end
    if self.pending then self.Print("Es wartet bereits eine Löschbestätigung."); return end
    if not CursorEmpty() then self.Print("Zuerst den Mauszeiger leeren (Gegenstand ablegen)."); return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self.Print("Bitte außerhalb des Kampfes aufräumen."); return
    end
    if not items or #items == 0 then self.Print("Keine löschbaren Gegenstände gefunden."); return end
    local total, preview = 0, {}
    for i, item in ipairs(items) do
        local live = self:ReadSlot(item.bag, item.slot)
        if not self:SameSlot(item, live) then
            self.Print("Tascheninhalt hat sich geändert. Bitte erneut versuchen.")
            self:RequestRefresh()
            return
        end
        total = total + item.total
        if i <= 5 then insert(preview, "- " .. item.link .. " x" .. item.count .. " (" .. self:Money(item.total) .. ")") end
    end
    if #items > 5 then insert(preview, "... und " .. (#items - 5) .. " weitere Stapel") end
    self.pending = { items = items, total = total, allowClosed = allowClosed and true or false }
    if self.db.confirmDelete == false then
        -- Opt-out skips BagCleaner's confirmation. Deletion still requires a click.
        self:AcceptPending()
        self.Print("Auswahl vorbereitet. Im Taschenfenster auf 'Jetzt löschen' klicken.")
        return
    end
    if type(StaticPopup_Show) ~= "function" or not StaticPopupDialogs then
        self.pending = nil
        self.Print("Sicherheitsabfrage nicht verfügbar; es wird nichts gelöscht.")
        return
    end
    local title = "Wirklich " .. #items .. " Taschenplatz/-plätze freimachen?\n"
        .. "Verlorener Händlerwert: " .. self:Money(total) .. "\n"
        .. table.concat(preview, "\n") .. "\nDiese Löschung kann nicht rückgängig gemacht werden!"
    local popup = StaticPopup_Show("BAGCLEANER_CONFIRM", title)
    if not popup then self.pending = nil; self.Print("Sicherheitsabfrage konnte nicht geöffnet werden.") end
end

function BC:Cleanup(n, allEligible, allowClosed)
    if not allEligible then
        n = max(1, min(128, floor(tonumber(n) or self.db.lastSlots)))
        self.db.lastSlots = n
    end
    local all = self:Scan("stack") -- Auto-clean always uses TOTAL STACK vendor price.
    local selected = {}
    for _, item in ipairs(all) do
        if not item.protected then
            insert(selected, item)
            if not allEligible and #selected == n then break end
        end
    end
    if not allEligible and #selected < n then
        self.Print("Nur " .. #selected .. " von " .. n .. " angeforderten Stapeln sind löschbar.")
    end
    self:DeleteSelected(selected, allowClosed)
end

function BC:AddBlacklist(value)
    local id = value and (tonumber(tostring(value):match("item:(%d+)")) or tonumber(tostring(value):match("^%s*(%d+)%s*$")))
    if not id or id < 1 then self.Print("Bitte eine Item-ID oder einen Item-Link angeben."); return false end
    id = math.floor(id)
    local name
    local getItem = C_Item and C_Item.GetItemInfo or GetItemInfo
    if type(getItem) == "function" then
        local ok, result = pcall(getItem, id)
        if ok then name = result end
    end
    self.db.blacklist[tostring(id)] = name or ("Item " .. tostring(id))
    self.Print("Blacklist: " .. self.db.blacklist[tostring(id)] .. " (" .. id .. ") geschützt.")
    self:ItemRulesChanged()
    return true
end

function BC:RemoveBlacklist(value)
    local id = value and (tonumber(tostring(value):match("item:(%d+)")) or tonumber(tostring(value):match("^%s*(%d+)%s*$")))
    if not id or not self.db.blacklist[tostring(math.floor(id))] then
        self.Print("Diese Item-ID ist nicht auf der Blacklist.")
        return false
    end
    self.db.blacklist[tostring(math.floor(id))] = nil
    self.Print("Item " .. tostring(math.floor(id)) .. " von der Blacklist entfernt.")
    self:ItemRulesChanged()
    return true
end

function BC:ToggleBlacklistItem(item)
    if not item then return end
    if self.db.blacklist[tostring(item.id)] then self:RemoveBlacklist(item.id)
    else self:AddBlacklist(item.id) end
end

function BC:DeleteOne(item)
    self:DeleteSelected({item})
end

function BC:AcceptPending()
    local request = self.pending
    self.pending = nil
    if not request then return end
    if self.job then self.Print("Es läuft bereits ein Löschvorgang."); return end
    if not CursorEmpty() then self.Print("Mauszeiger ist belegt; Abbruch."); return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self.Print("Im Kampf wird nichts gelöscht."); return
    end
    for _, item in ipairs(request.items) do
        if not self:SameSlot(item, self:ReadSlot(item.bag, item.slot)) then
            self.Print("Inventar geändert; Sicherheitsabbruch ohne Löschung.")
            self:RequestRefresh()
            return
        end
    end
    self.job = { items = request.items, index = 1, done = 0, lost = 0, waiting = nil,
        allowClosed = request.allowClosed, nextAt = GetTime() }
    if self.RefreshUI then self:RefreshUI() end
    -- /clean from chat only creates a selection; expose the next-click action.
    if self.panel and not self.panel:IsShown() and self.OpenAndTogglePanel then
        self:OpenAndTogglePanel()
    end
end

function BC:StopJob(message)
    local old = self.job
    if not old then return end
    self.job = nil
    if old.done > 0 then
        self.Print(old.done .. " Platz/Plätze freigemacht; Händlerwert " .. self:Money(old.lost) .. ".")
    end
    if message then self.Print(message) end
    self:RequestRefresh()
    if self.RefreshUI then self:RefreshUI() end
end

function BC:JobTick()
    local job = self.job
    if not job then return end
    local now = GetTime()
    if now < job.nextAt then return end
    if not job.allowClosed and self.GetActiveBagFrame and not self:GetActiveBagFrame() then
        self:StopJob("Taschen geschlossen; Aufräumen angehalten.")
        return
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self:StopJob("Kampf begonnen; Löschvorgang angehalten.")
        return
    end
    if not CursorEmpty() then
        self:StopJob("Mauszeiger belegt / Blizzard-Bestätigung erforderlich; Abbruch.")
        return
    end

    if job.waiting then
        local old = job.waiting
        -- Read raw slot identity: a temporarily locked item must not count as deleted.
        if self:RawSlotStillMatches(old) then
            if now - job.waitStart > 3 then self:StopJob("Löschung nicht bestätigt; Abbruch.") end
            return
        end
        job.done = job.done + 1
        job.lost = job.lost + old.total
        job.waiting = nil
        job.index = job.index + 1
        job.nextAt = now + 0.3
        if self.RefreshUI then self:RefreshUI() end
        if job.index > #job.items then self:StopJob("Aufräumen abgeschlossen.") end
        return
    end

    -- DeleteCursorItem is hardware-event restricted on Forever.
    -- Never call it from OnUpdate, even if confirmations are disabled.
    if not job.items[job.index] then self:StopJob("Aufräumen abgeschlossen.") end

end

-- Must be invoked synchronously from a real in-game click.
-- A bulk selection needs one further click per additional stack on modern clients.
function BC:HardwareDeleteNext()
    local job = self.job
    if not job then return end
    if job.waiting then self.Print("Warte auf Bestätigung der letzten Löschung."); return end
    if GetTime() < (job.nextAt or 0) then return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        self:StopJob("Im Kampf nicht verfügbar."); return
    end
    if not CursorEmpty() then self:StopJob("Mauszeiger ist belegt; Abbruch."); return end
    local item = job.items[job.index]
    if not item then self:StopJob("Aufräumen abgeschlossen."); return end
    if not self:SameSlot(item, self:ReadSlot(item.bag, item.slot)) then
        self:StopJob("Tascheninhalt verändert; Abbruch."); return
    end
    local pickup = C_Container and C_Container.PickupContainerItem or PickupContainerItem
    if type(pickup) ~= "function" or type(DeleteCursorItem) ~= "function" then
        self:StopJob("Löschfunktion auf diesem Client nicht verfügbar."); return
    end
    local ok, err = pcall(pickup, item.bag, item.slot)
    if not ok then self:StopJob("Aufnehmen fehlgeschlagen: " .. tostring(err)); return end
    local cursorType, cursorID = CursorInfo()
    if cursorType ~= "item" or (cursorID and tonumber(cursorID) ~= item.id) then
        if cursorType == "item" then pcall(pickup, item.bag, item.slot) end
        self:StopJob("Gegenstand am Mauszeiger nicht eindeutig; Abbruch."); return
    end
    local deleted, message = pcall(DeleteCursorItem)
    if not deleted then
        -- Do not clear the cursor blindly. Attempt to return the item to its original slot.
        if CursorInfo() == "item" then pcall(pickup, item.bag, item.slot) end
        self:StopJob("WoW hat die Löschung blockiert: " .. tostring(message)); return
    end
    job.waiting = item
    job.waitStart = GetTime()
    job.nextAt = GetTime() + 0.3
    self:RequestRefresh()
    if self.RefreshUI then self:RefreshUI() end
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.BAGCLEANER_CONFIRM = {
    text = "%s", button1 = YES, button2 = NO,
    OnAccept = function() BC:AcceptPending(); BC:HardwareDeleteNext() end,
    OnCancel = function() BC.pending = nil end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

SLASH_BAGCLEANER1 = "/clean"
SLASH_BAGCLEANER2 = "/bagcleaner"
SlashCmdList.BAGCLEANER = function(message)
    if not BC.db then BC:InitDB() end
    local raw = (message or ""):match("^%s*(.-)%s*$")
    local action = string.lower(raw)
    if action == "" then
        BC:Cleanup(BC.db.lastSlots, false, true)
    elseif action == "all" then
        BC:Cleanup(nil, true, true)
    elseif action:match("^%d+$") then
        BC:Cleanup(tonumber(action), false, true)
    elseif action == "auto" then
        BC.db.autoOpen = not BC.db.autoOpen
        BC.Print("Automatisch öffnen: " .. (BC.db.autoOpen and "AN" or "AUS"))
        if BC.SyncOptions then BC:SyncOptions() end
    elseif action == "protect" then
        BC.db.protectWhite = not BC.db.protectWhite
        BC.Print("Weiße Gegenstände schützen: " .. (BC.db.protectWhite and "AN" or "AUS"))
        BC:RequestRefresh()
        if BC.SyncOptions then BC:SyncOptions() end
    elseif action == "confirm" then
        BC.db.confirmDelete = not BC.db.confirmDelete
        BC.Print("Löschbestätigung: " .. (BC.db.confirmDelete and "AN" or "AUS"))
        if BC.SyncOptions then BC:SyncOptions() end
    elseif action == "status" or action == "debug" then
        local elv = BC.GetElvBagFrame and BC:GetElvBagFrame()
        local active, mode = BC.GetActiveBagFrame and BC:GetActiveBagFrame()
        local titan = _G.TitanPlugins and _G.TitanPlugins.BagCleaner
        BC.Print("Version 1.4.1 | UI=" .. tostring(BC.panel ~= nil)
            .. " | ElvUI=" .. tostring(BC:Loaded("ElvUI"))
            .. " | ElvUI-Tasche=" .. tostring(elv and elv:GetName() or "nicht gefunden")
            .. " | Tasche offen=" .. tostring(active ~= nil)
            .. " | Modus=" .. tostring(mode or "kein")
            .. " | Titan=" .. tostring(BC:Loaded("Titan") or BC:Loaded("TitanPanel"))
            .. " | Titan-registriert=" .. tostring(BC.titanRegistered or titan ~= nil)
            .. " | Titan-Modus=" .. tostring(BC.titanMode or "keiner"))
    elseif action == "settings" or action == "optionen" then
        if BC.ToggleOptions then BC:ToggleOptions() end
    elseif action == "show" or action == "panel" then
        if BC.OpenAndTogglePanel then BC:OpenAndTogglePanel()
        elseif BC.TogglePanel then BC:TogglePanel() end
    elseif action == "blacklist" or action == "hidden" or action == "rules" then
        if BC.ToggleBlacklist then BC:ToggleBlacklist() end
    elseif action:match("^blacklist%s+add%s+") then
        BC:AddBlacklist(raw:match("^%S+%s+%S+%s+(.+)$"))
    elseif action:match("^blacklist%s+remove%s+") then
        BC:RemoveBlacklist(raw:match("^%S+%s+%S+%s+(.+)$"))
    else
        BC.Print("/clean [Anzahl|all] | /clean show | /clean settings | /clean status | /clean rules | /clean blacklist [add/remove ID]")
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("ITEM_LOCK_CHANGED")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        BC:InitDB()
    elseif event == "PLAYER_LOGIN" then
        if not BC.db then BC:InitDB() end
        if BC.CreateUI then
            local ok, err = pcall(BC.CreateUI, BC)
            if not ok then BC.Print("UI-Fehler: " .. tostring(err) .. " | bitte Screenshot sichern") end
        end
        if BC.RegisterTitan then BC:RegisterTitan() end
        BC.Print("v1.4.1 geladen. Clean-Liste: Klick loeschen | Shortcut blacklisten | /clean status")
        BC:RequestRefresh()
    elseif BC.db then
        BC:RequestRefresh()
    end
end)
eventFrame:SetScript("OnUpdate", function(self, elapsed)
    BC.elapsed = BC.elapsed + elapsed
    if BC.elapsed < 0.08 then return end
    BC.elapsed = 0
    if not BC.db then return end
    if BC.job then BC:JobTick() end
    if BC.needsRefresh and GetTime() >= BC.refreshAt then
        BC.needsRefresh = false
        if BC.panel and BC.panel:IsShown() then BC:Refresh() end
    end
    if BC.PollIntegration then BC:PollIntegration() end
    if BC.PollTitan then BC:PollTitan() end
end)
