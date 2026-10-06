# LIGHTS LEFT ON: Milestone 1 demo (how to play)

This is a small test build. It has a title screen and one little test room where you can walk Red around and flip the old-PlayStation graphics effects on and off. There is no story or battle yet. We want to know how the look and the camera feel to you.

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
| Talk / interact in a room | E or Z | **B** |
| Confirm / pick a menu item | Enter, Z or E | A button |
| Start / go back | Enter or Esc | Start button |
| PSX options panel | **F1** | (keyboard only) |

Esc (or Start) in the room takes you back to the title screen.

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
- **Red.** This is a placeholder model, built from simple shapes. Does her size on screen and her walk and run feel right?

Tell us what you think. All of it goes straight into the style guide.
