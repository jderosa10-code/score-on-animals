# Score on Animals: Game Plan

Every egg is a goalkeeper: score a penalty on it, it hatches, and the animal inside is yours.

## How to play
- Shoot a penalty at an egg goalkeeper
- Score and the egg cracks open: the animal inside joins your stadium
- Animals earn cash in your stadium
- Train on the kick wall for Kick Power
- Buy better balls so rarer eggs hop out
- Reach farther stadiums with bigger, rarer eggs

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

## One round (about 20 seconds)
1. Put your ball on a penalty spot in a stadium.
2. An egg hops out of the tunnel and takes the goal. Its rarity is rolled from the zone and your ball's Luck.
3. Tap where to aim, then hit a timing ring. Up to 3 tries.
4. Score and the egg cracks open: the hatch reveal shows the animal inside, which joins your stadium and earns cash.
5. Miss and the egg bounces the ball back into you and you ragdoll.
6. Spend cash on a better ball, train Kick Power, walk to the next stadium.

## Kick Power vs Save Power
Every egg shows a Save Power number.
| Your Kick Power | What happens |
|---|---|
| Far below Save Power | The egg blocks everything (locks later stadiums) |
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
| Ball | Cash | Luck: rarer eggs hop out |
| Boots | Cash | Walk speed, bigger "perfect" timing window |
| Stadium | Cash | More bench slots, extra floors |
| Rebirth ("promotion") | Reset Kick Power and cash | Permanent multipliers, a new league of zones |

## Collecting
You collect the animals that hatch. Each has one number that matters: cash per second.
- Rarity: Common, Rare, Epic, Legendary, Mythic, Secret
- Mutation: Gold, Diamond, Rainbow, Fire (a Gold egg hatches a Gold animal)
- Size: normal, Big, Huge (bigger eggs cover more goal and hatch bigger animals)
- Index: sticker album, reward per finished page

## Zones
Backyard, School Field, Zoo Stadium, Safari Arena, Arctic Dome, Jungle, Ocean, Dino Coliseum, Mythic, Moon.

Events about every 30 minutes: **Cup Final** (giant boss egg, whole server shoots, everyone who scores gets a hatch), **Golden Goal** (double mutation chance), **Rain** (eggs slip).

## First build
One zone (Backyard), five eggs, the kick (aim tap + timing ring, 3 tries), egg hop-out/dive/save, the hatch reveal, the bench with cash per second, the kick wall, one ball upgrade.

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

## Open questions
- [ ] Does this run alongside Home Run to the Moon, or replace it?
- [ ] After a hatch, does the animal run to your stadium, or go straight to the bench?
- [ ] After three misses, does the egg leave, or a short wait?
- [ ] Aim control: tap + timing ring, or swipe?
- [ ] With stealing gone, what do players do together besides the Cup Final?
- [ ] How many zones and eggs at launch?
- [ ] Which Robux products to sell?
- [ ] Is "Score on Animals" still the name now that eggs are the keepers?
- [ ] What's inside an egg: always that egg's own animal (each egg is themed to one animal), or a random animal from the zone?
