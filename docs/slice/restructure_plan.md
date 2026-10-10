# Slice restructure plan: build 5 (estimate for Ross)

> For Ross, 2026-10-10. From your build 4 notes and answers (docs/decisions.md, 2026-10-10). **Nothing is built until you approve this.** Fun first is the test for every item.

## What changes, in one line each
1. **New action opening** (5 to 10 min): camera behind Red, one enemy at a time, the level itself teaches every button (jumps over gaps, ledges, a hack target, a dash gap). No "press X" pop-ups.
2. **Town after the opening**, rebuilt small and tight (Kalm / Lindblum / Mega Man Legends market feel): 3 or 4 places, each with one obvious job, growing as you play.
3. **Always know where to go:** an objective line on screen, a marker over the next person or door, and a map with the goal marked.
4. **Junkyard untangled:** one clear route to the loader and on to the colossus, with landmarks, lights and the marker pointing the way.
5. **Lights On switched off** in the slice (code kept).
6. **New order:** opening → town → junkyard → boss → back to town.

## Itemized roadmap

| # | Step | Who | Studio time | Needs you? |
|---|---|---|---|---|
| 1 | **Design (no code):** opening level map with its teaching beats; compact town map; junkyard route fix; new story order | Creative Director, Level Designer | 2 to 3 hrs | **Yes: approve the two maps** |
| 2 | Lights On off, camera behind Red by default | Combat Programmer | under 1 hr | No |
| 3 | Objective line, world marker, map screen | Gameplay + UI Programmers | 3 to 4 hrs | No (you see it in build 5) |
| 4 | Opening level graybox (one enemy at a time, environment teaching) | Level Designer | 3 to 4 hrs | No |
| 4b | *Optional:* wall-running (see the decision) | Combat Programmer + Animator | +3 to 4 hrs | **Yes: the decision** |
| 5 | Compact town rebuilt, with "people move in" growth | Level Designer + Gameplay Programmer | 3 to 4 hrs | No |
| 6 | Junkyard route fix to the loader and colossus | Level Designer | 2 to 3 hrs | No |
| 7 | New story order and placeholder lines | Gameplay Programmer + Writer | 2 hrs | No (real script is Phase 2) |
| 8 | QA (bot plays it start to finish), fun and pacing pass, fixes | QA Tester, Playtester, owners | 3 to 4 hrs | No |
| 9 | **Build 5 (Mac) to you** | Studio lead | 1 hr | **Yes: play it** |

Steps 2 to 7 run side by side once you approve the maps, so the total is shorter than the sum.

## Time
- **Studio time:** about 20 to 25 hours of agent work (24 to 29 with wall-running).
- **Clock time:** about **12 to 16 hours** from your map approval to build 5, with several roles working at once.
- **Your time:** two short approvals (the maps, and the wall-run decision), then one play session.
- **Pushes to GitHub:** steady, in small commits as each step lands. The finished build 5 code is pushed about **a day after you approve the maps**, unless the monthly spend limit pauses us.

## Cost
- I can't see your bill or your limit, so this is in amounts of work. The last push (finishing Phase 1: the robot round, loader run, hookups, QA, feel pass and fixes) used about **3.5 million tokens** of agent work.
- **This restructure is about the same size: 3 to 4 million tokens** (4 to 5 million with wall-running).
- **Risk:** we hit the monthly spend limit twice before. If it's close, I can split this into two halves: first the opening and the direction tools (steps 1 to 4), then the town and the junkyard (steps 5 to 9).

## Not in this round
The real script, the looks, music and your art stay in Phase 2, after you've played build 5.
