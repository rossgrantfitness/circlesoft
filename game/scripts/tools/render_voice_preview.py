#!/usr/bin/env python3
"""Renders offline PREVIEW recordings of the placeholder gibberish voices and UI sounds, so
Ross can listen without running the game.

    python3 game/scripts/tools/render_voice_preview.py

Needs only the Python 3 standard library, and the syllable WAVs already built by
make_voice_syllables.py. Writes (22.05 kHz, 16-bit, mono):
    docs/audio_previews/voices_preview.wav   seven voices, one sample line each, 0.5 s apart
    docs/audio_previews/ui_sfx_preview.wav   the 8 placeholder SFX, 0.5 s apart
    docs/audio_previews/voices_preview.md    order, lines and voice settings

It mirrors the runtime (scripts/audio/gibberish_voice.gd, audio_manager.gd): the same
letter -> syllable table, every-Nth-letter throttle, punctuation breaths, "?" rise, "!" punch,
uppercase boost and pitch_scale per speaker. Text "types" at TYPING_CPS characters per second
(spaces and newlines take time too, like the dialogue box). Each blip is resampled with linear
interpolation, like pitch_scale on an AudioStreamPlayer, and blips overlap like the player pool.
Everything is deterministic, so running it twice gives identical files. The only liberty: the
whole file is scaled by one common factor so it never clips (relative loudness is kept).
"""

import json
import math
import struct
import wave
from pathlib import Path

SAMPLE_RATE = 22050
TYPING_CPS = 30.0
GAP_S = 0.5
PEAK = 0.9
GAME_DIR = Path(__file__).resolve().parents[2]
DOCS_DIR = GAME_DIR.parent / "docs" / "audio_previews"
VOICES_JSON = GAME_DIR / "data" / "audio" / "voices.json"
SFX_JSON = GAME_DIR / "data" / "audio" / "sfx.json"

# (speaker, line). Otis, Mox and Zero are lines from data/dialogue/test_room.json; the
# others are short in-character lines written for this preview.
LINES = [
    ("otis", "Red! There you are. Welcome to the\ntest room, friend."),
    ("mox", "DIBS on narrating! This is a TEST ROOM.\nFor testing! Like me!"),
    ("zero_old", "Watch Zero, SOUND OFF! *DING-DING!*\nThat's me. I'm all of Watch Zero today."),
    ("kasp", "Citizens! Is this lamp registered? It is NOT.\nSection Nine, subsection nine!"),
    ("vela", "Good evening. I do hope you wiped your boots?\nProper manners, if you please."),
    ("ruo", "A ten out of ten entrance, naturally.\nNow, who do I charm to get out of here?"),
    ("townsfolk", "Evening, traveler. The lamps are lit,\nthe docks are quiet, the stew is warm."),
]
SFX_ORDER = ["menu_tick", "menu_confirm", "menu_back", "bubble_open", "bubble_next", "item_get",
             "red_thumbs_up", "red_head_shake"]
RES_PREFIX = "res://"
LONG_PAUSE_FACTOR = 2


def read_wav(path):
    with wave.open(str(path), "rb") as w:
        assert w.getframerate() == SAMPLE_RATE and w.getnchannels() == 1 and w.getsampwidth() == 2
        raw = w.readframes(w.getnframes())
    return [v / 32768.0 for v in struct.unpack("<%dh" % (len(raw) // 2), raw)]


def res_path(res):
    return GAME_DIR / res[len(RES_PREFIX):]


class Voice:
    """Python twin of GibberishVoice (same rules, same data)."""

    def __init__(self, doc):
        self.doc = doc
        self.settings = doc["settings"]
        self.letters = doc["letters"]
        self.keys = sorted(self.letters.keys())
        self.voices = doc["voices"]
        self.punct = doc["punctuation"]
        self.cache = {}
        self.reset()

    def reset(self):
        self.counter = 0
        self.pause_left = 0
        self.in_run = False

    def classify(self, ch):
        if not ch:
            return "skip"
        for kind, chars in (("rise", self.punct["rise"]), ("punch", self.punct["punch"]),
                            ("long_pause", self.punct["long_pause"]), ("pause", self.punct["pause"])):
            if ch in chars:
                return kind
        if ch.lower() in self.letters or ch.isdigit() and ord(ch) < 128:
            return "letter"
        if ord(ch) >= 128 and ch.lower() != ch.upper():
            return "letter"
        return "skip"

    def step(self, voice_id, ch):
        kind = self.classify(ch)
        if kind == "letter":
            self.in_run = False
            if self.pause_left > 0:
                self.pause_left -= 1
                return None
            play = self.counter % int(self.voices[voice_id]["every_nth_letter"]) == 0
            self.counter += 1
            return self.blip(voice_id, ch) if play else None
        if kind in ("pause", "long_pause"):
            if not self.in_run:
                self.in_run = True
                factor = LONG_PAUSE_FACTOR if kind == "long_pause" else 1
                self.pause_left = int(self.settings.get("pause_letters", 1)) * factor
                self.counter = 0
        elif kind in ("rise", "punch"):
            if not self.in_run:
                self.in_run = True
                self.pause_left = 0
                return self.inflection(voice_id, kind)
        return None

    def build(self, voice_id, syllable, semitones, gain, extra_db):
        v = self.voices[voice_id]
        timbre = self.doc["timbres"][v["timbre"]]
        ref = float(timbre["ref_hz"])
        res = "%s/%s/%s.wav" % (self.doc["folder"], timbre["dir"], syllable)
        scale = max(0.05, float(v["base_pitch_hz"]) / ref * 2.0 ** (semitones / 12.0))
        db = 20.0 * math.log10(max(gain, 0.0001)) + extra_db
        return {"path": res_path(res), "pitch_scale": scale, "gain": 10.0 ** (db / 20.0)}

    def blip(self, voice_id, ch):
        v = self.voices[voice_id]
        lower = ch.lower()
        entry = self.letters.get(lower) or self.letters[self.keys[ord(ch) % len(self.keys)]]
        syllable = entry["syllable"]
        half = float(v["pitch_range_semitones"]) * 0.5
        semis = float(entry["pitch"]) * half
        gain = float(v["volume"])
        if syllable.startswith("v_"):
            semis = semis * float(v["vowel_spread"]) + float(v["vowel_shift_semitones"])
        else:
            gain *= float(self.settings["consonant_gain"])
        extra = 0.0
        if ch != lower:
            semis += float(self.settings["uppercase_boost_semitones"])
            extra += float(self.settings["uppercase_boost_db"])
        return self.build(voice_id, syllable, semis, gain, extra)

    def inflection(self, voice_id, kind):
        v = self.voices[voice_id]
        gain = float(v["volume"])
        if kind == "rise":
            return self.build(voice_id, "i_rise", float(v["rise_semitones"]), gain, 0.0)
        lift = float(v["pitch_range_semitones"]) * 0.25
        return self.build(voice_id, "i_punch", lift, gain, float(v["punch_boost_db"]))


def resample(samples, scale, gain):
    """Linear-interpolation playback at `scale` times the speed (what pitch_scale does)."""
    out = []
    pos = 0.0
    last = len(samples) - 1
    while pos < last:
        i = int(pos)
        frac = pos - i
        out.append((samples[i] * (1.0 - frac) + samples[i + 1] * frac) * gain)
        pos += scale
    return out


def add_at(track, samples, start):
    need = start + len(samples)
    if need > len(track):
        track.extend([0.0] * (need - len(track)))
    for i, v in enumerate(samples):
        track[start + i] += v


def render_line(voice, speaker, text, wavs):
    """Returns (samples, blip_count). Includes the tail of the last blip."""
    voice.reset()
    track = []
    blips = 0
    for index, ch in enumerate(text):
        b = voice.step(speaker, ch)
        if b is None:
            continue
        blips += 1
        path = b["path"]
        if path not in wavs:
            wavs[path] = read_wav(path)
        add_at(track, resample(wavs[path], b["pitch_scale"], b["gain"]),
               int(index / TYPING_CPS * SAMPLE_RATE))
    typed_len = int(len(text) / TYPING_CPS * SAMPLE_RATE)
    track.extend([0.0] * max(0, typed_len - len(track)))
    return track, blips


def finish(track):
    top = max(abs(v) for v in track) or 1.0
    k = min(1.0, PEAK / top) if top > PEAK else 1.0
    return [v * k for v in track], k


def write_wav(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in samples)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        w.writeframes(frames)


def main():
    doc = json.loads(VOICES_JSON.read_text())
    voice = Voice(doc)
    wavs = {}
    gap = [0.0] * int(GAP_S * SAMPLE_RATE)

    # ---- voices ----
    track = []
    notes = []
    for speaker, text in LINES:
        start = len(track) / SAMPLE_RATE
        samples, blips = render_line(voice, speaker, text, wavs)
        track.extend(samples)
        track.extend(gap)
        notes.append((speaker, text, start, len(samples) / SAMPLE_RATE, blips))
    track, k = finish(track)
    write_wav(DOCS_DIR / "voices_preview.wav", track)

    # ---- sfx ----
    sfx = json.loads(SFX_JSON.read_text())["sfx"]
    track2 = []
    sfx_notes = []
    for name in SFX_ORDER:
        d = sfx[name]
        start = len(track2) / SAMPLE_RATE
        samples = read_wav(res_path(d["file"]))
        gain = 10.0 ** (float(d.get("volume_db", 0.0)) / 20.0)
        track2.extend(resample(samples, float(d.get("pitch_scale", 1.0)), gain))
        sfx_notes.append((name, start, d.get("note", "")))
        track2.extend(gap)
    track2, _ = finish(track2)
    write_wav(DOCS_DIR / "ui_sfx_preview.wav", track2)

    write_markdown(doc, notes, sfx_notes, k)
    print("voices_preview.wav  %.1f s" % (len(track) / SAMPLE_RATE))
    print("ui_sfx_preview.wav  %.1f s" % (len(track2) / SAMPLE_RATE))


def write_markdown(doc, notes, sfx_notes, scale_used):
    out = []
    out.append("# Voice and UI sound previews (placeholders)\n")
    out.append("Offline renders of the placeholder audio so you can listen without running the game. "
               "Made by `game/scripts/tools/render_voice_preview.py`, which copies the game's rules "
               "(same letter-to-syllable table, every-Nth-letter throttle, breaths on punctuation, "
               "`?` rise, `!` punch, per-speaker pitch) at %d characters per second of typing. "
               "These are placeholder voices; final voices are TBD. Red has no voice, only gesture "
               "sounds (see the SFX file).\n" % TYPING_CPS)
    out.append("## voices_preview.wav\n")
    out.append("22 kHz mono. Seven voices in this order, half a second of silence between them.\n")
    out.append("| # | Starts at | Voice | Line (as typed) |")
    out.append("|---|---|---|---|")
    for i, (speaker, text, start, length, blips) in enumerate(notes, 1):
        out.append("| %d | %.1f s | %s | %s |" % (i, start, speaker, text.replace("\n", " / ")))
    out.append("")
    out.append("Otis, Mox and Zero use lines from `game/data/dialogue/test_room.json`. Kasp, Vela, Ruo and "
               "the townsfolk lines are short in-character lines written for this preview.\n")
    out.append("### Voice settings (from `game/data/audio/voices.json`)\n")
    out.append("| Voice | Timbre | Base pitch | Pitch range | Plays every | Vowel shift / spread | Volume | `!` boost | `?` lift | Blips in line | Character |")
    out.append("|---|---|---|---|---|---|---|---|---|---|---|")
    for speaker, text, start, length, blips in notes:
        v = doc["voices"][speaker]
        out.append("| %s | %s | %g Hz | %g semitones | %d letters | %+g st / x%g | %g | +%g dB | +%g st | %d | %s |" % (
            speaker, v["timbre"], v["base_pitch_hz"], v["pitch_range_semitones"], v["every_nth_letter"],
            v["vowel_shift_semitones"], v["vowel_spread"], v["volume"], v["punch_boost_db"],
            v["rise_semitones"], blips, v.get("note", "")))
    out.append("")
    out.append("## ui_sfx_preview.wav\n")
    out.append("22 kHz mono. The eight placeholder sounds in this order, half a second apart, no announcements. "
               "Each plays at its volume from `game/data/audio/sfx.json`.\n")
    out.append("| # | Starts at | Sound | What it is |")
    out.append("|---|---|---|---|")
    for i, (name, start, note) in enumerate(sfx_notes, 1):
        out.append("| %d | %.1f s | %s | %s |" % (i, start, name, note))
    out.append("")
    (DOCS_DIR / "voices_preview.md").write_text("\n".join(out))


if __name__ == "__main__":
    main()
