# Updates

Newest first. Each Claude adds an entry after every work session (format in [CLAUDE.md](CLAUDE.md)).

## 2026-11-09 20:20 CT · pigeon-claude
**Done:** Pigeon chose the game's real textures: NEW animals now keep the restyled shape (bigger head + eyes, shorter legs, wider, blush) but the body AND eyes wear the original `SurfaceAppearance` from the matching `BaseAnimals` model (smile and patterns are back, crisp). The baked recolour/gradient is dropped. Updated preview in `Workspace.RestyleShowcase`; FBX in `models/restyle/fbx/` now use the original UVs (plain material, SurfaceAppearance goes on after Import 3D).
**Next:** pigeon imports the 5 FBX with Import 3D; then they become real assets everyone can see.
**Blockers / questions:** none.

## 2026-11-09 20:12 CT · pigeon-claude
**Done:** Pigeon: the game's original eyes look much better, so the NEW animals now keep their original eye pieces (bigger, seated in the head) and wear the real `SurfaceAppearance` from the matching `BaseAnimals` model. Bead eyes and shine dots removed. FBX of the 5 NEW animals for Import 3D: `models/restyle/fbx/` (body + baked texture, eyes on original UVs, blush).
**Next:** import the FBX in Studio so the NEW animals are real assets (the runtime-built ones show as blue boxes for anyone else in Team Create).
**Blockers / questions:** NEW body textures come from the 64px OBJ export and look softer than the real `SurfaceAppearance` (hedgehog face, giraffe pattern). Could put the real textures on the bodies too.

## 2026-11-09 20:08 CT · pigeon-claude
**Done:** Restyle showcase in pigeon's place, in front of the spawn: `Workspace.RestyleShowcase` = clones of the real `BaseAnimals` (Corgi, Toad, Hedgehog, Giraffe2, PolarBear2) as OLD + slots where NEW is built. NEW is rebuilt on Play by `StarterPlayerScripts.RestyleShowcaseClient` from `ReplicatedStorage.RestyleData` via `ReplicatedStorage.RestyleBuilder` (Editable meshes, since CreateAssetAsync is `not available yet`). Sent #13: restyle is not on hold (pigeon).
**Next:** pigeon checks it in Play. Not verified in Play yet (the test session ended before it built).
**Blockers / questions:** the restyle came from the low-detail OBJ texture, so NEW lost face details (e.g. Corgi's smile) that the real SurfaceAppearance has. The Studio-script route on the real models would keep them.

## 2026-11-09 19:57 CT · pigeon-claude
**Done:** Restyle v2 after pigeon's feedback (eyes looked like they were floating, dog's blush/eyes weird): eyes are now re-seated into the head, every animal gets the same black bead eyes + shine, blush sits on the cheek front, toad's front legs fixed (head-finder picked a leg). New check: every piece must touch the body; all 5 pass. Shown in pigeon's Studio at `Workspace.RestyleTest` (preview only). Scripts + renders: `models/restyle/`.
**Next:** pigeon approves the look, then the rest of the animals.
**Blockers / questions:** jacob: rigs question still open (Studio-script restyle vs re-rig).

## 2026-11-09 19:34 CT · pigeon-claude
**Done:** Put the 5 restyle test animals (OLD + NEW) into pigeon's Studio place to compare in Roblox: `Workspace.RestyleTest` (built as EditableMesh MeshParts, preview only, they won't save with the place).
**Next:** pigeon decides on the look; then the rest of the animals.
**Blockers / questions:** jacob: still need your call on the rigs (Studio-script restyle vs re-rig), see my 19:28 entry.

## 2026-11-09 19:45 CT · jacob-claude
**Done:** Read pigeon-claude's restyle test (db3df51) and showed Jacob the renders. Jacob's answer: hold off on the restyle for now. Sent to pigeon as a [to:pigeon] issue.
**Next:** Egg moves in `ReplicatedStorage.Keeper.KeeperAnimator` (hop, squash and stretch, roll, crack + hatch) and the egg roll at the kick area.
**Blockers / questions:** None.

## 2026-11-09 19:28 CT · pigeon-claude
**Done:**
- Pigeon's request: restyle the animal pack so it looks different from Fake an Egg. Test on 5 (Corgi, Toad, Hedgehog, Giraffe, Polar Bear) in Blender: bigger head, bigger eyes with a shine dot, pink blush cheeks, shorter legs, slightly wider, brighter colours, soft dark-to-light gradient baked into one 256px texture per animal. Same script runs on any animal.
- OLD vs NEW renders + scripts: `models/restyle/` (`five_compare.png`).
- Read and closed #8–#11, passed them to pigeon.
**Next:** pigeon reviews the look; if approved, run it on the rest.
**Blockers / questions:** jacob: the test used the flattened OBJ export, not your rigged Studio models. To keep your rigs, the same changes could run as a Studio script on the real parts (scale head/eyes, shorten legs, add blush parts, recolour). Which way do you want it?

## 2026-11-09 19:20 CT · jacob-claude
**Done:**
- Jacob decided: **one small map with one shared net**. Walking into the kick area rolls an egg on your screen (RNG + Luck); everyone kicks at the same net, rare rolls show to the whole server. **Leagues via promotion replace walk-to zones.**
- Jacob decided: **UI is a mix of Roblox sim and FIFA**: FIFA-style cards for the index, hatch reveal and rare-roll announcement; normal sim UI elsewhere.
- Updated PLAN.md (map, round, upgrades, leagues, UI style, decisions, open questions) and GDD (sections 3, 6, 8, 9, new 10 UI direction).
**Next:** egg moves + egg roll at the kick area in Studio.
**Blockers / questions:** open: where animals live on the small map (bench/plot per player, or stands)? Does an egg always hatch its own animal?

## 2026-11-09 19:12 CT · pigeon-claude
**Done:** Test update from pigeon's side, to check pushes show up in Discord. Read jacob-claude's 19:10 entry (eggs are now the goalkeepers) and passed it to pigeon.
**Next:** pigeon answers the open question: does an egg always hatch its own animal, or a random one from the zone?
**Blockers / questions:** none.

## 2026-11-09 19:10 CT · jacob-claude
**Done:**
- **Big change (Jacob's decision): eggs are the goalkeepers, not animals.** Score on an egg, it hatches, the animal joins your stadium.
- Rewrote PLAN.md (pitch, round, egg keeper styles, events, first build, decisions, open questions) and GDD sections 3, 4, 6, 7, 8, 9. README pitch updated.
- Closed #6 (Mystery Egg question) since eggs are now the core; #4 is now "5 eggs".
**Next:** add egg moves to `ReplicatedStorage.Keeper.KeeperAnimator` (hop, squash and stretch, roll, dig in, crack + hatch).
**Blockers / questions:** open: does an egg always hatch its own animal, or a random one from the zone?

## 2026-11-09 18:55 CT · jacob-claude
**Done:**
- Made "both Claudes send updates" an explicit rule: new section in CLAUDE.md + "How we work" in PLAN.md (Jacob's request).
- Read pigeon-claude's answers in #7 and passed them to Jacob.
**Next:** Jacob and pigeon decide the open questions (#6 eggs, PLAN open questions); then the kick (#1).
**Blockers / questions:** none

## 2026-11-09 18:30 CT · pigeon-claude
**Done:** Cleared the animal pack risk in GDD section 10. Pigeon confirmed Fake an Egg is our own game, so the pack is fine to ship. Ignore that flag in my #7 reply.
**Next:** pigeon answers the PLAN.md open questions with Jacob.
**Blockers / questions:** none.

## 2026-11-09 18:22 CT · jacob-claude
**Done:**
- Repo live with labels (task, claude-chat, to:jacob, to:pigeon, decision) and starter tasks #1-#6.
- Welcome message for pigeon-claude in #7.
- Discord: repo pushes, issues and comments now post to #me-and-braden-game-making.
**Next:** Jacob adds pigeonlover1223 as a collaborator; then back to the kick (#1).
**Blockers / questions:** none

## 2026-11-09 18:20 CT · pigeon-claude
**Done:**
- Joined the repo, read PLAN/GDD/inventory, saved the sync skill on pigeon's PC.
- Answered and closed #7: suggestions on egg keepers (random Mystery Egg walk-out + Egg Rush event, egg rolls better than a normal walk-out) and every open question in PLAN.md. Suggestions only, no decisions changed.
- Fixed pigeon's GitHub login to `pigeonlover1223-png` in README.md, CLAUDE.md and the sync skill.
**Next:** pigeon reviews the suggestions in #7 and answers the open questions with Jacob.
**Blockers / questions:** the animal pack came from another game's files (GDD section 10); sort out whether we can ship it before any public release.

## 2026-11-09 18:00 CT · jacob-claude
**Done:**
- Set up this repo: PLAN, GDD (built from our real animals/mutations/eggs/VFX), inventory, Claude rules and messaging.
- Score on Animals replaces Habitat RNG (Jacob's decision).
**Next:** Jacob tests the keeper demo; then the kick (aim tap + timing ring) and the bench.
**Blockers / questions:** pigeon: please read GDD section 6 (eggs as keepers) and the open questions in PLAN.

## 2026-11-09 17:40 CT · jacob-claude
**Done:**
- Keeper code: `ReplicatedStorage.Keeper.KeeperAnimator` (walk out, ready, dive jump/slide/panic/shell, flop, get up, celebrate, punt, sulk, blasted into the net). Each keeper is 4 numbers: reach, react, diveSpeed, diveType.
- Keeper leg animations for all 155 walkers: Run, Ready, Dive, Kick, Tuck, Shell, Flail.
- Test goal + 5-keeper demo: `Workspace.KeeperTest`, `ServerScriptService.KeeperDemo`. Watch with **Run (F8)**, not Play.
**Next:** publish animations so they work in Play and live.

## 2026-11-09 17:20 CT · jacob-claude
**Done:**
- Fixed the leg "snap" in every walk (foot planting now fades in and is smoothed).
- Wings flap on 42 winged animals (Fly animation + flutter in Idle/Walk). Owl, Sphinx and Chimera have no wing bones.
- Octopus, squid, jellyfish and Kraken tentacles now curl.
- Halloween animals (49) + their eggs, mutations and animations moved to `ServerStorage.HalloweenArchive`.

## 2026-11-09 17:00 CT · jacob-claude
**Done:**
- Generated Idle + movement animations for every animal (`ServerStorage.AnimForge` tool, saved in `ServerStorage.RBX_ANIMSAVES`). Feet stay on the ground.
- Showcase of every animal looping its animations: `Workspace.AnimShowcase` (watch with Run, F8).
- Stripped all old scripts/GUIs from the imported pack; kept animals, eggs and VFX (`ReplicatedStorage.Assets`).
