# One-button combo (Kingdom Hearts style)

> **For Ross:** you picked B. There is now **one attack button**. You mash it and Red picks the right move for the situation: a string of hits that ends in a launcher, a lunge when the enemy is far away, a spin when she is surrounded, an air string that follows a launched enemy up. The second button (K, right mouse, Y) is kept free for Red's hacker abilities; for now it only pops up "Hack: coming later". All the rules are data in `game/data/combat/combo.json`, so you can tune them without code. Nothing here is built yet: the Combat Programmer builds the selector next.

## What one press does

| Situation when you press | Red does |
|---|---|
| Enemy far away (4.5 to 12 m) | **Lunge**: dashes up to 5 m at it, stops just short, thrusts. Counts as hit 1 |
| Enemy close, you on the ground | **Light 1**, then Light 2, then Light 3 |
| After Light 3, normal enemy | **Launcher**: pops it into the air |
| After Light 3, three or more enemies close | **Sweep**: a full spin that hits everyone around her |
| After Light 3, enemy is guarding or armored (the Brute) | keeps hitting: Light 1, Light 2, then the **Heavy slam**, which breaks the guard |
| Enemy is in the air, you on the ground | Red **jumps up** to it and starts the air string |
| You just launched it | Red **follows it up** automatically (the existing follow-jump) |
| In the air | **Air 1, Air 2, Air 3**: Air 3 slams it down |

So a normal fight is: press, press, press, launcher, up, press, press, press, slam. Nothing to remember.

## The rules (in plain words)

- Each press checks the situation: how far the target is, whether you or it are in the air, whether it can be launched or is guarding, how many enemies are close, and where you are in the string.
- It follows the **first rule that fits**, top to bottom, in `combo.json`. Rules are short and readable (`from`, `when`, `next`, and a one-line `why`).
- **Finishers** are the launcher, heavy slam, sweep and air 3. After one, the string starts over.
- A string forgets itself 0.5 s after Red stops attacking.
- **Timing is the same as before:** a press is accepted in each move's cancel window; press early and it waits and fires at the right frame. Dash, jump and guard still cancel out of attacks.
- Normal string is 3 hits plus the finisher. Against a guarding or armored target it is 5 hits plus the slam, so the extra Lights chip the guard before it breaks.

## What changed in the data

- **New file** `combo.json`: the buttons, the numbers (near/far distances, string length), the situation words, the rules, and an example of each string.
- **Two new Red moves in `moves.json`**, both reusing existing clips: `lunge` (clip `light_3`, a quick thrust that travels 5 m) and `sweep` (clip `air_3`, the spin, on the ground).
- The old Heavy, Launcher and the three Lights are unchanged; they are just reached by the rules now instead of by separate buttons.
- The second button's call-out text is in `combo.json` (`buttons.hack`).

## What the Combat Programmer builds

1. A pure selector (`ComboSelector`): situation in, next move id out, reading `combo.json`. Unit tests for every rule.
2. `ActionPlayer`: the attack button asks the selector. The Heavy button shows "Hack: coming later" (a HUD pop-up from the UI Programmer) and does nothing else.
3. The `lunge` travel (stop 0.9 m short of the target, up to 5 m) and the `follow_jump` prefix on `rise_to_juggle` and `launcher_follow`.
4. The `launcher_input` feel knob and its three modes are no longer used. They can stay, hidden, until Ross says to remove them.

## Notes and open points

- Controls card, Config screen and button labels need the new wording ("Attack", "Hack (coming)"): UI Programmer.
- Parry and dash are untouched.
- Magnetism is already generous (tuning log), which is what makes the lunge and the air string find their target.
- Mixing: since you can no longer choose Heavy or Launcher on purpose, a "Light, Light, then wait" string is the only way to vary things. If it feels too automatic, the cheapest fix is holding the attack button for the finisher; that would be a new mechanic, so it would come to you first.
