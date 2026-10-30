# Builder model benchmark (2026-10-30)

Sachin, 2026-10-30: "So what do you recommend? Should we try a mix of Sonnet
5.5 Low + Opus 5.5 High, or Sonnet 5.5 Medium + Opus 5.5 High, or Sonnet 5.5
Extra High + Opus 5.5 High, or Sonnet 5.5 Max + Opus 5.5 High for Subagent +
Main Agent (Orchestrator) distribution? Or should it be Opus 5.5 Low/Medium +
Opus 5.5 High? ... Can you check all these reliably and then let me know?"

## Answer to "how are you so sure" (honest)
The trial 2 "at Opus prices" figure ($3.43) was Sonnet's own token counts
priced at Opus rates. No Opus builder ran those packages, so it assumed Opus
uses the same tokens. Not a measurement.

## Design (screening, n=1 per cell)
- Replay both trial 2 packages with the exact trial 2 briefs (paths changed
  to a per-run worktree, plus a shared-lock setup note), each in a detached
  worktree at its original base: P1 flame Texture2DArray from d2dde41, P2
  cull margin from 846616f. Worktrees /home/user/bench/p{1,2}-<combo>, logs
  /tmp/bench/<id>/, briefs in the scratchpad bench/ folder.
- Builders: Sonnet 5.5 low/medium/xhigh/max, Opus 5.5 low/medium/high.
  Sonnet high = the trial 2 runs (same briefs).
- Waves to keep the Godot lock queue short: all 7 P2, then P1 in 4 + 3.
- Quality: hidden checks run by the main session (P2: the final committed
  far-corner test from 28aaf74 dropped into each worktree; P1: SCRIPT ERROR in
  the builder's own test log, create_from_images result checked, shader-only
  revert caught, image memory kept, shots 16/16) plus one blinded Opus-high
  grader per package scoring all 8 diffs against the trial 2 review findings.
- Cost: per-agent token usage from the session's subagent logs, API list
  prices (Opus $4 in / $20 out / $5 cache write / $0.20 cache read; Sonnet
  $2 / $10 / $2.50 / $0.20).
- Estimate before launch: 16 agents, ~$25-40, 2-3 h. Cheaper option: no runs
  (answer from trial data only). Reliable option: 3-5 repeats per cell on more
  packages, ~$150-300 and most of a day (needs Sachin's word).

## Results
(in progress; raw notes, filled into a table at the end)
- P2 son-max: far corner x curve peak (matches the reviewed fix), +152 lines,
  148k tokens, 41 min, no first-run fails; flagged FireFx.curve clamps peaks >1.
- P1 son-low: stopped INCOMPLETE. Edits done but gates 2-4 were not run (it gave
  up waiting on the shared Godot lock). Its first before-shot run wrote no PNGs
  (dir not made). The main session reruns its gates in the hidden checks.
- P2 son-xhigh: far corner x max(min,max) x curve peak (matches reviewed fix),
  +105 lines, 159k tokens, 63 min wall (lock waits), no first-run fails;
  flagged the blast flash billboard. Stopped p1-son-low (it kept re-sending).
- Confound: the shared Godot lock queue (up to ~8 deep) cost wall time and made
  some builders' background waits time out; wall time is not a model measure.

- P1 son-max: all 4 gates pass, +81/-21, own test fails on old code (mutation),
  checks shader declares sampler2DArray; added _flame_layers() helper (headless
  get_layer_data is null); flagged saved-count gate misleading without mkdir.
- P1 son-xhigh: all 4 gates pass, +63/-15; first-run SCRIPT ERROR (get_layer_data
  null headless) caught and fixed via flame_images() helper; noted PASS row can
  hide a SCRIPT ERROR; no shader-declaration check in its test.
- P1 opus-med: all 4 gates pass; first test run failed 2 checks (get_layer_data
  null headless), fixed via _flame_images() helper; restores global state; no
  shader-declaration check in its test.
