# Bug Log

> Logged by QA tester, text checker, asset checker, and playtester. Fixed by staff as assigned by the Producer.
> Severity: crash / major / minor / polish · Status: Open / Fixing / Fixed / Won't fix

| # | Title | Severity | Steps to reproduce | Expected | Actual | File involved | Reported by | Status |
|---|---|---|---|---|---|---|---|---|
| B1 | Two movement tests failed once, then passed on re-runs | minor | Run the full suite while other Godot processes are busy on the same machine | Always pass | test_distance_travelled_matches_speed and test_movement_is_relative_to_the_camera failed once (timing-dependent under load) | game/tests/integration/test_player_move.gd | Technical Artist (seen), studio floor (re-ran 3×: pass) | Fixed (Gameplay Programmer): both tests now switch Red's physics off and call step() by hand, so they count exact steps instead of real frames; awaiting QA re-check |
| B2 | Red's animation-state test failed once under load, passed alone | minor | Run the full suite while other agents run Godot on the same machine | Always pass | test_movement_states_map_to_clips_with_the_real_model failed once in a full run; passed with --only=red_shiba | game/tests/integration/test_red_shiba.gd | Audio Designer (seen), Technical Artist (seen earlier) | Open: make it frame-independent like B1 (drive step() by hand) during M2 integration |
