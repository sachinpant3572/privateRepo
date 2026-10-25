# Stress test

A one-screen Godot 4.7 test app that checks how many enemies, bullets and
explosions a cheap Android phone can run smoothly. It's step 3 of the plan in
[docs/casual-android-game-research.md](../../docs/casual-android-game-research.md).
It uses the engine and techniques the report recommends for the real game.

## What it runs

- **Enemies** (pink) close in on the player from all sides. Each takes 3 hits,
  flashes white when hit, and respawns at an edge when killed.
- **Bullets** (cyan) fire from the player in a spinning 6-stream spiral. They
  pass through enemies, so the bullet count stays steady.
- **Explosions** (orange particles) burst on each kill, with a light screen
  shake.
- **Autopilot:** the player moves on a fixed path, so every phone does the same
  work. Drag anywhere to take over for 2 seconds.

How it's built:
- Each type is drawn with one MultiMesh, which is one draw call.
- Positions live in packed arrays.
- Bullet hits use a spatial hash grid instead of the physics engine.
- The renderer is Compatibility (OpenGL ES 3), the safe choice on budget GPUs.

## Tests

| Button | What it does |
|---|---|
| Quick check | 500 enemies + 1,000 bullets until you tap Stop |
| Auto ramp | Starts at 100 enemies + 200 bullets and grows 25% every 6 s (at least +100), up to 20,000 enemies. Stops at the first level that can't hold 92% of the target frame rate (55 FPS at a 60 cap). Logs FPS and game-logic time per level |
| 5-minute heat soak | 500 + 1,000 for 5 minutes. Logs FPS and the phone's heat level every 10 s, to show whether the phone slows down as it warms up |
| Heavy / Extreme | 1,000 + 2,000 and 2,000 + 4,000 |

Settings:
- **Effects:** turn explosions, flashes and shake on or off.
- **Frame-rate cap:** 60, 30, or none. With no cap, the test runs at the
  screen's refresh rate (e.g. 120 Hz), which shows how much headroom a fast
  phone has.
- **Heat sensor:** on or off. It uses Android's thermal status (Android 10+)
  and headroom (Android 11+).

Every result also shows **game-logic time per frame**. That's the CPU time for
moving, firing and hit checks, and it runs out first on cheap phones. A 60 FPS
frame has 16.7 ms in total, and drawing needs part of that.

## How to install

1. Get `stress-test.apk`. The build sends it to the chat, and it's also on the
   `stress-test-builds` branch of this repo.
2. On the phone, open it and allow "Install unknown apps" for your browser or
   file manager when asked.
3. Each build is signed with a new throwaway key. Before installing a newer
   build, uninstall the old one, or Android will say "App not installed".

## What to send back

Run, in this order, on your cheapest phone (unplugged, normal brightness):
1. Quick check for about 30 seconds.
2. Auto ramp.
3. The 5-minute heat soak.

After each test, tap **Copy results** and paste the text into the chat. Also
say how it felt: smooth, or stuttery.

## How it's built

`.github/workflows/stress-test-apk.yml` runs on every push that touches this
folder:
1. Downloads Godot 4.7.2 and its export templates from the official
   `godotengine/godot-builds` releases and checks them against the official
   SHA-512 checksums.
2. Runs a headless smoke test (`godot --headless -- --smoke`). This runs each
   test mode briefly and fails on any script error.
3. Exports a release APK (arm64-v8a and armeabi-v7a).
4. Uploads the APK as a build artifact and to the `stress-test-builds` branch.
