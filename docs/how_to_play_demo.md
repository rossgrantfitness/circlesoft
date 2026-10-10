# LIGHTS LEFT ON: v0.3.0 (how to play)

This build has the start of the real game: **Harrow Landing**, the first town, as a graybox (simple blocks and stand-in figures, no final art yet). Choose **New Game** on the title screen and Red wakes up at home at night. From there: the courier office next door, Lamp Square, the general store and gear shop, the bar, Otis's dock office, the docks (with the first story fight) and the Signals checkpoint. About 25 townsfolk have short placeholder lines that change as the story moves on. The job board has two side deliveries, and 5 items are hidden around town.

**Saving:** walk up to a save lamp and press E (the lamp in Red's home also rests the party for free). The game also auto-saves each time you enter a new area. **Continue** on the title loads your newest save.

**Battle Test** on the title screen still jumps straight into any of the test fights. The old test room is behind the DEBUG door on the west side of Lamp Square.

## Opening it on Windows

1. Unzip or copy `LightsLeftOn.exe` anywhere (it is one file).
2. Double-click it.
3. Windows will probably show a blue "Windows protected your PC" box, because we haven't paid for a publisher certificate yet. Click **More info**, then **Run anyway**. You only have to do this the first time.

## Opening it on a Mac

1. Double-click `LightsLeftOn.zip` to unzip it. You get an app called **Lights Left On**.
2. Double-click the app. A warning will say it can't be opened because Apple can't check it. Click **Done** (or **OK**) to close the warning.
3. Open **System Settings**, then **Privacy & Security**. Scroll down to the message about "Lights Left On" and click **Open Anyway**. Enter your password if it asks.
4. Double-click the app again and click **Open**. From now on it opens normally.

(If you can't find the message, wait a few seconds after step 2 and look again. Right-clicking the app and choosing **Open** also works on some Macs.)

## Controls

| What | Keyboard | Controller |
|---|---|---|
| Move Red | W A S D or the arrow keys | Left stick or d-pad |
| Run | Hold **Shift** (let go to walk) | Hold **X** (the west button) |
| Jump | **Space** | **A** |
| Talk / examine / take (the icon over Red's head shows when you can) | E or Z | **B** |
| Field menu (Items, Status, Config, Save, Close) | Tab or C | **Y** |
| Confirm / pick a menu item | Enter, Z or E | A button |
| **Clutch** (the timing button in a fight) | Space, Z, E or Enter | **A** |
| Start / go back | Enter or Esc | Start button |
| PSX options panel | **F1** | (keyboard only) |

Esc (or Start) in the room takes you back to the title screen. It does nothing while a speech bubble, the menu or a fight is up.

## Fighting

Four enemies stand in the room: a Grunt, a Drone, a Squad Boss and the Quota Enforcer (the tough one: you can't run from it). Walk up to one until the little speech-bubble icon shows over Red's head, then press the talk button (E / Z / B). The enemy shouts a silly challenge and asks **Fight?** Pick **Fight!** to start the battle, or "Not now" to walk away.

- **Timing.** Press the Clutch button right as your hit lands to hit harder. Press it right as an enemy's hit lands on you to block it. Miss and nothing bad happens, you just don't get the bonus.
- **Winning** puts you back in the room exactly where you stood, and that enemy is gone until you start the demo again. **Running away** puts you back too, and the enemy is still there. **Losing** asks whether to **Retry** (the same fight, from the moment before it started) or go back to the title screen.
- **Making timing easier.** Open the field menu (Tab / C / Y), then **Config**. There are three timing options:
  - **Auto-Timing**: the game presses for you, so you can just watch (off by default).
  - **Wide Windows**: the moment that counts is longer. You still press.
  - **Timing Offset**: nudges the timing earlier or later, for laggy TVs and wireless headphones.

## The PSX options panel (press F1)

F1 shows or hides a list of the graphics effects. Press the key to flip each one on or off and see the difference right away:

| Key | What it does |
|---|---|
| F2 | Vertex jitter: models wobble slightly, like the PlayStation |
| F3 | Affine warp: textures bend a little as the camera moves |
| F4 | Dither: the checkerboard pattern that hides color banding (it only shows while 15-bit color is on) |
| F5 | 15-bit color: fewer colors, like the old console |
| F6 | Fog: distant things fade into the night color |
| F7 | Vertex lighting: the chunky per-corner lighting |
| F8 | Cycle the screen's tiny internal size (384x216, 320x240, 426x240, 480x270) |
| F9 | Cycle the camera: narrow perspective, wider perspective, then flat (orthographic) |

## What to look at

- **The camera.** It never turns. It just slides with Red. Walk to the far right to follow Red into the long wing of the room, and watch how she stays in frame.
- **The pillar.** Walk behind the tall pillar (near the middle of the room). It dithers away so you can still see Red, then comes back when she steps out.
- **The PSX look.** Turn each effect off and on with F2 to F7. Which ones do you love, and which are too much? Try F8 and F9 too.
- **Talking.** Walk up to Otis, Mox or the old Zero (rough stand-in models in Red's style) and press E. They turn to face Red and talk in comic speech bubbles with gibberish voices. Mox asks you a yes/no question.
- **Examining.** Try the pillar, the lamp, the crates, the sign and the window. The gold prize crate on the raised platform needs a jump to reach.
- **The field menu.** Press Tab (or Y): Items, Skills, Equip (green/red arrows compare gear), Status, Party (reorder the crew; Red stays in front), Config (all settings, including a tap-along test that tunes Clutch timing to your screen) and Save (only at a save lamp).
- **The battle camera** now moves, from your storyboard: a short camera sequence at the start of each fight (any button skips), a drifting camera while you pick commands, and action shots when someone attacks. It holds steady whenever a timing press is coming. Config → Battle Camera switches between Dynamic and Calm (the old fixed view).
- **Shops.** Walk up to a counter and press E. Buy, sell at half price, pick how many; the gear shop shows who each item would make stronger.
- **Roaming enemies** (in the test yards behind the test room's west door): they patrol and chase you. Sneak up from behind for a first strike; get caught from behind and they strike first.
- **Red.** This is the shiba Red you approved, with rough stand-in animations only (stand, walk, run, jump, fall, land). Does her size on screen feel right?

Tell us what you think. All of it goes straight into the style guide.
