# Camera and Room Style: Decision

> Status: **DECIDED 2026-10-06: Option B, fixed diorama camera with real-time 3D rooms.** Proposed by the Technical Director after Ross suggested fixed diorama angles like Mario RPG.

**DECISION NEEDED: Which camera and room style do we build?**

**Option A: Rotatable follow camera, real-time 3D rooms** (the current draft)
- In play: a high camera follows Red; the shoulder buttons turn it in 90° steps.
- Ross's art: every room has to look good from all four sides, so all four walls get built, plus cutaways so walls don't block the view. The most modeling per room.
- Fit: full PSX look. The turning camera is a little "clever" for Pillar 3.
- Battles, cutscenes, robots: no problems.
- Build: medium. The main bug risk is the camera clipping through walls.

**Option B: Fixed diorama camera, real-time 3D rooms**
- In play: one high angle per room, showing the floor and the two back walls, like a toy box. The camera slides along with Red but never turns.
- Ross's art: a floor, two walls and props in Blender, with 64–256px textures. The least work per room.
- Fit: full PSX look (jitter, warping and dithering all apply). Very "Classic, Not Clever".
- Battles, cutscenes, robots: battles are unchanged. Cutscene cameras can still move, as long as they stay on the open side. For robot scale, the camera just pulls back.
- Build: the easiest of the three.
- Risks: Red can be hidden behind tall props (fix: those props fade out). Players can walk off-screen in big rooms (fix: the camera slides to follow her).

**Option C: Fixed angles, prerendered backgrounds**
- In play: rich, painted-looking rooms with 3D characters walking over them.
- Ross's art: a detailed render for each camera angle, plus an invisible floor and a "walk-behind" mask for each. It needs lighting and rendering skills, and any change means rendering again.
- Fit: it looks like FF7, not like Mega Man Legends or Fear Effect. The PSX effects don't apply to the backgrounds, so sharp backdrops can clash with the jittery characters. It's hard to build, which Pillar 3 rules out.
- Battles, cutscenes, robots: battles need their own backgrounds, cutscene cameras can't move, and every robot or ship shot is a new render.
- Build: the hardest. The classic bug is characters drawn in front of or behind the background at the wrong moment.

**Originality:** "Mario RPG-style" means the framing only, not borrowed content.

**Recommendation: Option B.** It's the diorama look Ross described with the least art per room. Because the rooms stay real 3D, the PSX look, moving cutscene cameras and robot scale-ups all still work.
