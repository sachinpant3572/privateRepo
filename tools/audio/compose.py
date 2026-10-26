"""Composes the World 1 (Iron Dominion) soundtrack.

Run: python3 tools/audio/compose.py
Writes Ogg loops to games/prototype/audio/music/:
  menu.ogg                 90 BPM, atmospheric hero theme
  stage_calm.ogg           128 BPM, 64 bars: pads, bass, light percussion
  stage_combat.ogg         the same 64 bars: drums, drive bass, brass, lead
  boss.ogg                 140 BPM, phrygian, heavy
  victory.ogg, defeat.ogg  short stingers (not looped)

The two stage stems are sample-aligned; the game plays both and fades the
combat stem in and out with the fight's intensity. Every loop is folded
(reverb tails wrap to the start), so it repeats without a seam. Melodies
are picked from chord tones with a fixed seed per section, so each run of
this script produces the same music.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from synth import (RATE, Track, adsr, expdecay, fft_filter, fold_loop, highpass, midi_hz, noise, reverb,  # noqa: E402
                   saw, seconds, sidechain, sine, softclip, square, supersaw, sweep_filter, tri, write_ogg)

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "games", "prototype", "audio", "music")

# Chords as MIDI root + quality. D minor world.
CHORDS = {
    "Dm": [50, 53, 57], "Gm": [55, 58, 62], "Bb": [46, 50, 53], "F": [53, 57, 60],
    "C": [48, 52, 55], "A": [45, 49, 52], "Eb": [51, 55, 58], "Am": [45, 48, 52],
}


# --- Instruments --------------------------------------------------------------

def kick(power=1.0):
    n = seconds(0.55)
    f = 42.0 + 110.0 * np.exp(-np.arange(n) / (0.035 * RATE))
    body = sine(f, n) * expdecay(n, 0.28)
    click = fft_filter(noise(seconds(0.006)), high=2500.0) * 0.5
    body[: len(click)] += click
    return softclip(body * 1.3 * power, 1.6)


def snare():
    n = seconds(0.32)
    tone = sine(np.full(n, 185.0), n) * expdecay(n, 0.07) * 0.7
    nz = fft_filter(noise(n), center=2200.0, width=0.9) * expdecay(n, 0.1) * 1.0
    return softclip(tone + nz, 1.3)


def hat(open_=False):
    n = seconds(0.25 if open_ else 0.06)
    return fft_filter(noise(n), high=7500.0) * expdecay(n, 0.09 if open_ else 0.018) * 0.6


def taiko(pitch=1.0):
    n = seconds(0.9)
    f = (58.0 + 50.0 * np.exp(-np.arange(n) / (0.05 * RATE))) * pitch
    body = sine(f, n) * expdecay(n, 0.42)
    slap = fft_filter(noise(seconds(0.08)), low=900.0) * expdecay(seconds(0.08), 0.02)
    body[: len(slap)] += slap * 0.8
    return softclip(body * 1.2, 1.4)


def crash():
    n = seconds(2.2)
    return fft_filter(noise(n), high=4000.0) * expdecay(n, 0.6) * 0.45


def riser(length):
    n = seconds(length)
    x = noise(n) * np.linspace(0.0, 1.0, n) ** 2
    return sweep_filter(x, 300.0, 9000.0) * 0.5


def impact():
    n = seconds(2.0)
    f = 30.0 + 60.0 * np.exp(-np.arange(n) / (0.12 * RATE))
    boom = sine(f, n) * expdecay(n, 0.7)
    air = fft_filter(noise(n), low=2500.0) * expdecay(n, 0.25) * 0.5
    return softclip((boom + air) * 1.4, 1.5)


def bass(note, dur, bright=900.0):
    n = seconds(dur)
    f = midi_hz(note)
    x = saw(f, n) * 0.6 + square(f * 0.5, n) * 0.35
    x = sweep_filter(x, bright * 2.2, bright * 0.5, steps=5)
    x += sine(f * 0.5, n) * 0.2
    return x * adsr(n, 0.004, 0.08, 0.75, min(0.06, dur * 0.3))


def drive_bass(note, dur):
    n = seconds(dur)
    f = midi_hz(note)
    x = softclip(saw(f, n) + saw(f * 1.006, n), 3.0)
    x = fft_filter(x, low=1400.0, q_db=4.0)
    return x * adsr(n, 0.002, 0.05, 0.5, min(0.04, dur * 0.3)) * 0.6


def pad(notes, dur, cutoff=2200.0):
    n = seconds(dur + 0.8)
    x = np.zeros(n, np.float32)
    for m in notes:
        x += supersaw(midi_hz(m), n, voices=5, detune=0.011)
        x += supersaw(midi_hz(m + 12), n, voices=3, detune=0.008) * 0.35
    x = fft_filter(x / len(notes), low=cutoff)
    return x * adsr(n, 0.35, 0.4, 0.85, 0.8)


def brass(notes, dur):
    n = seconds(dur + 0.3)
    x = np.zeros(n, np.float32)
    for m in notes:
        x += saw(midi_hz(m), n) + saw(midi_hz(m) * 1.004, n) * 0.7
    x = softclip(x / len(notes), 1.6)
    swell = sweep_filter(x, 500.0, 3800.0, steps=6)
    return swell * adsr(n, 0.06, 0.25, 0.6, 0.3)


def lead(note, dur):
    n = seconds(dur + 0.15)
    f = midi_hz(note) * (1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * np.arange(n) / RATE) * np.linspace(0, 1, n))
    x = square(f, n, 0.32) * 0.5 + saw(f * 1.003, n) * 0.5
    x = fft_filter(x, low=3800.0)
    return x * adsr(n, 0.01, 0.15, 0.7, 0.15)


def pluck(note, dur):
    n = seconds(max(dur, 0.25))
    x = tri(midi_hz(note), n) * 0.6 + square(midi_hz(note), n, 0.25) * 0.4
    x = sweep_filter(x, 5000.0, 600.0, steps=5)
    return x * expdecay(n, 0.18)


def bell(note, dur):
    n = seconds(dur + 1.5)
    f = midi_hz(note)
    x = sine(f, n) + sine(f * 2.76, n) * 0.4 * expdecay(n, 0.4) + sine(f * 5.4, n) * 0.2 * expdecay(n, 0.15)
    return x * expdecay(n, 1.2) * 0.5


# --- Melody -------------------------------------------------------------------

MOTIF = [(0, 1.0), (1, 0.5), (1.5, 0.5), (2, 1.0), (3, 1.0), (4, 1.5), (5.5, 0.5), (6, 2.0)]  # beats, length


def melody(chords_per_bar, bars, seed, low=62, high=81):
    """Chord-tone melody on a fixed heroic rhythm, moving mostly by step."""
    r = np.random.default_rng(seed)
    out = []
    prev = 69
    for b in range(0, bars, 2):
        for beat, length in MOTIF:
            bar = b + int(beat // 4)
            if bar >= bars:
                break
            tones = [m + 12 * o for m in chords_per_bar[bar] for o in range(1, 4)]
            tones = [m for m in tones if low <= m <= high]
            # Prefer tones close to the last one; leap on phrase starts.
            weights = np.array([1.0 / (1.0 + abs(m - prev)) ** (1.2 if beat else 0.6) for m in tones])
            prev = int(r.choice(tones, p=weights / weights.sum()))
            out.append((b * 4 + beat, prev, length))
    return out


# --- Arrangements ---------------------------------------------------------------

def stage():
    bpm = 128.0
    beat = 60.0 / bpm
    bar = beat * 4
    bars = 64
    sections = [
        ["Dm", "Dm", "Bb", "Bb", "F", "F", "C", "C"],
        ["Dm", "Dm", "Gm", "Gm", "Bb", "Bb", "A", "A"],
        ["Bb", "Bb", "F", "F", "C", "C", "Dm", "Dm"],
        ["Gm", "Gm", "Bb", "Bb", "Dm", "Dm", "A", "A"],
    ]
    plan = []
    for s in sections:
        plan += s * 2
    chords = [CHORDS[c] for c in plan]
    length = bars * bar
    calm = Track(length)
    combat = Track(length)
    kicks = []
    for b in range(bars):
        t0 = b * bar
        ch = chords[b]
        sec = b // 16
        # Calm: pad on chord changes, bass pulse, taiko, soft hats, arp.
        if b % 2 == 0:
            calm.add(t0, pad(ch, bar * 2, 2400.0 if sec != 2 else 3200.0), 0.26)
        for e in range(8):
            if e % 2 == 0 or sec in (1, 3):
                calm.add(t0 + e * beat / 2, bass(ch[0] - 12, beat / 2 * 0.9), 0.32)
        calm.add(t0, taiko(), 0.32)
        if b % 2 == 1:
            calm.add(t0 + beat * 2.5, taiko(1.3), 0.3, -0.3)
            calm.add(t0 + beat * 3, taiko(1.5), 0.3, 0.3)
        for e in range(8):
            calm.add(t0 + e * beat / 2 + beat / 4, hat(), 0.08, 0.4)
        arp = [ch[0] + 24, ch[1] + 24, ch[2] + 24, ch[1] + 24]
        for e in range(8):
            calm.add(t0 + e * beat / 2, pluck(arp[e % 4], beat / 2), 0.16, -0.5 + (e % 2))
        # Combat: full drums, drive bass, brass stabs, lead in sections 2-3.
        for q in range(4):
            calm_t = t0 + q * beat
            combat.add(calm_t, kick(), 0.5)
            kicks.append(calm_t)
            if q in (1, 3):
                combat.add(calm_t, snare(), 0.5)
        for s16 in range(16):
            combat.add(t0 + s16 * beat / 4, hat(s16 % 4 == 2), (0.05 if s16 % 4 == 2 else 0.09) if s16 % 2 == 0 else 0.05, 0.35)
        for s16 in range(16):
            combat.add(t0 + s16 * beat / 4, drive_bass(ch[0] - (12 if s16 % 4 else 0), beat / 4 * 0.8), 0.2)
        if b % 2 == 0:
            for hit in (0.0, 1.5, 3.0):
                combat.add(t0 + hit * beat, brass([m + 12 for m in ch], beat * 0.6), 0.34)
        if b % 16 == 15:
            combat.add(t0, riser(bar), 0.35)
            for r16 in range(8):
                combat.add(t0 + beat * 2 + r16 * beat / 4, snare(), 0.15 + 0.05 * r16)
        if b % 16 == 0:
            combat.add(t0, crash(), 0.5)
            combat.add(t0, impact(), 0.45)
    for sec in (2, 3):
        for when, note, length_beats in melody(chords[sec * 16:sec * 16 + 16], 16, seed=11 + sec):
            combat.add(sec * 16 * bar + when * beat, lead(note, length_beats * beat * 0.95), 0.26, 0.1)
    # Calm theme hint in section 1 on a bell, so the calm stem alone isn't static.
    for when, note, length_beats in melody(chords[16:32], 16, seed=5, low=69, high=86):
        calm.add(16 * bar + when * beat, bell(note, length_beats * beat), 0.2, -0.2)
    combat.buf = sidechain(combat.buf, kicks, length, depth=0.35)
    n = calm.n
    calm_buf = fold_loop(highpass(reverb(calm.buf, 2.4, 0.28)), n)
    combat_buf = fold_loop(highpass(reverb(combat.buf, 1.4, 0.14)), n)
    g = 0.9 / (np.max(np.abs(calm_buf + combat_buf)) + 1e-9)
    write_ogg(os.path.join(OUT, "stage_calm.ogg"), softclip(calm_buf * g, 1.1))
    write_ogg(os.path.join(OUT, "stage_combat.ogg"), softclip(combat_buf * g, 1.1))
    return length


def boss():
    bpm = 140.0
    beat = 60.0 / bpm
    bar = beat * 4
    bars = 32
    prog = ["Dm", "Eb", "Dm", "C"] * 4 + ["Gm", "Eb", "Dm", "A"] * 4
    length = bars * bar
    tr = Track(length)
    kicks = []
    for b in range(bars):
        t0 = b * bar
        ch = CHORDS[prog[b]]
        for q in range(4):
            tr.add(t0 + q * beat, kick(1.1), 0.55)
            kicks.append(t0 + q * beat)
        tr.add(t0 + beat, snare(), 0.55)
        tr.add(t0 + beat * 3, snare(), 0.55)
        tr.add(t0 + beat * 3.5, snare(), 0.25)
        for q in range(4):
            tr.add(t0 + q * beat + beat / 2, taiko(1.0 + 0.2 * (q % 2)), 0.45, -0.4 + 0.8 * (q % 2))
        for s16 in range(16):
            tr.add(t0 + s16 * beat / 4, hat(), 0.07 if s16 % 2 == 0 else 0.04, 0.3)
            tr.add(t0 + s16 * beat / 4, drive_bass(ch[0] - 12 + (12 if s16 in (6, 14) else 0), beat / 4 * 0.85), 0.26)
        tr.add(t0, brass([m + 12 for m in ch], beat * 1.2), 0.36)
        tr.add(t0 + beat * 2.5, brass([m + 12 for m in ch], beat * 0.5), 0.3)
        if b % 2 == 0:
            tr.add(t0, pad([m + 12 for m in ch], bar * 2, 2200.0), 0.18)
        if b % 8 == 0:
            tr.add(t0, crash(), 0.5)
            tr.add(t0, impact(), 0.5)
        if b % 8 == 7:
            tr.add(t0, riser(bar), 0.3)
    # Alarm-like lead: semitone wails over the second half.
    for b in range(16, 32, 2):
        t0 = b * bar
        tr.add(t0, lead(74, beat * 2), 0.22)
        tr.add(t0 + beat * 2, lead(75, beat * 2), 0.22)
        tr.add(t0 + beat * 4, lead(74, beat * 1.5), 0.22)
        tr.add(t0 + beat * 5.5, lead(72, beat * 2.5), 0.22)
    tr.buf = sidechain(tr.buf, kicks, length, depth=0.3)
    buf = fold_loop(highpass(reverb(tr.buf, 1.6, 0.16)), tr.n)
    write_ogg(os.path.join(OUT, "boss.ogg"), softclip(buf / (np.max(np.abs(buf)) + 1e-9) * 0.95, 1.3) * 0.9)


def menu():
    bpm = 90.0
    beat = 60.0 / bpm
    bar = beat * 4
    bars = 24
    prog = ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"] * 3
    length = bars * bar
    tr = Track(length, tail_s=5.0)
    for b in range(bars):
        t0 = b * bar
        ch = CHORDS[prog[b]]
        tr.add(t0, pad(ch, bar, 1500.0 + 400.0 * (b // 8)), 0.2)
        tr.add(t0, bass(ch[0] - 12, bar * 0.95, 700.0), 0.2)
        if b >= 8:
            tr.add(t0, taiko(0.9), 0.35)
            tr.add(t0 + beat * 2.5, taiko(1.2), 0.2)
        if b >= 16:
            for e in range(8):
                tr.add(t0 + e * beat / 2, pluck(ch[e % 3] + 24, beat / 2), 0.07, -0.4 + 0.8 * (e % 2))
    chords = [CHORDS[c] for c in prog]
    for when, note, length_beats in melody(chords[8:24], 16, seed=3, low=62, high=79):
        tr.add(8 * bar + when * beat, brass([note], length_beats * beat * 0.95), 0.24)
    for when, note, length_beats in melody(chords[0:8], 8, seed=9, low=69, high=88):
        tr.add(when * beat, bell(note, length_beats * beat), 0.1, 0.25)
    buf = fold_loop(highpass(reverb(tr.buf, 3.2, 0.38)), tr.n)
    write_ogg(os.path.join(OUT, "menu.ogg"), softclip(buf / (np.max(np.abs(buf)) + 1e-9) * 0.9, 1.1) * 0.85)


def stinger(victory):
    tr = Track(6.0, tail_s=0.0)
    if victory:
        steps = [([50, 57, 62], 0.0), ([53, 57, 62, 65], 0.35), ([55, 59, 62, 67], 0.7), ([57, 62, 66, 69, 74], 1.1)]
        for notes, t in steps:
            tr.add(t, brass([m + 12 for m in notes], 0.32 if t < 1.0 else 2.6), 0.3)
        for k in range(10):
            tr.add(0.6 + k * 0.05, taiko(1.4), 0.12)
        tr.add(1.1, crash(), 0.6)
        tr.add(1.1, impact(), 0.5)
        tr.add(1.1, pad([62, 66, 69], 3.0, 3000.0), 0.2)
    else:
        for k, (notes, t) in enumerate([([62, 65, 69], 0.0), ([60, 63, 67], 0.6), ([58, 62, 65], 1.2), ([57, 61, 64], 1.9)]):
            tr.add(t, brass([m for m in notes], 0.55 if k < 3 else 3.0), 0.26)
        tr.add(1.9, impact(), 0.7)
        tr.add(1.9, pad([50, 53, 57], 3.5, 900.0), 0.25)
    buf = reverb(tr.buf, 2.5, 0.3)
    n = len(buf)
    fade = np.ones(n, np.float32)
    fade[-seconds(0.8):] = np.linspace(1.0, 0.0, seconds(0.8))
    buf = buf * fade[:, None]
    write_ogg(os.path.join(OUT, "victory.ogg" if victory else "defeat.ogg"), buf / (np.max(np.abs(buf)) + 1e-9) * 0.85)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    which = sys.argv[1:] or ["stage", "boss", "menu", "stingers"]
    if "stage" in which:
        stage()
    if "boss" in which:
        boss()
    if "menu" in which:
        menu()
    if "stingers" in which:
        stinger(True)
        stinger(False)
    print("music written to", os.path.normpath(OUT))
