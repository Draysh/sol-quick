#!/usr/bin/env python3
"""Each world's own small sound, for its main good moment, made from sines and noise.

Saturn's soft ring, Neptune's water drop, Mercury's bell, Terra's wood tick,
Luna's chime, Titan's whoosh and Triton's static blip: under a second each,
quiet, mono, 22.05 kHz, 16-bit, a few tens of KB. Nothing is recorded or
downloaded; run it again and the same files come out (the noise is seeded).

    scripts/world-sounds.py assets/sounds      # writes <world>.wav for each

`Sounds.voice()` plays the window's world's own. Needs Python 3 with numpy.
"""

import sys
import wave
from pathlib import Path

import numpy as np

RATE = 22_050
rng = np.random.default_rng(2026)


def t_of(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def fade(signal, attack=0.004, release=0.03):
    """No clicks at either end."""
    n = len(signal)
    a, r = int(RATE * attack), int(RATE * release)
    env = np.ones(n)
    if a:
        env[:a] = np.linspace(0, 1, a)
    if r:
        env[-r:] *= np.linspace(1, 0, r)
    return signal * env


def bandpass(signal, lo, hi):
    spectrum = np.fft.rfft(signal)
    f = np.fft.rfftfreq(len(signal), 1 / RATE)
    f = np.maximum(f, 1.0)
    shape = 1 / (1 + (lo / f) ** 4) / (1 + (f / hi) ** 4)
    return np.fft.irfft(spectrum * shape, len(signal))


def bell(base, partials, decay, seconds):
    """Struck metal: partials that die away, the high ones sooner."""
    t = t_of(seconds)
    out = np.zeros_like(t)
    for ratio, gain in partials:
        out += gain * np.sin(2 * np.pi * base * ratio * t) * np.exp(-t * ratio / decay)
    return out


def saturn():
    # A soft ring: a low glassy bell with a slow shimmer, like the rings themselves.
    t = t_of(1.1)
    ring = bell(660, [(1, 1.0), (2.0, 0.25), (2.76, 0.18), (5.4, 0.05)], 0.55, 1.1)
    return ring * (1 + 0.08 * np.sin(2 * np.pi * 5.5 * t))


def neptune():
    # A water drop: a sine that leaps up in pitch as it fades, and a smaller one after.
    def drop(f0, f1, seconds, at):
        t = t_of(seconds)
        sweep = f0 * (f1 / f0) ** (t / seconds)
        phase = 2 * np.pi * np.cumsum(sweep) / RATE
        out = np.zeros(int(RATE * 0.5))
        s = np.sin(phase) * np.exp(-t / (seconds / 3))
        out[at : at + len(s)] += s
        return out

    return drop(520, 1500, 0.09, 0) + 0.35 * drop(700, 1700, 0.06, int(RATE * 0.11))


def mercury():
    # A small bell, a rin's bright partials, ringing out.
    return bell(1320, [(1, 1.0), (2.71, 0.32), (5.16, 0.12), (8.4, 0.04)], 0.5, 1.3)


def terra():
    # A wood tick: a short knock with two hollow resonances.
    t = t_of(0.16)
    knock = rng.normal(0, 1, len(t)) * np.exp(-t / 0.004)
    body = np.sin(2 * np.pi * 820 * t) * np.exp(-t / 0.035) + 0.5 * np.sin(2 * np.pi * 1730 * t) * np.exp(-t / 0.02)
    return bandpass(knock, 400, 3000) * 0.4 + body


def luna():
    # A chime: two soft notes a fifth apart, the second a breath later.
    t = t_of(1.4)
    first = np.sin(2 * np.pi * 1318.5 * t) * np.exp(-t / 0.45)
    second = np.zeros_like(t)
    d = int(RATE * 0.12)
    second[d:] = np.sin(2 * np.pi * 1975.5 * t[: len(t) - d]) * np.exp(-t[: len(t) - d] / 0.4)
    swell = 1 - np.exp(-t / 0.01)
    return (first + 0.6 * second) * swell


def titan():
    # A whoosh: breath of noise whose colour sweeps up and back as it passes.
    seconds = 0.7
    t = t_of(seconds)
    noise = rng.normal(0, 1, len(t))
    out = np.zeros_like(t)
    # Sum of a few bands, each loudest at its own moment, so the colour moves.
    for i, centre in enumerate(np.geomspace(500, 3200, 6)):
        peak = 0.25 + 0.35 * i / 5
        env = np.exp(-(((t / seconds) - peak) / 0.18) ** 2)
        out += bandpass(noise, centre / 1.5, centre * 1.5) * env
    return out


def triton():
    # A static blip: a crackle of radio noise, then a short tone, as a station is found.
    t = t_of(0.28)
    static = bandpass(rng.normal(0, 1, len(t)), 900, 5000) * np.exp(-t / 0.03)
    static *= (rng.uniform(0, 1, len(t)) > 0.35)
    tone = np.zeros_like(t)
    at = int(RATE * 0.07)
    tt = t[: len(t) - at]
    tone[at:] = np.sin(2 * np.pi * 1180 * tt) * np.exp(-tt / 0.05) * (1 - np.exp(-tt / 0.003))
    return static * 0.5 + tone * 0.8


SOUNDS = {
    "saturn": (saturn, 0.22),
    "neptune": (neptune, 0.24),
    "mercury": (mercury, 0.2),
    "terra": (terra, 0.3),
    "luna": (luna, 0.2),
    "titan": (titan, 0.2),
    "triton": (triton, 0.22),
}


def write(path, signal, peak):
    signal = fade(signal)
    signal = signal / np.max(np.abs(signal)) * peak
    pcm = np.clip(signal * 32767, -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, (make, peak) in SOUNDS.items():
        write(out / f"{name}.wav", make(), peak)
        print(out / f"{name}.wav")


if __name__ == "__main__":
    main()
