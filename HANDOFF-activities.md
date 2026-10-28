# Decisions note: activity catalogue and stock market (2026-10-28)

Docs only; no game code. Files: `ACTIVITY_IDEAS.md`, `STOCK_MARKET_DESIGN.md`,
`tools/stock_market_sim.py`.

## Done
- Request 1 ("never bored" catalogue): `ACTIVITY_IDEAS.md` sections 0-8, two review runs, pushed.
- Request 2 (stock market + GTA V/VI check):
  - GTA Online and GTA VI pass: `ACTIVITY_IDEAS.md` 4.11, sources A14-A22.
  - Stock market design and simulation: written by an opus xhigh agent (hard design step, per
    CLAUDE.md); `ACTIVITY_IDEAS.md` 4.12 links to it.
- Request 3 ("Check GTA 3, Watch Dogs, and Sleeping Dogs, and GTA Liberty City too"): 4.13,
  sources A23-A28. "Liberty City" was read as LCS plus GTA IV with TLAD and TBoGT.
- Request 4 ("specify all planned activities here, in different terrains, regions and places"):
  `ACTIVITY_ATLAS.md`. It adds nothing new; places not fixed by the world docs are marked
  *suggested*.
- Request 5 ("Check Bully, Saints Row and Yakuza too"): `ACTIVITY_IDEAS.md` 4.14, sources
  A29-A31, placed in the atlas.
- Request 6 (spread activities over the whole map; venues need the bigger map; packages for the
  five RM 1.1 gaps): atlas Part D (regional styles, signatures, venue homes, city packs CP-1 to
  CP-6, about 19 sessions, cheaper 7) and roadmap packages 28-32 (about 8 sessions).
- Request 7 (story progression unlocks, "or suggest anything else that seems much better"):
  `PROGRESSION_UNLOCKS.md` ("the Rebuild": the city reopens, Jules's franchise, buying back the
  Wards, exploration; unlock ladder; laundering routes; N26 framework 2 sessions, N27 branches
  and showrooms 2).

## Decisions
- GTA V story-mode parity was already done in `ACTIVITY_ROADMAP.md` section 1, so 4.11 covers
  only GTA Online and GTA VI gaps. Items already planned are listed once and not repeated.
- GTA VI is unreleased (due 2026-11-19), so every GTA VI item is labelled 2 (news) and
  "re-check after launch".
- The stock market goes in its own doc, because its anti-exploit design and simulation are too
  long for the catalogue.
- Exploit claims must be proven by a seeded simulation, not just asserted.
- Sachin's answers (2026-10-28): cheaper city packs (7, listed in atlas D5); laundering through
  people, gangs and companies, opened by the story (N20 now 2.5); alcohol "Both" (one cartoon
  drink or the soda dares, never drunk driving); stock design approved with its 10 recommended
  answers as defaults.
- Unlock framing: the pitch's "new city" and "escape his past" clash with canon (300-year-old
  Bellerive, Jules returns home, gender-neutral), so the doc keeps canon and uses the rebuild
  after the Great Storm; the canon touch and the hero are open points for Sachin.
- Review run 2: save slots are whole worlds (a profile-wide market duplicated cash);
  `biz_cap_w_per_day` 0.35 keeps tips plus businesses at clock-bot pace at 2.38 < 2.5;
  spearfishing became fish tagging; real golf lives in CP-2 (Ember Heights) and the full CP-3.
- Unlock review run 1 fixes: a fourth driver, buying back the Wards (N8) with clean cash; new
  N27 for branches (reward: venue, rep, wash allowance; never income above the cap) and six
  showrooms; act 1 rows hold two adds at most, the rest by trigger; Crescent Bridge leads west
  (Saltgrass, Golden Flats), Verdant Hills opens at mission 10, the pier at 12, flight school
  with phase 3; phase 3 places are act 2 side roads; laundering: fronts' allowance is a hard
  cap, people route by mission 4, a both-sides gang route at 25%, dirty-bought items sell dirty,
  washed cash is not takings, rolls follow stock §6.5, v2 cash loads clean.

- 4.13 keeps Slash TV only as a non-lethal studio show; privacy invasions are out
  (voyeurism); alcohol in minigames is swapped for a soda dare until Sachin says otherwise.

- Part D is a proposal: every place in it is *suggested*. Regional martial arts use 2.9's ten
  styles plus a stunt school; a hermit master and an ex-Halberd trainer carry the odd ones.
- Rodeo uses a mechanical bull, not live animals; Saints Row's fire becomes coloured powder.
- The Shakedown takes pocket cash only, never bank or stock holdings.
- Review run 1 (11 findings), fixes:
  - regional martial arts are costed only in the city packs (N10 cut to 1: Bellerive masters);
  - every 4.11-4.14 item now has a home: new N24 and N25 (2.5 each), snorkelling in CP-2;
  - a countryside table gives each region its core set; Sovereign County has a signature (CP-3);
  - market: only sabotage and heists move prices; world event rates are fixed; taxi time counts
    up to 4 h a day; tip cap 17 W, checked on p90; a seized lot loses its dividends too; one
    market per profile across save slots. A clock-bot sim proves time skipping stays below side
    jobs (0.382 vs 2.5 W per real hour);
  - "chapel" became wedding-hall; barrel racing uses dirt bikes; roadmap rows point to packages.

## Traps
- WebFetch can't reach the wikis; only WebSearch summaries work, so labels stay 2 or U.
- The single save file `user://solvera_save.json` (mission_manager.gd `save_game`) is the
  save-scum surface for the market.
- "Canal Street" and other real New Orleans names must not be used as placeholders.

## Open
- Done: section 5 rows N15-N27, decisions 7-11, the stock-market doc and sim (8 checks pass,
  seed 20261028), N17 costed at 2.5 lite / 6 full. Review runs 1 and 2 (the cap) done and fixed.
- Sachin's open points: `ACTIVITY_IDEAS.md` section 7 items 1-6 and `PROGRESSION_UNLOCKS.md`
  section 6. `PROGRESSION_UNLOCKS.md` had its own review run 1 (11 findings, all fixed; see
  Decisions).
