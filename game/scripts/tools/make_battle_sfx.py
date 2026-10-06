#!/usr/bin/env python3
"""Builds the PLACEHOLDER battle sound effects for Lights Left On (Milestone 2).

numpy + Python standard library only. Everything is seeded, so running it twice gives
byte-identical files.

    python3 game/scripts/tools/make_battle_sfx.py                # write the WAVs
    python3 game/scripts/tools/make_battle_sfx.py --write-json   # also append missing ids to sfx.json

Writes game/audio/sfx/placeholder/battle_*.wav   44.1 kHz, 16-bit, mono.
The ids are the SFX ids in docs/battle_api.md. Existing entries in game/data/audio/sfx.json are
never touched; --write-json only appends ids that are not there yet.

Loudness plan (file peak plus volume_db in sfx.json): the cue is bright and loud-ish, the three
ratings climb nice < rad < totally_rad, and TOTALLY RAD is the loudest and splashiest sound in a
fight (design doc, "Battle system"). battle_ding has its peak inside the first ~10 ms because it
is the timing cue: a soft attack would feel late.

All sounds are synthesized from scratch (sines, filtered noise, simple envelopes). The victory
jingle is an original eight-note tune. They imitate no existing game; real sounds are briefed in
docs/audio_requests.md.
"""

import json
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
GAME_DIR = Path(__file__).resolve().parents[2]
OUT_DIR = GAME_DIR / "audio" / "sfx" / "placeholder"
SFX_JSON = GAME_DIR / "data" / "audio" / "sfx.json"
TAU = 2.0 * np.pi


# ---------------------------------------------------------------- building blocks

def rng_for(name):
    """A generator seeded from the sound's name, so each sound is stable on its own."""
    return np.random.default_rng(sum((i + 1) * ord(c) for i, c in enumerate(name)) + 7)


def n_of(seconds):
    return int(round(seconds * SR))


def ramp(n, a, b):
    return np.linspace(a, b, n)


def env_exp(n, tau, attack=0.0004):
    """Near-instant attack, then exponential decay with time constant `tau` seconds."""
    t = np.arange(n) / SR
    env = np.exp(-t / tau)
    a = max(1, int(attack * SR))
    env[:a] *= np.linspace(0.0, 1.0, a)
    return env


def env_adsr(n, attack, hold, tau):
    t = np.arange(n) / SR
    env = np.where(t < attack + hold, 1.0, np.exp(-(t - attack - hold) / tau))
    a = max(1, int(attack * SR))
    env[:a] *= np.linspace(0.0, 1.0, a)
    return env


def osc(freq, n, harmonics=((1, 1.0),), phase=0.0):
    """A sum of harmonics. `freq` is a number or an array of per-sample Hz (a pitch sweep)."""
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.asarray(freq, dtype=float)
    ph = TAU * np.cumsum(f) / SR + phase
    out = np.zeros(n)
    for h, amp in harmonics:
        out += amp * np.sin(h * ph)
    return out


def square(freq, n, count=9):
    return osc(freq, n, tuple((h, 1.0 / h) for h in range(1, 2 * count, 2)))


def pulse(freq, n, count=10):
    """A thin, nasal 25% pulse: all harmonics, shaped by sin(pi*h*duty)."""
    return osc(freq, n, tuple((h, np.sin(np.pi * h * 0.25) / h) for h in range(1, count + 1)))


def saw(freq, n, count=12):
    return osc(freq, n, tuple((h, 1.0 / h) for h in range(1, count + 1)))


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def white(rng, n):
    return rng.uniform(-1.0, 1.0, n)


def bandpass(x, lo, hi):
    """Brick-wall band filter by FFT (deterministic). lo=0 gives a low-pass, hi>=nyquist a high-pass."""
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / SR)
    spec[(freqs < lo) | (freqs > hi)] = 0.0
    return np.fft.irfft(spec, len(x))


def clip(x, drive=1.0):
    return np.tanh(x * drive)


def place(buf, start, part, gain=1.0):
    """Add `part` into `buf` at `start` seconds, growing the buffer if needed."""
    i = n_of(start)
    end = i + len(part)
    if end > len(buf):
        buf = np.concatenate([buf, np.zeros(end - len(buf))])
    buf[i:end] += part * gain
    return buf


def finish(x, peak, tail_fade=0.01):
    """Scale so the loudest sample hits `peak` (0..1), with a short fade at the very end only."""
    x = np.asarray(x, dtype=float)
    x = x / max(1e-9, np.max(np.abs(x))) * peak
    f = min(len(x), max(1, int(tail_fade * SR)))
    x[-f:] *= np.linspace(1.0, 0.0, f)
    return x


def thump(n, f0, f1, tau):
    """A sine that falls fast from f0 to f1: the body of a punch or slam."""
    t = np.arange(n) / SR
    freq = f1 + (f0 - f1) * np.exp(-t / (tau * 0.35))
    return osc(freq, n) * env_exp(n, tau, 0.0006)


def burst(rng, n, lo, hi, tau, attack=0.0004):
    return bandpass(white(rng, n), lo, hi) * env_exp(n, tau, attack)


def bell(freq, n, tau, ratios=(1.0, 2.0, 3.01), amps=(1.0, 0.5, 0.25)):
    out = np.zeros(n)
    for r, a in zip(ratios, amps):
        out += a * osc(freq * r, n) * env_exp(n, tau / (0.6 + 0.4 * r), 0.0004)
    return out


def clank(rng, n, base, tau, shimmer=0.0):
    """Metal on metal: inharmonic partials with fast decay, plus a tiny noise tick."""
    ratios = (1.0, 1.59, 2.14, 2.65, 3.43, 4.2)
    out = np.zeros(n)
    for i, r in enumerate(ratios):
        out += (1.0 / (1 + 0.4 * i)) * osc(base * r, n) * env_exp(n, tau / (1 + 0.25 * i), 0.0003)
    out += 0.6 * burst(rng, n, 2500, 14000, 0.012, 0.0002)
    if shimmer > 0.0:
        tt = np.arange(n) / SR
        out += shimmer * osc(base * 4.1, n) * (0.6 + 0.4 * np.sin(TAU * 11.0 * tt)) * env_exp(n, tau * 1.8, 0.001)
    return out


def static_wash(rng, n, rising):
    """Radio static: bands of hiss with a tuning sweep, plus sparse crackle pops."""
    t = np.linspace(0.0, 1.0, n)
    low = bandpass(white(rng, n), 300, 2200)
    mid = bandpass(white(rng, n), 2200, 6500)
    high = bandpass(white(rng, n), 6500, 16000)
    if rising:
        w_low, w_mid, w_high = (1 - t) ** 1.5, np.sin(np.pi * t), t ** 1.5
    else:
        w_low, w_mid, w_high = t ** 1.5, np.sin(np.pi * t), (1 - t) ** 1.5
    wash = low * w_low * 1.4 + mid * w_mid + high * w_high * 0.9
    pops = np.zeros(n)
    idx = rng.integers(0, n, size=max(8, n // 900))
    pops[idx] = rng.uniform(-1.0, 1.0, len(idx)) * 3.0
    pops = bandpass(pops, 800, 12000)
    return wash + pops * 0.8


# ---------------------------------------------------------------- the sounds

def make_ding(rng):
    """The Clutch cue. Bright, sharp, tiny. Full level from the first sample, peak inside ~2 ms."""
    n = n_of(0.16)
    x = osc(2637.0, n, ((1, 1.0), (2, 0.55), (3, 0.3))) * env_exp(n, 0.05, 0.0003)
    x += 0.7 * osc(3951.0, n) * env_exp(n, 0.03, 0.0003)
    x += 0.8 * burst(rng, n, 3000, 16000, 0.004, 0.0001)  # a tick of "click" at the front
    return finish(x, 0.9, 0.02)


def make_hit(rng):
    n = n_of(0.26)
    x = thump(n, 220, 70, 0.07) * 1.0
    x += 0.8 * burst(rng, n, 400, 5000, 0.035)
    x += 0.35 * burst(rng, n, 4000, 12000, 0.012)
    return finish(clip(x, 1.6), 0.8)


def make_hit_big(rng):
    n = n_of(0.55)
    x = thump(n, 170, 45, 0.16) * 1.3
    x += 0.9 * burst(rng, n, 200, 4500, 0.09)
    x += 0.5 * burst(rng, n, 3000, 14000, 0.03)
    x += 0.5 * clank(rng, n, 520.0, 0.12)
    return finish(clip(x, 2.2), 0.95)


def make_rating_nice(rng):
    """Two little bright bell notes, going up."""
    n = n_of(0.5)
    x = np.zeros(n)
    x = place(x, 0.0, bell(hz(84), n_of(0.35), 0.22))     # C6
    x = place(x, 0.09, bell(hz(91), n_of(0.38), 0.25))    # G6
    return finish(x, 0.5, 0.05)


def make_rating_rad(rng):
    """A quick rising three-note arpeggio with a sparkle on top. Fuller and louder than Nice."""
    n = n_of(0.75)
    x = np.zeros(n)
    for i, m in enumerate((72, 76, 79)):  # C5 E5 G5
        d = n_of(0.4)
        note = square(hz(m), d) * 0.55 + bell(hz(m + 12), d, 0.2) * 0.8
        x = place(x, i * 0.075, note * env_exp(d, 0.18, 0.0004))
    x = place(x, 0.2, burst(rng, n_of(0.3), 6000, 16000, 0.09), 0.45)
    return finish(clip(x, 1.4), 0.72, 0.06)


def make_rating_totally_rad(rng):
    """The loudest, splashiest sound in a fight: a big rising run, a stacked chord, a cymbal-like
    crash, a laser zip and a low boom underneath. Pushed into soft clipping on purpose."""
    n = n_of(1.3)
    x = np.zeros(n)
    run = (60, 64, 67, 72, 76, 79, 84)
    for i, m in enumerate(run):
        d = n_of(0.5)
        note = square(hz(m), d) * 0.5 + saw(hz(m), d) * 0.4 + bell(hz(m + 12), d, 0.25)
        x = place(x, i * 0.05, note * env_exp(d, 0.3, 0.0004), 0.8)
    t0 = 0.05 * len(run)
    chord_n = n_of(0.9)
    chord = np.zeros(chord_n)
    for m in (60, 67, 72, 76, 79, 84, 88):
        chord += (square(hz(m), chord_n) * 0.5 + saw(hz(m), chord_n) * 0.5) * 0.5
    x = place(x, t0, chord * env_adsr(chord_n, 0.0004, 0.12, 0.28), 1.0)
    x = place(x, 0.0, burst(rng, n_of(1.2), 5000, 18000, 0.38), 1.1)      # crash splash
    x = place(x, 0.0, burst(rng, n_of(0.9), 800, 5000, 0.2), 0.5)
    zip_n = n_of(0.3)
    zip_f = np.geomspace(300.0, 5200.0, zip_n)
    x = place(x, 0.0, osc(zip_f, zip_n) * env_exp(zip_n, 0.2, 0.002), 0.7)  # laser zip
    x = place(x, t0, thump(n_of(0.6), 110, 38, 0.25), 1.4)                 # boom
    return finish(clip(x, 1.5), 1.0, 0.12)


def make_block(rng):
    n = n_of(0.35)
    x = clank(rng, n, 640.0, 0.07) + 0.8 * thump(n, 160, 80, 0.04)
    return finish(clip(x, 1.3), 0.78)


def make_perfect_block(rng):
    n = n_of(0.95)
    x = clank(rng, n, 1250.0, 0.35, shimmer=0.6) + 0.5 * thump(n, 200, 90, 0.04)
    x += 0.4 * bell(hz(100), n, 0.5, (1.0, 2.0, 2.7), (1.0, 0.4, 0.3))   # a ringing "ting"
    return finish(clip(x, 1.2), 0.9, 0.08)


def make_payback(rng):
    """Perfect Block's ring, a quick whoosh back, then a punchy counter-hit."""
    n = n_of(0.8)
    x = np.zeros(n)
    x = place(x, 0.0, clank(rng, n_of(0.3), 1250.0, 0.12, shimmer=0.3), 0.8)
    whoosh = bandpass(white(rng, n_of(0.22)), 600, 7000) * np.sin(np.pi * np.linspace(0, 1, n_of(0.22))) ** 1.5
    x = place(x, 0.12, whoosh, 0.9)
    hit = thump(n_of(0.35), 230, 60, 0.09) + 0.8 * burst(rng, n_of(0.35), 400, 6000, 0.05)
    x = place(x, 0.3, hit * 1.3)
    x = place(x, 0.3, bell(hz(88), n_of(0.4), 0.2), 0.35)
    return finish(clip(x, 1.7), 0.88, 0.06)


def make_ko(rng):
    """The K.O. freeze-frame slam: a huge boom, a crash and a long rumbling tail."""
    n = n_of(1.5)
    x = thump(n, 130, 28, 0.55) * 1.6
    x += 0.8 * burst(rng, n, 100, 3000, 0.28)
    x += 0.7 * burst(rng, n, 3000, 16000, 0.12)
    x += 0.5 * clank(rng, n, 330.0, 0.25)
    x += 0.5 * osc(np.linspace(900.0, 120.0, n), n) * env_exp(n, 0.1, 0.002)  # a falling "zwoop"
    return finish(clip(x, 2.4), 0.98, 0.15)


def make_down(rng):
    """Down for the Count: a goofy descending 'bwomp' with a wobble and a dull thud."""
    n = n_of(0.75)
    t = np.arange(n) / SR
    f = 420.0 * np.exp(-t * 2.4) + 70.0
    f *= 1.0 + 0.03 * np.sin(TAU * 9.0 * t)
    x = (osc(f, n, ((1, 1.0), (2, 0.4), (3, 0.2))) * env_adsr(n, 0.002, 0.2, 0.12)) * 0.8
    x = place(x, 0.42, thump(n_of(0.3), 120, 50, 0.07) + 0.4 * burst(rng, n_of(0.3), 150, 1500, 0.04), 1.1)
    return finish(clip(x, 1.4), 0.8, 0.05)


def make_flee(rng):
    """A comic scramble: quick pattering footsteps that speed up, a rising zip and a puff."""
    n = n_of(1.0)
    x = np.zeros(n)
    t, gap = 0.0, 0.14
    i = 0
    while t < 0.7:
        step = burst(rng, n_of(0.05), 300 + 120 * (i % 2), 2500, 0.014) + 0.5 * thump(n_of(0.05), 260 + 80 * (i % 2), 150, 0.012)
        x = place(x, t, step, 0.9)
        t += gap
        gap = max(0.05, gap * 0.86)
        i += 1
    zip_n = n_of(0.35)
    zf = np.geomspace(250.0, 2400.0, zip_n)
    x = place(x, 0.55, osc(zf, zip_n, ((1, 1.0), (2, 0.3))) * env_exp(zip_n, 0.18, 0.004) * 0.5)
    x = place(x, 0.6, bandpass(white(rng, n_of(0.38)), 1200, 9000) * env_exp(n_of(0.38), 0.12, 0.01), 0.6)
    return finish(clip(x, 1.2), 0.7, 0.08)


def make_heal(rng):
    """Soft rising sparkles (a pentatonic run) with a warm shimmer under it."""
    n = n_of(0.9)
    x = np.zeros(n)
    for i, m in enumerate((72, 76, 79, 84, 88)):
        d = n_of(0.4)
        x = place(x, i * 0.07, (osc(hz(m), d, ((1, 1.0), (2, 0.25))) * env_exp(d, 0.18, 0.003)))
    d = n_of(0.8)
    tt = np.arange(d) / SR
    x = place(x, 0.0, (osc(hz(79), d) + osc(hz(84), d)) * 0.25 * (0.7 + 0.3 * np.sin(TAU * 7.0 * tt)) * env_adsr(d, 0.05, 0.2, 0.22))
    return finish(x, 0.6, 0.08)


def make_static_in(rng):
    """Radio static sweeping up, then a sharp snap into the fight."""
    n = n_of(0.75)
    x = static_wash(rng, n, True) * (np.linspace(0.15, 1.0, n) ** 1.2)
    x[-n_of(0.03):] *= 0.6
    snap_n = n_of(0.12)
    snap = burst(rng, snap_n, 800, 16000, 0.03, 0.0003) + 0.7 * thump(snap_n, 200, 80, 0.04)
    x = place(x, 0.7, snap, 1.8)
    return finish(clip(x, 1.1), 0.75, 0.04)


def make_static_out(rng):
    """The fight tunes out: a thump, then static whooshing away downward."""
    n = n_of(0.65)
    x = static_wash(rng, n, False) * (1.0 - np.linspace(0.0, 1.0, n)) ** 0.8
    x = place(x, 0.0, thump(n_of(0.14), 190, 70, 0.04) + 0.5 * burst(rng, n_of(0.14), 800, 14000, 0.02, 0.0003), 1.5)
    return finish(clip(x, 1.1), 0.75, 0.08)


def make_victory(rng):
    """~2 s original jingle in C major: a rising G arpeggio, a little turn, then a big held C chord.
    Pulse-wave lead, triangle-ish bass, snare-and-cymbal hits. Roughly 140 BPM."""
    beat = 60.0 / 140.0
    n = n_of(2.3)
    x = np.zeros(n)

    def lead(midi, start, beats, gain=1.0):
        d = n_of(beats * beat + 0.12)
        note = pulse(hz(midi), d) * 0.8 + osc(hz(midi + 12), d) * 0.15
        return place_note(midi, start, d, note, gain)

    def place_note(midi, start, d, note, gain):
        nonlocal x
        env = env_adsr(d, 0.003, max(0.0, d / SR - 0.14), 0.05)
        x = place(x, start, note * env, gain)

    melody = [(67, 0.0, 0.5), (71, 0.5, 0.5), (74, 1.0, 0.5), (79, 1.5, 0.5),   # G4 B4 D5 G5
              (81, 2.0, 0.25), (79, 2.25, 0.25), (76, 2.5, 0.5)]               # A5 G5 E5
    for midi, b0, ln in melody:
        lead(midi, b0 * beat, ln)
    final_start = 3.0 * beat
    final_n = n_of(1.3)
    chord = np.zeros(final_n)
    for m in (72, 76, 79, 84):  # C5 E5 G5 C6
        chord += pulse(hz(m), final_n) * 0.5 + osc(hz(m), final_n, ((1, 1.0), (2, 0.3))) * 0.3
    x = place(x, final_start, chord * env_adsr(final_n, 0.003, 0.5, 0.28), 0.9)
    for i, m in enumerate((48, 52, 55)):  # bass walk C3 E3 G3 into C2 landing
        bass_n = n_of(0.3)
        x = place(x, i * 2 * beat * 0.5 + 0.0, osc(hz(m - 12), bass_n, ((1, 1.0), (3, 0.1))) * env_exp(bass_n, 0.15, 0.002), 0.7)
    land_n = n_of(1.2)
    x = place(x, final_start, osc(hz(36), land_n, ((1, 1.0), (2, 0.2))) * env_adsr(land_n, 0.003, 0.4, 0.3), 0.9)
    x = place(x, final_start, burst(rng, n_of(1.1), 5000, 17000, 0.4), 0.7)    # cymbal
    x = place(x, final_start, burst(rng, n_of(0.2), 300, 6000, 0.06), 0.9)      # snare crack
    for b in (0.0, 1.0, 2.0):
        x = place(x, b * beat, thump(n_of(0.15), 150, 60, 0.05), 0.7)             # kick
        x = place(x, (b + 0.5) * beat, burst(rng, n_of(0.1), 2000, 9000, 0.03), 0.35)  # hat
    return finish(clip(x, 1.1), 0.85, 0.12)


def make_game_over(rng):
    """Comically deflated: four sagging 'wah' notes sliding down, the last one drooping away with a
    wobble, then a tiny pfft of air. Sad trombone energy, but cheerful about it."""
    notes = [(58, 0.0, 0.28), (57, 0.34, 0.28), (56, 0.68, 0.28), (55, 1.02, 0.85)]
    n = n_of(2.1)
    x = np.zeros(n)
    for i, (m, start, dur) in enumerate(notes):
        d = n_of(dur)
        t = np.arange(d) / SR
        last = i == len(notes) - 1
        f = np.full(d, hz(m))
        if last:
            f = f * (2.0 ** (-np.clip(t - 0.3, 0.0, None) * 0.42))   # the long droop
            f *= 1.0 + 0.025 * np.sin(TAU * 5.5 * t) * np.clip(t * 4, 0, 1)
        # "wah": a formant hump that opens then closes over each note
        fc = 500.0 + 700.0 * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.2
        ph = np.cumsum(f) / SR * TAU
        note = np.zeros(d)
        for h in range(1, 41):
            fh = f * h
            amp = (1.0 / h) * (0.12 + np.exp(-(((fh - fc) / 600.0) ** 2)))
            amp = np.where(fh < 9000.0, amp, 0.0)
            note += amp * np.sin(h * ph)
        env = env_adsr(d, 0.025, dur * 0.55, 0.12 if not last else 0.35)
        x = place(x, start, note * env, 1.0)
    x = place(x, 1.9 - 0.0, bandpass(white(rng, n_of(0.2)), 1500, 8000) * env_exp(n_of(0.2), 0.07, 0.01), 0.18)
    return finish(x, 0.6, 0.08)


def make_menu_open(rng):
    """Battle command menu pops open: a quick bright rising chirp and a tiny click."""
    n = n_of(0.17)
    f = np.geomspace(700.0, 1900.0, n)
    x = osc(f, n, ((1, 1.0), (2, 0.3))) * env_exp(n, 0.07, 0.002)
    x += 0.4 * burst(rng, n, 2500, 12000, 0.006, 0.0002)
    return finish(x, 0.5, 0.03)


# id -> (builder, volume_db, note for sfx.json). volume_db plans the loudness ladder.
SOUNDS = {
    "battle_ding": (make_ding, -3.0, "THE Clutch cue. Very short, sharp and bright; peak inside the first ~10 ms so the press never feels late."),
    "battle_hit": (make_hit, -6.0, "Basic hit: a chunky cartoon thump with a noisy crack."),
    "battle_hit_big": (make_hit_big, -4.0, "Big hit: heavier, longer thump and clank for boss and big-attack damage."),
    "battle_rating_nice": (make_rating_nice, -9.0, "Nice!: two small bright bell notes rising. Quietest of the three ratings."),
    "battle_rating_rad": (make_rating_rad, -6.0, "Rad!: a quick rising three-note arpeggio with sparkle. Louder and fuller than Nice."),
    "battle_rating_totally_rad": (make_rating_totally_rad, 0.0, "TOTALLY RAD!: loudest sound in a fight. Big rising run, stacked chord, crash splash, zip and boom."),
    "battle_block": (make_block, -6.0, "Blocked!: a solid metal clank."),
    "battle_perfect_block": (make_perfect_block, -4.0, "Perfect Block!: a ringing clank that sustains with a bright ting."),
    "battle_payback": (make_payback, -3.0, "Payback!: perfect-block ring, a whoosh, then a punchy counter-hit."),
    "battle_ko": (make_ko, -2.0, "K.O. freeze-frame slam: huge boom, crash and a rumbling tail (~1.5 s)."),
    "battle_down": (make_down, -5.0, "Down for the Count: a goofy descending bwomp, wobble and dull thud."),
    "battle_flee": (make_flee, -6.0, "Run away: comic scramble of quick footsteps speeding up, a zip and a puff."),
    "battle_heal": (make_heal, -7.0, "Heal: soft rising sparkles over a warm shimmer."),
    "battle_static_in": (make_static_in, -5.0, "Fight starts: radio static sweeping up into a sharp snap."),
    "battle_static_out": (make_static_out, -5.0, "Fight ends: a thump then radio static whooshing away."),
    "battle_victory": (make_victory, -4.0, "Victory jingle (~2 s): original rising arpeggio, little turn, big held C chord with a cymbal."),
    "battle_game_over": (make_game_over, -5.0, "Game over: four sagging 'wah' notes and a long comic droop. Deflated, not grim."),
    "battle_menu_open": (make_menu_open, -9.0, "Battle command menu opens: tiny bright rising chirp."),
}


# ---------------------------------------------------------------- output

def write_wav(path, samples):
    pcm = np.clip(samples, -1.0, 1.0)
    data = (np.round(pcm * 32767.0)).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


def write_json():
    """Append any battle ids missing from sfx.json. Existing entries are left exactly as they are."""
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
        rms = float(np.sqrt(np.mean(samples ** 2)))
        print("%-28s %5.2f s  peak %.2f  rms %.3f" % (sfx_id, len(samples) / SR, peak, rms))
    if "--write-json" in sys.argv:
        print("sfx.json: appended %s" % (write_json() or "nothing (all ids already present)"))


if __name__ == "__main__":
    main()
