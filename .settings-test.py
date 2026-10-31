from pathlib import Path
import sys
import xml.etree.ElementTree as ET

addon = Path(__file__).resolve().parent
sys.path.insert(0, str(addon / '.test-runtime'))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime()
lua.execute('''
frames={};SlashCmdList={};clock=100;STANDARD_TEXT_FONT='font'
tinsert=table.insert;tremove=table.remove
function wipe(t) for k in pairs(t) do t[k]=nil end end
function strtrim(v) return v:match('^%s*(.-)%s*$') end
function strsplit(_,v)
 local t={};for part in (v..','):gmatch('(.-),') do t[#t+1]=part end
 return unpack(t)
end
function GetTime() return clock end
local M={}
function M:SetScript(k,v) self.scripts[k]=v end
function M:GetScript(k) return self.scripts[k] end
function M:SetPoint(...) self.point={...} end
function M:ClearAllPoints() self.point=nil end
function M:SetSize(w,h) self.width=w;self.height=h end
function M:SetWidth(w) self.width=w end
function M:SetHeight(h) self.height=h end
function M:GetWidth() return rawget(self,'width') or 1920 end
function M:GetHeight() return rawget(self,'height') or 1080 end
function M:GetLeft() return 100 end
function M:GetBottom() return 200 end
function M:GetEffectiveScale() return 1 end
function M:SetText(v) self.text=v end
function M:GetText() return rawget(self,'text') or '' end
function M:SetTexture(v) self.texture=v end
function M:GetTexture() return rawget(self,'texture') end
function M:SetVertexColor(...) self.color={...} end
function M:SetAlpha(v) self.alpha=v end
function M:EnableMouse(v) self.mouse=v end
function M:IsMouseEnabled() return self.mouse==true end
function M:ClearFocus()
 if self.focus then self.focus=false;if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
end
function M:CreateTexture() local t=CreateFrame('Texture');self.textureRegion=t;return t end
function M:CreateFontString() return CreateFrame('Font') end
setmetatable(M,{__index=function(_,key) if key:match('^%u') then return function() end end end})
function CreateFrame(kind,name,parent,template)
 assert(not name or not name:find('OptionsFrame'),'Old options window was created')
 local f=setmetatable({scripts={},parent=parent,template=template},{__index=M});frames[#frames+1]=f
 return f
end
function Mixin(t,...) for i=1,select('#',...) do for k,v in pairs(select(i,...)) do t[k]=v end end;return t end
function CreateFromMixins(...) return Mixin({},...) end
UIParent=CreateFrame('Frame')
GetInventoryItemID=function() end
C_Container={GetContainerNumSlots=function() return 0 end}
GetPetActionInfo=function() end
C_Spell={GetSpellName=function(id) return 'Spell'..id end,GetSpellTexture=function(id) return 'Texture'..id end}
local expiry=110
function C_Spell.GetSpellCooldown(id) return {startTime=100,duration=expiry-100,isEnabled=true} end
registry={};notices={};callbacks={};buttons={}
Settings={}
function Settings.RegisterVerticalLayoutSubcategory(parent,title)
 local c={parent=parent,title=title};function c:GetID() return self.title end
 local l={rows={}};function l:AddInitializer(row) table.insert(self.rows,row) end
 c.layout=l;return c,l
end
function Settings.RegisterAddOnCategory(c) registered=c end
function Settings.RegisterProxySetting(c,v,kind,label,default,get,set)
 local s={category=c,variable=v,kind=kind,label=label,default=default,get=get,set=set}
 function s:GetValue() return self.get() end
 function s:SetValue(value) self.set(value) end
 function s:GetVariable() return self.variable end
 function s:GetName() return self.label end
 registry[v]=s;return s
end
function Settings.NotifyUpdate(v)
 notices[v]=(notices[v] or 0)+1
 if activeRow and activeRow.data and activeRow.data.setting.variable==v then activeRow:SetValue(registry[v].get()) end
end
function Settings.CreateCheckbox(c,s,tooltip) c.layout:AddInitializer({setting=s,tooltip=tooltip}) end
function Settings.CreateSliderOptions(min,max,step)
 return {min=min,max=max,step=step,SetLabelFormatter=function() end}
end
function Settings.CreateSlider(c,s,options,tooltip) c.layout:AddInitializer({setting=s,options=options,tooltip=tooltip}) end
function Settings.CreateColorSwatch(c,s,tooltip) c.layout:AddInitializer({setting=s,tooltip=tooltip}) end
function Settings.CreateSettingInitializerData(s,options,tooltip) return {setting=s,tooltip=tooltip} end
function Settings.CreateSettingInitializer(template,data) return {template=template,data=data} end
function Settings.OpenToCategory(id) opened=id end
function CreateSettingsListSectionHeaderInitializer(text) return {header=text} end
function CreateSettingsButtonInitializer(label,text,fn,tooltip) buttons[text]=fn;return {label=label} end
MinimalSliderWithSteppersMixin={Label={Right=1}}
EventRegistry={}
function EventRegistry:RegisterCallback(event,fn,owner)
 callbacks[event]=callbacks[event] or {};table.insert(callbacks[event],{fn,owner})
end
function fire(event,...) for _,v in ipairs(callbacks[event]) do v[1](v[2],...) end end
function CreateColor(r,g,b,a)
 return {GenerateHexColor=function() return string.format('%02x%02x%02x%02x',a*255,math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5)) end}
end
function CreateColorFromHexString(hex)
 return {GetRGB=function() return tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255,tonumber(hex:sub(7,8),16)/255 end}
end
DefaultTooltipMixin={OnLoad=function() end,OnEnter=function() end,OnLeave=function() end}
SettingsControlMixin={OnLoad=function() end,
 Init=function(self,initializer) self.data=initializer.data end,
 Release=function(self) self.data=nil end,
 GetSetting=function(self) return self.data.setting end,
 SetSmartNavCursorAnchor=function() end}
LH_Tweaks={modules={}}
''')
core = addon.parent / 'LH_Tweaks'
source = (core / 'LH_Tweaks.lua').read_text()
registration = source.split('function Hub:RegisterModule(id, title, build)')[1].split('\nfunction Hub:RestoreDefaults')[0]
lua.execute('local Hub=LH_Tweaks\nfunction Hub:RegisterModule(id, title, build)' + registration)
source = (core / 'Settings.lua').read_text()
registration = source.split('function Hub:RegisterModulePage(id)')[1].split('\nlocal function RegisterSettings')[0]
lua.execute('local Hub=LH_Tweaks\nfunction Hub:RegisterModulePage(id)' + registration)
lua.execute((addon / 'LH_CooldownPulse.lua').read_text(), 'LH_CooldownPulse')
lua.execute((addon / 'Settings.lua').read_text(), 'LH_CooldownPulse')
lua.execute('''
local a=LH_CooldownPulse
assert(LH_Tweaks.modules.LH_CooldownPulse and not registered)
-- Saved settings survive initialization and native registration.
LH_CooldownPulse_Saved={iconSize=95,petOverlay={.2,.4,.6},showSpellName=true}
LH_CooldownPulse_SavedPerCharacter={ignoredSpells='Spell9, 10',invertIgnored=false}
a:ADDON_LOADED('LH_CooldownPulse')
LH_Tweaks.category={title='LH Tweaks'}
LH_Tweaks:RegisterModulePage('LH_CooldownPulse')
local c=a.category
assert(c.parent==LH_Tweaks.category and c.title=='LH CooldownPulse')
assert(c.layout.rows[1].header=='Positioning')
assert(a:GetOption('iconSize')==95 and a:GetOption('showSpellName') and a:GetOption('trackPetAbilities'))
assert(registry.LH_CooldownPulse_petOverlay.get()=='ff336699')
local count=0;for _ in pairs(registry) do count=count+1 end;assert(count==13)
assert(registry.LH_CooldownPulse_trackPetAbilities.get()==true)
SlashCmdList.LH_COOLDOWNPULSE();assert(opened==c:GetID())
assert(registry.LH_CooldownPulse_locked.default and registry.LH_CooldownPulse_locked.get())
registry.LH_CooldownPulse_locked.set(false);assert(a:IsMouseEnabled() and a.width==95 and a.alpha==1)
a:PLAYER_ENTERING_WORLD();assert(a:IsMouseEnabled() and a.alpha==1 and a.textureRegion.texture)
registry.LH_CooldownPulse_iconSize.set(120);assert(a.width==120)
a.scripts.OnDragStop(a);local x,y=LH_CooldownPulse_Saved.x,LH_CooldownPulse_Saved.y
assert(x==160 and y==260)
buttons['Reset position']();assert(LH_CooldownPulse_Saved.x==960 and a:IsMouseEnabled())
registry.LH_CooldownPulse_petOverlay.set('ffff0000');assert(LH_CooldownPulse_Saved.petOverlay[1]==1 and LH_CooldownPulse_Saved.petOverlay[2]==0)
for _,o in ipairs(a.options) do
 registry['LH_CooldownPulse_'..o.key].set(o.max)
 assert(a:GetOption(o.key)==o.max)
end
-- Inline filter editing commits on Enter/focus loss, cancels on Escape and survives pooling.
local init=c.layout.rows[#c.layout.rows]
activeRow=CreateFrame('Frame');Mixin(activeRow,LH_CooldownPulseFilterControlMixin)
activeRow:OnLoad();activeRow:Init(init)
local box=activeRow.EditBox
box.focus=true;box:SetText('Spell7, 8');box.scripts.OnEnterPressed(box)
assert(a:GetOption('ignoredSpells')=='Spell7, 8')
box.focus=true;box:SetText('discard');box.scripts.OnEscapePressed(box)
assert(a:GetOption('ignoredSpells')=='Spell7, 8' and box:GetText()=='Spell7, 8')
box.focus=true;box:SetText('Spell1');activeRow:Release()
assert(a:GetOption('ignoredSpells')=='Spell1' and not activeRow.data)
activeRow:Init(init);assert(box:GetText()=='Spell1')
fire('Settings.CategoryDefaulted',{});assert(a:GetOption('iconSize')==125)
fire('Settings.CategoryDefaulted',c)
assert(a:GetOption('iconSize')==75 and not a:GetOption('showSpellName') and a:GetOption('trackPetAbilities'))
assert(a:GetOption('ignoredSpells')=='' and not a:GetOption('invertIgnored') and not a:IsMouseEnabled())
assert(box:GetText()=='' and registry.LH_CooldownPulse_petOverlay.get()=='ffffffff')
-- Defaults must not alias a mutable color table.
LH_CooldownPulse_Saved.petOverlay[1]=0;a:RestoreDefaults();assert(LH_CooldownPulse_Saved.petOverlay[1]==1)
a:SetOption('fadeInTime',.3);a:SetOption('holdTime',.2);a:SetOption('fadeOutTime',.7)
a:SetOption('showSpellName',true);buttons.Test()
assert(not a:IsMouseEnabled() and notices.LH_CooldownPulse_locked>0)
a.scripts.OnUpdate(a,.1);assert(a.textureRegion.texture and a.TextFrame.text=='Spell Name' and a.alpha>0)
a.scripts.OnUpdate(a,2);assert(not a.textureRegion.texture)
-- Reuse the actual tracker: matching filters, completion and restricted cooldown suppression.
local function tick(t) clock=t;local fn=a.scripts.OnUpdate;if fn then fn(a,.1) end end
local function watch(id) a:UNIT_SPELLCAST_SUCCEEDED('player','cast',id) end
a:PLAYER_ENTERING_WORLD();a:SetOption('ignoredSpells','Spell1');watch(1);tick(101);tick(111)
assert(not a.textureRegion.texture,'Excluded spell pulsed')
a:PLAYER_ENTERING_WORLD();a:SetOption('invertIgnored',true);clock=100;watch(1);tick(101);tick(111)
assert(a.textureRegion.texture=='Texture1','Allowed spell did not pulse')
a:PLAYER_ENTERING_WORLD();a:SetOption('invertIgnored',false);a:SetOption('ignoredSpells','')
local secret={};issecretvalue=function(v) return v==secret end
C_Spell.GetSpellCooldown=function() return {startTime=secret,duration=10,isEnabled=true} end
clock=100;watch(2);tick(101)
C_Spell.GetSpellCooldown=function() return {startTime=0,duration=0,isEnabled=true} end
tick(111);assert(not a.textureRegion.texture,'Restricted cooldown caused a late pulse')
-- Account settings also affect actual pet and item notifications.
GetPetActionInfo=function(slot) if slot==1 then return 'PetName','PetTexture',false end end
GetPetActionCooldown=function() return 100,10,1 end
a:SetOption('petOverlay',{.3,.5,.7});a:SetOption('showSpellName',true)
clock=100;a:PLAYER_ENTERING_WORLD();tick(101)
registry.LH_CooldownPulse_trackPetAbilities.set(false)
assert(not a:GetOption('trackPetAbilities') and LH_CooldownPulse_Saved.trackPetAbilities==false)
tick(111);assert(not a.textureRegion.texture,'Disabled pending pet cooldown pulsed')
clock=100;a:PLAYER_ENTERING_WORLD();tick(101);tick(111)
assert(not a.textureRegion.texture,'Disabled pet tracking resumed on world entry')
registry.LH_CooldownPulse_trackPetAbilities.set(true)
clock=100;a:PLAYER_ENTERING_WORLD();tick(101);tick(111)
assert(a.textureRegion.texture=='PetTexture' and a.textureRegion.color[1]==.3 and a.TextFrame.text=='PetName')
registry.LH_CooldownPulse_trackPetAbilities.set(false)
assert(not a.textureRegion.texture and not a.TextFrame.text,'Active pet pulse was not cleared')
registry.LH_CooldownPulse_trackPetAbilities.set(true)
GetPetActionInfo=function() end
GetInventoryItemID=function(_,slot) if slot==1 then return 500 end end
C_Item={GetItemNameByID=function() return 'ItemName' end,GetItemIconByID=function() return 'ItemTexture' end}
C_Container.GetItemCooldown=function() return 100,10,1 end
clock=100;a:PLAYER_ENTERING_WORLD();tick(101);tick(111)
assert(a.textureRegion.texture=='ItemTexture' and a.textureRegion.color[1]==1 and a.TextFrame.text=='ItemName')
a:SetOption('iconSize',100);a:SetOption('invertIgnored',true);fire('Settings.Defaulted')
assert(a:GetOption('iconSize')==75 and not a:GetOption('invertIgnored'))
''')
ET.parse(addon / 'Settings.xml')
for ext in ('png', 'tga'):
    assert (addon / f'Media/Icon.{ext}').read_bytes() == (core / f'Icon.{ext}').read_bytes()
source = (addon / 'LH_CooldownPulse.lua').read_text()
assert 'CreateOptionsFrame' not in source and 'OptionsFrame' not in source
print('PASS: host registration, fork notice, all 13 settings, pet toggle and cancellation, saved values, inline filter lifecycle, colors, preview/drag/reset, defaults, real cooldown/filter regression, restricted data, XML and identical icons')
