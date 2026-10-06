# Audio Requests

> Music and sound effects the game needs. Written by the Audio Designer.
> Status: Requested / In progress / Delivered / Implemented

**Vertical slice audio (approved 2026-10-06): 8 music tracks and jingles, ~40 SFX.** Until real audio arrives, the Audio Designer wires in **placeholder tones** for every row (task M6-5; the Clutch ding gets a placeholder in M2-3). The music direction goes to Ross for sign-off before real tracks are made (Audio direction is Level 0). Tone: loud, goofy, big-hearted, 90s JRPG energy; original music only, never copied. Files: .ogg for music (with loop points), .wav for SFX; destination game/audio/music/ and game/audio/sfx/ (folders confirmed by the tech plan).

**Timing rule for battle audio:** the Clutch ding and the rating sounds fire from the same moment as the flash, so they must have a sharp, instant attack (no fade-in, no silence at the start of the file).

**Priority follows the build order:** P1 = battle (M2) · P2 = Harrow Landing, menus, saves (M3) · P3 = road and tower (M4) · P4 = Kasp (M5) · P5 = story and title (M6).

### Music and jingles (8)
| # | Name | Type (music / SFX / jingle) | Where it plays | Mood | Tempo | Length | Loops? | Priority | Status |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Battle theme | Music | Every regular fight | Hot-blooded, loud, rad; guitars and drums with a strong, steady beat so Clutch presses feel in the groove | Fast, ~150–160 BPM | ~1:30–2:00 | Yes | P1 | Requested |
| 2 | Victory | Jingle | Victory screen after every win | Big triumphant knockout fanfare, a little cocky | Fast | ~4–6 s (one press skips) | No | P1 | Requested |
| 3 | Game over | Jingle | All three down; before Retry battle / Title | Wry and deflated, never grim; "we'll get 'em next time" | Slow | ~5–8 s | No | P1 | Requested |
| 4 | Harrow Landing at night | Music | The town, the docks, interiors | Warm, laid-back frontier swagger at night; lamps in the windows, a little rowdy | Mid, ~85–100 BPM | ~1:30–2:30 | Yes | P2 | Requested |
| 5 | The Old Relay Tower | Music | The road and the tower floors | Driving and a bit tense, still fun; adventurous climb. Built so the call (row 8) can layer in louder each floor | Mid-fast, ~110–120 BPM | ~1:30–2:30 | Yes | P3 | Requested |
| 6 | Kasp and the Hushmaster | Music | The boss fight | Pompous bureaucratic march meets boss rock; brassy, swaggering, a bit ridiculous. Must still keep a steady beat under the jam pulse | Fast, ~140–150 BPM | ~2:00–2:30 | Yes | P4 | Requested |
| 7 | Title theme | Music | Title screen | Hopeful, big-hearted, a hint of adventure ahead | Mid, ~90–100 BPM | ~1:00–1:30 | Yes | P5 | Requested |
| 8 | The call | Music (signal theme) | Layer in the tower (louder each floor), the final beat at the window | A distant distress signal through radio static; mysterious, a little haunting, never grim. Creative Director gives story notes | Free / slow | ~30–60 s | Yes (also used as a layer) | P5 | Requested |

### Sound effects (~40, grouped)
| # | Name | Type (music / SFX / jingle) | Where it plays | Mood | Tempo | Length | Loops? | Priority | Status |
|---|---|---|---|---|---|---|---|---|---|
| 9 | Clutch cue: ding (1) and boss "!!" warning (1) | SFX (2) | The moment to press; boss big-attack warning | Sharp, bright, unmistakable; the warning bigger and more alarming | — | Ding <0.3 s; warning ~1 s | No | P1 | Requested |
| 10 | Ratings: Nice!, Rad!, TOTALLY RAD! | SFX (3) | Clutch attack ratings | Rising excitement; TOTALLY RAD is the loudest sound in a fight | — | ~0.5–1 s each | No | P1 | Requested |
| 11 | Defense: Blocked!, Perfect Block!, Payback! | SFX (3) | Clutch block ratings and the counter | Solid clank, ringing perfect clank, cheeky counter whack | — | ~0.5–1 s each | No | P1 | Requested |
| 12 | Hits: sword, hammer, wrench-mace, enemy attack | SFX (4) | Basic attacks | Chunky, punchy, cartoon-meaty | — | ~0.3–0.6 s each | No | P1 | Requested |
| 13 | Hurt, Down for the Count, K.O.! slam | SFX (3) | Taking damage, a fighter knocked out, last hit freeze | Hurt short and light; Down a goofy thud; K.O. a huge freeze-frame slam | — | ~0.3–1.5 s each | No | P1 | Requested |
| 14 | Signature skills: Porch Light flare + spin slash, Heave-Ho lift and slam, Patent Pending wheel spin and stop | SFX (4) | Signature moves | Big and showy; the slot wheel ticks fast then clunks to a stop | — | ~0.5–2 s each | Wheel spin loops until stopped | P1 | Requested |
| 15 | Status and items: Burnt Toast, Noise Ticket, Wobbly, heal/item use | SFX (4) | Status effects landing, items used | Sizzle; officious stamp-and-buzz; woozy wobble; warm sparkle | — | ~0.5–1 s each | No | P1 | Requested |
| 16 | Battle flow: radio-static transition, boss transition, run away, grunt white flag, level-up, skill learned, credits count-up tick | SFX (7) | Starting and ending fights, victory screen | Static hiss snapping into battle (boss version longer and louder); comic scramble; triumphant level-up | — | ~0.2–3 s each | Count-up tick repeats | P1 | Requested |
| 17 | Menu: cursor tick, confirm, cancel, error, buy/sell | SFX (5) | Every menu, shops | Crisp and tactile; cash-register for buy/sell | — | <0.3 s each | No | P2 | Requested |
| 18 | Text blips (per speaker: Otis, Mox, Kasp, 2 key NPCs, crowd) | SFX (6) | Dialogue boxes, one blip per few letters | Each fits the voice: Otis low and calm, Mox high and fast, Kasp nasal and officious | — | <0.1 s each | No | P2 | Requested |
| 19 | Lamp check: lamp lights, two knuckle taps on glass, save confirm | SFX (3) | Rest and save at Red's window and save lamps | Warm, quiet, a little sincere | — | ~0.3–1.5 s each | No | P2 | Requested |
| 20 | Field: footsteps, door, locked door, item get, crate open, interaction pop | SFX (6) | Exploring Harrow and the tower | Light and readable; item get a happy little sting | — | ~0.2–1.5 s each | No | P2 | Requested |
| 21 | Tower puzzles: card reader beep, power switch, cage lift (running), crate push | SFX (4) | Tower puzzles | Clunky old machinery; card reader a fussy Signals beep | — | ~0.5–2 s; lift loops | Lift loops | P3 | Requested |
| 22 | Watch Zero bells: bell tones for the tune puzzle, sleeve-bell protest jingle | SFX (2 sets) | Optional bell chest; Zero sit-in | Bright brass bells, one pitch per bell; the protest a joyful racket | — | ~1–2 s each | No | P3 | Requested |
| 23 | Hushmaster: leg stomps and servos, Quiet Hours jam-pulse charge, leg-pair break, topple crash, Kasp's whistle | SFX (5) | Kasp boss fight and cutscenes | Big clanky machine with bureaucratic pomp; the jam pulse a rising electronic whine into a static burst | — | ~0.5–3 s each | Servo hum loops | P4 | Requested |
