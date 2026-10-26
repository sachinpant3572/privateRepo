"""Small offline synthesizer for the game's music and sound effects.

Everything is rendered with numpy into float32 stereo buffers at RATE and
written as WAV, then encoded to Ogg Vorbis with ffmpeg (see compose.py and
sfx.py). Filters are done in the frequency domain on short note buffers,
which keeps the code vectorized and fast without scipy.
"""

import subprocess
import wave

import numpy as np

RATE = 44100
rng = np.random.default_rng(7)


def seconds(n):
    return int(round(n * RATE))


def midi_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


# --- Oscillators -------------------------------------------------------------

def phase(freq, n):
    """Phase in cycles for a constant or per-sample frequency."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    return np.cumsum(f) / RATE


def saw(freq, n, ph0=0.0):
    p = phase(freq, n) + ph0
    return (2.0 * (p % 1.0) - 1.0).astype(np.float32)


def square(freq, n, duty=0.5):
    p = phase(freq, n) % 1.0
    return np.where(p < duty, 1.0, -1.0).astype(np.float32)


def sine(freq, n):
    return np.sin(2.0 * np.pi * phase(freq, n)).astype(np.float32)


def tri(freq, n):
    p = phase(freq, n) % 1.0
    return (4.0 * np.abs(p - 0.5) - 1.0).astype(np.float32)


def noise(n):
    return rng.uniform(-1.0, 1.0, n).astype(np.float32)


def supersaw(freq, n, voices=5, detune=0.012):
    out = np.zeros(n, np.float32)
    for v in range(voices):
        d = 1.0 + detune * (v - (voices - 1) / 2.0) / ((voices - 1) / 2.0 or 1.0)
        out += saw(freq * d, n, rng.random())
    return out / voices


# --- Envelopes and filters ---------------------------------------------------

def adsr(n, a=0.005, d=0.1, s=0.7, r=0.1):
    env = np.ones(n, np.float32) * s
    na, nd, nr = seconds(a), seconds(d), seconds(r)
    na = min(na, n)
    env[:na] = np.linspace(0.0, 1.0, na, endpoint=False)
    nd = min(nd, n - na)
    env[na:na + nd] = np.linspace(1.0, s, nd, endpoint=False)
    nr = min(nr, n)
    if nr > 0:
        env[n - nr:] *= np.linspace(1.0, 0.0, nr)
    return env


def expdecay(n, t):
    return np.exp(-np.arange(n) / (t * RATE)).astype(np.float32)


def fft_filter(x, low=None, high=None, q_db=0.0, center=None, width=None):
    """Zero-phase filter in the frequency domain.

    low: lowpass cutoff in Hz, high: highpass cutoff, center/width: bandpass.
    Slopes are smooth (about 12 dB/octave) so notes don't ring.
    """
    n = len(x)
    size = 1 << int(np.ceil(np.log2(max(n, 2))))
    spec = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1.0 / RATE)
    gain = np.ones_like(f)
    if low is not None:
        gain *= 1.0 / (1.0 + (f / low) ** 4)
        if q_db:
            gain *= 1.0 + (10 ** (q_db / 20.0) - 1.0) * np.exp(-((np.log2((f + 1.0) / low)) ** 2) * 8.0)
    if high is not None:
        gain *= 1.0 / (1.0 + (high / np.maximum(f, 1.0)) ** 4)
    if center is not None:
        gain *= np.exp(-((np.log2((f + 1.0) / center)) ** 2) / (2.0 * (width or 0.5) ** 2))
    return np.fft.irfft(spec * gain, size)[:n].astype(np.float32)


def sweep_filter(x, start, end, steps=8):
    """Lowpass whose cutoff moves from start to end, by crossfading a few
    statically filtered copies (cheap, and smooth enough for music)."""
    n = len(x)
    out = np.zeros(n, np.float32)
    cuts = np.geomspace(start, end, steps)
    seg = np.linspace(0.0, steps - 1, n)
    for k, c in enumerate(cuts):
        w = np.clip(1.0 - np.abs(seg - k), 0.0, 1.0).astype(np.float32)
        if w.any():
            out += fft_filter(x, low=c) * w
    return out


def softclip(x, drive=1.0):
    return (np.tanh(x * drive) / np.tanh(drive)).astype(np.float32)


# --- Mixing ------------------------------------------------------------------

class Track:
    """A stereo buffer you can add notes into at a time position."""

    def __init__(self, length_s, tail_s=3.0):
        self.n = seconds(length_s)
        self.buf = np.zeros((self.n + seconds(tail_s), 2), np.float32)

    def add(self, t, mono, gain=1.0, pan=0.0):
        i = seconds(t)
        if i >= len(self.buf):
            return
        mono = mono[: len(self.buf) - i] * gain
        left = np.cos((pan + 1.0) * np.pi / 4.0)
        right = np.sin((pan + 1.0) * np.pi / 4.0)
        self.buf[i:i + len(mono), 0] += mono * left * 1.414
        self.buf[i:i + len(mono), 1] += mono * right * 1.414

    def add_stereo(self, t, st, gain=1.0):
        i = seconds(t)
        st = st[: len(self.buf) - i] * gain
        self.buf[i:i + len(st)] += st


def reverb(st, decay=1.8, mix=0.25, predelay=0.02, bright=4500.0):
    """Convolution with a synthetic, decorrelated stereo tail."""
    n_ir = seconds(decay * 1.5)
    t = np.arange(n_ir) / RATE
    env = np.exp(-t * 6.9 / decay)
    out = np.empty_like(st)
    size = 1 << int(np.ceil(np.log2(len(st) + n_ir)))
    for ch in range(2):
        ir = (rng.standard_normal(n_ir) * env).astype(np.float32)
        ir = fft_filter(ir, low=bright, high=200.0)
        ir = np.concatenate([np.zeros(seconds(predelay), np.float32), ir])
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        wet = np.fft.irfft(np.fft.rfft(st[:, ch], size) * np.fft.rfft(ir, size), size)[: len(st)]
        out[:, ch] = st[:, ch] + wet.astype(np.float32) * mix
    return out


def sidechain(st, hits, length_s, depth=0.55, release=0.22):
    """Duck a buffer on each kick (the classic pumping feel)."""
    n = len(st)
    env = np.ones(n, np.float32)
    shape = 1.0 - depth * np.exp(-np.arange(seconds(release * 2)) / (release * RATE * 0.5))
    for h in hits:
        i = seconds(h)
        if i < n:
            seg = shape[: n - i]
            env[i:i + len(seg)] = np.minimum(env[i:i + len(seg)], seg)
    return st * env[:, None]


def highpass(st, cut=38.0):
    """Remove rumble below what any speaker plays, so headroom goes to
    the parts phones can actually reproduce."""
    out = np.empty_like(st)
    for ch in range(st.shape[1]):
        out[:, ch] = fft_filter(st[:, ch], high=cut)
    return out


def fold_loop(buf, n):
    """Make a seamless loop of n samples: the tail that rings past the loop
    point (reverb, releases) is added back onto the start."""
    out = buf[:n].copy()
    tail = buf[n:]
    k = min(len(tail), n)
    out[:k] += tail[:k]
    return out


def master(st, peak=0.89, drive=1.4):
    st = softclip(st / (np.max(np.abs(st)) + 1e-9) * 1.2, drive)
    return st / (np.max(np.abs(st)) + 1e-9) * peak


def write_wav(path, st):
    data = (np.clip(st, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1 if data.ndim == 1 else 2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def write_ogg(path, st, quality=5, mono=False):
    tmp = path + ".tmp.wav"
    write_wav(tmp, st)
    cmd = ["ffmpeg", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality)]
    if mono and np.ndim(st) == 2:
        cmd += ["-ac", "1"]
    subprocess.run(cmd + [path], check=True)
    subprocess.run(["rm", "-f", tmp], check=True)
