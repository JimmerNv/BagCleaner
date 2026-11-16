-- Regression test: Forever requires modern C_ APIs, older globals are intentionally absent.
local BC, t, cursor = {}, 0, nil
local bag = {
 [1]={id=1001,name='grey1',count=1,quality=0,price=50},
 [2]={id=1002,name='grey2',count=4,quality=0,price=20},
 [3]={id=1003,name='white_quest',count=1,quality=1,price=0,quest=true},
 [4]={id=1004,name='white_safe',count=1,quality=1,price=10},
}
local all={};for _,v in pairs(bag)do all[v.id]=v end
function CreateFrame() return {RegisterEvent=function()end,SetScript=function()end}end
function GetTime()return t end
function InCombatLockdown()return false end
C_Container={}
function C_Container.GetContainerNumSlots(i) return i==0 and 6 or 0 end
function C_Container.GetContainerNumFreeSlots(i)
 if i~=0 then return 0 end
 local n=0; for j=1,6 do if not bag[j] then n=n+1 end end;return n
end
function C_Container.GetContainerItemInfo(i,j)
 local v=i==0 and bag[j];if not v then return nil end
 return {iconFileID=132200,stackCount=v.count,isLocked=false,quality=v.quality,hyperlink='|Hitem:'..v.id..':0|h['..v.name..']|h'}
end
function C_Container.GetContainerItemLink(i,j) local v=i==0 and bag[j];return v and '|Hitem:'..v.id..':0|h['..v.name..']|h' end
function C_Container.GetContainerItemID(i,j) local v=i==0 and bag[j];return v and v.id end
function C_Container.GetContainerItemQuestInfo(i,j)
 local v=i==0 and bag[j];return {isQuestItem=v and v.quest or false}
end
function C_Container.PickupContainerItem(i,j)
 assert(i==0)
 if cursor then bag[j]=cursor;cursor=nil else cursor=bag[j];bag[j]=nil end
end
C_Item={}
function C_Item.GetItemInfo(link)
 local id=tonumber(tostring(link):match('item:(%d+)'));local v=all[id]
 if not v then return nil end
 return v.name,link,v.quality,1,1,'Misc','','',nil,132200,v.price,v.quest and 12 or 15
end
function C_Item.GetItemInfoInstant(link)
 local id=tonumber(tostring(link):match('item:(%d+)'));local v=all[id];
 return id, 'Misc','','',132200,v and v.quest and 12 or 15
end
C_AddOns={IsAddOnLoaded=function(name)return name=='ElvUI' end}
function GetCursorInfo() if cursor then return 'item',cursor.id end end
function DeleteCursorItem() cursor=nil end
StaticPopupDialogs={};function StaticPopup_Show(name) return {} end
SlashCmdList={};YES='yes';NO='no';DEFAULT_CHAT_FRAME={AddMessage=function()end}
assert(loadfile('Core.lua'))('BagCleaner',BC)
BC:InitDB()
assert(BC:Loaded('ElvUI'),'modern add-on lookup')
assert(BC:GetMaxBagIndex()==5,'modern bag index')
local entries=BC:Scan('stack')
assert(#entries==3,'quest class exclusion')
assert(entries[1].id==1004 and entries[1].protected,'white protected')
BC.db.confirmDelete=false
BC:Cleanup(2,true)
assert(BC.job and #BC.job.items==2,'only two grey stacks eligible')
BC:HardwareDeleteNext()
assert(bag[1]==nil and bag[2]~=nil,'one real click deletes one stack')
for i=1,4 do t=t+0.2;BC:JobTick() end
assert(BC.job and BC.job.done==1,'queue does not auto-delete next')
BC:HardwareDeleteNext()
for i=1,4 do t=t+0.2;BC:JobTick() end
assert(not BC.job and bag[2]==nil and bag[4], 'second click deletes second stack')
print('PASS: Forever C_Container/C_Item/C_AddOns APIs, quest exclusion, staged hardware-event deletion')
