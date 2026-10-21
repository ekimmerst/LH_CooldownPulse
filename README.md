# LH_CooldownPulse

Version: 1.60.1-forever.3. WoW Forever Beta (Interface 16001).

Flashes an ability's icon when its cooldown ends. Supports player spells, pet abilities and usable items in bags or equipment.

## Configuration

Open WoW Settings > AddOns > LH Tweaks > LH CooldownPulse, or use `/lh_cooldownpulse` to open that page directly. This is a native settings subcategory; the standalone options window has been removed. The first row below the page heading reads **Fork of Doom_CooldownPulse by discoteq.**

Select **Test** to preview the animation. Enable **Unlock icon position**, left-drag the preview icon, then disable the checkbox to lock it. Unlocking lasts for the current session. Test also locks the icon. **Reset position** centers the icon while retaining the other settings.

Options include the original seven sliders for icon size, fade timing, opacity, hold time, animation scaling and advance notification time; a native pet color swatch; spell names; and per-character spell/item filters. White disables the pet tint. In **Names or IDs**, separate localized spell/item names or numeric IDs with commas. Enter or leaving the field saves the text; Escape cancels editing. With **Use an allowlist** disabled, listed entries are excluded. With it enabled, only listed entries notify; an empty allowlist suppresses all notifications.

Blizzard's **Defaults** for this category restores all animation settings, the white pet tint, hidden spell names, centered position and empty exclusion list, then locks the icon. Other LH categories are unaffected. The game-wide defaults action also resets this addon.

Animation settings and icon position are saved account-wide in `LH_CooldownPulse_Saved`. Spell filters are saved per character in `LH_CooldownPulse_SavedPerCharacter`.

## Installation and upgrade

Place the complete `LH_CooldownPulse` folder in your game's `Interface/AddOns` folder, including its Lua/TOC files, Settings.lua, Settings.xml and Media directory. Install and enable LH_Tweaks as well. Fully restart WoW and enable **LH CooldownPulse**, grouped under **LH Tweaks** in the AddOn list. Version 1.60.1-forever.3 needs a full restart because its TOC loads new files.

Media/Icon.png and Media/Icon.tga are exact copies of LH_Tweaks' shared gold LH artwork, using Spoken's chamfered gold frame as the reference. There is no runtime Spoken dependency.

When upgrading from Doom_CooldownPulse, replace the old folder and fully restart WoW. Do not enable both versions together. The former `/dcp`, `/cooldownpulse` and `/doomcooldownpulse` commands are replaced by `/lh_cooldownpulse`.

To retain your settings, close WoW and back up both types of saved-variable file:

- Account settings: `WTF/Account/<account>/SavedVariables/Doom_CooldownPulse.lua`.
- Character settings: `WTF/Account/<account>/<realm>/<character>/SavedVariables/Doom_CooldownPulse.lua` for each character.

Copy each file to `LH_CooldownPulse.lua` in the same SavedVariables folder. Inside each copy, replace `DCP_SavedPerCharacter` with `LH_CooldownPulse_SavedPerCharacter` and `DCP_Saved` with `LH_CooldownPulse_Saved`. Migrate before first using the renamed addon; do not overwrite an existing `LH_CooldownPulse.lua` containing settings you want to keep. Without migration, default settings are used.

## Cooldown tracking and beta limitations

Player spells are tracked through `UNIT_SPELLCAST_SUCCEEDED`, and pet abilities through pet events. Bag and equipped items are checked on cooldown and inventory events. No combat-log processing or hooks on protected use functions are required.

Cooldowns are queried again to account for resets, reductions and charges. Global cooldowns and shared item lockouts of two seconds or less do not trigger a pulse.

Restricted secret values are not inspected or used to estimate cooldown completion. While the beta protects a cooldown, a reliable completion or advance notification cannot be displayed. If it is already ready when readable data returns, a late notification is suppressed. Cooldowns that are still running resume normal monitoring.

Active item and pet cooldowns are discovered at loading. Player spells are tracked after their next successful cast.

## Verification

The `.settings-test.py` Lua 5.1 simulation checks the real host's module registration, all 12 native settings proxies, the first-row fork notice, saved settings, inline filter editing/cancellation/pooling, color conversion, preview/drag/position reset, category-scoped/global defaults, and real player/pet/item notification paths and restricted cooldown suppression. It also checks XML parsing and identical icon files. Run `python .settings-test.py` from this folder with Lupa installed in `.test-runtime`.

Native rendering remains pending in game: fully restart WoW, open `/lh_cooldownpulse`, inspect the fork notice, exercise every control, test filters and defaults, and check player spells, pet abilities and usable items. The previous version's documentation additionally recorded simulated global-cooldown suppression and disabled-cooldown checks; these are historical checks.

## Credits

Fork of Doom_CooldownPulse by **discoteq**, adapted for the LH Tweaks suite and WoW Forever Beta. The inherited original-author credit **Woffle of Dark Iron[US]** remains in the TOC.

## Changelog

### 1.60.1-forever.3 - 2026-10-21

- Replaced the standalone options dialog with a native LH CooldownPulse subcategory under LH Tweaks. The slash command opens that native page.
- Retained all existing options using native sliders, checkboxes and a color swatch, plus an inline filter text field in the settings list. Existing account-wide and per-character saved-variable tables are preserved.
- Added test, unlock/lock, position reset and category-scoped/global defaults, including immediate application to animation settings. Unlocked previews survive world entry.
- Added the discoteq fork notice directly below the page heading and preserved the inherited author credit.
- Added the shared LH icon and native AddOn list grouping under LH Tweaks.
- Reset the pet tint on world entry so a subsequent spell/item pulse cannot inherit the previous pet icon's color.
- `.settings-test.py` and `git diff --check` passed. Native in-game rendering remains pending.

### 1.60.1-forever.2 - 2026-10-21

- Renamed Doom_CooldownPulse to LH_CooldownPulse, including the folder, Lua/TOC files, metadata, options title, global option-frame names and saved-variable tables.
- Replaced the previous commands with `/lh_cooldownpulse`.
- Translated and repaired the English documentation, including migration instructions for account and character settings.

## Required core addon

Install and enable **LH_Tweaks** alongside this addon. LH_Tweaks is the shared LiteHawk configuration host and must load first. CurseForge releases must list LH_Tweaks as a required dependency so the client installs it automatically.
