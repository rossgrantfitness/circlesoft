# Red Style Prototypes: Brief for the Technical Artist

> **Status:** PROPOSED by the Creative Director, 2026-10-06. Nothing here is final until Ross picks.
> **Who builds:** Technical Artist (5 static blockout prototypes, no animation). **Who decides:** Ross.
> **Before building:** the Producer adds this job to docs/task_board.md (studio rule: if it isn't on the board, don't build it). Ross's request below is the reason for the task.

**Ross's ask (2026-10-06):** "produce 5 prototypes of the main character for me to approve before we decide on an art style. borrow from games from 98-02 and try to find a classic art style that is more stylized and timeless as opposed to one that tries to be cool and realistic." Earlier: characters "closer to animal crossing style big huge head, tiny body, chibi proportions." Look touchstones (F31): PSX style, Mega Man Legends, Tail Concerto, MGS1, FF7.

## Decision for Ross (after you've seen the contact sheet)

DECISION NEEDED: Which look should Red (and so the whole cast) be built in?
Option A: Wind-Up Toy (chunky painted toy, about 2 heads tall) — pros: closest to your own touchstones, huge head, cheap to rig / cons: the "safest" look of the five.
Option B: Button Pup (rounder, simplest, head over half her height) — pros: the most "huge head, tiny body" of all, least work for you / cons: can look too plain and too clean for the PSX shaders.
Option C: Picture-Book (soft painted storybook, 2.5 heads, the current style guide) — pros: richest acting and close-ups / cons: the most painting per character, and the smallest head.
Option D: Ink Line (flat color with dark outlines, about 2 heads) — pros: reads the sharpest at 40 px, very little texture painting / cons: needs new shader work and fights the PSX texture wobble.
Option E: Rubber Bounce (big hands, big boots, springy, about 2.8 heads) — pros: gestures and thumbs-up read huge, the goofiest / cons: smallest head, most animation work.
Recommendation: A. See the end of this doc for why.

Whichever wins rewrites the "Character proportions" part of docs/style_guide.md (currently 2.5 heads), which Ross signs off as part of this pick. Mixing parts (for example A's surface with B's head size) is a fine answer.

---

## Rules for all five prototypes

These keep the test fair, so Ross is comparing style, not effort.

- **Red, as approved (story bible, Main cast):** scrappy mutt pup, tawny-red fur, cream muzzle and chest, short tail. **One ear straight up, one flopped over.** Mom's red flight jacket three sizes too big, sleeves rolled into fat cuffs, Harrow patches, a hand-painted lamp on the back. Goggles pushed up between the ears. Courier satchel. Scuffed boots. Heavy brass hand lamp clipped at her hip. A scavenged sword a little too big for her, on her shoulder.
- **Originality:** every prototype borrows a *way of making things* from 1998–2002 games, described here in words only. Never copy a character, outfit, face, texture or pose from any game. No reference images traced or pasted. If a prototype starts to look like a specific existing character, change it.
- **Not "cool," not realistic:** no grit, no sharp angular "edgy" shapes, no realistic fur or anatomy, no smooth modern shading. Friendly, round-cornered, readable.
- **Same scale:** Red is 1.0 unit tall (to the top of her head, not counting the up-ear). The test room crate is 0.8.
- **Same skeleton:** the approved shared 17-bone rig, rigid skinning (each vertex follows one bone). Bone lengths change per prototype; bone names and count do not. The lamp sits rigidly on the hips bone (a swinging lamp would need an 18th Red-only bone; that is a separate question for later, not for this test).
- **Same budget:** party member 700 triangles target, 900 hard cap. The sword is a separate prop (100 target, 150 cap). Textures 128×128 body plus a 128×64 face sheet, unless a prototype says it needs less.
- **Same palette** (style guide): tawny #C98A45, cream #F4E4C1, jacket red #C8322A, brass #D9A441 for lamp and goggles, Lamp glow #FFE08A for the lamp glass and goggle lenses, Ink #14121F for the darkest marks, Chalk #EDEAD8 for highlights. Boots, satchel and sword grip from rust #9C4A2E and dusty tan #CBA878; sword blade in Chalk with Dusk #3A3566 shade. **No slate gray on Red** (slate is Hegemony). No pure black or pure white. No Call teal on her (reserved for the call).
- **Same hands:** mitten hands with a thumb bump (for the thumbs-up).
- **Same face sheet idea:** expressions live on the face texture, not in geometry, unless the prototype says otherwise. For the test, paint only two cells: **neutral** and **grin** (Red is a silent hero; her face and ears do all her talking, so the face has to work).
- **These are blockouts, not final art.** Ross makes Red's final model. Prototypes are simple placeholder builds in the target style, good enough to judge the look.

---

## A. Wind-Up Toy

**The idea:** Red as a sturdy painted toy you could wind up and set marching across a tabletop.
**Borrows from:** the Mega Man Legends / Tail Concerto strand: chunky, toy-like low-poly figures built from a few big parts, with small painted textures and simple painted faces.

**Proportions:** honors the huge-head ask. About **2 heads tall** (head is about 50% of her height). Head is a big rounded box (a cube with heavily cut corners, not a sphere). Body is a short, wide block hidden inside the jacket. Arms are short tubes ending in oversized mittens; legs are short stubs in big round boots. Nothing tapers: every part is a chunky piece that looks bolted on.

**Shapes and silhouette:** rounded-blocky. The up-ear is a thick, slightly pointed slab; the flopped ear is the same slab bent once and hanging past the cheek, so the two ears are clearly mismatched in black. The jacket is the torso: a wide trapezoid that flares at the hem, with sleeve cuffs as two fat rings that half-swallow the mittens. At 40 px: goggles read as a brass band with two bright dots across the top of the head; the lamp is an oversized brass block (about 0.15 unit tall) at the left hip with a Lamp glow pixel or two; the sword over the right shoulder reads as one clean diagonal line past the head.

**Surface:** small painted textures on a 128×128 body sheet: flat color areas with one painted shade step (darker tawny under the head, darker red in the jacket folds), chunky seams, a few patch squares and the hand-painted lamp on the back. Hand-dithered shading where a shade step is wider than a few pixels. Sits naturally with the PSX shaders: the painted texture is what the affine warp bends, so she gets the full wobble-and-warp PSX feel; vertex jitter makes the blocky parts shimmer slightly in motion; the 15-bit dither sits on top of the painted shades without muddying them.

**Face:** painted on the face sheet. Large upright oval eyes (Ink with one Chalk shine), small brows painted as short dashes so worry and determination read, tiny mouth. Muzzle is a separate cream block on the face, so the mouth sits on it and stays readable from 3/4.

**Build cost for Ross:** about **600–650 triangles**. 2 textures (128×128 body, 128×64 face). Rigging and animation ease: **4 of 5**. Separate stiff parts are exactly what rigid skinning is good at, and short limbs hide joint seams.

**Why it's timeless:** toys don't date; a well-made figure from a few honest shapes looks as good in 20 years as it did in 1998.
**Risk:** it is the "obvious" pick for our touchstones, so it needs Red's jacket and ears pushed hard to feel like ours and not like a generic PSX mascot.

---

## B. Button Pup

**The idea:** the simplest possible Red: a round head on a tiny body, so cute and plain that the jacket and ears do all the work.
**Borrows from:** the 2001 village-life strand (Animal Crossing era): huge-headed, simple-bodied villagers, flat colors, almost no surface detail, all character in the face.

**Proportions:** honors the huge-head ask, the most of all five. About **1.8 heads tall** (head is about 55% of her height). Head is a big smooth ball, slightly wider than tall. Body is a small capsule; arms are short stubs with round mitten ends; legs are two tiny stubby cylinders in round boots. From the front, the head is wider than the jacket.

**Shapes and silhouette:** round everywhere. The up-ear is a soft leaf shape; the flop-ear is a leaf folded down, sitting against the side of the ball. The jacket is a small bell shape, three sizes too big read as cuffs that hang past the hands and a hem down to the knees. At 40 px: head and ears are half the silhouette, so the ear pair is the strongest read in the game; goggles are a brass strip on top of the ball; the lamp is a fat brass lozenge at the hip; the sword on her shoulder is longer than she is tall, which is funny and reads instantly.

**Surface:** mostly flat **vertex colors** per part (no body texture at all, or one 64×64 sheet for the jacket patches and the lamp painted on the back). Only the face uses the face sheet. With the PSX shaders: vertex lighting and the 4×4 dither give her soft stepped shading for free, which suits a smooth ball. Because there is almost no texture, the affine warp has little to bend, so she reads cleaner and less "PSX" than A, C and E; jitter still makes her wobble.

**Face:** painted on the face sheet. Simple and graphic: two tall eyes set wide apart, a small muzzle shape, and a tiny mouth line. To keep it our own, her eyes are tall ovals with a shine, not plain dots, and her brows are painted so she can look determined (the face reads at a distance, which suits the huge head).

**Build cost for Ross:** about **420–480 triangles**. 1 to 2 textures (128×64 face sheet, optional 64×64 body). Rigging and animation ease: **5 of 5**. Almost nothing to bend; most acting is the head tilting, the ears and the arms.

**Why it's timeless:** simple round shapes and flat color never look old, because they never tried to look new.
**Risk:** the plainest of the five; next to MGS1-style moody spaces and chunky robots she may look too soft and too clean, and the village-life strand is the easiest to drift too close to, so the jacket, goggles and gear must stay loud.

---

## C. Picture-Book

**The idea:** Red as a character stepped out of a hand-painted storybook, soft and warm, made for close-ups and quiet moments.
**Borrows from:** the FF9 storybook-chibi strand plus the Legend of Mana / Dark Cloud picture-book softness: gentle proportions, hand-painted textures with drawn-in line work and soft (dithered) painted shading.

**Proportions:** a contrast to the huge-head ask, on purpose. About **2.5 heads tall** (head about 40% of her height), which is what docs/style_guide.md says today. Slightly longer arms and legs than A or B, a gently tapered body, so poses and gestures can act more. Shown so Ross can see the current guide side by side with the bigger-headed versions.

**Shapes and silhouette:** soft and organic: rounded head with a slightly pointed muzzle, a teardrop body, tapered limbs, boots with a little upturn. Up-ear tall and curved; flop-ear long and droopy, past the jaw. The jacket hangs in big folds, with the hem swinging off one side so the "three sizes too big" reads as cloth, not a block. At 40 px: the softer shapes read a little less crisply than A or B, so the ear pair and the jacket's red mass carry the read; the lamp is a warm brass shape with a Lamp glow dot; the sword is a long diagonal.

**Surface:** fully hand-painted 128×128 body texture with drawn-in line work in dark warm colors (Ink thinned toward rust, never black), painted folds and painted light from above, all shading hand-dithered. With the PSX shaders: the richest of the five under affine warping and dithering; the painted light can fight the room's vertex lighting if the paint is too strong, so keep painted shade to one or two steps.

**Face:** painted on the face sheet, the most detailed of the five: eyes with a lid line and a shine, painted brows, a small muzzle with a nose highlight, mouth shapes with a hint of cheek. Best of the five for cutscene close-ups.

**Build cost for Ross:** about **720–800 triangles**. 2 textures (128×128 body, 128×64 face), but each takes the longest to paint. Rigging and animation ease: **3 of 5**. Longer limbs show rigid-skinning seams at elbows and knees, so joints need overlap caps; more painting per character for the whole cast.

**Why it's timeless:** storybook illustration is a tradition far older than games, and it ages like a book, not like a console.
**Risk:** it's the most work for Ross for every future character, and it ignores his "big huge head, tiny body" ask the most of the five.

---

## D. Ink Line

**The idea:** Red as a clean, flat-color cartoon with a dark outline, like a moving animation cel.
**Borrows from:** the cel-shaded strand of 2000–2002 (Jet Set Radio, Skies of Arcadia's bright skies-and-pirates feel, and the then-upcoming Wind Waker): flat color fills, two-tone shading, outlines drawn by the engine. We take the flat color and the line, and **leave the street attitude** of the era's "cool" cel games: no graffiti edge, no sneer.

**Proportions:** honors the huge-head ask. About **2 heads tall** (head about 50%). Pear-shaped body (narrow shoulders, wide jacket hem), short limbs, big boots. Shapes are graphic and simplified, as if drawn with a marker, flatter than A's toy parts.

**Shapes and silhouette:** simple graphic shapes with clear outer edges, because the outline only looks good on clean silhouettes. Up-ear a crisp leaf, flop-ear a clean folded tab. Jacket as a big bell with two oversized cuff rings. At 40 px: the dark outline is 1 pixel all round, which makes her the sharpest, most readable of the five against any background; goggles, lamp and sword all get outlined, so even the small lamp pops.

**Surface:** flat color fills from a tiny **64×64 color swatch strip** (plus the back-of-jacket lamp painted there). Lighting is **cel shaded**: the vertex lighting is cut into two flat bands (lit and shade), shade band in a darker sibling of each color. Outline is an **inverted hull** (a second copy of the mesh, turned inside out, pushed slightly out and drawn in Ink). With the PSX shaders: jitter applies to both mesh and outline (so they must snap together or the line will swim); the 4×4 dither shows only at the band edge, which looks good; affine warping barely shows because there is almost no texture, so she reads more "2000s cel" than "PSX." The Technical Artist builds the two-band shader and the outline in the Compatibility renderer; this is new work, not in the style guide.

**Face:** **eye decals:** the eyes are two small alpha-cut quads sitting just in front of the face, using the face sheet. They can swap cells for blinks and expressions like the others, and because they are separate, the outline doesn't cross the eyes. Mouth and brows painted on the face sheet.

**Build cost for Ross:** base mesh about **400–440 triangles**, so with the outline hull the total drawn is about **800–880** (under the 900 cap; the sword likewise about 70 plus 70). 2 textures (64×64 swatch strip, 128×64 face sheet), the least painting of the five. Rigging and animation ease: **3 of 5**. The hull has to be skinned exactly like the body, and rigid skinning can show gaps in the outline at bending joints; Ross builds joints with overlapping caps.

**Why it's timeless:** a clean line and flat color is how animation has looked for a century; it never needs better hardware.
**Risk:** it's the furthest from the PSX look Ross approved (it is the next console generation's trick), it needs new shader work, and the outline halves the triangles left for shape.

---

## E. Rubber Bounce

**The idea:** Red as a springy cartoon mascot with giant mitts and giant boots, built to be a ball of motion and big gestures.
**Borrows from:** the playful-exaggeration strand of 1998–2001 3D platformers (Klonoa, Ape Escape, Rayman 2, Banjo-Kazooie era): bright rounded shapes, oversized hands and feet, squash-and-stretch poses, everything exaggerated for fun.

**Proportions:** a contrast to the huge-head ask, on purpose. About **2.8 heads tall** (head about 35%). The exaggeration moves to the hands and feet instead: mittens nearly as big as her head, huge round boots, thin-ish springy limbs (never thinner than 0.1 unit, the style guide floor). A slight forward lean in the neutral pose, as if she's about to take off running.

**Shapes and silhouette:** round and bouncy: a bean-shaped body, a rounded head with a big muzzle. Up-ear extra tall and springy; flop-ear long and swinging. The jacket is short and puffy, like a bomber with huge cuffs, so the big mitts burst out of it. At 40 px: hands and feet dominate, so the thumbs-up and the sword grip read huge (her gestures are her voice, and this makes them the loudest); the lamp is a chunky brass bulb at the hip; the sword reads as a big diagonal held in a big mitt.

**Surface:** small painted textures (128×128) in the brightest version of the palette, big simple color areas, one painted shade step, glossy-looking Chalk highlights painted on the boots and lamp. With the PSX shaders: plays well with jitter and warping (lively shapes wobble charmingly). Squash and stretch can't be done by bending under rigid skinning; it is done by keying bone scale, which the glTF export supports.

**Face:** painted on the face sheet, the most cartoon-elastic of the five: big eyes that change shape a lot between cells (wide surprise, squinting grin), a big mouth that can open wide on the grin cell.

**Build cost for Ross:** about **780–850 triangles** (the big mitts and boots eat budget). 2 textures (128×128 body, 128×64 face). Rigging and animation ease: **3 of 5**. The rig is the same, but the style asks for snappier, more exaggerated keys and bone-scale squash in every clip, which is more animating time.

**Why it's timeless:** rubber-hose cartoon energy has been charming people since the 1920s.
**Risk:** the smallest head of the five, which goes against Ross's stated ask, and its high-energy mascot look may clash with the game's long, sincere cutscenes.

---

## Side-by-side

| | A. Wind-Up Toy | B. Button Pup | C. Picture-Book | D. Ink Line | E. Rubber Bounce |
|---|---|---|---|---|---|
| Heads tall | ~2 | ~1.8 | ~2.5 (current guide) | ~2 | ~2.8 |
| Honors "huge head, tiny body" | Yes | Yes, the most | No (contrast) | Yes | No (contrast) |
| Triangles | 600–650 | 420–480 | 720–800 | 800–880 incl. outline | 780–850 |
| Textures | 128² + face | face (+ 64²) | 128² + face (heavy paint) | 64² swatch + face | 128² + face |
| Rig/animation ease (5 = easiest) | 4 | 5 | 3 | 3 | 3 |
| PSX shader fit | Full | Partial (little to warp) | Full | Weakest (new shader) | Full |
| New tech needed | None | None | None | Two-band shader, outline hull | Bone-scale keys |

---

## How the prototypes are shown

- **Static models only.** No animation. Each prototype stands in a **neutral pose** (relaxed stance, sword resting on her shoulder, lamp at her hip). An optional second pose: **thumbs-up** (one mitten raised), since it's her signature gesture.
- **Rendered in-engine with the full PSX look**: 384×216 internal resolution, scaled up by whole numbers with nearest-neighbor, vertex jitter, affine warping, 15-bit color with 4×4 dither, vertex lighting and blob shadow. In-game captures, not mockups (Ross asked for screenshots taken in the game).
- **Clean, neutral turntable stage:** a plain floor disc in a mid neutral (Dusk-ish, not a palette accent) against a Night background, so nothing competes with Red. **Identical lighting for all five:** the same ambient color, one warm Lamp-amber key light from front-left above, one dim cool fill from back-right. Same camera distances and angles for all five.
- **Shots per prototype (close camera, Red filling most of the frame height):** **front, 3/4, side, back** (the back shows the painted lamp on the jacket and the satchel).
- **One shot at true in-game scale:** the default diorama camera (40 to 45 degrees down, about 38 px tall on screen), Red standing next to a crate in the PSX test room (game/scenes/debug/psx_test_room.tscn). Also save the same shot in grayscale and as a solid-Ink silhouette, to check the style guide's two readability rules (she separates without color; you can tell who she is filled in black at 40 px).
- **One contact sheet:** all five side by side in columns A to E, rows: front, 3/4, side, back, in-game scale, silhouette. Labeled with the prototype letter and name only.
- **Where things go:**
  - Models: `game/art/placeholder/prototypes/red/chr_red_proto_a.glb` to `..._e.glb` (with textures beside them, same base names). Not loaded by the game.
  - Turntable scene: `game/scenes/debug/red_proto_turntable.tscn`.
  - Images: `docs/screenshots/red_prototypes/red_proto_<letter>_<front|34|side|back|ingame|gray|silhouette>.png`, and the contact sheet as `docs/screenshots/red_prototypes/red_prototypes_contact_sheet.png`.
- Share work in progress with Ross as it comes in (studio rule), and log it in docs/studio_log.md.

---

## Creative Director's recommendation

**A. Wind-Up Toy.** It gives Ross the big head and tiny body he asked for while staying closest to his own touchstones (Mega Man Legends, Tail Concerto) and to the approved PSX shaders, and its stiff, chunky parts are the cheapest look for him to rig and animate across the whole cast. If the contact sheet shows he wants the head even bigger, take B's head size on A's toy build. **The decision is Ross's.**
