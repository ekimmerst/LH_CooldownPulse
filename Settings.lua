local addonName = ...
local Addon = LH_CooldownPulse
local variables = {}

function Addon:RefreshSettings()
    if self.notifying or not Settings or not Settings.NotifyUpdate then return end
    self.notifying = true
    for _, variable in ipairs(variables) do Settings.NotifyUpdate(variable) end
    self.notifying = false
end

local function Proxy(category, key, kind, label, default, get, set)
    local variable = "LH_CooldownPulse_" .. key
    variables[#variables + 1] = variable
    return Settings.RegisterProxySetting(category, variable, kind, label, default,
        get or function() return Addon:GetOption(key) end,
        set or function(value) Addon:SetOption(key, value) end)
end

local function Header(layout, text)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

local function Button(layout, label, text, callback, tooltip)
    layout:AddInitializer(CreateSettingsButtonInitializer(label, text, callback, tooltip, true))
end

-- A pooled inline text control inside Blizzard's settings list, not a popup.
local FilterControl = {}
function FilterControl:OnLoad()
    self.Text = self:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.Tooltip = CreateFrame("Frame", nil, self)
    self.Tooltip:SetPoint("TOPLEFT")
    self.Tooltip:SetPoint("BOTTOMRIGHT", self, "BOTTOM", -80, 0)
    Mixin(self.Tooltip, DefaultTooltipMixin)
    self.Tooltip:OnLoad()
    self.NewFeature = CreateFrame("Frame", nil, self, "NewFeatureLabelTemplate")
    self.NewFeature:SetPoint("BOTTOMRIGHT", self.Text, "LEFT", 16, -10)
    self.NewFeature:Hide()
    SettingsControlMixin.OnLoad(self)
    self.EditBox = CreateFrame("EditBox", nil, self, "InputBoxTemplate")
    self.EditBox:SetAutoFocus(false)
    self.EditBox:SetSize(280, 26)
    self.EditBox:SetPoint("LEFT", self, "CENTER", -70, 0)
    self.EditBox:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)
    self.EditBox:SetScript("OnEscapePressed", function(box)
        if self.data then box:SetText(self:GetSetting():GetValue()) end
        box:ClearFocus()
    end)
    self.EditBox:SetScript("OnEditFocusLost", function(box)
        if self.data then self:GetSetting():SetValue(box:GetText()) end
    end)
    self.EditBox:SetScript("OnHide", function(box) box:ClearFocus() end)
    self.EditBox:SetScript("OnEnter", function() self.Tooltip:OnEnter() end)
    self.EditBox:SetScript("OnLeave", function() self.Tooltip:OnLeave() end)
end
function FilterControl:Init(initializer)
    SettingsControlMixin.Init(self, initializer)
    self:SetValue(self:GetSetting():GetValue())
    self:SetSmartNavCursorAnchor(self.EditBox)
end
function FilterControl:SetValue(value)
    if self.EditBox:GetText() ~= value then self.EditBox:SetText(value) end
end
function FilterControl:Release()
    self.EditBox:ClearFocus()
    SettingsControlMixin.Release(self)
end

local function Build(category, layout)
    Addon.category = category
    LH_CooldownPulseFilterControlMixin = CreateFromMixins(SettingsControlMixin, FilterControl)
    Header(layout, "Positioning")
    local locked = Proxy(category, "locked", "boolean", "Lock pulse icon", true,
        function() return not Addon:IsMouseEnabled() end,
        function(value) Addon:SetUnlocked(not value) end)
    Settings.CreateCheckbox(category, locked, "Disable to show a stationary preview icon and drag it to move the pulse. Enable to lock. Position is saved account-wide; unlocking lasts for this session.")
    Button(layout, "Preview the current animation", "Test", function() Addon:Test() end,
        "Lock the icon and play one test pulse using your current settings.")
    Button(layout, "Restore the centered icon position", "Reset position", function() Addon:ResetPosition() end,
        "Center the icon without changing animation settings or filters.")

    Header(layout, "Fork of Doom_CooldownPulse by discoteq.")
    Header(layout, "Animation (account-wide)")
    for _, option in ipairs(Addon.options) do
        local setting = Proxy(category, option.key, "number", option.label, Addon:GetDefault(option.key))
        local options = Settings.CreateSliderOptions(option.min, option.max, option.step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
            function(value) return string.format(option.key == "iconSize" and "%.0f" or "%.1f", value) end)
        Settings.CreateSlider(category, setting, options, option.tooltip .. " Saved account-wide.")
    end
    local names = Proxy(category, "showSpellName", "boolean", "Show spell names", false)
    Settings.CreateCheckbox(category, names, "Display the spell or item name over the icon. Saved account-wide.")
    local petAbilities = Proxy(category, "trackPetAbilities", "boolean", "Track pet abilities", true)
    Settings.CreateCheckbox(category, petAbilities, "Notify when a pet ability is ready. Turning this off clears pending pet notifications. Saved account-wide.")
    local color = Proxy(category, "petOverlay", "string", "Pet color overlay", "ffffffff",
        function()
            local rgb = Addon:GetOption("petOverlay")
            return CreateColor(rgb[1], rgb[2], rgb[3], 1):GenerateHexColor()
        end,
        function(value)
            local picked = CreateColorFromHexString(value)
            Addon:SetOption("petOverlay", {picked:GetRGB()})
        end)
    Settings.CreateColorSwatch(category, color, "Tint pet cooldown icons. White disables the tint. Saved account-wide.")

    Header(layout, "Spell and item filters (per character)")
    local invert = Proxy(category, "invertIgnored", "boolean", "Use an allowlist", false)
    Settings.CreateCheckbox(category, invert, "Enabled: notify only for listed entries. Disabled: exclude listed entries. An empty allowlist suppresses all notifications. Saved per character.")
    local filter = Proxy(category, "ignoredSpells", "string", "Names or IDs", "")
    local tooltip = "Separate localized spell/item names or numeric IDs with commas. Press Enter or leave the field to save; Escape cancels editing. Saved per character."
    layout:AddInitializer(Settings.CreateSettingInitializer("LH_CooldownPulseFilterControlTemplate",
        Settings.CreateSettingInitializerData(filter, nil, tooltip)))

    EventRegistry:RegisterCallback("Settings.CategoryDefaulted", function(_, selected)
        if selected == category then Addon:RestoreDefaults() end
    end, Addon)
    EventRegistry:RegisterCallback("Settings.Defaulted", function() Addon:RestoreDefaults() end, Addon)
end

LH_Tweaks:RegisterModule(addonName, "LH CooldownPulse", Build)

SlashCmdList.LH_COOLDOWNPULSE = function()
    if Addon.category then Settings.OpenToCategory(Addon.category:GetID()) end
end
SLASH_LH_COOLDOWNPULSE1 = "/lh_cooldownpulse"
