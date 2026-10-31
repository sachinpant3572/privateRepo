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
- P1 blinded Opus-high grade (fix min): son-max 9 (2; only test catching the
  shader revert), son-xhigh 8 (4), opus-med 8 (4), opus-high 8 (5), opus-low 7
  (5), son-high 6 (8; keeps 260 KB images), son-med 5 (10; Medium: uniqueness
  check a no-op headless), son-low 3 (15; High: SCRIPT ERROR, gates unrun).
  All 8 ignore create_from_images' result (Low each).
- Bench cost: 14 builders + 2 graders $39.93 (raw, with lock-wait cache
  rewrites); main-session overhead not included.

## Final table (both packages; n=1 per cell)
Build $ = builder cost with cache writes capped at 130k (lock-wait rewrites
removed; P2 low/med/opus untouched). Review = trial 2 Opus-high per-package
reviews ($0.88 + $1.77). Fix $ = grader's fix minutes x ~$0.10/min main session
(estimate). Sonnet high = trial 2 runs.

| Builder | Grades P1/P2 | Build $ | Fix min | Total $ (build+review+fix) |
|---|---|---|---|---|
| Sonnet low | 3 / 3 | 1.93 | 30 | 7.58 |
| Sonnet medium | 5 / 3 | 1.72 | 25 | 6.87 |
| Sonnet high | 6 / 5 | 2.12 | 18 | 6.57 |
| Sonnet xhigh | 8 / 8 | 3.10 | 9 | 6.65 |
| Sonnet max | 9 / 9 | 8.40 | 5 | 11.55 |
| Opus low | 7 / 5 | 2.07 | 15 | 6.22 |
| Opus medium | 8 / 7 | 3.02 | 10 | 6.67 |
| Opus high | 8 / 5 | 3.28 | 15 | 7.43 |

Reading: higher effort mainly buys catching a wrong brief (P2: xhigh, max,
opus-med corrected the half-side formula; opus-high and son-high used
half-diagonal). Totals for the mid combos sit within ~$1 of each other, which
n=1 cannot separate. Wall time: xhigh/max far slower (P2 39k/168k output
tokens vs 21k for opus-high). Opus low/medium sit below the CLAUDE.md effort
floor (high).
Recommendation: Sonnet xhigh builders + Opus high main session and per-package
Opus review, provisionally; confirm with a finalist run (son-xhigh, son-max,
opus-med, opus-high; 3 repeats x 3 packages, ~$100-150, half a day) on Sachin's
word.

## Anthropic article (2026-10-22, Sachin asked 2026-10-30)
"Building agents: When to fold subagents into your main agent loop"
(claude.com/resources/articles/...). Keep subagents for: context bloat,
parallel work with fresh disposable context, tool-selection trouble; also
verification. Otherwise one loop with skills/tool search; split by context,
not problem type; handoffs are a "telephone game". Fit to us: CLAUDE.md
already builds in the main session and keeps agents for big reads, parallel
separate-file packages >= 20 min, and the independent review. The two bench
packages (3-27 min) are below that bar; P2's wrong formula came from the
main session's brief (a lossy handoff). Proposal (Sachin decides, desktop
file): small packages stay in the main session; builders (Sonnet xhigh) only
for long parallel separate-file packages.

## Follow-up test (Sachin, 2026-10-30: "create the scheduled task for next week
after the reset, at around 11AM on Tuesday, to test that 3 setup with 3 jobs")
Runs as its own session, Tue 2026-11-03 11:00 IST. Arms: S = Sonnet xhigh
builder + per-job Opus-high review; O = Opus high builder + per-job review;
M = main session does the job (a `fork` agent, so it inherits a real main
context), no per-job review. 3 jobs x 3 repeats per arm = 27 runs.
- Jobs: replays of 3 past small reviewed fixes (not the flame or cull ones),
  each a one- or two-file change with a test, from its base commit, reviewed
  final as reference. No new game features.
- Same brief per job for all arms; hidden test + mutation check + one blinded
  Opus-high grader per job; costs from subagent logs (cap lock-wait cache
  writes as above). Waves of <= 4 builders to keep the Godot lock queue short.
- Report: grade mean/spread, cost incl. review and fix, wall time, per arm.
