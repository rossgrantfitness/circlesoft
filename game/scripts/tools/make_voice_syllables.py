#!/usr/bin/env python3
"""Builds the PLACEHOLDER gibberish-voice syllables and UI/gesture SFX for Lights Left On.

Pure Python 3 standard library (no numpy, no Blender). Everything is seeded, so running it
twice gives byte-identical files.

    python3 game/scripts/tools/make_voice_syllables.py

Reads  game/data/audio/voices.json   (the "timbres" block: folder name and reference pitch)
Writes game/audio/voice/<timbre>/<syllable>.wav        22.05 kHz, 16-bit, mono, ~30-120 ms
       game/audio/sfx/placeholder/<name>.wav            22.05 kHz, 16-bit, mono

How the voice works (the game side is scripts/audio/gibberish_voice.gd + audio_manager.gd):
each timbre has one small bank of syllables recorded at that timbre's reference pitch. The game
picks a syllable per typed letter and shifts it to the speaker's pitch with pitch_scale.
  v_a v_e v_i v_o v_u   vowels: a stack of harmonics shaped by two vocal-tract "formant" humps
  c_plosive             p/b/t/d/k/g: a tiny noise click, then a short neutral vowel
  c_nasal               m/n: a closed-mouth hum
  c_fricative           f/s/z/h: a hiss with a short voiced tail
  c_liquid              l/r/w/y: a vowel that slides between two mouth shapes
  i_rise                the "?" inflection: pitch swoops up
  i_punch               the "!" inflection: a loud, short, falling accent
The sounds are synthesized from scratch (additive harmonics + formant humps + seeded noise);
they imitate no existing game. They are placeholders: final voices are TBD (docs/audio_requests.md).
"""

import json
import math
import random
import struct
import sys
import wave
from pathlib import Path

SAMPLE_RATE = 22050
PEAK = 0.85
GAME_DIR = Path(__file__).resolve().parents[2]
VOICES_JSON = GAME_DIR / "data" / "audio" / "voices.json"
VOICE_OUT = GAME_DIR / "audio" / "voice"
SFX_OUT = GAME_DIR / "audio" / "sfx" / "placeholder"

# Vowel mouth shapes: (formant 1 Hz, formant 2 Hz).
VOWELS = {"a": (800, 1250), "e": (520, 1900), "i": (300, 2300), "o": (500, 900), "u": (330, 800)}
SCHWA = (500, 1500)

# Per-timbre character. harm: harmonic amplitude by number. dur: length multiplier.
# vib: (rate Hz, depth) pitch wobble. jitter: random pitch drift. trem: (rate Hz, depth) loudness flutter.
# nasal: extra formant hump (Hz, gain). bw: formant width multiplier. chirp: opening pitch flick.
# droop: pitch fall over the syllable, in octaves.
TIMBRES = {
    "round": dict(harm=lambda h: 1.0 / h ** 1.8, dur=1.15, vib=(5.0, 0.004), jitter=0.0, trem=None,
                  nasal=None, bw=1.0, chirp=0.0, droop=0.0, attack=0.009),
    "chirp": dict(harm=lambda h: abs(math.sin(math.pi * h * 0.25)) / h, dur=0.7, vib=None, jitter=0.0,
                  trem=None, nasal=None, bw=1.2, chirp=0.12, droop=0.0, attack=0.002),
    "creak": dict(harm=lambda h: 1.0 / h ** 0.95, dur=1.0, vib=(4.0, 0.012), jitter=0.035,
                  trem=(31.0, 0.45), nasal=None, bw=0.9, chirp=0.0, droop=0.05, attack=0.006),
    "honk": dict(harm=lambda h: 1.0 / h ** 0.8, dur=0.95, vib=None, jitter=0.004, trem=None,
                 nasal=(1150, 1.6), bw=0.7, chirp=0.0, droop=0.0, attack=0.003),
    "prim": dict(harm=lambda h: {1: 1.0, 2: 0.5, 3: 0.35, 5: 0.15}.get(h, 0.0), dur=0.6, vib=None,
                 jitter=0.0, trem=None, nasal=None, bw=1.0, chirp=0.03, droop=0.0, attack=0.002),
    "smooth": dict(harm=lambda h: (1.0 / h ** 2.0) if h % 2 == 1 else 0.05 / h, dur=1.05, vib=(5.5, 0.012),
                   jitter=0.0, trem=None, nasal=None, bw=1.1, chirp=0.0, droop=0.09, attack=0.008),
    "plain": dict(harm=lambda h: (1.0 / h) if h % 2 == 1 else 0.0, dur=0.9, vib=None, jitter=0.0,
                  trem=None, nasal=None, bw=1.0, chirp=0.0, droop=0.0, attack=0.004),
}

SYLLABLES = ["v_a", "v_e", "v_i", "v_o", "v_u", "c_plosive", "c_nasal", "c_fricative", "c_liquid",
             "i_rise", "i_punch"]


# ---------------------------------------------------------------- synthesis helpers

def lerp(a, b, t):
    return a + (b - a) * t


def formant_gain(freq, formants, nasal, bw_mult):
    """Loudness of a harmonic at `freq`: the sum of a few bell-shaped humps (the formants)."""
    total = 0.04
    for centre, gain, width in formants:
        d = (freq - centre) / (width * bw_mult)
        total += gain * math.exp(-0.5 * d * d)
    if nasal is not None:
        d = (freq - nasal[0]) / 160.0
        total += nasal[1] * math.exp(-0.5 * d * d)
    return total


def voiced(rng, dur, f0, shape, formants_at, pitch_at, env):
    """Renders `dur` seconds of a buzzing voice. shape is a TIMBRES entry."""
    n = int(dur * SAMPLE_RATE)
    out = [0.0] * n
    phase = 0.0
    drift = 0.0
    block = 24
    gains = []
    harm_count = 1
    for i in range(n):
        x = i / n
        sec = i / SAMPLE_RATE
        hz = f0 * pitch_at(x)
        hz *= 2.0 ** (-shape["droop"] * x)
        if shape["chirp"]:
            hz *= 1.0 + shape["chirp"] * math.exp(-sec / 0.012)
        if shape["vib"]:
            hz *= 1.0 + shape["vib"][1] * math.sin(2 * math.pi * shape["vib"][0] * sec)
        if shape["jitter"]:
            drift = drift * 0.92 + rng.uniform(-1, 1) * shape["jitter"]
            hz *= 1.0 + drift
        phase += hz / SAMPLE_RATE
        if i % block == 0:
            harm_count = max(1, min(48, int(9500.0 / hz)))
            forms = formants_at(x)
            gains = []
            for h in range(1, harm_count + 1):
                a = shape["harm"](h)
                if a > 0.0:
                    a *= formant_gain(h * hz, forms, shape["nasal"], shape["bw"])
                gains.append(a)
        s = 0.0
        for h, a in enumerate(gains, 1):
            if a > 0.0:
                s += a * math.sin(2 * math.pi * h * phase)
        amp = env(sec)
        if shape["trem"]:
            amp *= 1.0 - shape["trem"][1] * (0.5 + 0.5 * math.sin(2 * math.pi * shape["trem"][0] * sec))
        out[i] = s * amp
    return out


def hiss(rng, dur, env, bright=0.92):
    """High-passed noise (a hiss or a click, depending on the envelope)."""
    n = int(dur * SAMPLE_RATE)
    out = []
    prev = 0.0
    for i in range(n):
        x = rng.uniform(-1, 1)
        out.append((x - prev * bright) * env(i / SAMPLE_RATE))
        prev = x
    return out


def adsr(attack, decay_rate):
    def env(sec):
        if sec < attack:
            return sec / attack
        return math.exp(-decay_rate * (sec - attack))
    return env


def mix_into(base, extra, offset=0, gain=1.0):
    need = offset + len(extra)
    if need > len(base):
        base.extend([0.0] * (need - len(base)))
    for i, v in enumerate(extra):
        base[offset + i] += v * gain


def normalise(samples, peak=PEAK):
    top = max(abs(v) for v in samples) or 1.0
    k = peak / top
    return [v * k for v in samples]


def fade_tail(samples, ms=4.0):
    n = max(1, int(ms / 1000.0 * SAMPLE_RATE))
    n = min(n, len(samples))
    for i in range(n):
        samples[-1 - i] *= i / n
    return samples


def write_wav(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(frames)


# ---------------------------------------------------------------- voice syllables

def make_syllable(timbre_name, syllable, ref_hz):
    shape = TIMBRES[timbre_name]
    rng = random.Random("%s/%s" % (timbre_name, syllable))
    k = shape["dur"]
    atk = shape["attack"]
    steady = lambda x: 1.0

    def fixed(f1, f2):
        return lambda x: [(f1, 1.0, 130), (f2, 0.55, 260)]

    if syllable.startswith("v_"):
        f1, f2 = VOWELS[syllable[2]]
        out = voiced(rng, 0.085 * k, ref_hz, shape, fixed(f1, f2), steady, adsr(atk, 14.0))
    elif syllable == "c_plosive":
        click = hiss(rng, 0.012, adsr(0.0005, 330.0), 0.6)
        tail = voiced(rng, 0.06 * k, ref_hz, shape, fixed(*SCHWA), steady, adsr(atk, 24.0))
        out = [0.0] * len(tail)
        mix_into(out, tail, 0, 1.0)
        mix_into(out, click, 0, 1.4)
    elif syllable == "c_nasal":
        out = voiced(rng, 0.095 * k, ref_hz, shape,
                     lambda x: [(270, 1.3, 70), (1000, 0.18, 200)], steady, adsr(0.010, 9.0))
    elif syllable == "c_fricative":
        wash = hiss(rng, 0.05, adsr(0.004, 38.0), 0.96)
        tail = voiced(rng, 0.045 * k, ref_hz, shape, fixed(*SCHWA), steady, adsr(0.012, 30.0))
        out = [0.0] * (len(wash) + len(tail) // 2)
        mix_into(out, wash, 0, 0.9)
        mix_into(out, tail, int(0.03 * SAMPLE_RATE), 0.9)
    elif syllable == "c_liquid":
        out = voiced(rng, 0.085 * k, ref_hz, shape,
                     lambda x: [(lerp(350, 650, x), 1.0, 130), (lerp(800, 1400, x), 0.55, 260)],
                     lambda x: lerp(0.93, 1.05, x), adsr(atk, 12.0))
    elif syllable == "i_rise":
        out = voiced(rng, 0.12 * k, ref_hz, shape,
                     lambda x: [(lerp(800, 520, x), 1.0, 130), (lerp(1250, 1900, x), 0.55, 260)],
                     lambda x: lerp(0.85, 1.65, x ** 1.4), adsr(atk, 6.0))
    elif syllable == "i_punch":
        body = voiced(rng, 0.075 * k, ref_hz, shape, fixed(*VOWELS["o"]),
                      lambda x: lerp(1.3, 0.95, min(1.0, x * 2.0)), adsr(0.001, 22.0))
        click = hiss(rng, 0.008, adsr(0.0003, 500.0), 0.7)
        out = list(body)
        mix_into(out, click, 0, 1.2)
    else:
        raise ValueError(syllable)
    return fade_tail(normalise(out))


def build_voices():
    doc = json.loads(VOICES_JSON.read_text())
    count = 0
    for name, info in doc["timbres"].items():
        if name not in TIMBRES:
            sys.exit("voices.json timbre '%s' has no recipe in make_voice_syllables.py" % name)
        for syl in SYLLABLES:
            write_wav(VOICE_OUT / info["dir"] / (syl + ".wav"), make_syllable(name, syl, float(info["ref_hz"])))
            count += 1
    print("voice syllables: %d files in %s" % (count, VOICE_OUT))


# ---------------------------------------------------------------- placeholder SFX

def tone(freqs, dur, wave_kind="sine", decay=18.0, attack=0.002, glide=None):
    """One note. glide = end frequency (linear slide)."""
    n = int(dur * SAMPLE_RATE)
    out = []
    phase = 0.0
    env = adsr(attack, decay)
    for i in range(n):
        x = i / n
        hz = freqs if glide is None else lerp(freqs, glide, x)
        phase += hz / SAMPLE_RATE
        if wave_kind == "sine":
            s = math.sin(2 * math.pi * phase)
        elif wave_kind == "tri":
            s = 2.0 * abs(2.0 * (phase % 1.0) - 1.0) - 1.0
        else:  # soft square
            s = math.tanh(3.0 * math.sin(2 * math.pi * phase))
        out.append(s * env(i / SAMPLE_RATE))
    return out


def swish(rng, dur, low, high):
    """Cloth swish: noise through a one-pole low-pass whose cutoff sweeps from low to high."""
    n = int(dur * SAMPLE_RATE)
    out = []
    y = 0.0
    for i in range(n):
        x = i / n
        cutoff = lerp(low, high, x)
        a = 1.0 - math.exp(-2 * math.pi * cutoff / SAMPLE_RATE)
        y += a * (rng.uniform(-1, 1) - y)
        out.append(y * math.sin(math.pi * x) ** 1.5 * 3.0)
    return out


def sequence(notes):
    """Plays notes one after another."""
    out = []
    for note in notes:
        out.extend(note)
    return out


def build_sfx():
    rng = random.Random("sfx")
    sfx = {}
    sfx["menu_tick"] = tone(1500, 0.03, "square", decay=70.0, attack=0.0005)
    sfx["menu_confirm"] = sequence([tone(880, 0.05, "square", 30.0), tone(1320, 0.09, "square", 22.0)])
    sfx["menu_back"] = sequence([tone(660, 0.05, "square", 30.0), tone(440, 0.09, "square", 22.0)])
    sfx["bubble_open"] = tone(300, 0.1, "sine", decay=14.0, attack=0.004, glide=640)
    sfx["bubble_next"] = tone(520, 0.045, "sine", decay=40.0, attack=0.002)
    sfx["item_get"] = sequence([tone(f, 0.075, "tri", 16.0) for f in (523, 659, 784, 1047)]
                               + [tone(1047, 0.18, "tri", 9.0)])
    thumbs = swish(rng, 0.11, 400, 3000)
    mix_into(thumbs, tone(500, 0.1, "sine", 14.0, 0.003, 780), len(thumbs) - 600, 0.9)
    sfx["red_thumbs_up"] = thumbs
    shake = swish(rng, 0.07, 1500, 400)
    mix_into(shake, tone(420, 0.07, "sine", 24.0, 0.002, 360), 300, 0.7)
    mix_into(shake, swish(rng, 0.07, 400, 1500), int(0.1 * SAMPLE_RATE), 1.0)
    mix_into(shake, tone(360, 0.09, "sine", 20.0, 0.002, 290), int(0.1 * SAMPLE_RATE) + 300, 0.7)
    sfx["red_head_shake"] = shake
    for name, samples in sfx.items():
        write_wav(SFX_OUT / (name + ".wav"), fade_tail(normalise(samples, 0.7)))
    print("placeholder sfx: %d files in %s" % (len(sfx), SFX_OUT))


if __name__ == "__main__":
    build_voices()
    build_sfx()
