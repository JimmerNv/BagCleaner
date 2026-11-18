-- Headless WoW Forever 1.60.1 rules verification: sell price, hearthstone,
-- tooltip conjured detection, hide / protect / combined and automatic selection.
local BC = {}
local now = 0
local bag = {
  [1]={id=6948,name='Hearthstone',count=1,quality=1,price=99},
  [2]={id=12001,name='Conjured Bread',count=1,quality=1,price=25,conjured=true},
  [3]={id=12002,name='Unsellable Grey',count=1,quality=0,price=0},
  [4]={id=12003,name='Sellable Grey',count=1,quality=0,price=10},
  [5]={id=12004,name='Sellable White',count=2,quality=1,price=60},
  [6]={id=12005,name='Quest Grey',count=1,quality=0,price=50,quest=true},
  [7]={id=12006,name='Cheaper Grey',count=1,quality=0,price=5},
}
local all = {}
for _,v in pairs(bag) do all[v.id]=v end
function CreateFrame()return {RegisterEvent=function()end,SetScript=function()end}end
function GetTime()return now end
function InCombatLockdown()return false end
C_Container = {
  GetContainerNumSlots=function(b)return b==0 and 8 or 0 end,
  GetContainerItemInfo=function(b,slot)
    local v=b==0 and bag[slot]
    if not v then return nil end
    return { iconFileID=100, stackCount=v.count, quality=v.quality, isLocked=false,
       hyperlink='|Hitem:'..v.id..':0|h['..v.name..']|h' }
  end,
  GetContainerItemID=function(b,slot) return b==0 and bag[slot] and bag[slot].id end,
  GetContainerItemQuestInfo=function(b,slot) return {isQuestItem=b==0 and bag[slot] and bag[slot].quest or false} end,
}
C_Item = {
 GetItemInfo=function(link)
   local id=tonumber(tostring(link):match('item:(%d+)'))
   local v=all[id]
   if not v then return nil end
   return v.name,link,v.quality,1,1,'Misc','','',nil,100,v.price,15
 end,
 GetItemInfoInstant=function(link)
   return tonumber(tostring(link):match('item:(%d+)')),nil,nil,nil,nil,15
 end,
}
ITEM_CONJURED='Conjured Item'
C_TooltipInfo = {
 GetBagItem=function(b,slot)
   local v=b==0 and bag[slot]
   if not v then return nil end
   return {lines={{leftText=v.conjured and 'Conjured Item' or v.name}}}
 end,
}
function GetCursorInfo()return nil end
function DeleteCursorItem()end
StaticPopupDialogs=setmetatable({}, {__newindex=function() error("tainted popup registry") end})
SlashCmdList={}; YES='yes';NO='no';DEFAULT_CHAT_FRAME={AddMessage=function()end}
assert(loadfile('Core.lua'))('BagCleaner',BC)
BC:InitDB()
assert(type(BC.db.hidden)=='table','hidden set initialized')
local items=BC:Scan('stack')
assert(#items==3,'exclude hearthstone, conjured, zero vendor, quest item')
assert(items[1].id==12006 and items[2].id==12003 and items[3].id==12004,'sort by total value')
local a=items[2]
assert(BC:SetHiddenItem(a,true),'hide item')
items=BC:Scan('stack')
assert(#items==2 and items[1].id==12006,'hidden item is not shown')
assert(BC:UnhideItem(12003),'unhide')
items=BC:Scan('stack')
assert(#items==3,'unhidden is shown again')
assert(BC:SetProtectedItem(items[1], true),'protect grey')
assert(BC:Scan('stack')[1].protected,'grey can be protected')
assert(BC:HideAndProtectItem({id=12004,name='Sellable White'}),'both flags set')
assert(BC:IsHidden(12004) and BC.db.blacklist['12004'],'hide+protect persistent')
assert(BC:UnhideItem(12004),'hidden flag cleared independently')
local visible=BC:Scan('stack')
assert(#visible==3 and visible[3].protected,'still protected when unhidden')
BC.db.protectWhite=false
assert(BC:ReadSlot(0,5).protected,'blacklist protects white even when global white protection is off')
BC.db.confirmDelete=false
BC:Cleanup(nil, true, true)
assert(BC.job and #BC.job.items==1 and BC.job.items[1].id==12003,
 'clean all picks only eligible, excluding protected, hidden, conjured, no-value and quest')
print('PASS: Forever sell-value exclusions, hearthstone, conjured tooltip, quest, hide, protect, both, unhide and Clean All')
