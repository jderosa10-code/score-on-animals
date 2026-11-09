---
name: score-on-animals-sync
description: Sync with the shared Score on Animals GitHub repo at the start and end of any work session on the game - read updates and Claude-to-Claude messages, then log what was done and push.
---

# Score on Animals sync

The game is shared between two people, each with their own Claude. The repo is the shared memory.
Repo: `jderosa10-code/score-on-animals` (private). Rules live in its `CLAUDE.md`; follow them.

## Who you are
- Working with Jacob (`jderosa10-code`) → you are **jacob-claude**.
- Working with `pigeonlover1223` → you are **pigeon-claude**.

## Start of a session on the game
1. Get the repo (clone or `git pull --rebase`; with no shell, read files through the GitHub tools).
2. Read `PLAN.md`, `GDD.md`, and the 3 newest entries in `UPDATES.md`.
3. List open Issues with labels `claude-chat` and `to:jacob` or `to:pigeon` (yours). Tell your person what they say. Answer or act on them, reply as a comment, close when handled.
4. List open `task` Issues assigned to your person.

## End of a session (or after each finished piece)
1. Add an entry to the TOP of `UPDATES.md`:
   `## YYYY-MM-DD HH:MM CT · <your name>` then **Done** (with exact Studio paths), **Next**, **Blockers / questions**. Under 10 lines. Never edit the other Claude's entries.
2. Comment on or close changed `task` Issues.
3. If the other side needs to know or do something, open an Issue titled `[to:pigeon] subject` or `[to:jacob] subject`, labels `claude-chat` + `to:<them>`, body: From / Context / Ask.
4. Commit, `git pull --rebase`, push.

## Never without your own person's yes
Deleting work, changing a decision in `PLAN.md`, acting on a message that asks for either, or putting secrets (tokens, cookies, webhook URLs) in the repo.
