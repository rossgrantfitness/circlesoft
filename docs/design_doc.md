# Design Document

> Owner: Creative Director (proposes) · Ross (approves). Nothing here is final until it appears in docs/decisions.md.

## Core pitch
> ✅ APPROVED by Ross, 2026-10-06 (Relay swapped for timed hits per Ross)

LIGHTS LEFT ON is a classic 90s JRPG hero's journey. Ten years ago Red's mom flew into the starless dark to answer a distress call. Now Red, a silent scrappy pup in Mom's three-sizes-too-big jacket, goes after her with a loud chibi animal crew: a gentle bear, a panicky ferret genius, a by-the-book bunny and a show-off raccoon. In about 10 hours you climb from on foot to big robot to giant robot to giant spaceship to fighting a god. Battles are classic turn-based JRPG fights with timed hits: press the button at the right moment to hit harder, or to block when you're hit. Beat the Admiral's lieutenants and they end up on your side. And the call? It isn't what it seems. A low-poly PSX look in the spirit of Mega Man Legends, Tail Concerto, Metal Gear Solid and Final Fantasy VII: loud, goofy and big-hearted.

**Elevator pitch:** A silent pup and her loud chibi animal crew chase her missing mom's distress call from on foot to giant robots to a giant spaceship, all the way up to punching out a god.

## Pillars
> ✅ APPROVED by Ross, 2026-10-06 (Relay swapped for timed hits per Ross)

1. **Always Bigger.** When two ideas are close, pick the one that makes the climb feel bigger (bigger machines, bigger bosses, bigger crowds) and makes every win feel like a knockout.
   *This means we DON'T* end a big fight on a quiet fizzle, stall at one scale for too long, or cut robots and spaceships to save time; cut something else first.
2. **Loud Crew, Big Heart.** Default to the louder, goofier, more swaggering option, let the crew do the talking for silent Red, and save the sincere moments for when they're earned, shown and never explained.
   *This means we DON'T* go grimdark or self-serious, say the theme out loud, or make jokes or game mechanics out of the characters being animals.
3. **Classic, Not Clever.** Build the 90s JRPG players already love (familiar menus, readable turn-based fights, cute chibi critters Ross can actually model and animate) and spend our one big hook, timed hits, where it counts.
   *This means we DON'T* add high-concept gimmicks, turn the themes into systems (no death or rebirth mechanics), or pick anything that's hard to build just because it's clever.

## Exploration
> ✅ APPROVED by Ross, 2026-10-06 (camera: fixed diorama, Option B)

### Ross's calls on the new ideas (2026-10-06)
- **Instant wins (Later list):** yes, and fast, the way EarthBound did it. Once the party clearly outclasses a group, Hegemony grunts on the map wave a white flag; walk into them and there's no battle screen at all: a quick jingle, a one-line "The grunts surrender!" pop-up with the XP and credits, and you keep walking. Never in the slice.
- **Red's lamp lighting dark rooms:** no. The lamp stays her signature item (at her hip), her Porch Light flare and her rest/save animation; dungeons are lit normally.

### Movement & camera
- **Moving:** Red runs with the stick or d-pad; tilt lightly to walk. Brisk speed, no stamina, no dash.
- **One button does it all:** talk, examine, pick up, open.
- **No jump button.** Ladders, ledges and small gaps get climbed or hopped with that same button at marked spots, like the big 3D JRPGs of the era.
- **The crew follows Red** in a short line in towns and dungeons, so they're always on screen (Pillar 2). They pass through each other and never block her.
- **Rooms load** with a quick fade to black, PSX-style.
- **Camera: a fixed diorama camera (Ross, 2026-10-06).** One high angle per room that never rotates, showing the floor and the two back walls; the front walls are cut away, like looking into a toy box. Rooms are real low-poly 3D in Godot, so the full PSX look applies. The camera slides along with Red in bigger rooms so she never walks off-screen, and tall props in front of her fade out.
  - *Why:* it's the Mario RPG-style diorama Ross asked for, with the least art per room (a floor, two walls and props), and it keeps moving cutscene cameras and robot-scale pull-backs working.
  - *Also considered:* a rotatable follow camera (more art per room) and prerendered backgrounds (FF7-style; heavy art, clashes with the PSX effects). See docs/camera_decision.md.

### Towns
**What you do:** talk to everyone (their lines change after every story beat), shop, rest, find hidden items and pick up small side jobs.

**Harrow Landing (the slice town),** at night, with lamps in the windows:
- **Red's home:** her window lamp. Rest (full heal) and save, free.
- **Courier office:** the job board. The main job to the Old Relay Tower, plus one or two small side deliveries for credits and items.
- **The docks and Otis's dock office:** where the first fight happens. Otis's desk has things to examine.
- **The bar:** barflies, gossip, rumors and the bets board (just flavor in the slice).
- **General store** (healing items) and a **junk-and-gear shop** (weapons and armor, all scavenged).
- **Signals Corps checkpoint:** Kasp's crew being awful; story scenes.
- **Hidden items** behind crates and down alleys.

**Talking with a silent hero:**
- NPCs talk to Red, and Red answers with her face: a quick expression on her portrait, or a little pop-up over her head (ear perk, thumbs-up, shrug).
- When the game needs a yes or no, it shows up as two gestures: thumbs-up or head shake.
- **The party chimes in** after key lines, each in their own way: Mox narrates what Red is "obviously" thinking (always wrong, always heroic); Otis reads her right in one look. Vela and Ruo join in once they're in the party.
- Named characters get a portrait; crowd NPCs talk in plain boxes (less art for Ross).

### Dungeons
- **Layout:** a short chain of hand-built rooms with one main path and small side branches for treasure. Easy to read, hard to get lost in.
- **Puzzles, classic and light:** switches that power a lift or open a door, key cards for locked doors, pushing a crate to make a path. None should take more than a minute or two.
- **Treasure:** chests are crates. Gray Hegemony supply crates (ring-and-bar stencil), and Coldrunner stashes marked with a chalked shuttered lantern, so sharp-eyed players learn to search wherever they see chalk.
- **Save points:** a lamp in a little wall niche. Red does her lamp check to save. One at the entrance, one before the boss.

**The Old Relay Tower (the slice dungeon):**
- Watch Zero's back way leads into the half-buried bottom floor, then up about 5 floors around the old mast to Kasp and the Hushmaster at the top.
- The early floors teach battles and Clutch with easy fights. The call gets louder with every floor (audio).
- **Puzzles:** Kasp's laminated access cards (grunts drop them; every card has his photo on it) open Signals doors; a power switch runs the old cage lift; one crate push opens a side path. **Optional:** ring the Zeroes' bells in the order of the tune an old Zero hums, for a bonus chest.
- **Things to examine:** the Writer gives the level builder the list (some carry story details).
- **Before the boss:** a save lamp, and an old Zero with a thermos who heals the party once.

### Encounters
- **Visible enemies on the map. No random battles.** *Why:* you see every fight coming and can take it or dodge it, which keeps things snappy, and the grunts and drones get to be characters on the map (grumbling on patrol, chasing Red, giving up out of breath).
- **Starting a fight:** touch an enemy. The screen hisses into radio static for a beat, then snaps into battle with a music sting. Same transition every time; bosses get a longer, louder one.
- **Who goes first:** touch an enemy from behind and the party gets a free first turn. Get caught from behind and the enemies go first. (A standard of visible-enemy JRPGs.)
- **Running and avoiding:** dodge them on the map, or use Run in battle (regular fights only). After any fight or escape, Red blinks for a couple of seconds and can't be caught again right away.
- **Respawning:** enemies come back when you leave an area and return. Bosses and story fights don't.

### Getting around the Marches
- **Act 1 (Harrow, on foot):** no world map. Harrow's places are joined by short paths you walk (the Landing, the road to the tower, later the ore tunnels).
- **Biscuit (end of Act 1):** a story stomp through the Landing, not free roaming. Red drives and Biscuit steps over crates and fences. Afterward it rides in the ship's hold.
- **The *Low Profile* (Act 2): the lane chart.** A simple map of the Marches, with moons and stations as dots joined by jump lanes (Ruo's family chart). Pick a destination, watch a short jump (the crew belts a lane-song; skippable after the first time) and land at that place's dock. New lanes light up as the story opens them. No random fights in space; ship fights are story set pieces.
- **The titan (Act 2):** towed behind the *Low Profile*. On some moons you unload it for titan stages: same controls, camera pulled way back, stomping Hardfall Corps garrisons.
- **The *Supper's On* (end of Act 2 and Act 3):** becomes home base, a big ship you walk around: crew quarters, the hold with Biscuit and the titan, and the bridge with its lamp (rest and save). In Act 3 every former foe hangs around on board to talk to. The lane chart zooms out to the whole Marches and reaches into the Quiet.
- *Also considered:* flying the ship freely around a 3D space map. More freedom, but much more to build, and the lane chart fits the lore: whoever holds the lanes holds the Marches.

### Interaction
- **One button:** talk, examine, pick up, open. A small icon pops over Red's head when something nearby can be used (speech bubble = talk, "?" = examine, hand = take). We don't use "!" here, because "!" is the battle timing cue.
- **Examine:** a line of text, and sometimes a crew member comments (Mox asks the questions, Otis answers them).
- **Pick up:** items glint. A box says what you got.
- **Doors:** walk into a door to go through. Locked doors tell you what they need ("Signals access only").
- **The lamp check (rest and save):** at Red's home window (free full heal + save) and at inns (full heal + save, for a small fee), and at save lamps (save only; use a Camp Stove there to rest). She lights the brass lamp, taps the glass twice and gives the sky a thumbs-up, then the save screen opens. Full length the first time each session, a short version after that; one press skips it.

### Cutscenes
- **Long, and plenty of them** (Ross's call), played **in-engine** with the same chibi models as the field. Camera moves, close-ups and wide shots are staged like a movie.
- **Dialogue:** text boxes with 2D anime portraits that change expression mid-line. Each speaker has their own little text "blip" sound. No voice acting.
- **Red's lines are her face:** her portrait shows the expression but never a text box, and her ears do the talking.
- **Big moments get big staging:** slow push-ins, freeze-frames and a chunky title card when a boss arrives.
- **Player controls:** press to advance; hold to fast-forward; text speed and auto-advance settings; any cutscene can be skipped by holding Start (held, so it never happens by accident).
- **Portrait budget for Ross (slice):** about 5 expressions each for Red, Otis and Mox; about 3 for Kasp and key NPCs; none for crowd NPCs. These go into docs/art_requests.md once approved.

### Vertical slice needs vs Later
**In the slice:**
- Run/walk, one-button interaction, climb and hop spots, the crew following Red.
- The fixed diorama camera (floor and two back walls, slides with Red, tall props fade).
- Harrow Landing: Red's home, courier office, docks and Otis's office, bar, general store, gear shop, checkpoint; NPC lines that change after each story beat; one or two side deliveries; hidden items.
- The road to the tower (a short walk) and the Old Relay Tower (about 5 floors): switches, access cards, a crate push, the optional bell chest, two save lamps.
- Visible enemies, the static transition, first-turn rules, Run, the blink after a fight, respawning.
- Treasure crates, chalk stashes and item pickups.
- The lamp check for rest and save.
- In-engine cutscenes with portraits, text blips, fast-forward, text speed and skip.
- All dialogue, shop stock, chest contents and enemy placements in game/data/, with headless tests in game/tests/ (interaction, doors, pickups, fight starts, save and load).

**Later (task board "Later" list):**
- The lane chart, travel between moons, and the *Low Profile*.
- The Biscuit stomp, titan stages and the *Supper's On* home base.
- Dungeon maps in the menu.
- White-flag instant wins (if approved) and lamp-lit dark rooms (if approved).
- The bets board as a playable minigame.
- A theater for rewatching cutscenes.
- Pre-rendered movie scenes: probably never, maybe one or two for the very biggest moments.

## Battle system
> ✅ APPROVED by Ross, 2026-10-06 (names: Clutch, Juice)

**Names (Ross, 2026-10-06):** timed hits are called **Clutch** (a "Clutch press"); the skill gauge is **Juice**.

### The basics
- **Classic turn-based.** You pick a command, the fighter does it, the next one goes.
- **Turn order:** fastest goes first, every round. A row of little portraits along the top of the screen shows who's up next, so you always know when the hit is coming.
- **Party:** 3 fighters on the field in the slice (Red, Otis, Mox). Up to 3 on the field in the full game too.
- **Enemies:** come in groups of 1 to 4 in the slice (more in later fights).
- **Commands:**
  - **Attack:** a basic hit, with a Clutch press.
  - **Skills:** special moves that cost Juice.
  - **Items:** heal, cure, revive, throw.
  - **Defend:** take less damage until your next turn, get a little Juice back, and your block windows get easier.
  - **Swap** (later, once the party has more than 3): swap a fighter in from the bench. Uses that turn.
  - **Run:** works on regular fights, never on bosses.
- **HP:** run out and you're Down for the Count (see Status effects). All 3 down = game over, back to the last save.
- **Juice:** the skill gauge. Comes back with items, by resting, and a little every time you land a Rad or better.

### Timed hits (the hook): Clutch
- **On attacks:** press the button at the right moment as your hit lands for a bonus. Depending on the move: extra damage, an extra hit, or an extra effect (like a stun).
- **On defense:** press as the enemy's hit lands to block and take less damage. A perfect press blocks it all, and on close-up hits you swing back for free (**"Payback!"**).
- **Missing never hurts you.** A missed press is just a normal hit or a normal hurt. Timing only ever adds.
- **The cue, every time:** a bright flash on the fighter, a sharp "ding," and a little **"!"** popping up over the head of whoever's about to hit or be hit. Same cue in every fight, so it's learned once.
- **Ratings** pop up in big chunky letters:
  - **"Nice!"**: close enough. Small bonus.
  - **"Rad!"**: good timing. Full bonus, plus a sip of Juice.
  - **"TOTALLY RAD!"**: perfect. Biggest bonus, the loudest sound, a quick screen shake.
  - On defense: **"Blocked!"**, then **"Perfect Block!"** (and **"Payback!"** if you counter).
- **Three kinds of press, for the whole game:** a **tap** (hit the moment), a **hold and let go** (release at the right moment), and a **string** (a few taps in a row, one per flash). Nothing new gets added later.
- **Accessibility:** an **Auto-Timing** option in settings lands every press as "Rad!" automatically. Also a **Wide Windows** option for players who want it easier but still want to press.

### Skills
Each signature move uses Clutch in its own way.
- **Red, Porch Light:** a **tap** when the lamp at her hip flares blinds the enemy, then a **hold and let go** at the top of her sword spin adds a second, bigger slash. Red never shouts the name; it just slams onto the screen while she grins.
- **Otis, Heave-Ho:** **hold** while he lifts the enemy and **let go** at the top to slam it onto a second enemy, hurting both. A perfect release stuns them.
- **Mox, Patent Pending:** a slot-machine wheel of gadget results spins over his head; a **tap** stops it. Good timing lands the better results, and "TOTALLY RAD!" always lands the amazing one.
- **Vela, Approved in Triplicate:** a **string** of three stamps. Each good stamp heals the whole party more; three perfect stamps also clear everyone's bad status effects.
- **Ruo, Ten Out of Ten:** a **string** of flare-pistol shots. Ruo scores your timing out of ten, out loud, and the score sets how big the last shot is.

### Status effects
- **Burnt Toast:** loses a bit of HP every turn.
- **Noise Ticket:** can't use Skills for a few turns (the Signals Corps' favorite).
- **Wobbly:** hits a random target, sometimes a friend.
- **Tangled:** stuck in a net or cable; skips turns until it wears off.
- **Butterfingers:** timing windows get smaller.
- **Fired Up** (a good one): hits harder and timing windows get bigger. Red's up-ear perks all the way up.
- **Down for the Count:** knocked out at 0 HP. Bring them back with an item or skill.

### Enemies and bosses
- **Every enemy attack has a tell:** a clear wind-up that's the same every time, so players learn the rhythm. Hegemony grunts wave a white flag and leave when they're nearly beaten.
- **Bosses telegraph big attacks:** a longer wind-up, a bigger **"!!"**, a warning sound and a camera push-in, so the player knows a big block is coming and gets ready.
- **Each boss gets its own timing gimmick** (for example, a different rhythm, a fake-out, or a cue it tries to hide). The details live in the story bible's Villains section.

### Scaling up (on foot to god)
One system the whole game. Same commands, same three presses, same cues and ratings. What changes is size.
- **On foot:** the slice. Numbers in the tens and hundreds.
- **Big robot (Biscuit):** the party crews the robot; each crew member still takes their own turn, and their commands become the robot's (Red swings the arms, Otis raises the shield, Mox keeps it running). Numbers in the thousands.
- **Giant robot (the *Second Helping*):** same again, with a wider camera and enemies that fill the screen. Numbers in the tens of thousands.
- **Giant spaceship (the *Supper's On*):** same again; enemies are whole ships and fleets. Numbers in the hundreds of thousands.
- **God fight:** the biggest numbers on any screen. On the big finishers the whole team-up joins in, each ally's face flashing in for one press of a long string.
- **Bigger presses:** the button and the timing stay the same, but the payoff grows: longer wind-ups, bigger flashes, louder sounds, harder screen shake, and longer, wilder strings on the biggest finishers.

### Rewards
- After every win: **XP, credits, and sometimes an item drop.**
- **Victory screen:** a quick party pose (Red's thumbs-up), the totals counting up fast, then straight back to the map. A few seconds long, and one press skips it.
- **Level-ups** show right on the victory screen.

### Feel targets
- **Snappy:** attacks and skills play fast; any animation can be sped up or skipped after you've seen it once.
- **Readable:** you always know whose turn it is, who's getting hit, and when to press.
- **Satisfying:** the last hit of every fight freezes for a beat with a big **"K.O.!"** (Pillar 1: every win feels like a knockout).
- **Length:** a regular fight in the slice takes about 1 to 3 minutes; the Kasp boss about 5 to 8.
- **Timing windows (rough starting point, tune in playtests):** "Nice!" about a quarter of a second, "TOTALLY RAD!" about a tenth.

### Vertical slice needs
**In the slice:**
- Turn order by speed, with the portrait row on screen.
- Attack, Skills, Items, Defend, Run.
- HP, Juice, and Clutch on every attack and every block, with the flash, the "ding," the "!" and the ratings.
- All three press types (tap, hold and let go, string).
- Auto-Timing and Wide Windows options.
- Red, Otis and Mox, with their signature moves and a couple of basic skills each.
- Status effects: Burnt Toast, Noise Ticket, Wobbly, Down for the Count.
- About 4 enemy types (Hegemony grunts, Signals drones and a couple more), plus the Kasp boss with his own timing gimmick.
- Victory screen with XP, credits, drops and level-ups.
- All numbers (stats, skills, enemies, drops, timing windows) in game/data/, with headless tests in game/tests/.

**Later (task board "Later" list):**
- Swap and the bench (Vela and Ruo), and their signature moves.
- Tangled, Butterfingers, Fired Up.
- Robot, giant robot, spaceship and god-scale fights.
- Other bosses' gimmicks.

### Technical Director's review
- **Feasibility for the slice: Medium.** Turn-based battles are well-trodden; only the timed presses need real care.
- **Trickiest pieces:**
  - *Fair timing on any computer:* presses are timed by a clock, not screen updates, so slow machines get the same window.
  - *Flash and "ding" landing together:* both fire from the same moment in the attack's data, plus a "timing offset" setting for laggy TVs and headphones.
  - *Kasp's jam pulse:* cues scramble, but the real window never moves, so learned rhythm still works.
- **Automatic testing:** press-judging runs without graphics. The simulator plays thousands of fights as a "perfect," "good," "miss" and Auto-Timing player, and checks win rates and fight lengths against the Feel targets.
- **Simplify:** Kasp's eight legs break in four pairs (all eight still on screen). Later, not slice: Tilly's net costs a turn on a miss, which breaks "missing never hurts."

## Party & progression
> ✅ APPROVED by Ross, 2026-10-06 (Hull bar A; foes as guests A)

### Ross's calls (2026-10-06)
- **Machine fights:** the crew shares **one Hull bar** (Option A). Hits land on the machine; Hull at 0 = fight lost; crew can't be knocked out inside, but status effects still hit their station.
- **Act 3 former foes are guests** (Option A), as below.

### The party over the game
- **Act 1 (slice):** Red, Otis, Mox. Exactly 3, so no bench yet.
- **End of Act 1:** Vela joins (her resignation fight). 4 in the crew.
- **Act 2:** Ruo joins at Wobble Station. 5 in the crew: the full playable roster.
- **Act 3: former foes are guests, not full party members.** Brunt, Calloway, Sorrell, Tilly, Kasp and Vane each step in for their own story mission (Brunt on a boarding action, Tilly with Ruo on a scouting run, and so on), taking one of the 3 field spots for that stretch.
  - You control them in battle, with a fixed handful of their boss-fight moves (Brunt calls her punches, Sorrell duels).
  - They join at the party's level, don't take gear and leave when the mission ends.
  - Everyone still flashes in on the god fight's big finisher (already approved).
  - *Why:* six more full characters means six more skill lists, growth tables, gear and full portrait sets for Ross. Guests get their moment without that. Playable roster stays at 5.
  - *Also considered:* one or two foes fully playable (say Brunt and Tilly): a bigger fan payoff, but more to build and balance late in the game. Or foes only in cutscenes and fleet fights: cheapest, but you'd never get the team-up in your hands.
- **3 on the field, always.** Red is always one of them (she's the hero). Pick the other two from the field menu any time outside battle.
- **The bench:** sits out until Swap is built (approved, Later); then Swap uses a turn to bring someone in. All 3 on the field down = game over, bench or not.
- Some story fights lock in who fights (Vela in her resignation fight, guests in their missions).

### Levels & XP
- **Classic levels.** Every win gives XP; level-ups show on the victory screen (approved).
- **Level cap: 50.** Rough pace on a straight ~10-hour run:
  - End of the slice (Kasp): about level 6
  - End of Act 1: about 15
  - End of Act 2: about 35
  - Final battle: about 45, with room to 50 for players who do side jobs or like to grind
- **No grinding needed** on the main path: tune so a player who fights most of the visible enemies hits those targets.
- **Each level raises every stat a little,** in each character's own shape (Otis gains lots of HP, Ruo lots of Speed).
- **The bench earns full XP.** Recommended, so nobody falls behind and picking your three is a free choice, not a chore. Fighters who are Down at the end of a fight get full XP too.
- **Late joiners catch up:** Vela and Ruo join at the party's level, already knowing the skills they'd have learned by then.

### Stats
Seven stats, plain names, shown as numbers on the status screen.
- **HP:** health. Hit 0 and you're Down for the Count.
- **Juice:** pays for Skills.
- **Attack:** how hard basic attacks and physical skills hit.
- **Defense:** how much damage you shrug off.
- **Heart:** how hard gadget and lamp skills land, and how much heals restore.
- **Speed:** who goes first in the turn order.
- **Luck:** item drops, Ruo's steals, and the odds of status effects landing (on enemies or on you).
- *Alternates for "Heart":* Spirit, Knack.
- **Stats never change Clutch timing.** Timing stays the player's skill: only status effects (Butterfingers, Fired Up) and the Wide Windows setting change the window, so Clutch feels the same at level 1 and level 50.

### Learning skills
- **Classic: by level.** Reach the level, learn the skill; it pops up on the victory screen. No skill trees, no points to spend.
- **Signature moves** are known from the moment each character joins, and get stronger with level.
- **Every new skill uses one of the three approved press types** (tap, hold and let go, string). No new kinds of press.
- **Who learns what:**
  - **Red (quick front-line hitter):** sword swings and lamp flares. Big single hits, fast double swings, blinding enemies, firing herself up.
  - **Otis (tank):** guarding allies, drawing hits onto himself, shield bashes, stunning throws, toughening up the party.
  - **Mox (gadget wildcard):** traps, gadget buffs, quick patch-ups (small heals), weakening enemies and the odd small explosion, each with a timing gamble.
  - **Vela (healer and support):** heals, revives, cures, shields, and writing enemies a Noise Ticket (no Skills for a few turns).
  - **Ruo (fast attacker and thief):** steals, quick multi-shots, speed tricks and showy finishers he scores out loud.
- **How many:**
  - Full game: about 8 per character, signature included (about 40 total).
  - Slice: 3 each for Red, Otis and Mox (signature plus 2 basic). Each starts with 2 and learns the third around level 4, so players see "learned a skill!" at least once.

### Growth across scales
**One system: the crew's levels and stats drive every machine.** Nothing levels up separately.
- **The crew are the machine.** In Biscuit, the *Second Helping* and the *Supper's On*, the 3 on the field each take a station, take their own turn and use their own stats and Juice (approved: Red swings the arms, Otis raises the shield, Mox keeps it running).
- **Same skills, bigger outfit.** Each character's learned skills carry over as a machine version: Red's Porch Light becomes Biscuit's floodlight swing; Vela's stamps become hull patches. Learn it on foot and it's there in the robot.
- **The machine's own numbers:** a Hull bar (see the decision at the top) and a size boost that turns the crew's numbers into robot, titan or ship numbers (thousands and up, as approved).
- **Machine upgrades:** a short list of parts per machine (armor plating, bigger fists, better engines), found in crates or bought, fitted by Mox in the hold. They raise the Hull and the size boost. Details go in Equipment & items.
- **The bench** rides along off screen and keeps earning XP.
- **The god fight:** same stations and stats; its special staging lives in the story bible.
- *Why:* one set of levels to tune and one set of skill data, and the climb feels like *your crew* getting bigger, not a new game each act (Pillar 1).
- *Also considered:* machines that level up on their own. More to balance, and it splits attention away from the crew.

### Vertical slice needs vs Later
**In the slice:**
- Red, Otis and Mox, 3 on the field, Red always in.
- Levels 1 to about 6, XP on the victory screen, level-ups raising stats.
- All seven stats, with each character's growth table in game/data/.
- Skills learned by level: 3 each, one learned mid-slice.
- A status screen with level, XP to next level, stats and skills (layout goes in Menus).
- Headless tests in game/tests/: XP curve, level-up gains, skills learned at the right level, and the bench-XP and catch-up rules (built now so they switch on later with no new code).

**Later (task board "Later" list):**
- Vela and Ruo, picking your three, the bench and Swap.
- Levels past 6 and the rest of each skill list.
- Act 3 guest missions.
- Machine stations, Hull, size boost, machine versions of skills, and upgrades.

## Equipment & items
> ✅ Direction set by Ross, 2026-10-06 (Red: sword; party: fantasy weapons; items mirror FF7–9 with original names). Item lists are the studio's call; Ross reviews after, no sign-off needed for individual items.

### Notes
- **No new mechanics.** Everything here is standard FF7–9-style gear and items with our own names. No gear ever changes Clutch timing (approved rule: timing stays the player's skill).
- **Weapon types (studio's call under Ross's "appropriate fantasy weapons"):** Red a **sword** (Ross), Otis a **hammer** (door shield kept), Mox a **wrench-mace**, Vela a **staff with a rubber stamp for a head**, Ruo **twin knives** (flare pistols kept for Ten Out of Ten). Each keeps the item already in their approved look. *Alternative Ross can swap to any time:* axe / crossbow / plain healer's rod / pistol-sabre (more textbook fantasy).
- **Save lamps save; they don't heal.** Resting means using a Camp Stove at a save lamp (the classic FF7–9 pattern). Red's home window heals for free; inns heal for a small fee in credits (see Economy).

### The basics
- **One shared bag.** Up to 99 of each item, no weight limits. Key items get their own tab and can't be sold or dropped.
- **Equip from the field menu** any time outside battle. Shops show an up or down arrow next to each fighter so you can see at a glance who an item suits.
- **Guests don't take gear** (approved in Party & progression).
- **Icons:** one small icon per kind of thing (sword, hammer, mace, staff, knives, vest, charm, food, can, bottle, bomb, part), recolored per item. About 12 icons for Ross, not one per item.

### Equipment slots
Three slots, FF7-style.
- **Weapon:** one, the character's own type only. Raises Attack (staffs raise Heart too).
- **Armor:** one. Raises Defense, some also HP. Light armor fits anyone, heavy armor is Otis only, and a few pieces belong to one character.
- **Charm:** one (the accessory slot). A stat bump, protection from a status effect, or a bigger Clutch payoff. Marchfolk hang lucky charms on everything; ours actually work.

### Weapons by character
- **About 7 per character:** a new one every few levels, plus a hidden ultimate weapon at the end of a late side job (classic).
- Weapons give Attack (staffs also Heart) and at most one small perk, like a chance to land a status effect.
- **How weapons show on the 3D model (cheap for Ross):** weapons are separate props held in the hand, so swapping one never touches the character model. Each character gets **3 weapon models for the whole game** (starter, Act 2, Act 3). Every weapon in between reuses the nearest model with a new color; the ultimate reuses the Act 3 model with a special color. The slice needs only the starter models, plus recolors.

**Red: swords** (the brass lamp stays clipped at her hip for Porch Light and the lamp check)
- **Scrap Sword** (starter): hammered out of a hull plate, grip wrapped in tape.
- **Rebar Blade** (slice shop): heavier, hits harder.
- **Bread Knife, Extremely Large** (slice, the optional bell chest): a little Luck. Nobody asks where it came from.
- **Hull-Plate Broadsword** (the Act 2 model).
- **Coldrunner Cutlass:** a little Speed.
- **Lamplighter** (the Act 3 model).
- **Wicked Awesome** (ultimate): the sword every barfly on Harrow swears is real.

**Otis: hammers** (his door shield is part of his model and never changes)
- **Dock Mallet** (starter).
- **Rivet Hammer** (slice shop).
- **Sledge, Gently Used.**
- **Pile Driver** (the Act 2 model).
- **Anchor on a Stick:** a chance to stun.
- **Big Friendly Hammer** (the Act 3 model).
- **Mostly Structural** (ultimate): "Nothing personal."

**Mox: wrench-maces** (his gadgets still come out of his pockets as Skills)
- **Big Wrench** (starter): nearly as tall as he is, with a weight welded on the end.
- **Pipe Wrench, Slightly Bent** (slice shop): "It's supposed to be like that."
- **Lug-Nut Morningstar** (the Act 2 model): lug nuts welded on like spikes.
- **Torque Wrench With Opinions:** clicks very loudly.
- **Hot Wrench:** a chance of Burnt Toast.
- **Wrench-and-a-Half** (the Act 3 model): two wrenches welded together, MOX WUZ HERE on the join.
- **Patent Still Pending** (ultimate).

**Vela: stamp-staffs** (her clipboard is part of her model and never changes)
- **Approval Staff** (starter): a brass rod with an APPROVED stamp on top.
- **Self-Inking Staff.**
- **Signals Antenna Staff:** pulled off her old post. Picks up lane-songs.
- **Notary Rod** (the Act 2 model): embosses.
- **Express Mail Staff:** a little Speed.
- **Triplicate Staff** (the Act 3 model): three stamp heads.
- **Final Notice** (ultimate).

**Ruo: twin knives** (his flare pistols stay on his belt for Ten Out of Ten)
- **Coldrunner Knives** (starter).
- **Butter Knives (Sharpened).**
- **Galley Cleavers.**
- **Lane-Cutters** (the Act 2 model).
- **Getaway Knives:** better odds on steals.
- **Showstoppers** (the Act 3 model).
- **Perfect Ten** (ultimate): he scored them himself.

### Armor
- **Armor never changes the 3D model.** Red's jacket, Otis's coveralls and everyone's look stay exactly as Ross models them; armor only shows in the menu.
- **Light (anyone):** Padded Work Vest, Hi-Vis Vest (a little Luck: "They see you coming. Somehow that helps."), Dust Duster, Spacer's Flight Suit, Rim Runner Coat, Starlight Lining (late, best light armor).
- **Heavy (Otis only):** Lucky Coveralls (starter; never been washed, never been beaten), Steel-Toe Everything, Surplus Plate (Numbers Filed Off), Dockmaster's Harness.
- **One character only:** Quilted Lining (Red's starter, sewn inside Mom's jacket), Too-Many-Pockets Vest (Mox's starter), Pressed Uniform (Vela's starter; still pressed after she quit), Dramatic Scarf (Ruo's starter; a little Speed).

### Charms
- **Stats:** Lucky Bolt (Luck), Weightlifting Belt (Attack), Knee Pads (Defense), Lucky Locket (Heart), Running Shoes (Speed).
- **Status protection:** Earplugs (Noise Ticket), Oven Mitts (Burnt Toast), Sea-Legs Band (Wobbly), Pocketknife (Tangled), Grippy Gloves (Butterfingers), **Zero's Sleeve Bell** (late and rare: protects from every bad status; it rings when trouble's near).
- **Clutch payoff:** Sore Loser Patch (Payback hits harder), Encore Pin (a "Rad!" or better gives a bigger sip of Juice).
- **Other:** Spare Battery (start every fight with some Juice), Gold Star Sticker (more XP), Tip Jar (more credits), Pep Rally Pennant (start every fight Fired Up).
- Charms don't show on the model.

### Items
The same structure and tiers as FF7–9, with our own names. Anyone can use any item. Items never need a Clutch press: pick it, it works (classic).

**HP heals (one fighter):**
- **Ration Bar:** small. Tastes like the wrapper.
- **Can of Chili:** medium.
- **Dock Diner Special:** large.
- **Sunday Roast:** full HP.

**Juice:**
- **Canned Coffee:** small.
- **Juice Box:** medium. Yes, really.
- **Thermos of Cold Brew:** full Juice.

**HP and Juice together (rare):**
- **The Whole Enchilada:** full HP and Juice, one fighter.
- **Block Party Platter:** full HP and Juice, whole party. Very rare.

**Revive (Down for the Count):**
- **Smelling Salts:** back up with a little HP.
- **Jumper Cables:** back up with full HP.
- **Air Horn:** everyone who's Down gets back up with a little HP. Rare.

**Status cures:**
- **Burn Gel:** Burnt Toast.
- **Appeal Form:** Noise Ticket (voids it, in triplicate).
- **Ginger Chews:** Wobbly.
- **Box Cutter:** Tangled.
- **Grip Tape:** Butterfingers.
- **Snake-Oil Tonic:** cures everything. It works, weirdly.

**Rest:**
- **Camp Stove:** use it at a save lamp and the whole party gets full HP and Juice. Sold in towns, a few hidden in dungeons.

**Throwables** (fixed damage, so they're useful at any level):
- **Firecracker String:** small hit on every enemy.
- **Scrap Grenade:** big hit on one enemy.
- **Hot Sauce Bomb:** a hit plus Burnt Toast.
- **Static Can:** gives an enemy a Noise Ticket.
- **Fizz Bomb:** a shaken-up soda; makes an enemy Wobbly.
- **Cable Bolas:** Tangles an enemy.
- **Smoke Bomb:** escape a regular fight (a Coldrunner favorite; never works on bosses).

**Boosters (rare, raise a stat for good):**
- **Cod Liver Oil** (max HP), **Triple Espresso** (max Juice), **Protein Shake** (Attack), **Hardtack** (Defense), **Hot Cocoa** (Heart), **Energy Drink** (Speed), **Four-Leaf Clover** (Luck).

**Battle boosts:**
- **Pep Talk Tape:** one fighter gets Fired Up.

**Key items (slice):**
- **Courier Job Slip:** the delivery to the Old Relay Tower.
- **Delivery Crate:** heavier than expected (Mox is inside).
- **Side-job parcels:** one or two, for the small deliveries in Harrow Landing.
- **Kasp's Access Cards:** laminated, his photo on every one; grunts drop them and they open Signals doors. Shows a count.
- **Bell Tune Napkin:** the old Zero's tune written down, for the optional bell chest.
- **Beacon part:** from the Hushmaster's wreck. The Writer writes its description, and the Creative Director checks it against the twist clues before it goes in.

### Machine upgrades
No crafting and no slots. Each part is a one-time find, and Mox fits it in the hold the next time the crew rests. Every part raises the Hull, the size boost, or both (as approved). Parts are just numbers: no new commands, and no changes to the machine models.

**How you get them:** crates, dock shops and story gifts: Calloway's hatch notes lead to titan parts, and every former foe who crosses over in Act 3 brings one part for the *Supper's On*.

**Biscuit (big robot), about 4 parts:**
- **Extra Cargo Plating:** more Hull.
- **Bigger Mitts:** bigger size boost.
- **Fresh Hydraulics:** a little of both.
- **Steel-Toe Feet:** more Hull.

**The *Second Helping* (giant robot), about 5 parts:**
- **Scrapforge Plating:** more Hull.
- **Arm Number Nine:** salvaged from Calloway's fight. Bigger size boost.
- **Coolant Valve (Kick Gently):** from one of Calloway's hatch notes. A little of both.
- **Heavier Fists** and **Bigger Reactor:** size boost.

**The *Supper's On* (giant spaceship), about 7 parts (the Act 3 refit):**
- **Titan Salvage Plating:** more Hull.
- **Hushmaster Dish (Rebuilt):** Kasp's rig bolted to the hull (approved Act 3 beat).
- One part from each former foe: **Title Belt Armor** (Brunt), **Arm Number Ten** (Calloway), **Riposte Ram** (Sorrell), **Fanfare Horns** (Vane), **Price-Tagged Net Cannon** (Tilly).

### Crafting
**None.** You find things, buy things, or get given things. Mox fits machine parts, but it happens on its own, not in a crafting menu. Nothing here seemed worth flagging as a new idea: crafting would add a whole system to a 10-hour classic game and break "Classic, Not Clever."

### Vertical slice needs vs Later
**In the slice:**
- Weapon, armor and charm slots for Red, Otis and Mox; the equip menu and shop arrows.
- **Weapons: 7** (Red: Scrap Sword, Rebar Blade, Bread Knife; Otis: Dock Mallet, Rivet Hammer; Mox: Big Wrench, Pipe Wrench). **Weapon models: 3** (sword, hammer, wrench-mace), the rest are recolors.
- **Armor: 5** (Quilted Lining, Lucky Coveralls, Too-Many-Pockets Vest, Padded Work Vest, Hi-Vis Vest).
- **Charms: 4** (Lucky Bolt, Earplugs, Oven Mitts, Sore Loser Patch).
- **Items: 13** (Ration Bar, Can of Chili, Canned Coffee, Juice Box, Smelling Salts, Burn Gel, Appeal Form, Ginger Chews, Camp Stove, Firecracker String, Hot Sauce Bomb, Smoke Bomb, and one Protein Shake hidden in the tower). These cover the slice's four status effects.
- **Key items: 6.**
- **Icons:** about 12.
- All gear and items in game/data/ (JSON), with headless tests in game/tests/: equipping changes stats correctly, weapons lock to their owner, charms block their status, every item works in and out of battle, the Camp Stove only works at save lamps, boosters raise stats for good, the 99 cap, and key items can't be sold.
- Art needs (3 weapon props, recolors, icons; Otis's hammer is a new prop in his hand) go into docs/art_requests.md.

**Later (task board "Later" list):**
- Vela's and Ruo's weapons; the Act 2 and Act 3 weapon models; ultimate weapons.
- The bigger item tiers (Dock Diner Special, Sunday Roast, Thermos of Cold Brew, The Whole Enchilada, Block Party Platter, Jumper Cables, Air Horn), the Tangled and Butterfingers cures and charms, Snake-Oil Tonic, Pep Talk Tape, the other throwables and boosters, and later armor and charms.
- All machine upgrades.
- Rough full-game counts: about 35 weapons (7 per character), about 15 armor, about 17 charms, about 35 items, about 16 machine parts.

## Economy
> ✅ APPROVED by Ross, 2026-10-06

**No new mechanics.** This is the classic FF7–9 money loop with nothing added.

### Money
- **Credits** are the only currency.
- **Where they come from:** battles, crates, courier side jobs, and selling.
- **What they're for:** gear, items, machine upgrades (from Act 2 on) and inn stays (a small fee; Red's home stays free).

### Shops
- **General store:** heals, Juice, revives, cures, Camp Stoves, throwables.
- **Gear shop:** weapons, armor, charms.
- **Dock shop (Act 2 on):** machine parts, plus the basics.
- Each new town's shops sell the next tier up, and prices rise with the tier.
- **Sell anything except key items for half price.**

### Pacing targets
- You can afford the next weapon tier about once per town.
- Never forced to grind: fighting most of the visible enemies (the same rule as XP) pays for the main path. Side jobs and selling pay for the extras.
- Healing items always stay cheap. Nobody is ever too broke to heal.
- The best gear comes from crates and side jobs, so exploring pays off.
- **Slice target:** about 1,500 credits by the Kasp fight. That's enough for the three shop weapons plus a pocketful of Ration Bars, but not every vest as well, so the player makes one real choice.

### Balance lives in data
All prices, drops, crate contents and side-job pay go in game/data/. The battle simulator checks that the credits you earn keep up with the price curve.

### Vertical slice needs vs Later
**In the slice:** credits from battles, crates and one or two side jobs; the general store and gear shop; selling for half price.
**Later:** inns, dock shops and machine parts, higher tiers, the Tip Jar charm.

## Menus
> ✅ Finalized by the studio, 2026-10-06 (Level 2: Ross reviews after)

Classic FF7–9 menus with our own names. **Controller-first;** keyboard (arrows or WASD, Enter, Esc) and mouse (hover moves the cursor, click picks, right-click backs out) work everywhere. The cursor snaps with a crisp tick and remembers where it was. *The window look gets decided later in docs/style_guide.md.*

**Title screen:** New Game, Continue, Config. Continue opens the save list with the newest save already picked, so one press loads it (grayed out if there are no saves). New Game asks for the hero's name (default "Red").

**Field menu** (outside battle): Items, Skills, Equip, Status, Party, Config, Save (only at a save spot), and Lane Chart once you have it. A side panel shows the 3 fighters' portraits, HP and Juice, plus credits, play time and where you are.
- **Party:** pick the two who join Red, and set the order.
- **Status:** portrait, level, XP to next level, the seven stats, gear, skills and status effects.

**Battle menu:**
- A command list next to whoever's up: Attack, Skills, Items, Defend, Run (Swap later).
- **Targeting:** a pointer hops between enemies; flip sides to pick a friend; all-target moves light up the whole group.
- The **turn-order portrait row** along the top; HP and Juice along the bottom.
- When a move plays, the menu slides away so nothing covers the Clutch cue (flash, "ding", "!") or the ratings, which pop up big over the fighter.

**Shops:** Buy, Sell, Leave. Pick how many, see how many you own, and gear shows an up or down arrow by each fighter.

**Dialogue box:** 2D anime portraits for named characters; plain boxes for crowd NPCs. Red never gets a text box: her face or a gesture pops up over her head. Yes/no is a thumbs-up or a head shake.

**Config:** Auto-Timing, Wide Windows, timing offset (with a tap-along test), text speed, auto-advance, cutscene skip on/off, music and sound volume, controls (remap buttons), vibration.

### Vertical slice needs vs Later
- **Slice:** everything above except Lane Chart and Swap. All menu text in game/data/; headless tests in game/tests/ for cursor movement, equip, buy and sell, and Config saving.
- **Later:** Lane Chart, Swap and the bench in Party, a window color option (if the style guide allows it).

## Save system
> ✅ Finalized by the studio, 2026-10-06 (Level 2: Ross reviews after)

Classic FF7–9 saving: you save at set spots, not anywhere.

**Where you can save:**
- **Save lamps** in dungeons: save only (a Camp Stove rests the party there).
- **Red's home:** free rest and save.
- **Inns:** rest for a small fee, and save.
- **The *Supper's On* bridge lamp:** rest and save, once the ship is home base.

**The lamp check:** at every save spot Red lights the lamp, taps the glass twice and gives the sky a thumbs-up, then the save screen opens. Full length the first time each session, a short version after; one press skips it.

**Slots:** 3 manual slots plus 1 auto-save.
- The auto-save writes when you enter a new area (a town, a road, a dungeon), never mid-room or mid-battle. You can't save over it by hand.
- Each slot shows the party's portraits, Red's level, the place name, play time and credits.
- Saving over a slot asks first (thumbs-up or head shake).

**What's saved:** story progress, where you are, the hero's name, the party (who's in, order, levels, XP, HP, Juice, stats including boosters, skills, gear), the bag and key items, credits, opened crates and picked-up items, beaten bosses, side jobs and play time. Config is saved once for the whole game, not per slot.

**Continue** loads the newest save, manual or auto.

**Game over** (all 3 down, or Hull at 0): a short fade, then a choice:
- **Retry battle** *(the studio's call; not an FF7–9 feature, Ross can strike it):* restart that fight from the top, exactly as you were when it began. Cheap to build, and it saves a long walk back after a tough boss.
- **Title screen,** where Continue loads the last save.

### Vertical slice needs vs Later
- **Slice:** Red's home and the tower's two save lamps, the lamp check (full and short), 3 slots plus the auto-save, Continue, game over with Retry battle. Saves as versioned JSON files; headless tests in game/tests/: save then load gives the same game, the auto-save fires on area entry, Retry restores the fight's start, older saves still load.
- **Later:** inns, the *Supper's On* bridge, and saving machine parts, Hull and Act 3 guest missions.

## The 10-hour structure (act by act)
> ✅ APPROVED by Ross, 2026-10-06 (Act 2: two re-dressed moons, Option A; studio additions kept)

> **Pacing rule (Ross): keep it tight.** No filler. Every area, side job and rematch earns its minutes; studio additions (the Tilly rematch, the Slipway Prime hub, the two titan stages, the scouting run) stay short and punchy. When something runs long, cut it before padding anything. The ~10-hour target is a ceiling, not a quota.

**What this is:** a gameplay map of the approved Act 1/2/3 outlines: where you go, what you do there, how big you are, who you fight and roughly how long it takes. No new story and no new mechanics. Times are rough first-playthrough minutes, cutscenes included.

**Key:**
- **Town:** people, shops, rest, side jobs.
- **Dungeon:** enemies, light puzzles, save lamps.
- **Travel:** the lane chart (Act 2 on) or a short walk (Act 1).
- **Set piece:** a story sequence, mostly cutscene, sometimes with scripted fights.
- **Boss:** a story boss fight.
- **Scale:** on foot → big robot → giant robot → giant spaceship → god.
- **Party:** 3 on the field, Red always in. The rest ride along on the bench.

### Decisions for Ross

DECISION NEEDED: How many new moons does Act 2 visit? (the biggest swing in your art load)
Option A: Two moons, built by re-dressing Harrow's pieces (new palette, signs and props) — pros: Act 2 still feels like a road trip and hits 4 hours; mostly reused parts / cons: the moons look related to Harrow (fair: they're all dust moons).
Option B: Three or four moons, each with its own look — pros: more variety; the "moon by moon" rally feels bigger / cons: one or two more towns and dungeons from scratch, the biggest single addition to your art list.
Option C: One moon plus Wobble Station — pros: least art / cons: "moon by moon" shrinks to cutscenes, and Act 2 comes in well under 4 hours.
Recommendation: A. It keeps the approved road-trip feel and the 4-hour act, and the moons cost you a re-dress, not a new build.

**Studio additions to check.** The outlines imply these but don't spell them out. Strike any you don't want:
- A **Tilly rematch** at Wobble Station (her Act 1 fight again, harder; she smoke-bombs out again). Her approved bio says she isn't really beaten until Act 2.
- A **small hub on Slipway Prime** (the gate and a dock shop) before the heist.
- **Two titan stages** on the Act 2 moons you already visited (the approved "frees moon after moon").
- The Act 3 **scouting run** (Tilly and Ruo) set in the wreck of the Rim blockade, reusing Act 2's ships.
- **Where each Act 3 guest fights** (from the approved guest list).

### Act 1
**Harrow · about 3 hours · levels 1 → 15 · on foot, then big robot**

1. **[SLICE] Harrow Landing, night**
   Town · on foot · ~8 min
   Party: Red; Otis joins in the dock fight.
2. **[SLICE] The road to the tower**
   Travel (a short walk) + Watch Zero's sit-in · on foot · ~4 min
   Party: Red, Otis; Mox joins (out of the crate).
3. **[SLICE] The Old Relay Tower** (about 5 floors)
   Dungeon · on foot · ~12 min
   Party: Red, Otis, Mox.
4. **[SLICE] Top of the tower**
   Boss · on foot · ~6 min
   **Boss: Sgt. Kasp in the Hushmaster.** About level 6.
   **The vertical slice ends here: about 30 min.**
5. **The lockdown** (Harrow Landing)
   Set piece · on foot · ~10 min
   Party: Red, Otis, Mox.
6. **Harrow under curfew** (the Landing re-dressed with checkpoints) + first trip into the **Signals compound**
   Town + dungeon · on foot · ~40 min
   Shops and side jobs; Hardfall patrols are visible enemies. Ends caught by Vela.
7. **Tilly's way out** (the old ore tunnels to her hidden pad)
   Dungeon + boss · on foot · ~38 min
   **Boss: Tilly in the *Fine Print*.** About level 9.
8. **Vela's resignation** (breaking out of the Signals compound: the cells and the back half)
   Dungeon + boss · on foot · ~30 min
   **Boss: Kasp in the Hushmaster Mk II.** Vela joins mid-fight. About level 12.
9. **Borrowing Biscuit** (stomp through the Landing)
   Set piece with fights · big robot · ~15 min
   Party: Red, Otis, Mox, Vela (3 at Biscuit's stations).
10. **The cargo yard** (the docks' floodlit back lot)
    Boss · big robot · ~12 min
    **Boss: Lt. Brunt in the *HNS Title Shot*.** About level 15.
11. **Off Harrow** (the ore freighter's hold)
    Set piece · big robot · ~5 min

**Art load, Act 1:**
- **New areas (6):** Harrow Landing (Red's home, courier office, docks and Otis's office, bar, two shops, checkpoint), the road, the Old Relay Tower, the ore tunnels and Tilly's pad, the Signals compound, the freighter hold. The first 3 are the slice.
- **Re-dresses, not new:** the Landing under curfew (checkpoints, troopers, lit windows); the Landing for Biscuit's stomp.
- **New big models (4):** the Hushmaster (Mk II is a variant), the *Fine Print*, Biscuit, the *HNS Title Shot*.
- **Reuse tricks:**
  - The **cargo yard is part of the docks**, so it isn't its own build.
  - **Size Biscuit to fit the Landing's own streets.** The stomp is the same rooms with the camera pulled back and containers in the road.
  - **The Signals compound is used twice:** break in (beat 6), break out (beat 8), through different halves.

### Act 2
**The Marches · about 4 hours · levels 15 → 35 · on foot and big robot, then giant robot, then giant spaceship**

Party from beat 1: Red + any 2 of Otis, Mox, Vela, Ruo.

1. **Wobble Station** + the dockside getaway
   Town + short dungeon · on foot · ~30 min
   **Boss: Tilly rematch in the *Fine Print*** (studio addition). Ruo joins.
2. **Moon-hopping** (Moon 1 and Moon 2; names to come)
   Travel (lane chart) + 2 small towns + 2 jammer-site dungeons · on foot and big robot (Biscuit at the jammer sites) · ~35 min
3. **A rematch nobody scheduled** (Moon 2's outskirts)
   Boss · big robot · ~12 min
   **Boss: Lt. Brunt in the patched *HNS Title Shot*** (called off halfway). About level 21.
4. **The plan** (aboard the *Low Profile*)
   Set piece · on foot · ~5 min
5. **Heist on Slipway Prime** (the gate hub, then the Scrapforge Division)
   Small town + dungeon · on foot · ~35 min
6. **Stealing the titan** (out through Slipway Prime's docks)
   Set piece with fights · giant robot · ~10 min
7. **The chase off Slipway Prime**
   Boss · giant robot · ~15 min
   **Boss: Lt. Calloway in the *Second Draft*.** About level 27.
8. **Notes in the hatches** (back to Moon 1 and Moon 2)
   Travel + 2 titan stages vs Hardfall garrisons · giant robot · ~25 min
9. **The last lane**
   Travel + set piece · giant robot · ~8 min
10. **The Rim blockade**
    Boss · giant robot · ~20 min
    **Boss: Lt. Sorrell in the *HNS Riposte*** (Tilly works the edges). About level 32.
11. **Into the Quiet: the *Supper's On*** (the dark ship)
    Dungeon · on foot, ending at giant spaceship · ~20 min
12. **Vane's last stand**, then the reveal (restricted)
    Boss · giant spaceship · ~25 min
    **Boss: Admiral Vane in the *HNS Magnificent*.** About level 35.

**Art load, Act 2 (the heaviest act):**
- **New areas (10, 4 of them mostly re-dressed):** Wobble Station, Moon 1, Moon 2, two jammer sites, the *Low Profile* cockpit (cutscenes only), Slipway Prime (gate and docks), the Scrapforge Division, the Rim blockade, the *Supper's On* (inside and out).
- **New big models (7):** the *Low Profile*, the *Second Helping* (titan), the *Second Draft*, the *HNS Riposte* and its battleship, a gray Navy hull kit, the *Supper's On*, the *HNS Magnificent*.
- **Reuse tricks, by flag:**
  - **Moons:** Harrow's pieces with a new palette, signs and props. Low-res textures make palette swaps cheap.
  - **Jammer sites:** the Old Relay Tower's mast pieces, re-dressed.
  - **Titan stages:** big simple terrain, with the moon towns' own buildings shrunk down to toy size as props. No new buildings.
  - **Slipway Prime (a whole shipyard world):** build one dock module (slipway, crane, half-built hull) and repeat it to the horizon. The heist is only three rooms (gate, dock walk, Scrapforge floor). The titan punch-out uses the same module from far back.
  - **The Navy (blockade, *Magnificent*, Scrapforge hulls, Act 3 fleets):** the lore already says every Navy ship is mismatched hulls painted one gray. Build a kit of 6 to 8 hull chunks and kitbash every Navy ship from it, with one gray texture. The *Magnificent* is the biggest kitbash plus the greatcoat sail.
  - **The Rim blockade:** only the lead battleship and the *Riposte* get detail. The "wall of gray hulls" behind them is the kitbash, mostly as silhouettes on a flat backdrop.
  - **The *Supper's On*:** one build, two uses. Lights off, it's the beat 11 dungeon; lights on, it's the home base for the rest of the game.

### Act 3
**The team-up · about 3 hours · levels 35 → 45 · every scale, ending at god**

Party: Red + any 2 of the five. Guests take a field spot for their own mission (approved).

1. **The first to cross** (the *Supper's On*, at the Rim)
   Home base + set piece · on foot · ~8 min
   Brunt and Sorrell cross over.
2. **The Admiral's encore** (the *Magnificent*'s wreck)
   Set piece · giant spaceship · ~8 min
   Vane crosses over.
3. **Engineers and enlistments** (the *Supper's On*'s hold)
   Home base: the refit · on foot · ~10 min
   Calloway and Kasp cross over; machine upgrades fitted.
4. **Tilly's price tag** (scouting run through the Rim blockade's wreck)
   Dungeon · on foot · ~15 min
   **Guest: Tilly**, with Ruo locked in.
5. **Rallying the Marches** (Wobble Station, Moon 1, Moon 2, a pass over Harrow)
   Travel + town revisits · on foot and giant spaceship · ~25 min
   Last shops, side jobs, and the late side jobs for the ultimate weapons. About level 38.
6. **Into the Quiet** (the fleet charge)
   Set piece with fights · giant spaceship · ~15 min
   **Guest: Vane.**
7. **Every scale at once** (the Quiet)
   Dungeon · on foot, big robot, giant robot, giant spaceship · ~35 min
   **Guests: Brunt** (on foot, boarding), **Calloway** (Biscuit, in the holds), **Sorrell** (the titan, on the hulls). About level 42.
8. **Otis gets loud**
   Set piece · giant spaceship · ~5 min
9. **Final battle, part 1**
   Boss · giant spaceship · ~15 min
   **Boss: the real enemy** (restricted). **Guest: Kasp.**
10. **Red's choice and the finale**
    Boss (continued) · every scale, ending at god · ~30 min
    The whole team-up. About level 45. Staging is in the story bible's restricted section.
11. **Coming home**
    Set piece · giant spaceship · ~8 min
12. **Lights out** (Harrow)
    Set piece, ending · on foot · ~7 min

**Art load, Act 3 (the lightest act to build):**
- **New areas (2):** the Quiet (one multi-scale dungeon) and the finale arena.
- **Revisits, re-dressed:** Harrow, Wobble Station, Moon 1, Moon 2 (lamps lit, fleet overhead); the blockade wreck (the Act 2 hull kit, broken up).
- **New big models (1):** the real enemy. Variants only: the refit *Supper's On*, the rebuilt *Second Draft*, the Hushmaster bolted to the hull.
- **Reuse tricks, by flag:**
  - **The Quiet:** starless is the cheapest sky in the game: black, plus fog, radio hiss and lighting. Its rooms reuse the hull kit and the *Supper's On* pieces, re-lit.
  - **Every scale at once and the finale:** every party machine and enemy model from Acts 1–2 comes back. The only new giant is the real enemy, and the Creative Director will cost it with Ross directly (it's twist material).
  - **Guests:** only Brunt and Tilly fight on foot; the other four fight from machine stations. So only 2 former foes need on-foot battle animations.

### Summary: hours and art load

| Act | Hours | Levels | Towns | Dungeons | Bosses | New areas | New big models |
|---|---|---|---|---|---|---|---|
| 1 | ~3 | 1→15 | 1 | 3 | 4 | 6 (3 in slice) | 4 |
| 2 | ~4 | 15→35 | 4 | 5 | 5 | 10 (4 re-dressed) | 7 |
| 3 | ~3 | 35→45 | 0 new | 2 | 1 | 2 | 1 |
| **Total** | **~10** | | **5** | **10** | **10** | **18** | **12** |

- **Bosses by scale:** 4 on foot (Kasp, Tilly, Kasp Mk II, Tilly again), 2 big robot (Brunt twice), 2 giant robot (Calloway, Sorrell), 1 giant spaceship (Vane), 1 final that climbs every scale to god.
- **3 of the 10 bosses are rematches** on a model you've already built. Unique boss rigs: 7.
- **Where your art time goes:** Act 2 is about half of it (Slipway Prime, the Navy hull kit, the titan, the *Supper's On*). The hull kit pays for itself three times: Act 2's Navy, the blockade wreck, and the Quiet.

## Vertical slice scope
> 🟡 DRAFT: awaiting Ross's approval

**The slice in one paragraph:** Night on Harrow Landing. Red does her lamp check, takes a courier job to the Old Relay Tower and wades into Kasp's crew at the docks; Otis joins. On the road her delivery crate starts bragging: Mox is in. Watch Zero's old-timers show the back way in, and the crew climbs about 5 floors of fights, Clutch lessons and light puzzles while the call gets louder. At the top: Kasp in the Hushmaster. In the wreck Red finds the beacon part, hears the call clearly, and holds it up to her window lamp. About 30 minutes, no filler.

**IN the slice (the build list):**
- [ ] **Places:** Harrow Landing (home, courier office, docks and Otis's office, bar, two shops, checkpoint), the road, the Old Relay Tower (~5 floors).
- [ ] **Party:** Red, Otis, Mox; levels 1–6; 3 skills each.
- [ ] **Battle:** Attack, Skills, Items, Defend, Run; turn-order row; Juice; Clutch on every hit and block (all 3 presses, ratings, Payback); signature moves; Burnt Toast, Noise Ticket, Wobbly, Down for the Count; ~4 enemy types; Kasp's jam pulse, legs breaking in pairs, then Kasp on foot; victory screen.
- [ ] **Exploration:** fixed diorama camera, one button, crew follows, visible enemies, 2 save lamps + Red's home, the lamp check, card doors, lift switch, crate push, optional bell chest.
- [ ] **Menus and save:** all but Lane Chart and Swap; 3 slots + auto-save.
- [ ] **Gear:** 7 weapons, 5 armor, 4 charms, 13 items, 6 key items.
- [ ] **Economy:** two shops, sell at half, 1–2 side deliveries, ~1,500 credits by Kasp.
- [ ] **Story:** ~6 in-engine cutscenes; all dialogue in game/data/; the slice's twist clues per the story bible (Creative Director/Writer own).
- [ ] **Audio:** 8 music tracks and jingles (title, Harrow at night, tower, battle, Kasp, victory, game over, the call); ~40 SFX (Clutch ding, ratings, hits, static transition, menu ticks, text blips, lamp check, bells, Hushmaster).
- [ ] **Options:** Auto-Timing, Wide Windows, timing offset, Retry battle.

**OUT of the slice (goes to Later):** everything on the task board's Later list. Biggest cuts: Vela and Ruo, Swap, robots/ships/god fights, travel off Harrow, inns, instant wins, Act 1 from the lockdown on.

**Ross's art list for the slice (41 assets).** The look: PSX style, Mega Man Legends, Tail Concerto, MGS1, FF7.
1. Party models, rigged (3): Red, Otis (with door shield), Mox (with Tuesday).
2. Weapon props (3): sword, hammer, wrench-mace; shop weapons are recolors.
3. Portrait sets (6): Red, Otis, Mox ×5 expressions; Kasp + 2 key NPCs ×3 (21 images).
4. Enemy models (4): Signals grunt, Signals drone, 2 more (variants of those two save you work).
5. Boss (2): Kasp; the Hushmaster rig (8 legs, dish, toppled state).
6. Townsfolk models (4): old Zero, dockhand, Marchfolk, shopkeeper; recolored for crowds.
7. Environment sets (4): Landing streets and docks; 6 interiors; the road and mast foot; tower kit with cage lift and roof. Battle backdrops reuse these.
8. Props (8): delivery crate, supply crate, chalk mark, save-lamp niche, bells, power switch, card-reader door, beacon part.
9. UI art (7): item and status icons (~16); turn-order heads (8); rating lettering; field pop-ups and Red's gestures; Kasp's title card; title screen and logo; menu window and cursor.

**Done means:**
1. Playable from title screen to the lamp at the window in ~30 minutes, no dead ends.
2. All tests in game/tests/ pass headless; the battle simulator hits the Feel targets.
3. Full QA pass (no crash or major bugs open), text and asset checks, and a playtest report.
4. Ross's art in everywhere (placeholders only with his OK).
5. Ross plays a build on his own computer and signs off.

**Rough build order** (placeholders until each art drop):
- **First:** the full docs/style_guide.md (palette, proportions, PSX rendering rules, UI windows, fonts) is drafted and approved by Ross before his final art starts; placeholders until then.
1. PSX look (Mega Man Legends, Tail Concerto, MGS1, FF7) + diorama camera test room.
2. Battle system and simulator. *Art in: party models, weapons.*
3. Harrow Landing: exploration, menus, shops, saves. *Art in: Harrow sets, townsfolk, portraits.*
4. The road and the tower. *Art in: enemies, tower kit, props.*
5. Kasp and the Hushmaster. *Art in: the boss.*
6. Story, cutscenes, dialogue, audio.
7. Polish and QA. *Art in: UI.*
