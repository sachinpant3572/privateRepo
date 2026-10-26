"""Cuts individual sound effects out of a longer recording.

Usage: python3 tools/audio/slice.py <input audio/video> <out prefix> <count> [max_len_s] [min_gap_s]

Finds the strongest onsets (sudden jumps in loudness), cuts each from just
before its onset until it has decayed or the next one starts, then trims,
fades, high-passes and normalizes it. Writes <prefix>_<n>.ogg, loudest first.
Used for effects extracted from AI-generated video audio (see docs/audio.md).
"""

import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from synth import RATE, fft_filter, write_ogg  # noqa: E402


def load(path):
    raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-vn", "-ac", "1", "-ar", str(RATE), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).copy()


def onsets(x, min_gap):
    hop = 220
    frames = len(x) // hop
    env = np.sqrt(np.mean(x[: frames * hop].reshape(frames, hop) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(env)
    rise = np.diff(db, prepend=db[0])
    # Rise over the last ~30 ms against the floor before it.
    score = np.array([db[i] - np.min(db[max(0, i - 6):i + 1]) for i in range(frames)])
    cand = [i for i in range(frames) if score[i] > 12.0 and rise[i] > 3.0 and db[i] > -40.0]
    picked = []
    gap = int(min_gap * RATE / hop)
    for i in sorted(cand, key=lambda k: -db[k]):
        if all(abs(i - j) >= gap for j in picked):
            picked.append(i)
    return sorted(picked), db, hop


def cut(x, start, end):
    seg = x[start:end].copy()
    # Trim the tail once it has decayed 40 dB below the peak.
    hop = 220
    n = len(seg) // hop
    if n > 2:
        env = 20 * np.log10(np.sqrt(np.mean(seg[: n * hop].reshape(n, hop) ** 2, axis=1)) + 1e-9)
        last = np.where(env > env.max() - 40.0)[0]
        if len(last):
            seg = seg[: min(len(seg), (last[-1] + 2) * hop)]
    seg = fft_filter(seg, high=40.0)
    fade_in = min(len(seg), int(0.003 * RATE))
    seg[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    fade_out = min(len(seg), int(0.04 * RATE))
    seg[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    return seg / (np.max(np.abs(seg)) + 1e-9) * 0.85


def main():
    src, prefix, count = sys.argv[1], sys.argv[2], int(sys.argv[3])
    max_len = float(sys.argv[4]) if len(sys.argv) > 4 else 1.5
    min_gap = float(sys.argv[5]) if len(sys.argv) > 5 else 0.15
    x = load(src)
    found, db, hop = onsets(x, min_gap)
    pre = int(0.008 * RATE)
    events = []
    for k, i in enumerate(found):
        start = max(0, i * hop - pre)
        nxt = found[k + 1] * hop - pre if k + 1 < len(found) else len(x)
        end = min(nxt, start + int(max_len * RATE), len(x))
        if end - start > int(0.05 * RATE):
            events.append((db[i], start, end))
    events.sort(key=lambda e: -e[0])
    for n, (_, start, end) in enumerate(events[:count]):
        write_ogg("%s_%d.ogg" % (prefix, n), cut(x, start, end), quality=5, mono=True)
        print("%s_%d.ogg  %.2fs at %.2fs" % (os.path.basename(prefix), n, (end - start) / RATE, start / RATE))


if __name__ == "__main__":
    main()
