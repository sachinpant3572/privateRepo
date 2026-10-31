#!/usr/bin/env python3
"""Solvera stock market: price model plus exploit strategies (STOCK_MARKET_DESIGN.md).

Stdlib only and deterministic: the same SEED always prints the same table.
Run:  python3 -I tools/stock_market_sim.py

Units: money is in W, what an average player earns from legit side jobs in one
in-game day. A tick is one game hour of open market (09:00 to 20:00, 12 per day);
the 09:00 tick also carries the overnight gap. Parameter names match the doc.

What it covers: the price model (section 4 of the doc), every honest baseline and
exploit in section 6 that a price simulation can show, with the counters switched
on, and the main ones again with them off. What it can't show (blackouts, the
phone warning, story one-offs on retry, the clock rules) is argued in the doc.
Options: --runs N (default 150) for quicker tuning runs.
"""
import math
import random
import statistics
import sys
import time
import zlib

SEED = 20261028
RUNS = int(sys.argv[sys.argv.index("--runs") + 1]) if "--runs" in sys.argv else 150
DAYS = 60
TPD = 12                      # ticks_per_day
T = DAYS * TPD

P = {
    # Caps and limits (W). Caps are in W, and W rises with the story.
    "pos_cap_w": 6.0,             # market value per company, checked on each buy
    "book_cap_w": 24.0,           # market value of the whole book, checked on each buy
    "buy_limit_w": 4.0,           # bought per company per market day
    "min_hold_ticks": 12,         # T+1: a lot can be sold one market day after it was bought
    # Costs
    "broker_fee": 0.0025,         # each side
    "sales_tax": 0.005,           # on the sell value
    "impact_k": 0.01,             # slippage = impact_k * sqrt(order / daily volume); moves the mid too
    # Price model
    "revert_half_life_ticks": 18,  # transient mispricing halves in 1.5 market days
    "momentum": 0.10,             # NPC trend followers
    "rho_market": 0.30,
    "rho_sector": 0.40,
    "perm_half_life_days": 20,    # "the city heals": event damage fades
    "overreact": 0.25,            # share of an event surprise that overshoots, then reverts
    # World events
    "earnings_every_days": 10,
    "news_per_day": 2.0,
    "world_rival_share": 0.3,
    "rumour_chance": 0.7,
    "rumour_lead_ticks": (4, 18),
    "rumour_reliability": (0.6, 0.7, 0.8),
    "priced_in": 0.25,            # share of a public rumour's implied move priced in at once
    "tip_chance": 0.35,
    "tip_lead_ticks": (12, 36),
    "tip_reliability": 0.85,
    "tip_fee_w": 0.03,
    "tips_per_day": 2,
    "skill_min_edge": 0.02,       # a skilled player skips rumours worth less than this
    # Player-caused events
    "sab_mag": {"L": 0.04, "M": 0.08, "H": 0.12},
    "heist_mag": {"L": 0.06, "M": 0.10, "H": 0.15},
    "insured_share": 0.5,
    "scare": 0.3,
    "rival_share": 0.5,
    "repeat_decay": 0.5,
    "repeat_memory_days": 30,
    "pattern_decay": 0.8,
    "pattern_memory_days": 7,
    "cooldown_days": 3,
    "player_impact_floor": -0.15,
    # Regulator (Solvera Securities Commission)
    "case_min_w": 0.05,           # expected gain to the book from one crime that opens a case
    "watch_tau_ticks": 36,
    "post_watch_ticks": 24,
    "post_weight": 0.5,
    "p_floor": 0.25,
    "p_size": 0.6,
    "p_repeat": 0.15,
    "p_max": 0.95,
    "fine_mult": 1.0,
    # Authored payday (story tip)
    "tip_cap_w": 17.0,
    "payday_move": 0.30,
    # Save-scum and time-skip inputs
    "reloads": 10,
    "copy_attempts": 5,
    "scum_phase_ticks": 24,       # hourly scummer: 2 market days pushing down, then 2 pushing up
    "scum_minutes_per_try": 1.25,  # real minutes per game hour tried (1 played + load)
    "oracle_real_days": 3,
    # Clock (6.6): 1 game hour = 1 real minute of play
    "sleep_h": 8.0,
    "awake_per_sleep_h": 16.0,
    "taxi_ride_h": 2.0,           # longest ride; the clock gains the ride's own time
    "taxi_cap_h_per_day": 4.0,    # taxi time beyond this in one game day moves only the sky
    "load_real_min": 0.25,        # a sleep or taxi fade, in real minutes
    "tap_real_min": 0.125,        # one "Skip 3 hours" tap
    "biz_cap_w_per_day": 0.35,   # R-22: all business income per game day, net (shares the clock)
    "counters": True,
    "allow_short": False,
}

CLASS = {
    "L": {"vol_day": 0.012, "volume_w": 200.0, "div_day": 0.0040, "half_spread": 0.002, "ev_mag": 0.04},
    "M": {"vol_day": 0.020, "volume_w": 60.0, "div_day": 0.0035, "half_spread": 0.003, "ev_mag": 0.09},
    "H": {"vol_day": 0.035, "volume_w": 20.0, "div_day": 0.0030, "half_spread": 0.005, "ev_mag": 0.14},
}

COMPANIES = [  # ticker, sector, class, rival
    ("AUR", "fin", "L", None), ("CIG", "fin", "L", None),
    ("KYS", "build", "M", None), ("DPL", "build", "L", None),
    ("SVL", "move", "H", "GWF"), ("GWF", "move", "M", "SVL"), ("IWP", "move", "M", None),
    ("HLB", "guard", "M", "BWK"), ("BWK", "guard", "H", "HLB"),
    ("LTV", "media", "M", "BZL"), ("BZL", "media", "H", "LTV"),
    ("GMB", "consumer", "L", "BYB"), ("BYB", "consumer", "M", "GMB"), ("MRM", "consumer", "M", None),
]
N = len(COMPANIES)
IDX = {c[0]: i for i, c in enumerate(COMPANIES)}
RIVAL = [IDX[c[3]] if c[3] else None for c in COMPANIES]
SECTORS = sorted({c[1] for c in COMPANIES})
SEC = [SECTORS.index(c[1]) for c in COMPANIES]
CL = [c[2] for c in COMPANIES]
CLS = [CLASS[c] for c in CL]
PAIRED = [i for i in range(N) if RIVAL[i] is not None]

# name, kind, effects (good news for weight > 0 when the sign is +), magnitude, every N days
TEMPLATES = [
    ("storm", "calendar", {"CIG": 1, "DPL": 0.7, "IWP": 0.6, "GMB": 0.3, "BYB": 0.3, "KYS": -0.8}, 0.06, 20),
    ("line vote", "calendar", {"SVL": 1, "AUR": 0.4, "KYS": 0.4, "GWF": -0.5}, 0.08, 15),
    ("festival", "calendar", {"BYB": 1, "GMB": 0.7, "IWP": 0.5, "LTV": 0.4, "BZL": 0.4}, 0.05, 12),
    ("crime wave", "world", {"BWK": 1, "HLB": 0.8, "CIG": -0.4, "IWP": -0.3}, 0.06, 10),
    ("turf war", "world", {"KYS": -1, "HLB": 0.5, "MRM": -0.4}, 0.05, 12),
    ("ledger leak", "world", {"AUR": 1, "SVL": 0.6, "LTV": -0.4}, 0.07, 20),
]

KAPPA = 1 - 0.5 ** (1 / P["revert_half_life_ticks"])
A1 = 1 - KAPPA + P["momentum"]
A2 = -P["momentum"]
DP = 0.5 ** (1 / (P["perm_half_life_days"] * TPD))
HX = [1.0, A1]
for _k in range(2, T + 1):
    HX.append(A1 * HX[-1] + A2 * HX[-2])
HP = [DP ** k for k in range(T + 1)]
HX_LIVE = next(k for k in range(2, T) if abs(HX[k]) < 1e-3)   # impulse tails below 0.1% are dropped


def poisson(rng, lam):
    lim, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= rng.random()
        if p < lim:
            return k
        k += 1


class World:
    """One seed's city without the player: events, rumours, tips and log prices."""

    def __init__(self, seed):
        rng = random.Random(seed)
        self.events = []
        self.rumours = []   # (t, rel, srep, eff, m, t_res)
        self.tips = []
        pa = [[0.0] * T for _ in range(N)]
        xa = [[0.0] * T for _ in range(N)]

        def add(t_res, eff, m, kind):
            s = 1 if rng.random() < 0.5 else -1
            e_in = 0.0
            if rng.random() < P["rumour_chance"]:
                lo, hi = P["rumour_lead_ticks"]
                tr = max(0, t_res - rng.randint(lo, hi))
                rel = rng.choice(P["rumour_reliability"])
                srep = s if rng.random() < rel else -s
                e_in = P["priced_in"] * (2 * rel - 1) * srep * m
                for i, w in eff:
                    pa[i][tr] += e_in * w
                self.rumours.append((tr, rel, srep, eff, m, t_res))
            if rng.random() < P["tip_chance"]:
                lo, hi = P["tip_lead_ticks"]
                tt = max(0, t_res - rng.randint(lo, hi))
                rel = P["tip_reliability"]
                srep = s if rng.random() < rel else -s
                self.tips.append((tt, rel, srep, eff, m, t_res))
            sur = s * m - e_in
            for i, w in eff:
                pa[i][t_res] += sur * w
                xa[i][t_res] += P["overreact"] * sur * w
            self.events.append((t_res, eff, s, m, e_in, kind))

        def company_eff(i):
            r = RIVAL[i]
            return [(i, 1.0)] + ([(r, -P["world_rival_share"])] if r is not None else [])

        every = P["earnings_every_days"]
        for i in range(N):
            for d in range(rng.randrange(every), DAYS, every):
                add(d * TPD, company_eff(i), CLS[i]["ev_mag"] * rng.uniform(0.5, 1.5), "calendar")
        for _ in range(poisson(rng, P["news_per_day"] * DAYS)):
            i = rng.randrange(N)
            add(rng.randrange(T), company_eff(i), CLS[i]["ev_mag"] * rng.uniform(0.5, 1.5), "world")
        for _name, kind, effects, mag, per in TEMPLATES:
            eff = [(IDX[k], w) for k, w in effects.items()]
            if kind == "calendar":
                d = rng.randrange(per)
                while d < DAYS:
                    add(d * TPD + rng.randrange(TPD), eff, mag * rng.uniform(0.6, 1.4), kind)
                    d += per
            else:
                for _ in range(poisson(rng, DAYS / per)):
                    add(rng.randrange(T), eff, mag * rng.uniform(0.6, 1.4), kind)
        self.rumours.sort(key=lambda r: r[0])
        self.tips.sort(key=lambda r: r[0])

        rm, rs = P["rho_market"], P["rho_sector"]
        ri = math.sqrt(1 - rm * rm - rs * rs)
        sig = [CLS[i]["vol_day"] / math.sqrt(TPD + 3) for i in range(N)]
        x, xp, pm = [0.0] * N, [0.0] * N, [0.0] * N
        self.logp = [[0.0] * T for _ in range(N)]
        self.x = [[0.0] * T for _ in range(N)]
        self.perm = [[0.0] * T for _ in range(N)]
        g = rng.gauss
        ns = len(SECTORS)
        for t in range(T):
            gap = 2.0 if t % TPD == 0 else 1.0
            zm = g(0.0, 1.0)
            zs = [g(0.0, 1.0) for _ in range(ns)]
            for i in range(N):
                z = rm * zm + rs * zs[SEC[i]] + ri * g(0.0, 1.0)
                xn = A1 * x[i] + A2 * xp[i] + gap * sig[i] * z + xa[i][t]
                xp[i] = x[i]
                x[i] = xn
                pm[i] = pm[i] * DP + pa[i][t]
                self.logp[i][t] = pm[i] + xn
                self.x[i][t] = xn
                self.perm[i][t] = pm[i]
        self.sdx = [statistics.pstdev(self.x[i]) for i in range(N)]


class Run:
    """One strategy on one world: the book, costs, caps, overlays and the regulator."""

    def __init__(self, world, cfg, rng, cash):
        self.w, self.c, self.rng = world, cfg, rng
        self.cash = self.cash0 = cash
        self.imp = [[] for _ in range(N)]       # (t0, ax, ap) price impulses from the player
        self.lots = [[] for _ in range(N)]      # [t, shares (<0 short), cost or proceeds, susp, tag, dividends]
        self.bought = [0.0] * N
        self.bday = -1
        self.pevents = []                       # (t, i, material)
        self.last_material = [-10 ** 9] * N
        self.flags = 0
        self.seized = 0.0
        self.equity = []

    # Prices
    def lp(self, i, t):
        v = self.w.logp[i][t]
        for t0, ax, ap in self.imp[i]:
            k = t - t0
            if k >= 0:
                if ax and k < HX_LIVE:
                    v += ax * HX[k]
                if ap:
                    v += ap * HP[k]
        return v

    def mid(self, i, t):
        return math.exp(self.lp(i, t))

    def shares(self, i):
        return sum(l[1] for l in self.lots[i])

    def book(self, t):
        return sum(abs(self.shares(i)) * self.mid(i, t) for i in range(N) if self.lots[i])

    def impulse(self, i, t0, ax, ap):
        if t0 < T:
            imp = self.imp[i]
            if len(imp) > 12:   # time only moves forward: drop transient impulses that have died out
                imp[:] = [e for e in imp if e[2] or t0 - e[0] < HX_LIVE]
            imp.append((t0, ax, ap))

    def _day(self, t):
        d = t // TPD
        if d != self.bday:
            self.bday, self.bought = d, [0.0] * N

    def _post_susp(self, i, t):
        if not self.c["counters"]:
            return 0.0
        for te, j, mat in reversed(self.pevents):
            if t - te > self.c["post_watch_ticks"]:
                break
            if mat and (j == i or RIVAL[j] == i):
                return self.c["post_weight"]
        return 0.0

    # Orders
    def buy(self, i, t, value, short=False, tag=""):
        self._day(t)
        c, k = self.c, CLS[i]
        if short and not c["allow_short"]:
            return 0.0
        m = self.mid(i, t)
        pos = abs(self.shares(i)) * m
        room = min(value, c["buy_limit_w"] - self.bought[i], c["pos_cap_w"] - pos,
                   c["book_cap_w"] - self.book(t))
        if not short:
            room = min(room, self.cash / (1 + c["broker_fee"]))
        if room <= 1e-6:
            return 0.0
        imp = c["impact_k"] * math.sqrt(room / k["volume_w"])
        if short:   # sell borrowed shares at the bid
            fill = m * (1 - k["half_spread"] - imp)
            sh = room / fill
            self.cash += room * (1 - c["broker_fee"] - c["sales_tax"])
            self.lots[i].append([t, -sh, room * (1 - c["broker_fee"] - c["sales_tax"]), self._post_susp(i, t), tag, 0.0])
            self.impulse(i, t + 1, -imp, 0.0)
        else:
            fill = m * (1 + k["half_spread"] + imp)
            sh = room / fill
            cost = room * (1 + c["broker_fee"])
            self.cash -= cost
            self.lots[i].append([t, sh, cost, self._post_susp(i, t), tag, 0.0])
            self.impulse(i, t + 1, imp, 0.0)
        self.bought[i] += room
        return room

    def sell(self, i, t, force=False, tag=None):
        c, k = self.c, CLS[i]
        ready = [l for l in self.lots[i] if (force or t - l[0] >= c["min_hold_ticks"])
                 and (tag is None or l[4] == tag)]
        if not ready:
            return 0.0
        self.lots[i] = [l for l in self.lots[i] if l not in ready]
        m = self.mid(i, t)
        longs = [l for l in ready if l[1] > 0]
        shorts = [l for l in ready if l[1] < 0]
        pnl_sus, susp, val_sus, total = 0.0, 0.0, 0.0, 0.0
        if longs:
            sh = sum(l[1] for l in longs)
            imp = c["impact_k"] * math.sqrt(sh * m / k["volume_w"])
            px = m * (1 - k["half_spread"] - imp) * (1 - c["broker_fee"] - c["sales_tax"])
            for l in longs:
                g = l[1] * px - l[2] + l[5]   # dividends on a flagged lot are seized too
                total += l[1] * px
                if l[3] > 0:
                    pnl_sus += g
                    susp = max(susp, l[3])
                    val_sus += l[1] * m
            self.cash += sh * px
            self.impulse(i, t + 1, -imp, 0.0)
        if shorts:
            sh = -sum(l[1] for l in shorts)
            imp = c["impact_k"] * math.sqrt(sh * m / k["volume_w"])
            px = m * (1 + k["half_spread"] + imp) * (1 + c["broker_fee"])
            for l in shorts:
                g = l[2] - (-l[1]) * px + l[5]
                if l[3] > 0:
                    pnl_sus += g
                    susp = max(susp, l[3])
                    val_sus += -l[1] * m
            self.cash -= sh * px
            self.impulse(i, t + 1, imp, 0.0)
        if susp > 0 and c["counters"]:
            p = min(c["p_max"], c["p_floor"] + c["p_size"] * susp * min(1.0, val_sus / c["pos_cap_w"])
                    + c["p_repeat"] * self.flags)
            if self.rng.random() < p:
                self.flags += 1
                hit = max(pnl_sus, 0.0) * (1 + c["fine_mult"])
                self.cash -= hit
                self.seized += hit
        return total

    def close_day(self, t):
        """Dividends at the 20:00 close; shorts pay them."""
        if t % TPD != TPD - 1:
            return
        for i in range(N):
            if self.lots[i]:
                m = self.mid(i, t)
                for l in self.lots[i]:
                    d = l[1] * m * CLS[i]["div_day"]
                    l[5] += d
                    self.cash += d
        self.equity.append(self.cash + sum(self.shares(i) * self.mid(i, t) for i in range(N) if self.lots[i]))

    def liquidate(self):
        for i in range(N):
            if self.lots[i]:
                self.sell(i, T - 1, force=True)
        return (self.cash - self.cash0) / DAYS

    # Player-caused events
    def player_perm(self, i, t):
        return sum(ap * HP[t - t0] for t0, ax, ap in self.imp[i] if ap and t >= t0 and ap < 0)

    def player_event(self, i, t, kind):
        """A material crime against company i during hour t; the market reacts at t + 1."""
        c = self.c
        m = c[kind][CL[i]]
        insured = c["insured_share"] if c["counters"] else 0.0
        if c["counters"]:
            if t - self.last_material[i] < c["cooldown_days"] * TPD:
                m = 0.0
            else:
                same = sum(1 for te, j, mat in self.pevents
                           if mat and j == i and t - te < c["repeat_memory_days"] * TPD)
                allp = sum(1 for te, j, mat in self.pevents
                           if mat and t - te < c["pattern_memory_days"] * TPD)
                m *= c["repeat_decay"] ** same * c["pattern_decay"] ** allp
        perm, scare = -m * (1 - insured), -m * c["scare"]
        if c["counters"] and m > 0:
            cur = self.player_perm(i, t + 1)
            perm = max(perm, min(0.0, c["player_impact_floor"] - cur))
        material = m > 0
        self.pevents.append((t, i, material))
        if not material:
            return 0.0
        self.last_material[i] = t
        self.impulse(i, t + 1, scare, perm)
        r = RIVAL[i]
        if r is not None:
            self.impulse(r, t + 1, -c["rival_share"] * scare, -c["rival_share"] * perm)
        # The SSC opens a case only when the crime's expected gain to the whole book is
        # over case_min_w, so an index holder who wrecks a van is never flagged; then it
        # marks each lot that gains.
        gain = m * (-self.shares(i) * self.mid(i, t)
                    + (c["rival_share"] * self.shares(r) * self.mid(r, t) if r is not None else 0.0))
        if c["counters"] and gain > c["case_min_w"]:
            for j, want_long in ((r, True), (i, False)):
                if j is None:
                    continue
                for l in self.lots[j]:
                    if (l[1] > 0) == want_long:
                        l[3] = max(l[3], 1e-6 + math.exp(-(t - l[0]) / c["watch_tau_ticks"]))
        return perm + scare


# ----------------------------------------------------------------------------- strategies

def s_passive(run):
    s_passive_setup(run)
    for t in range(T):
        run.close_day(t)


def s_passive_crimes(run):
    """Fairness: an index holder who also wrecks a paired company's property every 3 days."""
    s_passive_setup(run)
    rng = random.Random(run.rng.random())
    for t in range(T):
        if t % (3 * TPD) == 1:
            run.player_event(rng.choice(PAIRED), t, "sab_mag")
        run.close_day(t)


def s_passive_setup(run):
    each = run.c["book_cap_w"] / N
    for i in range(N):
        run.buy(i, 0, each, tag="core")


def s_casual(run):
    rng = random.Random(run.rng.random())
    for t in range(T):
        if rng.random() < 0.5 / TPD:
            run.buy(rng.randrange(N), t, 2.0)
        if rng.random() < 0.3 / TPD:
            run.sell(rng.randrange(N), t)
        run.close_day(t)


def _expected(eff, srep, m, rel, priced):
    best = max(eff, key=lambda e: e[1] * srep)
    edge = best[1] * srep * m * (2 * rel - 1) * (1 - priced)
    return best[0], edge


def s_skilled(run, tips=False, size=None, core=0.5):
    """Holds `core` of the book as an index and trades the news feed with the rest:
    public rumours of reliability 0.7 or more, plus paid tips when `tips`."""
    w, c = run.w, run.c
    each = core * c["book_cap_w"] / N
    for i in range(N):
        run.buy(i, 0, each, tag="core")
    news = [(r, c["priced_in"]) for r in w.rumours if r[1] >= 0.7]
    if tips:
        news += [(r, 0.0) for r in w.tips]
    news.sort(key=lambda n: n[0][0])
    exits = {}
    k = 0
    tips_day, tday = 0, -1
    for t in range(T):
        while k < len(news) and news[k][0][0] <= t:
            (tr, rel, srep, eff, m, t_res), priced = news[k]
            k += 1
            if t_res <= t:
                continue
            if priced == 0.0:
                if t // TPD != tday:
                    tday, tips_day = t // TPD, 0
                if tips_day >= c["tips_per_day"]:
                    continue
                tips_day += 1
                run.cash -= c["tip_fee_w"]
            i, edge = _expected(eff, srep, m, rel, priced)
            if edge < c["skill_min_edge"]:
                continue
            amt = size(run, t) if size else c["buy_limit_w"]
            if run.buy(i, t, amt, tag="s") > 0:
                ts = max(t_res + 1, t + c["min_hold_ticks"])
                exits.setdefault(min(ts, T - 1), []).append(i)
        for i in exits.pop(t, []):
            run.sell(i, t, tag="s")
        run.close_day(t)


def s_compound(run):
    """Skilled with tips and no caps: each trade is a quarter of current wealth."""
    def size(r, t):
        return 0.25 * (r.cash + r.book(t))
    s_skilled(run, tips=True, size=size, core=0.0)


def s_sab_loop(run):
    """Hold the rival of GWF at the cap and hit GWF's vans every day."""
    tgt, riv = IDX["GWF"], IDX["SVL"]
    for t in range(T):
        h = t % TPD
        if h == 0:
            run.buy(riv, t, run.c["buy_limit_w"])
        if h == 1:
            run.player_event(tgt, t, "sab_mag")
        run.close_day(t)


def s_short_sab(run):
    """If short selling existed: short GWF at the cap and hit it every day."""
    tgt = IDX["GWF"]
    for t in range(T):
        h = t % TPD
        if h == 0:
            run.buy(tgt, t, run.c["buy_limit_w"], short=True)
        if h == 1:
            run.player_event(tgt, t, "sab_mag")
        run.close_day(t)


def s_sab_quiet(run):
    """Stay under the SSC's radar: hold the rival of one company in each pair, each sized
    so one crime's expected gain is just under case_min_w, and hit one target a day."""
    c = run.c
    targets = [IDX[k] for k in ("GWF", "HLB", "LTV", "GMB")]
    for i in targets:
        run.buy(RIVAL[i], 0, 0.95 * c["case_min_w"] / (c["sab_mag"][CL[i]] * c["rival_share"]))
    for t in range(T):
        d, h = divmod(t, TPD)
        if h == 1:
            run.player_event(targets[d % len(targets)], t, "sab_mag")
        run.close_day(t)


def s_sab_rotate(run):
    """Each day hit a different paired company; ladder into its rival the day before."""
    order = PAIRED
    for t in range(T):
        d, h = divmod(t, TPD)
        tgt, nxt = order[d % len(order)], order[(d + 1) % len(order)]
        if h == 0:
            for i in range(N):
                run.sell(i, t)
            run.buy(RIVAL[tgt], t, run.c["buy_limit_w"])
            run.buy(RIVAL[nxt], t, run.c["pos_cap_w"] - run.c["buy_limit_w"])
        if h == 1:
            run.player_event(tgt, t, "sab_mag")
        run.close_day(t)


def s_sab_dip(run):
    """Hit a company with no position, buy its dip next hour, sell two days later."""
    exits = {}
    for t in range(T):
        d, h = divmod(t, TPD)
        tgt = d % N
        if h == 1:
            run.player_event(tgt, t, "sab_mag")
        if h == 2 and run.buy(tgt, t, run.c["buy_limit_w"]) > 0:
            exits.setdefault(min(t + 2 * TPD, T - 1), []).append(tgt)
        for i in exits.pop(t, []):
            run.sell(i, t)
        run.close_day(t)


def _heists(run, lead_days):
    """A heist every 5 days on a rotating paired target; buy its rival lead_days before."""
    plan = {}
    for n, d in enumerate(range(max(lead_days, 1), DAYS - 3, 5)):
        tgt = PAIRED[n % len(PAIRED)]
        plan[d] = tgt
    exits = {}
    for t in range(T):
        d, h = divmod(t, TPD)
        if h == 0:
            for hd, tgt in plan.items():
                if hd - lead_days <= d < hd or (lead_days == 0 and d == hd):
                    run.buy(RIVAL[tgt], t, run.c["buy_limit_w"])
        if h == 1 and d in plan:
            run.player_event(plan[d], t, "heist_mag")
            exits.setdefault(min(t + 2 * TPD, T - 1), []).append(RIVAL[plan[d]])
        for i in exits.pop(t, []):
            run.sell(i, t)
        run.close_day(t)


def s_insider_quick(run):
    _heists(run, 1)


def s_insider_patient(run):
    _heists(run, 6)


def s_pump(run):
    """Buy a small cap to the cap over two days, dump on the third; rotate small caps."""
    smalls = [i for i in range(N) if CL[i] == "H"]
    for t in range(T):
        d, h = divmod(t, TPD)
        tgt = smalls[(d // 3) % len(smalls)]
        if h == 0:
            if d % 3 in (0, 1):
                run.buy(tgt, t, run.c["pos_cap_w"])
            else:
                for i in range(N):
                    run.sell(i, t)
        run.close_day(t)


def s_churn(run):
    """Tick scalper: buy any 1-sigma dip on mid caps, sell at the first gain or after 3 days."""
    mids = [i for i in range(N) if CL[i] == "M"]
    sig = {i: CLS[i]["vol_day"] / math.sqrt(TPD + 3) for i in mids}
    for t in range(1, T):
        for i in mids:
            if run.w.logp[i][t] - run.w.logp[i][t - 1] < -sig[i]:   # the hourly move on the chart
                run.buy(i, t, 2.0)
            elif run.lots[i]:
                l0 = run.lots[i][0]
                if run.mid(i, t) * run.shares(i) > sum(l[2] for l in run.lots[i]) or t - l0[0] > 3 * TPD:
                    run.sell(i, t)
        run.close_day(t)


def s_oracle(run):
    """Perfect foresight (a fixed future, scouted then reloaded), within every cap and cost."""
    c, w = run.c, run.w
    hold = c["min_hold_ticks"]
    plan_buy, plan_sell = {}, {}
    for t in range(T):
        d, h = divmod(t, TPD)
        if h == 0 and d < DAYS - 1:
            cands = []
            for i in range(N):
                lp = w.logp[i]
                k = CLS[i]
                cost = math.log((1 + k["half_spread"] + 0.003) * (1 + c["broker_fee"])) - \
                    math.log((1 - k["half_spread"] - 0.003) * (1 - c["broker_fee"] - c["sales_tax"]))
                for tb in range(t, t + TPD):
                    hi = min(tb + hold + TPD, T - 1)
                    if tb + hold > hi:
                        continue
                    seg = lp[tb + hold:hi + 1]
                    top = max(seg)
                    ts = tb + hold + seg.index(top)
                    gain = top - lp[tb] - cost
                    if gain > 0:
                        cands.append((gain, i, tb, ts))
            cands.sort(reverse=True)
            used = set()
            for gain, i, tb, ts in cands:
                if i not in used:
                    used.add(i)
                    plan_buy.setdefault(tb, []).append((i, ts))
        for i, ts in plan_buy.pop(t, []):
            if run.buy(i, t, c["buy_limit_w"]) > 0:
                plan_sell.setdefault(ts, []).append(i)
        for i in plan_sell.pop(t, []):
            run.sell(i, t)
        run.close_day(t)


SCUM_NAMES = [IDX[k] for k in ("SVL", "BWK", "BZL", "BYB")]


def _scum_setup(world, cfg):
    res = {}
    for t_res, eff, s, m, e_in, kind in world.events:
        for i, wt in eff:
            if i in SCUM_NAMES:
                res.setdefault(t_res, []).append((i, wt, m, e_in))
    return res


def _scum_step(st, t, res, rng, cfg):
    """One market hour for the scum book, drawn fresh (a restore rerolls the future,
    event outcomes included); st maps company -> [x, x_prev, perm]."""
    rm, rs = cfg["rho_market"], cfg["rho_sector"]
    ri = math.sqrt(1 - rm * rm - rs * rs)
    gap = 2.0 if t % TPD == 0 else 1.0
    zm = rng.gauss(0, 1)
    out = {}
    for i in SCUM_NAMES:
        x, xp, pm = st[i]
        shock_p, shock_x = 0.0, 0.0
        for j, wt, m, e_in in res.get(t, ()):
            if j == i:
                sur = (1 if rng.random() < 0.5 else -1) * m - e_in
                shock_p += sur * wt
                shock_x += cfg["overreact"] * sur * wt
        z = rm * zm + rs * rng.gauss(0, 1) + ri * rng.gauss(0, 1)
        xn = A1 * x + A2 * xp + gap * CLS[i]["vol_day"] / math.sqrt(TPD + 3) * z + shock_x
        out[i] = [xn, x, pm * DP + shock_p]
    return out


def _px(st, i):
    return math.exp(st[i][0] + st[i][2])


def copy_scum(world, rng, cfg):
    """Save copied outside the game once a game day: the player keeps the best of
    `copy_attempts` versions of each day for a full book of the four liveliest names."""
    res = _scum_setup(world, cfg)
    per = cfg["book_cap_w"] / len(SCUM_NAMES)
    fee, tax = cfg["broker_fee"], cfg["sales_tax"]
    st = {i: [0.0, 0.0, 0.0] for i in SCUM_NAMES}
    sh = {}
    cash = cfg["book_cap_w"]
    for i in SCUM_NAMES:  # buy the book at the open of day 0 (ignores the buy limit: generous)
        k = CLS[i]
        imp = cfg["impact_k"] * math.sqrt(per / k["volume_w"])
        sh[i] = per / (1 + k["half_spread"] + imp)
        cash -= per * (1 + fee)
    for d in range(DAYS):
        best = None
        for _a in range(cfg["copy_attempts"]):
            s2 = st
            for h in range(TPD):
                s2 = _scum_step(s2, d * TPD + h, res, rng, cfg)
            val = sum(sh[i] * _px(s2, i) for i in SCUM_NAMES)
            if best is None or val > best[0]:
                best = (val, s2)
        st = best[1]
        cash += sum(sh[i] * _px(st, i) * CLS[i]["div_day"] for i in SCUM_NAMES)
    for i in SCUM_NAMES:
        k = CLS[i]
        px = _px(st, i)
        imp = cfg["impact_k"] * math.sqrt(sh[i] * px / k["volume_w"])
        cash += sh[i] * px * (1 - k["half_spread"] - imp) * (1 - fee - tax)
    return (cash - cfg["book_cap_w"]) / DAYS


def copy_scum_hourly(world, rng, cfg):
    """Save copied outside the game every game hour (PC or emulator with a script):
    best of `copy_attempts` per hour, pushing prices down while out, buying, then
    pushing them up and selling. Returns W per REAL hour spent."""
    res = _scum_setup(world, cfg)
    fee, tax, lim = cfg["broker_fee"], cfg["sales_tax"], cfg["buy_limit_w"]
    st = {i: [0.0, 0.0, 0.0] for i in SCUM_NAMES}
    sh, cost, pnl, n_in, up = {}, 0.0, 0.0, 0, False
    for t in range(T):
        cands = [_scum_step(st, t, res, rng, cfg) for _ in range(cfg["copy_attempts"])]
        key = lambda s2: sum(_px(s2, i) for i in SCUM_NAMES)
        st = max(cands, key=key) if up else min(cands, key=key)
        n_in += 1
        last = t == T - 1
        if not up and n_in >= cfg["scum_phase_ticks"] and not last:
            cost = 0.0
            for i in SCUM_NAMES:
                k = CLS[i]
                imp = cfg["impact_k"] * math.sqrt(lim / k["volume_w"])
                sh[i] = lim / (_px(st, i) * (1 + k["half_spread"] + imp))
                cost += lim * (1 + fee)
            up, n_in = True, 0
        elif up and (n_in >= cfg["scum_phase_ticks"] or last):
            for i in SCUM_NAMES:
                k, px = CLS[i], _px(st, i)
                imp = cfg["impact_k"] * math.sqrt(sh[i] * px / k["volume_w"])
                pnl += sh[i] * px * (1 - k["half_spread"] - imp) * (1 - fee - tax)
            pnl -= cost
            up, n_in = False, 0
        if up and t % TPD == TPD - 1:
            pnl += sum(sh[i] * _px(st, i) * CLS[i]["div_day"] for i in SCUM_NAMES)
    return pnl / (T * cfg["copy_attempts"] * cfg["scum_minutes_per_try"] / 60)


def reload_naive(world, rng, cfg):
    """A naive save that rerolls mispricing on load (the GTA V exploit): reload until a
    low to buy, reload until a high to sell, one round trip a day on a full book."""
    names = sorted(range(N), key=lambda i: -world.sdx[i])[:int(cfg["book_cap_w"] // cfg["buy_limit_w"])]
    fee, tax = cfg["broker_fee"], cfg["sales_tax"]
    pnl = 0.0
    for _d in range(DAYS - 1):
        for i in names:
            k, sd = CLS[i], world.sdx[i]
            lo = min(rng.gauss(0, sd) for _ in range(cfg["reloads"]))
            hi = max(rng.gauss(0, sd) for _ in range(cfg["reloads"]))
            v = cfg["buy_limit_w"]
            imp = cfg["impact_k"] * math.sqrt(v / k["volume_w"])
            ratio = math.exp(hi - lo) * (1 - k["half_spread"] - imp) * (1 - fee - tax) / \
                ((1 + k["half_spread"] + imp) * (1 + fee))
            pnl += v * (ratio - 1)
    return pnl / DAYS


def clock_bot(cfg, taxi_cap, taps_count):
    """Greedy time skipper for one real hour; returns game days the market clock advances.

    Each step takes the cheapest legal jump: sleep once 16 h awake, a 3 h tap if taps move the
    clock, a taxi ride while the day's taxi allowance lasts, else 6 game minutes of play. Taxi and
    tap time count as awake, which earns sleep sooner (the worst case for the rules)."""
    real = clock = awake = taxi_day = 0.0
    day = 0
    while real < 60.0:
        if int(clock // 24) != day:
            day, taxi_day = int(clock // 24), 0.0
        if awake >= cfg["awake_per_sleep_h"]:
            clock += cfg["sleep_h"]
            awake = 0.0
            real += cfg["load_real_min"]
        elif taps_count:
            clock += 3.0
            awake += 3.0
            real += cfg["tap_real_min"]
        elif taxi_day < taxi_cap:
            h = min(cfg["taxi_ride_h"], taxi_cap - taxi_day)
            clock += h
            awake += h
            taxi_day += h
            real += cfg["load_real_min"]
        else:
            clock += 0.1
            awake += 0.1
            real += 0.1
    return clock / 24


def payday(world, rng, cfg):
    """An authored story tip: buy up to tip_cap_w, the mission lands the next day."""
    c = dict(cfg, buy_limit_w=cfg["tip_cap_w"], pos_cap_w=cfg["tip_cap_w"],
             book_cap_w=cfg["tip_cap_w"], counters=False)
    run = Run(world, c, rng, cfg["tip_cap_w"])
    d = rng.randrange(10, DAYS - 5)
    i = IDX["GWF"]
    tb = d * TPD + 1
    run.buy(i, tb, c["tip_cap_w"])
    run.impulse(i, (d + 1) * TPD + 7, 0.0, c["payday_move"])
    run.impulse(IDX["SVL"], (d + 1) * TPD + 7, 0.0, -c["payday_move"])
    run.sell(i, (d + 1) * TPD + 8)
    return run.cash - run.cash0


# ----------------------------------------------------------------------------- main

def sub_seed(name, r):
    """Stable per-run seed (Python's hash() of a str changes between processes)."""
    return zlib.crc32(("%d:%s:%d" % (SEED, name, r)).encode())


def stats(xs):
    xs = sorted(xs)
    n = len(xs)
    return statistics.fmean(xs), statistics.pstdev(xs), xs[n // 10], xs[(9 * n) // 10]


def main():
    t_start = time.time()
    worlds = [World(SEED * 1000 + r) for r in range(RUNS)]
    rows = []

    def run_strategy(name, fn, **over):
        cfg = dict(P, **over)
        out, flags, seized, eq = [], [], [], []
        for r, w in enumerate(worlds):
            run = Run(w, cfg, random.Random(sub_seed(name, r)), P["book_cap_w"])
            fn(run)
            out.append(run.liquidate())
            flags.append(run.flags)
            seized.append(run.seized)
            eq.append(run.equity)
        return out, flags, seized, eq

    def other(name, fn, **over):
        cfg = dict(P, **over)
        return [fn(w, random.Random(sub_seed(name, r)), cfg) for r, w in enumerate(worlds)]

    def add(label, xs, extra=""):
        rows.append((label, stats(xs), extra))

    res = {}
    for key, label, fn, over in [
        ("passive", "Passive index, hold 60 days", s_passive, {}),
        ("fair", "Passive + own crime every 3 days (fairness)", s_passive_crimes, {}),
        ("casual", "Casual random trades", s_casual, {}),
        ("skilled", "Skilled: half index + public rumours", s_skilled, {}),
        ("tips", "Skilled: half index + rumours + paid tips", lambda r: s_skilled(r, tips=True), {}),
        ("sab", "1 Sabotage loop: hold rival, hit daily", s_sab_loop, {}),
        ("sab_off", "1 ... same, no counters", s_sab_loop, {"counters": False}),
        ("sab_rot", "1 Sabotage rotation over 8 targets", s_sab_rotate, {}),
        ("sab_small", "1 Sabotage rotation, sized under case_min_w", s_sab_quiet, {}),
        ("sab_small_off", "1 ... same, no counters", s_sab_quiet, {"counters": False}),
        ("sab_dip", "1 Sabotage then buy the dip", s_sab_dip, {}),
        ("ins_q", "2 Insider: rival bought 1 day before heist", s_insider_quick, {}),
        ("ins_q_off", "2 ... same, no counters", s_insider_quick, {"counters": False}),
        ("ins_p", "2 Insider: rival bought 6 days before", s_insider_patient, {}),
        ("pump", "3 Pump and dump, small caps", s_pump, {}),
        ("pump_off", "3 ... no caps or buy limits", s_pump,
         {"pos_cap_w": 1e9, "book_cap_w": 1e9, "buy_limit_w": 24.0}),
        ("churn", "4 Tick scalper (T+1 on)", s_churn, {}),
        ("churn_off", "4 ... no minimum hold", s_churn, {"min_hold_ticks": 0}),
        ("oracle", "5 Oracle: fixed future scouted, per kept day", s_oracle, {}),
        ("short", "8 Short + sabotage (if shorts existed)", s_short_sab, {"allow_short": True}),
        ("comp_off", "7 Compounding, no caps (tips trader)", s_compound,
         {"pos_cap_w": 1e9, "book_cap_w": 1e9, "buy_limit_w": 1e9}),
    ]:
        out, flags, seized, eq = run_strategy(key, fn, **over)
        res[key] = (out, flags, seized, eq)
        extra = ""
        if over.get("counters", True) and max(flags) > 0:
            extra = "flags %.1f, seized %.2fW" % (statistics.fmean(flags), statistics.fmean(seized))
        add(label, out, extra)
    reload_s = res["passive"][0]
    add("5 Reload, Solvera save (nothing rerolls)", reload_s, "= passive")
    add("5 Reload, naive save (reroll on load)", other("reload", reload_naive))
    cs = other("copy", copy_scum)
    add("5 Save copy daily, best of %d, per kept day" % P["copy_attempts"], cs)
    add("5 ... same, per game day of real play", [v / P["copy_attempts"] for v in cs])
    hs = other("hourly", copy_scum_hourly)
    add("5 Save copy hourly, best of %d: W per REAL hour" % P["copy_attempts"], hs, "side jobs 2.50")
    add("5 Oracle, per real day (scouting x%d)" % P["oracle_real_days"],
        [v / P["oracle_real_days"] for v in res["oracle"][0]])
    pd = other("payday", payday)
    rows.append(("Authored payday (one-off total, not /day)", stats(pd), "tip_cap_w %.0f" % P["tip_cap_w"]))

    def growth(eq):
        a = statistics.fmean((e[19] - e[0]) / 19 for e in eq)
        b = statistics.fmean((e[-1] - e[-21]) / 20 for e in eq)
        return b / a if a else float("nan")
    _, _, _, eq_tips = res["tips"]
    _, _, _, eq_off = res["comp_off"]

    # Output
    pr = print
    pr("Solvera stock market sim  seed=%d  runs=%d  days=%d  ticks/day=%d  companies=%d" %
       (SEED, RUNS, DAYS, TPD, N))
    pr("Money in W (side-job pay per game day); P&L per game day after all costs, fines and fees.")
    pr("%-46s %7s %6s %7s %7s  %s" % ("strategy", "mean", "sd", "p10", "p90", "notes"))
    for label, (mn, sd, p10, p90), extra in rows:
        pr("%-46s %7.3f %6.3f %7.3f %7.3f  %s" % (label, mn, sd, p10, p90, extra))
    pas = statistics.fmean(res["passive"][0])
    days_per_hour = 60 / 24
    big = 1e9
    clk = {"sleep": clock_bot(P, 0.0, False), "rules": clock_bot(P, P["taxi_cap_h_per_day"], False),
           "taxi_off": clock_bot(P, big, False), "taps": clock_bot(P, big, True)}
    pr("6 Time skip, clock bot (passive income per REAL hour, game days/h in brackets; side jobs = %.2fW):"
       % days_per_hour)
    pr("    normal play %.3f (%.2f) | sleep rule %.3f (%.2f) | sleep + taxi cap %.0fh/day (all rules) %.3f (%.2f)" %
       (pas * days_per_hour, days_per_hour, pas * clk["sleep"], clk["sleep"], P["taxi_cap_h_per_day"],
        pas * clk["rules"], clk["rules"]))
    pr("    no taxi cap %.3f (%.2f) | 3h-skip taps move the clock %.3f (%.2f)" %
       (pas * clk["taxi_off"], clk["taxi_off"], pas * clk["taps"], clk["taps"]))
    pr("    all rules: skilled %.3f | tips %.3f | tips + businesses at the %.2fW/day cap %.3f" %
       (statistics.fmean(res["skilled"][0]) * clk["rules"], statistics.fmean(res["tips"][0]) * clk["rules"],
        P["biz_cap_w_per_day"], (statistics.fmean(res["tips"][0]) + P["biz_cap_w_per_day"]) * clk["rules"]))
    pr("7 Compounding: P&L/day in days 41-60 vs days 1-20:  caps on x%.2f | no caps x%.2f" %
       (growth(eq_tips), growth(eq_off)))

    sk = statistics.fmean(res["skilled"][0])
    tp = statistics.fmean(res["tips"][0])
    exploit_keys = ["sab", "sab_rot", "sab_small", "sab_dip", "ins_q", "ins_p", "pump", "churn"]
    worst = max(exploit_keys, key=lambda k: statistics.fmean(res[k][0]))
    worst_v = statistics.fmean(res[worst][0]) + 0.5 * pas   # an exploiter may hold half an index too
    fair_flags = statistics.fmean(res["fair"][1])
    hs_m = statistics.fmean(hs)
    cs_real = statistics.fmean(cs) / P["copy_attempts"]
    or_real = statistics.fmean(res["oracle"][0]) / P["oracle_real_days"]
    pd_m = statistics.fmean(pd)
    checks = [
        ("passive in 0.05-0.15 W/day", 0.05 <= pas <= 0.15, "%.3f" % pas),
        ("skilled > passive and <= 0.5 W/day", pas < sk <= 0.5 and tp <= 0.5, "%.3f / tips %.3f" % (sk, tp)),
        ("every exploit (counters on) + half index <= skilled public", worst_v <= sk,
         "worst %s %.3f" % (worst, worst_v)),
        ("index holder's own crimes never flagged", fair_flags == 0, "flags %.2f" % fair_flags),
        ("hourly save copying < side jobs per real hour (2.5 W)", hs_m < days_per_hour, "%.3f" % hs_m),
        ("save copy and oracle per real day < side jobs (1 W)", max(cs_real, or_real) < 1.0,
         "%.3f / %.3f" % (cs_real, or_real)),
        ("authored payday p90 <= 8 W, one-off", stats(pd)[3] <= 8.0,
         "mean %.2f, p90 %.2f" % (pd_m, stats(pd)[3])),
        ("clock bot, all rules: tips + businesses < side jobs per real hour (taxi cap binds)",
         (max(pas, sk, tp) + P["biz_cap_w_per_day"]) * clk["rules"] < days_per_hour
         and clk["rules"] < clk["taxi_off"],
         "%.3f (passive alone %.3f, no cap %.3f)" % ((max(pas, sk, tp) + P["biz_cap_w_per_day"]) * clk["rules"],
                                                     pas * clk["rules"], pas * clk["taxi_off"])),
    ]
    for name, ok, val in checks:
        pr("  [%s] %s: %s" % ("PASS" if ok else "FAIL", name, val))
    pr("runtime %.1fs" % (time.time() - t_start))
    return 0 if all(ok for _, ok, _ in checks) else 1


if __name__ == "__main__":
    sys.exit(main())
