# HANDOFF: Bellerive on a California street plan, plus skyscrapers, monuments and shady districts

Task (Sachin, 2026-10-27, after the v3 APK): "Right now Bellariv looks like a messed up version of
all cities I told you, because of popr district, and Road build. It looks more like Delhi in India
right now in the latest apk. I mean the streets look ao diagonal, literally all of them are
diagonal, not parallel in your map. I can under some parts having diagonal, uneven roads, few of
them but rest all have bigger parallel roads. Check California's map from top down and then
research thoroughly. Also, add skyscrapers, monuments, all fictional, shady places, ghettos etc
too. Check Californias map from fully zoomed out view from.top down, and the multiple shots of
zooming in, into multiple districts and regions of its. Also see what each region stands for,
what they have, and then we will be replicating the same in our Bellariv city"

This supersedes the street layout in `HANDOFF-bellerive-v3.md` (B-3, B-7, B-9). The civic centre,
the government buildings and the outskirts patterns from v3 carry over.

## Diagnosis (measured, 2026-10-27)

- Only 17% of street length runs within 5 degrees of north-south or east-west. 38% is tilted 5-15 degrees and 46% by 15-45 degrees (`plan_v3b`, scratch `straight.py`).
- Cause: every district grid has its own angle (-25, +30, +16, -20, -12, -9, +8 degrees). The grids also bend, fan and jog. On top of that, the seam roads (Lantern, Rampart, Crescent, Bayou, Magnolia) are curved splines.
- The design was deliberate (v2, the New Orleans faubourgs). `test_street_plan_is_not_a_grid` even requires it: "most streets are off the compass", "T-junctions outnumber crossroads".

## Decisions

- C-1 **Approach** (rough costs; full option chosen):
  - **Full (chosen), about 8-12 hours.**
    - Research California top-down. The network blocks map imagery, so the agent renders real geometry from public data files and cites search sources.
    - Rebuild the plan on one citywide north-south/east-west arterial grid, with local streets between.
    - Add skyscrapers, fictional monuments, and shady and poor districts.
  - **Cheaper, about 4 hours:** set every district grid to 0 degrees with no bends, then raise tower heights and re-skin the Wards with existing kits.
- C-2 **Street rules** (California; tune with the research numbers):
  - **Main grid.** Most of the city sits on one N-S/E-W grid.
  - **Arterials.** Arterial avenues and boulevards run on a citywide pitch, so they line up across districts like LA's boulevards. Local streets split each superblock evenly.
  - **Diagonals and curves**, kept few:
    - Liberty Avenue, the one long diagonal (an old road);
    - the River Road, following the water;
    - the old Lantern Quarter, the one rotated grid (DTLA's rotated old grid; the French Quarter follows the river), meeting the main grid along one seam (SF's Market Street);
    - winding roads only in the hills (outskirts).
  - **Seam roads** become straight arterials: Lantern and Rampart run N-S, and Crescent and Bayou run E-W.
- C-3 **Test** `test_street_plan_is_not_a_grid` becomes a California test:
  - a high axis share;
  - arterials that run through;
  - a capped diagonal share;
  - Liberty still crossing.
- C-4 **Grid as built** (`street_plan.gd`, local metres):
  - Arterial pitch 360 m: ART_X = -390, -30, 330, 690, 1050, 1410, 1770. North of the river ART_Y = -220, 140, 500, 860, 1220; south of it, 180 m from 1040.
  - Named arterials: Palmetto and Cypress Avenues (x -30 and 1050), Aurum Boulevard (y 140), Basin Street (y 860, west of Rampart), Harbor Way (x 690, south bank) and Morrow Boulevard (y 1400).
  - Patch grids `[nu, nv]` split each superblock evenly:
    - Gilt [4,4] (90 m);
    - Midtown [3,6] (120 x 60 m, Manhattan-long blocks, avenues north-south);
    - Quarter [5,5] (72 m);
    - Wards [5,7];
    - Wards North [5,5];
    - Docks [4,3];
    - Morrow Point [5,3].
  - Result: 93% of street length runs within 5 degrees of the axes (was 17%).
  - Liberty Avenue is now straight from Founders Circle through (690, 500) to the east edge.
  - The Lantern Quarter stays on the main grid for now. A rotated old-town grid waits on the research (C-2).
- C-5 **Traffic on wide boulevards** (`vehicle.gd _traffic_ai`). The grid makes many turns from an 11 m street onto a 24 m boulevard with a median.
  - The failure: after switching segments, the car sped back to cruise mid-turn and hit the median's nose.
  - The fix: it now holds turn speed until lined up with the new street, and the lookahead shortens while the car is far off its lane.
  - Rejected: braking for sharp turns ahead. The cars already reached the junction at turn speed.
- C-6 **Camera for skyscrapers.** `TopDownCamera.DISTANCE` 60 -> 220 (camera about 190 m up, so 150 m towers do not clip) and far = DISTANCE + 120.
  - The view is orthographic, so the framing is unchanged.
  - Sun shadows: max distance 300, with splits 0.45/0.62/0.8, so the ground (205-235 m away) falls in a 54 m cascade, as sharp as before.
