#!/usr/bin/env python3
"""Each world's own small sounds, made from sines and noise.

- Its voice, for its main good moment: Saturn's soft ring, Neptune's water
  drop, Mercury's bell, Terra's wood tick, Luna's chime, Titan's whoosh and
  Triton's static blip (`<world>.wav`, `Sounds.voice()`).
- Each flavour's stings, hits only (`<flavour>-turn.wav`, `-opening.wav`,
  `-moment.wav`; a moon without a flavour of its own takes its planet's),
  and Neptune's `-lit.wav`, a neon tube catching (`Sounds.lit()`):
  Neptune's a glitch and a synth stab, Saturn's a film's thump and a low
  boom with the rings' bell, Mercury's a brush, a taiko and a rin, Terra's
  a sweep of air, a furin and a sunrise of glass bells, Luna's the same
  softer, under the moon.
- The kit's own, every world's: `open.wav` and `close.wav` (the palette, a
  sheet), `focus.wav` (the keys moving on, very soft) and `error.wav`.

Short (a turn a quarter of a second, an opening under a second, a moment
about a second and a half) and low, mono, 22.05 kHz, 16-bit, a few tens of
KB each. Nothing is recorded or downloaded; run it again and the same files
come out (the noise is seeded).

    scripts/world-sounds.py assets/sounds      # writes every file above

Needs Python 3 with numpy.
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
    a, r = min(int(RATE * attack), n // 4), min(int(RATE * release), n // 2)
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


# ---- Stings: hits only --------------------------------------------------------


def place(out, signal, at):
    """`signal` added into `out` from `at` seconds."""
    i = int(RATE * at)
    n = min(len(signal), len(out) - i)
    out[i : i + n] += signal[:n]
    return out


def thump(f0, f1, seconds, decay):
    """A drum's body: a sine falling in pitch, dying away."""
    t = t_of(seconds)
    sweep = f1 + (f0 - f1) * np.exp(-t / 0.03)
    return np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * np.exp(-t / decay)


def lowpass(signal, hi):
    return bandpass(signal, 1.0, hi)


def saws(freqs, seconds, detune=0.004):
    """A synth's chord: two slightly apart saws on each note."""
    t = t_of(seconds)
    out = np.zeros_like(t)
    for f in freqs:
        for d in (-detune, detune):
            out += 2 * ((t * f * (1 + d)) % 1) - 1
    return out / (2 * len(freqs))


def neptune_turn():
    # A glitch slice: a crushed blip falling in pitch, stuttered twice.
    out = np.zeros(int(RATE * 0.22))
    t = t_of(0.05)
    blip = np.sign(np.sin(2 * np.pi * np.cumsum(900 - 600 * t / 0.05) / RATE)) * np.exp(-t / 0.02)
    blip = np.round(blip * 6) / 6
    place(out, blip, 0)
    place(out, 0.6 * blip, 0.06)
    place(out, 0.35 * bandpass(rng.normal(0, 1, len(t)), 2000, 6000) * np.exp(-t / 0.01), 0.12)
    return lowpass(out, 5000)


def neptune_opening():
    # A deep synth hit under a glitch: a stutter, then the chord's low root swelling out.
    out = np.zeros(int(RATE * 0.95))
    t = t_of(0.9)
    body = lowpass(saws([55, 110, 164.8], 0.9), 900) * np.exp(-t / 0.35)
    place(out, body, 0.02)
    for k, at in enumerate((0.0, 0.035, 0.07)):
        g = t_of(0.025)
        place(out, (0.5 - 0.12 * k) * bandpass(rng.normal(0, 1, len(g)), 1500, 7000) * np.exp(-g / 0.008), at)
    place(out, 0.8 * thump(120, 45, 0.5, 0.18), 0.02)
    return out


def neptune_lit():
    # A neon tube catching: its buzz in three stutters (on, off, on, low, on), a tick as the
    # gas strikes, then the hum held a moment and let go.
    out = np.zeros(int(RATE * 0.6))
    def buzz(seconds):
        t = t_of(seconds)
        hum = sum(np.sin(2 * np.pi * f * t) / k for k, f in enumerate((120, 240, 360, 480, 720), 1))
        return bandpass(np.sign(hum) * 0.4 + hum * 0.6, 90, 3000)
    for at, length, level in ((0.0, 0.05, 0.7), (0.15, 0.05, 0.9), (0.2, 0.05, 0.25), (0.25, 0.3, 1.0)):
        b = buzz(length) * level
        place(out, fade(b, 0.002, 0.008 if length < 0.1 else 0.2), at)
    t = t_of(0.02)
    place(out, 0.8 * bandpass(rng.normal(0, 1, len(t)), 2500, 8000) * np.exp(-t / 0.004), 0.25)
    return lowpass(out, 4000)


def neptune_moment():
    # A synth stab, a minor seventh, with a tail.
    t = t_of(1.4)
    stab = lowpass(saws([220, 261.6, 329.6, 392], 1.4), 2400) * np.exp(-t / 0.4)
    return stab + 0.5 * thump(110, 55, 1.4, 0.2)


def saturn_turn():
    # A film's cut: a soft low thump and the click of the gate.
    out = thump(140, 60, 0.25, 0.06)
    click = t_of(0.008)
    place(out, 0.5 * bandpass(rng.normal(0, 1, len(click)), 1500, 5000), 0.0)
    return out


def saturn_opening():
    # A low boom, and the rings' bell over it, quiet.
    t = t_of(1.0)
    boom = thump(90, 38, 1.0, 0.3)
    ring = bell(330, [(1, 1.0), (2.0, 0.3), (2.76, 0.2)], 0.4, 1.0)
    return boom + 0.35 * ring


def saturn_moment():
    # A warm chord of bells (major, open) on a boom: the film's last frame.
    t = t_of(1.6)
    chord = sum(bell(f, [(1, 1.0), (2.0, 0.2)], 0.7, 1.6) for f in (262, 330, 392, 523)) / 4
    return chord * (1 - np.exp(-t / 0.01)) + 0.6 * thump(80, 40, 1.6, 0.25)


def mercury_turn():
    # Ink: a brush's soft stroke of air.
    t = t_of(0.26)
    env = np.sin(np.pi * t / 0.26) ** 2
    return bandpass(rng.normal(0, 1, len(t)), 400, 1800) * env


def mercury_opening():
    # A taiko, and a rin ringing out over it.
    out = np.zeros(int(RATE * 1.1))
    place(out, thump(110, 70, 0.6, 0.16) + 0.25 * bandpass(rng.normal(0, 1, int(RATE * 0.6)), 200, 1200) * np.exp(-t_of(0.6) / 0.02), 0)
    place(out, 0.4 * bell(1320, [(1, 1.0), (2.71, 0.3), (5.16, 0.1)], 0.5, 1.0), 0.08)
    return out


def mercury_moment():
    # Two rin a fifth apart, and the taiko under the first.
    out = np.zeros(int(RATE * 1.5))
    place(out, bell(880, [(1, 1.0), (2.71, 0.3), (5.16, 0.1)], 0.6, 1.4), 0)
    place(out, 0.7 * bell(1318.5, [(1, 1.0), (2.71, 0.3)], 0.6, 1.3), 0.18)
    place(out, 0.7 * thump(110, 70, 0.6, 0.16), 0)
    return out


def terra_turn():
    # A sweep of air rising, and a glint of glass as the light lands.
    t = t_of(0.28)
    noise = rng.normal(0, 1, len(t))
    air = sum(bandpass(noise, c / 1.4, c * 1.4) * np.exp(-(((t / 0.28) - p) / 0.2) ** 2) for c, p in ((1500, 0.2), (2600, 0.45), (4200, 0.7)))
    glint = np.zeros_like(t)
    place(glint, 0.25 * bell(2637, [(1, 1.0), (2.4, 0.2)], 0.15, 0.1), 0.17)
    return air * 0.6 + glint


def terra_opening():
    # A furin: a few glass notes struck together, the clapper swinging.
    out = np.zeros(int(RATE * 1.0))
    for k, (f, at) in enumerate(((1760, 0.0), (2217, 0.06), (2637, 0.11), (2217, 0.3))):
        place(out, (1 - 0.2 * k) * bell(f, [(1, 1.0), (2.76, 0.2)], 0.35, 0.7), at)
    place(out, 0.5 * thump(130, 80, 0.3, 0.08), 0)
    return out


def terra_moment():
    # Sunrise: glass bells climbing a major chord, quickly.
    out = np.zeros(int(RATE * 1.5))
    for k, f in enumerate((523, 659, 784, 1047, 1319)):
        place(out, (0.6 + 0.1 * k) * bell(f, [(1, 1.0), (2.0, 0.15)], 0.45, 1.0), k * 0.07)
    return out


def luna_turn():
    # The moon's: a soft glide upwards, barely there.
    t = t_of(0.26)
    f = 600 * (900 / 600) ** (t / 0.26)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.sin(np.pi * t / 0.26) ** 2


def luna_opening():
    # A low chime under the moon.
    return bell(659, [(1, 1.0), (2.0, 0.2), (3.0, 0.08)], 0.45, 1.0) + 0.6 * bell(988, [(1, 1.0)], 0.4, 1.0)


def luna_moment():
    # A soft chord of chimes, a fifth and an octave.
    out = np.zeros(int(RATE * 1.5))
    for k, f in enumerate((659, 988, 1319)):
        place(out, bell(f, [(1, 1.0), (2.0, 0.15)], 0.55, 1.2), k * 0.12)
    return out


def open_():
    # A palette or a sheet opening: air rising, short.
    t = t_of(0.12)
    return bandpass(rng.normal(0, 1, len(t)), 1200, 5000) * np.sin(np.pi * t / 0.12) * (t / 0.12)


def close_():
    # Closing: air falling, shorter.
    t = t_of(0.1)
    return bandpass(rng.normal(0, 1, len(t)), 800, 3000) * np.sin(np.pi * t / 0.1) * (1 - t / 0.1)


def focus():
    # The keys moving on: the smallest click.
    t = t_of(0.018)
    return np.sin(2 * np.pi * 2400 * t) * np.exp(-t / 0.004)


def error():
    # Something went wrong: two low notes, falling.
    out = np.zeros(int(RATE * 0.3))
    for f, at in ((392, 0.0), (311, 0.12)):
        t = t_of(0.16)
        place(out, np.sin(2 * np.pi * f * t) * np.exp(-t / 0.06) * (1 - np.exp(-t / 0.004)), at)
    return out


STINGS = {
    "neptune-turn": (neptune_turn, 0.16),
    "neptune-opening": (neptune_opening, 0.24),
    "neptune-moment": (neptune_moment, 0.22),
    "saturn-turn": (saturn_turn, 0.18),
    "saturn-opening": (saturn_opening, 0.24),
    "saturn-moment": (saturn_moment, 0.22),
    "mercury-turn": (mercury_turn, 0.14),
    "mercury-opening": (mercury_opening, 0.24),
    "mercury-moment": (mercury_moment, 0.22),
    "terra-turn": (terra_turn, 0.14),
    "terra-opening": (terra_opening, 0.22),
    "terra-moment": (terra_moment, 0.22),
    "luna-turn": (luna_turn, 0.12),
    "luna-opening": (luna_opening, 0.2),
    "luna-moment": (luna_moment, 0.2),
    "open": (open_, 0.12),
    "close": (close_, 0.1),
    "focus": (focus, 0.08),
    "error": (error, 0.18),
    # Last, so the seeded noise of every sound above stays as it was.
    "neptune-lit": (neptune_lit, 0.14),
}

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
    for name, (make, peak) in {**SOUNDS, **STINGS}.items():
        write(out / f"{name}.wav", make(), peak)
        print(out / f"{name}.wav")


if __name__ == "__main__":
    main()
