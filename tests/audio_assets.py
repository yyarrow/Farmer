#!/usr/bin/env python3
"""Validate the offline-generated music and sound assets without playback."""

from __future__ import annotations

import math
import hashlib
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
EXPECTED_DURATIONS = {
    "qinghe_theme.wav": 96.0,
    "qinghe_summer.wav": 96.0,
    "qinghe_autumn.wav": 96.0,
    "qinghe_winter.wav": 96.0,
    "ui_tap.wav": 0.16,
    "build.wav": 0.85,
    "upgrade.wav": 1.15,
    "trade.wav": 0.75,
    "recruit.wav": 1.0,
    "command.wav": 0.9,
    "battle_win.wav": 1.8,
    "battle_loss.wav": 1.6,
    "event.wav": 1.1,
}
LOOP_INTRO_SECONDS = 2.0
MUSIC_SECTION_SECONDS = 24.0
MUSIC_FILES = {name for name in EXPECTED_DURATIONS if name.startswith("qinghe_")}


def read_samples(path: Path) -> tuple[wave.Wave_read, tuple[int, ...]]:
    wav = wave.open(str(path), "rb")
    frames = wav.readframes(wav.getnframes())
    samples = struct.unpack("<" + "h" * (len(frames) // 2), frames)
    return wav, samples


def normalized_correlation(a: list[float], b: list[float]) -> float:
    mean_a = sum(a) / len(a)
    mean_b = sum(b) / len(b)
    covariance = sum((x - mean_a) * (y - mean_b) for x, y in zip(a, b))
    energy_a = sum((x - mean_a) ** 2 for x in a)
    energy_b = sum((y - mean_b) ** 2 for y in b)
    return covariance / max(1.0, math.sqrt(energy_a * energy_b))


def main() -> None:
    failures: list[str] = []
    music_seams: list[float] = []
    section_correlations: list[float] = []
    section_level_spreads: list[float] = []
    internal_boundary_jumps: list[float] = []
    music_hashes: set[str] = set()
    for name, expected_duration in EXPECTED_DURATIONS.items():
        path = AUDIO / name
        if not path.exists():
            failures.append(f"missing {name}")
            continue
        wav, samples = read_samples(path)
        duration = wav.getnframes() / wav.getframerate()
        if wav.getnchannels() != 2 or wav.getsampwidth() != 2 or wav.getframerate() != 32_000:
            failures.append(f"unexpected format {name}")
        if abs(duration - expected_duration) > 0.02:
            failures.append(f"unexpected duration {name}={duration:.3f}s")
        peak = max(abs(sample) for sample in samples) / 32767.0
        rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples)) / 32767.0
        if peak >= 0.95 or peak < 0.10:
            failures.append(f"unsafe peak {name}={peak:.3f}")
        if rms < 0.015:
            failures.append(f"near-silent asset {name}={rms:.4f}")
        if name in MUSIC_FILES:
            music_hashes.add(hashlib.sha256(path.read_bytes()).hexdigest())
            channels = wav.getnchannels()
            loop_frame = int(LOOP_INTRO_SECONDS * wav.getframerate())
            last = samples[-channels:]
            first_loop = samples[loop_frame * channels : (loop_frame + 1) * channels]
            music_seam = max(abs(a - b) for a, b in zip(last, first_loop)) / 32767.0
            music_seams.append(music_seam)
            if music_seam > 0.01:
                failures.append(f"music loop seam too large {name}={music_seam:.4f}")
            section_count = round(expected_duration / MUSIC_SECTION_SECONDS)
            section_frames = int(MUSIC_SECTION_SECONDS * wav.getframerate())
            sections: list[list[float]] = []
            for section in range(section_count):
                start = section * section_frames
                end = min(wav.getnframes(), start + section_frames)
                sections.append(
                    [
                        sum(samples[frame * channels : frame * channels + channels]) / channels
                        for frame in range(start, end, 160)
                    ]
                )
            section_levels = [math.sqrt(sum(value * value for value in section) / len(section)) for section in sections]
            level_spread = max(section_levels) / max(1.0, min(section_levels))
            section_level_spreads.append(level_spread)
            if level_spread > 2.25:
                failures.append(f"music section loudness is uneven {name} spread={level_spread:.3f}")
            boundary_jump = max(
                max(
                    abs(samples[frame * channels + channel] - samples[(frame - 1) * channels + channel])
                    for channel in range(channels)
                )
                for frame in (section_frames, section_frames * 2, section_frames * 3)
            ) / 32767.0
            internal_boundary_jumps.append(boundary_jump)
            if boundary_jump > 0.10:
                failures.append(f"music section boundary click {name} jump={boundary_jump:.4f}")
            track_correlation = max(
                abs(normalized_correlation(sections[a], sections[b]))
                for a in range(len(sections))
                for b in range(a + 1, len(sections))
            )
            section_correlations.append(track_correlation)
            if track_correlation >= 0.985:
                failures.append(f"music sections appear duplicated {name} correlation={track_correlation:.4f}")
        wav.close()
    if len(music_hashes) != len(MUSIC_FILES):
        failures.append("seasonal music files are not distinct")
    if failures:
        raise SystemExit("AUDIO_ASSETS_FAILED\n" + "\n".join(failures))
    print(
        f"AUDIO_ASSETS_OK files={len(EXPECTED_DURATIONS)} "
        f"music_tracks={len(MUSIC_FILES)} music_total=384.00s "
        f"loop_seam_max={max(music_seams):.4f} section_corr_max={max(section_correlations):.4f} "
        f"section_level_spread_max={max(section_level_spreads):.3f} "
        f"section_jump_max={max(internal_boundary_jumps):.4f}"
    )


if __name__ == "__main__":
    main()
