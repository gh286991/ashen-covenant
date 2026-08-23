#!/usr/bin/env python3
"""Generate Ashen Covenant's original brass level-up fanfare as a WAV file."""

from __future__ import annotations

import math
import random
import struct
import sys
import wave
from pathlib import Path

SAMPLE_RATE = 44_100
DURATION = 2.65
TAU = math.tau


def envelope(t: float, start: float, length: float, attack: float = 0.025) -> float:
    local = t - start
    if local < 0.0 or local >= length:
        return 0.0
    if local < attack:
        return local / attack
    release = min(0.34, length * 0.38)
    if local > length - release:
        return max(0.0, (length - local) / release)
    return 1.0


def brass_voice(t: float, frequency: float, start: float, length: float, detune: float) -> float:
    env = envelope(t, start, length)
    if env <= 0.0:
        return 0.0
    local = t - start
    vibrato = 1.0 + 0.0025 * math.sin(TAU * 5.2 * local)
    phase = TAU * frequency * detune * vibrato * local
    harmonics = (1.0, 0.52, 0.29, 0.17, 0.105, 0.065, 0.04)
    raw = sum(amp * math.sin(phase * (index + 1)) for index, amp in enumerate(harmonics))
    brightness = min(1.0, local / 0.09)
    return math.tanh(raw * (0.72 + 0.42 * brightness)) * env


def synth_channel(t: float, detune: float, side: float) -> float:
    value = 0.0
    fanfare = (
        (523.251, 0.00, 0.26, 0.34),
        (659.255, 0.22, 0.27, 0.34),
        (783.991, 0.44, 0.34, 0.37),
        (1046.502, 0.70, 0.48, 0.40),
        (523.251, 1.08, 1.34, 0.23),
        (659.255, 1.08, 1.34, 0.20),
        (783.991, 1.08, 1.34, 0.18),
        (1046.502, 1.08, 1.34, 0.16),
    )
    for frequency, start, length, gain in fanfare:
        value += brass_voice(t, frequency, start, length, detune) * gain
    # Quiet high sparkle reinforces celebration without replacing the brass lead.
    sparkle_env = envelope(t, 0.72, 1.25, 0.015)
    value += math.sin(TAU * (2093.0 + side * 7.0) * max(0.0, t - 0.72)) * sparkle_env * 0.028
    return value


def main() -> int:
    output = Path(sys.argv[1] if len(sys.argv) > 1 else "assets/audio/sfx/level_up_fanfare.wav")
    output.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(0xA5E12026)
    dry_left: list[float] = []
    dry_right: list[float] = []
    frame_count = int(SAMPLE_RATE * DURATION)
    for frame in range(frame_count):
        t = frame / SAMPLE_RATE
        breath = (rng.random() * 2.0 - 1.0) * envelope(t, 0.0, 2.35, 0.01) * 0.006
        dry_left.append(synth_channel(t, 0.9985, -1.0) + breath)
        dry_right.append(synth_channel(t, 1.0015, 1.0) + breath)

    echoes = ((0.085, 0.18), (0.17, 0.11), (0.31, 0.075), (0.47, 0.045))
    mixed: list[tuple[float, float]] = []
    peak = 0.001
    for frame in range(frame_count):
        left = dry_left[frame]
        right = dry_right[frame]
        for delay, gain in echoes:
            source = frame - int(delay * SAMPLE_RATE)
            if source >= 0:
                left += dry_right[source] * gain
                right += dry_left[source] * gain
        mixed.append((left, right))
        peak = max(peak, abs(left), abs(right))

    scale = 0.91 / peak
    with wave.open(str(output), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for left, right in mixed:
            frames.extend(struct.pack("<hh", int(left * scale * 32767), int(right * scale * 32767)))
        wav.writeframes(frames)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
