# Disco Kickoff event (pigeon-claude, 14 Nov 2026)

Every 12 to 20 minutes (never at night or during 2X EGGS), a giant mirror disco ball drops out of the sky over the field
for 2 minutes. While it's down, 35% of eggs that didn't roll another mutation come out **Groovy**. A Groovy animal wears
a black afro (with a red sweatband and a pick) plus round pink disco glasses with mini disco balls. Groovy is
event-only (`Chance = 0`), with Income x3 and Need x1.25.

## Live places in Studio
| What | Where |
|---|---|
| Event timer | `ServerScriptService.DiscoEvent` (this folder). Admin: `ServerStorage.DiscoStart:Fire(seconds)`; Studio: workspace attribute `TestDisco = true` |
| Show (ball drop, beams, music, tint) | `StarterPlayerScripts.DiscoClient` |
| Groovy roll | `ServerScriptService.EggInventory` (`groovy()` before `muts[player] = mut`) |
| Mutation | `ReplicatedStorage.GameConfig` Mutations `Groovy`; HUD colour in `HUDClient` |
| Music pause | `StarterPlayerScripts.MusicPlayer` `muted()` is true while `DiscoActive` |
| Cosmetic models (Blender: `roblox_pets/cosmetics/disco_kit.py`, `disco_ball.py`) | `ReplicatedStorage.Assets.EventCosmetics.Disco` (Afro, ShadesL, ShadesR, Bridge, DiscoBall) |
| Groovy animals (213) | `ReplicatedStorage.Assets.Animals.GroovyAnimals` |
| Groovy eggs (197) | `ReplicatedStorage.Assets.Eggs.GroovyEggs` + per-egg afro in `Assets.EggCosmetics.GroovyAfro`, worn through `GameConfig G.addGroovyAfro` (called from `G.addMutationVFX` for `Groovy`, refits when the egg is resized) |

## Fitting tools (ServerStorage, Studio only)
- `DiscoFit` measures each animal's head and eyes and attaches the afro and glasses (RigidConstraint to the head or eye bone, so they follow the animations).
- `DiscoFit.Overrides` holds the hand fits: every animal was checked close-up and about 120 have hand-picked eyes, afro spots or sizes. Positions are in base-animal pivot space.
- `DiscoEyePicker`: `P.pick(model, cam, look, u, v)` casts a screenshot pixel onto the mesh to get a pivot-space point.
- `DiscoBuild`: `B.one(name)` rebuilds one Groovy animal; `B.set(name, "{...}")` writes an override and rebuilds; `B.look(name, dir, dist, slot)` stages a close-up.
- `DiscoEggFit`: `E.fit(egg)` refits one egg's afro (shell top and width from the mesh; unreadable meshes use the standard egg shell).

**A new animal or egg** needs its Groovy version: run `require(ServerStorage.DiscoBuild:Clone()).one("Name")` and
`require(ServerStorage.DiscoEggFit:Clone()).fit(Assets.Eggs.GroovyEggs.Name)` (after copying the base egg into
GroovyEggs), then look at it up close.
