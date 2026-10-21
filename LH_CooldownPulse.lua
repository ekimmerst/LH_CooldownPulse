local addonName = ...
local fadeInTime, fadeOutTime, maxAlpha, animScale, iconSize, holdTime, showSpellName, trackPetAbilities, ignoredSpells, invertIgnored, remainingCooldownWhenNotified
local cooldowns, animating, watching, notified = { }, { }, { }, { }
local itemSpells = {}
local GetTime = GetTime
local runtimer = 0

local defaultSettings = {
    fadeInTime = 0.3,
    fadeOutTime = 0.7,
    maxAlpha = 0.7,
    animScale = 1.5,
    iconSize = 75,
    holdTime = 0,
    petOverlay = {1,1,1},
    showSpellName = false,
    trackPetAbilities = true,
    x = UIParent:GetWidth()*UIParent:GetEffectiveScale()/2,
    y = UIParent:GetHeight()*UIParent:GetEffectiveScale()/2,
    remainingCooldownWhenNotified = 0
}

local defaultSettingsPerCharacter = {
    ignoredSpells = "",
    invertIgnored = false
}

local DCP = CreateFrame("frame")
DCP:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
DCP:SetMovable(true)
DCP:EnableMouse(false)
DCP:RegisterForDrag("LeftButton")
DCP:SetScript("OnDragStart", function(self) self:StartMoving() end)
DCP:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    LH_CooldownPulse_Saved.x = self:GetLeft()+self:GetWidth()/2
    LH_CooldownPulse_Saved.y = self:GetBottom()+self:GetHeight()/2
    self:ClearAllPoints()
    self:SetPoint("CENTER",UIParent,"BOTTOMLEFT",LH_CooldownPulse_Saved.x,LH_CooldownPulse_Saved.y)
end)
DCP.TextFrame = DCP:CreateFontString(nil, "ARTWORK")
DCP.TextFrame:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
DCP.TextFrame:SetShadowOffset(2,-2)
DCP.TextFrame:SetPoint("CENTER",DCP,"CENTER")
DCP.TextFrame:SetWidth(185)
DCP.TextFrame:SetJustifyH("CENTER")
DCP.TextFrame:SetTextColor(1,1,1)

local DCPT = DCP:CreateTexture(nil,"BACKGROUND")
DCPT:SetAllPoints(DCP)

-----------------------
-- Utility Functions --
-----------------------
local function tcount(tab)
    local n = 0
    for _ in pairs(tab) do
        n = n + 1
    end
    return n
end

-- Never branch on, format, or calculate with restricted combat values.
local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function PlainNumber(value)
    return not IsSecret(value) and type(value) == "number"
end

local function ReadCooldown(entry)
    local start, duration, enabled, rate, onGCD
    if entry.kind == "spell" then
        local info = C_Spell.GetSpellCooldown(entry.id)
        if IsSecret(info) or type(info) ~= "table" or
            (issecrettable and issecrettable(info)) then return end
        start, duration, enabled, rate, onGCD = info.startTime, info.duration, info.isEnabled, info.modRate, info.isOnGCD
        local charges = C_Spell.GetSpellCharges and C_Spell.GetSpellCharges(entry.id)
        if not IsSecret(charges) and type(charges) == "table" and
            not (issecrettable and issecrettable(charges)) then
            if not PlainNumber(charges.currentCharges) or not PlainNumber(charges.maxCharges) then return end
            if charges.currentCharges < charges.maxCharges then
                start, duration, rate = charges.cooldownStartTime, charges.cooldownDuration, charges.chargeModRate
                onGCD = false
            end
        end
    elseif entry.kind == "pet" then
        start, duration, enabled = GetPetActionCooldown(entry.id)
    else
        start, duration, enabled = C_Container.GetItemCooldown(entry.id)
    end
    if not PlainNumber(start) or not PlainNumber(duration) or IsSecret(enabled) or
        IsSecret(rate) or IsSecret(onGCD) then return end
    if enabled == false or enabled == 0 then return end
    if not PlainNumber(rate) or rate <= 0 then rate = 1 end
    -- Ignore the global cooldown and shared short item lockouts.
    if onGCD or duration <= 2 then return false end
    return start + duration / rate
end

local function RefreshLocals()
    fadeInTime = LH_CooldownPulse_Saved.fadeInTime
    fadeOutTime = LH_CooldownPulse_Saved.fadeOutTime
    maxAlpha = LH_CooldownPulse_Saved.maxAlpha
    animScale = LH_CooldownPulse_Saved.animScale
    iconSize = LH_CooldownPulse_Saved.iconSize
    holdTime = LH_CooldownPulse_Saved.holdTime
    showSpellName = LH_CooldownPulse_Saved.showSpellName
    trackPetAbilities = LH_CooldownPulse_Saved.trackPetAbilities
    invertIgnored = LH_CooldownPulse_SavedPerCharacter.invertIgnored
    remainingCooldownWhenNotified = LH_CooldownPulse_Saved.remainingCooldownWhenNotified

    ignoredSpells = { }
    for _,v in ipairs({strsplit(",",LH_CooldownPulse_SavedPerCharacter.ignoredSpells)}) do
        ignoredSpells[strtrim(v)] = true
    end
end

local function MergeTable(destination, source)
    for i, v in pairs(source) do
        if (destination[i] == nil) then
            destination[i] = type(v) == "table" and {unpack(v)} or v
        end
    end
end

local function InitializeSavedVariables()
    if (LH_CooldownPulse_Saved == nil) then
        LH_CooldownPulse_Saved = {}
    end

    if (LH_CooldownPulse_SavedPerCharacter == nil) then
        LH_CooldownPulse_SavedPerCharacter = {}
    end

    MergeTable(LH_CooldownPulse_Saved, defaultSettings)
    MergeTable(LH_CooldownPulse_SavedPerCharacter, defaultSettingsPerCharacter)
end

-- Shared setting definitions retain the original dialog's ranges and defaults.
DCP.options = {
    { key = "iconSize", label = "Icon size", min = 30, max = 125, step = 5, tooltip = "Base icon size in UI units." },
    { key = "fadeInTime", label = "Fade-in time", min = 0, max = 1.5, step = 0.1, tooltip = "Seconds spent fading in." },
    { key = "fadeOutTime", label = "Fade-out time", min = 0, max = 1.5, step = 0.1, tooltip = "Seconds spent fading out." },
    { key = "maxAlpha", label = "Maximum opacity", min = 0, max = 1, step = 0.1, tooltip = "Peak opacity, from invisible to fully opaque." },
    { key = "holdTime", label = "Hold time", min = 0, max = 1.5, step = 0.1, tooltip = "Seconds to hold the maximum opacity." },
    { key = "animScale", label = "Animation scaling", min = 0, max = 2, step = 0.1, tooltip = "Final icon size relative to its base size." },
    { key = "remainingCooldownWhenNotified", label = "Advance notification", min = 0, max = 3, step = 0.1, tooltip = "Notify this many seconds before the cooldown ends. Zero notifies when ready." },
}

function DCP:GetOption(key)
    local perCharacter = defaultSettingsPerCharacter[key] ~= nil
    local saved = perCharacter and LH_CooldownPulse_SavedPerCharacter or LH_CooldownPulse_Saved
    if saved and saved[key] ~= nil then return saved[key] end
    if perCharacter then return defaultSettingsPerCharacter[key] end
    return defaultSettings[key]
end

function DCP:GetDefault(key)
    if defaultSettingsPerCharacter[key] ~= nil then return defaultSettingsPerCharacter[key] end
    return defaultSettings[key]
end

local function ClearPetTracking()
    for key, entry in pairs(watching) do
        if entry.kind == "pet" then
            watching[key] = nil
            notified[key] = nil
        end
    end
    local activePet = animating[1] and animating[1][2]
    for i = #animating, 1, -1 do
        if animating[i][2] then tremove(animating, i) end
    end
    if activePet then
        runtimer = 0
        DCP.TextFrame:SetText(nil)
        DCPT:SetTexture(nil)
        DCPT:SetVertexColor(1, 1, 1)
        DCP:SetAlpha(0)
    end
end

function DCP:SetOption(key, value)
    InitializeSavedVariables()
    if key == "showSpellName" or key == "invertIgnored" or key == "trackPetAbilities" then value = value == true
    elseif key == "ignoredSpells" then
        if type(value) ~= "string" then return end
    elseif key == "petOverlay" then
        if type(value) ~= "table" then return end
        local color = {}
        for i = 1, 3 do
            if not PlainNumber(value[i]) then return end
            color[i] = math.max(0, math.min(1, value[i]))
        end
        value = color
    else
        local option
        for _, candidate in ipairs(self.options) do if candidate.key == key then option = candidate; break end end
        if not option or not PlainNumber(value) then return end
        value = math.max(option.min, math.min(option.max, value))
    end
    local saved = defaultSettingsPerCharacter[key] ~= nil and LH_CooldownPulse_SavedPerCharacter or LH_CooldownPulse_Saved
    saved[key] = value
    RefreshLocals()
    if key == "trackPetAbilities" and not value then ClearPetTracking() end
    if self:IsMouseEnabled() then
        self:SetSize(iconSize, iconSize)
        DCPT:SetVertexColor(1, 1, 1)
    end
    if self.RefreshSettings then self:RefreshSettings() end
end

LH_CooldownPulse = DCP

local function IsAnimatingCooldownByName(name)
    for i, details in pairs(animating) do
        if details[3] == name then
            return true
        end
    end

    return false
end

--------------------------
-- Cooldown / Animation --
--------------------------
local elapsed = 0
local function OnUpdate(_,update)
    elapsed = elapsed + update
    if (elapsed > 0.05) then
        local now = GetTime()
        for key, entry in pairs(watching) do
            if now >= entry.checkAt then
                local expires = ReadCooldown(entry)
                if expires == nil then
                    -- A restricted or temporarily unavailable cooldown is retried.
                    -- Do not infer readiness from the last readable timestamp.
                    entry.restricted = true
                elseif expires == false or expires <= now then
                    if entry.active and not notified[key] and not entry.restricted and
                        not IsAnimatingCooldownByName(entry.name) then
                        tinsert(animating, {entry.texture, entry.kind == "pet", entry.name})
                    end
                    watching[key] = nil
                    notified[key] = nil
                else
                    entry.active = true
                    entry.restricted = false
                    if not notified[key] and expires - now <= remainingCooldownWhenNotified and
                        not IsAnimatingCooldownByName(entry.name) then
                        tinsert(animating, {entry.texture, entry.kind == "pet", entry.name})
                        notified[key] = true
                    end
                end
            end
        end

        elapsed = 0
        if (#animating == 0 and tcount(watching) == 0 and tcount(cooldowns) == 0) then
            DCP:SetScript("OnUpdate", nil)
            return
        end
    end

    if (#animating > 0) then
        runtimer = runtimer + update
        if (runtimer > (fadeInTime + holdTime + fadeOutTime)) then
            tremove(animating,1)
            runtimer = 0
            DCP.TextFrame:SetText(nil)
            DCPT:SetTexture(nil)
            DCPT:SetVertexColor(1,1,1)
        else
            if (not DCPT:GetTexture()) then
                if (animating[1][3] ~= nil and showSpellName) then
                    DCP.TextFrame:SetText(animating[1][3])
                end
                DCPT:SetTexture(animating[1][1])
                if animating[1][2] then
                    DCPT:SetVertexColor(unpack(LH_CooldownPulse_Saved.petOverlay))
                end
            end
            local alpha = maxAlpha
            if (runtimer < fadeInTime) then
                alpha = maxAlpha * (runtimer / fadeInTime)
            elseif (runtimer >= fadeInTime + holdTime) then
                alpha = maxAlpha - ( maxAlpha * ((runtimer - holdTime - fadeInTime) / fadeOutTime))
            end
            DCP:SetAlpha(alpha)
            local scale = iconSize+(iconSize*((animScale-1)*(runtimer/(fadeInTime+holdTime+fadeOutTime))))
            DCP:SetWidth(scale)
            DCP:SetHeight(scale)
        end
    end
end

--------------------
-- Event Handlers --
--------------------
function DCP:ADDON_LOADED(addon)
    if addon ~= addonName then return end
    InitializeSavedVariables()
    RefreshLocals()
    self:SetPoint("CENTER",UIParent,"BOTTOMLEFT",LH_CooldownPulse_Saved.x,LH_CooldownPulse_Saved.y)
    self:UnregisterEvent("ADDON_LOADED")
end
DCP:RegisterEvent("ADDON_LOADED")

local function Watch(kind, id, name, texture, filterID)
    if kind == "pet" and not trackPetAbilities then return end
    if IsSecret(id) or IsSecret(name) or IsSecret(texture) then return end
    if not id or not name or not texture or not ignoredSpells then return end
    local listed = ignoredSpells[name] or ignoredSpells[tostring(filterID or id)] or false
    if listed ~= invertIgnored then return end
    local key = kind .. ":" .. id
    if not watching[key] then
        watching[key] = {kind = kind, id = id, name = name, texture = texture,
            checkAt = GetTime() + 0.5}
    end
    if not DCP:IsMouseEnabled() then DCP:SetScript("OnUpdate", OnUpdate) end
end

local function ScanItems()
    local function AddItem(id)
        if id then
            Watch("item", id, C_Item.GetItemNameByID(id), C_Item.GetItemIconByID(id))
            if C_Item.GetItemSpell then
                local _, spellID = C_Item.GetItemSpell(id)
                if not IsSecret(spellID) and spellID then itemSpells[spellID] = id end
            end
        end
    end
    for slot = 1, 19 do AddItem(GetInventoryItemID("player", slot)) end
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            AddItem(C_Container.GetContainerItemID(bag, slot))
        end
    end
end

local function ScanPet()
    if not trackPetAbilities then return end
    for slot = 1, (NUM_PET_ACTION_SLOTS or 10) do
        local name, texture, isToken, _, _, _, spellID = GetPetActionInfo(slot)
        if not IsSecret(spellID) and spellID then
            name = C_Spell.GetSpellName(spellID)
            texture = C_Spell.GetSpellTexture(spellID)
        elseif not IsSecret(isToken) and isToken and not IsSecret(name) and name then
            name = _G[name] or name
            if not IsSecret(texture) and texture then texture = _G[texture] or texture end
        end
        Watch("pet", slot, name, texture, spellID)
    end
end

function DCP:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)
    if IsSecret(unit) or IsSecret(spellID) then return end
    if unit == "player" and spellID then
        ScanItems()
        if not itemSpells[spellID] then
            Watch("spell", spellID, C_Spell.GetSpellName(spellID), C_Spell.GetSpellTexture(spellID))
        end
    elseif unit == "pet" then
        ScanPet()
    end
end

function DCP:SPELL_UPDATE_COOLDOWN()
    -- Entries are read afresh on every update, including cooldown resets/reductions.
end
DCP.BAG_UPDATE_COOLDOWN = ScanItems
DCP.BAG_UPDATE_DELAYED = ScanItems
DCP.PLAYER_EQUIPMENT_CHANGED = ScanItems
DCP.GET_ITEM_INFO_RECEIVED = ScanItems
DCP.PET_BAR_UPDATE_COOLDOWN = ScanPet
DCP.PET_BAR_UPDATE = ScanPet

function DCP:PLAYER_ENTERING_WORLD()
    wipe(watching)
    wipe(notified)
    wipe(cooldowns)
    wipe(animating)
    runtimer = 0
    DCPT:SetTexture(nil)
    DCPT:SetVertexColor(1, 1, 1)
    self.TextFrame:SetText(nil)
    self:SetAlpha(0)
    ScanItems()
    ScanPet()
    if self:IsMouseEnabled() then self:SetUnlocked(true) end
end

function DCP:PLAYER_SPECIALIZATION_CHANGED(unit)
    if not IsSecret(unit) and unit == "player" then wipe(watching) end
end

for _, event in ipairs({"UNIT_SPELLCAST_SUCCEEDED", "SPELL_UPDATE_COOLDOWN",
    "BAG_UPDATE_COOLDOWN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED",
    "GET_ITEM_INFO_RECEIVED", "PET_BAR_UPDATE_COOLDOWN", "PET_BAR_UPDATE",
    "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED"}) do
    if not C_EventUtils or not C_EventUtils.IsEventValid or C_EventUtils.IsEventValid(event) then
        DCP:RegisterEvent(event)
    end
end

function DCP:SetUnlocked(unlocked)
    InitializeSavedVariables()
    RefreshLocals()
    self:StopMovingOrSizing()
    wipe(animating)
    runtimer = 0
    self.TextFrame:SetText(nil)
    DCPT:SetVertexColor(1, 1, 1)
    self:EnableMouse(unlocked == true)
    if unlocked then
        self:SetSize(iconSize, iconSize)
        self:SetAlpha(1)
        DCPT:SetTexture("Interface\\Icons\\Spell_Nature_Earthbind")
        self:SetScript("OnUpdate", nil)
    else
        self:SetAlpha(0)
        DCPT:SetTexture(nil)
        self:SetScript("OnUpdate", OnUpdate)
    end
    if self.RefreshSettings then self:RefreshSettings() end
end

function DCP:Test()
    self:SetUnlocked(false)
    tinsert(animating, {"Interface\\Icons\\Spell_Nature_Earthbind", nil, "Spell Name"})
    self:SetScript("OnUpdate", OnUpdate)
end

function DCP:ResetPosition()
    self:StopMovingOrSizing()
    LH_CooldownPulse_Saved.x, LH_CooldownPulse_Saved.y = defaultSettings.x, defaultSettings.y
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", LH_CooldownPulse_Saved.x, LH_CooldownPulse_Saved.y)
end

function DCP:RestoreDefaults()
    InitializeSavedVariables()
    for key, value in pairs(defaultSettings) do
        LH_CooldownPulse_Saved[key] = type(value) == "table" and {unpack(value)} or value
    end
    for key, value in pairs(defaultSettingsPerCharacter) do LH_CooldownPulse_SavedPerCharacter[key] = value end
    self:ResetPosition()
    self:SetUnlocked(false)
end
