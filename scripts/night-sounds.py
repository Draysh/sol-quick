#!/usr/bin/env python3
"""Night sounds, made from noise and sines: rain, a fire and space.

Each is a seamless loop of eight seconds (shaped in the frequency domain, so
its end meets its start), quiet, mono, 22.05 kHz, 16-bit: about 350 KB.
Nothing is recorded or downloaded; run it again and the same files come out
(the noise is seeded).

    scripts/night-sounds.py <folder>      # Luna's: worlds/luna/sounds

Needs Python 3 with numpy.
"""

import sys
import wave
from pathlib import Path

import numpy as np

RATE = 22_050
SECONDS = 8
N = RATE * SECONDS
rng = np.random.default_rng(1969)
freqs = np.fft.rfftfreq(N, 1 / RATE)


def shaped(shape):
    """Noise with the given magnitude per frequency, as a loop."""
    phase = rng.uniform(0, 2 * np.pi, len(freqs))
    return np.fft.irfft(shape * np.exp(1j * phase), N)


def circular(signal, kernel):
    """`signal` through `kernel`, wrapping round, so the loop stays whole."""
    return np.fft.irfft(np.fft.rfft(signal) * np.fft.rfft(kernel, N), N)


def band(lo, hi, slope=1.0):
    """A soft band: rising from `lo`, falling after `hi`."""
    f = np.maximum(freqs, 1.0)
    return 1 / (1 + (lo / f) ** (2 * slope)) / (1 + (f / hi) ** (2 * slope))


def slow(cycles, depth):
    """A swell that goes round a whole number of times a loop."""
    t = np.arange(N) / N
    return 1 + depth * np.sin(2 * np.pi * cycles * t + rng.uniform(0, 2 * np.pi))


def rain():
    # The hiss of rain everywhere, and drops close by: short ticks of noise.
    hiss = shaped(band(500, 5000, 1.2) / np.sqrt(np.maximum(freqs, 1) / 500)) * slow(2, 0.12)
    drops = np.zeros(N)
    for at in rng.integers(0, N, 2600):
        drops[at] += rng.uniform(0.1, 1.0) ** 2
    tick = rng.normal(0, 1, 200) * np.exp(-np.arange(200) / 18)
    drops = circular(drops, tick)
    drops = np.fft.irfft(np.fft.rfft(drops) * band(1500, 6500), N)
    return hiss / np.std(hiss) + drops / np.std(drops) * 0.35


def fire():
    # A low roar that breathes, and crackles: sharp pops, a few close together.
    roar = shaped(band(40, 420, 1.5)) * slow(3, 0.25) * slow(7, 0.12)
    pops = np.zeros(N)
    at = rng.integers(0, N, 180)
    for a in at:
        for k in range(rng.integers(1, 4)):
            pops[(a + k * rng.integers(300, 1400)) % N] += rng.uniform(0.2, 1.0) ** 1.5
    snap = rng.normal(0, 1, 120) * np.exp(-np.arange(120) / 9)
    pops = circular(pops, snap)
    pops = np.fft.irfft(np.fft.rfft(pops) * band(900, 6000), N)
    return roar / np.std(roar) + pops / np.std(pops) * 0.5


def space():
    # A deep, slow drone: low sines a loop apart in pitch (so they meet
    # their start), beating gently, over a faint dark wind.
    t = np.arange(N) / RATE
    drone = np.zeros(N)
    for cycles, level in [(440, 1.0), (443, 0.8), (660, 0.45), (881, 0.25), (1320, 0.12)]:
        f = cycles / SECONDS
        drone += level * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi))
    drone *= slow(1, 0.3)
    wind = shaped(band(60, 700, 1.3)) * slow(2, 0.4)
    return drone / np.std(drone) + wind / np.std(wind) * 0.4


def write(path, signal, loudness):
    # Quiet: the RMS at `loudness` of full scale, peaks kept under it.
    signal = signal - signal.mean()
    signal *= loudness / np.sqrt(np.mean(signal**2))
    peak = np.max(np.abs(signal))
    if peak > 0.9:
        signal *= 0.9 / peak
    data = (signal * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, make, loudness in [("rain", rain, 0.11), ("fire", fire, 0.12), ("space", space, 0.1)]:
        write(out / f"{name}.wav", make(), loudness)
        print(out / f"{name}.wav")


if __name__ == "__main__":
    main()
