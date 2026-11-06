# Solvera: stock market design (2026-10-28)

Brief, from Sachin (word for word): "Stock market trading too, based on real events happening in
the city, or events that the player can affect. But this needs to be very meticulous, other wise
player can manipulate the market everytime and keep earning."

Design and a price simulation only; no game code is changed. Status: proposed, waiting on
section 11. "Real events" means events in the game world (calendar, random events, faction wars,
story beats, storms), never real-world news.

## 0. Method, labels and units

- Sources: WebSearch result summaries (WebFetch can't reach the wikis from this container) and
  the repo. Labels as in `ACTIVITY_IDEAS.md`: **V** a primary source states it (URL in section
  12) or the repo file was read; **2** guide or news sites only; **U** from memory or unchecked.
- **W**: what an average player earns from legit side jobs (R-16) in one game day; a placeholder
  of about $600 in act 1 (U; the demo missions pay $300-800). Caps are written in W, and W rises
  with the story, so the market grows with the game, not with itself. `atmosphere.gd` runs at
  `minutes_per_second := 1.0` (line 38, V): a game day is 24 real minutes, so side jobs pay about
  **2.5 W per real hour**. Costs are in roadmap sessions (one agent, one 3-5 h sitting).
- Simulation: `tools/stock_market_sim.py` (Python 3.13, stdlib, deterministic): seed 20261028,
  150 runs of 60 game days, 12 ticks a day, 14 companies; exit 1 if a target fails. Run
  `python3 -I tools/stock_market_sim.py > /tmp/sim.log 2>&1; echo "exit $?"; cat /tmp/sim.log`
  (about 35 s). Names `like_this` are keys of its `P` or `CLASS`. Results are profit per game day
  from `book_cap_w` cash, after spread, slippage, fees, tax, fines and seized gains.

## 1. What other games teach

| Game | What happened | Lesson for Solvera | Label |
|---|---|---|---|
| GTA V, LCN (offline) and BAWSAQ (online) | LCN moves with the player's actions; Lester's 5 assassinations each kill an executive and move rival companies (Betta against Bilkinton) | The authored "kill the CEO, buy the rival" moment is the fun part. Keep it, one-off and capped | V (repo [S1]), 2 [S2] |
| GTA V guides | Guides say to hold all three characters' cash until the assassinations and compound through them; the brief cites a 2014 guide's $2.1B | Uncapped story paydays become the whole economy. Cap them in W | 2 [S2]; $2.1B U |
| GTA V BAWSAQ, 2013 | Players organised online to pump one stock; reported to have had little visible effect | A deep market shrugs off a crowd, but in a single-player game the player *is* the crowd, so liquidity limits must be explicit | 2 [S11][S12] |
| GTA V reload bug, Nov 2014 (PS4, Xbox One) | Prices re-randomised on loading a save: reload until low, buy, save; reload until high, sell. Reported patched 26 Nov 2014; a 2015 Steam thread claims it still worked on PC (unconfirmed) | **Nothing may reroll on load.** The sim's naive reroll earns 24 times the passive rate | 2 [S3][S4][S13] |
| Old School RuneScape, Grand Exchange | Each item has a buy limit per 4 hours; selling has none | Buy limits throttle cornering without trapping sellers: `buy_limit_w` per company per day | V [S5] |
| EVE Online | Since late 2021 the base sales tax is 8% and the broker fee 3%, both cut by skills | A round trip that costs more than the tick-to-tick noise kills scalping. Solvera's fees are far smaller because its noise is too | V [S6] |

## 2. Companies

Fourteen fictional companies, each tied to a place or faction in `WORLD_BIBLE.md`. When one of a
rival pair is hurt, the other gains `world_rival_share` 0.3 (world news) or `rival_share` 0.5
(player crimes) of the move.

| Ticker | Company | Sector | Class | Rival | Moves on (weight; + = good news when the event's sign is +) |
|---|---|---|---|---|---|
| AUR | Aurum Consortium | fin | L | - | Line vote +.4, ledger leak +1 (a cleared name) or -1 (exposure); story beats |
| CIG | Crescent Insurance Group | fin | L | - | Storm +1 (a miss) or -1 (a hit); crime wave -.4. See-saw with KYS on storms |
| KYS | Keystone Builders | build | M | - | Storm -.8 (a hit means rebuilding work); Line vote +.4; turf war -1 |
| DPL | Delta Power & Light | build | L | - | Storm +.7; blackouts as random news |
| SVL | Solvera Line Rail (Aurum's listed rail arm) | move | H | GWF | Line vote +1; ledger leak +.6; act 3 Line sabotage |
| GWF | Gulfway Freight | move | M | SVL | Line vote -.5; hijacked trucks; act 1 Cargo |
| IWP | Ironwharf Port & Cruise | move | M | - | Storm +.6; festival +.5; crime wave -.3 |
| HLB | Halberd Security | guard | M | BWK | Crime wave +.8; turf war +.5; Fort Granite break-in |
| BWK | Bulwark Alarm | guard | H | HLB | Crime wave +1; burglaries of its clients |
| LTV | Lantern Broadcasting | media | M | BZL | Festival +.4; ledger leak -.4 (their scoop when Aurum falls) |
| BZL | Buzzline (the short-video app) | media | H | LTV | Festival +.4; viral stories |
| GMB | Gumbo Brothers | consumer | L | BYB | Festival +.7; storm +.3 |
| BYB | Bayou Bites | consumer | M | GMB | Festival +1; storm +.3 |
| MRM | Morrow Motors | consumer | M | - | Turf war -.4; car-theft news |

Every company also reports earnings every `earnings_every_days` (10) and gets random news
(`news_per_day` 2.0 across the market). The class sets how a company behaves:

| Class | `vol_day` | `volume_w` (W/day) | `div_day` | `half_spread` | `ev_mag` | Feel |
|---|---|---|---|---|---|---|
| L, blue chip | 1.2% | 200 | 0.40% | 0.2% | 4% | Calm, pays the most |
| M, mid cap | 2.0% | 60 | 0.35% | 0.3% | 9% | The trading names |
| H, small cap | 3.5% | 20 | 0.30% | 0.5% | 14% | Jumpy, thin, costly to trade |

**Which player actions move prices.** Only two kinds of player action call
`Market.player_event(ticker, kind)`, and every one of them goes through 6.1-6.2:
- `sabotage`: wrecking or torching a listed company's property (GWF vans, SVL rail kit, KYS
  sites, BYB food trucks, an IWP crane), from R-5 street crime;
- `heist`: an R-23 heist or a side job whose target is a listed company (a BWK client's vault, a
  GWF hijacked truck, an MRM showroom).
Everything else in the "Moves on" column is world news. "Burglaries of its clients", "car-theft
news" and "hijacked trucks" there mean the world's own random company news, drawn at a fixed
rate. **World event rates never depend on the player's crime**: the wanted level, the heat map
and a crime spree change nothing about how often a crime wave, a turf war or company news comes,
so buying BWK or HLB and then going on a spree earns nothing from the spree. Car thefts, muggings,
police chases and street fights never call the market at all. The player's crimes can only touch a
price through the two kinds above, each one capped, decayed and watched by the SSC.

## 3. Where trading lives

- **Phase 1, Bellerive: the phone app "Bourse"** (Bourse de Bellerive). R-13 Phone media already
  plans "a fictional stock ticker" in `phone.gd` (V, `ACTIVITY_ROADMAP.md` package 13). Read-only
  ticker from mission 2 (the phone); trading after mission 6, when Simone brings Jules into Aurum
  Tower. **Optional broker office** in a Gilt District tower lobby: the same market with a face
  (tips, SSC letters, a tutorial), nothing exclusive, so it can come later (0.5-1 session).
- **Phase 5, Concordia**: Market Seam holds "Finance, the Exchange" (`WORLD_BIBLE.md` line 91, V).
  The Bourse becomes the Concordia Exchange: same code, more data rows, caps at the act's W.
- **Hours**: a tick per game hour, 09:00 to 20:00 (12 a day, about one per real minute). Orders
  placed outside hours fill at the 09:00 open, which carries the overnight gap.

## 4. Price model, the tick and the clock

```
log price = perm + x
x(t)      = A1*x(t-1) + A2*x(t-2) + gap*sigma*z + overreact*surprise     (noise and overshoot)
perm(t)   = DP*perm(t-1) + surprise + player impact                      (fundamentals)
z         = rho_market*zm + rho_sector*zs + sqrt(1 - rho_market^2 - rho_sector^2)*zi
```

- **Mean reversion**: kappa = 1 - 0.5^(1/`revert_half_life_ticks`), 18 ticks; A1 = 1 - kappa +
  `momentum`, A2 = -`momentum` (0.10, NPC trend followers). **Noise**: sigma = `vol_day`/sqrt(15)
  per tick, gap = 2 at 09:00; `rho_market` 0.30 and `rho_sector` 0.40 make a storm day feel like
  a market, not 14 dice.
- **Fundamentals**: event surprises land in perm and fade with `perm_half_life_days` 20 ("the city
  heals"), DP = 0.5^(1/(20*12)). Prices are stationary around each company's base price, so no
  stock drifts up for ever; the long-run return is the **cash dividend**, `div_day` of the value at
  the 20:00 close. Passive income is then a known rate the caps bound, and nothing compounds
  through price drift (6.7).
- **Fills**: mid +/- `half_spread` +/- impact, impact = `impact_k`*sqrt(order/`volume_w`); the
  impact also pushes the mid and fades like noise. `broker_fee` 0.25% each side, `sales_tax` 0.5%
  on sells.
- **Clock and catch-up**: `market.gd` ticks on its own saved, monotonic `market.clock` (6.6),
  never on `atmosphere.hour`, which missions set and which isn't saved (V, `mission_manager.gd`
  138-139). Nothing moves while the app is closed; the device clock is never read. When game time
  jumps (sleep, taxi, a mission start) the skipped ticks run at once, at most 7 game days (84
  ticks) per jump, and the feed shows a "while you were away" digest. Taxi time counts only up to
  `taxi_cap_h_per_day` 4 game hours per game day (6.6).

## 5. Event pipeline

- **Sources**: calendar (R-25: storms every 20 days, Line votes 15, festivals 12, earnings 10;
  the date shows days ahead, the outcome doesn't); world (R-5 and faction wars: crime waves about
  every 10 days, turf wars 12, ledger leaks 20, random company news; fixed rates that the player's
  crime never changes, section 2); player-caused (sabotage
  `sab_mag` and heists `heist_mag` through R-5 and R-23 hooks, and five story beats, below).
- **Shape**: each event lists (ticker, weight), a magnitude m (template value times U(0.6, 1.4);
  company news `ev_mag` times U(0.5, 1.5)) and a sign, + or - with even odds.
- **Public rumours**: with `rumour_chance` 0.7 an event is rumoured `rumour_lead_ticks` (4-18)
  ticks early, with `rumour_reliability` 0.6, 0.7 or 0.8 shown as 1-3 stars. The market prices in
  `priced_in` 0.25 of the implied move at once: priced = `priced_in`*(2*rel - 1)*reported sign*
  m*weight. At resolution the surprise (s*m - priced) goes into perm and `overreact` 0.25 of it
  into x, an overshoot that fades.
- **Paid tips**: `tip_chance` 0.35 of events get a tip `tip_lead_ticks` (12-36) early, right with
  `tip_reliability` 0.85, not priced in; `tip_fee_w` 0.03 W each, at most `tips_per_day` 2.
  Sold by Pops ("information for a price", `ACT1_MISSIONS.md`) or the broker.
- **The sign is drawn late**: in the game it is drawn when the event resolves, from the reseeded
  RNG (6.5), conditioned on the reports already shown so each is right with its stated
  reliability. The odds match the sim (which draws first), but no save holds an outcome to scout.
- **Authored paydays** (proposals; one-off, SSC-exempt, saved as a flag; `payday_move` 0.30 lands
  at mission pass):

| Beat | Tip from | Moves |
|---|---|---|
| Act 1, 12 Cargo | Pops | GWF up, AUR down |
| Act 2, the ledger scoop | Celeste | LTV up, AUR down |
| Act 3, Line sabotage | Velvet Aces contact | GWF up, SVL down |
| Act 3, Fort Granite break-in | Captain Reyes | HLB down, BWK up |
| Ending | The ending's ally | Crown: AUR up; Ashes: AUR and SVL crash, KYS up; Light: LTV up, AUR down |

  The tip allows up to `tip_cap_w` 17 W in that company, outside the
  normal caps. A retry doesn't reapply the move; untipped story moves stay under 15%.

## 6. Anti-manipulation

Each loop was played by a bot in the sim with the counters on, the main ones again with them
off. The bar (section 7): no exploit plus half an index may beat skilled honest trading (0.131).

**6.1 Sabotage loop.** *Loop*: hold SVL, burn GWF's vans every day, sell into the rise, repeat.
*Counters*: small moves (`sab_mag` 4/8/12% by class L/M/H, `heist_mag` 6/10/15%);
`insured_share` 0.5 of the lasting part is insured and `scare` 0.3 is a part that fades; the
rival gains only `rival_share` 0.5; a second crime on the same company within `cooldown_days` 3
moves nothing; each repeat on it within `repeat_memory_days` 30 halves the move (`repeat_decay`
0.5) and every crime within `pattern_memory_days` 7 cuts it by `pattern_decay` 0.8; the player's
lasting impact on a company bottoms out at `player_impact_floor` -15%; and the regulator (6.2).
*Sim* (W/day): daily loop -0.022 (0.8 flags, 3.39 W seized; 0.225 with counters off); rotating
over 8 targets -0.155 (27 flags); sized just under the case threshold 0.022 (0.047 off), the worst
exploit: 0.022 + half an index 0.042 = 0.064, under 0.131; sabotage then buy the dip -0.227.

**6.2 Insider trading on your own missions and heists.** *Loop*: take a heist on GWF, buy SVL
the day before, rob, sell. *Counters*:
- **The SSC** (Solvera Securities Commission) opens a case only when a crime's expected gain to
  the player's book is over `case_min_w` 0.05 W: m*(`rival_share`*rival value - target value).
  It marks each lot that gains with suspicion exp(-age/`watch_tau_ticks` 36), so a lot bought
  weeks ago is barely suspect; buys within `post_watch_ticks` 24 after your own crime on that
  company or its rival get `post_weight` 0.5.
- Selling a marked lot is flagged with p = min(`p_max` 0.95, `p_floor` 0.25 + `p_size` 0.6*
  suspicion*min(1, value/`pos_cap_w`) + `p_repeat` 0.15*past flags). A flag seizes the gain, dividends
  received on the lot included, and fines the same again (`fine_mult` 1.0), sent as an SSC letter
  (fines UI from R-20).
- **Blackout**: from accepting a heist or job on a listed company until 12 ticks after it, no
  buys in the target or its rival. Not in the sim, so the insider rows are a worst case.
- **Phone warning** before a crime while holding a position that would gain, so the SSC is never
  a hidden trap. **Fees**: the round trip (about 2% on a mid cap) eats a small edge. Story
  paydays are authored, one-off and capped; repeatable crimes always face the SSC.
*Sim*: rival bought 1 day before -0.066 W/day (10.2 flags; 0.054 with counters off); 6 days
before -0.046 (4.6 flags). Fairness: an index holder who also wrecks a paired company every 3
days earns 0.082 with 0 flags, thanks to the net-gain rule.

**6.3 Pump and dump.** *Loop*: buy a thin small cap up over two days, dump on the third.
*Counters*: slippage both ways while the impact fades; `buy_limit_w` 4 W per company per market
day (OSRS-style, sells unlimited); `pos_cap_w` 6 W per company; `book_cap_w` 24 W in all.
*Sim*: -0.030 W/day; -0.143 with no caps or limits, since bigger orders pay more slippage.

**6.4 Fee churning and tick scalping.** *Loop*: buy every one-sigma hourly dip, sell the first
uptick. *Counters*: a mid cap's round trip costs about 2% (spread 0.6%, fees 0.5%, tax 0.5%,
impact 0.4%) against hourly noise of about 0.5%; EVE-style tax on sells; T+1 hold
(`min_hold_ticks` 12). Dividend capture over one close gets 0.35% against the same 2%.
*Sim*: -0.104 W/day with T+1, -0.179 without. Costs alone kill scalping; T+1 is the backstop.

**6.5 Save-scumming and reload foresight.** Today Solvera has one JSON save,
`user://solvera_save.json`; `save_game()` (`mission_manager.gd` line 299) writes `{version, done,
cash, phone, settings, inventory}` only on a mission pass and on New game, and `load_game()`
(line 309) reads it back (V). The market adds four rules:
1. **Nothing rerolls on load.** Prices, noise history, pending events and their reports, lots,
   flags, cooldowns and the clock are saved; loading resumes exactly where it was.
2. **Commit, then reveal.** The save is written before a new tick, fill or event result is shown,
   and orders fill at the next tick, after its shocks. Quitting after a bad price undoes nothing.
3. **Fresh seed.** Noise and event signs come from an RNG reseeded from the OS RNG on every load
   and after every trade (tests inject a fixed seed), so a copied save never replays the same
   future. An emulator snapshot that restores RAM is just another copy (rows below).
4. **Autosave on every tick, trade and skip**, atomically (write a temp file, then rename).
5. **Each save slot is one whole world.** If the game ever gets several manual save slots, the
   market, its clock, lots, flags, paydays and the cash all live in the slot together; nothing is
   shared between slots or kept in a profile. Splitting them would print money (save, buy shares,
   reload: the cash returns and a profile-wide market keeps the shares) and would let a payday
   be replayed from a slot whose flag is unset. Picking the best of N slots is save copying from
   a menu, which rule 3 already bounds (the rows below).
*What's left*: copying the save outside the game (PC, emulator, rooted phone, R-27 cloud restore)
and keeping the best of N futures. Nobody can stop that on an open platform, so it must pay worse
than playing. A checksum stops casual cash edits, not copying. Exclude the save from Android Auto
Backup so a reinstall isn't a free rollback (U, check the manifest setting).
*Sim*: naive reroll on load 2.027 W/day (24 times passive); Solvera's save 0.084 (= passive, by
construction); daily copy, best of 5: 0.618 per kept day but 0.124 per game day of real play
(side jobs: 1); scripted hourly copy, best of 5: 0.756 W per real hour (side jobs: 2.5); a fixed
future scouted three times (only if a bug ever fixed it): 1.059 per kept day, 0.353 per real day.

**6.6 Time-skip abuse and device clock changes.** Today the phone's "Skip 3 hours" button
(`phone.gd` line 275) is unlimited; missions set `atmosphere.hour` on every start, retries
included, so fail-and-retry can move time either way; and the hour isn't saved (V). *Counters*:
`market.clock` is monotonic and saved, and grows only by played time, by sleep at a safehouse
(8 h per 16 h awake, the sleep rule), by a taxi ride's time up to `taxi_cap_h_per_day` 4 h per
game day (longer taxi time moves only the sky), and by a mission's first start (at most 12 h, a
one-off per mission, so not a loop); retries and backward hour sets move only the sky. "Skip 3 hours" becomes sky-only.
Catch-up stops at 7 days per jump, and the device clock is never read. "First start" means a
story mission's first start; repeatable jobs and activities that set an hour move only the sky.
The same clock drives R-22 business income, so R-22 gets a cap too: `biz_cap_w_per_day` 0.35 W
per game day for all businesses together, net, so the clock bot with tips and full businesses
still earns less than side jobs. *Sim*: a clock bot plays one real hour (1 game hour = 1 real minute) and takes every legal
jump: sleep as soon as allowed, taxi rides of 2 h with a 15 s fade, and 3 h taps at 7.5 s each
when taps count; taxi time counts as awake, which earns sleep sooner. Passive income per real
hour (game days per real hour): normal play 0.211 (2.5), sleep rule 0.293 (3.5), all rules with
the taxi cap 0.382 (4.5), no taxi cap 2.239 (26.5 game days per real hour; 2.239 W is close to side jobs' 2.5), taps that move the
clock 5.492 (65, twice side jobs). At the all-rules pace a skilled trader earns 0.592 per real
hour and a tips trader 0.798; tips plus businesses at their cap earn 2.380, under side jobs' 2.5
(check 8). Mission first starts add a one-off, not a rate.

**6.7 Infinite compounding.** *Loop*: reinvest every gain. *Counters*: caps in W that rise only
with the story, stationary prices, cash dividends. *Sim*: a tips trader's profit per day in days
41-60 against days 1-20 is x0.95 with caps, x1.55 without (0.416 W/day, three times skilled).

**6.8 Shorts, options, leverage and the rest.** *Short then destroy*: a short makes every
company a target and needs no rival; the sim's short-and-sabotage bot loses (-0.032, 0.8 flags)
only because of 6.1-6.2, and shorts carry unlimited losses that confuse players. **No shorts at
launch.** *Leverage* multiplies every exploit and voids the caps (6 W at 5x margin is 30 W):
**none.** *Options* add the same risk and look like betting (section 9): **none.** Also: player
social posts (R-13) never move prices; player businesses (R-22) are unlisted; New Game+ resets
the market; a payday is a saved flag, so a mission retry can't repeat it.

## 7. Economy balance and sim results

Targets: passive 5-15% of W per day; skilled above passive and well below missions; every
exploit after counters no better than skilled honest play; authored paydays one-off and capped.
Seed 20261028, 150 runs, 60 days, 12 ticks a day; profit per game day in W:

| Strategy | mean | sd | p10 | p90 | notes |
|---|---|---|---|---|---|
| Passive index, hold 60 days | 0.084 | 0.021 | 0.059 | 0.111 | |
| Passive + own crime every 3 days (fairness) | 0.082 | 0.020 | 0.057 | 0.108 | 0 flags |
| Casual random trades | 0.062 | 0.039 | 0.018 | 0.115 | |
| Skilled: half index + public rumours | 0.131 | 0.054 | 0.065 | 0.204 | |
| Skilled: half index + rumours + paid tips | 0.177 | 0.058 | 0.111 | 0.261 | |
| 1 Sabotage loop: hold rival, hit daily | -0.022 | 0.044 | -0.074 | 0.031 | flags 0.8, seized 3.39 W |
| 1 ... same, no counters | 0.225 | 0.090 | 0.116 | 0.352 | |
| 1 Sabotage rotation over 8 targets | -0.155 | 0.034 | -0.197 | -0.109 | flags 27.2, seized 3.94 W |
| 1 Sabotage rotation, sized under `case_min_w` | 0.022 | 0.016 | 0.003 | 0.040 | worst exploit |
| 1 ... same, no counters | 0.047 | 0.020 | 0.025 | 0.071 | |
| 1 Sabotage then buy the dip | -0.227 | 0.027 | -0.261 | -0.187 | flags 55.2, seized 12.14 W |
| 2 Insider: rival bought 1 day before heist | -0.066 | 0.026 | -0.097 | -0.036 | flags 10.2, seized 5.35 W |
| 2 ... same, no counters | 0.054 | 0.032 | 0.011 | 0.098 | |
| 2 Insider: rival bought 6 days before | -0.046 | 0.056 | -0.114 | 0.026 | flags 4.6, seized 4.78 W |
| 3 Pump and dump, small caps | -0.030 | 0.052 | -0.105 | 0.031 | |
| 3 ... no caps or buy limits | -0.143 | 0.148 | -0.297 | 0.078 | |
| 4 Tick scalper (T+1 on) | -0.104 | 0.040 | -0.154 | -0.050 | |
| 4 ... no minimum hold | -0.179 | 0.035 | -0.226 | -0.138 | |
| 5 Oracle: fixed future scouted, per kept day | 1.059 | 0.064 | 0.981 | 1.141 | needs a fixed future |
| 8 Short + sabotage (if shorts existed) | -0.032 | 0.023 | -0.061 | -0.008 | flags 0.8, seized 0.08 W |
| 7 Compounding, no caps (tips trader) | 0.416 | 0.224 | 0.170 | 0.719 | |
| 5 Reload, Solvera save (nothing rerolls) | 0.084 | 0.021 | 0.059 | 0.111 | = passive |
| 5 Reload, naive save (reroll on load) | 2.027 | 0.150 | 1.849 | 2.219 | |
| 5 Save copy daily, best of 5, per kept day | 0.618 | 0.108 | 0.497 | 0.749 | |
| 5 ... same, per game day of real play | 0.124 | 0.022 | 0.099 | 0.150 | |
| 5 Save copy hourly, best of 5, W per real hour | 0.756 | 0.041 | 0.707 | 0.809 | side jobs 2.50 |
| 5 Oracle, per real day (scouting x3) | 0.353 | 0.021 | 0.327 | 0.380 | |
| Authored payday (one-off total, not per day) | 5.475 | 1.709 | 3.431 | 7.621 | `tip_cap_w` 17 |

Time skip (clock bot), passive per real hour: normal 0.211, sleep rule 0.293, all rules with the
taxi cap 0.382, no taxi cap 2.239, taps moving the clock 5.492; all rules, skilled 0.592, tips
0.798, tips plus businesses at `biz_cap_w_per_day` 0.35: 2.380. Compounding, days 41-60 against
1-20: caps on x0.95, no caps x1.55. Runtime 38.1 s, exit 0.

**Which targets held** (all 8 sim checks pass): passive 0.084 W/day (8.4% of W) is inside 5-15%;
skilled 0.131 (0.177 with tips), or 0.33 (0.44) per real hour, sits far below side jobs' 2.5;
every in-game exploit with counters, plus half an index, is at most 0.064; the honest index
holder's crimes are never flagged; the payday's p90 is 7.6 W (mean 5.5) at `tip_cap_w` 17, under
the 8 W cap (20 W would give p90 8.9); the clock bot with all rules earns 0.382 per real hour passive, 0.798 with tips, and 2.380 with tips and businesses at their cap.
**Partly held**: copying
the save outside the game beats skilled trading at normal pace (0.756 against 0.33; the tips
trader at the clock bot's pace makes 0.798) but stays well
under side jobs (2.5), the honest limit on an open platform. The "Solvera save" row equals
passive by construction, and the blackout isn't modelled (so the insider rows are a worst case).

## 8. Player-facing feel

- **News feed**: the R-13 social feed carries market posts tagged with tickers; rumours show 1-3
  stars; tips arrive as messages from Pops or the broker; tap a post to open its chart. Story beats
  get a headline. Simone's first message after mission 6 explains dividends, caps and T+1.
- **Charts for a phone**: one company per screen, the last 3 market days (36 ticks) with 1-day and
  10-day toggles; big price and change with an arrow (never colour alone); pins for events (storm,
  newspaper, a flame for your own crimes). The portfolio shows book value, today's dividends and
  three cap bars (company, book, today's buys); a lot shows a lock until T+1 ends.
- **"I blew up the competitor and my stock went up"**: big for authored beats (30%, a headline, a
  cutscene line), modest for repeats (4-12% the first time, then halving), and the feed says why
  ("Analysts shrug off another Gulfway van fire"), so the decay feels like the city, not a nerf.

## 9. Ratings and monetization

- **No real money ever buys shares, trading cash, tips or bigger caps**; no in-app purchase
  touches the market. `GANGSTAR_CONCEPT.md` line 101 (V): "Avoid: casino games built on simulated
  gambling. They raise age ratings and are restricted in some regions."
- ESRB's "Simulated Gambling" descriptor covers games where the player can "gamble without
  betting or wagering real cash" (V [S7]); its 2019 reply on NBA 2K20 turned on whether real money
  is wagered (2 [S8]). PEGI's gambling descriptor is for games that "encourage or teach" gambling,
  not ones where it is only part of the story (V/2 [S9]); Wikipedia says PEGI now rates gambling
  themes 12 and simulated gambling 18 (2 [S10], not checked on PEGI's own site).
- **Does a stock sim count as gambling?** No source found says either way (**U**); GTA V has one
  and is rated for other reasons (U). Stance: frame it as investing in a living city, with no odds,
  no wager on a single outcome, no spins or double-or-nothing, T+1 instead of fast cycles, and
  dividends as the main return; answer the IARC questionnaire honestly (open decision 9).

## 10. Build plan

- **Files**: `game/data/market.json` (companies, classes, templates and every `P` value under the
  sim's keys, so retuning is a data change); a `game/scripts/market.gd` autoload (clock, ticks,
  prices, events and reports, orders, caps, SSC, catch-up, save); a phone "Bourse" screen (list,
  chart, order sheet, portfolio, news). Hooks: `Market.player_event(ticker, kind)` from R-5 and
  R-23, `Market.schedule(template, day)` from R-25, `Market.story_beat(id)` from missions.
- **Save**: `SAVE_VERSION` 3 adds `market` and `clock`; v2 saves load with a fresh market.
  Autosave on every tick, trade and skip, atomically (today `save_game()` runs only on a pass).
- **Headless tests** (`game/tests/run.sh`): save and load mid-market keeps every shown price, lot
  and flag and reseeds the RNG; caps, buy limits and T+1 refuse orders; cooldown and decay cut
  repeats; an index holder's crimes never open a case; a retry never moves `market.clock`, the
  skip button is sky-only, taxi time past 4 h a game day is sky-only, catch-up stops at 84 ticks;
  loading another save slot loads that slot's own market and cash and reseeds the RNG; a short GDScript balance run (passive and
  the sabotage loop, 20 seeds) lands near the sim's numbers.
- **Cost, full: about 6 sessions**: `market.gd` and data 2, Bourse screen 1.5, event hooks with
  SSC and clock rules 1.5, tests and balance port 1. Broker office +0.5-1.
- **Cost, lite: about 2.5 sessions**: 8 companies, calendar and world events, rumours, caps, fees,
  T+1, and the save and clock rules (never optional). No player crimes moving prices, no SSC, no
  tips, no paydays, so exploits 1, 2 and 8 can't exist yet.
- **Dependencies**: R-13 phone media (feed and ticker; the Bourse can ship first as a plain phone
  screen); R-5 random events and R-25 calendar (until then the market keeps a small calendar of
  its own); R-20 fines (until then the SSC only seizes); R-22 businesses (shares the clock rule);
  R-23 heists (full version only); R-16 side jobs set W; R-27 cloud restore counts as a copy.

## 11. Decisions (Sachin approved the design on 2026-10-28: "Sure")

The first ten answers below are the recommended ones, taken as the defaults; Sachin can overrule
any. Item 11 follows from his laundering answer.

1. **Shorts, leverage, options**: recommend none at launch (6.8).
2. **Paydays**: recommend five, `payday_move` 0.30, `tip_cap_w` 17 W (p90 7.6 W; 20 W gives 8.9).
3. **"Skip 3 hours"**: recommend sky-only (players still use it to see the night), not removal.
4. **Unlock**: recommend trading after mission 6 (Simone), with a read-only ticker from mission 2.
5. **Lite first**: recommend the 2.5-session lite once R-13 lands, and the full version with R-23.
6. **Broker office**: recommend leaving it for phase 5's Exchange in Concordia.
7. **Save copies**: recommend excluding the save from Android Auto Backup and accepting that PC or
   emulator copying pays less than side jobs, rather than adding online checks.
8. **Names**: "Bourse de Bellerive" and the SSC; recommend keeping both.
9. **Rating stance**: recommend the sober framing in section 9, revisited with the gambling call.
10. **W**: placeholder $600 in act 1; set it when R-16 side jobs are tuned.
11. **Clean cash only** (follows Sachin's laundering answer, 2026-10-28; `PROGRESSION_UNLOCKS.md`
    section 4): orders take only clean cash, so the Bourse never turns dirty cash clean.

## 12. Sources

- [S1] Repo: `reference/world/gta_systems.md` section 2.5 (cites GTABase, SegmentNext, Prima).
- [S2] GTABase, Lester's assassinations guide: https://www.gtabase.com/grand-theft-auto-v/side-missions/gta-5-lester-s-assassinations-guide-how-to-make-2-billion-with-stock-market
- [S3] GTA Boom, single-player stock market bug: https://www.gtaboom.com/bug-found-single-player-stock-market-players-making-millions
- [S4] GTA Boom, post-patch bug: https://www.gtaboom.com/new-post-patch-stock-market-bug-found-a14d
- [S5] OSRS Wiki, Grand Exchange: https://oldschool.runescape.wiki/w/GE
- [S6] EVE Online, sales tax and broker fee update: https://www.eveonline.com/news/view/updates-to-sales-taxes-and-brokers-fees
- [S7] ESRB ratings guide: https://www.esrb.org/ratings-guide/
- [S8] Wccftech, ESRB on NBA 2K20: https://wccftech.com/esrb-responds-nba-2k20-gambling-controversy/amp/
- [S9] Ask About Games, content descriptors: https://askaboutgames.com/need-to-know/what-are-content-descriptors
- [S10] Wikipedia, PEGI: https://en.wikipedia.org/wiki/PEGI
- [S11] TechSpot, players try to sway BAWSAQ: https://www.techspot.com/news/54206-gamers-band-together-to-influence-gta-vs-stock-market.html
- [S12] The Billfold, BAWSAQ scheme: https://www.thebillfold.com/2013/10/of-course-there-would-be-a-stock-manipulation-scheme-in-grand-theft-auto-v/
- [S13] SegmentNext, stock market exploits (undated): https://segmentnext.com/gta-v-stock-market-exploits-money-farming-lcn-bawsaq-stock-trading-tips/
- Repo files read: `mission_manager.gd`, `phone.gd`, `atmosphere.gd` (all in `game/scripts/`),
  `ACTIVITY_ROADMAP.md`, `WORLD_BIBLE.md`, `ACT1_MISSIONS.md`, `GANGSTAR_CONCEPT.md`.
