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
- P1 son-med: all 4 gates pass; first test had a SCRIPT ERROR yet printed PASS
  (caught); its fix makes the uniqueness check skip headless (0 layers read), so
  that check never runs in the suite (weaker test). No shader check.
- P1 opus-low: all 4 gates pass, +52/-11; first test had SCRIPT ERROR yet PASS
  (caught), fixed via public flame_images(); no shader check.
- P1 opus-high: all 4 gates pass, +78/-19; first test run failed 2 checks
  (get_layer_data null headless), fixed via _flame_images() helper; restores
  cache; no shader-declaration check in its test.
- P2 hidden far-corner test (base 846616f fails it 3/20): PASS son-xhigh,
  son-max, opus-med; partial (3 pass/8 fail, half-diagonal margin ~0.82 vs 1.48
  needed) son-high, opus-low, opus-high; FAIL 3/20 son-low, son-med (half
  longest side = what the brief literally said). Passing = caught the brief's
  error.
- P2 builder tokens: son-low 91k, son-med 97k, opus-low 95k, opus-med 114k,
  opus-high 123k, son-max 148k, son-xhigh 159k.
- P2 blinded Opus-high grade (1-10; est. main-session fix min): son-max 9 (3),
  son-xhigh 8 (5), opus-med 7 (6), son-high 5 (10), opus-low 5 (10),
  opus-high 5 (10), son-low 3 (15), son-med 3 (15). Only son-max's test fails
  on a half-diagonal/half-side formula. son-high (trial 2) is byte-identical
  to the original 70ef924. Grader $ in the cost table.
- P1 hidden test (array, 6 layers, 64x128, mips, sampler2DArray + vec3, shape,
  cached): all 8 PASS. son-low's own test logs SCRIPT ERROR (get_width on null,
  headless get_layer_data) yet prints PASS (never ran its gates). Shader-only
  revert (sampler2DArray -> sampler2D): only son-max's own test FAILs; the
  other 7 still PASS (a SHADER ERROR is logged, the tests don't notice).
- Cost confound P1: lock waits > 5 min expire the agent's prompt cache, so P1
  cache writes (0.35-1.14M tokens) mostly measure waiting, not the model. P2
  (short queue for low/med/opus) is the cleaner cost comparison.
