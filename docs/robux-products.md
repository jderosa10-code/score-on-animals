# Robux products (created 2026-11-11)

Prices and contents live in `ReplicatedStorage.GameConfig` (`G.Passes`, `G.Products`). All passes and products below were created by pigeon-claude through Open Cloud on 2026-11-11 (group-owned universe 10775616643) and their ids are in GameConfig. Change a price on the Creator Dashboard AND in GameConfig `Price` (the shop shows GameConfig). Pictures: `_studio_src/product_icons` (local).

Balance rule (pigeon-claude, 2026-11-11): a pack is worth minutes of the player's own progress, and bigger packs give more per Robux. Packs scale with the player, so they never skip the game. The top tiers (Secret, Celestial...) are never sold.

| Key | Type | Price | Gives | Where | Id | Gift id |
|---|---|---|---|---|---|---|
| StarterPack | product, one per player | 99 | Giraffe egg (Rare) + 150 min of lifting (or 14% of your Strength, at least +100) + 2 h of income (at least $25K); about 2x the value of buying them separately | shop top card (VIPPack frame) | 3730520668 | - |
| VIP | game pass | 299 | not sold any more (card now sells the Starter Pack); perks still work if owned: 1.5x cash, 1.25x lift XP | - | not created | - |
| Cash2x | game pass (+ gift) | 199 | 2x cash | shop Boost2xCash, BoostsHUD | 2082212310 | 3730520744 |
| Luck2x | game pass (+ gift) | 249 | 2x luck | shop Boost2xStrength card, BoostsHUD | 2081720308 | 3730520756 |
| Pack10M | product (+ gift) | 49 | 60 min of your income, at least $10K | shop Pack10M | 3730520464 | 3730520818 |
| Pack100M | product (+ gift) | 199 | 360 min of your income, at least $75K | shop Pack100M | 3730520528 | 3730520834 |
| StrengthSmall | product | 19 | 30 min of lifting, or 3% of your Strength, at least +25 | lifting bar BoostButton1 | 3730520534 | - |
| StrengthMedium | product | 79 | 150 min of lifting, or 14%, at least +100 | BoostButton2 | 3730520542 | - |
| StrengthLarge | product | 249 | 600 min of lifting, or 50%, at least +350 | BoostButton3 | 3730520584 | - |
| EggTRex | product (+ gift) | 299 | T-Rex egg (Legendary, $200/s) | shop EasterEgg card | 3730520594 | 3730520844 |
| EggElephant | product (+ gift) | 129 | Elephant egg (Epic, $75/s) | shop ChickenEgg card | 3730520603 | 3730520903 |
| EggTurtle | product (+ gift) | 25 | Turtle egg (Uncommon, $12/s) | shop BabyEgg card | 3730520650 | 3730520918 |
| LuckyPack | product | 99 | a random egg rolled with x10 luck | BoostsHUD LuckyPack | 3730520659 | - |
| SkipRebirth | product | 149 | rebirth without the requirements | Rebirth menu | 3730520734 | - |

Test a product in Studio without buying: `game.ServerStorage.DevCommand:Invoke("grant", player, "StrengthSmall")` (server).
