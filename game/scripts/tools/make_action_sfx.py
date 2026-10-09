#!/usr/bin/env python3
"""Builds the PLACEHOLDER action-combat sound effects for LIGHTS ON (the combat sandbox).

numpy + Python standard library only. Everything is seeded, so running it twice gives
byte-identical files. It reuses the building blocks of make_battle_sfx.py (same folder).

    python3 game/scripts/tools/make_action_sfx.py                # write the WAVs
    python3 game/scripts/tools/make_action_sfx.py --write-json   # also append missing ids to sfx.json

Writes game/audio/sfx/placeholder/combat_*.wav   44.1 kHz, 16-bit, mono.
Existing entries in game/data/audio/sfx.json are never touched; --write-json only appends ids that
are not there yet (so it is safe to run again).

Feel targets (Ross, 2026-10-08; references Kingdom Hearts, Devil May Cry, Bayonetta):
  * Crunchy and fast. Every sound has a transient in its first 10 ms: a click, a crack or a thump,
    sometimes bit-crushed for grit. No soft fade-ins on anything that answers a button press.
  * Hits must feel powerful: low thump + mid body + bright crack, pushed into soft clipping.
  * The ten quickest sounds (swings, hits, dash, air dash, jump, land) fire constantly, so each is
    under 0.25 s (tests/unit/test_audio_action_sfx.gd enforces it).
  * Tone: grim world, loud heroes. Enemy and world sounds are cold, dry and metallic; Red's sounds
    (parry, Lamp Flare, Lights On, rank-up) are warm, bright and big.

Loudness plan: files are normalized, and volume_db in sfx.json sets the ladder. Light swings and
movement sit low (they fire constantly), hits and parries in the middle, the Lights On activation is
the loudest sound in the sandbox.

All sounds are synthesized from scratch (sines, filtered noise, simple envelopes) and imitate no
existing game. Real sounds are briefed in docs/audio_requests.md.
"""

import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from make_battle_sfx import (  # noqa: E402
    OUT_DIR, SFX_JSON, SR, TAU,
    bandpass, bell, burst, clank, clip, env_adsr, env_exp, finish, hz, n_of, osc, place,
    rng_for, saw, square, thump, white, write_wav,
)


# ---------------------------------------------------------------- extra building blocks

def crush(x, factor):
    """Cheap bit/rate crusher: hold every `factor`-th sample. Adds the crunchy grit."""
    idx = (np.arange(len(x)) // factor) * factor
    return x[idx]


def sweep_noise(rng, n, f0, f1, bands=10, spread=1.5):
    """Filtered noise whose centre frequency glides from f0 to f1 (a whoosh). Built from
    overlapping band-passed noise, each fading in and out around its moment in the sweep."""
    t = np.linspace(0.0, 1.0, n)
    centers = np.geomspace(f0, f1, bands)
    out = np.zeros(n)
    for i, c in enumerate(centers):
        pos = i / (bands - 1)
        w = np.exp(-(((t - pos) / (1.6 / bands)) ** 2))
        band = bandpass(white(rng, n), c / spread, min(c * spread, SR / 2 - 100))
        out += 0.4 * w * band / (np.std(band) + 1e-9)
    return out


def tick(rng, n, lo=2500, hi=16000, tau=0.003):
    """A very short click for the first few milliseconds: the transient."""
    return burst(rng, n, lo, hi, tau, 0.0001)


def rising_tone(n, f0, f1, harmonics=((1, 1.0),)):
    return osc(np.geomspace(f0, f1, n), n, harmonics)


# ---------------------------------------------------------------- swings

def make_swing_light(rng):
    """A fast thin slice of air: bright upward whoosh with a snick at the front. ~0.16 s."""
    n = n_of(0.16)
    x = sweep_noise(rng, n, 2200, 8000) * env_exp(n, 0.045, 0.005)
    x += 0.9 * tick(rng, n, 3000, 15000, 0.003)
    x += 0.25 * rising_tone(n, 900, 2600) * env_exp(n, 0.03, 0.003)
    return finish(clip(x, 1.1), 0.85, 0.02)


def make_swing_heavy(rng):
    """A big cleaving swoosh: lower, wider, with a weighty low push under it. ~0.23 s."""
    n = n_of(0.23)
    x = sweep_noise(rng, n, 500, 4200, spread=1.8) * env_exp(n, 0.075, 0.008)
    x += 0.7 * thump(n, 150, 55, 0.07)
    x += 0.8 * tick(rng, n, 1500, 10000, 0.004)
    x += 0.2 * rising_tone(n, 180, 700, ((1, 1.0), (2, 0.4))) * env_exp(n, 0.06, 0.004)
    return finish(clip(x, 1.4), 0.95, 0.025)


# ---------------------------------------------------------------- hits

def make_hit_light(rng):
    """A snappy crunchy smack with weight. Tuning v1.3 (Ross: chunky hits): a harder click up front, a low body thump under the
    old one so it lands in the chest and not just the ears, then the mid crack, gritted with a bit-crush. ~0.15 s."""
    n = n_of(0.15)
    x = 1.1 * tick(rng, n, 2500, 16000, 0.004)
    x += thump(n, 320, 95, 0.032) * 1.0
    x += 1.0 * thump(n, 150, 58, 0.055)
    x += 0.9 * burst(rng, n, 600, 7000, 0.016)
    x += 0.7 * burst(rng, n, 5000, 16000, 0.006)
    x += 0.35 * clank(rng, n, 760.0, 0.03)
    x = 0.65 * x + 0.35 * crush(x, 3)
    return finish(clip(x, 1.7), 0.92, 0.02)


def make_hit_heavy(rng):
    """The big meaty one. Tuning v1.3 (Ross: chunky hits): a harder crack and click at the very front, a deep sub boom under a
    thick body, a steel clank. Still under a quarter second. ~0.24 s."""
    n = n_of(0.24)
    x = 1.2 * tick(rng, n, 2000, 16000, 0.005)
    x += thump(n, 210, 42, 0.1) * 1.5
    x += 1.0 * thump(n, 90, 34, 0.12)
    x += 1.0 * burst(rng, n, 150, 5000, 0.06)
    x += 0.9 * burst(rng, n, 3000, 15000, 0.014)
    x += 0.5 * clank(rng, n, 390.0, 0.07)
    x = 0.7 * x + 0.3 * crush(x, 3)
    return finish(clip(x, 1.9), 0.98, 0.025)


def make_hit_launch(rng):
    """The launcher: a hard crack, then a rising whoosh-crack that shoots the enemy upward. ~0.24 s."""
    n = n_of(0.24)
    x = np.zeros(n)
    crack = thump(n_of(0.1), 260, 70, 0.04) + 0.9 * burst(rng, n_of(0.1), 400, 9000, 0.02)
    crack += 0.8 * tick(rng, n_of(0.1), 4000, 16000, 0.004)
    x = place(x, 0.0, crack * 1.3)
    rise = sweep_noise(rng, n, 500, 9000, spread=1.6) * (np.linspace(0.0, 1.0, n) ** 0.7) * env_exp(n, 0.2, 0.01)
    x += 0.8 * rise
    x += 0.5 * rising_tone(n, 260, 2200, ((1, 1.0), (2, 0.35))) * env_exp(n, 0.14, 0.004)
    x = 0.75 * x + 0.25 * crush(x, 2)
    return finish(clip(x, 1.6), 0.95, 0.03)


def make_hit_air(rng):
    """A hit on an airborne enemy: lighter, bouncier and brighter, a crisp pop with a ping. ~0.2 s."""
    n = n_of(0.2)
    x = thump(n, 480, 170, 0.028) * 0.8
    x += 0.9 * burst(rng, n, 1000, 10000, 0.02)
    x += 0.6 * tick(rng, n, 5000, 16000, 0.004)
    x += 0.5 * bell(1250.0, n, 0.1, (1.0, 2.0, 3.01), (1.0, 0.4, 0.2))
    x += 0.35 * rising_tone(n, 500, 1700) * env_exp(n, 0.04, 0.002)
    x = 0.7 * x + 0.3 * crush(x, 2)
    return finish(clip(x, 1.4), 0.88, 0.03)


# ---------------------------------------------------------------- parry

def make_parry(rng):
    """A bright metallic ring: blade on blade, crisp spark up front, ringing for ~0.7 s."""
    n = n_of(0.7)
    x = clank(rng, n, 1500.0, 0.3, shimmer=0.4)
    x += 0.6 * bell(hz(96), n, 0.4, (1.0, 2.0, 2.76), (1.0, 0.4, 0.3))
    x += 0.7 * tick(rng, n, 3000, 16000, 0.004)
    x += 0.5 * thump(n, 260, 110, 0.03)
    return finish(clip(x, 1.3), 0.92, 0.1)


def make_parry_perfect(rng):
    """A bigger ring plus a sparkle: heavier clang, a low thud for weight, a rising shower of
    high pings and an airy shimmer over the top. ~1.2 s."""
    n = n_of(1.2)
    x = clank(rng, n, 1250.0, 0.6, shimmer=0.7)
    x += 0.8 * bell(hz(93), n, 0.7, (1.0, 2.0, 2.76), (1.0, 0.45, 0.3))
    x += 0.9 * tick(rng, n, 2500, 16000, 0.005)
    x += 0.8 * thump(n, 220, 70, 0.07)
    for i, m in enumerate((96, 100, 103, 108, 112)):
        d = n_of(0.45)
        x = place(x, 0.04 + i * 0.045, bell(hz(m), d, 0.2, (1.0, 2.0), (1.0, 0.3)), 0.55)
    sh = n_of(0.7)
    x = place(x, 0.03, burst(rng, sh, 8000, 19000, 0.2, 0.002), 0.5)
    return finish(clip(x, 1.4), 1.0, 0.15)


# ---------------------------------------------------------------- movement

def make_dash(rng):
    """A short ground dash: a scuff of boot, then a whoosh. ~0.17 s."""
    n = n_of(0.17)
    x = sweep_noise(rng, n, 700, 4200) * env_exp(n, 0.055, 0.006)
    x += 0.8 * burst(rng, n, 200, 1800, 0.02)
    x += 0.7 * tick(rng, n, 2000, 12000, 0.003)
    x += 0.3 * thump(n, 170, 80, 0.03)
    return finish(clip(x, 1.2), 0.85, 0.025)


def make_air_dash(rng):
    """The dash in mid-air: thinner and brighter, a rising airy zip, no boot. ~0.2 s."""
    n = n_of(0.2)
    x = sweep_noise(rng, n, 1800, 9500, spread=1.7) * env_exp(n, 0.07, 0.006)
    x += 0.7 * tick(rng, n, 4000, 16000, 0.003)
    x += 0.35 * rising_tone(n, 600, 2800) * env_exp(n, 0.05, 0.004)
    x += 0.2 * osc(hz(100), n) * env_exp(n, 0.06, 0.004)
    return finish(clip(x, 1.1), 0.82, 0.03)


def make_jump(rng):
    """Push off the ground: a boot scuff, a little rising spring tone and a puff of air. ~0.18 s."""
    n = n_of(0.18)
    x = 0.9 * burst(rng, n, 150, 2500, 0.018)
    x += 0.6 * tick(rng, n, 2000, 10000, 0.003)
    x += 0.6 * rising_tone(n, 170, 480, ((1, 1.0), (2, 0.25))) * env_exp(n, 0.07, 0.003)
    x += 0.4 * sweep_noise(rng, n, 800, 3500) * env_exp(n, 0.06, 0.008)
    return finish(clip(x, 1.3), 0.8, 0.03)


def make_land(rng):
    """Boots on steel grating: a solid thump, a dusty scuff and a small metal tick. ~0.2 s."""
    n = n_of(0.2)
    x = thump(n, 150, 55, 0.055) * 1.2
    x += 0.8 * burst(rng, n, 100, 1800, 0.03)
    x += 0.5 * tick(rng, n, 1500, 9000, 0.004)
    x += 0.3 * clank(rng, n, 720.0, 0.035)
    x = 0.75 * x + 0.25 * crush(x, 3)
    return finish(clip(x, 1.7), 0.88, 0.03)


# ---------------------------------------------------------------- Lamp Flare and Lights On

def make_lamp_flare(rng):
    """The perfect-dodge trigger. A bright ping at the very front, a warm swell that blooms upward,
    and a low time-stretch 'thoom': a deep tone sagging down like the world slowing. ~1.5 s."""
    n = n_of(1.5)
    t = np.arange(n) / SR
    x = np.zeros(n)
    x = place(x, 0.0, bell(hz(96), n_of(0.5), 0.14, (1.0, 2.0, 3.01), (1.0, 0.5, 0.25)), 0.8)
    x = place(x, 0.0, tick(rng, n_of(0.06), 2500, 16000, 0.005), 0.8)
    # Warm swell: a bright major stack, fading in fast (0.18 s), blooming, then decaying slowly.
    swell_env = (1.0 - np.exp(-t / 0.09)) * np.exp(-t / 0.6)
    warm = np.zeros(n)
    for m, g in ((60, 1.0), (67, 0.8), (72, 0.8), (76, 0.7), (79, 0.6), (84, 0.45)):
        detune = 1.0 + 0.004 * np.sin(TAU * 0.7 * t + m)           # slow shimmer beating
        warm += g * osc(hz(m) * detune, n, ((1, 1.0), (2, 0.35), (3, 0.15)))
    x += 0.5 * warm * swell_env
    # Brightness opens up after the front: a rising airy glow.
    glow = sweep_noise(rng, n_of(0.9), 800, 11000, spread=1.6) * np.sin(np.pi * np.linspace(0, 1, n_of(0.9))) ** 1.4
    x = place(x, 0.02, glow, 0.35)
    # The thoom: a deep sine that sags in pitch and rings out, like a slowed-down heartbeat.
    thoom_n = n_of(1.3)
    tt = np.arange(thoom_n) / SR
    f = 30.0 + 62.0 * np.exp(-tt / 0.45)
    thoom = osc(f, thoom_n, ((1, 1.0), (2, 0.35))) * env_exp(thoom_n, 0.4, 0.004)
    x = place(x, 0.0, thoom, 1.5)
    return finish(clip(x, 1.3), 0.95, 0.2)


def make_lights_on_activate(rng):
    """Lights On: big and triumphant. A fast charge-up zip, a huge boom and cymbal crash, a wide
    stacked brass-like chord, a shower of bright pings and a long warm ring-out. ~2.4 s."""
    n = n_of(2.4)
    x = np.zeros(n)
    charge = 0.28
    cn = n_of(charge)
    zip_ = sweep_noise(rng, cn, 300, 12000, spread=1.8) * np.linspace(0.2, 1.0, cn) ** 1.5
    zip_ += 0.7 * rising_tone(cn, 130, 1400, ((1, 1.0), (2, 0.5), (3, 0.3))) * np.linspace(0.2, 1.0, cn)
    x = place(x, 0.0, zip_, 0.9)
    x = place(x, 0.0, tick(rng, n_of(0.05), 2500, 15000, 0.004), 0.7)       # instant transient
    # The impact at t = charge.
    x = place(x, charge, thump(n_of(1.4), 125, 30, 0.45), 1.7)
    x = place(x, charge, burst(rng, n_of(1.6), 4500, 19000, 0.5, 0.0004), 1.0)   # crash
    x = place(x, charge, burst(rng, n_of(0.8), 200, 5000, 0.12, 0.0004), 0.9)
    # The chord: a wide stack with doubled octaves, saw plus square for a brassy bite.
    chord_n = n_of(2.0)
    chord = np.zeros(chord_n)
    for m, g in ((43, 0.9), (55, 0.8), (62, 0.8), (67, 0.9), (71, 0.7), (74, 0.9), (79, 0.8), (83, 0.5)):
        chord += g * (saw(hz(m), chord_n, 14) * 0.55 + square(hz(m) * 1.003, chord_n, 7) * 0.45)
    x = place(x, charge, chord * env_adsr(chord_n, 0.003, 0.35, 0.55), 0.42)
    # A rising shower of bright pings (an original pentatonic run) over the ring-out.
    for i, m in enumerate((91, 95, 98, 103, 107, 110, 115)):
        x = place(x, charge + 0.1 + i * 0.065, bell(hz(m), n_of(0.7), 0.3, (1.0, 2.0), (1.0, 0.3)), 0.35)
    return finish(clip(x, 1.2), 1.0, 0.3)


def make_noise_rank_up(rng):
    """Noise rank up: a short punchy sting, five quick bright steps climbing a pentatonic scale
    (G4 B4 D5 G5 B5), the last one longer with a sparkle. ~0.55 s."""
    n = n_of(0.55)
    x = np.zeros(n)
    steps = (67, 71, 74, 79, 83)
    for i, m in enumerate(steps):
        last = i == len(steps) - 1
        d = n_of(0.3 if last else 0.12)
        note = square(hz(m), d, 6) * 0.5 + saw(hz(m), d, 8) * 0.4 + bell(hz(m + 12), d, 0.1) * 0.6
        env = env_exp(d, 0.2 if last else 0.05, 0.0006)
        x = place(x, i * 0.065, note * env, 0.75 + 0.1 * i)
    x = place(x, 0.0, tick(rng, n_of(0.03), 3000, 15000, 0.003), 0.6)
    x = place(x, 4 * 0.065, thump(n_of(0.2), 200, 80, 0.05), 0.8)
    x = place(x, 4 * 0.065, burst(rng, n_of(0.25), 6000, 17000, 0.08), 0.35)
    return finish(clip(x, 1.4), 0.9, 0.06)


# ---------------------------------------------------------------- lock-on and enemies

def make_lock_on(rng):
    """Targeting click-beep: a dry click then two quick rising square beeps. ~0.12 s."""
    n = n_of(0.12)
    x = 0.9 * tick(rng, n, 1500, 12000, 0.004)
    x = place(x, 0.0, square(1500.0, n_of(0.05), 5) * env_exp(n_of(0.05), 0.03, 0.0004), 0.6)
    x = place(x, 0.045, square(2250.0, n_of(0.075), 5) * env_exp(n_of(0.075), 0.035, 0.0004), 0.55)
    return finish(x, 0.7, 0.02)


def make_enemy_telegraph(rng):
    """Incoming attack warning: a sharp dissonant two-stab alarm (a tritone buzz that steps up),
    with a metal ping up front. Cold and urgent, nothing like the friendly lock-on beep. ~0.3 s."""
    n = n_of(0.3)
    x = np.zeros(n)
    for start, f, dur in ((0.0, 1480.0, 0.09), (0.11, 1960.0, 0.17)):
        d = n_of(dur)
        stab = pulse_buzz(f, d) + pulse_buzz(f * 1.414, d) * 0.8
        x = place(x, start, stab * env_adsr(d, 0.0006, dur * 0.55, 0.03), 0.7)
    x = place(x, 0.0, tick(rng, n_of(0.04), 2500, 16000, 0.004), 0.8)
    x = place(x, 0.0, bell(2800.0, n_of(0.25), 0.07, (1.0, 2.4), (1.0, 0.4)), 0.4)
    return finish(clip(x, 1.4), 0.85, 0.03)


def pulse_buzz(freq, n):
    """A harsh narrow pulse used for alarms."""
    return osc(freq, n, tuple((h, np.sin(np.pi * h * 0.2) / h) for h in range(1, 12)))


def make_enemy_death(rng):
    """An enemy breaks: a hard crack, a bit-crushed power-down sliding to the floor, a fizz of
    sparks and a last low thud. Cold and electrical, not gory. ~0.7 s."""
    n = n_of(0.7)
    x = np.zeros(n)
    crack = thump(n_of(0.2), 240, 60, 0.07) + 0.9 * burst(rng, n_of(0.2), 400, 9000, 0.04)
    crack += 0.8 * tick(rng, n_of(0.2), 3000, 16000, 0.005)
    x = place(x, 0.0, crack * 1.2)
    fall = saw(np.geomspace(700.0, 55.0, n_of(0.55)), n_of(0.55), 10) * env_adsr(n_of(0.55), 0.002, 0.08, 0.14)
    x = place(x, 0.0, crush(fall, 6), 0.55)
    fizz_n = n_of(0.5)
    fizz = burst(rng, fizz_n, 3000, 14000, 0.15, 0.003)
    pops = np.zeros(fizz_n)
    idx = rng.integers(0, fizz_n, size=40)
    pops[idx] = rng.uniform(-1.0, 1.0, len(idx)) * 4.0
    fizz = fizz * 0.6 + bandpass(pops, 1500, 14000) * env_exp(fizz_n, 0.18, 0.001)
    x = place(x, 0.04, crush(fizz, 2), 0.7)
    x = place(x, 0.28, thump(n_of(0.3), 110, 40, 0.1), 0.9)
    return finish(clip(x, 1.5), 0.92, 0.08)


def make_brute_slam(rng):
    """The Brute's overhead slam: a ground-shaking boom, a hard crack, a steel clang, a rumbling
    tail and a scatter of debris. The heaviest sound in the sandbox. ~1.0 s."""
    n = n_of(1.0)
    x = thump(n, 112, 26, 0.34) * 1.9
    x += 1.0 * burst(rng, n, 60, 2500, 0.18, 0.0006)
    x += 0.9 * burst(rng, n, 2000, 14000, 0.025, 0.0002)
    x += 0.6 * clank(rng, n, 210.0, 0.28)
    x += 0.5 * bandpass(white(rng, n), 30, 300) * env_exp(n, 0.4, 0.01)
    debris = np.zeros(n)
    idx = rng.integers(n_of(0.08), n_of(0.7), size=70)
    debris[idx] = rng.uniform(-1.0, 1.0, len(idx)) * 5.0
    x += 0.35 * bandpass(debris, 500, 9000) * env_exp(n, 0.3, 0.001)
    x = 0.75 * x + 0.25 * crush(x, 3)
    return finish(clip(x, 1.6), 1.0, 0.12)


# id -> (builder, volume_db, note for sfx.json). volume_db plans the loudness ladder.
SOUNDS = {
    "combat_swing_light": (make_swing_light, -11.0, "Light sword swing: a fast thin air-slice with a snick at the front. Fires constantly, so it sits low."),
    "combat_swing_heavy": (make_swing_heavy, -8.0, "Heavy sword swing: a big low cleaving swoosh with weight under it."),
    "combat_hit_light": (make_hit_light, -5.5, "Light hit: a snappy crunchy smack, thump plus crack."),
    "combat_hit_heavy": (make_hit_heavy, -2.0, "Heavy hit: deep thump, thick body, hard crack and a steel clank. Must feel powerful."),
    "combat_hit_launch": (make_hit_launch, -3.0, "Launcher hit: a hard crack then a rising whoosh-crack that sends the enemy up."),
    "combat_hit_air": (make_hit_air, -6.0, "Hit on an airborne enemy: lighter and bouncier, a crisp pop with a bright ping."),
    "combat_parry": (make_parry, -4.0, "Parry: a bright metallic ring, blade on blade."),
    "combat_parry_perfect": (make_parry_perfect, -1.0, "Perfect parry: a bigger ring with a low thud and a rising sparkle shower."),
    "combat_dash": (make_dash, -10.0, "Ground dash: a boot scuff and a short whoosh."),
    "combat_air_dash": (make_air_dash, -10.0, "Air dash: thinner and brighter than the ground dash, a rising airy zip."),
    "combat_jump": (make_jump, -9.0, "Jump: a push-off scuff, a little rising spring tone and a puff of air."),
    "combat_land": (make_land, -8.0, "Landing: a solid thump on steel grating with a dusty scuff."),
    "combat_lamp_flare": (make_lamp_flare, -2.0, "Lamp Flare (perfect dodge slow-mo trigger): bright ping, warm bright swell, and a low time-stretch thoom."),
    "combat_lights_on_activate": (make_lights_on_activate, 0.0, "Lights On activation: big and triumphant. Charge zip, boom, crash, wide brassy chord, sparkle shower. Loudest sound in the sandbox."),
    "combat_noise_rank_up": (make_noise_rank_up, -5.0, "Noise rank up: a short punchy sting, five quick steps rising."),
    "combat_lock_on": (make_lock_on, -10.0, "Lock-on: a dry click then two quick rising beeps."),
    "combat_enemy_telegraph": (make_enemy_telegraph, -4.0, "Enemy attack telegraph: a sharp dissonant two-stab warning with a metal ping. Cold and urgent."),
    "combat_enemy_death": (make_enemy_death, -5.0, "Enemy death: a hard crack, a bit-crushed power-down, a fizz of sparks and a last thud."),
    "combat_brute_slam": (make_brute_slam, -1.0, "Brute slam: heavy ground-shaking impact with a clang, rumble tail and debris."),
}

# The ten that fire constantly: each must stay under QUICK_MAX_SECONDS (the test enforces it).
QUICK_IDS = (
    "combat_swing_light", "combat_swing_heavy", "combat_hit_light", "combat_hit_heavy",
    "combat_hit_launch", "combat_hit_air", "combat_dash", "combat_air_dash", "combat_jump", "combat_land",
)
QUICK_MAX_SECONDS = 0.25


# ---------------------------------------------------------------- output

def write_json():
    """Append any combat ids missing from sfx.json. Existing entries are left exactly as they are."""
    doc = json.loads(SFX_JSON.read_text())
    added = []
    for sfx_id, (_, volume_db, note) in SOUNDS.items():
        if sfx_id in doc["sfx"]:
            continue
        doc["sfx"][sfx_id] = {
            "file": "res://audio/sfx/placeholder/%s.wav" % sfx_id,
            "bus": "SFX",
            "volume_db": volume_db,
            "pitch_scale": 1.0,
            "loop": False,
            "placeholder": True,
            "note": note,
        }
        added.append(sfx_id)
    if added:
        SFX_JSON.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
    return added


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for sfx_id, (builder, _, _) in SOUNDS.items():
        samples = builder(rng_for(sfx_id))
        write_wav(OUT_DIR / (sfx_id + ".wav"), samples)
        peak = float(np.max(np.abs(samples)))
        early = float(np.max(np.abs(samples[: n_of(0.010)])))
        seconds = len(samples) / SR
        flag = "  <-- TOO LONG for a quick sound" if sfx_id in QUICK_IDS and seconds >= QUICK_MAX_SECONDS else ""
        print("%-28s %5.2f s  peak %.2f  first-10ms peak %.2f%s" % (sfx_id, seconds, peak, early, flag))
    if "--write-json" in sys.argv:
        print("sfx.json: appended %s" % (write_json() or "nothing (all ids already present)"))


if __name__ == "__main__":
    main()
