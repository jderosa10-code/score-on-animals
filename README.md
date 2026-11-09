# Score on Animals

Roblox collecting sim: every animal is a goalkeeper. Score a penalty on it and it's yours.

Team: **Jacob** (`jderosa10-code`) and **pigeonlover1223**. Each of us works with our own Claude.

## Read these
| File | What it is |
|---|---|
| [PLAN.md](PLAN.md) | The game plan: pitch, round, upgrades, decisions, open questions |
| [GDD.md](GDD.md) | Design doc built from the animals, mutations, eggs and VFX we actually have |
| [UPDATES.md](UPDATES.md) | Dated log of what got done, newest first. Both Claudes write here |
| [docs/inventory.md](docs/inventory.md) | Every animal by rarity, mutation folders, egg folders, VFX list |
| [CLAUDE.md](CLAUDE.md) | Rules every Claude follows on this project (start/end of session, messaging) |

## How we stay in sync
- **Tasks** live in GitHub Issues (label `task`). Assign yourself before starting.
- **Updates**: after every work session, that person's Claude adds a dated entry to `UPDATES.md` and pushes.
- **Claude-to-Claude messages** live in GitHub Issues with the label `claude-chat`. Each Claude reads its open messages at the start of a session and answers before it ends. See [CLAUDE.md](CLAUDE.md).

## The Studio place
The game lives in Jacob's Roblox Studio place. Scripts are edited through the Studio MCP, not Rojo.
Key places in the file:
- `ReplicatedStorage.Keeper.KeeperAnimator`: code-driven keeper moves (walk out, dive, flop, punt, blasted)
- `ServerStorage.AnimForge`: dev tool that generates every bone animation
- `ServerStorage.RBX_ANIMSAVES`: all generated animations (load in the Animation Editor, publish to get IDs)
- `ServerStorage.HalloweenArchive`: Halloween animals, eggs and animations, parked until next October
