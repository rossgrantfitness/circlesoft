# Voice and UI sound previews (placeholders)

Offline renders of the placeholder audio so you can listen without running the game. Made by `game/scripts/tools/render_voice_preview.py`, which copies the game's rules (same letter-to-syllable table, every-Nth-letter throttle, breaths on punctuation, `?` rise, `!` punch, per-speaker pitch) at 30 characters per second of typing. These are placeholder voices; final voices are TBD. Red has no voice, only gesture sounds (see the SFX file).

## voices_preview.wav

22 kHz mono. Seven voices in this order, half a second of silence between them.

| # | Starts at | Voice | Line (as typed) |
|---|---|---|---|
| 1 | 0.0 s | otis | Red! There you are. Welcome to the / test room, friend. |
| 2 | 2.3 s | mox | DIBS on narrating! This is a TEST ROOM. / For testing! Like me! |
| 3 | 4.8 s | zero_old | Watch Zero, SOUND OFF! *DING-DING!* / That's me. I'm all of Watch Zero today. |
| 4 | 7.9 s | kasp | Citizens! Is this lamp registered? It is NOT. / Section Nine, subsection nine! |
| 5 | 10.9 s | vela | Good evening. I do hope you wiped your boots? / Proper manners, if you please. |
| 6 | 14.0 s | ruo | A ten out of ten entrance, naturally. / Now, who do I charm to get out of here? |
| 7 | 17.1 s | townsfolk | Evening, traveler. The lamps are lit, / the docks are quiet, the stew is warm. |

Otis, Mox and Zero use lines from `game/data/dialogue/test_room.json`. Kasp, Vela, Ruo and the townsfolk lines are short in-character lines written for this preview.

### Voice settings (from `game/data/audio/voices.json`)

| Voice | Timbre | Base pitch | Pitch range | Plays every | Vowel shift / spread | Volume | `!` boost | `?` lift | Blips in line | Character |
|---|---|---|---|---|---|---|---|---|---|---|
| otis | round | 95 Hz | 3 semitones | 3 letters | -1 st / x0.8 | 0.9 | +1 dB | +3 st | 14 | Gentle big bear: low, slow, warm, narrow melody. |
| mox | chirp | 620 Hz | 10 semitones | 2 letters | +0 st / x1.3 | 0.7 | +3 dB | +7 st | 25 | Hyper ferret kid: high, zippy, wide melody. |
| zero_old | creak | 125 Hz | 5 semitones | 3 letters | +0 st / x1.2 | 0.85 | +1.5 dB | +3 st | 20 | Creaky old-timer: low-mid, crackly, drifting pitch. |
| kasp | honk | 165 Hz | 6 semitones | 2 letters | +1 st / x1 | 0.8 | +4 dB | +4 st | 33 | Blustering beaver sergeant: nasal, loud punch on every !. |
| vela | prim | 430 Hz | 7 semitones | 2 letters | +2 st / x0.6 | 0.75 | +1.5 dB | +6 st | 30 | Prim bunny: tidy, bell-like, even, stiff little rises. |
| ruo | smooth | 150 Hz | 5 semitones | 2 letters | +0 st / x1 | 0.85 | +2 dB | +6 st | 28 | Smooth-talking smuggler: lazy vibrato, drawling droop. |
| townsfolk | plain | 235 Hz | 4 semitones | 3 letters | +0 st / x1 | 0.75 | +2 dB | +4 st | 19 | Generic villager: plain mid voice. Pitch it up or down per NPC with play_voice's optional third argument (semitones). |

## ui_sfx_preview.wav

22 kHz mono. The eight placeholder sounds in this order, half a second apart, no announcements. Each plays at its volume from `game/data/audio/sfx.json`.

| # | Starts at | Sound | What it is |
|---|---|---|---|
| 1 | 0.0 s | menu_tick | Cursor move. Crisp little click. |
| 2 | 0.5 s | menu_confirm | Two quick rising notes. |
| 3 | 1.2 s | menu_back | Two quick falling notes. |
| 4 | 1.8 s | bubble_open | Speech bubble pops open: soft rising bloop. |
| 5 | 2.4 s | bubble_next | Advance to the next bubble: tiny soft tick. |
| 6 | 3.0 s | item_get | Item picked up: four-note sparkle. |
| 7 | 3.9 s | red_thumbs_up | Red's thumbs-up gesture: cloth swish into a happy boop. |
| 8 | 4.6 s | red_head_shake | Red's head-shake gesture: two swishes with a low 'nuh-uh' boop. |
