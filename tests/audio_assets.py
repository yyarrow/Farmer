#!/usr/bin/env python3
"""Validate the offline-generated music and sound assets without playback."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "assets" / "audio"
EXPECTED_DURATIONS = {
    "qinghe_theme.wav": 48.0,
    "ui_tap.wav": 0.16,
    "build.wav": 0.85,
    "upgrade.wav": 1.15,
    "trade.wav": 0.75,
    "recruit.wav": 1.0,
    "battle_win.wav": 1.8,
    "battle_loss.wav": 1.6,
    "event.wav": 1.1,
}
LOOP_INTRO_SECONDS = 2.0


def read_samples(path: Path) -> tuple[wave.Wave_read, tuple[int, ...]]:
    wav = wave.open(str(path), "rb")
    frames = wav.readframes(wav.getnframes())
    samples = struct.unpack("<" + "h" * (len(frames) // 2), frames)
    return wav, samples


def main() -> None:
    failures: list[str] = []
    music_seam = 1.0
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
        if name == "qinghe_theme.wav":
            channels = wav.getnchannels()
            loop_frame = int(LOOP_INTRO_SECONDS * wav.getframerate())
            last = samples[-channels:]
            first_loop = samples[loop_frame * channels : (loop_frame + 1) * channels]
            music_seam = max(abs(a - b) for a, b in zip(last, first_loop)) / 32767.0
            if music_seam > 0.01:
                failures.append(f"music loop seam too large={music_seam:.4f}")
        wav.close()
    if failures:
        raise SystemExit("AUDIO_ASSETS_FAILED\n" + "\n".join(failures))
    print(f"AUDIO_ASSETS_OK files={len(EXPECTED_DURATIONS)} music=48.00s loop_seam={music_seam:.4f}")


if __name__ == "__main__":
    main()
