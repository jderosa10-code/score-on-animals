# Score on Animals: GDD (built from what we have)

This turns [PLAN.md](PLAN.md) into a buildable design using the animals, mutations, eggs and VFX already in the Studio place. Full lists: [docs/inventory.md](docs/inventory.md).

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

## 3. Zones and their keepers
Each stadium draws from animals that fit its theme. Examples from what we have:

| # | Zone | Keepers (examples) |
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

## 4. Keeper styles from numbers
Every keeper is `{reach, react, diveSpeed, diveType}` (already working in `KeeperAnimator`). Defaults by body type, tuned per animal later:

| Body type | Default dive | Feel |
|---|---|---|
| Small 4-legged (Backyard) | panic or jump, short reach | Easy, funny |
| Big 4-legged (Elephant, Rhino, Mammoth) | jump, huge reach, slow react | Fills the goal, beat it with power |
| Long-necked (Giraffe, Brachiosaurus) | jump, covers high | Shoot low |
| Birds | jump with wing flaps, fast react | Shoot the far corner |
| Shelled (Turtle, Tortoise, Sea Turtle) | shell | Raw power only |
| Swimmers (Ocean zone) | slide (glide across the goal) | Shoot high |
| Tentacled (Octopus, Kraken, Squid) | arms cover the corners | Shoot the middle |
| Snakes | slide low | Shoot high |
| Dinos (T-Rex, raptors) | jump, tiny reach up top | Corners |

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

## 6. Eggs as keepers (new idea)
We have an egg for almost every animal, plus gold/diamond/rainbow/inverted/hacked egg sets. Eggs can block the goal instead of animals:

- **Mystery Egg walk-out**: sometimes an egg hops out of the tunnel instead of an animal. Score on it and it cracks, then a hatch roll reveals which animal you got (zone pool + Luck + mutation roll). This brings the egg-hatching reveal straight into the kick.
- **Egg keeper style**: eggs squash, stretch and hop side to side. They can't dive far, but big eggs fill more of the goal. Mutation eggs (gold, rainbow) are rarer and give better hatch odds.
- **Hatch moment**: `ScreenParticles.EggCrack`, then the rarity reveal (`Epic` / `Mythic` screen particles for high tiers).
- Eggs have no bones, so their hop is code-driven (scale + tilt), the same way the plan's launch keeper moves are.

Where it fits is an open question: a random walk-out in every zone, an egg-only zone, or an event ("Egg Rush").

## 7. Animation status
| Group | Count | Animations |
|---|---|---|
| Walkers | 113 | Idle, Walk + keeper set: Run, Ready, Dive, Kick, Tuck, Shell, Flail |
| Winged walkers | 42 | All of the above + Fly (wings flap in Idle and Walk too) |
| Swimmers | 45 | Idle, Swim (tentacles curl on octopus/squid/jellyfish/Kraken) |
| Snakes | 7 | Idle, Slither |
| Pure fliers | 2 | Idle (hover), Fly |
| Kangaroo / crawlers | 4 | Idle + Hop / crawl |

Keeper whole-body moves are code (`KeeperAnimator`): walk out, ready shuffle, dive (jump, slide, panic, shell), flop, get up, celebrate, punt, sulk, blasted into the net.
**Not published yet**: animations only play in Studio Run mode (F8) until they're published and given real IDs.

## 8. VFX use
| Moment | VFX |
|---|---|
| Keeper walk-out reveal (rare+) | Rarity aura from `VFX.Mutations` |
| Goal scored | `ScreenParticles.Confetti`, `Effects.Explosion` |
| Keeper blasted into net | `Effects.Poof`, `ScreenParticles.Explosion` |
| Cash from bench | `Effects.CashCollect` |
| Buy upgrade / ball | `Effects.Buy` |
| Promotion (rebirth) | `Effects.Rebirth` |
| Egg hatch | `ScreenParticles.EggCrack`, `EggCrack2` |
| Rain event | `Weather` thunderstorm |
| Extra server events | `Events.Tornado`, `Meteor`, `Eclipse`, `DiscoBall` (keepers get the matching trait aura) |

## 9. MVP
Unchanged from the plan's first build: Backyard, five keepers (Chicken, Bunny, Cat, Dog, Frog), the kick, keeper walk-out/dive/save, bench with cash per second, kick wall, one ball upgrade. Mystery Egg walk-out is the first add-on if the kick feels good.

## 10. Risks
- The animal pack, its eggs and VFX came from another game's files. The original plan called it study only; we've since decided to use it. Confirm we're allowed to ship it before launch.
- Animations need publishing under the account or group that owns the game.
