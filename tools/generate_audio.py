#!/usr/bin/env python3
"""Generate original, loopable Qinghe music and UI/gameplay sound effects.

Uses only the Python standard library so audio can be rebuilt offline.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

RATE = 32_000
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio"
TAU = math.tau


def note(midi: float) -> float:
    return 440.0 * (2.0 ** ((midi - 69.0) / 12.0))


def pan_gains(pan: float) -> tuple[float, float]:
    angle = (pan + 1.0) * math.pi / 4.0
    return math.cos(angle), math.sin(angle)


def add_tone(
    left: list[float],
    right: list[float],
    start: float,
    duration: float,
    frequency: float,
    volume: float,
    pan: float = 0.0,
    kind: str = "pluck",
) -> None:
    begin = max(0, int(start * RATE))
    end = min(len(left), int((start + duration) * RATE))
    gl, gr = pan_gains(pan)
    phase = 0.0
    vibrato_phase = 0.0
    for i in range(begin, end):
        t = (i - begin) / RATE
        p = t / max(duration, 0.001)
        if kind == "pluck":
            env = math.exp(-4.8 * p) * min(1.0, t * 90.0)
            body = (
                math.sin(phase)
                + 0.34 * math.sin(phase * 2.01 + 0.25)
                + 0.12 * math.sin(phase * 3.98 + 0.7)
            )
        elif kind == "flute":
            env = min(1.0, t * 3.8) * min(1.0, (duration - t) * 3.2)
            vibrato = 1.0 + 0.004 * math.sin(vibrato_phase)
            phase += TAU * frequency * vibrato / RATE
            vibrato_phase += TAU * 5.1 / RATE
            body = math.sin(phase) + 0.16 * math.sin(phase * 2.0) + 0.05 * math.sin(phase * 3.0)
            sample = body * env * volume
            left[i] += sample * gl
            right[i] += sample * gr
            continue
        else:
            env = math.sin(math.pi * min(1.0, p)) ** 0.65
            body = math.sin(phase) + 0.18 * math.sin(phase * 0.5)
        sample = body * env * volume
        left[i] += sample * gl
        right[i] += sample * gr
        phase += TAU * frequency / RATE


def add_bell(left: list[float], right: list[float], start: float, frequency: float, volume: float, pan: float) -> None:
    begin = int(start * RATE)
    end = min(len(left), begin + int(2.2 * RATE))
    gl, gr = pan_gains(pan)
    for i in range(begin, end):
        t = (i - begin) / RATE
        env = math.exp(-2.35 * t)
        s = (
            math.sin(TAU * frequency * t)
            + 0.54 * math.sin(TAU * frequency * 2.71 * t + 0.4)
            + 0.24 * math.sin(TAU * frequency * 4.13 * t + 1.1)
        ) * env * volume
        left[i] += s * gl
        right[i] += s * gr


def add_drum(left: list[float], right: list[float], start: float, volume: float) -> None:
    begin = int(start * RATE)
    end = min(len(left), begin + int(0.55 * RATE))
    rng = random.Random(1100 + begin)
    phase = 0.0
    for i in range(begin, end):
        t = (i - begin) / RATE
        env = math.exp(-8.0 * t)
        freq = 92.0 - 42.0 * min(1.0, t / 0.32)
        phase += TAU * freq / RATE
        s = (math.sin(phase) * 0.86 + rng.uniform(-1.0, 1.0) * math.exp(-28.0 * t) * 0.22) * env * volume
        left[i] += s
        right[i] += s


def add_ambience(left: list[float], right: list[float], seed: int, level: float) -> None:
    rng = random.Random(seed)
    slow_l = slow_r = 0.0
    for i in range(len(left)):
        # Soft filtered air/water bed, intentionally very quiet.
        slow_l = slow_l * 0.996 + rng.uniform(-1.0, 1.0) * 0.004
        slow_r = slow_r * 0.996 + rng.uniform(-1.0, 1.0) * 0.004
        breath = level * (0.006 + 0.003 * math.sin(TAU * i / RATE / 9.0))
        left[i] += slow_l * breath
        right[i] += slow_r * breath


def crossfade_loop(left: list[float], right: list[float], seconds: float = 2.0) -> None:
    n = int(seconds * RATE)
    for i in range(n):
        a = i / max(1, n - 1)
        tail_index = len(left) - n + i
        head_l, head_r = left[i], right[i]
        tail_l, tail_r = left[tail_index], right[tail_index]
        mixed_l = tail_l * (1.0 - a) + head_l * a
        mixed_r = tail_r * (1.0 - a) + head_r * a
        left[tail_index] = mixed_l
        right[tail_index] = mixed_r


def write_wav(path: Path, left: list[float], right: list[float] | None = None) -> None:
    right = left if right is None else right
    peak = max(0.001, max(max(abs(x) for x in left), max(abs(x) for x in right)))
    gain = min(1.0, 0.88 / peak)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        frames = bytearray()
        for l, r in zip(left, right):
            frames.extend(struct.pack("<hh", int(max(-1.0, min(1.0, l * gain)) * 32767), int(max(-1.0, min(1.0, r * gain)) * 32767)))
        wav.writeframes(frames)


def generate_music_track(path: Path, score: dict) -> None:
    duration = 96.0
    samples = int(duration * RATE)
    left = [0.0] * samples
    right = [0.0] * samples
    sections = [
        (score["melody"], 0.0),
        (score["answer"], 24.0),
        (score["variation"], 48.0),
        (score["reprise"], 72.0),
    ]
    for section_index, (phrase, start) in enumerate(sections):
        for index, midi in enumerate(phrase):
            t = start + index * 1.5
            add_tone(left, right, t, score["note_length"], note(midi), score["pluck"], -0.28 + (index % 3) * 0.26, "pluck")
            if index in score["bell_steps"]:
                add_bell(left, right, t + 0.75, note(midi + score["bell_shift"]), score["bell"], 0.45)
        bass_line = score["bass"] if section_index in (0, 3) else score["bass_alt"]
        drum_scale = (1.0, 0.78, 1.12, 0.70)[section_index]
        for bar in range(6):
            t = start + bar * 4.0
            bass = bass_line[bar]
            add_tone(left, right, t, 4.2, note(bass), score["pad"], 0.0, "pad")
            add_drum(left, right, t, score["drum"] * drum_scale)
            if score["offbeat_drum"] > 0.0:
                add_drum(left, right, t + 2.0, score["offbeat_drum"] * drum_scale)
    for start, midi, length in score["flute"]:
        add_tone(left, right, start, length, note(midi), score["flute_volume"], 0.18, "flute")
    add_ambience(left, right, score["seed"], score["ambience"])
    crossfade_loop(left, right)
    write_wav(path, left, right)


def generate_music() -> None:
    # Four related pentatonic pieces: lively in summer, warm in autumn and sparse in winter.
    scores = {
        "qinghe_theme.wav": {
            "melody": [62, 64, 66, 69, 66, 64, 62, 57, 59, 62, 64, 62, 59, 57, 54, 57],
            "answer": [57, 59, 62, 64, 69, 66, 64, 62, 64, 66, 69, 71, 69, 66, 64, 62],
            "variation": [64, 66, 69, 71, 69, 66, 64, 59, 62, 64, 66, 69, 66, 64, 62, 59],
            "reprise": [62, 57, 59, 62, 66, 64, 62, 59, 57, 59, 62, 64, 62, 59, 57, 54],
            "bass": [38, 35, 33, 35, 38, 33],
            "bass_alt": [38, 40, 35, 33, 35, 38],
            "flute": [(6.0, 69, 5.0), (13.0, 66, 4.5), (28.0, 64, 5.0), (36.0, 69, 5.5), (43.0, 66, 4.2), (52.0, 71, 4.8), (61.0, 69, 5.2), (75.0, 66, 4.5), (86.0, 69, 5.5)],
            "note_length": 2.0, "pluck": 0.13, "bell_steps": (2, 6, 10, 14), "bell_shift": -12,
            "bell": 0.035, "pad": 0.055, "drum": 0.055, "offbeat_drum": 0.028,
            "flute_volume": 0.045, "seed": 20260711, "ambience": 1.0,
        },
        "qinghe_summer.wav": {
            "melody": [67, 69, 71, 74, 71, 69, 67, 64, 67, 71, 74, 76, 74, 71, 69, 67],
            "answer": [62, 67, 69, 71, 74, 71, 69, 67, 71, 74, 76, 79, 76, 74, 71, 67],
            "variation": [69, 71, 74, 76, 79, 76, 74, 71, 67, 69, 71, 74, 71, 69, 67, 64],
            "reprise": [67, 64, 67, 69, 71, 74, 71, 69, 67, 71, 69, 67, 64, 67, 62, 64],
            "bass": [43, 38, 40, 38, 43, 40],
            "bass_alt": [43, 45, 40, 38, 40, 43],
            "flute": [(4.5, 74, 4.0), (12.0, 79, 4.5), (26.0, 76, 4.0), (34.5, 79, 5.0), (42.0, 74, 4.5), (50.0, 76, 4.0), (58.0, 81, 4.6), (67.0, 74, 4.2), (78.0, 71, 4.5), (88.0, 76, 4.8)],
            "note_length": 1.75, "pluck": 0.12, "bell_steps": (1, 5, 9, 13), "bell_shift": -12,
            "bell": 0.04, "pad": 0.052, "drum": 0.07, "offbeat_drum": 0.04,
            "flute_volume": 0.041, "seed": 20260712, "ambience": 1.2,
        },
        "qinghe_autumn.wav": {
            "melody": [59, 62, 64, 67, 64, 62, 59, 55, 57, 59, 62, 64, 62, 59, 57, 55],
            "answer": [55, 57, 59, 62, 67, 64, 62, 59, 57, 62, 64, 67, 64, 62, 59, 55],
            "variation": [62, 64, 67, 69, 67, 64, 62, 59, 57, 59, 62, 64, 67, 64, 62, 57],
            "reprise": [59, 57, 55, 57, 59, 62, 64, 62, 59, 55, 57, 59, 57, 55, 52, 55],
            "bass": [35, 31, 33, 31, 35, 33],
            "bass_alt": [35, 38, 33, 31, 33, 35],
            "flute": [(7.5, 67, 5.5), (16.0, 64, 5.0), (29.5, 62, 5.5), (38.0, 67, 5.0), (51.0, 69, 5.0), (61.0, 64, 5.5), (74.0, 62, 5.0), (86.0, 59, 5.5)],
            "note_length": 2.25, "pluck": 0.115, "bell_steps": (3, 7, 11, 15), "bell_shift": 0,
            "bell": 0.028, "pad": 0.062, "drum": 0.045, "offbeat_drum": 0.018,
            "flute_volume": 0.043, "seed": 20260713, "ambience": 0.9,
        },
        "qinghe_winter.wav": {
            "melody": [57, 59, 62, 64, 62, 59, 57, 54, 52, 54, 57, 59, 57, 54, 52, 50],
            "answer": [50, 52, 54, 57, 62, 59, 57, 54, 57, 59, 62, 64, 62, 59, 54, 52],
            "variation": [54, 57, 59, 62, 59, 57, 54, 50, 52, 54, 57, 62, 59, 57, 54, 50],
            "reprise": [57, 54, 52, 54, 57, 59, 57, 54, 52, 50, 52, 54, 52, 50, 47, 50],
            "bass": [33, 29, 31, 29, 33, 31],
            "bass_alt": [33, 35, 31, 29, 31, 33],
            "flute": [(8.0, 64, 6.0), (18.0, 59, 4.5), (30.0, 57, 6.0), (40.0, 62, 5.5), (53.0, 59, 6.0), (65.0, 57, 5.5), (77.0, 54, 6.0), (88.0, 59, 5.5)],
            "note_length": 2.5, "pluck": 0.095, "bell_steps": (4, 12), "bell_shift": 0,
            "bell": 0.022, "pad": 0.07, "drum": 0.022, "offbeat_drum": 0.0,
            "flute_volume": 0.038, "seed": 20260714, "ambience": 0.75,
        },
    }
    for filename, score in scores.items():
        generate_music_track(OUT / filename, score)


def effect(kind: str, seconds: float, builder) -> None:
    samples = int(seconds * RATE)
    left = [0.0] * samples
    right = [0.0] * samples
    builder(left, right)
    write_wav(OUT / f"{kind}.wav", left, right)


def generate_effects() -> None:
    effect("ui_tap", 0.16, lambda l, r: add_tone(l, r, 0.0, 0.15, note(74), 0.26, 0.0, "pluck"))
    effect("build", 0.85, lambda l, r: [add_tone(l, r, i * 0.16, 0.55, note(57 + i * 2), 0.18, -0.3 + i * 0.3, "pluck") for i in range(3)])
    effect("upgrade", 1.15, lambda l, r: [add_bell(l, r, i * 0.22, note(62 + i * 2), 0.10, -0.35 + i * 0.35) for i in range(4)])
    effect("trade", 0.75, lambda l, r: [add_bell(l, r, i * 0.14, note(69 + i * 3), 0.07, -0.25 + i * 0.25) for i in range(3)])
    effect("recruit", 1.0, lambda l, r: [add_drum(l, r, i * 0.23, 0.20 - i * 0.03) for i in range(4)])
    effect("command", 0.9, lambda l, r: [add_drum(l, r, i * 0.24, 0.24 - i * 0.04) for i in range(3)] + [add_bell(l, r, 0.48, note(57), 0.055, 0.0)])
    effect("battle_win", 1.8, lambda l, r: [add_bell(l, r, i * 0.25, note([57, 62, 66, 69, 74][i]), 0.11, -0.4 + i * 0.2) for i in range(5)])
    effect("battle_loss", 1.6, lambda l, r: [add_tone(l, r, i * 0.28, 1.0, note([50, 47, 45][i]), 0.13, 0.0, "pad") for i in range(3)])
    effect("event", 1.1, lambda l, r: [add_bell(l, r, i * 0.32, note(62 + i * 7), 0.08, -0.25 + i * 0.5) for i in range(2)])


if __name__ == "__main__":
    generate_music()
    generate_effects()
    print(f"Generated original audio in {OUT}")
