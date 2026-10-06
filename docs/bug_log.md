# Bug Log

> Logged by QA tester, text checker, asset checker, and playtester. Fixed by staff as assigned by the Producer.
> Severity: crash / major / minor / polish · Status: Open / Fixing / Fixed / Won't fix

| # | Title | Severity | Steps to reproduce | Expected | Actual | File involved | Reported by | Status |
|---|---|---|---|---|---|---|---|---|
| B1 | Two movement tests failed once, then passed on re-runs | minor | Run the full suite while other Godot processes are busy on the same machine | Always pass | test_distance_travelled_matches_speed and test_movement_is_relative_to_the_camera failed once (timing-dependent under load) | game/tests/integration/test_player_move.gd | Technical Artist (seen), studio floor (re-ran 3×: pass) | Open: Gameplay Programmer to make them frame-time independent |
