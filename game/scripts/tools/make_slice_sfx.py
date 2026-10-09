#!/usr/bin/env python3
"""Builds the PLACEHOLDER vertical-slice sounds (task VS-32): hacks, boss patterns, the junk mech,
the robots and docking, market and junkyard ambience, and simple music stand-ins.

numpy + Python standard library only. Everything is seeded (each sound's generator is seeded from
its id), so running it twice gives byte-identical files. It reuses the building blocks of
make_battle_sfx.py and make_action_sfx.py (same folder).

    python3 game/scripts/tools/make_slice_sfx.py                # write the WAVs
    python3 game/scripts/tools/make_slice_sfx.py --write-json   # also append missing ids to sfx.json

Writes game/audio/sfx/placeholder/{hack,boss,mech,robot,scale,amb,music}_*.wav, 16-bit mono.
One-shots are 44.1 kHz. Ambience beds and music loops are 22.05 kHz to keep the repo small.
Existing entries in game/data/audio/sfx.json are never touched; --write-json only appends ids that
are not there yet (so it is safe to run again). Loops carry a WAV 'smpl' chunk, which Godot's
importer ("Detect From WAV") turns into a forward loop, and every loop is built circularly (tails
wrap round, filters work on the whole buffer), so the seam is clean without any crossfade.

Tone (docs/audio_requests.md, "Vertical slice"): cute town, grim world, loud heroes.
  * Red's hacks are warm, bright and techy. Signals machines and the Hushmaster are cold, dry and
    officious. The junk mech is loose and rattly: every impact comes with a shower of scrap.
  * Ross, 2026-10-09: the night market is LOUD and CHEERFUL from the start (chatter, music leaking
    out of speaker stacks, arcade bleeps). The junkyard is the opposite: wide, grim and lonely.
  * Anything that answers a button press has a transient in its first 10 ms.

Loudness plan: files are normalized and volume_db in sfx.json sets the ladder. The mech slam is the
loudest sound in the slice; ambience sits under all effects; music sits under the ambience.

All sounds are synthesized from scratch and imitate no existing game. The music stand-ins are short
original tunes written for this file, to be replaced by Ross's real tracks (briefed in
docs/audio_requests.md).
"""

import json
import struct
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from make_action_sfx import crush, pulse_buzz, rising_tone, sweep_noise, tick  # noqa: E402
from make_battle_sfx import (  # noqa: E402
    OUT_DIR, SFX_JSON, SR, TAU,
    bandpass, bell, burst, clank, clip, env_adsr, env_exp, finish, hz, n_of, osc, place,
    rng_for, saw, square, static_wash, thump, white,
)

LOW_RATE = 22050          # ambience beds and music loops are written at this rate
NYQUIST = SR / 2.0


# ---------------------------------------------------------------- extra building blocks

def place_wrap(buf, start, part, gain=1.0):
    """Add `part` into a loop buffer at `start` seconds; whatever runs past the end wraps round to the
    front, so a tail never gets cut and the loop seam stays clean."""
    n = len(buf)
    i = n_of(start) % n
    part = part * gain
    pos = 0
    while pos < len(part):
        take = min(len(part) - pos, n - i)
        buf[i:i + take] += part[pos:pos + take]
        pos += take
        i = (i + take) % n
    return buf


def finish_loop(x, peak):
    """Loop version of finish(): remove DC and scale to `peak`. No fade, so the seam stays seamless."""
    x = np.asarray(x, dtype=float)
    x = x - np.mean(x)
    return x / max(1e-9, np.max(np.abs(x))) * peak


def bump(n, power=1.0):
    """A smooth 0 -> 1 -> 0 hill across n samples."""
    return np.sin(np.pi * np.linspace(0.0, 1.0, n)) ** power


def fade_in(n, power=1.0):
    return np.linspace(0.0, 1.0, n) ** power


def fade_out(n, power=1.0):
    return np.linspace(1.0, 0.0, n) ** power


def lowpass(x, hi):
    return bandpass(x, 0.0, hi)


def highpass(x, lo):
    return bandpass(x, lo, NYQUIST)


def loop_freq(f, seconds):
    """Snap a frequency to a whole number of cycles over the loop, so the tone is periodic."""
    return max(1.0, round(f * seconds)) / seconds


def loop_noise(rng, n, lo, hi):
    """Band-limited noise, filtered over the whole buffer (so it is circular: it loops cleanly)."""
    x = bandpass(white(rng, n), lo, hi)
    return x / (np.std(x) + 1e-9)


def am(n, seconds, rate_hz, depth, phase=0.0):
    """Amplitude modulation that is periodic over the loop (rate snapped to whole cycles)."""
    f = loop_freq(rate_hz, seconds)
    t = np.arange(n) / SR
    return (1.0 - depth) + depth * (0.5 + 0.5 * np.sin(TAU * f * t + phase))


def pops(rng, n, count, lo=1500, hi=14000, tau=0.12, level=4.0):
    """Sparse crackle: random single-sample impulses, band-passed, with a decay."""
    p = np.zeros(n)
    idx = rng.integers(0, n, size=count)
    p[idx] = rng.uniform(-1.0, 1.0, len(idx)) * level
    return bandpass(p, lo, hi) * env_exp(n, tau, 0.001)


def metal_clatter(rng, seconds, count, base_lo=180.0, base_hi=1400.0, decay=None, small=False):
    """A shower of loose scrap: `count` little clanks scattered over `seconds`, each with its own pitch
    and decay, thinning out toward the end. Returns an array. Used by the mech and the junkyard."""
    n = n_of(seconds)
    out = np.zeros(n)
    decay = decay if decay is not None else seconds * 0.5
    for _ in range(count):
        # more clanks early, fewer late
        start = seconds * float(rng.random() ** 1.7) * 0.92
        base = float(np.exp(rng.uniform(np.log(base_lo), np.log(base_hi))))
        d = n_of(0.05 + 0.2 * float(rng.random()))
        c = clank(rng, d, base, 0.02 + 0.05 * float(rng.random()))
        amp = float(np.exp(-start / decay)) * (0.25 + 0.75 * float(rng.random()))
        if small:
            amp *= 0.4
        out = place(out, start, c, amp)
    return out[:n]


# ---------------------------------------------------------------- voices (market chatter)

VOWELS = ((730, 1090), (530, 1840), (270, 2290), (570, 840), (300, 870), (660, 1720))


def syllable(rng, dur, f0, f1, vowel, cons=0.35):
    """One babbling syllable: a glottal buzz run through two vowel formants, with a breathy consonant
    puff at the front. Not words, just the shape of speech."""
    n = n_of(dur)
    src = saw(np.linspace(f0, f1, n), n, 18)
    a, b = VOWELS[vowel]
    y = bandpass(src, a * 0.8, a * 1.25) + 0.55 * bandpass(src, b * 0.85, b * 1.2)
    y = y / (np.std(y) + 1e-9)
    puff = bandpass(white(rng, n), 2500, 9000) * env_exp(n, 0.012, 0.001)
    y = y * bump(n, 0.8) + cons * puff / (np.std(puff) + 1e-9)
    return y


def babble(rng, seconds, voices, rate_per_s=3.0, lo=95.0, hi=330.0, loud=1.0, laughs=0):
    """A crowd murmur as a circular buffer: many voices each saying a run of syllables with
    sing-song pitch, plus a few laughs ('ha ha ha': a quick run of bright, falling syllables)."""
    n = n_of(seconds)
    out = np.zeros(n)
    for _ in range(voices):
        f_base = float(rng.uniform(lo, hi))
        t = float(rng.uniform(0, 1.0))
        gain = float(rng.uniform(0.3, 1.0)) * loud
        while t < seconds:
            run = int(rng.integers(2, 7))
            for _s in range(run):
                dur = float(rng.uniform(0.07, 0.2))
                sw = float(rng.uniform(0.8, 1.35))
                syl = syllable(rng, dur, f_base, f_base * sw, int(rng.integers(0, len(VOWELS))))
                out = place_wrap(out, t, syl, gain * 0.12)
                t += dur + float(rng.uniform(0.0, 0.05))
            t += float(rng.uniform(0.3, 1.8 / (rate_per_s / 3.0)))
    for _ in range(laughs):
        t = float(rng.uniform(0, seconds))
        f = float(rng.uniform(260, 420))
        for k in range(int(rng.integers(3, 6))):
            syl = syllable(rng, 0.09, f * (1.0 - 0.05 * k), f * (0.9 - 0.05 * k), 0, 0.5)
            out = place_wrap(out, t + k * 0.13, syl, 0.2 * loud)
    return out


# ---------------------------------------------------------------- HACKS (Red: warm, bright, techy)

def make_hack_zap_cast(rng):
    """Zap Drone launches: a whir-up, a bright chirp, a click at the front. ~0.32 s."""
    n = n_of(0.32)
    t = np.arange(n) / SR
    whir = saw(np.geomspace(180, 1500, n), n, 8) * (0.7 + 0.3 * np.sin(TAU * 45 * t)) * env_adsr(n, 0.002, 0.14, 0.05)
    x = 0.7 * whir
    x = place(x, 0.0, tick(rng, n_of(0.04), 2500, 15000, 0.003), 0.9)
    x = place(x, 0.13, osc(np.geomspace(2200, 4200, n_of(0.17)), n_of(0.17), ((1, 1.0), (2, 0.25))) * env_exp(n_of(0.17), 0.06, 0.002), 0.8)
    return finish(clip(x, 1.2), 0.85, 0.03)


def make_hack_zap_fly(rng):
    """The drone in flight (loop, 1 s): a small homemade electric buzz with a wobble."""
    secs = 1.0
    n = n_of(secs)
    t = np.arange(n) / SR
    f = loop_freq(190.0, secs)
    wob = loop_freq(5.0, secs)
    ph = TAU * f * t + 0.8 * np.sin(TAU * wob * t)
    x = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.6), (3, 0.4), (5, 0.25), (7, 0.15)):
        x += a * np.sin(h * ph)
    x += 0.35 * loop_noise(rng, n, 2200, 7000) * am(n, secs, 190.0, 0.7)
    return finish_loop(clip(x, 0.8), 0.7)


def make_hack_zap_hit(rng):
    """One zap: a sharp crackle snap, clean transient, a spark 'zzt'. ~0.2 s."""
    n = n_of(0.2)
    x = 1.0 * tick(rng, n, 3000, 16000, 0.004)
    x += 0.9 * burst(rng, n, 1500, 12000, 0.02, 0.0002)
    x += 0.5 * thump(n, 600, 160, 0.02)
    x += 0.5 * osc(np.geomspace(3600, 900, n), n) * env_exp(n, 0.05, 0.0003)
    x += 0.6 * pops(rng, n, 24, 2500, 15000, 0.07, 3.0)
    x = 0.65 * x + 0.35 * crush(x, 2)
    return finish(clip(x, 1.5), 0.9, 0.025)


def make_hack_emp(rng):
    """EMP cast and pulse: a quick charge inhale (~0.15 s), a deep round whump, then crackle
    spreading out in a ring. ~0.85 s."""
    n = n_of(0.85)
    x = np.zeros(n)
    inhale_n = n_of(0.15)
    inh = sweep_noise(rng, inhale_n, 300, 6000, spread=1.6) * fade_in(inhale_n, 1.5)
    inh += 0.6 * rising_tone(inhale_n, 200, 1800, ((1, 1.0), (2, 0.3))) * fade_in(inhale_n, 1.2)
    x = place(x, 0.0, inh, 0.7)
    x = place(x, 0.0, tick(rng, n_of(0.03), 2500, 14000, 0.003), 0.8)
    x = place(x, 0.15, thump(n_of(0.6), 130, 34, 0.18), 1.7)
    x = place(x, 0.15, burst(rng, n_of(0.35), 80, 1800, 0.07, 0.0006), 0.9)
    ring_n = n_of(0.6)
    ring = sweep_noise(rng, ring_n, 1500, 9000, spread=1.8) * env_exp(ring_n, 0.2, 0.01)
    ring += pops(rng, ring_n, 60, 2000, 14000, 0.25, 3.5)
    x = place(x, 0.17, ring, 0.55)
    return finish(clip(x, 1.4), 0.95, 0.06)


def make_hack_emp_hit(rng):
    """Enemy stunned by the EMP, drones and turrets sputter: a short electric clunk plus a power-down
    fizz, like a breaker tripping. ~0.3 s."""
    n = n_of(0.3)
    x = thump(n, 330, 80, 0.04) + 0.8 * burst(rng, n, 400, 6000, 0.03, 0.0002)
    x += 0.7 * tick(rng, n, 2500, 14000, 0.004)
    fall = saw(np.geomspace(900, 70, n), n, 8) * env_exp(n, 0.1, 0.002)
    x += 0.5 * crush(fall, 4)
    x += 0.5 * pops(rng, n, 30, 2000, 13000, 0.1, 3.0)
    return finish(clip(x, 1.4), 0.9, 0.03)


def make_hack_overclock_link(rng):
    """Overclock takes a machine: a data-burst of chirps, a lock-in click, a rising tone. The most
    'hacker' sound Red has. ~0.7 s."""
    n = n_of(0.7)
    x = np.zeros(n)
    notes = (91, 98, 95, 103, 100, 107, 103, 110)
    for i, m in enumerate(notes):
        d = n_of(0.03)
        x = place(x, i * 0.032, square(hz(m), d, 5) * env_exp(d, 0.02, 0.0004), 0.6)
    x = place(x, 0.0, tick(rng, n_of(0.03), 3000, 15000, 0.003), 0.7)
    x = place(x, 0.30, tick(rng, n_of(0.04), 1500, 12000, 0.005), 0.9)
    x = place(x, 0.30, thump(n_of(0.1), 300, 110, 0.03), 0.7)
    rise_n = n_of(0.38)
    rise = rising_tone(rise_n, 520, 1850, ((1, 1.0), (2, 0.35), (3, 0.15))) * env_adsr(rise_n, 0.005, 0.2, 0.06)
    x = place(x, 0.32, rise, 0.75)
    x = place(x, 0.5, bell(hz(100), n_of(0.2), 0.1, (1.0, 2.0), (1.0, 0.3)), 0.4)
    return finish(clip(x, 1.2), 0.9, 0.05)


def make_hack_overclock_loop(rng):
    """Under a hijacked machine (loop, 2 s): a quiet cyan whine with a soft pulse, a server-room hum
    sweetened with a high shimmer."""
    secs = 2.0
    n = n_of(secs)
    t = np.arange(n) / SR
    whine = np.sin(TAU * loop_freq(880.0, secs) * t) + 0.35 * np.sin(TAU * loop_freq(1760.0, secs) * t)
    whine = whine * am(n, secs, 2.0, 0.35)
    hum = np.sin(TAU * loop_freq(110.0, secs) * t) + 0.5 * np.sin(TAU * loop_freq(220.0, secs) * t)
    shimmer = 0.15 * np.sin(TAU * loop_freq(2640.0, secs) * t + 0.5 * np.sin(TAU * 3.0 * t))
    x = 0.8 * whine + 0.7 * hum + shimmer + 0.12 * loop_noise(rng, n, 3000, 8000)
    return finish_loop(x, 0.5)


def make_hack_overclock_end(rng):
    """The link drops: a descending blip and a fizz, like unplugging a controller. ~0.5 s."""
    n = n_of(0.5)
    x = np.zeros(n)
    x = place(x, 0.0, tick(rng, n_of(0.03), 2500, 14000, 0.003), 0.8)
    for i, (f0, f1) in enumerate(((1800, 1250), (1250, 640))):
        d = n_of(0.11)
        x = place(x, i * 0.1, osc(np.geomspace(f0, f1, d), d, ((1, 1.0), (2, 0.3))) * env_exp(d, 0.08, 0.0006), 0.7)
    fz = n_of(0.35)
    x = place(x, 0.12, burst(rng, fz, 2500, 12000, 0.1, 0.002) + 0.5 * pops(rng, fz, 40, 2000, 13000, 0.12, 3.0), 0.5)
    x = place(x, 0.2, saw(np.geomspace(500, 70, n_of(0.3)), n_of(0.3), 8) * env_exp(n_of(0.3), 0.08, 0.002), 0.25)
    return finish(clip(x, 1.2), 0.85, 0.05)


def make_hack_reboot(rng):
    """Reboot: a power-down click, a hair of silence, then a warm rising boot-up chord with a chime.
    ~1.25 s. (Original notes: a D add-nine climb.)"""
    n = n_of(1.25)
    x = np.zeros(n)
    x = place(x, 0.0, tick(rng, n_of(0.04), 2000, 14000, 0.004), 0.9)
    x = place(x, 0.0, thump(n_of(0.1), 220, 70, 0.03), 0.7)
    x = place(x, 0.0, osc(np.geomspace(700, 90, n_of(0.09)), n_of(0.09)) * env_exp(n_of(0.09), 0.04, 0.0004), 0.4)
    start = 0.24
    for i, m in enumerate((50, 57, 62, 66, 69, 74)):
        d = n_of(0.9 - i * 0.04)
        note = osc(hz(m), d, ((1, 1.0), (2, 0.4), (3, 0.2))) + 0.3 * saw(hz(m) * 1.004, d, 6)
        x = place(x, start + i * 0.07, note * env_adsr(d, 0.03, 0.12, 0.28), 0.4)
    x = place(x, start + 0.46, bell(hz(98), n_of(0.6), 0.28, (1.0, 2.0, 3.01), (1.0, 0.4, 0.2)), 0.5)
    x = place(x, start + 0.46, tick(rng, n_of(0.02), 3000, 15000, 0.003), 0.3)
    return finish(clip(x, 1.1), 0.9, 0.12)


def make_hack_battery_full(rng):
    """Battery full: a tiny bright satisfied chime. Quiet, it happens a lot. ~0.26 s."""
    n = n_of(0.26)
    x = np.zeros(n)
    x = place(x, 0.0, bell(hz(93), n_of(0.2), 0.06, (1.0, 2.0, 3.0), (1.0, 0.35, 0.15)), 0.8)
    x = place(x, 0.07, bell(hz(100), n_of(0.19), 0.07, (1.0, 2.0), (1.0, 0.3)), 0.8)
    x = place(x, 0.0, tick(rng, n_of(0.02), 4000, 16000, 0.003), 0.5)
    return finish(x, 0.8, 0.04)


def make_hack_denied(rng):
    """Hack refused: a dry double blip that says no without scolding. ~0.24 s."""
    n = n_of(0.24)
    x = np.zeros(n)
    for i, f in enumerate((392.0, 330.0)):
        d = n_of(0.085)
        x = place(x, i * 0.11, (square(f, d, 4) * 0.7 + osc(f, d) * 0.4) * env_adsr(d, 0.0008, 0.04, 0.02), 0.8)
    x = place(x, 0.0, tick(rng, n_of(0.02), 1500, 8000, 0.003), 0.4)
    return finish(x, 0.75, 0.02)


def make_hack_locked(rng):
    """Quiet Hours locks Red's hacks: static clamping down (a hiss that narrows and chokes), ending
    in a dry clamp click. A radio losing signal. ~0.6 s."""
    n = n_of(0.6)
    x = sweep_noise(rng, n, 9000, 700, spread=1.7) * env_exp(n, 0.5, 0.004)
    x += 0.6 * pops(rng, n, 80, 1500, 12000, 0.4, 3.0)
    x = x * np.linspace(1.0, 0.45, n)
    x = place(x, 0.0, tick(rng, n_of(0.03), 3000, 15000, 0.004), 0.7)
    x = place(x, 0.5, tick(rng, n_of(0.05), 1200, 9000, 0.008), 1.0)
    x = place(x, 0.5, thump(n_of(0.1), 200, 80, 0.03), 0.7)
    x = place(x, 0.0, saw(np.geomspace(1200, 160, n_of(0.5)), n_of(0.5), 6) * env_exp(n_of(0.5), 0.2, 0.002), 0.18)
    return finish(clip(x, 1.2), 0.85, 0.05)


def make_hack_unlocked(rng):
    """Hacks come back: a clean click-ping. A radio finding its signal. ~0.3 s."""
    n = n_of(0.3)
    x = tick(rng, n, 2500, 15000, 0.004) * 0.9
    x += 0.8 * bell(hz(96), n, 0.12, (1.0, 2.0, 3.01), (1.0, 0.4, 0.2))
    x = place(x, 0.0, rising_tone(n_of(0.08), 900, 2400) * env_exp(n_of(0.08), 0.03, 0.001), 0.4)
    return finish(x, 0.85, 0.05)


def make_hack_target_door(rng):
    """The fuse-box gate: a spark, a clunk, then the gate grinding open (stuttering rust), a last thunk.
    ~1.5 s."""
    n = n_of(1.5)
    x = np.zeros(n)
    x = place(x, 0.0, tick(rng, n_of(0.05), 3000, 16000, 0.004) + 0.8 * pops(rng, n_of(0.25), 30, 2500, 15000, 0.08, 3.0), 0.9)
    x = place(x, 0.12, thump(n_of(0.25), 160, 50, 0.07), 1.2)
    x = place(x, 0.12, clank(rng, n_of(0.3), 310.0, 0.08), 0.5)
    gn = n_of(1.05)
    t = np.arange(gn) / SR
    grind = loop_noise(rng, gn, 150, 1400) * (0.5 + 0.5 * (np.sin(TAU * 17 * t) > 0)) * bump(gn, 0.5)
    grind += 0.6 * saw(np.linspace(52, 70, gn), gn, 10) * bump(gn, 0.5)
    grind += 0.25 * loop_noise(rng, gn, 2500, 7000) * (np.sin(TAU * 9 * t) > 0.6) * bump(gn, 0.5)
    x = place(x, 0.3, grind, 0.65)
    x = place(x, 1.28, thump(n_of(0.2), 130, 45, 0.06), 1.0)
    x = place(x, 1.28, clank(rng, n_of(0.2), 450.0, 0.05), 0.4)
    return finish(clip(x, 1.3), 0.92, 0.06)


def make_hack_target_crane_loop(rng):
    """The hijacked crane moving (loop, 2 s): a hydraulic groan and a chain rattle."""
    secs = 2.0
    n = n_of(secs)
    t = np.arange(n) / SR
    f = loop_freq(68.0, secs)
    fl = loop_freq(1.0, secs)
    groan = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.6), (3, 0.45), (4, 0.3), (6, 0.15)):
        groan += a * np.sin(h * (TAU * f * t + 1.6 * np.sin(TAU * fl * t)))
    groan = lowpass(groan, 900)
    x = 0.8 * groan * am(n, secs, 2.0, 0.3)
    x += 0.35 * loop_noise(rng, n, 200, 1500) * am(n, secs, 1.0, 0.6)
    for k in range(14):
        x = place_wrap(x, k * secs / 14 + float(rng.uniform(-0.02, 0.02)), clank(rng, n_of(0.12), float(rng.uniform(900, 1700)), 0.03), 0.18)
    return finish_loop(clip(x, 0.9), 0.7)


def make_hack_target_line_off(rng):
    """A drone line shuts down: a power-down whine and a last rotor dying (chopping slower and slower),
    one final tick. ~1.2 s."""
    n = n_of(1.2)
    t = np.arange(n) / SR
    whine = osc(900.0 * np.exp(-t / 0.38) + 90, n, ((1, 1.0), (2, 0.4))) * env_exp(n, 0.55, 0.002)
    chop_rate = 38.0 * np.exp(-t / 0.5) + 3.0
    chop = 0.5 + 0.5 * np.sin(TAU * np.cumsum(chop_rate) / SR)
    rotor = lowpass(saw(160.0 * np.exp(-t / 0.5) + 50, n, 8), 1800) * chop * env_exp(n, 0.7, 0.002)
    x = 0.7 * whine + 0.7 * rotor
    x = place(x, 0.0, tick(rng, n_of(0.03), 2500, 12000, 0.004), 0.5)
    x = place(x, 1.08, tick(rng, n_of(0.03), 2000, 10000, 0.005), 0.7)
    return finish(clip(x, 1.2), 0.85, 0.06)


def make_hack_target_terminal(rng):
    """A terminal is used: a fussy Signals beep-chirp (three officious beeps). Cold, not the friendly
    lock-on beep. ~0.4 s."""
    n = n_of(0.4)
    x = np.zeros(n)
    for start, f, dur in ((0.0, 1760.0, 0.07), (0.1, 2093.0, 0.07), (0.2, 1568.0, 0.16)):
        d = n_of(dur)
        x = place(x, start, (pulse_buzz(f, d) * 0.7 + osc(f, d) * 0.4) * env_adsr(d, 0.0006, dur * 0.5, 0.03), 0.75)
    x = place(x, 0.0, tick(rng, n_of(0.02), 3000, 14000, 0.003), 0.4)
    return finish(x, 0.8, 0.04)


# ---------------------------------------------------------------- BOSS patterns (cold, dry, metallic)

def make_boss_stomp_windup(rng):
    """Leg Stomp telegraph: a rising servo whine and an electric charge hum, a hydraulic press drawing
    back, ending on ratchet ticks. Unmistakable. ~0.8 s."""
    n = n_of(0.8)
    t = np.arange(n) / SR
    whine = saw(np.geomspace(140, 980, n), n, 10) * fade_in(n, 0.8)
    hum = osc(120.0, n, ((1, 1.0), (2, 0.5), (3, 0.5))) * (0.5 + 0.5 * np.sin(TAU * (6 + 14 * t / 0.8) * t)) * fade_in(n, 1.2)
    x = 0.6 * whine + 0.7 * hum + 0.3 * sweep_noise(rng, n, 400, 4000) * fade_in(n, 1.5)
    for k in range(7):
        x = place(x, 0.4 + k * 0.055, tick(rng, n_of(0.01), 1500, 9000, 0.002), 0.45 + 0.05 * k)
    return finish(clip(x, 1.1), 0.85, 0.04)


def make_boss_stomp_ring(rng):
    """The slam and the shock ring: a heavy clank, then a crackling ring that travels outward across
    the floor. A shockwave over sheet metal. ~1.2 s."""
    n = n_of(1.2)
    x = thump(n, 150, 34, 0.18) * 1.6
    x += 0.9 * clank(rng, n, 230.0, 0.15)
    x += 0.8 * burst(rng, n, 100, 5000, 0.05, 0.0004)
    x = place(x, 0.0, tick(rng, n_of(0.03), 2500, 15000, 0.003), 0.9)
    ring_n = n_of(1.0)
    ring = sweep_noise(rng, ring_n, 700, 9000, spread=1.8) * bump(ring_n, 0.6) * env_exp(ring_n, 0.5, 0.02)
    ring += pops(rng, ring_n, 90, 2000, 14000, 0.45, 3.5) * bump(ring_n, 0.4)
    ring += 0.4 * bell(260.0, ring_n, 0.5, (1.0, 1.59, 2.14, 2.65), (1.0, 0.6, 0.4, 0.3)) * bump(ring_n, 0.3)
    x = place(x, 0.08, ring, 0.55)
    return finish(clip(x, 1.4), 0.98, 0.08)


def make_boss_sweep_line(rng):
    """Dish Sweep line (loop, 1.5 s): a thin rising tone with a scanning tick-tick-tick. A barcode
    scanner, slowed and ominous."""
    secs = 1.5
    n = n_of(secs)
    t = np.arange(n) / SR
    tone = osc(np.geomspace(780, 1560, n), n, ((1, 1.0), (2, 0.2))) * bump(n, 0.6)
    tone *= am(n, secs, 12.0, 0.25)
    x = 0.55 * tone
    for k in range(12):
        x = place_wrap(x, k * secs / 12, tick(rng, n_of(0.02), 1800, 9000, 0.004) + 0.4 * osc(2400, n_of(0.02)) * env_exp(n_of(0.02), 0.008, 0.0004), 0.7)
    x += 0.07 * loop_noise(rng, n, 4000, 9000)
    return finish_loop(x, 0.6)


def make_boss_sweep_beam(rng):
    """Dish Sweep beam (loop, 1.5 s): a thick buzzing roar, a welding arc at stadium size."""
    secs = 1.5
    n = n_of(secs)
    t = np.arange(n) / SR
    f = loop_freq(100.0, secs)
    x = np.zeros(n)
    for h in range(1, 14):
        x += (1.0 / h ** 0.7) * np.sin(h * TAU * f * t + 0.5 * np.sin(TAU * loop_freq(3.0, secs) * t))
    x *= 0.4
    x += 0.8 * loop_noise(rng, n, 600, 7000) * am(n, secs, 100.0, 0.85)
    x += 0.4 * loop_noise(rng, n, 80, 400)
    x += 0.25 * pops(rng, n, 150, 2500, 14000, 100.0, 3.0)
    x = 0.7 * x + 0.3 * crush(x, 2)
    return finish_loop(clip(x, 0.7), 0.85)


def make_boss_drone_drop(rng):
    """Drone Drop: a hatch clank, a pneumatic hiss, three rotor spin-ups (like a vending machine
    dropping three cans, then they fly). ~1.5 s."""
    n = n_of(1.5)
    x = np.zeros(n)
    x = place(x, 0.0, clank(rng, n_of(0.35), 380.0, 0.12) + 0.8 * thump(n_of(0.35), 190, 60, 0.06) + 0.8 * tick(rng, n_of(0.35), 2000, 12000, 0.004), 0.9)
    hiss = burst(rng, n_of(0.5), 3500, 13000, 0.22, 0.01)
    x = place(x, 0.12, hiss, 0.6)
    for i, start in enumerate((0.62, 0.8, 0.98)):
        d = n_of(0.5)
        t = np.arange(d) / SR
        f = np.geomspace(70, 340 + 30 * i, d)
        chop = 0.55 + 0.45 * np.sin(TAU * np.cumsum(np.geomspace(8, 55, d)) / SR)
        rotor = (saw(f, d, 10) * chop + 0.4 * lowpass(white(rng, d), 3000) * chop) * env_adsr(d, 0.01, 0.25, 0.15)
        x = place(x, start, rotor, 0.4)
        x = place(x, start - 0.04, thump(n_of(0.08), 140, 60, 0.03), 0.5)
    return finish(clip(x, 1.2), 0.92, 0.1)


def make_boss_quiet_hours(rng):
    """Quiet Hours: the dish hums (a rising whine, a tannoy feeding back) into a static burst. ~1.5 s."""
    n = n_of(1.5)
    t = np.arange(n) / SR
    f = np.geomspace(260, 2600, n)
    whine = osc(f, n, ((1, 1.0), (2, 0.35), (3, 0.2))) * (0.7 + 0.3 * np.sin(TAU * (4 + 10 * t) * t)) * fade_in(n, 1.2)
    hum = osc(60.0, n, ((1, 1.0), (2, 0.6), (4, 0.3))) * fade_in(n, 1.5)
    x = 0.55 * whine + 0.4 * hum
    burst_n = n_of(0.3)
    x = place(x, 1.2, static_wash(rng, burst_n, False) * env_adsr(burst_n, 0.003, 0.12, 0.08), 0.8)
    x = place(x, 1.2, tick(rng, n_of(0.02), 2000, 14000, 0.003), 0.7)
    return finish(clip(x, 1.1), 0.88, 0.05)


def make_boss_quiet_hours_cut(rng):
    """Hitting the dish cuts Quiet Hours short: the whine collapses downward with a pop. ~0.6 s."""
    n = n_of(0.6)
    t = np.arange(n) / SR
    whine = osc(2200.0 * np.exp(-t / 0.12) + 70, n, ((1, 1.0), (2, 0.35))) * env_exp(n, 0.2, 0.0005)
    x = 0.8 * whine
    x = place(x, 0.0, tick(rng, n_of(0.03), 2000, 15000, 0.004), 0.9)
    x = place(x, 0.0, thump(n_of(0.12), 260, 70, 0.04), 0.8)
    x = place(x, 0.0, burst(rng, n_of(0.15), 1000, 9000, 0.03, 0.0002), 0.5)
    x = place(x, 0.5, tick(rng, n_of(0.04), 1000, 7000, 0.006), 0.5)
    return finish(clip(x, 1.2), 0.9, 0.06)


def make_boss_relay_break(rng):
    """A relay box bursts: a pop, a spark shower, a dying status beep. A fuse blowing in a filing
    cabinet. ~0.8 s."""
    n = n_of(0.8)
    x = thump(n, 360, 90, 0.03) + 0.9 * burst(rng, n, 500, 9000, 0.03, 0.0002) + 0.8 * tick(rng, n, 3000, 16000, 0.004)
    x += 0.7 * pops(rng, n, 90, 2000, 15000, 0.3, 3.5)
    x += 0.4 * clank(rng, n, 640.0, 0.05)
    for i, (f, dur) in enumerate(((1320, 0.1), (1320, 0.09), (990, 0.1), (660, 0.14))):
        d = n_of(dur)
        x = place(x, 0.28 + i * 0.13, square(f, d, 4) * env_exp(d, dur * 0.6, 0.0006), 0.35 * (1.0 - 0.15 * i))
    x = 0.8 * x + 0.2 * crush(x, 2)
    return finish(clip(x, 1.4), 0.92, 0.08)


def make_boss_topple(rng):
    """The Hushmaster topples: servos failing in groans that sag, a stagger of metal impacts, then the
    full crash with a rumble tail and debris. ~3 s."""
    n = n_of(3.0)
    x = np.zeros(n)
    sag = saw(np.geomspace(420, 36, n_of(1.7)), n_of(1.7), 12) * env_adsr(n_of(1.7), 0.05, 0.6, 0.35)
    x = place(x, 0.0, crush(sag, 3), 0.28)
    grind = sweep_noise(rng, n_of(1.4), 200, 2600) * bump(n_of(1.4), 0.7)
    x = place(x, 0.1, grind, 0.35)
    for i, s in enumerate((0.35, 0.7, 0.98, 1.2)):
        x = place(x, s, clank(rng, n_of(0.4), 300.0 - 40 * i, 0.12) + 0.7 * thump(n_of(0.3), 130, 45, 0.07), 0.45 + 0.1 * i)
    # the fall
    big = thump(n_of(1.6), 100, 24, 0.45) * 2.0 + 1.0 * burst(rng, n_of(1.6), 50, 3000, 0.22, 0.0006) + 0.9 * burst(rng, n_of(0.5), 2000, 14000, 0.03, 0.0002)
    big += 0.7 * clank(rng, n_of(1.2), 190.0, 0.4)
    x = place(x, 1.45, big, 1.0)
    x = place(x, 1.5, metal_clatter(rng, 1.4, 60, 150, 1600, 0.6), 0.5)
    x = place(x, 1.5, bandpass(white(rng, n_of(1.5)), 25, 250) * env_exp(n_of(1.5), 0.6, 0.02), 0.8)
    x = 0.8 * x + 0.2 * crush(x, 3)
    return finish(clip(x, 1.4), 1.0, 0.18)


def make_boss_jack_in(rng):
    """Red jacks into the dish: a data-dive whoosh, a rising digital roar, then a huge hit and a cyan
    ring-out. The payoff of phase 1. ~2.1 s."""
    n = n_of(2.1)
    x = np.zeros(n)
    dive_n = n_of(1.0)
    dive = sweep_noise(rng, dive_n, 250, 12000, spread=1.8) * fade_in(dive_n, 0.8)
    x = place(x, 0.0, dive, 0.85)
    x = place(x, 0.0, tick(rng, n_of(0.04), 3000, 15000, 0.004), 0.8)
    roar_n = n_of(0.5)
    tt = np.arange(roar_n) / SR
    roar = saw(np.geomspace(90, 1700, roar_n), roar_n, 14) * fade_in(roar_n, 0.8)
    roar = crush(roar, 3) * (0.7 + 0.3 * np.sign(np.sin(TAU * 38 * tt)))
    x = place(x, 0.8, roar, 0.6)
    for i in range(10):
        d = n_of(0.03)
        x = place(x, 0.1 + i * 0.09, square(hz(86 + int(rng.integers(0, 14))), d, 4) * env_exp(d, 0.02, 0.0004), 0.3)
    hit = 1.3
    x = place(x, hit, thump(n_of(0.9), 140, 32, 0.28), 1.8)
    x = place(x, hit, burst(rng, n_of(0.7), 3500, 18000, 0.22, 0.0004), 0.9)
    x = place(x, hit, burst(rng, n_of(0.4), 150, 4500, 0.07, 0.0004), 0.9)
    chord_n = n_of(0.8)
    chord = np.zeros(chord_n)
    for m, g in ((55, 0.9), (62, 0.8), (67, 0.8), (71, 0.7), (74, 0.7), (79, 0.6)):
        chord += g * (saw(hz(m), chord_n, 12) * 0.5 + square(hz(m) * 1.003, chord_n, 6) * 0.4)
    x = place(x, hit, chord * env_adsr(chord_n, 0.004, 0.15, 0.3), 0.35)
    for i, m in enumerate((98, 103, 107, 110, 115)):
        x = place(x, hit + 0.05 + i * 0.06, bell(hz(m), n_of(0.5), 0.25, (1.0, 2.0), (1.0, 0.3)), 0.28)
    return finish(clip(x, 1.2), 1.0, 0.2)


def make_boss_kasp_whistle(rng):
    """Kasp's whistle: a shrill referee whistle with a wet pea rattle. Comic and officious. ~0.45 s."""
    n = n_of(0.45)
    t = np.arange(n) / SR
    f = 2850.0 + 90.0 * np.sin(TAU * 7 * t)
    tone = osc(f, n, ((1, 1.0), (2, 0.3), (3, 0.1))) * (0.65 + 0.35 * np.sign(np.sin(TAU * 52 * t)) * 0.8)
    tone *= env_adsr(n, 0.004, 0.25, 0.07)
    breath = bandpass(white(rng, n), 2200, 6500) * env_adsr(n, 0.002, 0.3, 0.06)
    x = 0.8 * tone + 0.35 * breath
    x = place(x, 0.0, tick(rng, n_of(0.015), 3000, 9000, 0.003), 0.5)
    return finish(clip(x, 1.1), 0.85, 0.04)


# ---------------------------------------------------------------- MECH (loose, rattly, enormous)

def make_mech_assemble(rng):
    """The yard's scrap rises and locks together round Kasp: a magnetic hum building, scrap scraping
    and flying, dozens of impacts clamping into place, one huge final clamp and the floodlight head
    switching on. ~7.2 s."""
    n = n_of(7.2)
    t = np.arange(n) / SR
    x = np.zeros(n)
    hum_f = 38.0 + 55.0 * (t / 5.4).clip(0, 1) ** 1.3
    hum = osc(hum_f, n, ((1, 1.0), (2, 0.6), (3, 0.35))) * np.minimum(1.0, t / 5.2) ** 1.6
    hum *= np.where(t < 5.4, 1.0, np.exp(-(t - 5.4) / 0.4))
    x += 0.7 * hum
    # scrap scraping and flying: streaks that come faster and faster
    k = 0.0
    while k < 5.2:
        d = n_of(float(rng.uniform(0.15, 0.4)))
        lo = float(rng.uniform(500, 2500))
        streak = sweep_noise(rng, d, lo, lo * float(rng.uniform(1.5, 3.5)), spread=1.6) * bump(d, 0.8)
        x = place(x, k, streak, 0.06 + 0.22 * (k / 5.2))
        k += 0.5 * (1.1 - k / 5.2) + 0.03
    # impacts: dozens, densest in the middle
    k = 0.4
    while k < 5.3:
        base = float(np.exp(rng.uniform(np.log(110), np.log(900))))
        c = clank(rng, n_of(0.35), base, float(rng.uniform(0.05, 0.14))) + 0.5 * thump(n_of(0.2), 160, 55, 0.05)
        x = place(x, k, c, 0.12 + 0.35 * float(rng.random()))
        k += float(rng.uniform(0.06, 0.26)) * (1.3 - 0.9 * np.sin(np.pi * k / 5.4))
    # the final clamp
    x = place(x, 5.4, thump(n_of(1.4), 100, 26, 0.4), 1.7)
    x = place(x, 5.4, clank(rng, n_of(1.2), 170.0, 0.35), 0.9)
    x = place(x, 5.4, burst(rng, n_of(0.9), 1500, 14000, 0.18, 0.0003), 0.9)
    x = place(x, 5.4, metal_clatter(rng, 1.2, 40, 150, 1500, 0.5), 0.5)
    # the floodlight head switches on: relay thunk, ballast buzz that flickers, then steady
    x = place(x, 6.25, tick(rng, n_of(0.04), 1000, 8000, 0.008) + 0.9 * thump(n_of(0.1), 200, 80, 0.03), 0.9)
    ft = n_of(0.9)
    tf = np.arange(ft) / SR
    flick = np.where(((tf * 14).astype(int) % 5 == 0) & (tf < 0.4), 0.2, 1.0)
    buzz = osc(120.0, ft, ((1, 1.0), (2, 0.5), (3, 0.5), (5, 0.3))) * flick * np.minimum(1.0, tf / 0.02) * np.exp(-tf / 0.7)
    x = place(x, 6.3, buzz, 0.45)
    return finish(clip(x, 1.3), 1.0, 0.25)


def make_scale_switch(rng):
    """The scene eases out from Red's scale to the colossus's: a deep air swell with a low boom
    underneath, like a camera pulling back from a skyscraper. ~2 s."""
    n = n_of(2.0)
    x = lowpass(white(rng, n), 900) * bump(n, 1.3)
    x += 0.6 * sweep_noise(rng, n, 5000, 250, spread=1.7) * bump(n, 1.0)
    x = place(x, 0.7, thump(n_of(1.2), 80, 24, 0.35), 1.8)
    x = place(x, 0.7, bandpass(white(rng, n_of(1.0)), 30, 220) * env_exp(n_of(1.0), 0.4, 0.02), 0.9)
    x = place(x, 0.0, osc(np.geomspace(60, 38, n), n) * bump(n, 0.6), 0.6)
    return finish(clip(x, 1.1), 0.9, 0.2)


def make_mech_step(rng):
    """A junk mech footfall: a boom plus a shower of rattling scrap. Like the colossus's step but
    loose, a dump truck tipping. ~1.5 s."""
    n = n_of(1.5)
    x = thump(n, 95, 26, 0.3) * 1.8
    x += 0.9 * burst(rng, n, 50, 1800, 0.12, 0.0005)
    x += 0.5 * clank(rng, n, 150.0, 0.2)
    x += 0.4 * bandpass(white(rng, n), 25, 220) * env_exp(n, 0.5, 0.01)
    x = place(x, 0.04, metal_clatter(rng, 1.3, 55, 200, 2400, 0.45), 0.55)
    x = 0.8 * x + 0.2 * crush(x, 3)
    return finish(clip(x, 1.5), 0.98, 0.15)


def make_mech_idle_loop(rng):
    """Under the mech (loop, 4 s): creaking, groaning metal, loose sheets flapping and a rough diesel
    engine. A scrapyard in a gale."""
    secs = 4.0
    n = n_of(secs)
    t = np.arange(n) / SR
    # rough diesel: slow chugging pulses on a low saw
    f = loop_freq(46.0, secs)
    engine = lowpass(saw(f, n, 14), 700) * (0.5 + 0.5 * np.maximum(0.0, np.sin(TAU * loop_freq(11.0, secs) * t)) ** 2)
    engine += 0.3 * loop_noise(rng, n, 60, 400) * am(n, secs, 11.0, 0.8)
    x = 0.8 * engine
    wind = loop_noise(rng, n, 300, 2200) * am(n, secs, 0.5, 0.7)
    x += 0.25 * wind
    # flapping sheets
    for k in range(9):
        s = float(rng.uniform(0, secs))
        d = n_of(float(rng.uniform(0.08, 0.2)))
        x = place_wrap(x, s, (bandpass(white(rng, d), 500, 4000) * env_exp(d, 0.04, 0.002)) * 1.2, 0.35)
    # creaks and groans: slow pitch glides
    for k in range(6):
        s = float(rng.uniform(0, secs))
        d = n_of(float(rng.uniform(0.3, 0.8)))
        f0 = float(rng.uniform(180, 700))
        glide = osc(np.linspace(f0, f0 * float(rng.uniform(0.7, 1.4)), d), d, ((1, 1.0), (2, 0.5), (3, 0.3), (5, 0.2))) * bump(d, 0.9)
        x = place_wrap(x, s, lowpass(glide, 2400) * (0.7 + 0.3 * np.sin(TAU * 17 * np.arange(d) / SR)), 0.28)
    return finish_loop(clip(x, 0.9), 0.75)


def make_mech_telegraph(rng):
    """Every junk mech wind-up (readable from 75 m): a long low horn blast with scrap rattle, a ship's
    horn in fog. Same cold, dissonant family as the enemy telegraph; never the lock-on beep. ~1.2 s."""
    n = n_of(1.2)
    t = np.arange(n) / SR
    drift = 1.0 - 0.025 * t
    x = np.zeros(n)
    for f, g in ((92.0, 1.0), (130.0, 0.8), (184.0, 0.55)):
        x += g * (saw(f * drift, n, 14) * 0.6 + square(f * 1.004 * drift, n, 7) * 0.4)
    x = lowpass(x, 1800) * env_adsr(n, 0.04, 0.6, 0.2)
    x = place(x, 0.0, clank(rng, n_of(0.3), 220.0, 0.09) + 0.7 * tick(rng, n_of(0.3), 1500, 9000, 0.004), 0.5)
    x = place(x, 0.1, metal_clatter(rng, 1.0, 22, 250, 2200, 0.5, small=True), 0.4)
    return finish(clip(x, 1.1), 0.9, 0.15)


def make_mech_sting_windup(rng):
    """The sting when a mech attack winds up (data: junk_mech.json sting_at_start): a short low horn
    swell with a rattle. ~0.5 s."""
    n = n_of(0.5)
    x = np.zeros(n)
    for f, g in ((92.0, 1.0), (138.0, 0.7)):
        x += g * (saw(np.linspace(f * 0.92, f, n), n, 12) * 0.6 + square(f * 1.005, n, 6) * 0.4)
    x = lowpass(x, 1500) * env_adsr(n, 0.02, 0.18, 0.12)
    x = place(x, 0.0, clank(rng, n_of(0.2), 240.0, 0.07) + 0.6 * tick(rng, n_of(0.2), 1500, 9000, 0.004), 0.6)
    x = place(x, 0.1, metal_clatter(rng, 0.35, 10, 300, 2000, 0.25, small=True), 0.35)
    return finish(clip(x, 1.2), 0.85, 0.06)


def make_mech_sting_lock(rng):
    """The second sting when the aim locks (junk_mech.json sting_at_lock): a sharp metallic double
    stab, higher and drier than the wind-up, so 'now' reads. ~0.35 s."""
    n = n_of(0.35)
    x = np.zeros(n)
    for start, f in ((0.0, 196.0), (0.11, 261.6)):
        d = n_of(0.2)
        stab = pulse_buzz(f, d) + 0.7 * pulse_buzz(f * 1.414, d)
        x = place(x, start, lowpass(stab, 3000) * env_adsr(d, 0.0008, 0.05, 0.05), 0.7)
        x = place(x, start, tick(rng, n_of(0.04), 2000, 13000, 0.004) + 0.6 * clank(rng, n_of(0.12), 520.0, 0.04), 0.7)
    return finish(clip(x, 1.4), 0.9, 0.04)


def make_mech_swing(rng):
    """The mech's arm swing: a low, slow whoosh with debris flying off. A wrecking ball. ~1 s."""
    n = n_of(1.0)
    x = sweep_noise(rng, n, 120, 1100, spread=1.7) * bump(n, 1.3)
    x += 0.6 * osc(np.geomspace(55, 95, n), n, ((1, 1.0), (2, 0.4))) * bump(n, 1.2)
    x += 0.5 * lowpass(white(rng, n), 500) * bump(n, 1.8)
    x = place(x, 0.0, tick(rng, n_of(0.03), 1500, 9000, 0.004), 0.5)
    x = place(x, 0.3, metal_clatter(rng, 0.65, 18, 400, 3000, 0.3, small=True), 0.5)
    return finish(clip(x, 1.2), 0.92, 0.1)


def make_mech_slam(rng):
    """The biggest impact in the slice: a ground-shaking boom and a scrap avalanche. A building
    coming down. ~1.6 s."""
    n = n_of(1.6)
    x = thump(n, 105, 20, 0.55) * 2.2
    x += 1.0 * burst(rng, n, 40, 2600, 0.22, 0.0005)
    x += 0.9 * burst(rng, n, 2000, 15000, 0.03, 0.0002)
    x += 0.7 * clank(rng, n, 175.0, 0.4)
    x += 0.7 * bandpass(white(rng, n), 22, 260) * env_exp(n, 0.65, 0.01)
    x = place(x, 0.05, metal_clatter(rng, 1.45, 100, 120, 2200, 0.6), 0.7)
    x = 0.75 * x + 0.25 * crush(x, 3)
    return finish(clip(x, 1.7), 1.0, 0.2)


def make_mech_barrage(rng):
    """Scrap Barrage: the mech fires chunks of scrap, a run of launch thunks each with a whoosh and
    clatter, ending in a rattle. ~1.3 s."""
    n = n_of(1.3)
    x = np.zeros(n)
    for i in range(6):
        s = i * 0.14
        x = place(x, s, thump(n_of(0.2), 150, 55, 0.05) + 0.6 * clank(rng, n_of(0.2), float(rng.uniform(200, 380)), 0.05) + 0.6 * tick(rng, n_of(0.2), 1500, 9000, 0.004), 0.7 + 0.04 * i)
        x = place(x, s + 0.02, sweep_noise(rng, n_of(0.25), 600, 3500) * env_exp(n_of(0.25), 0.07, 0.004), 0.35)
    x = place(x, 0.8, metal_clatter(rng, 0.5, 30, 250, 2400, 0.3), 0.55)
    return finish(clip(x, 1.4), 0.92, 0.08)


def make_mech_roar(rng):
    """The mech's roar (core reveal and last stand): a huge grinding growl, a horn underneath and a
    steam venting. Metal, not an animal. ~2.4 s."""
    n = n_of(2.4)
    t = np.arange(n) / SR
    f = 64.0 + 28.0 * np.exp(-t / 0.6) - 8.0 * t
    wob = 1.0 + 0.04 * np.sin(TAU * 7.0 * t)
    x = saw(f * wob, n, 24) * (0.6 + 0.4 * np.sign(np.sin(TAU * 31 * t)))
    x += 0.8 * saw(f * 1.5 * wob, n, 14)
    x = crush(x, 3)
    x = lowpass(x, 3200) * env_adsr(n, 0.05, 1.2, 0.5)
    x += 0.5 * sweep_noise(rng, n, 400, 2400) * bump(n, 0.8)
    x = place(x, 0.0, thump(n_of(0.6), 90, 28, 0.2), 1.1)
    steam = burst(rng, n_of(1.2), 3000, 12000, 0.5, 0.05)
    x = place(x, 0.7, steam, 0.4)
    x = place(x, 0.0, metal_clatter(rng, 1.6, 40, 150, 1800, 0.8), 0.5)
    return finish(clip(x, 1.4), 0.98, 0.25)


def make_mech_plate_break(rng):
    """An armour plate tears off and falls: a shrieking metal tear, then a long falling crash. A car
    door ripped off its hinges, at 40 m. ~2 s."""
    n = n_of(2.0)
    t = np.arange(n) / SR
    tear_n = n_of(0.6)
    tt = np.arange(tear_n) / SR
    shriek = saw(1700.0 + 600.0 * np.sin(TAU * 9 * tt) - 900.0 * tt / 0.6, tear_n, 14) * (0.6 + 0.4 * np.sign(np.sin(TAU * 71 * tt)))
    shriek += 0.8 * bandpass(white(rng, tear_n), 1200, 7000)
    shriek *= env_adsr(tear_n, 0.01, 0.35, 0.1)
    x = np.zeros(n)
    x = place(x, 0.0, crush(shriek, 2), 0.6)
    x = place(x, 0.0, tick(rng, n_of(0.03), 2000, 14000, 0.004) + 0.8 * thump(n_of(0.15), 200, 60, 0.04), 0.9)
    # the plate tumbles: bounces that get closer and quieter
    fall_start = 0.7
    bounce = fall_start
    gap = 0.34
    for i in range(6):
        x = place(x, bounce, clank(rng, n_of(0.5), 150.0 + 40 * (i % 3), 0.22 - 0.02 * i) + thump(n_of(0.3), 120, 40, 0.08), 0.9 * 0.7 ** i)
        bounce += gap
        gap *= 0.72
    x = place(x, 1.0, thump(n_of(1.0), 90, 26, 0.3), 1.2)
    x = place(x, 0.8, metal_clatter(rng, 1.2, 60, 150, 2500, 0.5), 0.5)
    return finish(clip(x, 1.4), 0.98, 0.2)


def make_mech_core_hit(rng):
    """A hit on the exposed core: a hollow metallic bong, a bright crack and an electric zap. ~0.45 s."""
    n = n_of(0.45)
    x = thump(n, 220, 70, 0.07) * 1.2
    x += 0.8 * burst(rng, n, 500, 9000, 0.03, 0.0002)
    x += 0.8 * tick(rng, n, 3000, 16000, 0.004)
    x += 0.6 * bell(190.0, n, 0.3, (1.0, 1.47, 2.09, 2.78), (1.0, 0.6, 0.4, 0.25))
    x += 0.5 * osc(np.geomspace(3800, 800, n), n) * env_exp(n, 0.06, 0.0003)
    x += 0.4 * pops(rng, n, 30, 2500, 14000, 0.12, 3.0)
    x = 0.75 * x + 0.25 * crush(x, 2)
    return finish(clip(x, 1.5), 0.95, 0.06)


def make_mech_core_alarm(rng):
    """The core is exposed and Kasp's cockpit alarms (loop, 1.5 s): panicky Signals alarm beeps over a
    pulsing low tone. An office fire alarm that won't stop."""
    secs = 1.5
    n = n_of(secs)
    t = np.arange(n) / SR
    x = 0.55 * np.sin(TAU * loop_freq(55.0, secs) * t) * am(n, secs, 4.0, 0.7)
    x += 0.3 * np.sin(TAU * loop_freq(110.0, secs) * t) * am(n, secs, 4.0, 0.7)
    for k in range(12):
        s = k * secs / 12 if (k % 4) != 3 else None       # three beeps then a rest, three times
        if s is None:
            continue
        d = n_of(0.07)
        beep = (pulse_buzz(1568.0, d) * 0.6 + osc(1568.0, d) * 0.5) * env_adsr(d, 0.0006, 0.04, 0.012)
        x = place_wrap(x, s, beep, 0.8)
        x = place_wrap(x, s, tick(rng, n_of(0.01), 2500, 12000, 0.002), 0.3)
    return finish_loop(x, 0.8)


def make_mech_defeat(rng):
    """The mech collapses back into a junk pile: a long avalanche of scrap, a last clang, then one tin
    can rolling to a stop (the comic button). ~5.6 s."""
    n = n_of(5.6)
    x = np.zeros(n)
    x = place(x, 0.0, thump(n_of(2.0), 90, 22, 0.55) * 1.5 + 0.8 * burst(rng, n_of(1.6), 40, 2200, 0.5, 0.0005), 1.0)
    x = place(x, 0.0, sweep_noise(rng, n_of(1.4), 200, 2400) * bump(n_of(1.4), 0.7), 0.3)
    x = place(x, 0.0, crush(saw(np.geomspace(150, 28, n_of(1.7)), n_of(1.7), 10) * env_adsr(n_of(1.7), 0.01, 0.4, 0.4), 4), 0.3)
    x = place(x, 0.1, metal_clatter(rng, 3.4, 220, 100, 2600, 1.2), 0.75)
    x = place(x, 0.1, bandpass(white(rng, n_of(3.0)), 25, 300) * env_exp(n_of(3.0), 1.0, 0.05), 0.7)
    x = place(x, 3.35, clank(rng, n_of(1.0), 205.0, 0.45) + 0.6 * thump(n_of(0.4), 130, 50, 0.1), 0.95)
    # the tin can: tinny wobbling roll that slows, then a last little rattle
    roll_n = n_of(1.7)
    tr = np.arange(roll_n) / SR
    rate = 22.0 * np.exp(-tr / 0.55) + 1.2
    wob = 0.5 + 0.5 * np.sin(TAU * np.cumsum(rate) / SR)
    can = bandpass(white(rng, roll_n), 1800, 5200) * wob ** 2 * np.exp(-tr / 0.9)
    can += 0.5 * bell(1250.0, roll_n, 0.35, (1.0, 1.9, 2.6), (1.0, 0.5, 0.3)) * wob ** 3 * np.exp(-tr / 0.9)
    x = place(x, 3.75, can, 0.5)
    x = place(x, 5.35, bell(1900.0, n_of(0.25), 0.05, (1.0, 2.3), (1.0, 0.4)), 0.35)
    return finish(clip(x, 1.3), 1.0, 0.1)


# ---------------------------------------------------------------- ROBOTS (record at normal pitch)

def make_robot_step_small(rng):
    """The 3.5 m loader's foot: a heavy metal clomp on grating, a dull thud and a short servo whine.
    Not a boot, not a clang. ~0.26 s."""
    n = n_of(0.26)
    x = thump(n, 140, 48, 0.06) * 1.5
    x += 0.8 * burst(rng, n, 120, 1800, 0.03, 0.0004)
    x += 0.5 * tick(rng, n, 1200, 8000, 0.005)
    x += 0.35 * clank(rng, n, 480.0, 0.05)
    x += 0.3 * osc(np.geomspace(420, 240, n), n, ((1, 1.0), (2, 0.4))) * env_exp(n, 0.07, 0.003)
    x = 0.8 * x + 0.2 * crush(x, 3)
    return finish(clip(x, 1.5), 0.9, 0.03)


def make_robot_step_huge(rng):
    """The colossus's foot: a low, slow concrete-and-steel boom (under about 120 Hz) with a rolling
    tail and a distant debris patter. ~1.5 s."""
    n = n_of(1.5)
    x = lowpass(thump(n, 85, 22, 0.5), 160) * 2.2
    x += 0.8 * lowpass(burst(rng, n, 25, 260, 0.35, 0.002), 220)
    x += 0.4 * lowpass(bandpass(white(rng, n), 25, 150) * env_exp(n, 0.7, 0.02), 140)
    x += 0.3 * tick(rng, n, 400, 2500, 0.008)
    x = place(x, 0.15, metal_clatter(rng, 1.2, 35, 100, 900, 0.5, small=True), 0.35)
    return finish(clip(x, 1.4), 0.98, 0.15)


def make_robot_hatch(rng):
    """The loader's hatch folding down (and closing), also the hop-in jet puff: a pneumatic hiss, a
    rusty hinge clunk and a latch. An armoured van door. ~0.6 s."""
    n = n_of(0.6)
    x = burst(rng, n, 3000, 12000, 0.1, 0.004) * 0.7
    x = place(x, 0.0, tick(rng, n_of(0.03), 2500, 12000, 0.004), 0.5)
    x = place(x, 0.12, osc(np.geomspace(300, 180, n_of(0.25)), n_of(0.25), ((1, 1.0), (2, 0.6), (3, 0.4))) * bump(n_of(0.25), 0.5) * lowpass(white(rng, n_of(0.25)), 3000) * 0.0 + 0.5 * lowpass(saw(np.geomspace(300, 180, n_of(0.25)), n_of(0.25), 10), 1500) * bump(n_of(0.25), 0.5), 0.5)
    x = place(x, 0.34, thump(n_of(0.2), 170, 60, 0.05) + clank(rng, n_of(0.25), 330.0, 0.08), 0.9)
    x = place(x, 0.5, tick(rng, n_of(0.03), 1500, 9000, 0.005) + 0.6 * clank(rng, n_of(0.08), 1100.0, 0.02), 0.8)
    return finish(clip(x, 1.3), 0.9, 0.06)


def make_robot_bay_doors(rng):
    """The colossus's chest doors swinging open (and shut): a huge servo groan with a metal grind and
    a warning klaxon blip. A ship's bulkhead. ~0.9 s."""
    n = n_of(0.9)
    t = np.arange(n) / SR
    groan = saw(np.geomspace(48, 118, n), n, 16) * bump(n, 0.5) * (0.7 + 0.3 * np.sin(TAU * 13 * t))
    grind = bandpass(white(rng, n), 200, 2000) * bump(n, 0.7) * (0.5 + 0.5 * (np.sin(TAU * 21 * t) > 0))
    x = 0.8 * lowpass(groan, 900) + 0.5 * grind
    for s in (0.05, 0.5):
        d = n_of(0.09)
        x = place(x, s, (pulse_buzz(660.0, d) * 0.6 + osc(660.0, d) * 0.5) * env_adsr(d, 0.001, 0.05, 0.02), 0.4)
    x = place(x, 0.0, clank(rng, n_of(0.3), 260.0, 0.08), 0.5)
    x = place(x, 0.8, thump(n_of(0.1), 150, 55, 0.03), 0.6)
    return finish(clip(x, 1.2), 0.9, 0.06)


def make_robot_dock_clank(rng):
    """The loader snaps into the bay: one hard clank, a half-second of ringing metal, then 0.6 s later
    a low thunk of the clamps closing. A shuttle docking. ~1.2 s."""
    n = n_of(1.2)
    x = clank(rng, n, 300.0, 0.4, shimmer=0.4)
    x += 0.9 * thump(n, 230, 65, 0.06)
    x += 0.8 * tick(rng, n, 2000, 15000, 0.004)
    x += 0.6 * bell(hz(52), n, 0.3, (1.0, 2.76, 5.4), (1.0, 0.4, 0.2))
    x = place(x, 0.6, thump(n_of(0.4), 120, 36, 0.12) * 1.5 + 0.6 * clank(rng, n_of(0.3), 180.0, 0.08) + 0.5 * tick(rng, n_of(0.3), 800, 6000, 0.008), 0.95)
    return finish(clip(x, 1.4), 0.98, 0.1)


def make_robot_power_up(rng):
    """The robot powers on: a rising electric hum, a furnace roar underneath and three amber relay
    ticks left to right. A mech start-up, grim not shiny. ~1.5 s."""
    n = n_of(1.5)
    t = np.arange(n) / SR
    hum_f = 36.0 + 70.0 * (t / 1.3).clip(0, 1) ** 1.4
    hum = osc(hum_f, n, ((1, 1.0), (2, 0.6), (3, 0.4), (5, 0.2))) * fade_in(n, 0.9)
    furnace = lowpass(white(rng, n), 420) * fade_in(n, 1.2) * (0.8 + 0.2 * np.sin(TAU * 6.0 * t))
    x = 0.8 * hum + 0.9 * furnace
    x += 0.2 * osc(np.geomspace(240, 900, n), n) * fade_in(n, 1.5)
    for i, s in enumerate((0.3, 0.62, 0.94)):
        x = place(x, s, tick(rng, n_of(0.03), 1200, 8000, 0.006) + 0.8 * thump(n_of(0.06), 400 + 120 * i, 150, 0.015) + 0.4 * osc(1500 + 300 * i, n_of(0.04)) * env_exp(n_of(0.04), 0.015, 0.0006), 0.85)
    x = place(x, 1.2, thump(n_of(0.3), 100, 40, 0.08), 0.6)
    return finish(clip(x, 1.2), 0.9, 0.15)


def make_robot_servo_small_loop(rng):
    """The loader idling and moving (loop, 2 s): a chunky servo hum with a rattle. A forklift with
    attitude, a bit warm."""
    secs = 2.0
    n = n_of(secs)
    t = np.arange(n) / SR
    f = loop_freq(96.0, secs)
    hum = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.6), (3, 0.45), (4, 0.3), (6, 0.2)):
        hum += a * np.sin(h * (TAU * f * t + 0.5 * np.sin(TAU * loop_freq(2.0, secs) * t)))
    whine = 0.2 * np.sin(TAU * loop_freq(620.0, secs) * t + 1.5 * np.sin(TAU * loop_freq(3.0, secs) * t))
    x = 0.8 * lowpass(hum, 1400) + whine + 0.1 * loop_noise(rng, n, 150, 900)
    for k in range(8):
        x = place_wrap(x, float(rng.uniform(0, secs)), clank(rng, n_of(0.08), float(rng.uniform(600, 1500)), 0.02), 0.15)
    return finish_loop(clip(x, 0.9), 0.65)


def make_robot_servo_huge_loop(rng):
    """The colossus idling and moving (loop, 4 s): a deep hydraulic groan and slow machine breathing.
    A ship's engine room."""
    secs = 4.0
    n = n_of(secs)
    t = np.arange(n) / SR
    f = loop_freq(34.0, secs)
    groan = np.zeros(n)
    for h, a in ((1, 1.0), (2, 0.7), (3, 0.4), (4, 0.25)):
        groan += a * np.sin(h * (TAU * f * t + 1.1 * np.sin(TAU * loop_freq(0.5, secs) * t)))
    breath = loop_noise(rng, n, 40, 500) * (0.3 + 0.7 * np.maximum(0.0, np.sin(TAU * loop_freq(0.5, secs) * t)) ** 1.5)
    x = 0.9 * groan + 0.7 * breath
    x += 0.15 * lowpass(saw(loop_freq(68.0, secs) * (1 + 0.01 * np.sin(TAU * loop_freq(0.25, secs) * t)), n, 10), 600)
    for k in range(3):
        d = n_of(0.9)
        f0 = float(rng.uniform(70, 150))
        x = place_wrap(x, float(rng.uniform(0, secs)), lowpass(osc(np.linspace(f0, f0 * 0.8, d), d, ((1, 1.0), (2, 0.6), (3, 0.4))), 700) * bump(d, 0.9), 0.4)
    return finish_loop(clip(x, 0.9), 0.75)


def make_robot_swing_huge(rng):
    """The colossus's arm swings or punches: a huge low whoosh pushing air. A crane boom swinging
    past. ~0.8 s."""
    n = n_of(0.8)
    x = sweep_noise(rng, n, 90, 800, spread=1.7) * bump(n, 1.2)
    x += 0.8 * lowpass(white(rng, n), 350) * bump(n, 1.5)
    x += 0.6 * osc(np.geomspace(40, 75, n), n, ((1, 1.0), (2, 0.4))) * bump(n, 1.2)
    x = place(x, 0.0, tick(rng, n_of(0.03), 800, 5000, 0.006), 0.4)
    return finish(clip(x, 1.2), 0.9, 0.1)


def make_robot_hit_huge(rng):
    """The colossus's fist lands on the junk mech: metal crunching into scrap, a boom and falling
    debris. A car crusher closing. ~1.2 s."""
    n = n_of(1.2)
    x = thump(n, 100, 24, 0.35) * 2.0
    x += 1.0 * burst(rng, n, 80, 3500, 0.12, 0.0004)
    x += 0.8 * burst(rng, n, 1500, 12000, 0.025, 0.0002)
    x += 0.6 * clank(rng, n, 140.0, 0.25)
    x += 0.5 * crush(saw(np.geomspace(300, 40, n), n, 10) * env_exp(n, 0.2, 0.002), 5)
    x = place(x, 0.04, metal_clatter(rng, 1.0, 70, 150, 2300, 0.4), 0.6)
    x = 0.8 * x + 0.2 * crush(x, 3)
    return finish(clip(x, 1.6), 1.0, 0.12)


def _smash_scrap(rng, wall_boom):
    n = n_of(0.8)
    x = thump(n, 190, 55, 0.06 + 0.03 * wall_boom) * 1.1
    x += 0.9 * burst(rng, n, 200, 8000, 0.05, 0.0003)
    x += 0.7 * tick(rng, n, 2500, 15000, 0.004)
    x += 0.5 * clank(rng, n, float(rng.uniform(200, 380)), 0.12)
    x = place(x, 0.03, metal_clatter(rng, 0.7, 40, 250, 3200, 0.3), 0.6)
    x = 0.8 * x + 0.2 * crush(x, 2)
    return finish(clip(x, 1.5), 0.92, 0.08)


def make_robot_smash_scrap(rng):
    """The loader smashing scrap walls, props, cops and drones (the power fantasy): a crunchy metal
    crash with bits scattering. Satisfying, never heavy-sad. Variant A. ~0.8 s."""
    return _smash_scrap(rng, 0.0)


def make_robot_smash_scrap_2(rng):
    """Smash variant B: a bit more boom. ~0.8 s."""
    return _smash_scrap(rng, 1.0)


def make_robot_smash_scrap_3(rng):
    """Smash variant C: a bit more clatter. ~0.8 s."""
    return _smash_scrap(rng, 2.0)


# ---------------------------------------------------------------- AMBIENCE (loops at 22.05 kHz)

def make_amb_market_night(rng):
    """The night market bed (loop, 16 s): LOUD and CHEERFUL. A dense murmur of chatter with laughs, a
    wok sizzling, a cart bell, string lights humming, and the Signals tower's PA far off and
    unintelligible."""
    secs = 16.0
    n = n_of(secs)
    t = np.arange(n) / SR
    x = babble(rng, secs, 46, 3.5, 90, 340, 1.0, laughs=9)
    x = x / (np.max(np.abs(x)) + 1e-9)
    x += 0.2 * loop_noise(rng, n, 3000, 9000) * (0.5 + 0.5 * loop_noise(rng, n, 1, 25)).clip(0, 1)     # wok sizzle
    x += 0.1 * pops(rng, n, 1600, 2000, 9000, 100.0, 2.5)
    x += 0.09 * np.sin(TAU * loop_freq(120.0, secs) * t) + 0.05 * np.sin(TAU * loop_freq(360.0, secs) * t)   # string lights
    for s in (1.7, 5.9, 9.3, 13.4):
        x = place_wrap(x, s, bell(hz(97 + int(rng.integers(0, 3))), n_of(1.0), 0.35, (1.0, 2.0, 3.0), (1.0, 0.4, 0.15)), 0.22)
    pa = babble(rng, secs, 2, 0.8, 110, 150, 1.0)
    x += 0.7 * bandpass(pa, 400, 2600) / (np.max(np.abs(pa)) + 1e-9) * (0.4 + 0.6 * am(n, secs, 0.125, 1.0))
    return finish_loop(x, 0.9)


def _toon_tune(seconds, midi_seq, step, voice="square"):
    out = np.zeros(n_of(seconds))
    for i, m in enumerate(midi_seq):
        if m is None:
            continue
        d = n_of(step * 1.8)
        v = (square(hz(m), d, 5) * 0.6 + saw(hz(m), d, 6) * 0.3) * env_adsr(d, 0.003, step * 0.5, step * 0.25)
        out = place_wrap(out, i * step, v, 0.5)
    return out


def make_amb_market_music(rng):
    """Music leaking out of a stall's speaker stack (loop, 16 s): a cheerful tinny tune through a cheap
    speaker (band-limited, a bit crushed) with a bouncy bass. Its own little tune, original."""
    spec = TRACKS["music_market"]
    secs = spec["steps"] * 60.0 / spec["bpm"] / 4.0
    x = render_track(spec, rng)
    x = bandpass(x, 280, 4200)
    x = 0.7 * x + 0.3 * crush(x, 3)
    x = clip(x * 2.0, 1.0)
    # a little crowd hiss and a speaker buzz
    x += 0.04 * loop_noise(rng, len(x), 2000, 8000)
    return finish_loop(x, 0.85)


def make_amb_market_radio(rng):
    """A chatty counter radio (loop, 10 s): static bed, a presenter babbling, a jingle's bleeps."""
    secs = 10.0
    n = n_of(secs)
    voice = babble(rng, secs, 1, 6.0, 120, 190, 1.0)
    voice = bandpass(voice, 350, 3200)
    voice = voice / (np.max(np.abs(voice)) + 1e-9)
    x = 0.9 * voice + 0.18 * loop_noise(rng, n, 1500, 9000) + 0.04 * pops(rng, n, 200, 1200, 8000, 100.0, 3.0)
    for i, m in enumerate((88, 91, 95, 91)):
        d = n_of(0.1)
        x = place_wrap(x, 6.2 + i * 0.12, square(hz(m), d, 4) * env_exp(d, 0.07, 0.001), 0.3)
    x = x * (0.85 + 0.15 * np.sin(TAU * loop_freq(0.3, secs) * np.arange(n) / SR))
    return finish_loop(x, 0.8)


def make_amb_market_arcade(rng):
    """The bootleg arcade (loop, 10 s): original cabinet bleeps, coin drops, laser zips and a little
    win jingle, two machines out of step."""
    secs = 10.0
    n = n_of(secs)
    x = np.zeros(n)
    scale = (72, 74, 76, 79, 81, 84)
    for cab, (period, offset) in enumerate(((0.25, 0.0), (0.4, 0.07))):
        t0 = offset
        while t0 < secs:
            if rng.random() < 0.7:
                m = scale[int(rng.integers(0, len(scale)))] + (12 if cab else 0)
                d = n_of(0.07)
                x = place_wrap(x, t0, square(hz(m), d, 4) * env_exp(d, 0.05, 0.0005), 0.3)
            t0 += period
    for s in (1.3, 4.9, 8.1):                       # laser zip
        d = n_of(0.2)
        x = place_wrap(x, s, square(np.geomspace(2800, 300, d), d, 3) * env_exp(d, 0.1, 0.0005), 0.3)
    for s in (2.6, 7.2):                            # coin drop
        x = place_wrap(x, s, bell(hz(99), n_of(0.3), 0.08, (1.0, 1.5), (1.0, 0.5)), 0.35)
        x = place_wrap(x, s + 0.08, bell(hz(104), n_of(0.35), 0.1, (1.0, 1.5), (1.0, 0.5)), 0.35)
    for s in (3.8,):                                # explosion
        d = n_of(0.5)
        x = place_wrap(x, s, crush(lowpass(white(rng, d), 3500) * env_exp(d, 0.15, 0.001), 6), 0.35)
    for i, m in enumerate((72, 76, 79, 84, 79, 84, 88)):   # win jingle
        d = n_of(0.1)
        x = place_wrap(x, 5.5 + i * 0.09, (square(hz(m), d, 4) * 0.8) * env_exp(d, 0.08 if i < 6 else 0.3, 0.0005), 0.3)
    x += 0.025 * loop_noise(rng, n, 1000, 6000)
    return finish_loop(x, 0.75)


def make_amb_market_noodles(rng):
    """The noodle cart (loop, 10 s): a wok sizzling, a ladle clinking, a chopper tapping, a boiling
    pot's bubbles and a cart bell."""
    secs = 10.0
    n = n_of(secs)
    siz = loop_noise(rng, n, 3500, 10000) * (0.55 + 0.45 * loop_noise(rng, n, 1, 20).clip(-1, 1))
    x = 0.5 * siz + 0.15 * pops(rng, n, 900, 2500, 9000, 100.0, 2.5)
    x += 0.35 * loop_noise(rng, n, 80, 300) * am(n, secs, 0.6, 0.5)               # pot rumble
    for k in range(60):                                                         # bubbles
        s = float(rng.uniform(0, secs))
        d = n_of(0.05)
        f0 = float(rng.uniform(300, 700))
        x = place_wrap(x, s, osc(np.linspace(f0, f0 * 1.8, d), d) * env_exp(d, 0.02, 0.001), 0.1)
    for k in range(24):                                                         # chopping, in a steady rhythm
        x = place_wrap(x, 1.0 + k * 0.165, thump(n_of(0.05), 400, 170, 0.015) + 0.5 * tick(rng, n_of(0.05), 1500, 7000, 0.005), 0.35)
    for s in (0.8, 3.1, 6.6):                                                   # ladle on the wok
        x = place_wrap(x, s, clank(rng, n_of(0.35), 1100.0, 0.1), 0.3)
    x = place_wrap(x, 8.2, bell(hz(99), n_of(1.0), 0.4, (1.0, 2.0, 3.0), (1.0, 0.4, 0.15)), 0.35)
    return finish_loop(x, 0.8)


def make_amb_market_charger(rng):
    """The grandma's charging stall (loop, 10 s): a mains hum, a little fan, cheerful charge-up pings
    from the phones on the rack and a contented hummed tune."""
    secs = 10.0
    n = n_of(secs)
    t = np.arange(n) / SR
    hum = np.sin(TAU * loop_freq(100.0, secs) * t) + 0.5 * np.sin(TAU * loop_freq(200.0, secs) * t) + 0.3 * np.sin(TAU * loop_freq(300.0, secs) * t)
    x = 0.28 * hum * (0.85 + 0.15 * np.sin(TAU * loop_freq(0.8, secs) * t))
    x += 0.25 * loop_noise(rng, n, 400, 2500) * am(n, secs, 0.2, 0.3)
    for s, m in ((0.9, 95), (2.9, 98), (4.4, 100), (6.0, 95), (7.7, 103), (9.0, 98)):
        d = n_of(0.5)
        x = place_wrap(x, s, bell(hz(m), d, 0.15, (1.0, 2.0), (1.0, 0.3)), 0.28)
        x = place_wrap(x, s + 0.09, bell(hz(m + 7), d, 0.15, (1.0, 2.0), (1.0, 0.3)), 0.28)
    tune = (60, 64, 67, 64, 62, 65, 69, 65)
    for i, m in enumerate(tune * 2):
        d = n_of(0.35)
        x = place_wrap(x, 0.5 + i * 0.6, lowpass(osc(hz(m + 12) * (1 + 0.012 * np.sin(TAU * 5 * np.arange(d) / SR)), d, ((1, 1.0), (2, 0.5), (3, 0.2))), 1800) * bump(d, 0.6), 0.1)
    return finish_loop(x, 0.7)


def make_amb_market_chimes(rng):
    """Wind chimes on the tarp poles (loop, 10 s): bright inharmonic pentatonic bells at random, with
    gusts of wind swelling under them."""
    secs = 10.0
    n = n_of(secs)
    x = 0.3 * loop_noise(rng, n, 500, 3500) * (0.25 + 0.75 * (0.5 + 0.5 * np.sin(TAU * loop_freq(0.2, secs) * np.arange(n) / SR)) ** 2)
    notes = (84, 86, 88, 91, 93, 96)
    for k in range(34):
        s = float(rng.uniform(0, secs))
        m = notes[int(rng.integers(0, len(notes)))]
        d = n_of(1.3)
        x = place_wrap(x, s, bell(hz(m), d, float(rng.uniform(0.3, 0.7)), (1.0, 2.76, 5.4), (1.0, 0.4, 0.2)), float(rng.uniform(0.1, 0.35)))
    return finish_loop(x, 0.7)


def make_amb_market_drones(rng):
    """The kids' scrap drones whizzing past (one-shot, 2 s): two little rotors zooming by, pitch
    sliding down as they pass."""
    n = n_of(2.0)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for s, f0 in ((0.0, 420.0), (0.35, 560.0)):
        d = n_of(1.4)
        tt = np.arange(d) / SR
        f = f0 * (1.25 - 0.55 / (1 + np.exp(-(tt - 0.7) * 7.0)))
        chop = 0.7 + 0.3 * np.sin(TAU * 38 * tt)
        v = (saw(f, d, 10) * chop * 0.6 + 0.4 * bandpass(white(rng, d), 600, 3500)) * bump(d, 1.4)
        x = place(x, s, v, 0.6)
    return finish(x, 0.75, 0.1)


def make_amb_market_patrol(rng):
    """A Signals patrol passes through on the hour (one-shot, 9 s): boots in step, a radio squawk, one
    whistle. The market goes quiet, then comes back (the crowd bed ducks in code)."""
    secs = 9.0
    n = n_of(secs)
    x = np.zeros(n)
    steps = 16
    for k in range(steps):
        s = 0.4 + k * 0.5
        near = np.sin(np.pi * (k + 0.5) / steps) ** 1.3
        for side in (0, 1):
            x = place(x, s + side * 0.0, thump(n_of(0.12), 150, 60, 0.03) + 0.7 * burst(rng, n_of(0.1), 400, 4000, 0.02, 0.0003) + 0.3 * clank(rng, n_of(0.08), 900.0, 0.02), 0.5 * near + 0.05)
    sq = n_of(0.5)
    squawk = bandpass(static_wash(rng, sq, False), 400, 3500) * env_adsr(sq, 0.003, 0.25, 0.1)
    squawk += 0.4 * square(hz(88), n_of(0.08), 4).repeat(1)[:sq].tolist().__len__() * 0.0 if False else 0.0
    x = place(x, 3.9, squawk, 0.7)
    for i, f in enumerate((1568.0, 1320.0)):
        d = n_of(0.07)
        x = place(x, 4.5 + i * 0.1, square(f, d, 3) * env_exp(d, 0.04, 0.0005), 0.25)
    wn = n_of(0.5)
    tw = np.arange(wn) / SR
    whistle = osc(2950.0 + 80 * np.sin(TAU * 7 * tw), wn, ((1, 1.0), (2, 0.2))) * (0.7 + 0.3 * np.sign(np.sin(TAU * 52 * tw))) * env_adsr(wn, 0.005, 0.28, 0.07)
    x = place(x, 5.7, whistle, 0.5)
    return finish(x, 0.8, 0.3)


def make_amb_junkyard(rng):
    """The junkyard bed (loop, 16 s): wind over metal, creaks and ticks, distant crane chains, a
    far-off crusher, scrap settling and a drone buzzing somewhere. Grim, wide and a little lonely."""
    secs = 16.0
    n = n_of(secs)
    t = np.arange(n) / SR
    gust = (0.5 + 0.5 * np.sin(TAU * loop_freq(0.125, secs) * t + 0.8)) ** 1.5
    x = 0.55 * loop_noise(rng, n, 120, 900) * (0.35 + 0.65 * gust)
    x += 0.25 * loop_noise(rng, n, 900, 2600) * gust
    x += 0.12 * np.sin(TAU * loop_freq(430.0, secs) * t + 2.0 * np.sin(TAU * loop_freq(0.25, secs) * t)) * gust ** 2     # wind whistling
    for k in range(7):                                    # creaks
        d = n_of(float(rng.uniform(0.4, 1.0)))
        f0 = float(rng.uniform(220, 800))
        x = place_wrap(x, float(rng.uniform(0, secs)), lowpass(osc(np.linspace(f0, f0 * float(rng.uniform(0.6, 1.5)), d), d, ((1, 1.0), (2, 0.5), (3, 0.3))), 2200) * bump(d, 0.9), 0.1)
    for k in range(18):                                   # ticks of cooling metal
        x = place_wrap(x, float(rng.uniform(0, secs)), tick(rng, n_of(0.02), 1500, 7000, 0.004) + 0.4 * osc(float(rng.uniform(900, 2400)), n_of(0.03)) * env_exp(n_of(0.03), 0.01, 0.0005), 0.18)
    for s in (2.5, 9.0):                                  # distant crane chains
        for j in range(int(rng.integers(8, 13))):
            x = place_wrap(x, s + j * float(rng.uniform(0.05, 0.11)), clank(rng, n_of(0.12), float(rng.uniform(1500, 2600)), 0.03), 0.07)
    crush_gap = secs / 3.0                                # a far-off crusher
    for k in range(3):
        s = 1.0 + k * crush_gap
        x = place_wrap(x, s, lowpass(thump(n_of(1.2), 70, 26, 0.3), 140), 0.7)
        x = place_wrap(x, s, lowpass(bandpass(white(rng, n_of(1.0)), 30, 400) * env_exp(n_of(1.0), 0.4, 0.02), 400), 0.3)
    for s in (6.4, 12.7):                                 # scrap settling
        x = place_wrap(x, s, metal_clatter(rng, 1.2, 14, 250, 2200, 0.4, small=True), 0.4)
    drone_f = loop_freq(210.0, secs)                      # a drone buzzing somewhere
    drone = lowpass(saw(drone_f * (1 + 0.02 * np.sin(TAU * loop_freq(0.25, secs) * t)), n, 8), 1400)
    x += 0.04 * drone * (np.sin(TAU * loop_freq(0.0625, secs) * t) > 0.2)
    return finish_loop(clip(x, 0.9), 0.7)


# ---------------------------------------------------------------- MUSIC stand-ins (loops)
#
# A tiny step sequencer. Every track is 8 bars of 16 steps (128 steps), written as lists of
# (scale_degree_or_None, length_in_steps) per bar. Everything is original, simple on purpose, and
# there to be replaced.

MAJOR = (0, 2, 4, 5, 7, 9, 11)
MINOR = (0, 2, 3, 5, 7, 8, 10)
PHRYGIAN = (0, 1, 3, 5, 7, 8, 10)


def degree_midi(root, scale, d):
    return root + 12 * (d // len(scale)) + scale[d % len(scale)]


def bars_to_events(bars):
    """[(degree|None, len), ...] per bar -> [(step, degree, len)] over the whole track."""
    out = []
    step = 0
    for bar in bars:
        total = 0
        for d, ln in bar:
            if d is not None:
                out.append((step, d, ln))
            step += ln
            total += ln
        assert total == 16, "a bar must add up to 16 steps (got %d)" % total
    return out


def synth_note(kind, midi, dur_s, vel=1.0):
    f = hz(midi)
    tail = {"lead": 0.18, "bass": 0.1, "brass": 0.25, "pluck": 0.3, "pad": 0.4, "growl": 0.12}[kind]
    n = n_of(dur_s + tail)
    if kind == "lead":
        x = square(f, n, 6) * 0.5 + saw(f * 1.003, n, 8) * 0.35
        env = env_adsr(n, 0.004, dur_s * 0.7, 0.07)
    elif kind == "bass":
        x = lowpass(saw(f, n, 10), 900) * 0.7 + osc(f, n) * 0.6
        env = env_adsr(n, 0.003, dur_s * 0.5, 0.05)
    elif kind == "brass":
        x = saw(f, n, 14) * 0.6 + saw(f * 1.006, n, 14) * 0.4
        x = lowpass(x, 2800)
        env = env_adsr(n, 0.035, dur_s * 0.8, 0.09)
    elif kind == "pluck":
        x = osc(f, n, ((1, 1.0), (2, 0.4), (3, 0.2))) + 0.3 * square(f, n, 4)
        env = env_exp(n, 0.12, 0.002)
    elif kind == "pad":
        x = osc(f, n, ((1, 1.0), (2, 0.3))) + 0.6 * osc(f * 1.005, n, ((1, 1.0), (3, 0.2)))
        env = env_adsr(n, 0.05, dur_s * 0.7, 0.18)
    else:  # growl
        x = crush(lowpass(saw(f, n, 20), 1400), 3) * 0.8 + 0.4 * square(f * 0.5, n, 5)
        env = env_adsr(n, 0.004, dur_s * 0.7, 0.05)
    return x * env * vel


def drum_kick(n_len=0.18):
    n = n_of(n_len)
    return thump(n, 190, 48, 0.07) * 1.1


def drum_snare(rng, n_len=0.2):
    n = n_of(n_len)
    return 0.8 * burst(rng, n, 1200, 9000, 0.05, 0.0004) + 0.5 * thump(n, 260, 150, 0.04)


def drum_hat(rng, open_=False):
    n = n_of(0.16 if open_ else 0.04)
    return burst(rng, n, 6000, 16000, 0.07 if open_ else 0.012, 0.0003)


def render_track(spec, rng):
    """Mix a TRACKS spec into a circular buffer (tails wrap, so the loop is seamless)."""
    bpm = spec["bpm"]
    step_s = 60.0 / bpm / 4.0
    steps = spec["steps"]
    n = n_of(steps * step_s)
    scale = spec["scale"]
    root = spec["root"]
    mix = np.zeros(n)
    for layer in spec["layers"]:
        kind = layer["kind"]
        gain = layer.get("gain", 1.0)
        if kind in ("kick", "snare", "hat", "ohat"):
            for st in layer["steps"]:
                if kind == "kick":
                    snd = drum_kick()
                elif kind == "snare":
                    snd = drum_snare(rng)
                else:
                    snd = drum_hat(rng, kind == "ohat")
                mix = place_wrap(mix, st * step_s, snd, gain)
            continue
        octave = layer.get("octave", 0)
        for st, d, ln in bars_to_events(layer["bars"]):
            m = degree_midi(root, scale, d) + 12 * octave
            mix = place_wrap(mix, st * step_s, synth_note(kind, m, ln * step_s * layer.get("gate", 0.9)), gain * layer.get("vel", 1.0))
    return mix


def every(step_list, bars, per_bar=16):
    return [b * per_bar + s for b in range(bars) for s in step_list]


def pattern_bass(roots, rhythm, bars_rhythm):
    """Build bass bars from per-bar root degrees and a rhythm of (offset_degree, len)."""
    bars = []
    for r in roots:
        bar = []
        for off, ln in rhythm:
            bar.append((None if off is None else r + off, ln))
        bars.append(bar)
    return bars


MARKET_MELODY = [
    [(2, 2), (4, 2), (5, 2), (4, 2), (2, 4), (1, 2), (0, 2)],
    [(5, 3), (4, 1), (2, 2), (0, 2), (2, 4), (None, 4)],
    [(3, 2), (5, 2), (7, 2), (5, 2), (3, 4), (5, 2), (4, 2)],
    [(4, 4), (2, 2), (1, 2), (4, 4), (None, 2), (1, 2)],
    [(7, 2), (9, 2), (7, 2), (4, 2), (2, 4), (4, 2), (7, 2)],
    [(5, 2), (7, 2), (5, 2), (4, 2), (2, 6), (None, 2)],
    [(3, 2), (5, 2), (3, 2), (1, 2), (0, 4), (1, 2), (2, 2)],
    [(4, 2), (1, 2), (2, 2), (4, 2), (4, 6), (None, 2)],
]
MARKET_BASS_ROOTS = [-7, -9, -11, -10, -7, -9, -11, -10]            # C Am F G as scale degrees below the root (octave down)
MARKET_BASS_RHYTHM = [(0, 2), (None, 2), (4, 2), (None, 2), (0, 2), (None, 2), (4, 2), (2, 2)]
MARKET_ARP = [[(0, 2), (2, 2), (4, 2), (2, 2)] * 2 for _ in range(8)]
# chord arpeggio roots by bar (C, Am, F, G) as degrees: 0, 5, 3, 4 ; built below with offsets

BATTLE_MELODY = [
    [(0, 3), (2, 1), (4, 2), (2, 2), (0, 2), (None, 2), (4, 2), (5, 2)],
    [(4, 3), (2, 1), (0, 2), (2, 2), (4, 4), (None, 2)],
    [(5, 3), (4, 1), (2, 2), (4, 2), (5, 2), (7, 2), (5, 2)],
    [(4, 3), (2, 1), (1, 2), (2, 2), (4, 4), (None, 2)],
    [(7, 3), (5, 1), (4, 2), (5, 2), (7, 2), (9, 2), (7, 2)],
    [(5, 3), (4, 1), (2, 2), (4, 2), (5, 4), (None, 2)],
    [(7, 2), (9, 2), (7, 2), (5, 2), (4, 2), (2, 2), (4, 2), (5, 2)],
    [(4, 6), (2, 2), (1, 2), (0, 2), (None, 4)],
]

TOUGH_MELODY = [
    [(0, 1), (1, 1), (0, 2), (None, 2), (3, 2), (1, 2), (0, 2), (None, 4)],
    [(4, 2), (3, 2), (1, 2), (0, 2), (1, 2), (3, 2), (4, 2), (None, 2)],
    [(5, 1), (4, 1), (3, 2), (None, 2), (1, 2), (0, 2), (1, 2), (3, 2), (None, 2)][:9],
    [(7, 4), (5, 2), (4, 2), (3, 4), (1, 2), (0, 2)],
    [(0, 1), (1, 1), (0, 2), (None, 2), (3, 2), (1, 2), (0, 2), (None, 4)],
    [(7, 2), (8, 2), (7, 2), (5, 2), (4, 2), (3, 2), (1, 2), (0, 2)],
    [(5, 2), (4, 2), (3, 2), (1, 2), (3, 4), (4, 2), (5, 2)],
    [(8, 4), (7, 4), (5, 4), (4, 4)],
]
# bar 3 above sums to 16 only after the slice, fix explicitly:
TOUGH_MELODY[2] = [(5, 1), (4, 1), (3, 2), (None, 2), (1, 2), (0, 2), (1, 2), (3, 2), (None, 2)]

BOSS_MELODY = [
    [(0, 3), (0, 1), (2, 2), (4, 2), (7, 4), (None, 4)],
    [(5, 3), (5, 1), (4, 2), (2, 2), (4, 4), (None, 4)],
    [(0, 3), (0, 1), (2, 2), (4, 2), (7, 2), (9, 2), (7, 2), (None, 2)],
    [(8, 3), (7, 1), (5, 2), (4, 2), (2, 4), (None, 4)],
    [(7, 3), (7, 1), (9, 2), (11, 2), (14, 4), (None, 4)],
    [(12, 3), (11, 1), (9, 2), (7, 2), (9, 4), (None, 4)],
    [(7, 2), (9, 2), (11, 2), (12, 2), (11, 2), (9, 2), (7, 2), (4, 2)],
    [(7, 8), (None, 8)],
]

HUSH_MELODY = [
    [(0, 1), (None, 1), (0, 1), (None, 1), (4, 2), (2, 2), (0, 2), (None, 2), (2, 1), (None, 1), (4, 2)],
    [(5, 1), (None, 1), (5, 1), (None, 1), (7, 2), (5, 2), (4, 2), (None, 2), (2, 1), (None, 1), (4, 2)],
    [(0, 1), (None, 1), (0, 1), (None, 1), (4, 2), (7, 2), (9, 2), (None, 2), (7, 1), (None, 1), (4, 2)],
    [(8, 2), (7, 2), (5, 2), (4, 2), (2, 2), (4, 2), (1, 2), (None, 2)],
    [(2, 1), (None, 1), (2, 1), (None, 1), (6, 2), (4, 2), (2, 2), (None, 2), (4, 1), (None, 1), (6, 2)],
    [(7, 1), (None, 1), (7, 1), (None, 1), (9, 2), (7, 2), (6, 2), (None, 2), (4, 1), (None, 1), (6, 2)],
    [(9, 2), (7, 2), (6, 2), (4, 2), (2, 2), (4, 2), (6, 2), (7, 2)],
    [(4, 2), (None, 2), (1, 2), (None, 2), (0, 8)],
]

JUNK_MELODY = [
    [(0, 2), (None, 2), (0, 1), (1, 1), (0, 2), (None, 2), (3, 2), (None, 2), (4, 2)],
    [(5, 2), (None, 2), (4, 2), (None, 2), (3, 2), (None, 2), (1, 2), (0, 2)],
    [(0, 2), (None, 2), (0, 1), (1, 1), (0, 2), (None, 2), (3, 2), (None, 2), (7, 2)],
    [(8, 4), (7, 4), (5, 4), (3, 2), (4, 2)],
    [(0, 2), (None, 2), (0, 1), (1, 1), (0, 2), (None, 2), (3, 2), (None, 2), (4, 2)],
    [(7, 2), (5, 2), (4, 2), (3, 2), (5, 2), (4, 2), (3, 2), (1, 2)],
    [(0, 1), (0, 1), (0, 2), (None, 2), (0, 1), (0, 1), (0, 2), (None, 2), (3, 2), (4, 2)],
    [(1, 4), (0, 12)],
]


def fix_bars(bars):
    """Pad or trim each bar to exactly 16 steps so the tables above stay easy to write by hand."""
    out = []
    for bar in bars:
        total = 0
        fixed = []
        for d, ln in bar:
            if total + ln > 16:
                ln = 16 - total
            if ln <= 0:
                break
            fixed.append((d, ln))
            total += ln
        if total < 16:
            fixed.append((None, 16 - total))
        out.append(fixed)
    return out


def arp_bars(chord_degrees, pattern=(0, 2, 4, 2), step_len=2):
    """Arpeggio bars: per bar, cycle the chord's thirds-stack (degree offsets 0, 2, 4)."""
    bars = []
    for root in chord_degrees:
        bar = []
        for i in range(16 // step_len):
            bar.append((root + pattern[i % len(pattern)], step_len))
        bars.append(bar)
    return bars


def bass_bars(roots, rhythm):
    bars = []
    for r in roots:
        bars.append([(None if off is None else r + off, ln) for off, ln in rhythm])
    return bars


def _drums(kicks, snares, hats, ohats=()):
    return [
        {"kind": "kick", "steps": kicks, "gain": 0.85},
        {"kind": "snare", "steps": snares, "gain": 0.55},
        {"kind": "hat", "steps": hats, "gain": 0.22},
        {"kind": "ohat", "steps": list(ohats), "gain": 0.2},
    ]


TRACKS = {
    # Cheerful night market: sunny, bouncy, major, a little swing in the arpeggios (a warm pocket).
    "music_market": {
        "bpm": 116, "steps": 128, "root": 60, "scale": MAJOR,
        "layers": [
            {"kind": "lead", "bars": fix_bars(MARKET_MELODY), "gain": 0.55, "octave": 0},
            {"kind": "pluck", "bars": arp_bars([0, 5, 3, 4, 0, 5, 3, 4], (0, 2, 4, 2), 2), "gain": 0.28, "octave": 0},
            {"kind": "bass", "bars": bass_bars([-7, -9, -11, -10, -7, -9, -11, -10], MARKET_BASS_RHYTHM), "gain": 0.65},
        ] + _drums(every([0, 8], 8), every([4, 12], 8), every(list(range(0, 16, 2)), 8), every([14], 8)),
    },
    # Regular fight: hot-blooded, driving E minor, steady beat.
    "music_battle_regular": {
        "bpm": 156, "steps": 128, "root": 64, "scale": MINOR,
        "layers": [
            {"kind": "lead", "bars": fix_bars(BATTLE_MELODY), "gain": 0.55, "octave": 0},
            {"kind": "growl", "bars": arp_bars([0, 0, 5, 6, 0, 0, 5, 6], (0, 0, 4, 0), 2), "gain": 0.28, "octave": -1},
            {"kind": "bass", "bars": bass_bars([-7, -7, -9, -8, -7, -7, -9, -8], [(0, 2), (0, 2), (None, 2), (0, 2), (0, 2), (0, 2), (None, 2), (4, 2)]), "gain": 0.7},
        ] + _drums(every([0, 6, 8, 11], 8), every([4, 12], 8), every(list(range(0, 16, 2)), 8), every([14], 8)),
    },
    # Tough fight: faster, tenser, A phrygian with chromatic bite and a 16th bass pulse.
    "music_battle_tough": {
        "bpm": 166, "steps": 128, "root": 57, "scale": PHRYGIAN,
        "layers": [
            {"kind": "lead", "bars": fix_bars(TOUGH_MELODY), "gain": 0.55, "octave": 0},
            {"kind": "growl", "bars": arp_bars([0, 5, 6, 4, 0, 5, 6, 4], (0, 2, 0, 3), 1), "gain": 0.22, "octave": -1},
            {"kind": "bass", "bars": bass_bars([-7, -9, -8, -10, -7, -9, -8, -10], [(0, 1)] * 4 + [(None, 1)] + [(0, 1)] * 3 + [(0, 1), (None, 1), (1, 1), (0, 1), (0, 1), (None, 1), (3, 1), (0, 1)]), "gain": 0.7},
        ] + _drums(every([0, 3, 6, 8, 10, 14], 8), every([4, 12], 8), every(list(range(0, 16, 1)), 8), []),
    },
    # Boss fight (battle_boss): pompous march, brassy, swaggering.
    "music_battle_boss": {
        "bpm": 148, "steps": 128, "root": 58, "scale": MAJOR,
        "layers": [
            {"kind": "brass", "bars": fix_bars(BOSS_MELODY), "gain": 0.6, "octave": 0},
            {"kind": "brass", "bars": arp_bars([0, 3, 4, 0, 0, 3, 4, 0], (0, 2, 4, 2), 4), "gain": 0.3, "octave": -1},
            {"kind": "bass", "bars": bass_bars([-7, -4, -3, -7, -7, -4, -3, -7], [(0, 4), (None, 2), (0, 2), (0, 4), (None, 2), (4, 2)]), "gain": 0.7},
        ] + _drums(every([0, 8], 8), every([4, 12, 14, 15], 8), every([0, 4, 8, 12], 8), []),
    },
    # Kasp and the Hushmaster (phase 1): bureaucratic march, staccato brass over a ticking jam pulse.
    "music_hushmaster": {
        "bpm": 140, "steps": 128, "root": 62, "scale": MAJOR,
        "layers": [
            {"kind": "brass", "bars": fix_bars(HUSH_MELODY), "gain": 0.55, "gate": 0.45},
            {"kind": "pluck", "bars": arp_bars([0, 0, 3, 4, 1, 1, 3, 4], (0, 4, 2, 4), 1), "gain": 0.16, "octave": 1},
            {"kind": "bass", "bars": bass_bars([-7, -7, -4, -3, -6, -6, -4, -3], [(0, 2), (None, 2), (0, 2), (None, 2), (0, 2), (None, 2), (4, 2), (2, 2)]), "gain": 0.68},
        ] + _drums(every([0, 8], 8), every([4, 12], 8), every(list(range(0, 16, 1)), 8), []),
    },
    # Phase 2, the junk mech: heavy, lurching, C minor with a distorted chug.
    "music_junk_mech": {
        "bpm": 132, "steps": 128, "root": 60, "scale": MINOR,
        "layers": [
            {"kind": "growl", "bars": fix_bars(JUNK_MELODY), "gain": 0.6, "octave": 0},
            {"kind": "growl", "bars": bass_bars([-14, -14, -14, -11, -14, -14, -12, -11], [(0, 1), (0, 1), (None, 2), (0, 1), (0, 1), (None, 2)] * 2 + [(0, 1)] * 4), "gain": 0.55},
            {"kind": "bass", "bars": bass_bars([-14, -14, -14, -11, -14, -14, -12, -11], [(0, 4), (None, 4), (0, 2), (None, 2), (3, 4)]), "gain": 0.8},
        ] + _drums(every([0, 3, 8, 11], 8), every([4, 12], 8), every(list(range(0, 16, 2)), 8), every([6, 14], 8)),
    },
}


def _music_builder(track_id):
    def build(rng):
        x = render_track(TRACKS[track_id], rng)
        x = clip(x * 0.9, 1.0)
        return finish_loop(x, 0.8)
    build.__doc__ = "Music stand-in %s (loop): a simple sequenced tune; see TRACKS for the notes." % track_id
    return build


# ---------------------------------------------------------------- registry
#
# id -> dict(build, db, note, loop?, bus?, rate?). volume_db plans the loudness ladder.

def S(build, db, note, loop=False, bus="SFX", rate=SR):
    return {"build": build, "db": db, "note": note, "loop": loop, "bus": bus, "rate": rate}


SOUNDS = {
    # --- hacks (docs/audio_requests.md rows 76 to 88)
    "hack_zap_cast": S(make_hack_zap_cast, -7.0, "Zap Drone launches: a quick whir-up and a bright chirp, light and eager."),
    "hack_zap_fly": S(make_hack_zap_fly, -16.0, "Zap Drone in flight (loop): a small homemade electric buzz with a wobble.", loop=True),
    "hack_zap_hit": S(make_hack_zap_hit, -4.0, "Each of the drone's zaps: a sharp crackle snap with a clean transient (code pitches it up a little on bonus targets)."),
    "hack_emp": S(make_hack_emp, -2.0, "EMP cast and pulse: a fast charge inhale, a deep round whump, crackle spreading out in a ring."),
    "hack_emp_hit": S(make_hack_emp_hit, -5.0, "Enemy knocked back or stunned by the EMP: a short electric clunk plus a power-down fizz."),
    "hack_overclock_link": S(make_hack_overclock_link, -4.0, "Overclock takes a machine: data-burst chirps, a lock-in click, a rising tone. The most hacker sound Red has."),
    "hack_overclock_loop": S(make_hack_overclock_loop, -18.0, "Under a hijacked machine for its 10 s (loop): a quiet cyan whine with a soft pulse.", loop=True),
    "hack_overclock_end": S(make_hack_overclock_end, -6.0, "The link drops: a descending blip and a fizz."),
    "hack_reboot": S(make_hack_reboot, -3.0, "Reboot: a power-down click, a hair of silence, then a warm rising boot-up chord with a chime."),
    "hack_battery_full": S(make_hack_battery_full, -12.0, "Battery full: a tiny bright satisfied chime. Quiet, it happens a lot."),
    "hack_denied": S(make_hack_denied, -9.0, "Hack refused (not enough charge, or no signal): a dry double blip that says no without scolding."),
    "hack_locked": S(make_hack_locked, -5.0, "Quiet Hours locks the hacks (jam/lockout fizz): static clamping down, ending in a dry clamp click."),
    "hack_unlocked": S(make_hack_unlocked, -8.0, "Hacks come back after Quiet Hours: a clean click-ping."),
    "hack_target_door": S(make_hack_target_door, -5.0, "Fuse-box gate zaps open: a spark, a clunk, the gate grinding open, a last thunk."),
    "hack_target_crane_loop": S(make_hack_target_crane_loop, -14.0, "Hijacked crane moving (loop): hydraulic groan and chain rattle.", loop=True),
    "hack_target_line_off": S(make_hack_target_line_off, -6.0, "A drone line shuts down: a power-down whine and a last rotor dying."),
    "hack_target_terminal": S(make_hack_target_terminal, -8.0, "A terminal is used: a fussy Signals beep-chirp."),
    # --- boss patterns (rows 89 to 97, plus the topple from row 23)
    "boss_stomp_windup": S(make_boss_stomp_windup, -5.0, "Leg Stomp telegraph: a rising servo whine and an electric charge hum, ending on ratchet ticks."),
    "boss_stomp_ring": S(make_boss_stomp_ring, -2.0, "Leg Stomp slam and shock ring: a heavy clank, then a crackling ring travelling outward."),
    "boss_sweep_line": S(make_boss_sweep_line, -12.0, "Dish Sweep line crawling (loop): a thin rising tone with a scanning tick-tick-tick.", loop=True),
    "boss_sweep_beam": S(make_boss_sweep_beam, -7.0, "Dish Sweep beam (loop): a thick buzzing roar.", loop=True),
    "boss_drone_drop": S(make_boss_drone_drop, -4.0, "Drone Drop: a hatch clank, a pneumatic hiss, three rotor spin-ups."),
    "boss_quiet_hours": S(make_boss_quiet_hours, -4.0, "Quiet Hours: the dish hums, a rising whine into a static burst."),
    "boss_quiet_hours_cut": S(make_boss_quiet_hours_cut, -4.0, "Hitting the dish cuts Quiet Hours short: the whine collapsing downward with a pop."),
    "boss_relay_break": S(make_boss_relay_break, -4.0, "A relay box bursts: a pop, a spark shower, a dying status beep."),
    "boss_topple": S(make_boss_topple, -1.0, "The Hushmaster topples: servo groans sagging, metal impacts, then the full crash with a rumble tail. NEW id, not in the first brief (row 23's full crash)."),
    "boss_jack_in": S(make_boss_jack_in, -1.0, "Red jacks into the dish: a data-dive whoosh, a rising digital roar, then a huge hit. The payoff of phase 1."),
    "boss_kasp_whistle": S(make_boss_kasp_whistle, -6.0, "Kasp's whistle: a shrill, slightly wet referee whistle. Comic and officious."),
    # --- the junk mech (rows 98 to 106, plus ids the data and design asked for)
    "mech_assemble": S(make_mech_assemble, -2.0, "The scrap rises and locks together round Kasp: magnetic hum, scraping, dozens of clamps, a huge final clamp, the floodlight switching on."),
    "scale_switch": S(make_scale_switch, -4.0, "Scale shift from Red to the colossus: a deep air swell and a low boom underneath the docking sounds."),
    "mech_step": S(make_mech_step, -1.0, "Junk mech footfall: a boom plus a shower of rattling scrap."),
    "mech_idle_loop": S(make_mech_idle_loop, -14.0, "Under the mech (loop): creaking metal, flapping sheets, a rough diesel.", loop=True),
    "mech_telegraph": S(make_mech_telegraph, -2.0, "Every junk mech wind-up: a long low horn blast with scrap rattle. Cold, readable from 75 m."),
    "mech_sting_windup": S(make_mech_sting_windup, -4.0, "Sting when a mech attack starts (junk_mech.json sting_at_start): a short low horn swell with a rattle. NEW id from the data."),
    "mech_sting_lock": S(make_mech_sting_lock, -3.0, "Sting when the mech's aim locks (junk_mech.json sting_at_lock): a sharp metallic double stab. NEW id from the data."),
    "mech_swing": S(make_mech_swing, -3.0, "Mech arm swing (Scrap Swing): a low slow whoosh with debris."),
    "mech_slam": S(make_mech_slam, 0.0, "Mech slam (Wrecking Drop): the biggest impact in the slice, a ground-shaking boom and a scrap avalanche."),
    "mech_barrage": S(make_mech_barrage, -3.0, "Scrap Barrage: a run of launch thunks, each with a whoosh and clatter. NEW id (the fourth attack)."),
    "mech_roar": S(make_mech_roar, -2.0, "Mech roar (core reveal, last stand): a huge grinding metal growl with steam. NEW id."),
    "mech_plate_break": S(make_mech_plate_break, -1.0, "An armour plate tears off and falls: a shrieking tear then a long falling crash."),
    "mech_core_hit": S(make_mech_core_hit, -4.0, "A hit on the exposed core: a hollow metal bong, a crack and a zap. NEW id."),
    "mech_core_alarm": S(make_mech_core_alarm, -10.0, "Core exposed, Kasp's cockpit alarms (loop): panicky Signals beeps over a pulsing low tone.", loop=True),
    "mech_defeat": S(make_mech_defeat, -1.0, "The mech collapses into a junk pile: an avalanche, a last clang, then one tin can rolling to a stop."),
    # --- robots (rows 70 to 75 and 107 to 111)
    "robot_step_small": S(make_robot_step_small, -5.0, "Loader's foot: a heavy metal clomp on grating, thud plus servo whine."),
    "robot_step_huge": S(make_robot_step_huge, -2.0, "Colossus's foot: a low slow boom with a rolling tail and distant debris."),
    "robot_hatch": S(make_robot_hatch, -7.0, "Loader's hatch (and hop-in jet puff): pneumatic hiss, rusty hinge clunk, latch."),
    "robot_bay_doors": S(make_robot_bay_doors, -4.0, "Colossus's chest doors: a huge servo groan with a grind and a klaxon blip."),
    "robot_dock_clank": S(make_robot_dock_clank, -2.0, "Loader snaps into the bay: one hard clank and ring, then a low clamp thunk 0.6 s later."),
    "robot_power_up": S(make_robot_power_up, -3.0, "Robot powers on: a rising electric hum, furnace roar, three relay ticks."),
    "robot_servo_small_loop": S(make_robot_servo_small_loop, -17.0, "Loader idling and moving (loop): a chunky servo hum with a rattle.", loop=True),
    "robot_servo_huge_loop": S(make_robot_servo_huge_loop, -15.0, "Colossus idling and moving (loop): a deep hydraulic groan and slow machine breathing.", loop=True),
    "robot_swing_huge": S(make_robot_swing_huge, -4.0, "Colossus's arm swing: a huge low whoosh pushing air."),
    "robot_hit_huge": S(make_robot_hit_huge, -1.0, "Colossus's fist lands on the junk mech: metal crunching into scrap, a boom, falling debris."),
    "robot_smash_scrap": S(make_robot_smash_scrap, -5.0, "Loader smashes scrap, props, cops and drones: a crunchy metal crash with bits scattering (variant A)."),
    "robot_smash_scrap_2": S(make_robot_smash_scrap_2, -5.0, "Loader smash, variant B (a bit more boom)."),
    "robot_smash_scrap_3": S(make_robot_smash_scrap_3, -5.0, "Loader smash, variant C (a bit more clatter)."),
    # --- ambience (rows 112 to 115; Ross: the market is LOUD and cheerful). Loops at 22.05 kHz.
    "amb_market_night": S(make_amb_market_night, -9.0, "Night market bed (loop): LOUD and cheerful chatter with laughs, a sizzling wok, a cart bell, string-light hum, a far PA.", loop=True, rate=LOW_RATE),
    "amb_market_music": S(make_amb_market_music, -13.0, "Music leaking from a stall's speaker stack (loop, positional): a cheerful tinny tune.", loop=True, rate=LOW_RATE),
    "amb_market_radio": S(make_amb_market_radio, -14.0, "A chatty counter radio (loop, positional): static, a babbling presenter, a jingle's bleeps.", loop=True, rate=LOW_RATE),
    "amb_market_arcade": S(make_amb_market_arcade, -12.0, "The bootleg arcade (loop, positional): original cabinet bleeps, coins, zips and a win jingle.", loop=True, rate=LOW_RATE),
    "amb_market_noodles": S(make_amb_market_noodles, -13.0, "The noodle cart (loop, positional): wok sizzle, ladle, chopper, bubbling pot, cart bell.", loop=True, rate=LOW_RATE),
    "amb_market_charger": S(make_amb_market_charger, -15.0, "Grandma's charging stall (loop, positional): mains hum, fan, charge-up pings, a hummed tune.", loop=True, rate=LOW_RATE),
    "amb_market_chimes": S(make_amb_market_chimes, -15.0, "Wind chimes on the tarp poles (loop, positional): bright random bells in a breeze.", loop=True, rate=LOW_RATE),
    "amb_market_drones": S(make_amb_market_drones, -9.0, "The kids' scrap drones whizzing past (one-shot, positional)."),
    "amb_market_patrol": S(make_amb_market_patrol, -9.0, "A Signals patrol passes (one-shot, 9 s): boots in step, a radio squawk, one whistle."),
    "amb_junkyard": S(make_amb_junkyard, -12.0, "Junkyard bed (loop): wind over metal, creaks, far chains, a far crusher, settling scrap, a distant drone. Grim and lonely.", loop=True, rate=LOW_RATE),
    # --- music stand-ins (loops on the Music bus). Ids mirror the "music" keys in data (market,
    # battle_regular, battle_tough, battle_boss); AudioManager.play_music() accepts either spelling.
    "music_market": S(_music_builder("music_market"), -14.0, "Music stand-in, night market (rooms.json 'market'): sunny, bouncy, major, ~16.6 s loop. Original tune. Feels like a Mega Man Legends town theme.", loop=True, bus="Music", rate=LOW_RATE),
    "music_battle_regular": S(_music_builder("music_battle_regular"), -13.0, "Music stand-in, regular fight ('battle_regular'): hot, driving E minor at 156 BPM, ~12.3 s loop.", loop=True, bus="Music", rate=LOW_RATE),
    "music_battle_tough": S(_music_builder("music_battle_tough"), -13.0, "Music stand-in, tough fight ('battle_tough'): faster and tenser, A phrygian at 166 BPM, ~11.6 s loop.", loop=True, bus="Music", rate=LOW_RATE),
    "music_battle_boss": S(_music_builder("music_battle_boss"), -13.0, "Music stand-in, boss fight ('battle_boss'): pompous brass march at 148 BPM, ~13 s loop.", loop=True, bus="Music", rate=LOW_RATE),
    "music_hushmaster": S(_music_builder("music_hushmaster"), -13.0, "Music stand-in, Kasp and the Hushmaster (phase 1): bureaucratic staccato march at 140 BPM, ~13.7 s loop. NEW id.", loop=True, bus="Music", rate=LOW_RATE),
    "music_junk_mech": S(_music_builder("music_junk_mech"), -13.0, "Music stand-in, the junk mech (phase 2): heavy lurching C minor chug at 132 BPM, ~14.5 s loop. NEW id.", loop=True, bus="Music", rate=LOW_RATE),
}

# Anything that answers a press or lands a hit must start loud in its first 10 ms (the test checks it).
TRANSIENT_IDS = (
    "hack_zap_cast", "hack_zap_hit", "hack_emp", "hack_emp_hit", "hack_overclock_link", "hack_overclock_end",
    "hack_reboot", "hack_battery_full", "hack_denied", "hack_unlocked", "hack_target_door", "hack_target_terminal",
    "boss_stomp_ring", "boss_quiet_hours_cut", "boss_relay_break", "boss_topple_hit_unused",
    "mech_step", "mech_slam", "mech_core_hit", "mech_sting_lock", "mech_plate_break", "mech_swing_unused",
    "robot_step_small", "robot_dock_clank", "robot_hit_huge", "robot_smash_scrap", "robot_smash_scrap_2",
    "robot_smash_scrap_3", "robot_hatch",
)
TRANSIENT_IDS = tuple(i for i in TRANSIENT_IDS if i in SOUNDS)


# ---------------------------------------------------------------- output

def to_rate(x, rate):
    """Down-sample by an integer factor (a clean low-pass first). Only SR -> SR and SR -> SR/2."""
    if rate == SR:
        return x
    factor = SR // rate
    assert rate * factor == SR, "only integer down-sampling factors"
    x = lowpass(x, rate * 0.45)
    return x[::factor]


def write_wav_loop(path, samples, rate, loop):
    """16-bit mono WAV. Loops carry a 'smpl' chunk with one forward loop over the whole file, which
    Godot's importer (loop_mode 'Detect From WAV') reads."""
    pcm = np.clip(samples, -1.0, 1.0)
    data = (np.round(pcm * 32767.0)).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, rate, rate * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if len(data) % 2:
        chunks += b"\0"
    if loop:
        smpl = struct.pack("<IIIIIIIII", 0, 0, int(1e9 / rate), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<IIIIII", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    Path(path).write_bytes(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def render(sfx_id):
    spec = SOUNDS[sfx_id]
    samples = spec["build"](rng_for(sfx_id))
    return to_rate(samples, spec["rate"]), spec["rate"]


def write_json():
    """Append any slice ids missing from sfx.json. Existing entries are left exactly as they are."""
    doc = json.loads(SFX_JSON.read_text())
    added = []
    for sfx_id, spec in SOUNDS.items():
        if sfx_id in doc["sfx"]:
            continue
        doc["sfx"][sfx_id] = {
            "file": "res://audio/sfx/placeholder/%s.wav" % sfx_id,
            "bus": spec["bus"],
            "volume_db": spec["db"],
            "pitch_scale": 1.0,
            "loop": spec["loop"],
            "placeholder": True,
            "note": spec["note"],
        }
        added.append(sfx_id)
    if added:
        SFX_JSON.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    return added


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    total_bytes = 0
    for sfx_id, spec in SOUNDS.items():
        if only and sfx_id not in only:
            continue
        samples, rate = render(sfx_id)
        path = OUT_DIR / (sfx_id + ".wav")
        write_wav_loop(path, samples, rate, spec["loop"])
        total_bytes += path.stat().st_size
        peak = float(np.max(np.abs(samples)))
        early = float(np.max(np.abs(samples[: int(0.010 * rate)])))
        print("%-26s %5.2f s  %5d Hz  peak %.2f  first-10ms %.2f%s" % (sfx_id, len(samples) / rate, rate, peak, early, "  loop" if spec["loop"] else ""))
    print("wrote %.1f MB" % (total_bytes / 1e6))
    if "--write-json" in sys.argv:
        print("sfx.json: appended %s" % (write_json() or "nothing (all ids already present)"))


if __name__ == "__main__":
    main()
