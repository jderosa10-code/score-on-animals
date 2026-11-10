# Updates

Newest first. Each Claude adds an entry after every work session (format in [CLAUDE.md](CLAUDE.md)).

## 2026-11-10 01:30 CT · jacob-claude
**Done:** R6 RunUp rebuilt (RigDirectors one crossed the legs) and Kick exaggerated, both in `ServerStorage.RBX_ANIMSAVES.KickerRigR6`. Demo (`ReplicatedStorage.DevDemo.PenaltyDemoRunner`): spot 23.5 studs out, kicker backs up ~12 studs, ball 75 studs/s, kick camera further right and tracking the ball. VFX from `ReplicatedStorage.Assets.VFX.Effects`: foot dust, strike flash (Diamond), ball trail, save impact (Gold), egg landing dust, goal Confetti + Complete. Net flex: real vertex bulge via EditableMesh on the `Workspace.Goal` net parts (nets now Hull collision + `Net` attribute), with a simple panel push fallback. `EggKeeper.onLand` hook added.
**Next:** Ragdoll on a miss; legs/wings on eggs.
**Blockers / questions:** Real net bulge needs Game Settings > Security > Allow Mesh / Image APIs (Jacob).

## 2026-11-10 00:40 CT · jacob-claude
**Done:** Kicker is now R6 (Jacob's call). `ServerStorage.KickerRigR6` + anims in `ServerStorage.RBX_ANIMSAVES.KickerRigR6`: BackStep, Stance, RunUp (from RigDirectors) and Kick (made by jacob-claude, "Contact" marker). RigDirectors' pasted Luau uses character-space angles, so poses were converted into R6 joint space and feet grounded. Demo: spot moved to 17.5 studs out, kicker backs up ~10 studs, 1.4 s run-up. Uses your character if it's R6, otherwise an R6 stand-in.
**Next:** Ragdoll on a miss; legs/wings on eggs.
**Blockers / questions:** Studio Game Settings > Avatar must be set to R6 for players to be the kicker.

## 2026-11-09 22:17 CT · pigeon-claude
**Done:** Pigeon: do ALL the animals. Improved `restyle.py` (eye size relative to the animal, flat/blocky eyes + pupils, no eyes on wings, blocky leg+paw shortening, gentler settings for blocky A### models, chunky-body fallback for painted-eye fish/snakes). Restyled the remaining 145 and reviewed every one (`models/restyle/sheets_all/`). Two files: `models/restyle/fbx/Restyle_NEW_all_A.fbx` (73 + faceted Giraffe2/PolarBear2) and `Restyle_NEW_all_B.fbx` (72). OLD clones + slots for all of them placed in `Workspace.RestyleShowcase`. HoneyBadger and Tapir_V2 reuse the Badger/Tapir_V1 NEW meshes with their own texture. Thunderbird will reuse Roc.
**Next:** pigeon imports A and B; I place them (210 animals total).
**Blockers / questions:** NEW models are static (no bones).

## 2026-11-09 23:59 CT · jacob-claude
**Done:** New kicker animations in `ServerStorage.RBX_ANIMSAVES.KickerRig`: BackStep (head down watching feet), Stance (tall, feet apart, breathing), RunUp (leaning run, arms pumping), Kick (rebuilt, head down through contact, "Contact" marker), Celebrate (arms out). All auto-grounded so feet don't sink or float. Demo: run-up comes in at an angle and squares up for the plant; hold camera further back and right. Hatch reveal removed from the demo for now (beaten egg hops off).
**Next:** Tune from Jacob's feedback; legs/wings on eggs; ragdoll on a miss.
**Blockers / questions:** Kicker anims need publishing before the real game.

## 2026-11-09 23:40 CT · jacob-claude
**Done:** `ReplicatedStorage.DevDemo.PenaltyDemoRunner` camera pass: thinner letterbox (7%), shrinks to 2.5% while waiting for the click, 9% after; camera further back and over the right shoulder; field of view follows the moment (tight 40 while holding, 60 on the run-up, 44 in slow-mo, opens up after).
**Next:** Legs/wings on eggs; ragdoll on a miss.
**Blockers / questions:** None.

## 2026-11-09 22:00 CT · pigeon-claude
**Done:** Batch 3 imported and placed: 26 more OLD/NEW pairs in `Workspace.RestyleShowcase` (rows from Z -108 back), real `SurfaceAppearance` + Studs. 61 restyled animals in total now.
**Next:** pigeon decides whether to keep going on the rest; the skipped blocky (A###) and no-eyes-found animals would need a different method.
**Blockers / questions:** NEW models are static (no bones), so no animations yet.

## 2026-11-09 23:25 CT · jacob-claude
**Done:** `ReplicatedStorage.DevDemo.PenaltyDemoRunner`: in Play your own character is the kicker (no second kicker), black letterbox bars before the back-up, hold at the top of the run-up until click/tap, over-the-shoulder camera that follows you then the ball. Other avatar animations are blocked while kicking. Run (F8) still auto-kicks with a stand-in. Studs on `Workspace.Goal` frame and `Workspace.SoccerBall` made bigger and easier to see.
**Next:** Legs/wings on eggs; ragdoll on a miss.
**Blockers / questions:** Letterbox bars are a temporary demo ScreenGui (`PenaltyBars`); Jacob builds the real UI.

## 2026-11-09 23:05 CT · jacob-claude
**Done:** Penalty demo logic moved to `ReplicatedStorage.DevDemo.PenaltyDemoRunner`; runs on the client in Play (F5) and on the server in Run (F8). Disabled `ServerScriptService.AnimPreview` and `ServerScriptService.KeeperDemo` so the showcases don't play on start. Stud texture (same as eggs, rbxassetid://6927295847) on the goal frame parts in `Workspace.Goal` and on `Workspace.SoccerBall`.
**Next:** Legs/wings on eggs; ragdoll on a miss.
**Blockers / questions:** None.

## 2026-11-09 21:50 CT · pigeon-claude
**Done:** Fixes (Sloth, Aardvark, Bunny, Corgi) swapped into `Workspace.RestyleShowcase`. Batch 3: 26 more restyled (Tapir_V1, Porcupine, Platypus, Binturong, Jackalope, Raiju, Chupacabra, CattleDog, BichonFrise, CavalierKingCharlesSpaniel, Iguana, KomodoDragon, Kappa, Toucan, Duck, Kookaburra, Shoebill, Gecko, Newt, Chameleon, Raven2, Ladybug, Beetle, Isopod, Qilin, YiQi): `models/restyle/fbx/Restyle_NEW_batch3.fbx`; OLD clones + slots already placed in rows behind. Pigeon left the choice to me, so skipped: the blocky A### models (Lion, Tiger, Zebra, Horse, Wolf, Bear, Elephant, Koala, Goat, Cow; restyle makes them look rigid), Minotaur and Pegasus (rigid block bodies), Griffin and Pteranodon (an eye landed on a wing), and ones with no eyes found (Bunyip, Bison, Tortoise, Cassowary, Emu, Puffin, Secretary, Albatross, Flamingo, Dimetrodon, Sphinx, Hydra, Wyvern, Sabertooth, Manticore).
**Next:** pigeon imports batch 3; I place them.
**Blockers / questions:** none.

## 2026-11-09 22:55 CT · jacob-claude
**Done:** Penalty demo now runs on the client (smooth, like the real game where your egg is only on your screen): `StarterPlayer.StarterPlayerScripts.PenaltyDemoClient`; `ServerScriptService.PenaltyDemo` only copies assets to `ReplicatedStorage.PenaltyDemoAssets` (Studio only). Kicker backs up to the left of the ball after the egg is set, pauses, eased run-up blending into the kick; TV camera (C toggles). Egg idle is grounded (breathing/weight shift, no bouncing); saves use real contact and parry the ball wide; impact squash no longer fights the dive.
**Next:** Legs/wings on eggs (needs rebuilt eggs); ragdoll on a miss.
**Blockers / questions:** Test with Play (F5) now, not Run.

## 2026-11-09 22:20 CT · jacob-claude
**Done:** Test pitch moved to x = -400 (`Workspace.Goal`, `Workspace.SoccerBall`). `ReplicatedStorage.Keeper.EggKeeper` v2: eggs face the way they hop and turn back to the kicker; dives are crouch, fast takeoff, hang, controlled fall (no more random panic, Chicken now does one feint); eggs stay on the ground when lying down; `EggKeeper.timeScale` for slow motion. `ServerScriptService.PenaltyDemo`: kicker pause over the ball (2.5 s), short run-up, slow-mo on the shot.
**Next:** Legs/wings on eggs (they are baked into one mesh with no bones, so they need rebuilding to move); ragdoll on a miss.
**Blockers / questions:** Egg meshes can't be read or edited from Studio (no asset permission).

## 2026-11-09 21:40 CT · pigeon-claude
**Done:** Leg fix (pigeon: sloth's legs broken). Cause: front legs right next to the head were scaled up with the head (sloth, aardvark). Now ground-touching pieces never count as head, and small claws/feet ride up with their leg instead of being squashed. Re-ran all 35: only sloth and aardvark changed. One file with the fixes (Sloth, Aardvark, Bunny, Corgi redo): `models/restyle/fbx/Restyle_NEW_fixes.fbx` (replaces `Restyle_NEW_corgi.fbx`).
**Next:** pigeon imports it; I swap the 4 in.
**Blockers / questions:** none.

## 2026-11-09 21:36 CT · pigeon-claude
**Done:** Restyle batch 2: 30 more animals (GuineaPig, Cat, Bunny, Aardvark, Akita, Armadillo, Badger, Beaver, BostonTerrier, Caracal, ChowChow, Dingo, EnglishBulldog, FennecFox, Fossa, GreatDane, Hippopotamus, Hyena, Jackal, Lemur, Meerkat, Okapi, Papillon, Quokka, Serval, ShibaInu, Sloth, Tanuki, WhiteRhino, Yak) imported and placed as OLD/NEW pairs in `Workspace.RestyleShowcase` (3 rows behind the first 5), real `SurfaceAppearance` + Studs. Skipped for now: Chicken, Dog, RedPanda, Moose, WoollyMammoth, Anteater (eyes not detected), Capybara, Hamster. Corgi redo with gentler settings (pigeon: body shape weird, eyes too big): `models/restyle/fbx/Restyle_NEW_corgi.fbx`.
**Next:** pigeon imports the corgi file; I swap it in.
**Blockers / questions:** none.

## 2026-11-09 21:40 CT · jacob-claude
**Done:** Egg keeper moves in code: `ReplicatedStorage.Keeper.EggKeeper` (enter hop-in, idle squash hops, track, dives: hop/roll/panic/dig, bounce, getUp, celebrate, tumble, hatch with shell bits + animal pop-out). Player kick anim `ServerStorage.RBX_ANIMSAVES.KickerRig.Kick` (R15, "Contact" marker) on rig `ServerStorage.KickerRig`. Studio demo `ServerScriptService.PenaltyDemo` on `Workspace.Goal` (rotated so the mouth faces spawn): save then goal + hatch for Chicken, Giraffe, Turtle, Elephant, TRex, Blobfish. Run with F8.
**Next:** Ragdoll when the ball bounces back on a miss; tune moves from Jacob's feedback.
**Blockers / questions:** Kick anim must be published by Jacob before it works in Play.

## 2026-11-09 21:07 CT · pigeon-claude
**Done:** Pigeon: remove the blush. Deleted all blush parts from `Workspace.RestyleShowcase`; `restyle.py` now has `ADD_BLUSH = False`. NEW = bigger head + seated game eyes, shorter legs, wider, crisp edges, original textures.
**Next:** pigeon and Jacob judge the look.
**Blockers / questions:** none.

## 2026-11-09 21:03 CT · pigeon-claude
**Done:** Blush v5 imported and swapped into `Workspace.RestyleShowcase`: below each eye with a gap, on the front of the cheek, half-sunk, same Plastic material and the original `Studs` textures as the body. Checked all 5 up close in Studio.
**Next:** pigeon and Jacob judge the look; if approved, run the restyle on the other animals.
**Blockers / questions:** NEW models are static (no bones), so no animations yet.

## 2026-11-09 21:01 CT · pigeon-claude
**Done:** Blush v5 (pigeon: it overlapped the corgi's eye and floated off the frog's head). Now: always a gap below the eye, only on front-facing cheek spots (never the side edge), a low patch half-sunk into the skin. New `models/restyle/fbx/Restyle_NEW_all.fbx`.
**Next:** pigeon re-imports it; I swap it into `Workspace.RestyleShowcase` and give the blush the same Studs texture + material as the body.
**Blockers / questions:** none.

## 2026-11-09 20:56 CT · pigeon-claude
**Done:** Pigeon imported `Restyle_NEW_all.fbx`. Swapped into `Workspace.RestyleShowcase` as `<Name> NEW` (Corgi, Toad, Hedgehog, Giraffe, PolarBear): scaled from cm, stood up, facing the spawn, real `SurfaceAppearance` on body + eyes, the original `Studs` textures copied onto the body, pink dome blush. Previous NEW versions and the leftover import model deleted.
**Next:** pigeon and Jacob judge the look; if approved, run the same restyle on the rest.
**Blockers / questions:** NEW models are static (no bones), so no animations yet.

## 2026-11-09 20:55 CT · jacob-claude
**Done:** Built a new goal (frame + square-hole netting, soft gray gradient) and a soccer ball in Blender with Jacob. Imported and sized in Studio: `Workspace.Goal` (22.6 wide x 11.5 tall, same width as KeeperTest goal, opening faces -Z) and `Workspace.SoccerBall` (1.8 studs, same as KeeperTest ball).
**Next:** Egg keeper moves in `ReplicatedStorage.Keeper.KeeperAnimator`; egg roll at the kick area.
**Blockers / questions:** Only the soccer ball for now (Jacob dropped the other ball ideas).

## 2026-11-09 20:50 CT · pigeon-claude
**Done:** Pigeon's feedback on the imported restyle: blush looked weird and out of place on some animals, edges too soft. Blush is now a small rounded dome seated into the cheek like the eyes (smooth-shaded, partly sunk), on the most front-facing cheek spot under the eye, mirrored. Bodies are flat-shaded (crisp facets like the originals). All 5 in ONE file: `models/restyle/fbx/Restyle_NEW_all.fbx`.
**Next:** pigeon imports that one file; then I swap it into `Workspace.RestyleShowcase` (scale, stand up, real `SurfaceAppearance`, Studs textures).
**Blockers / questions:** none.

## 2026-11-09 20:45 CT · pigeon-claude
**Done:** Pigeon imported the 5 restyle FBX (Import 3D), so the NEW animals are now real uploaded meshes everyone can see. Set up in `Workspace.RestyleShowcase` (in front of the spawn): `<Name> OLD` (clones of `BaseAnimals`) next to `<Name> NEW` (imported; scaled 0.01 from cm, stood up and turned to face the spawn; body + eyes wear the original `SurfaceAppearance`; pink blush parts). Pivots are the bottom centre. Removed the temporary runtime builder: `ReplicatedStorage.RestyleBuilder`, `ReplicatedStorage.RestyleData`, `StarterPlayerScripts.RestyleShowcaseClient`.
**Next:** pigeon and Jacob decide on the look; if yes, the same restyle for the other animals.
**Blockers / questions:** the NEW models are static (no bones), so they don't play the rig animations yet.

## 2026-11-09 20:40 CT · pigeon-claude
**Done:** Blush fix (pigeon: it worked on one side only and missed the cheeks, e.g. hedgehog's landed on its spines). Blush now only goes on the HEAD piece, under and slightly in front of the eye, then mirrored so both cheeks match; it sits on the skin, not half-sunk. FBX in `models/restyle/fbx/` updated.
**Next:** import the 5 FBX with Import 3D so the NEW animals are real assets (script-built ones show as boxes for anyone else).
**Blockers / questions:** none.

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
