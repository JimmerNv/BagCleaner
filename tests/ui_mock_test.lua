-- Headless widget-API smoke test (not a substitute for live WoW testing).
local BC, t, cursor, bags = {}, 0, nil, {}
local function widget(name)
  local o = { _name=name, _visible=false, _level=1, _text='', _checked=false, hooks={} }
  local mt = {}
  mt.__index = function(self,key)
    -- WoW Forever plain frames lack these legacy skinning methods.
    if key == 'SetTemplate' or key == 'SetBackdrop'
      or key == 'BagCleanerBackground' or key == 'BagCleanerBorder' then return nil end
    if key == 'CreateFontString' or key == 'CreateTexture' then return function() return widget() end end
    if key == 'IsShown' then return function() return self._visible end end
    if key == 'Show' then return function()
      self._visible=true
      if self.hooks.OnShow then self.hooks.OnShow(self) end
    end end
    if key == 'Hide' then return function()
      self._visible=false
      if self.script_OnHide then self.script_OnHide(self) end
      if self.hooks.OnHide then self.hooks.OnHide(self) end
    end end
    if key == 'HookScript' then return function(_,k,fn) self.hooks[k]=fn end end
    if key == 'SetScript' then return function(_,k,fn) self['script_'..k]=fn end end
    if key == 'SetText' then return function(_,v) self._text=v end end
    if key == 'GetText' then return function() return self._text end end
    if key == 'SetChecked' then return function(_,v) self._checked=v end end
    if key == 'GetChecked' then return function() return self._checked end end
    if key == 'GetFrameLevel' then return function() return self._level end end
    if key == 'SetFrameLevel' then return function(_,x) self._level=x end end
    if key == 'SetFrameStrata' then return function(_,x) self._strata=x end end
    if key == 'SetPoint' then return function(_,...) self._point={...} end end
    if key == 'GetLeft' then return function() return 850 end end
    if key == 'GetEffectiveScale' then return function() return 1 end end
    if key == 'GetName' then return function() return self._name end end
    return function() end
  end
  return setmetatable(o,mt)
end
UIParent=widget('UIParent')
Minimap=widget('Minimap')
function CreateFrame(_,name,parent,template)
  local f=widget(name)
  if name then _G[name]=f end
  if template=='UICheckButtonTemplate' and name then
    _G[name..'Text']=widget(name..'Text')
  end
  return f
end
function GetTime() return t end
function GetContainerNumSlots() return 0 end
function GetContainerNumFreeSlots() return 0 end
function GetCursorInfo() end
function GetContainerItemQuestInfo() end
StaticPopupDialogs=setmetatable({}, {__newindex=function() error('Blizzard popup registry tainted') end})
function StaticPopup_Show() error('Blizzard popup invoked') end
SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function() end}
YES='Yes';NO='No'
STANDARD_TEXT_FONT='Fonts\\FRIZQT__.TTF'
NUM_CONTAINER_FRAMES=13
function FauxScrollFrame_GetOffset() return 0 end
function FauxScrollFrame_Update() end
GameTooltip=widget('GameTooltip')
assert(loadfile('Core.lua'))('BagCleaner',BC)
assert(loadfile('UI.lua'))('BagCleaner',BC)
BC:InitDB()
BC:CreateUI()
assert(BC.panel and BC.options and BC.standaloneButton,'UI instantiated')
assert(BC.deleteConfirmation and BC.deleteConfirmation.acceptButton and BC.deleteConfirmation.cancelButton,
  'custom confirmation created without touching Blizzard popup registry')
BC.pending={items={},total=0}
assert(BC:ShowDeleteConfirmation('Confirm test') and BC.deleteConfirmation:IsShown(),
  'dedicated confirmation opens')
BC.deleteConfirmation.cancelButton.script_OnClick()
assert(not BC.pending and not BC.deleteConfirmation:IsShown(),
  'cancel discards selected items and hides the dialog')
local oldAccept,oldHardware=BC.AcceptPending,BC.HardwareDeleteNext
local confirmed,hardware=0,0
BC.AcceptPending=function(self) confirmed=confirmed+1;self.pending=nil;self.job={} end
BC.HardwareDeleteNext=function(self) hardware=hardware+1;self.job=nil end
BC.pending={items={},total=0}
BC:ShowDeleteConfirmation('Confirm test')
BC.deleteConfirmation.acceptButton.script_OnClick()
assert(confirmed==1 and hardware==1 and not BC.pending and not BC.deleteConfirmation:IsShown(),
  'accept invokes selected cleanup once through real button click')
BC.AcceptPending,BC.HardwareDeleteNext=oldAccept,oldHardware
assert(next(StaticPopupDialogs)==nil,'Blizzard popup table remains untouched')
assert(BC.panel.BagCleanerBackground and #BC.panel.BagCleanerBorder==4,
  'opaque panel and four independent borders without ElvUI or SetBackdrop')
-- Options must be centered and layered above all BagCleaner launchers.
assert(BC.options._strata == "FULLSCREEN_DIALOG", 'options must use fullscreen dialog strata')
BC:ShowOptions()
assert(BC.options._point and BC.options._point[1] == "CENTER"
  and BC.options._point[2] == UIParent and BC.options._point[3] == "CENTER",
  'options must be centered on UIParent instead of attached to bag window')
BC.options:Hide()
assert(BC.options.BagCleanerBackground and BC.itemMenu.BagCleanerBackground,
  'options and right-click menu also have their own background in standalone mode')
assert(BC.panel.sortButton.text._text=='Gesamtwert aufsteigend',
  'total stack value is displayed as mandatory sort mode')
assert(BC.itemMenu and #BC.itemMenu.actionButtons==3,'right-click dropdown with 3 actions exists')
local rowAnchor=widget('MockItemRow')
BC:OpenItemMenu({id=88771,name='Hide example',quality=0}, rowAnchor)
assert(BC.itemMenu:IsShown(),'right-click dropdown opens')
BC.itemMenu.actionButtons[1].script_OnClick()
assert(BC.db.hidden['88771'] and not BC.db.blacklist['88771'],'Hide only')
BC:OpenItemMenu({id=88772,name='Protect example',quality=0}, rowAnchor)
BC.itemMenu.actionButtons[2].script_OnClick()
assert(not BC.db.hidden['88772'] and BC.db.blacklist['88772'],'Protect only')
BC:OpenItemMenu({id=88773,name='Both example',quality=1}, rowAnchor)
BC.itemMenu.actionButtons[3].script_OnClick()
assert(BC.db.hidden['88773'] and BC.db.blacklist['88773'],'Hide+Protect combined')
BC:RefreshBlacklist()
assert(BC:BlacklistCount()==3,'rule management lists hidden and protected items')
BC.blacklistPanel.rows[1].script_OnClick(BC.blacklistPanel.rows[1],'LeftButton')
assert(not BC.db.hidden['88771'],'left click restores hidden item')
BC.blacklistPanel.rows[1].script_OnClick(BC.blacklistPanel.rows[1],'RightButton')
assert(not BC.db.blacklist['88772'],'right click removes protection')

assert(BC.minimapButton, 'minimap fallback created even without Titan or ElvUI')
assert(not BC.panel:IsShown(),'initially closed')
_G.ElvUI_ContainerFrame=widget('ElvUI_ContainerFrame')
ElvUI_ContainerFrame.ContainerHolder=widget('ElvBagMenu')
ElvUI_ContainerFrame:Show()
t=t+0.4
BC:PollIntegration()
assert(BC.elvButton and BC.elvMenuButton,'ElvUI buttons wired')
assert(BC.elvButton.text._text=='Clean' and BC.elvMenuButton.text._text=='Clean','visible Clean launchers, not BC')
assert(BC.elvButton:IsShown(),'header launcher immediately visible')
assert(BC.mode=='elvui','ElvUI preferred')
assert(not BC.standaloneButton:IsShown(),'standalone hidden under ElvUI')
ElvUI_ContainerFrame.ContainerHolder:Show()
assert(BC.options:IsShown(),'settings visible with small ElvUI bag menu')
assert(BC.options.auto:GetChecked()==false and BC.options.protect:GetChecked()==false,'default options: whites not protected')
assert(BC.options.confirm:GetChecked()==true,'confirmation default enabled')
BC.options.confirm:SetChecked(false); BC.options.confirm.script_OnClick(BC.options.confirm)
assert(BC.db.confirmDelete==false,'confirmation checkbox is persisted')
BC.elvButton.script_OnClick(BC.elvButton,'RightButton')
assert(not BC.options:IsShown(),'header button right-click toggles options')
BC.elvButton.script_OnClick(BC.elvButton,'RightButton')
assert(BC.options:IsShown(),'header button right-click reopens options')
BC:ToggleBlacklist()
assert(BC.blacklistPanel:IsShown(),'blacklist manager opens from settings')
BC:AddBlacklist('14142')
assert(BC.db.blacklist['14142'],'blacklist manager shows added ID')
local blacklistRow
for _, row in ipairs(BC.blacklistPanel.rows) do if row.entry and row.entry.id==14142 then blacklistRow=row;break end end
assert(blacklistRow,'added ID appears in manager')
blacklistRow.script_OnClick(blacklistRow)
assert(not BC.db.blacklist['14142'],'blacklist row click removes item')
BC.blacklistPanel:Hide()
BC.options.auto:SetChecked(true);BC.options.auto.script_OnClick(BC.options.auto)
assert(BC.db.autoOpen,'auto option changes DB')
BC.options.protect:SetChecked(true);BC.options.protect.script_OnClick(BC.options.protect)
assert(BC.db.protectWhite,'white protection may be enabled explicitly')
BC.options.protect:SetChecked(false);BC.options.protect.script_OnClick(BC.options.protect)
assert(not BC.db.protectWhite,'white protection can be disabled again')
BC:TogglePanel();assert(BC.panel:IsShown(),'ElvUI sidebar opens')
BC.panel:Hide()
ElvUI_ContainerFrame:Hide()
_G.ContainerFrame1=widget('ContainerFrame1')
ContainerFrame1:Show()
t=t+1;BC:PollIntegration()
assert(BC.mode=='standalone','fallback activates')
assert(BC.standaloneButton:IsShown(),'standalone toggle appears')
assert(BC.panel:IsShown(),'auto-show works')
BC.panel:Hide()
BC.db.autoOpen=false
ContainerFrame1:Hide()
t=t+1;BC:PollIntegration()
assert(not BC.panel:IsShown(),'panel stays closed when bags close')
-- v1.4.5: explicit delete is never a blacklist operation, even with modifiers.
assert(BC.panel.rows[1].deleteButton and BC.panel.rows[1].value,
  'real per-item delete button plus vendor value')
assert(rawget(BC.options, "shortcutButton") == nil and rawget(BC, "shortcutMenu") == nil,
  'obsolete quick-blacklist UI was removed')
local ctrl,shift,alt = false,false,false
function IsControlKeyDown() return ctrl end
function IsShiftKeyDown() return shift end
function IsAltKeyDown() return alt end
local sample={id=97213,name='junk',count=1,total=23,unit=23,quality=0,
  icon='icon',link='|Hitem:97213:0|h[Junk]|h',protected=false,blacklisted=false}
local originalDelete=BC.DeleteOne
local deletedCount=0
BC.DeleteOne=function() deletedCount=deletedCount+1 end
BC.db.blacklist['97213']=nil
BC.items={sample}
BC.panel:Show()
BC:RefreshUI()
local one=BC.panel.rows[1]
assert(one.deleteButton.text._text=='Löschen','delete control labelled clearly')
assert(one.amount._text=='x1' and one.value._text=='23c','count and vendor value have separate labels')
one.deleteButton.script_OnClick(one.deleteButton, 'LeftButton')
assert(deletedCount==1 and not BC.db.blacklist['97213'],'delete button deletes without protecting')
shift,ctrl = true,true
one.deleteButton.script_OnClick(one.deleteButton, 'LeftButton')
assert(deletedCount==2 and not BC.db.blacklist['97213'],
  'Ctrl+Shift+Delete still deletes and never creates protection')
one.script_OnClick(one,'LeftButton')
assert(deletedCount==2 and not BC.db.blacklist['97213'],
  'clicking the row does not delete or protect')
one.deleteButton.script_OnClick(one.deleteButton, 'RightButton')
assert(BC.itemMenu:IsShown(),'right-click on delete button opens rule menu')
BC.itemMenu.actionButtons[2].script_OnClick()
assert(BC.db.blacklist['97213'],'protect only through explicit menu selection')
sample.protected=true;sample.blacklisted=true;BC.items={sample};BC:RefreshUI()
assert(one.deleteButton.text._text=='Löschen','protected items retain delete button text')
shift,ctrl=false,false
one.deleteButton.script_OnClick(one.deleteButton,'LeftButton')
assert(deletedCount==2,'protected item cannot be deleted via button')
-- White items are only protected when the user explicitly enables the option.
BC.db.blacklist['97213']=nil
BC.db.protectWhite=true
sample.protected=true;sample.blacklisted=false;sample.quality=1
BC.items={sample};BC:RefreshUI()
one.deleteButton.script_OnClick(one.deleteButton,'LeftButton')
assert(deletedCount==2 and not BC.db.blacklist['97213'],
  'opt-in protected white item remains safe and Delete never adds blacklist rules')
BC.DeleteOne=originalDelete
BC.panel:Hide()
print('PASS: delete button never protects, right-click opens rule menu, protected item safe')
print('PASS: UI creation, ElvUI preference, menu options, standalone fallback, auto-show and close')
