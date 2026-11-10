# Score on Animals: GDD (built from what we have)

This turns [PLAN.md](PLAN.md) into a buildable design using the animals, mutations, eggs and VFX already in the Studio place.

**Eggs are the goalkeepers** (Jacob, 9 Nov 2026). You score on an egg, it hatches, and the animal inside joins your stadium.
**One small map, one shared net** (Jacob, 9 Nov 2026): walk up to the kick area and an egg rolls on your screen. Leagues replace walk-to zones. Full lists: [docs/inventory.md](docs/inventory.md).

## 1. What we have
| Asset | Count | Where |
|---|---|---|
| Animals (base models, rigged) | 213 (+49 Halloween archived) | `Workspace.BaseAnimals` |
| Pre-built mutation models | Gold, Diamond, Rainbow, Inverted, Hacked: 213 each | `ReplicatedStorage.Assets.Animals` |
| Eggs (one per animal) | 197 base + Gold/Diamond/Rainbow/Inverted/Hacked sets (196 each) | `ServerStorage.BaseEggs`, `ReplicatedStorage.Assets.Eggs` |
| Rarity + mutation auras | 15 | `Assets.VFX.Mutations` |
| Trait VFX + trait auras | 13 + 23 | `Assets.VFX.Traits`, `Assets.VFX.TraitAuras` |
| One-shot effects | 32 (cash collect, buy, rebirth, poof, explosion, eat...) | `Assets.VFX.Effects` |
| Screen particles | Confetti, Epic, Mythic, Sparkles, EggCrack x2, Explosion | `Assets.VFX.ScreenParticles` |
| Event VFX | Tornado, Disco Ball, Volcano, Eclipse, Meteor, Night | `Assets.VFX.Events` |
| Weather | Default + Thunderstorm lighting and map | `Assets.VFX.Weather` |
| Bone animations | 1,553 (see section 7) | `ServerStorage.RBX_ANIMSAVES` |

## 2. Rarity tiers
The pack uses 12 tiers. The plan uses 6. Mapping:

| Game rarity | Pack tiers that fill it | Animals | Notes |
|---|---|---|---|
| Common | Common, Uncommon, most untagged everyday animals | ~60 | Dogs, cats, farm animals, reef fish |
| Rare | Rare + some untagged | ~25 | Lion, Wolf, Shark, Elephant, Gorilla |
| Epic | Epic | 17 | Bear, Tiger, Crocodile, Mammoth, Whale |
| Legendary | Legendary | 17 | T-Rex, Megalodon, Kitsune, Spinosaurus |
| Mythic | Mythic + Exotic | 34 | Griffin, Pegasus, Phoenix, Unicorn, Qilin |
| Secret | Divine + Celestial + Secret | 26 | Dragon, Kraken, Sphinx, Chimera, Fenrir |
| Event only | Admin + Hacker | 10 | Cup Final bosses and admin events (KrakenKing, GreenDragon, Axolotl...) |

The 76 untagged animals (mostly real-world dogs, reef fish, farm and savanna animals) still need a rarity. Default: by zone, Common or Rare.

## 3. The map and leagues
**Map:** one small stadium, one net shared by all players, one kick area in front of it.
- Walking into the kick area starts an **egg roll** on your screen (RNG spin, like an RNG game) from your league's pool, weighted by Luck.
- **Roll screen is a Bowmasters-style VS screen** (Jacob, 9 Nov 2026): your character on the left, a vertical RNG reel on the right that ticks through eggs, slows down and lands on the one you face, showing its rarity. Jacob builds the screen; the Claudes build the roll logic (Luck-weighted pick, the reel list that ends on it, tick timing, sounds, then the egg hops in).
- The rolled egg hops into the net **on your screen only**. Everyone kicks at the same net at once, so nobody queues.
- Legendary and rarer rolls are shown to the whole server (the egg appears for everyone + an announcement).
- Your animals live around the pitch (bench or plot per player; open question).

**Leagues:** promotion (rebirth) moves you up a league. The egg pool changes and the stadium reskins. Examples of each league's eggs from what we have (each egg hatches the animal named):

| # | League | Eggs of (examples) |
|---|---|---|
| 1 | Backyard | Chicken, Bunny, Cat, Dog, Hamster, Frog, Corgi, Guinea Pig |
| 2 | School Field | Goat, Duck, Pigeon, Beaver, Hedgehog, Badger, Meerkat |
| 3 | Zoo Stadium | Capybara, Kangaroo, Koala, Quokka, Red Panda, Lemur, Toucan |
| 4 | Safari Arena | Lion, Zebra, Giraffe, Elephant, White Rhino, Hippo, Hyena |
| 5 | Arctic Dome | Polar Bear, Seal, Mammoth, Woolly Mammoth, Yak, Puffin, Moose |
| 6 | Jungle | Gorilla, Tiger, Parrot, Sloth, Chameleon, Anaconda, Cassowary |
| 7 | Ocean | Shark, Octopus, Stingray, Whale, Swordfish, Megalodon, Kraken |
| 8 | Dino Coliseum | T-Rex, Triceratops, Stegosaurus, Velociraptor, Spinosaurus, Pteranodon |
| 9 | Mythic | Griffin, Pegasus, Unicorn, Phoenix, Dragon, Cerberus, Hydra |
| 10 | Moon | Celestial and Secret tier: Caladrius, Nautilus, Sphinx, Chimera, Fenrir |

No Penguin in the pack. It needs a model if we keep it as the belly-slide example.

## 4. Egg keeper styles from numbers
Every egg keeper is `{reach, react, diveSpeed, diveType}`, and it keeps goal like the animal inside it would. Eggs have no legs, so every move is whole-body code in `KeeperAnimator`: hop, squash and stretch, tilt, roll, bounce. Defaults by the animal inside, tuned per egg later:

| Animal inside | Dive type | Feel |
|---|---|---|
| Small animals (Backyard) | panic (random bounces) or hop, short reach | Easy, funny |
| Big animals (Elephant, Rhino, Mammoth) | hop, huge egg, slow react | Fills the goal, beat it with power |
| Long-necked (Giraffe, Brachiosaurus) | hop, tall egg, bounces high | Shoot low |
| Birds | hop, fast react | Far corner |
| Shelled (Turtle, Tortoise, Sea Turtle) | dig in (doesn't move) | Raw power only |
| Swimmers, snakes (Ocean zone) | roll along the goal line | Shoot high |
| Tentacled (Octopus, Kraken, Squid) | wobble, covers the corners | Shoot the middle |
| Dinos (T-Rex, raptors) | fast hops, short reach up top | Corners |

## 5. Mutations and size
| Mutation | How it shows | Source |
|---|---|---|
| Gold | Gold model + Gold aura | Pre-built model + `VFX.Mutations.Gold` |
| Diamond | Diamond model + aura | Pre-built model + `VFX.Mutations.Diamond` |
| Rainbow | Rainbow model + aura | Pre-built model + `VFX.Mutations.Rainbow` |
| Fire | Base model + Lava aura | `VFX.Mutations.Lava` |
| Inverted (event) | Inverted model + aura | Pre-built model |
| Hacked (event) | Hacked model + glitch aura | Pre-built model |

Size: normal, Big (x1.5), Huge (x2.2) using `Model:ScaleTo`. Animations scale with the model.
Rarity auras (Legendary, Mythic, Divine, Secret, Celestial, Admin, Hacker) go on top of any mutation. Base models carry a `VFX_<Rarity>` tag so code knows which aura to add.

## 6. Eggs as keepers (core loop)
We have an egg for almost every animal (197 base eggs) plus Gold, Diamond, Rainbow, Inverted and Hacked egg sets (196 each).

- **Roll:** stepping into the kick area spins the egg roll on your screen. It lands on an egg, which hops into the net. Rarer eggs get their rarity aura.
- **Saves:** the egg hops, rolls or wobbles toward the ball (section 4). Big and Huge eggs cover more goal.
- **Goal:** the ball beats the egg, it cracks (`ScreenParticles.EggCrack`, `EggCrack2`), and the hatch reveal shows the animal (`Epic` / `Mythic` screen particles for high tiers). The animal stands up, does its Idle, then runs off toward your stadium.
- **Blast:** Kick Power far above Save Power knocks the egg into the net, where it cracks open. That's still a goal.
- **Miss:** the egg bounces the ball back into you and you ragdoll.
- **Mutation eggs:** a Gold, Diamond or Rainbow egg hatches that mutation. They're rarer walk-outs and boost Golden Goal.
- **What hatches (open):** our eggs are themed one per animal, so the simplest rule is "the egg hatches its own animal". The other option is a random animal from the zone pool. See PLAN open questions.
- **Missing eggs:** a few animals have no exact egg match (see inventory). They need an egg made or a renamed match before they can appear.

## 7. Animation status
| Group | Count | Animations |
|---|---|---|
| Walkers | 113 | Idle, Walk + keeper set: Run, Ready, Dive, Kick, Tuck, Shell, Flail |
| Winged walkers | 42 | All of the above + Fly (wings flap in Idle and Walk too) |
| Swimmers | 45 | Idle, Swim (tentacles curl on octopus/squid/jellyfish/Kraken) |
| Snakes | 7 | Idle, Slither |
| Pure fliers | 2 | Idle (hover), Fly |
| Kangaroo / crawlers | 4 | Idle + Hop / crawl |

Keeper whole-body moves are code (`KeeperAnimator`): walk out, ready shuffle, dive (jump, slide, panic, shell), flop, get up, celebrate, punt, sulk, blasted into the net. With eggs as keepers these moves move the egg; egg-specific moves (hop, squash and stretch, roll, dig in, crack) still need adding. The animals' Idle and Walk play after they hatch and on the bench. The animal keeper leg sets (Run, Ready, Dive, Kick...) are kept for later, e.g. a Cup Final animal boss.
**Not published yet**: animations only play in Studio Run mode (F8) until they're published and given real IDs.

## 8. VFX use
| Moment | VFX |
|---|---|
| Egg roll lands (rare+) | Rarity aura from `VFX.Mutations`; `ScreenParticles.Epic` / `Mythic` for high tiers |
| Goal scored | `ScreenParticles.Confetti`, `Effects.Explosion` |
| Egg blasted into the net | `Effects.Poof`, `ScreenParticles.Explosion`, then the hatch |
| Cash from bench | `Effects.CashCollect` |
| Buy upgrade / ball | `Effects.Buy` |
| Promotion (rebirth) | `Effects.Rebirth` |
| Egg hatch | `ScreenParticles.EggCrack`, `EggCrack2` |
| Rain event | `Weather` thunderstorm |
| Extra server events | `Events.Tornado`, `Meteor`, `Eclipse`, `DiscoBall` (keepers get the matching trait aura) |

## 9. MVP
One stadium with the shared net. Backyard league with five eggs (Chicken, Bunny, Cat, Dog and Frog eggs), the egg roll at the kick area, the kick, egg dive/save, the hatch reveal, bench with cash per second, kick wall, one Luck upgrade.

## 10. UI direction
A mix of a normal Roblox simulator and FIFA (Jacob, 9 Nov 2026). Jacob builds all UI; this is the direction only.

| Screen | Style |
|---|---|
| Index (sticker album) | FIFA-style player cards: rarity-colored card, animal render, rating, Save Power, cash/sec, mutation badge |
| Hatch reveal | The card flips in, like opening a pack |
| Rare-roll server announcement | Card pops up for everyone |
| Egg roll at the kick area | RNG-game spin, Roblox style |
| HUD, shop, upgrades, Luck, kick wall | Normal Roblox simulator style |

Our own names and art only: no FIFA or EA names, logos or card designs copied.

## 11. Risks
- ~~The animal pack, its eggs and VFX came from another game's files. Confirm we're allowed to ship it before launch.~~ **Resolved 9 Nov 2026 (pigeon):** the pack comes from Fake an Egg, which is our own game, so it's fine to ship.
- Animations need publishing under the account or group that owns the game.
