# LH_CooldownPulse

Version: 1.60.1-forever.2. WoW Forever Beta (Interface 16001).

Flashes an ability's icon when its cooldown ends. Supports player spells, pet abilities and usable items in bags or equipment.

## Configuration

Use `/lh_cooldownpulse` to open the options window. Select **Test** to preview the animation. Select **Unlock**, drag the icon to your preferred position, then select **Lock**.

Options include icon size, fade timing, opacity, hold time, animation scaling, advance notification time, pet color overlay, spell names and per-character spell filters. **Defaults** restores the default settings.

Animation settings and icon position are saved account-wide in `LH_CooldownPulse_Saved`. Spell filters are saved per character in `LH_CooldownPulse_SavedPerCharacter`.

## Installation and upgrade

Place the `LH_CooldownPulse` folder in your game's `Interface/AddOns` folder. It must contain `LH_CooldownPulse.toc` and `LH_CooldownPulse.lua`. Restart WoW and enable **LH_CooldownPulse** in the addon list.

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

The previous version's documentation recorded successful Lua loading and simulated initialization, cooldown completion, global-cooldown suppression, disabled cooldowns and restricted values. These are historical checks. In-game verification of this rename remains pending: restart WoW, open `/lh_cooldownpulse`, select **Test**, and check player spells, pet abilities and usable items.

## Credits

Original author: Woffle of Dark Iron[US]. Adapted from Doom_CooldownPulse for WoW Forever Beta.

## Changelog

### 1.60.1-forever.2 - 2026-10-21

- Renamed Doom_CooldownPulse to LH_CooldownPulse, including the folder, Lua/TOC files, metadata, options title, global option-frame names and saved-variable tables.
- Replaced the previous commands with `/lh_cooldownpulse`.
- Translated and repaired the English documentation, including migration instructions for account and character settings.
