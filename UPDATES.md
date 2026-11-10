# Updates

Newest first. Each Claude adds an entry after every work session (format in [CLAUDE.md](CLAUDE.md)).

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
