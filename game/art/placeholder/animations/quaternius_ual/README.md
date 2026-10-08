# Quaternius Universal Animation Library 1 + 2 (Standard, free)

Placeholder animations (Ross, 2026-10-08: "just find some basic prefab animations for now, something open source or free").

- Source: https://quaternius.itch.io/universal-animation-library and https://quaternius.itch.io/universal-animation-library-2 (free "Standard" downloads), by Quaternius.
- License: CC0 1.0 (public domain); see LICENSE_UAL1.txt / LICENSE_UAL2.txt. No credit required (credit is welcome).
- Files: the "Unreal-Godot" GLBs without baked root motion (the game moves characters in code). Unity FBX, the _RM root-motion versions and the female mannequin were left out.
- Skeleton: 65-bone UE-mannequin-style humanoid (root, pelvis, spine_01..03, neck_01, Head, clavicle/upperarm/lowerarm/hand, fingers, thigh/calf/foot/ball), to be retargeted onto Red and the wolf with a Godot BoneMap.
- UAL1 (43): idle, walk, jog, sprint, jump start/loop/land, roll, crouch, hit chest/head, death, punches, Sword_Idle, Sword_Attack, pistol, spell, sitting, swim, interact.
- UAL2 (43): Sword_Regular_A/B/C (+ recoveries) and combo, Sword_Heavy_Combo, Sword_Block, Sword_Dash, Hit_Knockback, LayToIdle (get-up), NinjaJump, Slide, Melee_Hook, Shield moves, Zombie idle/walk/scratch, climb, throw, farming.

## Where they are used (Animator, 2026-10-08)
Retargeted offline onto Red, the Cyberwolf Sentinel and the sandbox Brute by `scripts/tools/retarget_ual.py` (settings in `data/animation/retarget_*.json`); the results are the `*_rigged_ual.glb` / `enm_sandbox_brute_ual.glb` files beside those rigs, each with an `ANIMATION_CREDITS_*.txt`. The source files here are never edited. See "Animator: the free Quaternius clips" in `docs/pivot/combat_api.md` (Changes).
