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

## Art and audio
- Ross makes the final art. Agents may make simple placeholder art (colored shapes, labeled boxes, basic low-poly blockouts) in game/art/placeholder/ only.
- When the game needs an art asset, add it to docs/art_requests.md with: name, what it's for, size/resolution, poly budget if 3D, palette notes, file format, and where it goes in the project.
- Music and SFX needs go in docs/audio_requests.md with mood, length, and whether it loops.

## The look
- PSX-era style: low-poly 3D, low-resolution textures (64–256px), nearest-neighbor filtering, vertex jitter/snapping, affine texture warping, dithering, and a low internal render resolution scaled up. 2D anime character portraits for dialogue and menus.
- docs/style_guide.md is the authority on the look. Read it before any visual work.

## Story secrecy
- docs/story_bible.md contains the twist. Only the Creative Director and Writer read the twist section. Other agents read only the sections they need.

## Code rules
- Godot 4, GDScript, statically typed where possible.
- Game data (stats, items, enemies, dialogue, shops) lives in game/data/ as JSON or CSV, never hard-coded, so balance and writing can change without touching code.
- Small commits with clear messages. Never commit broken builds to main.
- Every gameplay system gets automated tests in game/tests/ that can run headless.

## Scope discipline
- Current milestone: VERTICAL SLICE (one town, one dungeon, one boss, three party members, full battle system, ~30 min of story).
- Anything beyond the slice goes in a "Later" list on the task board, not into the build.

## Originality
- Inspired by 90s JRPGs, never copying them. No names, characters, monsters, music, or story beats from existing games.
