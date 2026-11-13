"""Run with Python and lupa to exercise spellbook cooldown discovery."""

from pathlib import Path

from lupa import LuaRuntime


root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
unpack = table.unpack
now = 0
cooldowns = {}
spellbook = {}
shown = {}
function GetTime() return now end
function wipe(t) for key in pairs(t) do t[key] = nil end end
function tinsert(t, v) table.insert(t, v) end
function tremove(t, i) table.remove(t, i) end
function strsplit(_, value) return value end
function strtrim(value) return value end
STANDARD_TEXT_FONT = "font"
UIParent = {GetWidth = function() return 100 end,
    GetHeight = function() return 100 end,
    GetEffectiveScale = function() return 1 end}
local frameMethods = {}
setmetatable(frameMethods, {__index = function(_, key)
    return function(self, ...)
        if key == "SetScript" then
            local scripts = rawget(self, "scripts") or {}
            rawset(self, "scripts", scripts)
            scripts[(...)] = select(2, ...)
        end
        if key == "SetTexture" then
            rawset(self, "texture", (...))
            if self == pulseTexture and rawget(self, "texture") then shown[#shown + 1] = self.texture end
        end
        if key == "GetTexture" then return rawget(self, "texture") end
        if key == "IsMouseEnabled" then return false end
        return nil
    end
end})
function CreateFrame()
    local frame = setmetatable({}, {__index = frameMethods})
    function frame:CreateFontString() return setmetatable({}, {__index = frameMethods}) end
    function frame:CreateTexture()
        pulseTexture = setmetatable({}, {__index = frameMethods})
        return pulseTexture
    end
    return frame
end
LH_LayoutProfiles = {Register = function() end}
C_Container = {GetContainerNumSlots = function() return 0 end}
C_Item = {}
function GetInventoryItemID() return nil end
NUM_BAG_SLOTS = 0
function GetPetActionInfo() return nil end
C_EventUtils = {IsEventValid = function() return true end}
Enum = {SpellBookSpellBank = {Player = 1}, SpellBookItemType = {Spell = 1, Flyout = 2}}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return {itemIndexOffset = 0, numSpellBookItems = #spellbook} end,
    GetSpellBookItemInfo = function(slot) return spellbook[slot] end,
}
C_Spell = {
    GetSpellName = function(id)
        if id == 16857 or id == 17392 then return "Faerie Fire (Feral)" end
        return "spell " .. id
    end,
    GetSpellTexture = function(id) return "icon " .. id end,
    GetSpellCooldown = function(id)
        local duration = cooldowns[id] or 0
        return {startTime = 0, duration = duration, isEnabled = true,
            isActive = duration > 0 and now < duration, isOnGCD = duration > 0 and duration <= 2}
    end,
}
function GetSpellBaseCooldown(id) return (cooldowns[id] or 0) * 1000 end
function GetFlyoutInfo() return nil, nil, 1, true end
function GetFlyoutSlotInfo() return 17392, nil, true end
''')
lua.execute((root / "LH_CooldownPulse.lua").read_text(encoding="utf-8"), "LH_CooldownPulse")
lua.execute(r'''
LH_CooldownPulse:ADDON_LOADED("LH_CooldownPulse")
spellbook = {
    {spellID = 770, itemType = 1}, -- ordinary Faerie Fire: GCD only
    {spellID = 16857, itemType = 1}, -- cast ID
    {spellID = 17392, itemType = 1}, -- learned rank with cooldown
    {spellID = 5211, itemType = 1}, -- Bash: unrelated cooldown
    {spellID = 12345, itemType = 1}, -- Read Leyline: unrelated cooldown
    {spellID = 111, itemType = 1, isOffSpec = true},
    {spellID = 222, itemType = 1, isPassive = true},
}
cooldowns[770], cooldowns[17392] = 1.5, 6
cooldowns[5211], cooldowns[12345] = 3, 10
LH_CooldownPulse:PLAYER_ENTERING_WORLD()
LH_CooldownPulse:UNIT_SPELLCAST_SUCCEEDED("player", "cast", 16857)
now = 2.1
LH_CooldownPulse.scripts.OnUpdate(nil, 0.1)
now = 6.1
LH_CooldownPulse.scripts.OnUpdate(nil, 0.1)
assert(#shown == 1 and shown[1] == "icon 17392", "learned rank must pulse once")
LH_CooldownPulse.scripts.OnUpdate(nil, 2)
now = 10.1
if LH_CooldownPulse.scripts.OnUpdate then LH_CooldownPulse.scripts.OnUpdate(nil, 0.1) end
assert(#shown == 1, "unrelated Bash and Read Leyline must not pulse")

-- New spellbook entries are picked up without a hardcoded druid spell list.
spellbook = {{spellID = 333, itemType = 1}}
cooldowns[333] = 10
now = 0
shown = {}
LH_CooldownPulse:PLAYER_SPECIALIZATION_CHANGED("player")
LH_CooldownPulse:UNIT_SPELLCAST_SUCCEEDED("player", "cast", 333)
now = 2.1
LH_CooldownPulse.scripts.OnUpdate(nil, 0.1)
now = 10.1
LH_CooldownPulse.scripts.OnUpdate(nil, 0.1)
assert(#shown == 1 and shown[1] == "icon 333", "new known ability must pulse")

-- Forever's legacy spellbook API is supported as well.
C_SpellBook = nil
function GetNumSpellTabs() return 1 end
function GetSpellTabInfo() return nil, nil, 0, 1 end
function GetSpellBookItemInfo() return "SPELL", 444 end
cooldowns[444] = 8
now = 0
shown = {}
LH_CooldownPulse:PLAYER_ENTERING_WORLD()
LH_CooldownPulse:UNIT_SPELLCAST_SUCCEEDED("player", "cast", 444)
now = 2.1
LH_CooldownPulse.scripts.OnUpdate(nil, 0.1)
now = 8.1
LH_CooldownPulse.scripts.OnUpdate(nil, 0.1)
assert(#shown == 1 and shown[1] == "icon 444", "legacy learned ability must pulse")
''')
print("Druid spellbook cooldown scenarios passed")
