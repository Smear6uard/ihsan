"""Placeholder tones for Ihsan.

Synthesised from sine partials only — no sample, no recording, no
license question. A struck bowl: a low fundamental with a small set of
partials, each decaying at its own rate so the bright ones fall away
first and what is left is warm.
"""
import math, struct, wave

RATE = 44100

def strike(f0, seconds, gain=1.0, start_gain=1.0):
    """One struck bowl. Partial ratios and decays are chosen so the
    upper partials fade within the first second and the fundamental
    rings on; that difference is what reads as 'warm' rather than
    'bell-like'."""
    partials = [
        # ratio, amplitude, decay seconds
        (1.000, 1.00, seconds * 0.95),
        (2.004, 0.42, seconds * 0.45),
        (2.985, 0.20, seconds * 0.26),
        (4.012, 0.11, seconds * 0.16),
        (5.430, 0.05, seconds * 0.10),
    ]
    n = int(RATE * seconds)
    out = [0.0] * n
    attack = int(RATE * 0.010)
    for ratio, amp, decay in partials:
        w = 2 * math.pi * f0 * ratio
        # A touch of drift so the partials never phase-lock into a
        # buzz the way pure integer ratios do.
        drift = 2 * math.pi * 0.15 * ratio
        for i in range(n):
            t = i / RATE
            env = math.exp(-t / (decay / 5.0))
            if i < attack:
                env *= i / attack
            out[i] += amp * env * math.sin(w * t + 0.02 * math.sin(drift * t))
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * gain * start_gain for v in out]

def mix(length_seconds, events):
    """events: (offset_seconds, samples)"""
    n = int(RATE * length_seconds)
    out = [0.0] * n
    for offset, samples in events:
        start = int(RATE * offset)
        for i, v in enumerate(samples):
            j = start + i
            if j < n:
                out[j] += v
    peak = max(abs(v) for v in out) or 1.0
    if peak > 0.89:
        out = [v / peak * 0.89 for v in out]
    return out

def fade_out(samples, seconds=0.25):
    n = int(RATE * seconds)
    total = len(samples)
    for i in range(max(0, total - n), total):
        samples[i] *= (total - i) / n
    return samples

def write(path, samples):
    samples = fade_out(list(samples))
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32000)) for v in samples
        ))
    print(path, f"{len(samples)/RATE:.1f}s")

F3 = 174.61

# The chime: one strike, a softer echo of it four seconds later. Long
# enough to serve as a repeating gentle wake, short enough to be a
# prayer notification.
write("ihsan-chime.wav", mix(8.0, [
    (0.0, strike(F3, 6.5, gain=0.85)),
    (3.9, strike(F3 * 1.5, 4.0, gain=0.34)),
]))

# The dawn variant: the same bowl, struck three times, rising in pitch
# and in volume. Nothing startles; it grows.
write("ihsan-chime-dawn.wav", mix(24.0, [
    (0.0,  strike(F3,          7.0, gain=0.30)),
    (5.5,  strike(F3 * 1.125,  7.0, gain=0.50)),
    (11.0, strike(F3 * 1.25,   8.0, gain=0.72)),
    (17.0, strike(F3 * 1.5,    7.0, gain=0.86)),
]))

# The in-app placeholder standing in for the full recording: the same
# vocabulary over a longer arc, so the AVAudioPlayer path — which is
# not bound by the notification limit — is exercised end to end.
write("ihsan-adhan-full-placeholder.wav", mix(46.0, [
    (0.0,  strike(F3,          9.0, gain=0.62)),
    (6.0,  strike(F3 * 1.125,  8.0, gain=0.58)),
    (12.0, strike(F3 * 1.333,  8.0, gain=0.62)),
    (18.0, strike(F3 * 1.5,    9.0, gain=0.66)),
    (25.0, strike(F3 * 1.333,  8.0, gain=0.58)),
    (31.0, strike(F3 * 1.125,  8.0, gain=0.54)),
    (37.0, strike(F3,         10.0, gain=0.70)),
]))
