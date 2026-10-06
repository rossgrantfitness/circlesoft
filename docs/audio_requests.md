# Audio Requests

> Music and sound effects the game needs. Written by the Audio Designer.
> Status: Requested / In progress / Delivered / Implemented

**Vertical slice audio (approved 2026-10-06): 8 music tracks and jingles, 40 SFX.** Until real audio arrives, the Audio Designer wires in **placeholder tones** for every row (task M6-5; the Clutch ding gets a placeholder in M2-3). The music direction goes to Ross for sign-off before real tracks are made (Audio direction is Level 0). Tone: loud, goofy, big-hearted, 90s JRPG energy; original music only, never copied. Files: .ogg for music (with loop points), .wav for SFX; destination game/audio/music/ and game/audio/sfx/ (folders confirmed by the tech plan).

**Timing rule for battle audio:** the Clutch ding and the rating sounds fire from the same moment as the flash, so they must have a sharp, instant attack (no fade-in, no silence at the start of the file).

**Keeping SFX to 40:** some sounds do double duty (noted per row), e.g. the cursor tick also ticks the credit count-up, and one bell tone is pitched per bell.

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

### Sound effects (40, grouped)
| # | Name | Type (music / SFX / jingle) | Where it plays | Mood | Tempo | Length | Loops? | Priority | Status |
|---|---|---|---|---|---|---|---|---|---|
| 9 | Clutch cue: ding; boss "!!" warning | SFX (2) | The moment to press; boss big-attack warning | Sharp, bright, unmistakable; the warning bigger and more alarming | — | Ding <0.3 s; warning ~1 s | No | P1 | Requested |
| 10 | Ratings: Nice!, Rad!, TOTALLY RAD! | SFX (3) | Clutch attack ratings | Rising excitement; TOTALLY RAD is the loudest sound in a fight | — | ~0.5–1 s each | No | P1 | Requested |
| 11 | Blocks: Blocked!, Perfect Block! | SFX (2) | Clutch block ratings (Payback = Perfect Block + a hit) | Solid clank; ringing perfect clank | — | ~0.5–1 s each | No | P1 | Requested |
| 12 | Hits: party weapon hit, enemy hit | SFX (2) | Basic attacks (pitch-varied per weapon) | Chunky, punchy, cartoon-meaty | — | ~0.3–0.6 s each | No | P1 | Requested |
| 13 | Hurt, Down for the Count, K.O.! slam | SFX (3) | Taking damage, a fighter knocked out, last-hit freeze | Hurt short and light; Down a goofy thud; K.O. a huge freeze-frame slam | — | ~0.3–1.5 s each | No | P1 | Requested |
| 14 | Signature moves: Porch Light flare, Heave-Ho slam, Patent Pending wheel | SFX (3) | Signature moves | Big and showy; the slot wheel ticks fast then clunks to a stop | — | ~0.5–2 s each | Wheel spin loops until stopped | P1 | Requested |
| 15 | Status: Burnt Toast, Noise Ticket, Wobbly | SFX (3) | Status effects landing | Sizzle; officious stamp-and-buzz; woozy wobble | — | ~0.5–1 s each | No | P1 | Requested |
| 16 | Battle flow: radio-static transition, run away, level-up | SFX (3) | Starting fights (boss uses a longer cut), Run and grunts' white-flag exit, level-up and skill learned | Static hiss snapping into battle; comic scramble; triumphant level-up | — | ~0.5–3 s each | No | P1 | Requested |
| 17 | Menu: cursor tick, confirm, cancel/error | SFX (3) | Every menu; tick also counts up credits, confirm also buy/sell and save | Crisp and tactile | — | <0.3 s each | No | P2 | Requested |
| 18 | Text blips: Otis, Mox, Kasp, generic | SFX (4) | Dialogue boxes; generic is pitched per key NPC and crowd | Otis low and calm, Mox high and fast, Kasp nasal and officious | — | <0.1 s each | No | P2 | Replaced by row 24 (gibberish voice set) |
| 19 | Lamp check: lamp lights, two knuckle taps on glass | SFX (2) | Rest and save at Red's window and save lamps | Warm, quiet, a little sincere | — | ~0.3–1.5 s each | No | P2 | Requested |
| 20 | Field: footsteps, door, item get, crate open | SFX (4) | Exploring Harrow and the tower; item get also plays for heals | Light and readable; item get a happy little sting | — | ~0.2–1.5 s each | Footsteps repeat | P2 | Requested |
| 21 | Tower puzzles: card reader beep, switch-and-lift | SFX (2) | Signals doors; power switch clunk into the running cage lift | Fussy Signals beep; clunky old machinery | — | Beep <0.5 s; lift ~2 s + loop | Lift loops | P3 | Requested |
| 22 | Watch Zero bell | SFX (1) | One brass bell tone, pitched per bell for the tune puzzle and layered for the sit-in protest | Bright brass, a joyful racket when layered | — | ~1–2 s | No | P3 | Requested |
| 23 | Hushmaster: leg stomp/servo, Quiet Hours jam pulse, crash | SFX (3) | Kasp fight and cutscenes; crash plays short for each leg pair and full for the topple | Big clanky machine with bureaucratic pomp; jam pulse a rising electronic whine into a static burst | — | ~0.5–3 s each | Servo hum loops | P4 | Requested |

### Gibberish voice set (added 2026-10-06, Ross's decision: "a voiced gibberish system")
As a speech bubble types out, each typed letter plays a very short babble syllable in the speaker's own synthesized voice. Same letter = same syllable for a speaker, so lines feel like a made-up language. Vowels and consonants use different syllable shapes; "?" swoops up, "!" punches, commas and full stops add a tiny breath. Red has no voice (gesture sounds only). Described in words only; nothing copied from any game.

How it is built: each voice picks one of 7 "timbres" (a bank of 11 tiny 22 kHz mono WAVs: 5 vowels, 4 consonant types, a rise and a punch) and the game pitch-shifts them per speaker. Placeholders are generated by `game/scripts/tools/make_voice_syllables.py` into `game/audio/voice/<timbre>/`. Voice settings (pitch, range, speed, vowel coloring, volume) are in `game/data/audio/voices.json`. To replace a bank with real audio, record the same 11 syllable names at the timbre's `ref_hz`, keep each under ~150 ms, 22-44 kHz mono WAV, and overwrite the folder; no code changes.

| # | Name | Type (music / SFX / jingle) | Where it plays | Mood | Tempo | Length | Loops? | Priority | Status |
|---|---|---|---|---|---|---|---|---|---|
| 24 | Gibberish voice set (7 voices x 11 syllables) | SFX (voice) | Every speech bubble, one syllable per typed letter (every 2nd-3rd letter) | **Otis** `round`: gentle big bear, low, slow, warm, narrow melody. **Mox** `chirp`: hyper ferret kid, very high, zippy, wide melody. **Zero (old)** `creak`: creaky old-timer, low-mid, buzzy, drifting pitch. **Kasp** `honk`: blustering beaver, nasal, every "!" a loud punch. **Vela** `prim`: prim bunny, tidy bell-like, even, stiff little rises. **Ruo** `smooth`: smooth-talking smuggler, lazy vibrato, drawling droop. **Townsfolk** `plain`: generic villager, pitched per NPC in code | Fast (several per second) | 30-120 ms each | No | P2 | Placeholder built; final voices TBD |
| 25 | UI and gesture placeholders: menu_tick, menu_confirm, menu_back, bubble_open, bubble_next, item_get, red_thumbs_up, red_head_shake | SFX (8) | Menus, speech bubbles opening and advancing, item pickup, Red's gestures (cloth swish plus a boop, never a voice) | Crisp, tactile, tiny; Red's are soft and cute | n/a | 30-480 ms each | No | P2 | Placeholder built (`game/audio/sfx/placeholder/`, mapped in `game/data/audio/sfx.json`); final TBD. Rows 17 and 20 (menu, item get) cover the final versions of these |

### Battle SFX placeholders (added 2026-10-06, Milestone 2)
Every `battle_*` id from docs/battle_api.md has a placeholder WAV in `game/audio/sfx/placeholder/`, built by `game/scripts/tools/make_battle_sfx.py` (numpy, seeded, byte-identical on every run) and mapped in `game/data/audio/sfx.json` (`placeholder: true`). These rows are the brief for the real sounds. To swap one in: drop the real .wav in `game/audio/sfx/`, change the `file` path in sfx.json, set `placeholder` to false. Timing rule: `battle_ding` and the three ratings must start at full level from the first sample. Loudness ladder: ding and big hits loud, Nice < Rad < TOTALLY RAD, and TOTALLY RAD is the loudest sound in any fight. Tone: loud, goofy, rad; nothing grim.

| # | Id | Where it plays | Mood | Length | Loops? | Reference feel | Status |
|---|---|---|---|---|---|---|---|
| 26 | `battle_ding` | The Clutch cue, same instant as the flash | Very short, sharp, bright, unmistakable; peak in the first ~10 ms, no fade-in | <0.2 s | No | A tiny bright bell-tick, like a shop-counter bell cut short | Placeholder built; final TBD |
| 27 | `battle_hit` | Basic party and enemy hits | Chunky, punchy, cartoon-meaty | ~0.3 s | No | Fat cartoon thwack, 90s beat-em-up punch | Placeholder built; final TBD |
| 28 | `battle_hit_big` | Boss and big-attack damage | Heavier, longer thump with a clank | ~0.5 s | No | Like `battle_hit` with a steel-drum slam under it | Placeholder built; final TBD |
| 29 | `battle_rating_nice` | "Nice!" rating | Small, pleased, two bright notes rising; quietest rating | ~0.5 s | No | A polite two-note chime | Placeholder built; final TBD |
| 30 | `battle_rating_rad` | "Rad!" rating | Excited, fuller, quick rising run with sparkle | ~0.7 s | No | A hot arcade combo-pop | Placeholder built; final TBD |
| 31 | `battle_rating_totally_rad` | "TOTALLY RAD!" rating | The loudest, splashiest sound in a fight: big rising run, stacked chord, cymbal crash, laser zip, boom. Goes with a quick screen shake | ~1.3 s | No | A guitar-and-brass victory sting crossed with a firework | Placeholder built; final TBD |
| 32 | `battle_block` | "Blocked!" | Solid metal clank | ~0.35 s | No | Sword on shield | Placeholder built; final TBD |
| 33 | `battle_perfect_block` | "Perfect Block!" | Ringing clank that sustains with a bright ting | ~0.9 s | No | A struck bell-metal shield | Placeholder built; final TBD |
| 34 | `battle_payback` | "Payback!" (Perfect Block plus a free counter-hit) | Ring, whoosh, punchy counter | ~0.8 s | No | Parry-and-riposte flourish | Placeholder built; final TBD |
| 35 | `battle_ko` | The last-hit K.O. freeze-frame | Huge slam, crash, rumbling tail; funny-big, not violent | ~1.5 s | No | Anime freeze-frame slam with a cymbal | Placeholder built; final TBD |
| 36 | `battle_down` | A fighter goes Down for the Count | Goofy descending "bwomp", wobble, dull thud | ~0.75 s | No | Cartoon deflation and a plop | Placeholder built; final TBD |
| 37 | `battle_flee` | Run away; grunts' white-flag exit | Comic scramble: pattering feet speeding up, a zip, a puff | ~1 s | No | Cartoon dash-off | Placeholder built; final TBD |
| 38 | `battle_heal` | Healing items and skills | Soft rising sparkles over a warm shimmer | ~0.9 s | No | A gentle harp glissando | Placeholder built; final TBD |
| 39 | `battle_static_in` | Fight starts (the boss uses a longer cut later) | Radio static sweeping up, then a sharp snap into battle | ~0.8 s | No | Tuning a dial, then a camera-flash snap | Placeholder built; final TBD |
| 40 | `battle_static_out` | Fight ends, back to the map | A thump, then static whooshing away | ~0.65 s | No | The dial tuning out | Placeholder built; final TBD |
| 41 | `battle_victory` | Victory screen start (one press skips) | Short, cocky, triumphant; rising arpeggio, a little turn, a big held chord with a cymbal. Original tune; the full row 2 fanfare replaces it | ~2 s | No | Sunny 90s JRPG "we won" sting; melody must be original | Placeholder built; final TBD (row 2) |
| 42 | `battle_game_over` | All three down | Comically deflated, never grim: sagging "wah" notes and a long droop | ~2 s | No | A sad-trombone shrug; the full row 3 jingle replaces it | Placeholder built; final TBD (row 3) |
| 43 | `battle_menu_open` | Battle command menu opens | Tiny bright rising chirp | ~0.17 s | No | A crisp UI blip | Placeholder built; final TBD |
