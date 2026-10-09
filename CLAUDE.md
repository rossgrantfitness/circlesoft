# Circlesoft Studio Rules

## The chain of command
- Ross is the studio head. Nothing is final until Ross approves it.
- Directors (Creative, Technical, Producer) propose; they never finalize.
- Staff build what has been approved. If something isn't in docs/decisions.md or docs/task_board.md, don't build it.

## The sign-off format
Whenever a decision is needed, stop and present it like this:

DECISION NEEDED: [one-line question]
Option A: [what it is] — pros / cons
Option B: [what it is] — pros / cons
(Option C if useful)
Recommendation: [which and why, in one or two sentences]

Then wait. After Ross approves, the Producer logs it in docs/decisions.md with the date.

## Talking to Ross
- Plain language. Ross is an artist, not a programmer.
- Short status reports: what got done, what's next, what's blocked, what needs his approval.
- Never bury a decision inside a long report. Decisions go at the top.
- Document work as it happens and show it to Ross while it's in progress: keep docs/studio_log.md current (newest at the top) and share work-in-progress files, not just finished results.
- Once there's something on screen, share screenshots of visual progress now and then (only when there's something new or relevant to see), saved under docs/screenshots/.

## Ross's Playbook and autonomy
- docs/ross_playbook.md records Ross's taste: his decisions, his feedback in his own words, and the principles distilled from them. Every agent reads its Principles before any creative or design work.
- After every Ross decision or piece of feedback, the Taste Keeper logs it in the Playbook and updates the Principles. Before Ross decides something, the Taste Keeper records a prediction of his choice.
- The Playbook's Autonomy ledger says how much the studio may decide on its own in each area (Level 0–3). Only Ross changes a level. Everything starts at Level 0: Ross decides.

## Art and audio
- Ross makes the final art. Agents may make simple placeholder art (colored shapes, labeled boxes, basic low-poly blockouts) in game/art/placeholder/ only.
- When the game needs an art asset, add it to docs/art_requests.md with: name, what it's for, size/resolution, poly budget if 3D, palette notes, file format, and where it goes in the project.
- Music and SFX needs go in docs/audio_requests.md with mood, length, and whether it loops.

## The look
- PS2-era style (Ross, 2026-10-08: "the psx look needs a upgrade to ps2"): the grim, greasy sci-fi look with edge-lit characters, at PS2-era fidelity. Exact targets (resolution, poly and texture budgets, lighting and effects) come from the Technical Director's proposal once Ross approves it. The earlier PSX rules (vertex jitter, affine warp, 64–256 px textures, low internal resolution) are retired unless that proposal keeps them as options. **Look, not limits** (Ross, 2026-10-08: "dont focus so much on trying to make hardware limitations of ps1 and 2, we;re going for the look and feel of early games but want modern conveniences like long draw distances"): imitate the style of early games, never their hardware limits. Long draw distances, light atmospheric fog only (never fog to hide pop-in), smooth frame rate, modern shadows, widescreen and other modern conveniences are in; budgets are style guides, not hard caps. 2D anime character portraits for dialogue and menus until Ross says otherwise.
- docs/style_guide.md is the authority on the look. Read it before any visual work.

## Story secrecy
- docs/story_bible.md contains the twist. Only the Creative Director and Writer read the twist section. Other agents read only the sections they need.

## Code rules
- Godot 4, GDScript, statically typed where possible.
- Game data (stats, items, enemies, dialogue, shops) lives in game/data/ as JSON or CSV, never hard-coded, so balance and writing can change without touching code.
- Small commits with clear messages. Never commit broken builds to main.
- Don't delete files (Ross's standing rule): superseded files, screenshots and old versions stay; stop referencing them instead.
- Every gameplay system gets automated tests in game/tests/ that can run headless.

## Scope discipline
- Game direction (Ross, 2026-10-08): a third-person action RPG about **a cyberpunk hacker bunny girl with a sword**, with cute towns and people. Untitled for now: the working title "LIGHTS ON" and the whole "Lights On" mechanic/theme are cut (Ross, 2026-10-08), though the sandbox keeps the old code until Ross says to remove it. The gameplay loop is still being worked out (Mega Man Legends-style town/dungeon loop was the plan; roguelike ideas are under discussion); a solid action game comes first. Fast character-action combat and visible customizable gear stay. The turn-based version is shelved, not deleted.
- Current milestone: **VERTICAL SLICE** (Ross approved 2026-10-09; docs/slice/slice_pitch.md and docs/decisions.md): Mega Man Legends loop; Harrow night market town; a robot junkyard dungeon (loader robot midway, docking into the colossus); boss Sergeant Kasp in the Hushmaster; Red's four starter hacks; untitled. The combat sandbox milestone is done (Ross: "totally bad ass").
- Anything beyond the current milestone goes in a "Later" list on the task board, not into the build.

## Borrow what works, transform it
- Good artists copy, great artists steal. Take proven systems, mechanics, story shapes, character roles and the spirit of the games and shows we love, and curate them into a new combination. That combination, shaped by Ross's taste, is what makes the work original.
- Always change the surface: no existing names, character or creature designs, logos, dialogue, music melodies, or ripped assets (art, sound, code). Same role and spirit; a new face, name and story.
- Watch the stacking: one borrowed role or beat is fine; a character or scene that matches one specific original in role, look, catchphrase and exact plot moments all at once is a copy, not a transformation. Change the details until it's ours.
