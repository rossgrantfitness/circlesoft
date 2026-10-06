# Getting the demo onto your computer

The builds are too big to send in one piece (the limit is 30 MB), so each one comes in a few parts. You download the parts, glue them back together with one copy-paste command, then open the game as described in **how_to_play_demo.md**.

## Mac (3 parts)

1. Download all three parts into your **Downloads** folder:
   `LightsLeftOn-Mac.zip.part0`, `LightsLeftOn-Mac.zip.part1`, `LightsLeftOn-Mac.zip.part2`
2. Open **Terminal** (press ⌘ + Space, type *Terminal*, press Return).
3. Copy this whole line, paste it into Terminal, and press Return:

   ```
   cd ~/Downloads && cat LightsLeftOn-Mac.zip.part0 LightsLeftOn-Mac.zip.part1 LightsLeftOn-Mac.zip.part2 > LightsLeftOn-Mac.zip && open LightsLeftOn-Mac.zip
   ```

4. That unzips **Lights Left On** into Downloads. Now follow "Opening it on a Mac" in how_to_play_demo.md (the first time, macOS asks you to approve it in System Settings → Privacy & Security → **Open Anyway**).

## Windows (2 parts)

1. Download both parts into your **Downloads** folder:
   `LightsLeftOn-Windows.zip.part0`, `LightsLeftOn-Windows.zip.part1`
2. Click the Start button, type **cmd**, and press Enter to open Command Prompt.
3. Copy this whole line, paste it in (right-click pastes), and press Enter:

   ```
   cd %USERPROFILE%\Downloads && copy /b LightsLeftOn-Windows.zip.part0 + LightsLeftOn-Windows.zip.part1 LightsLeftOn-Windows.zip
   ```

4. Open your Downloads folder, right-click **LightsLeftOn-Windows.zip** → **Extract All**, then double-click **LightsLeftOn.exe** inside. The first time, click **More info** → **Run anyway**.

If anything goes wrong, tell the studio which step you got stuck on. For future builds we can set up a simpler one-click download.
