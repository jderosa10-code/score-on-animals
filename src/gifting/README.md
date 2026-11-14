# Hold-E gifting (pigeon, 14 Nov 2026)

Walk up to another player while holding an animal and hold their **Gift** prompt (E on keyboard, X on a gamepad, hold-tap on touch). The animal in your hands is the gift. Empty hands give a "You're not holding any animal!" banner.

They get `StarterGui.Popups.GiftPopup`, a copy of ConfirmPopup with ACCEPT, DECLINE (with a 15 s countdown) and BLOCK. The X counts as a decline.

**Live in the place (these files are copies):**
- `ServerScriptService.GiftServer`: the rules and anti-spam; it moves the item with `GameData.takeItem` / `giveItem`.
- `StarterPlayerScripts.GiftClient`: the prompts on other players, the popup and the banners.
- `GameRemotes.Gift`: the RemoteEvent between them.
- `SettingsMenu ... Options.Gifts`: the Gifts ON/OFF row. It's saved as `Settings.Gifts` and is in `HUDClient` DEFAULT.

**Anti-spam:**
- One waiting gift per sender and per receiver.
- The popup auto-declines after 15 s.
- After a decline or no answer, that pair waits 1 min, then 5 min, then 15 min, and the sender waits 10 s before gifting anyone.
- 3 declines in a row, or pressing BLOCK, blocks that sender for the rest of the server.
- An accepted gift adds no wait.
- The sender must be within 16 studs, and ownership is checked again on accept.

**Studio testing:** setting workspace attribute `GiftSelfTest = true` lets you gift yourself, so one player can test the popup.
