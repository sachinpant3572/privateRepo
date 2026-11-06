# HANDOFF archive: wide roads

## Starting state (measured)

- City classes (`street_plan.gd CLASSES`): boulevard 24 (median 6.4), bridge 16, avenue 15, river 14,
  street 11, quarter 9, lane 7 (walk only), quay 10. Traffic drives one lane per direction at
  `lane_offset(w) = max(2.4, w*0.22)`; avenues are painted as 2+2 but parked cars sit in the outer
  lane, so in play every road is one lane each way.
- Country classes (`build_country.py CLASSES`): highway 16, avenue 14, road 10, street 10, lane 7,
  track 6, trail 3.5. Every class is drawn and driven as one lane each way.

## Measured after the change

- Country: 5106 nodes, 633 roads, lots 2335 -> 2056 (fronting 1511 -> 1333), worst lot turn 2.75 deg,
  the same 74 unreached nodes as before. Mountain grades: freeway 10.7% steepest, Crest 18.8%.
- City plan: river roads shifted (RIVER_ROAD 10); minor streets lost to bigger blocks, accepted:
  x922 y987-1043, x1339 y935-987, quarter streets (229..330, 786) and (342,614)-(330,635); (125,500-578)
  avenue became a lane; (649..690, 789..805) quarter became a lane.
- Tests: two cars abreast on a street 3.3 m apart; parked cars 0 of 117 in a traffic lane; lamp,
  street tree, signal and hydrant knocked down at 16 m/s, car keeps 15.9-20.5 m/s. Suite 635/0.

