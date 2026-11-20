"""Tiếng bước chân trên cỏ (dịu tai): tiếng sột soạt trầm, mềm, không có hạt rè chói tần số cao.
Chạy: python3 tools/make_grass_steps.py  -> ghi đè assets/sfx/step_grass_1..3.wav"""
import numpy as np, wave, os
SR = 32000
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
rng = np.random.default_rng(31)

def band(x, lo, hi, soft=0.3):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    m = 1 / (1 + np.exp(-(f - lo) / max(1.0, lo * soft))) * 1 / (1 + np.exp((f - hi) / max(1.0, hi * soft)))
    return np.fft.irfft(X * m, len(x))

def save(name, x, peak):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())

for i in range(1, 4):
    d = 0.26 + 0.03 * i
    n = int(SR * d); tt = np.arange(n) / SR
    # lớp sột soạt chính: nhiễu lọc dải 250-1600Hz, đường bao mềm (vào 25ms, tắt dần)
    swish = band(rng.uniform(-1, 1, n), 250, 1600) * (np.minimum(1, tt / 0.025) * np.exp(-tt / (d * 0.32)))
    # vài lá cỏ cọ nhau: hạt rất nhẹ, tần số vừa
    rust = np.zeros(n)
    for _ in range(8):
        p = rng.integers(0, n - 400); g = band(rng.uniform(-1, 1, 400), 900, 2600) * np.hanning(400) * rng.uniform(0.2, 0.5)
        rust[p:p + 400] += g * (1 - p / n)
    # gót chân lún nhẹ xuống đất mềm
    thud = np.sin(2 * np.pi * 85 * tt) * np.exp(-tt / 0.035) * 0.5
    x = swish + rust * 0.35 + thud
    x = np.convolve(x, np.ones(6) / 6, mode='same')        # làm mềm thêm
    save(f'step_grass_{i}', x, 0.32)
print("ok")
