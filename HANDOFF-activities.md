# Decisions note: activity catalogue and stock market (2026-10-28)

Docs only; no game code. Files: `ACTIVITY_IDEAS.md`, `STOCK_MARKET_DESIGN.md`,
`tools/stock_market_sim.py`.

## Done
- Request 1 ("never bored" catalogue): `ACTIVITY_IDEAS.md` sections 0-8, two review runs, pushed.
- Request 2 (stock market + GTA V/VI check):
  - GTA Online and GTA VI pass: `ACTIVITY_IDEAS.md` 4.11, sources A14-A22.
  - Stock market design and simulation: written by an opus xhigh agent (hard design step, per
    CLAUDE.md); `ACTIVITY_IDEAS.md` 4.12 links to it.

## Decisions
- GTA V story-mode parity was already done in `ACTIVITY_ROADMAP.md` section 1, so 4.11 covers
  only GTA Online and GTA VI gaps. Items already planned are listed once and not repeated.
- GTA VI is unreleased (due 2026-11-19), so every GTA VI item is labelled 2 (news) and
  "re-check after launch".
- The stock market goes in its own doc, because its anti-exploit design and simulation are too
  long for the catalogue.
- Exploit claims must be proven by a seeded simulation, not just asserted.

## Traps
- WebFetch can't reach the wikis; only WebSearch summaries work, so labels stay 2 or U.
- The single save file `user://solvera_save.json` (mission_manager.gd `save_game`) is the
  save-scum surface for the market.
- "Canal Street" and other real New Orleans names must not be used as placeholders.

## Open
- Sachin's decisions: `ACTIVITY_IDEAS.md` section 7 and `STOCK_MARKET_DESIGN.md`'s open
  questions.
