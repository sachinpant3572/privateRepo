## Common rules for every package (read first)

Repo: your worktree (its root is `git rev-parse --show-toplevel`; all paths below are relative to it, never edit /home/user/privateRepo itself). Game: game/ (Godot 4.7.2, GDScript, mobile/Android target, top-down/perspective camera). Read CLAUDE.md (the cloud working rules) and game/README.md sections you need; HANDOFF-hill-content.md is the task's decisions note.

Sachin's request (word for word): "Build the content, and then the tunnels and bridges". This session's order from him: "...Then phase 3 (races, stunt jumps, cycling, parachuting, bungee) and phase 4 (tunnels and bridges)."

- Godot: `godot` is on PATH. EVERY godot run goes under `flock /tmp/godot.lock` (other agents share the machine). In a fresh worktree run `cd game && flock /tmp/godot.lock godot --headless --import >/dev/null 2>&1` once.
- Focused tests, from game/: `ONLY=test_a,test_b flock /tmp/godot.lock timeout 900 godot --headless --fixed-fps 60 res://tests/test_runner.tscn > /tmp/<pkg>_only.log 2>&1; echo "exit $?"; grep -E '^(PASS|FAIL) |FAILED:|checks passed|SCRIPT ERROR|^ERROR|Parse Error' -A2 /tmp/<pkg>_only.log`. Passed only with a PASS row per name and no FAIL/SCRIPT ERROR/ERROR line. The runner does NOT fail on SCRIPT ERROR: grep for it.
- New tests go in a new module file tests/<pkg>_tests.gd (`extends RefCounted`, `const TESTS := [...]`, funcs `test_x(t)`; `t` is the runner: t.check(cond, msg), t._new_game(false), t._frames(n), t._place_player_at(pos), t.game). Follow tests/hunting_tests.gd as the model. Register the module by appending its path to TEST_MODULES in tests/test_runner.gd (that one-line edit is allowed).
- Screenshots for visual changes: xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --resolution 1280x720 <scene> -- /tmp/<pkg>_shots/ (under flock; one folder per package, never shared). When reading more than 4 images, tile them first: tools/contactsheet.sh <folder> --out <prefix> [--tile 400] and read the sheets; crop for small detail.
- The lock is shared with the main session's full suite (about 15 min): run godot commands with a Bash timeout of at least 1200000 ms or with run_in_background, so waiting for the lock does not kill them. If a run prints only the Godot banner and hangs, check `pgrep -af godot` before retrying. The user:// data dir is shared by every worktree, so tests must not rely on a leftover save.
- Logs to /tmp with your package letter in the name (/tmp/<pkg>_*.log), never the repo. Read code with grep -n then ranges of <=150 lines. Do not run the full suite (the main session does).
- Do not touch files outside your package's list. Shared files you may NOT edit: main.gd, hud.gd, player.gd (unless your list says so), anything another package owns. Instead, write the exact patch the main session must apply (file, anchor line, code) into your report and into your HANDOFF note. Expose your node with a small API so main.gd can create it (`X.new(); x.game = self; add_child(x)` style, as hunting.gd).
- Keep a short decisions note HANDOFF-<pkg>.md at the repo root (<80 lines): decisions, traps, open items, patches for the main session.
- Commit on your worktree's branch with clear messages ending with:
  Co-Authored-By: Claude <noreply@anthropic.com>
  Do not push. Do not include any model name in commits or code.
- Original content only: fictional names, no real brands. No real-world weapons beyond what exists.
- Report at the end (under 400 words): what you built (files, API), tests and their pass lines, screenshots taken and what you saw, the patch for main.gd/hud.gd/player.gd, open items. Effort floor: work carefully; quality over speed.
