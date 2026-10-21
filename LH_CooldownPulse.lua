local addonName = ...
local fadeInTime, fadeOutTime, maxAlpha, animScale, iconSize, holdTime, showSpellName, ignoredSpells, invertIgnored, remainingCooldownWhenNotified
local cooldowns, animating, watching, notified = { }, { }, { }, { }
local itemSpells = {}
local GetTime = GetTime

local defaultSettings = {
    fadeInTime = 0.3,
    fadeOutTime = 0.7,
    maxAlpha = 0.7,
    animScale = 1.5,
    iconSize = 75,
    holdTime = 0,
    petOverlay = {1,1,1},
    showSpellName = nil,
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
            destination[i] = v
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
local runtimer = 0
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
    self.TextFrame:SetText(nil)
    self:SetAlpha(0)
    ScanItems()
    ScanPet()
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

-------------------
-- Options Frame --
-------------------

SlashCmdList["LH_COOLDOWNPULSE"] = function() if (not LH_CooldownPulse_OptionsFrame) then DCP:CreateOptionsFrame() end LH_CooldownPulse_OptionsFrame:Show() end
SLASH_LH_COOLDOWNPULSE1 = "/lh_cooldownpulse"

function DCP:CreateOptionsFrame()
    local sliders = {
        { text = "Icon Size", value = "iconSize", min = 30, max = 125, step = 5 },
        { text = "Fade In Time", value = "fadeInTime", min = 0, max = 1.5, step = 0.1 },
        { text = "Fade Out Time", value = "fadeOutTime", min = 0, max = 1.5, step = 0.1 },
        { text = "Max Opacity", value = "maxAlpha", min = 0, max = 1, step = 0.1 },
        { text = "Max Opacity Hold Time", value = "holdTime", min = 0, max = 1.5, step = 0.1 },
        { text = "Animation Scaling", value = "animScale", min = 0, max = 2, step = 0.1 },
        { text = "Show Before Available Time", value = "remainingCooldownWhenNotified", min = 0, max = 3, step = 0.1 },
    }

    local buttons = {
        { text = "Close", func = function(self) self:GetParent():Hide() end },
        { text = "Test", func = function(self)
            LH_CooldownPulse_OptionsFrameButton3:SetText("Unlock")
            DCP:EnableMouse(false)
            RefreshLocals()
            tinsert(animating,{"Interface\\Icons\\Spell_Nature_Earthbind",nil,"Spell Name"})
            DCP:SetScript("OnUpdate", OnUpdate)
            end },
        { text = "Unlock", func = function(self)
            if (self:GetText() == "Unlock") then
                RefreshLocals()
                DCP:SetWidth(iconSize)
                DCP:SetHeight(iconSize)
                self:SetText("Lock")
                DCP:SetScript("OnUpdate", nil)
                DCP:SetAlpha(1)
                DCPT:SetTexture("Interface\\Icons\\Spell_Nature_Earthbind")
                DCP:EnableMouse(true)
            else
                DCP:SetAlpha(0)
                self:SetText("Unlock")
                DCP:EnableMouse(false)
                DCP:SetScript("OnUpdate", OnUpdate)
            end end },
        { text = "Defaults", func = function(self)
            for i,v in pairs(defaultSettings) do
                LH_CooldownPulse_Saved[i] = v
            end
            for i,v in pairs(defaultSettingsPerCharacter) do
                LH_CooldownPulse_SavedPerCharacter[i] = v
            end
            for i,v in pairs(sliders) do
                getglobal("LH_CooldownPulse_OptionsFrameSlider"..i).Slider:SetValue(LH_CooldownPulse_Saved[v.value])
            end
            LH_CooldownPulse_OptionsFramePetColorBox:GetNormalTexture():SetVertexColor(unpack(LH_CooldownPulse_Saved.petOverlay))
            LH_CooldownPulse_OptionsFrameIgnoreTypeButtonWhitelist:SetChecked(false)
            LH_CooldownPulse_OptionsFrameIgnoreTypeButtonBlacklist:SetChecked(true)
            LH_CooldownPulse_OptionsFrameIgnoreBox:SetText("")
            DCP:ClearAllPoints()
            DCP:SetPoint("CENTER",UIParent,"BOTTOMLEFT",LH_CooldownPulse_Saved.x,LH_CooldownPulse_Saved.y)
            end },
    }

    local optionsframe = CreateFrame("frame","LH_CooldownPulse_OptionsFrame",UIParent,BackdropTemplateMixin and "BackdropTemplate")
    optionsframe:SetBackdrop({
      bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
      tile=1, tileSize=32, edgeSize=32,
      insets={left=11, right=12, top=12, bottom=11}
    })
    optionsframe:SetWidth(230)
    optionsframe:SetHeight(610)
    optionsframe:SetPoint("CENTER",UIParent)
    optionsframe:EnableMouse(true)
    optionsframe:SetMovable(true)
    optionsframe:RegisterForDrag("LeftButton")
    optionsframe:SetScript("OnDragStart", function(self) self:StartMoving() end)
    optionsframe:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    optionsframe:SetFrameStrata("FULLSCREEN_DIALOG")
    optionsframe:SetScript("OnHide", function() RefreshLocals() end)
    tinsert(UISpecialFrames, "LH_CooldownPulse_OptionsFrame")

    local header = optionsframe:CreateTexture(nil,"ARTWORK")
    header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header.blp")
    header:SetWidth(350)
    header:SetHeight(68)
    header:SetPoint("TOP",optionsframe,"TOP",0,12)

    local headertext = optionsframe:CreateFontString(nil,"ARTWORK","GameFontNormal")
    headertext:SetPoint("TOP",header,"TOP",0,-14)
    headertext:SetText("LH_CooldownPulse")

    for i,v in pairs(sliders) do
        local options = Settings.CreateSliderOptions(v.min, v.max, v.step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Top, function() return v.text end)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Max, function() return v.max end);
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Min, function() return v.min end);
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value) return format("%.1f", value) end);

        local slider = CreateFrame("Frame", "LH_CooldownPulse_OptionsFrameSlider"..i, optionsframe, "MinimalSliderWithSteppersTemplate")
        slider:SetScale(0.9)
        slider:SetSize(220, 40)
        slider:Init(LH_CooldownPulse_Saved[v.value], options.minValue, options.maxValue, options.steps, options.formatters)
        if (i == 1) then
            slider:SetPoint("TOP",optionsframe,"TOP",0,-40)
        else
            slider:SetPoint("TOP",getglobal("LH_CooldownPulse_OptionsFrameSlider"..(i-1)),"BOTTOM",0,-20)
        end
        slider:RegisterCallback("OnValueChanged", function(self, value)
            LH_CooldownPulse_Saved[v.value] = value
            RefreshLocals()
            if (DCP:IsMouseEnabled()) then
                DCP:SetWidth(LH_CooldownPulse_Saved.iconSize)
                DCP:SetHeight(LH_CooldownPulse_Saved.iconSize)
            end
        end)

        slider.RightText:ClearAllPoints()
        slider.RightText:SetPoint("TOP",slider.Slider,"CENTER",0,-15)
    end

    local pettext = optionsframe:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
    pettext:SetPoint("TOPLEFT","LH_CooldownPulse_OptionsFrameSlider"..#sliders,"BOTTOMLEFT",13,-20)
    pettext:SetText("Pet color overlay:")

    local petcolorselect = CreateFrame('Button',"LH_CooldownPulse_OptionsFramePetColorBox",optionsframe)
    petcolorselect:SetPoint("LEFT",pettext,"RIGHT",10,0)
    petcolorselect:SetWidth(20)
    petcolorselect:SetHeight(20)
    petcolorselect:SetNormalTexture('Interface/ChatFrame/ChatFrameColorSwatch')
    petcolorselect:GetNormalTexture():SetVertexColor(unpack(LH_CooldownPulse_Saved.petOverlay))
    petcolorselect:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self, "ANCHOR_CURSOR") GameTooltip:SetText("Note: Use white if you don't want any overlay for pet cooldowns") end)
    petcolorselect:SetScript("OnLeave",function(self) GameTooltip:Hide() end)
    petcolorselect:SetScript('OnClick', function(self)
        local r, g, b = unpack(LH_CooldownPulse_Saved.petOverlay)
        ColorPickerFrame:SetupColorPickerAndShow({
            swatchFunc = function(self) LH_CooldownPulse_Saved.petOverlay={ColorPickerFrame:GetColorRGB()} petcolorselect:GetNormalTexture():SetVertexColor(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function(self) LH_CooldownPulse_Saved.petOverlay={r,g,b} petcolorselect:GetNormalTexture():SetVertexColor(unpack(LH_CooldownPulse_Saved.petOverlay)) end,
            hasOpacity = false,
            r = r,
            g = g,
            b = b
        })
        ColorPickerFrame:SetPoint("TOPLEFT",optionsframe,"TOPRIGHT")
    end)

    local petcolorselectbg = petcolorselect:CreateTexture(nil, 'BACKGROUND')
    petcolorselectbg:SetWidth(17)
    petcolorselectbg:SetHeight(17)
    petcolorselectbg:SetColorTexture(1,1,1)
    petcolorselectbg:SetPoint('CENTER')

    local spellnametext = optionsframe:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
    spellnametext:SetPoint("TOPLEFT",pettext,"BOTTOMLEFT",0,-18)
    spellnametext:SetText("Show spell name:")

    local spellnamecbt = CreateFrame("CheckButton","LH_CooldownPulse_OptionsFrameSpellNameCheckButton",optionsframe,"UICheckButtonTemplate")
    spellnamecbt:SetPoint("LEFT",spellnametext,"RIGHT",6,0)
    spellnamecbt:SetChecked(LH_CooldownPulse_Saved.showSpellName)
    spellnamecbt:SetScript("OnClick", function(self)
        local newState = self:GetChecked()
        self:SetChecked(newState)
        LH_CooldownPulse_Saved.showSpellName = newState
        RefreshLocals()
    end)

    local ignoretext = optionsframe:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
    ignoretext:SetPoint("TOPLEFT",spellnametext,"BOTTOMLEFT",0,-18)
    ignoretext:SetText("Filter spells:")

    local ignoretypebuttonblacklist = CreateFrame("Checkbutton","LH_CooldownPulse_OptionsFrameIgnoreTypeButtonBlacklist",optionsframe,"UIRadioButtonTemplate")
    ignoretypebuttonblacklist:SetPoint("TOPLEFT",ignoretext,"BOTTOMLEFT",0,-4)
    ignoretypebuttonblacklist:SetChecked(not LH_CooldownPulse_SavedPerCharacter.invertIgnored)
    ignoretypebuttonblacklist:SetScript("OnClick", function()
        LH_CooldownPulse_OptionsFrameIgnoreTypeButtonWhitelist:SetChecked(false)
        LH_CooldownPulse_SavedPerCharacter.invertIgnored = false
        RefreshLocals()
    end)

    local ignoretypetextblacklist = optionsframe:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
    ignoretypetextblacklist:SetPoint("LEFT",ignoretypebuttonblacklist,"RIGHT",4,0)
    ignoretypetextblacklist:SetText("Blacklist")

    local ignoretypebuttonwhitelist = CreateFrame("Checkbutton","LH_CooldownPulse_OptionsFrameIgnoreTypeButtonWhitelist",optionsframe,"UIRadioButtonTemplate")
    ignoretypebuttonwhitelist:SetPoint("LEFT",ignoretypetextblacklist,"RIGHT",10,0)
    ignoretypebuttonwhitelist:SetChecked(LH_CooldownPulse_SavedPerCharacter.invertIgnored)
    ignoretypebuttonwhitelist:SetScript("OnClick", function()
        LH_CooldownPulse_OptionsFrameIgnoreTypeButtonBlacklist:SetChecked(false)
        LH_CooldownPulse_SavedPerCharacter.invertIgnored = true
        RefreshLocals()
    end)

    local ignoretypetextwhitelist = optionsframe:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
    ignoretypetextwhitelist:SetPoint("LEFT",ignoretypebuttonwhitelist,"RIGHT",4,0)
    ignoretypetextwhitelist:SetText("Whitelist")

    local ignorebox = CreateFrame("EditBox","LH_CooldownPulse_OptionsFrameIgnoreBox",optionsframe,"InputBoxTemplate")
    ignorebox:SetAutoFocus(false)
    ignorebox:SetPoint("TOPLEFT",ignoretypebuttonblacklist,"BOTTOMLEFT",4,2)
    ignorebox:SetWidth(170)
    ignorebox:SetHeight(32)
    ignorebox:SetText(LH_CooldownPulse_SavedPerCharacter.ignoredSpells)
    ignorebox:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self, "ANCHOR_CURSOR") GameTooltip:SetText("Note: Separate multiple spells with commas") end)
    ignorebox:SetScript("OnLeave",function(self) GameTooltip:Hide() end)
    ignorebox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    ignorebox:SetScript("OnEditFocusLost",function(self)
        LH_CooldownPulse_SavedPerCharacter.ignoredSpells = ignorebox:GetText()
        RefreshLocals()
    end)

    for i,v in pairs(buttons) do
        local button = CreateFrame("Button", "LH_CooldownPulse_OptionsFrameButton"..i, optionsframe, "UIPanelButtonTemplate")
        button:SetHeight(24)
        button:SetWidth(75)
        button:SetPoint("BOTTOM", optionsframe, "BOTTOM", ((i%2==0 and -1) or 1)*45, 10 + ceil(i/2)*15 + (ceil(i/2)-1)*15)
        button:SetText(v.text)
        button:SetScript("OnClick", function(self) PlaySound(852) v.func(self) end)
    end
end
