# 0.25.2: hero animations (run, walk, sprint, fighting)

Sachin, 2026-10-29: "The Hero-s running animations too are very primitive,
same for his other actions."

## What was wrong (filmstrip `char_shots.tscn -- <dir> motion`, before)

- Arms: both swing about the vertical, so at a jog and sprint the hands
  reach forward to chest or face height (open hands, "zombie" look) and
  barely go behind the hip. Real running arms swing mostly behind the body
  with the elbow near 90°.
- Legs: thigh = sin(phase) x amplitude, so the stride got wide by raising
  the amplitude: the sprint looked like a lunge, with a straight trailing
  leg, no knee drive, no heel kick under the hips and no flight phase.
- Every joint eases toward its target at rate 16, a low-pass filter that
  costs a 1.4 Hz jog about 30° of phase and 12% of amplitude (more on the
  knee's faster harmonics), so the gait looked mushy.
- The hero's velocity jumps 0 -> 4.2 m/s in one frame: no start or stop.
- Punch: one linear extend with no wind-up, hips or weight shift. Kick:
  lift and straighten. The guard is a static pose.

## Decisions

- Legs are driven by the feet (foot placement and two-bone IK), the usual
  way good procedural locomotion is done. Per gait (walk, run, sprint,
  blended by speed): cadence and duty factor from running data, the stance
  foot planted and sliding back at exactly the ground speed (no skating),
  heel-strike to toe-off roll, an authored knee flex in stance that sets
  the pelvis height (walk: vault over a straight leg; run: compress), a
  ballistic flight between toe-off and the next contact, and an ankle path
  through swing (low in a walk, heel up under the hips in a run, high
  knee drive in a sprint). IK turns the ankle path into thigh and knee.
- Arms swing about a backward-biased centre with elbow flex rising from
  walk to sprint; the forearm crosses slightly toward the midline in front.
- Locomotion bones ease at a high rate while moving (near direct), so the
  curves show as authored; transitions still ease.
- Hero gets acceleration (about 0.2 s to full jog, a bit quicker to stop),
  so starts and stops lean and step instead of snapping.
- Punches get anticipation, a fast strike with hip and shoulder turn and a
  rear-heel pivot, then recover to guard; the second strike is a hook; the
  kick chambers, thrusts from the hip with the body leaning back and arms
  balancing, and re-chambers. The guard bounces like a boxer's.
- Shared rig: every person gets the new gait (styles keep their arms and
  tweaks). Cost per person per frame stays a few dozen trig calls.

## Options (cost)

- Chosen, A: procedural foot-placement gait + new fight moves, about 3-4 h.
- Not now, B: car door enter/exit animation (walk to the door, open it,
  sit) needs doors as separate meshes on every vehicle model, about 4-6 h.
- Not now, C: finger bones for fists (re-skin the body data's hands),
  about 2-3 h. Without them the hands stay open.
- Rejected: imported mocap clips. The skeleton has 17 bones and the
  network to fetch CC0 libraries is uncertain; retargeting is a project.

## Traps

- Skeleton rest (hero): hip 1.006, knee 0.550, ankle 0.077 (sole -0.03),
  toe tip 0.22 ahead of the ankle, heel 0.08 behind; all bone bases are
  identity (y along the bone), +x on a leg swings it forward (-z).
- Final numbers (rig.gd _locomotion): arm centre lerp(-0.08,-0.26,g)+0.08
  sprint, amplitude lerp(0.27,0.52,g)+0.38 sprint, elbow up to 1.7, bend
  lerp(0.12,0.3,g)+0.1 sprint. Swing tangent at touchdown and lift-off:
  all of the ground speed in a walk, 0.88 in a run (lower slipped 4-5 cm
  per sprint contact). Player ACCEL 18, DECEL 26 m/s². Punch/kick ease rate
  42. Fight poses: _guard, _fight_legs, _punch (right cross, left hook),
  _kick (chamber, thrust, re-chamber).
- Euler order YXZ: abducting the upper arm (z) and flexing the elbow sends
  the forearm up; aim the forearm with its .y twist instead (L_FORE.y + is
  toward the midline).
- Tests run only if listed in the array near the top of test_runner.gd.
  Bone poses for measurement need the skeleton in the tree plus
  force_update_all_bone_transforms().
- Skate test measures slip per contact (sum of |v - s|/60), < 3.5 cm,
  median speed within 5%; per-frame edge speeds are naturally off.
