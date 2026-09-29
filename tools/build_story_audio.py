"""Build quiet distant-voice prototypes from a locally synthesized male '啊'.

Source: Windows Speech Microsoft Kangkang (not a human actor or voice clone).
Run after recording build/verification/phase2-audio/prince_ah_source.wav.
Uses only standard-library resampling, low-pass filtering and short echoes.
"""
from pathlib import Path
import array
import math
import wave

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'build/verification/phase2-audio/prince_ah_source.wav'
OUTPUT = ROOT / 'assets/audio/phase2'


def main():
    with wave.open(str(SOURCE), 'rb') as stream:
        channels, width, rate, length, _, _ = stream.getparams()
        assert width == 2, 'Expected PCM16 speech source'
        samples = array.array('h', stream.readframes(length))
    mono = [sum(samples[i:i + channels]) / channels / 32768 for i in range(0, len(samples), channels)]
    # Trim synthetic leading/trailing silence, preserving a soft onset.
    active = [i for i, sample in enumerate(mono) if abs(sample) > 0.006]
    assert active, 'Speech source is silent'
    mono = mono[max(0, active[0] - int(rate * .03)):min(len(mono), active[-1] + int(rate * .05))]
    output_rate = 22050
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for variant, stretch in enumerate((1.6, 1.8, 1.45), 1):
        count = int(len(mono) * output_rate / rate * stretch)
        dry, previous = [], 0.0
        coefficient = 1 - math.exp(-2 * math.pi * 1300 / output_rate)
        for i in range(count):
            position = i * rate / output_rate / stretch
            lo = min(int(position), len(mono) - 1)
            hi = min(lo + 1, len(mono) - 1)
            value = mono[lo] * (1 - position % 1) + mono[hi] * (position % 1)
            previous += coefficient * (value - previous)
            envelope = min(1, i / (output_rate * .025), (count - i) / (output_rate * .06))
            dry.append(previous * envelope)
        result = [0.0] * (count + int(output_rate * .7))
        for delay_seconds, gain in ((0, .75), (.16, .28), (.33, .14), (.52, .07)):
            delay = int(delay_seconds * output_rate)
            for i, value in enumerate(dry):
                result[i + delay] += value * gain
        peak = max(abs(v) for v in result)
        gain = min(1.0, .48 / max(peak, 1e-8))
        pcm = array.array('h', [round(max(-.98, min(.98, v * gain)) * 32767) for v in result])
        path = OUTPUT / f'prince_cry_{variant}.wav'
        with wave.open(str(path), 'wb') as stream:
            stream.setparams((1, 2, output_rate, len(pcm), 'NONE', 'not compressed'))
            stream.writeframes(pcm.tobytes())
        print(f'{path.name}: {len(pcm)/output_rate:.2f}s, peak {peak*gain:.3f}')


if __name__ == '__main__':
    main()
