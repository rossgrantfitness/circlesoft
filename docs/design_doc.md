# Design Document

> Owner: Creative Director (proposes) · Ross (approves). Nothing here is final until it appears in docs/decisions.md.

## Core pitch
> ✅ APPROVED by Ross, 2026-10-06 (Relay swapped for timed hits per Ross)

LIGHTS LEFT ON is a classic 90s JRPG hero's journey. Ten years ago Red's mom flew into the starless dark to answer a distress call. Now Red, a silent scrappy pup in Mom's three-sizes-too-big jacket, goes after her with a loud chibi animal crew: a gentle bear, a panicky ferret genius, a by-the-book bunny and a show-off raccoon. In about 10 hours you climb from on foot to big robot to giant robot to giant spaceship to fighting a god. Battles are classic turn-based JRPG fights with timed hits: press the button at the right moment to hit harder, or to block when you're hit. Beat the Admiral's lieutenants and they end up on your side. And the call? It isn't what it seems. A low-poly PSX look in the spirit of Mega Man Legends and Fear Effect: loud, goofy and big-hearted.

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
_Movement, camera, towns, dungeons, world map, interaction, encounters._

## Battle system
> 🟡 DRAFT: awaiting Ross's approval

**Choices for Ross (small picks inside this draft):**
- **Name for timed hits:** A **Flashpoint** (recommended) · B **Clutch** · C **Showtime**. Flashpoint says exactly what to watch for (the flash) and sounds rad; Clutch is plainer and sporty; Showtime is the goofiest. ("Flashpoint" is a common word also used by a few other titles; it's a plain English word, not borrowed from a game's battle system.)
- **Name for the skill gauge:** A **Juice** (recommended) · B **Guts** · C **Gumption**. Juice works for a pup and a battleship alike ("Biscuit's out of Juice!"), so it carries through every scale.

### The basics
- **Classic turn-based.** You pick a command, the fighter does it, the next one goes.
- **Turn order:** fastest goes first, every round. A row of little portraits along the top of the screen shows who's up next, so you always know when the hit is coming.
- **Party:** 3 fighters on the field in the slice (Red, Otis, Mox). Up to 3 on the field in the full game too.
- **Enemies:** come in groups of 1 to 4 in the slice (more in later fights).
- **Commands:**
  - **Attack:** a basic hit, with a Flashpoint press.
  - **Skills:** special moves that cost Juice.
  - **Items:** heal, cure, revive, throw.
  - **Defend:** take less damage until your next turn, get a little Juice back, and your block windows get easier.
  - **Swap** (later, once the party has more than 3): swap a fighter in from the bench. Uses that turn.
  - **Run:** works on regular fights, never on bosses.
- **HP:** run out and you're Down for the Count (see Status effects). All 3 down = game over, back to the last save.
- **Juice:** the skill gauge. Comes back with items, by resting, and a little every time you land a Rad or better.

### Timed hits (the hook): Flashpoint
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
Each signature move uses Flashpoint in its own way.
- **Red, Porch Light:** a **tap** when the lamp flares blinds the enemy, then a **hold and let go** at the top of her spin adds a second, bigger wallop. Red never shouts the name; it just slams onto the screen while she grins.
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
- HP, Juice, and Flashpoint on every attack and every block, with the flash, the "ding," the "!" and the ratings.
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
_Party size and swapping, levels, XP, stats, skill learning, character growth._

## Equipment & items
_Equipment slots, item categories, key items, crafting (if any)._

## Economy
_Gold sources and sinks, shop pricing, rewards curve._

## Menus
_Main menu, field menu, battle menu, shops, inventory, status screens._

## Save system
_When and where the player can save, number of slots, what is saved._

## The 10-hour structure (act by act)
### Act 1
_Hours, locations, goals._
### Act 2
_Hours, locations, goals._
### Act 3
_Hours, locations, goals._

## Vertical slice scope
_One town, one dungeon, one boss, three party members, the full battle system, about 30 minutes of story._
- Town:
- Dungeon:
- Boss:
- Party members (3):
- Story covered:
- Out of scope (goes to "Later" on the task board):
