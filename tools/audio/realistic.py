"""Builds the realistic combat sounds from recorded clips.

Usage: python3 tools/audio/realistic.py <clips dir>

The clips are short videos with native audio, generated with Higgsfield
(Seedance 2.0 Mini, about 2 credits each); docs/audio.md lists the prompts.
Each is cut into single events (tools/audio/slice.py), and every event is
matched in loudness to the synthesized sound it replaces, so the game's mix
stays balanced. Interface and pickup sounds stay synthesized (sfx.py).

Run sfx.py first, then this: it overwrites only the IDs listed below.
"""

import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from slice import cut, load, onsets  # noqa: E402
from synth import RATE, write_ogg  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "games", "prototype", "audio", "sfx")

# id: [(clip, how many, longest cut in s, smallest gap between onsets in s), ...]
PLAN = {
    "shot": [("rifle", 6, 0.3, 0.08)],
    "scatter": [("shotgun", 4, 0.7, 0.5)],
    "rocket": [("rocket", 4, 0.7, 0.4)],
    "rail": [("railgun", 3, 1.3, 0.8)],
    "flame": [("flame", 3, 0.8, 0.5)],
    "grenade": [("grenade", 4, 0.45, 0.35)],
    "zap": [("tesla", 5, 0.32, 0.15)],
    "drone": [("drone", 4, 0.2, 0.1)],
    "hit": [("armor", 6, 0.16, 0.1)],
    "boom": [("explosions", 5, 1.0, 0.6), ("cannon", 2, 1.2, 1.2)],
    "big_boom": [("depot", 1, 2.6, 2.0), ("cannon", 2, 1.8, 1.2)],
    "jet": [("jet", 2, 2.6, 1.5)],
    "gunship": [("gunship", 4, 0.6, 0.4)],
    "siege": [("siege", 3, 1.5, 1.0)],
    "crunch": [("robots", 6, 0.5, 0.4)],
    "shatter": [("shatter", 3, 0.9, 0.8)],
    "debris": [("debris", 5, 0.6, 0.35)],
    "dash_launch": [("dash", 3, 0.8, 0.9)],
    "dash_hit": [("slice", 4, 0.5, 0.5)],
}
# Loudness (RMS, dB) for sounds with no synthesized original to match.
TARGETS = {"jet": -16.0, "gunship": -17.0, "siege": -15.0, "slam_impact": -12.0, "slam_launch": -16.0,
           "crunch": -20.0, "shatter": -18.0, "debris": -18.0, "dash_launch": -13.0, "dash_hit": -15.0,
           "crash": -14.0, "crash_start": -18.0}
# Sounds taken as one stretch of the clip rather than by onsets: start, length.
STRETCH = {"alarm": ("siren", 0.8, 1.6), "freeze": ("frost", None, 1.2),
           "slam_impact": ("slam2", None, 3.0), "slam_launch": ("slam1", None, 1.1),
           "crash": ("crash", 3.72, 1.3), "crash_start": ("crash", 0.18, 0.9)}


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)) + 1e-12))


def reference_rms(sound):
    if sound in TARGETS:
        return 10.0 ** (TARGETS[sound] / 20.0)
    path = os.path.join(OUT, "%s_0.ogg" % sound)
    if not os.path.exists(path):
        return 0.1
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"],
                         capture_output=True, check=True).stdout
    return rms(np.frombuffer(raw, np.float32))


def phone_eq(seg):
    """Shapes a recording for phone speakers: they can't play below about
    100 Hz, and trying to only makes them distort. So the deep sub-bass is
    cut, and the 150-500 Hz "punch" a phone can play is lifted instead."""
    n = len(seg)
    size = 1 << int(np.ceil(np.log2(max(n, 2))))
    spec = np.fft.rfft(seg, size)
    f = np.fft.rfftfreq(size, 1.0 / RATE)
    gain = 1.0 / (1.0 + (110.0 / np.maximum(f, 1.0)) ** 4)
    gain *= 1.0 + 0.6 * np.exp(-((np.log2((f + 1.0) / 280.0)) ** 2) / 0.5)
    return np.fft.irfft(spec * gain, size)[:n].astype(np.float32)


def match(seg, target):
    """Scales a recording to the loudness of the sound it replaces, without
    ever clipping or saturating it (a clean sound may end up quieter)."""
    seg = phone_eq(seg)
    seg = seg * (target / (rms(seg) + 1e-9))
    peak = np.max(np.abs(seg))
    if peak > 0.9:
        seg = seg / peak * 0.9
    return seg.astype(np.float32)


def events(clip, count, max_len, min_gap):
    x = load(clip)
    found, db, hop = onsets(x, min_gap)
    pre = int(0.008 * RATE)
    out = []
    for k, i in enumerate(found):
        start = max(0, i * hop - pre)
        nxt = found[k + 1] * hop - pre if k + 1 < len(found) else len(x)
        end = min(nxt, start + int(max_len * RATE), len(x))
        if end - start > int(0.05 * RATE):
            out.append((db[i], cut(x, start, end)))
    out.sort(key=lambda e: -e[0])
    return [seg for _, seg in out[:count]]


def main():
    clips = sys.argv[1]
    for sound, sources in PLAN.items():
        target = reference_rms(sound)
        made = []
        for clip, count, max_len, min_gap in sources:
            path = os.path.join(clips, clip + ".mp4")
            if os.path.exists(path):
                made += events(path, count, max_len, min_gap)
        if not made:
            continue
        for f in os.listdir(OUT):
            if f.startswith(sound + "_") and f[len(sound) + 1:-4].isdigit():
                os.remove(os.path.join(OUT, f))
        for n, seg in enumerate(made[:8]):
            write_ogg(os.path.join(OUT, "%s_%d.ogg" % (sound, n)), match(seg, target), quality=5, mono=True)
        print("%-9s %d variations" % (sound, min(len(made), 8)))
    for sound, (clip, start, length) in STRETCH.items():
        path = os.path.join(clips, clip + ".mp4")
        if not os.path.exists(path):
            continue
        target = reference_rms(sound)
        x = load(path)
        if start is None:
            found, _, hop = onsets(x, 0.5)
            start = found[0] * hop / RATE if found else 0.0
        a = int(start * RATE)
        seg = cut(x, a, min(len(x), a + int(length * RATE)))
        for f in os.listdir(OUT):
            if f.startswith(sound + "_"):
                os.remove(os.path.join(OUT, f))
        write_ogg(os.path.join(OUT, "%s_0.ogg" % sound), match(seg, target), quality=5, mono=True)
        print("%-9s 1 variation" % sound)


if __name__ == "__main__":
    main()
