"""Render the original After Silence score to loopable mono WAV."""
from array import array
from math import exp, pi, sin
from pathlib import Path
import wave

RATE = 22050
BARS = 4
BEAT = 0.78
DURATION = 4 * BARS * BEAT
PALETTES = {
    "courtyard": [(45, 52, 57, 60), (41, 48, 52, 57), (48, 55, 60, 64), (43, 50, 55, 59)],
    "inside": [(45, 52, 56, 59), (41, 48, 52, 55), (48, 53, 57, 60), (43, 50, 55, 58)],
    "shore": [(43, 50, 55, 58), (46, 53, 57, 60), (41, 48, 53, 57), (43, 50, 55, 62)],
}


def osc(note, time):
    frequency = 440 * 2 ** ((note - 69) / 12)
    phase = 2 * pi * frequency * time
    return sin(phase) + 0.18 * sin(phase * 2) + 0.07 * sin(phase * 3)


def render(chords):
    samples = [0.0] * round(RATE * DURATION)
    for bar, chord in enumerate(chords):
        for beat, index in ((0, 0), (0.5, 1), (1.5, 2), (2.5, 3), (3, 1)):
            offset = round((4 * bar + beat) * BEAT * RATE)
            for sample in range(round(2.1 * RATE)):
                time = sample / RATE
                envelope = min(time * 10, 1) * exp(-time * 2.15) * min(1, (2.1 - time) * 5)
                samples[(offset + sample) % len(samples)] += osc(chord[index], time) * envelope * (0.16 if index == 0 else 0.10)
    return array("h", (round(value * 29000) for value in samples))


def main():
    target = Path(__file__).resolve().parents[2] / "assets" / "score090"
    target.mkdir(parents=True, exist_ok=True)
    for name, chords in PALETTES.items():
        with wave.open(str(target / f"{name}.wav"), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(RATE)
            audio.writeframes(render(chords).tobytes())


if __name__ == "__main__":
    main()
