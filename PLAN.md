# Score on Animals: Game Plan

Every egg is a goalkeeper: score a penalty on it, it hatches, and the animal inside is yours.

## How to play
- Shoot a penalty at an egg goalkeeper
- Score and the egg cracks open: the animal inside joins your stadium
- Animals earn cash in your stadium
- Train on the kick wall for Kick Power
- Upgrade your Luck so rarer eggs roll
- Get promoted to new leagues with bigger, rarer eggs

Phone-first: one tap to aim, one tap to shoot. No stealing between players.

## Why now
The egg-collecting loop still tops Roblox, but a new verb alone no longer carries a game. This adds soccer's audience to that loop, and the hatch reveal now happens inside every goal.

Evidence (players online, 9 Nov 2026, approximate):
| Signal | Games |
|---|---|
| The loop is still on top | Steal An Egg 566K, Throw Food For Animals 145K |
| New egg games are stalling | Be Flash For Eggs 1.6K, Golf a Lucky Egg 470, Pull a Dino 290 |
| Breakouts borrow a second audience | Net a Fish (Throw Food loop + fishing) 14K |
| Soccer is all over the top 100 | Illegal Soccer 37K, Turbo Soccer 20K, Realistic Street Soccer 19.5K, Be a Soccer Legend 18K |
| Nobody has combined them | Kick For Animals 7 players, Score For Eggs 2 |

## The map
One small stadium with **one net shared by everyone** (Jacob, 9 Nov 2026). No walking between zones.
- Walk up to the **kick area** and an egg roll spins on your screen (RNG), from your league's egg pool and your Luck.
- Everyone kicks at the same net at the same time. Your egg is only on your screen, so nobody waits for a turn.
- Rare rolls (Legendary and up) appear for the whole server with an announcement, so others see the flex.

## One round (about 20 seconds)
1. Walk up to the kick area with your ball.
2. An egg roll spins on your screen and lands on an egg (league pool + your Luck). The egg hops into the net. The roll is a Bowmasters-style VS screen: you on the left, a vertical reel of eggs on the right that lands on your opponent and shows its rarity (Jacob, 9 Nov 2026).
3. Tap where to aim, then hit a timing ring. Up to 3 tries.
4. Score and the egg cracks open: the hatch reveal shows the animal inside, which joins your stadium and earns cash.
5. Miss and the egg bounces the ball back into you and you ragdoll.
6. Spend cash on Luck and upgrades, train Kick Power, get promoted to the next league.

## Kick Power vs Save Power
Every egg shows a Save Power number.
| Your Kick Power | What happens |
|---|---|
| Far below Save Power | The egg blocks everything (rare eggs need real Kick Power) |
| Around Save Power | Aim matters: find the egg's weak spot |
| Far above Save Power | Ball blasts through, the egg tumbles into the net and cracks open |

## Egg keeper styles (examples)
Each egg keeps goal like the animal inside it would.
| Egg | How it keeps goal | Where to shoot |
|---|---|---|
| Chicken egg | Panics, bounces around at random | Anywhere, with luck |
| Giraffe egg | Tall egg, bounces high | Low |
| Fish egg | Rolls along the goal line | High |
| Octopus egg | Wobbles and covers the corners | The middle |
| Turtle egg | Digs in and won't move | Raw power only |
| Elephant egg | Huge, fills the whole goal | Tiny top-corner gap, or blast through |
| T-Rex egg | Fast hops, short reach up top | The corners |

A style is a few numbers per egg: reach, react, dive speed, dive type (hop, roll, panic, dig in).

## Upgrades
| Upgrade | How you get it | What it does |
|---|---|---|
| Kick Power | Train on the kick wall | Faster shots that beat bigger eggs |
| Kick wall | Cash | More Kick Power per kick (wall, rebound net, ball cannon) |
| Ball / Luck | Cash | Luck: rarer eggs roll at the kick area |
| Boots | Cash | Walk speed, bigger "perfect" timing window |
| Stadium | Cash | More bench slots, extra floors |
| Rebirth ("promotion") | Reset Kick Power and cash | Permanent multipliers, moves you up a league (new egg pool, reskinned stadium) |

## Collecting
You collect the animals that hatch. Each has one number that matters: cash per second.
- Rarity (Jacob, 11 Nov 2026): Common, Uncommon, Rare, Epic, Legendary, Mythic, Exotic, Divine, Celestial, Secret, plus Event (Admin + Hacker). Every animal is set by hand in GameConfig.AnimalRarity: everyday animals Common, dinosaurs Legendary, myths Mythic and up.
- Mutation: Gold, Diamond, Rainbow, Fire (a Gold egg hatches a Gold animal)
- Size: normal, Big, Huge (bigger eggs cover more goal and hatch bigger animals)
- Index: sticker album, reward per finished page

## Leagues (replace walk-to zones)
Each promotion moves you up a league: a new egg pool and the stadium reskins to match.
Backyard, School Field, Zoo Stadium, Safari Arena, Arctic Dome, Jungle, Ocean, Dino Coliseum, Mythic, Moon.

## UI style
A mix of a normal Roblox simulator and FIFA (Jacob, 9 Nov 2026). Not everything is FIFA-themed.
- **FIFA-style** (Ultimate Team-like player cards): the index, the hatch reveal card, and the rare-roll announcement. Each animal gets a card with a rarity color, a rating, Save Power and cash per second.
- **Normal Roblox sim style**: HUD, shop, upgrades, Luck, kick wall.
- Use our own names and art; no FIFA/EA names or logos in the game. Jacob builds all UI.

Events about every 30 minutes: **Cup Final** (giant boss egg, whole server shoots, everyone who scores gets a hatch), **Golden Goal** (double mutation chance), **Rain** (eggs slip).

## First build
One stadium with the shared net, the Backyard league (five eggs), the egg roll at the kick area, the kick (aim tap + timing ring, 3 tries), egg dive/save, the hatch reveal, the bench with cash per second, the kick wall, one Luck upgrade.

## How we work
- Jacob (`jderosa10-code`) works with **jacob-claude**; pigeon (`pigeonlover1223-png`) works with **pigeon-claude**.
- **Both Claudes send updates**: after every session each adds an entry to `UPDATES.md` and pushes, which posts to Discord #me-and-braden-game-making. Rules in `CLAUDE.md`.
- Tasks are GitHub Issues (`task`); Claude-to-Claude messages are Issues (`claude-chat` + `to:jacob` / `to:pigeon`).

## Decisions
- 9 Nov 2026: No stealing between players.
- 9 Nov 2026: ~~We build our own animal models; the downloaded pack is study only.~~ **Updated 9 Nov 2026 (Jacob): we use the animal pack already in the Studio place.**
- 9 Nov 2026: Score on Animals replaces Habitat RNG.
- 9 Nov 2026: Halloween animals are parked in `ServerStorage.HalloweenArchive` until next October.
- **9 Nov 2026 (Jacob): eggs are the goalkeepers, not animals. Scoring hatches the egg and the animal inside joins your stadium.**
- **9 Nov 2026 (Jacob): one small map with one shared net; walking up to the kick area rolls an egg (RNG + Luck). Leagues via promotion replace walk-to zones.**
- **9 Nov 2026 (Jacob): UI is a mix of Roblox sim and FIFA; FIFA-style cards for the index and hatch reveal.**

## Open questions
- [ ] Does this run alongside Home Run to the Moon, or replace it?
- [ ] Where do your animals live on the small map: a bench/plot per player around the pitch, or in the stands?
- [ ] After three misses, does the egg leave, or a short wait?
- [ ] Aim control: tap + timing ring, or swipe?
- [ ] With stealing gone, what do players do together besides the Cup Final?
- [ ] How many leagues and eggs at launch?
- [ ] Which Robux products to sell?
- [ ] Is "Score on Animals" still the name now that eggs are the keepers?
- [ ] What's inside an egg: always that egg's own animal (each egg is themed to one animal), or a random animal from the zone?
