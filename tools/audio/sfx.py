"""Designs the game's sound effects.

Run: python3 tools/audio/sfx.py
Writes games/prototype/audio/sfx/<id>_<n>.ogg: several variations of each
sound (the game picks one at random and nudges its pitch), so sounds that
play hundreds of times a minute never repeat exactly. Each sound is built
from layers the way a sound designer would: a transient for the attack, a
body for weight and a tail for space.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from synth import (RATE, adsr, expdecay, fft_filter, midi_hz, noise, saw, seconds, sine,  # noqa: E402
                   softclip, square, sweep_filter, tri, write_ogg)

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "games", "prototype", "audio", "sfx")
rng = np.random.default_rng(21)


def r(a, b):
    return float(rng.uniform(a, b))


def env_sweep(n, f0, f1, t):
    """Frequency that glides exponentially from f0 to f1 with time constant t."""
    k = np.exp(-np.arange(n) / (t * RATE))
    return f1 + (f0 - f1) * k


def pad_to(x, n):
    return np.pad(x, (0, max(0, n - len(x))))[:n]


def mix(*layers):
    n = max(len(x) for x in layers)
    out = np.zeros(n, np.float32)
    for x in layers:
        out[: len(x)] += x
    return out


def finish(x, peak=0.9, fade=0.01):
    # Sub-sonic energy wastes headroom and makes Vorbis overshoot.
    x = fft_filter(x.astype(np.float32), high=35.0)
    nf = min(seconds(fade), len(x))
    if nf:
        x[-nf:] *= np.linspace(1.0, 0.0, nf)
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def crackle(n, density, decay):
    """Sparse random impulses: debris, sparks, fire."""
    x = np.zeros(n, np.float32)
    count = int(density * n / RATE)
    pos = rng.integers(0, n, count)
    amp = rng.uniform(0.2, 1.0, count) * np.exp(-pos / (decay * RATE))
    x[pos] = amp * rng.choice([-1.0, 1.0], count)
    return fft_filter(x, center=r(1500, 3500), width=1.2)


# --- Weapons --------------------------------------------------------------------

def shot():
    n = seconds(0.16)
    f = env_sweep(n, r(1700, 2300), r(380, 520), 0.025)
    zap = (square(f, n, 0.4) * 0.5 + saw(f * 1.01, n) * 0.5) * expdecay(n, 0.035)
    zap = fft_filter(zap, low=6000.0)
    thump = sine(env_sweep(n, 220, 90, 0.02), n) * expdecay(n, 0.03) * 0.8
    click = fft_filter(noise(seconds(0.004)), high=3000) * 0.6
    return finish(mix(zap * 0.6, thump, click), 0.75)


def scatter():
    n = seconds(0.42)
    blast = fft_filter(noise(n), low=r(2600, 3400)) * expdecay(n, 0.07)
    body = sine(env_sweep(n, 160, 55, 0.04), n) * expdecay(n, 0.09) * 1.2
    tail = fft_filter(noise(n), low=900) * expdecay(n, 0.18) * 0.4
    x = mix(softclip(blast * 1.5, 2.0), body, tail)
    # The pump racking the next shell.
    click = fft_filter(noise(seconds(0.01)), center=4000, width=0.4) * 0.5
    x[seconds(0.3):seconds(0.3) + len(click)] += click
    return finish(x, 0.85)


def rocket():
    n = seconds(0.45)
    hiss = noise(n) * np.concatenate([np.linspace(0, 1, seconds(0.04)), np.exp(-np.arange(n - seconds(0.04)) / (0.18 * RATE))])
    hiss = sweep_filter(hiss, 900.0, 4500.0, steps=6)
    pop = sine(env_sweep(n, 300, 120, 0.02), n) * expdecay(n, 0.03)
    return finish(mix(hiss * 0.8, pop), 0.7)


def rail():
    charge_n = seconds(0.18)
    charge = sine(np.geomspace(400, r(2400, 3000), charge_n), charge_n) * np.linspace(0.0, 0.5, charge_n)
    n = seconds(0.7)
    crack = fft_filter(noise(n), high=1200) * expdecay(n, 0.02) * 1.5
    beam = (saw(np.full(n, r(110, 130)), n) + saw(np.full(n, r(220, 260)), n) * 0.5) * expdecay(n, 0.25)
    beam = fft_filter(beam, low=2500.0)
    ring = sine(np.full(n, r(3100, 3500)), n) * expdecay(n, 0.3) * 0.15
    return finish(np.concatenate([charge, mix(crack, beam * 0.6, ring)]), 0.85)


def flame():
    n = seconds(0.55)
    roar = fft_filter(noise(n), low=r(1100, 1500)) * adsr(n, 0.03, 0.1, 0.8, 0.25)
    whoosh = sweep_filter(noise(n), 600.0, 2400.0, steps=5) * adsr(n, 0.02, 0.2, 0.4, 0.2) * 0.5
    return finish(mix(softclip(roar * 1.6, 1.8), whoosh, crackle(n, 120, 0.4) * 0.8), 0.75)


def grenade():
    n = seconds(0.3)
    thunk = sine(env_sweep(n, 180, 70, 0.03), n) * expdecay(n, 0.06)
    tube = fft_filter(noise(n), center=700, width=0.6) * expdecay(n, 0.04) * 0.8
    return finish(mix(thunk, tube), 0.75)


def mine():
    n = seconds(0.32)
    x = np.zeros(n, np.float32)
    for t0 in (0.0, 0.14):
        b = seconds(0.07)
        beep = square(np.full(b, 1760.0), b, 0.5) * adsr(b, 0.002, 0.02, 0.7, 0.02) * 0.4
        i = seconds(t0)
        x[i:i + b] += fft_filter(beep, low=5000.0)
    click = fft_filter(noise(seconds(0.006)), center=3000, width=0.5)
    x[: len(click)] += click * 0.6
    return finish(x, 0.6)


def drone():
    n = seconds(0.14)
    f = env_sweep(n, r(2600, 3200), r(900, 1200), 0.03)
    pew = tri(f, n) * expdecay(n, 0.05)
    buzz = square(f * 0.5, n, 0.2) * expdecay(n, 0.03) * 0.3
    return finish(fft_filter(mix(pew, buzz), low=7000.0), 0.55)


def zap():
    n = seconds(0.22)
    base = r(90, 140)
    jitter = np.repeat(rng.uniform(0.6, 2.5, n // 200 + 1), 200)[:n]
    arc = saw(base * jitter * 8.0, n) * 0.5 + square(base * jitter * 4.0, n, 0.3) * 0.5
    arc = fft_filter(arc, center=2500.0, width=1.0) * 2.0
    gate = (rng.random(n // 300 + 1) > 0.25).astype(np.float32)
    gate = np.repeat(gate, 300)[:n]
    snap = fft_filter(noise(seconds(0.01)), high=2000) * 0.8
    x = mix(softclip(arc * gate * expdecay(n, 0.09), 2.0), snap)
    return finish(x, 0.7)


# --- Impacts and explosions ---------------------------------------------------------

def hit():
    n = seconds(0.07)
    tick = fft_filter(noise(n), center=r(1200, 2200), width=0.7) * expdecay(n, 0.012)
    knock = sine(env_sweep(n, 400, 180, 0.01), n) * expdecay(n, 0.02) * 0.6
    return finish(mix(tick, knock), 0.5)


def boom():
    n = seconds(r(0.7, 0.9))
    sub = sine(env_sweep(n, r(110, 140), r(36, 44), 0.06), n) * expdecay(n, 0.22) * 1.3
    blast = sweep_filter(noise(n), r(5000, 7000), 300.0, steps=6) * expdecay(n, 0.16)
    debris = crackle(n, 260, 0.25) * 1.5
    return finish(softclip(mix(sub, blast * 1.2, debris), 1.8), 0.85)


def big_boom():
    n = seconds(r(1.8, 2.2))
    sub = sine(env_sweep(n, r(80, 95), 28.0, 0.12), n) * expdecay(n, 0.6) * 1.4
    blast = sweep_filter(noise(n), 7000.0, 180.0, steps=8) * expdecay(n, 0.35)
    rumble = fft_filter(noise(n), low=260.0) * expdecay(n, 0.8) * 1.2
    debris = crackle(n, 180, 0.9) * 2.0
    crack = fft_filter(noise(seconds(0.02)), high=1500) * 1.2
    return finish(softclip(mix(crack, sub, blast * 1.3, rumble, debris), 2.0), 0.62, 0.2)


def hurt():
    n = seconds(0.3)
    thud = sine(env_sweep(n, 160, 60, 0.03), n) * expdecay(n, 0.08) * 1.2
    crunch = softclip(fft_filter(noise(n), center=900, width=0.8) * expdecay(n, 0.05) * 3.0, 2.5)
    ring = sine(np.full(n, 2400.0), n) * expdecay(n, 0.15) * 0.12
    return finish(mix(thud, crunch * 0.6, ring), 0.8)


# --- Pickups and rewards ------------------------------------------------------------

def gem():
    n = seconds(0.14)
    f = r(1700, 1900)
    x = sine(np.full(n, f), n) + sine(np.full(n, f * 1.5), n) * 0.5 * expdecay(n, 0.03)
    return finish(x * expdecay(n, 0.05), 0.45)


def coin():
    n1, n2 = seconds(0.06), seconds(0.22)
    a = square(np.full(n1, midi_hz(88)), n1, 0.5) * 0.5
    b = square(np.full(n2, midi_hz(93)), n2, 0.5) * expdecay(n2, 0.07) * 0.5
    return finish(fft_filter(np.concatenate([a, b]), low=6000.0), 0.45)


def chime(notes, step, ring, bright=1.0):
    total = seconds(step * len(notes) + ring)
    x = np.zeros(total, np.float32)
    for k, m in enumerate(notes):
        nn = total - seconds(step * k)
        f = midi_hz(m)
        tone = sine(np.full(nn, f), nn) + sine(np.full(nn, f * 2.0), nn) * 0.3 * bright + sine(np.full(nn, f * 3.0), nn) * 0.12 * bright
        x[seconds(step * k):] += tone * expdecay(nn, ring * 0.45) * 0.4
    return x


def level():
    shimmer_n = seconds(0.9)
    shimmer = fft_filter(noise(shimmer_n), high=6000) * np.linspace(0.0, 1.0, shimmer_n) ** 2 * expdecay(shimmer_n, 0.6) * 0.25
    x = mix(chime([74, 78, 81, 86, 90], 0.06, 0.9), shimmer)
    return finish(x, 0.7, 0.1)


def fanfare():
    notes = [62, 66, 69, 74]
    n = seconds(1.4)
    x = np.zeros(n, np.float32)
    for k, m in enumerate(notes):
        i = seconds(0.07 * k)
        nn = n - i
        tone = (saw(np.full(nn, midi_hz(m)), nn) + saw(np.full(nn, midi_hz(m) * 1.004), nn)) * adsr(nn, 0.02, 0.3, 0.5, 0.5)
        x[i:] += sweep_filter(tone, 900.0, 3500.0, steps=4) * 0.25
    return finish(mix(x, chime([86, 90, 93, 98], 0.05, 1.0) * 0.6), 0.75, 0.2)


def tick():
    n = seconds(0.03)
    return finish(fft_filter(noise(n), center=r(3500, 4500), width=0.3) * expdecay(n, 0.006), 0.4)


def powerup():
    n = seconds(0.6)
    f = np.geomspace(220.0, r(1300, 1500), n)
    sweep = (square(f, n, 0.3) * 0.5 + saw(f * 1.5, n) * 0.3) * adsr(n, 0.01, 0.2, 0.7, 0.2)
    sweep = fft_filter(sweep, low=5000.0)
    sub = sine(env_sweep(n, 120, 50, 0.05), n) * expdecay(n, 0.12)
    return finish(mix(sweep * 0.7, sub, chime([86, 93], 0.08, 0.5) * 0.5), 0.75, 0.1)


def freeze():
    n = seconds(1.0)
    x = np.zeros(n, np.float32)
    for m in (96, 100, 103, 108):
        x += sine(np.full(n, midi_hz(m) * r(0.995, 1.005)), n) * 0.2
    x *= adsr(n, 0.25, 0.3, 0.6, 0.4)
    crack = fft_filter(noise(seconds(0.05)), high=3000) * expdecay(seconds(0.05), 0.01)
    air = fft_filter(noise(n), high=5000) * adsr(n, 0.3, 0.3, 0.3, 0.3) * 0.25
    out = mix(x, air)
    out[: len(crack)] += crack
    return finish(out, 0.7, 0.2)


def alarm():
    n = seconds(1.0)
    f = np.where((np.arange(n) // seconds(0.25)) % 2 == 0, 660.0, 520.0)
    x = softclip(square(f, n, 0.5) + saw(f * 1.01, n) * 0.5, 2.5)
    x = fft_filter(x, center=1200.0, width=0.9) * adsr(n, 0.01, 0.1, 0.9, 0.15)
    return finish(x, 0.6, 0.1)


# --- Big moments ------------------------------------------------------------------

def synergy():
    n = seconds(1.8)
    swoosh = sweep_filter(noise(seconds(0.5)), 400.0, 8000.0, steps=6) * np.linspace(0, 1, seconds(0.5)) ** 2
    hit_ = mix(sine(env_sweep(n, 120, 40, 0.08), n) * expdecay(n, 0.4) * 1.2,
               fft_filter(noise(n), low=3000) * expdecay(n, 0.12) * 0.6)
    chord = np.zeros(n, np.float32)
    for m in (62, 69, 74, 78, 81):
        chord += supersaw_lite(midi_hz(m), n)
    chord = fft_filter(chord, low=4000.0) * adsr(n, 0.02, 0.4, 0.5, 0.8) * 0.2
    x = swoosh * 0.6
    out = np.zeros(len(x) + n, np.float32)
    out[: len(x)] += x
    out[len(x):] += softclip(mix(hit_, chord, chime([86, 93, 98], 0.06, 1.2) * 0.5), 1.4)
    return finish(out, 0.9, 0.3)


def supersaw_lite(f, n):
    return (saw(f * 0.995, n) + saw(f, n) + saw(f * 1.005, n)) / 3.0


def evolve():
    n = seconds(2.6)
    rise_n = seconds(0.8)
    rise = sweep_filter(noise(rise_n), 300.0, 9000.0, steps=8) * np.linspace(0, 1, rise_n) ** 3
    boom_ = big_boom() * 0.8
    choir = np.zeros(n, np.float32)
    for m in (50, 57, 62, 66, 69, 74):
        f = midi_hz(m)
        vib = 1.0 + 0.003 * np.sin(2 * np.pi * 5.0 * np.arange(n) / RATE)
        choir += (tri(f * vib, n) + saw(f * vib * 1.003, n) * 0.4)
    choir = fft_filter(choir, center=900.0, width=1.4) * adsr(n, 0.15, 0.6, 0.6, 1.0) * 0.12
    out = np.zeros(rise_n + n, np.float32)
    out[:rise_n] += rise * 0.5
    out[rise_n:] += mix(pad_to(boom_, n), choir, chime([86, 90, 93, 98, 102], 0.07, 1.6) * 0.6)
    return finish(softclip(out, 1.3), 0.72, 0.4)


def limit_break():
    n = seconds(0.8)
    zap_ = pad_to(zap(), n)
    sub = sine(env_sweep(n, 200, 55, 0.05), n) * expdecay(n, 0.2)
    up = chime([81, 88, 93], 0.04, 0.6) * 0.6
    return finish(mix(zap_ * 0.7, sub, up), 0.8, 0.15)


def card_show():
    n = seconds(0.35)
    w = sweep_filter(noise(n), 500.0, 5000.0, steps=5) * adsr(n, 0.05, 0.1, 0.6, 0.2)
    return finish(w, 0.4)


def card_pick():
    n = seconds(0.25)
    click = fft_filter(noise(seconds(0.01)), center=3000, width=0.4)
    blip = (square(np.geomspace(900.0, 1800.0, n), n, 0.35) * expdecay(n, 0.06))
    out = fft_filter(blip, low=6000.0) * 0.5
    out[: len(click)] += click * 0.6
    return finish(out, 0.55)


def ui_tap():
    n = seconds(0.06)
    return finish(mix(fft_filter(noise(n), center=2500, width=0.4) * expdecay(n, 0.008),
                      sine(np.full(n, 1200.0), n) * expdecay(n, 0.015) * 0.5), 0.45)


def heal():
    n = seconds(0.9)
    x = chime([69, 74, 78, 81], 0.09, 0.8, 0.5)
    swell = fft_filter(noise(n), center=1500, width=1.0) * adsr(n, 0.3, 0.3, 0.2, 0.3) * 0.15
    return finish(mix(x, swell), 0.6, 0.2)


def shield():
    n = seconds(0.6)
    f = r(880, 990)
    x = sine(np.full(n, f), n) + sine(np.full(n, f * 2.4), n) * 0.5 + sine(np.full(n, f * 3.9), n) * 0.25
    return finish(x * expdecay(n, 0.15), 0.55)


def barrier():
    """An energy dome going up: a rising shimmer over a soft bass thump."""
    n = seconds(1.1)
    f = np.geomspace(180.0, 720.0, n)
    hum = (saw(f, n) * 0.4 + saw(f * 1.5, n) * 0.25 + sine(f * 2.0, n) * 0.3)
    hum = fft_filter(hum, low=3500.0) * adsr(n, 0.12, 0.3, 0.6, 0.5)
    thump = sine(env_sweep(n, 140, 55, 0.05), n) * expdecay(n, 0.15)
    return finish(mix(hum * 0.6, thump, chime([81, 88, 93], 0.05, 0.8, 0.6) * 0.35), 0.7, 0.25)


def emp():
    """A short electric pulse: frequent, so brief and soft-edged."""
    n = seconds(0.35)
    f = env_sweep(n, r(900, 1100), 70.0, 0.06)
    pulse = sine(f, n) * expdecay(n, 0.09)
    crackle_ = fft_filter(noise(n), center=3000.0, width=0.8) * expdecay(n, 0.04) * 0.5
    return finish(mix(pulse, crackle_), 0.55, 0.05)


def repair():
    """A tiny two-note chirp, quiet enough to hear every two seconds."""
    a = seconds(0.05)
    b = seconds(0.12)
    x = np.concatenate([sine(np.full(a, midi_hz(84)), a) * 0.6, sine(np.full(b, midi_hz(91)), b) * expdecay(b, 0.04)])
    return finish(x, 0.35, 0.03)


def slam_ready():
    """Charge complete: a rising power-up sweep into a bright, heavy chord."""
    n = seconds(0.9)
    f = np.geomspace(120.0, 900.0, n)
    sweep = (saw(f, n) * 0.5 + square(f * 0.5, n, 0.3) * 0.3) * np.linspace(0.2, 1.0, n) ** 2
    sweep = fft_filter(sweep, low=4000.0)
    m = seconds(1.0)
    chord = np.zeros(m, np.float32)
    for note in (62, 69, 74, 78):
        chord += saw(np.full(m, midi_hz(note)), m) * 0.25
    chord = fft_filter(chord, low=3500.0) * adsr(m, 0.01, 0.3, 0.4, 0.5)
    thump = sine(env_sweep(m, 130, 50, 0.05), m) * expdecay(m, 0.15)
    out = np.concatenate([sweep * 0.5, mix(chord, thump, chime([86, 93], 0.05, 0.7) * 0.5)])
    return finish(out, 0.75, 0.25)


SOUNDS = {
    "shot": (shot, 4), "scatter": (scatter, 3), "rocket": (rocket, 3), "rail": (rail, 2),
    "flame": (flame, 3), "grenade": (grenade, 3), "mine": (mine, 1), "drone": (drone, 3), "zap": (zap, 4),
    "hit": (hit, 5), "boom": (boom, 5), "big_boom": (big_boom, 3), "hurt": (hurt, 3),
    "gem": (gem, 3), "coin": (coin, 2), "level": (level, 1), "fanfare": (fanfare, 1), "tick": (tick, 3),
    "powerup": (powerup, 2), "freeze": (freeze, 1), "alarm": (alarm, 1),
    "synergy": (synergy, 1), "evolve": (evolve, 1), "limit_break": (limit_break, 2),
    "card_show": (card_show, 2), "card_pick": (card_pick, 2), "ui_tap": (ui_tap, 2),
    "heal": (heal, 1), "shield": (shield, 2),
    "barrier": (barrier, 1), "emp": (emp, 3), "repair": (repair, 2), "slam_ready": (slam_ready, 1),
}


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".ogg"):
            os.remove(os.path.join(OUT, f))
    for name, (fn, count) in SOUNDS.items():
        for k in range(count):
            write_ogg(os.path.join(OUT, "%s_%d.ogg" % (name, k)), fn(), quality=4, mono=True)
    print("%d sounds written to %s" % (sum(c for _, c in SOUNDS.values()), os.path.normpath(OUT)))
