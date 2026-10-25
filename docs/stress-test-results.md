# Stress test results

Results from `games/stress-test/` on real phones. Each test is described in
[games/stress-test/README.md](../games/stress-test/README.md).

## Samsung Galaxy S25 Ultra (SM-S938B), Oct 25, 2026

A flagship phone (Snapdragon 8 Elite, Adreno 830, 120 Hz screen, Android 16).
These results are the ceiling, not the floor.

| Test | Build | Result |
|---|---|---|
| Fixed 2,000 enemies + 4,000 bullets, 60 FPS cap | v1 | 60.0 FPS average and in the worst 1%; 0 slow frames in 56 s |
| Auto ramp, 60 FPS cap | v1 | Reached the old test maximum (4,000 + 8,000) at 60 FPS |
| Auto ramp, no cap (120 Hz) | v2 | Held 3,900 + 7,800 at 118 FPS; failed at 4,850 + 9,700 (97 FPS) |
| 5-minute heat soak, 500 + 1,000, 60 FPS cap | v2 | 60 FPS in every 10 s sample; heat "none" throughout; 1.1% slow frames, worst 1% 27.9 FPS |

### Game-logic time per frame (auto ramp, no cap)

| Enemies + bullets | FPS | Logic avg | Logic worst |
|---|---|---|---|
| 100 + 200 | 120 | 0.6 ms | 3.6 ms |
| 500 + 1,000 | 120 | 2.2 ms | 3.8 ms |
| 1,100 + 2,200 | 120 | 4.5 ms | 7.3 ms |
| 2,050 + 4,100 | 120 | 5.2 ms | 13.6 ms |
| 3,900 + 7,800 | 118 | 7.0 ms | 13.8 ms |
| 4,850 + 9,700 | 97 | 9.3 ms | 17.8 ms |

### What it means
- **The limit is processor time spent in GDScript, not graphics.** At 120 FPS a
  frame has 8.3 ms. The ramp failed at the level where game logic alone went
  over that.
- **Light loads read slower than they are.** Logic time grows much more slowly
  than the load (8x the enemies, about 3x the time). The phone probably runs
  its processor at low speed under light load. So small-load numbers overstate
  the per-enemy cost.
- **Estimate for budget phones (not yet measured):**
  - Their processors are roughly 3–7x slower per core.
  - At 500 + 1,000, game logic would take about 7–15 ms of the 16.7 ms frame
    at 60 FPS, which is borderline.
  - Expect about 200–400 enemies at 60 FPS with GDScript.
- **Fix if needed:** move the enemy, bullet and hit-check loop to C++
  (GDExtension) and keep everything else in GDScript.
- **Heat:** no throttling over 5 minutes on this phone.
- **Hitches in the soak** (1.1% of frames over 25 ms) aren't from game logic,
  which peaked at 9.4 ms. They are likely frame-pacing jitter from a 60 FPS cap
  on a 120 Hz screen. Handle frame pacing in the real game.
- **Device info:** RAM and chip read "unknown". This phone blocks
  `/proc/meminfo` and `/sys/devices/soc0` for apps. The model name is enough
  to look up the specs.

## Budget phone

Not tested yet. This is the result that decides the enemy budget for the game.
