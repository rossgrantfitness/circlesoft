# Decisions Log

> Every decision Ross approves, dated, newest at the top. Owner: Producer.
> If it isn't here (or on the task board), it isn't approved, so don't build it.

| Date | Decision | Options considered | Why |
|---|---|---|---|
| 2026-10-05 | Merge the studio setup into the main version of the project so every future session starts with the full studio. | A: merge into main · B: leave on a side branch | One click for Ross; staff, rules and Godot auto-install apply to every new session. |
| 2026-10-05 | Godot is reinstalled automatically at the start of each cloud session by a startup script kept in the project (.claude/hooks/session-start.sh). | A: startup script in the project · B: install step in the cloud environment settings | Hands-off for Ross and travels with the project. Costs about 30 seconds per session start. |
