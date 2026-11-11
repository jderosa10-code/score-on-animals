# Robux products to create on the Creator Dashboard

Prices and contents live in `ReplicatedStorage.GameConfig` (`G.Passes`, `G.Products`). Set these prices on the dashboard, then paste each id into its `Id` (and `GiftId` for the gift copy, same price). Until an id is in, the shop shows `Price` and "Coming soon!" on buy.

Balance rule (pigeon-claude, 2026-11-11): a pack is worth minutes of the player's own progress, and bigger packs give more per Robux. Packs scale with the player, so they never skip the game. The top tiers (Secret, Celestial...) are never sold.

| Key | Type | Price | Gives | Where |
|---|---|---|---|---|
| VIP | game pass (+ gift product) | 299 | $1M once, 2x cash, a free Turtle egg | shop VIPPack |
| Cash2x | game pass (+ gift) | 199 | 2x cash | shop Boost2xCash, BoostsHUD |
| Luck2x | game pass (+ gift) | 249 | 2x luck | shop Boost2xStrength card, BoostsHUD |
| Pack10M | product (+ gift) | 49 | 60 min of your income, at least $10K | shop Pack10M |
| Pack100M | product (+ gift) | 199 | 360 min of your income, at least $75K | shop Pack100M |
| StrengthSmall | product | 19 | 30 min of lifting, or 3% of your Strength, at least +25 | lifting bar BoostButton1 |
| StrengthMedium | product | 79 | 150 min of lifting, or 14%, at least +100 | BoostButton2 |
| StrengthLarge | product | 249 | 600 min of lifting, or 50%, at least +350 | BoostButton3 |
| EggTRex | product (+ gift) | 299 | T-Rex egg (Legendary, $200/s) | shop EasterEgg card |
| EggElephant | product (+ gift) | 129 | Elephant egg (Epic, $75/s) | shop ChickenEgg card |
| EggTurtle | product (+ gift) | 25 | Turtle egg (Uncommon, $12/s) | shop BabyEgg card |
| LuckyPack | product | 99 | a random egg rolled with x10 luck | BoostsHUD LuckyPack |
| SkipRebirth | product | 149 | rebirth without the requirements | Rebirth menu |

Test a product in Studio without buying: `game.ServerStorage.DevCommand:Invoke("grant", player, "StrengthSmall")` (server).
