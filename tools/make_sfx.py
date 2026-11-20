"""Tổng hợp toàn bộ âm thanh của game bằng numpy (không dùng file ngoài).
Chạy: python3 tools/make_sfx.py  -> ghi các file .wav vào assets/sfx/"""
import numpy as np, wave, os
SR = 32000
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')
rng = np.random.default_rng(7)

def noise(n): return rng.uniform(-1, 1, n)
def t(d): return np.arange(int(SR * d)) / SR
def band(x, lo, hi, soft=0.15):
    X = np.fft.rfft(x); f = np.fft.rfftfreq(len(x), 1 / SR)
    m = 1 / (1 + np.exp(-(f - lo) / max(1.0, lo * soft))) * 1 / (1 + np.exp((f - hi) / max(1.0, hi * soft)))
    return np.fft.irfft(X * m, len(x))
def env(n, a, d, curve=3.0):
    e = np.ones(n); na = max(1, int(a * SR)); e[:na] = np.linspace(0, 1, na)
    k = np.arange(n - na) / max(1, n - na); e[na:] = np.exp(-curve * k / max(1e-3, d))
    return e
def norm(x, peak=0.9): return x / (np.max(np.abs(x)) + 1e-9) * peak
def fade_loop(x, f=0.25):
    n = int(SR * f); a = x[:n]; b = x[-n:]; k = np.linspace(0, 1, n)
    mid = x[n:-n]; return np.concatenate([b * (1 - k) + a * k, mid])
def save(name, x, peak=0.9):
    x = norm(np.asarray(x, dtype=np.float64), peak)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype('<i2').tobytes())
def thump(d, f0, f1, amp=1.0):
    tt = t(d); f = f0 * (f1 / f0) ** (tt / d); return amp * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / (d * 0.35))
def burst(d, lo, hi, a=0.002, dec=0.25, curve=4.0):
    n = int(SR * d); return band(noise(n), lo, hi) * env(n, a, dec, curve)
def grains(d, count, lo, hi, gl=0.012):
    n = int(SR * d); x = np.zeros(n)
    for _ in range(count):
        p = rng.integers(0, max(1, n - int(SR * gl) - 1)); g = burst(gl, lo, hi, 0.001, 0.3) * rng.uniform(0.3, 1) * (1 - p / n) ** 1.5
        x[p:p + len(g)] += g
    return x
def pad(x, d):
    n = int(SR * d); return np.concatenate([x, np.zeros(max(0, n - len(x)))])
def mix(*xs):
    n = max(len(x) for x in xs); o = np.zeros(n)
    for x in xs: o[:len(x)] += x
    return o

# ---- bước chân theo bề mặt
for i in range(1, 4):
    v = rng.uniform(0.9, 1.1)
    save(f'step_asphalt_{i}', mix(burst(0.11, 900 * v, 4500, dec=0.16) * 0.8, thump(0.07, 150 * v, 70, 0.7), grains(0.12, 5, 3000, 9000) * 0.25), 0.6)
    save(f'step_concrete_{i}', mix(burst(0.09, 1400 * v, 6000, dec=0.12), thump(0.05, 220 * v, 110, 0.5)), 0.6)
    save(f'step_tile_{i}', mix(burst(0.07, 2200 * v, 9000, dec=0.08), thump(0.04, 320 * v, 180, 0.5), burst(0.2, 1800, 5000, dec=0.5) * 0.08), 0.6)
    save(f'step_wood_{i}', mix(thump(0.16, 190 * v, 95, 1.0), burst(0.08, 500, 2200, dec=0.2) * 0.5, np.concatenate([np.zeros(int(SR * 0.05)), burst(0.12, 700 * v, 1500, 0.02, 0.5) * 0.18])), 0.65)
    save(f'step_metal_{i}', mix(burst(0.06, 2500, 10000, dec=0.08) * 0.6, sum(np.sin(2 * np.pi * f * v * t(0.35)) * np.exp(-t(0.35) * dcy) * a for f, dcy, a in [(410, 14, .6), (967, 18, .4), (1730, 24, .3), (2890, 30, .2)])), 0.6)
    save(f'step_grass_{i}', mix(grains(0.22, 28, 2500, 9000, 0.02) * 0.9, burst(0.18, 300, 1500, 0.02, 0.4) * 0.3), 0.5)
    save(f'step_dirt_{i}', mix(grains(0.18, 16, 700, 4500, 0.025), thump(0.08, 120 * v, 60, 0.6), burst(0.14, 250, 1200, 0.005, 0.3) * 0.5), 0.6)
    save(f'step_water_{i}', mix(burst(0.32, 500, 5000, 0.01, 0.35, 3) * 0.8, grains(0.4, 30, 1500, 8000, 0.03) * 0.6, thump(0.12, 260 * v, 120, 0.4)), 0.65)
    # bơi: tiếng quạt nước dài hơn
    n = int(SR * 0.7); sw = band(noise(n), 300, 3500) * np.sin(np.pi * np.arange(n) / n) ** 2
    save(f'swim_{i}', mix(sw, grains(0.7, 40, 1500, 7000, 0.03) * 0.5), 0.55)
save('splash', mix(burst(0.9, 300, 7000, 0.005, 0.3, 3), thump(0.3, 180, 50, 0.9), grains(1.0, 80, 1500, 9000, 0.03) * 0.6), 0.85)

# ---- thời tiết (vòng lặp)
d = 6.0; n = int(SR * d)
rain = band(noise(n), 1500, 11000) * 0.5 + grains(d, 2600, 3000, 12000, 0.006) * 1.2 + band(noise(n), 200, 900) * 0.25
save('rain_loop', fade_loop(rain), 0.6)
roof = band(noise(n), 300, 2600) * 0.6 + grains(d, 900, 600, 3000, 0.012)
save('rain_roof_loop', fade_loop(roof), 0.5)
lfo = 0.55 + 0.45 * np.sin(2 * np.pi * 0.17 * t(d) + 1.0) * np.sin(2 * np.pi * 0.07 * t(d))
wind = band(noise(n), 120, 900) * lfo + band(noise(n), 900, 2600) * lfo ** 2 * 0.25
save('wind_loop', fade_loop(wind), 0.5)
city = band(noise(n), 40, 260) * 0.8 + band(noise(n), 260, 900) * 0.15
save('rumble_loop', fade_loop(city), 0.45)
under = band(noise(n), 60, 520) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.3 * t(d)))
save('underwater_loop', fade_loop(under), 0.55)
for i in (1, 2):
    dd = 4.5; nn = int(SR * dd); crack = burst(0.5, 400, 7000, 0.002, 0.25) * 1.2
    roll = band(noise(nn), 30, 260) * env(nn, 0.15, 0.6, 2.5) * (0.7 + 0.3 * np.sin(2 * np.pi * rng.uniform(0.8, 1.6) * t(dd)))
    save(f'thunder_{i}', mix(crack, roll * 1.4), 0.9)

# ---- hành động
save('ui_click', np.sin(2 * np.pi * 900 * t(0.05)) * np.exp(-t(0.05) * 90), 0.35)
save('ui_open', mix(burst(0.12, 800, 5000, 0.01, 0.3) * 0.6, np.sin(2 * np.pi * 520 * t(0.1)) * np.exp(-t(0.1) * 40) * 0.5), 0.35)
save('pickup', mix(burst(0.08, 1500, 7000, dec=0.2) * 0.6, np.sin(2 * np.pi * 660 * t(0.12)) * np.exp(-t(0.12) * 30) * 0.5, np.concatenate([np.zeros(int(SR * 0.06)), np.sin(2 * np.pi * 990 * t(0.12)) * np.exp(-t(0.12) * 30) * 0.4])), 0.45)
save('rummage', mix(grains(0.6, 40, 500, 5000, 0.03), burst(0.5, 300, 2000, 0.05, 0.6) * 0.3), 0.5)
save('eat', np.concatenate([mix(burst(0.09, 800, 5000, 0.004, 0.3), thump(0.05, 200, 120, 0.3)) for _ in range(4)] + [np.zeros(100)]), 0.5)
gulp = lambda f: np.sin(2 * np.pi * np.cumsum(f * (1 + 0.8 * t(0.16) / 0.16)) / SR) * np.sin(np.pi * t(0.16) / 0.16) ** 2
save('drink', np.concatenate([np.concatenate([gulp(230 + 30 * k), np.zeros(int(SR * 0.09))]) for k in range(4)]), 0.5)
save('bandage', mix(band(noise(int(SR * 0.7)), 1500, 8000) * np.abs(np.sin(2 * np.pi * 3 * t(0.7))) ** 3, grains(0.7, 20, 2000, 9000) * 0.4), 0.4)
save('swing', band(noise(int(SR * 0.28)), 400, 3500) * np.sin(np.pi * t(0.28) / 0.28) ** 3, 0.5)
save('hit', mix(thump(0.18, 200, 60, 1.0), burst(0.1, 600, 5000, dec=0.15) * 0.8), 0.8)
save('hurt', mix(thump(0.25, 150, 55, 1.0), burst(0.2, 200, 1800, 0.003, 0.3) * 0.7), 0.8)
hb = mix(thump(0.14, 70, 40, 1.0), np.concatenate([np.zeros(int(SR * 0.22)), thump(0.12, 60, 38, 0.7)]))
save('heartbeat', pad(hb, 0.9), 0.8)
save('gasp', band(noise(int(SR * 0.8)), 500, 4500) * env(int(SR * 0.8), 0.25, 0.5, 3) * (1 + 0.3 * np.sin(2 * np.pi * 30 * t(0.8))), 0.5)
save('gunshot', mix(burst(0.5, 200, 9000, 0.0005, 0.12, 5) * 1.2, thump(0.2, 220, 50, 1.0), band(noise(int(SR * 1.2)), 200, 2500) * env(int(SR * 1.2), 0.02, 0.5, 3) * 0.25), 0.95)
save('empty', mix(burst(0.03, 2500, 9000, dec=0.2), np.sin(2 * np.pi * 1800 * t(0.04)) * np.exp(-t(0.04) * 120)), 0.4)
save('glass', mix(burst(0.12, 2500, 12000, dec=0.15), sum(np.concatenate([np.zeros(int(SR * rng.uniform(0, 0.25))), np.sin(2 * np.pi * rng.uniform(2500, 7500) * t(0.25)) * np.exp(-t(0.25) * 25)]) [:int(SR * 0.5)].tolist() + [0] * 0 if False else pad(np.concatenate([np.zeros(int(SR * rng.uniform(0, 0.25))), np.sin(2 * np.pi * rng.uniform(2500, 7500) * t(0.25)) * np.exp(-t(0.25) * 25)]), 0.55)[:int(SR * 0.55)] * 0.25 for _ in range(9))), 0.7)
fc = np.zeros(int(SR * 1.3))
for k in range(9):
    p = int(SR * (0.02 + k * 0.12 + rng.uniform(0, 0.05))); g = mix(burst(0.12, 300, 9000, 0.0005, 0.15, 5), thump(0.06, 300, 90, 0.6)); fc[p:p + len(g)] += g[:len(fc) - p]
save('firecracker', fc, 0.9)
save('explosion', mix(thump(0.9, 110, 28, 1.3), burst(1.6, 60, 3500, 0.002, 0.3, 3), band(noise(int(SR * 2.2)), 40, 500) * env(int(SR * 2.2), 0.05, 0.6, 2.5) * 0.7), 0.95)
save('fireball', band(noise(int(SR * 1.2)), 200, 2600) * np.linspace(0.2, 1, int(SR * 1.2)) ** 2 * (1 + 0.5 * np.sin(2 * np.pi * 23 * t(1.2))), 0.6)
save('door', mix(thump(0.2, 140, 70, 0.8), burst(0.1, 400, 3000, dec=0.2) * 0.6), 0.5)
save('pry', mix(band(noise(int(SR * 1.1)), 300, 2400) * (0.5 + 0.5 * np.sin(2 * np.pi * 37 * t(1.1))) * env(int(SR * 1.1), 0.3, 0.8, 2), np.concatenate([np.zeros(int(SR * 0.9)), thump(0.25, 160, 60, 1.2)])), 0.7)
save('engine_loop', fade_loop(norm(sum(np.sin(2 * np.pi * f * t(2.0) + 0.3 * np.sin(2 * np.pi * 9 * t(2.0))) * a for f, a in [(55, 1), (110, .6), (165, .35), (220, .2)]) + band(noise(int(SR * 2.0)), 300, 2500) * 0.25), 0.2), 0.5)

# ---- quái vật
def growl(d, f0, f1, rough=30, lo=60, hi=1400, vib=0.2):
    tt = t(d); f = f0 * (f1 / f0) ** (tt / d) * (1 + vib * np.sin(2 * np.pi * 5 * tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    car = np.sign(np.sin(ph)) * 0.5 + np.sin(ph * 2.01) * 0.4 + np.sin(ph * 0.5) * 0.6
    am = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * rough * tt + 2 * np.sin(2 * np.pi * 3 * tt)))
    x = band(car * am + noise(len(tt)) * 0.35, lo, hi)
    return x * np.sin(np.pi * tt / d) ** 0.6
save('titan_roar', mix(growl(3.6, 70, 38, 22, 30, 900), growl(3.6, 141, 60, 31, 80, 1800) * 0.5, band(noise(int(SR * 3.6)), 30, 200) * 0.5), 0.95)
save('titan_stomp', mix(thump(0.9, 75, 24, 1.4), burst(0.7, 40, 900, 0.002, 0.35, 3), grains(1.2, 40, 300, 3000, 0.04) * 0.4), 0.95)
save('titan_groan', growl(2.6, 52, 44, 14, 30, 600, 0.1), 0.7)
save('worm_rumble', fade_loop(band(noise(int(SR * 3.0)), 25, 160) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t(3.0))) + grains(3.0, 60, 200, 1500, 0.05) * 0.3, 0.3), 0.8)
save('worm_erupt', mix(thump(1.1, 90, 26, 1.3), burst(1.8, 60, 5000, 0.004, 0.35, 2.5), grains(2.2, 160, 300, 5000, 0.04) * 0.7, np.concatenate([np.zeros(int(SR * 0.3)), growl(1.6, 220, 90, 45, 150, 3000) * 0.7])), 0.95)
save('stalker_screech', mix(growl(1.1, 900, 1700, 70, 600, 7000, 0.05), growl(1.1, 1350, 2300, 90, 900, 9000) * 0.5), 0.8)
save('stalker_growl', growl(1.4, 110, 85, 38, 80, 1800, 0.08), 0.6)
save('stalker_bite', mix(burst(0.12, 800, 6000, dec=0.15), thump(0.12, 240, 90, 0.8), growl(0.35, 300, 180, 60, 200, 3000) * 0.6), 0.8)
save('flyer_shriek', mix(growl(1.5, 1500, 700, 55, 500, 8000, 0.25), growl(1.5, 2250, 1000, 75, 900, 10000, 0.25) * 0.45), 0.8)
flap = band(noise(int(SR * 0.5)), 60, 700) * np.sin(np.pi * t(0.5) / 0.5) ** 4
save('flyer_flap', flap, 0.6)
sq = np.zeros(int(SR * 1.4))
for k in range(7):
    p = int(SR * (k * 0.18 + rng.uniform(0, 0.04))); g = mix(burst(0.16, 150, 1800, 0.02, 0.5, 3), gulp(120 + 20 * k)[:int(SR * 0.16)] * 0.6); sq[p:p + len(g)] += g[:len(sq) - p]
save('grub_squelch', sq, 0.6)
save('grub_bite', mix(thump(0.3, 130, 45, 1.2), burst(0.3, 200, 3500, 0.003, 0.25), growl(0.6, 160, 90, 28, 80, 1500) * 0.6), 0.85)
sting = sum(np.sin(2 * np.pi * f * t(2.2) + 0.5 * np.sin(2 * np.pi * 6 * t(2.2))) * np.exp(-t(2.2) * 1.4) for f in (98, 104, 147, 293.5))
save('sting', mix(sting, burst(0.4, 100, 800, 0.005, 0.3) * 1.5), 0.6)
save('win', sum(np.concatenate([np.zeros(int(SR * 0.22 * k)), np.sin(2 * np.pi * f * t(1.6)) * np.exp(-t(1.6) * 2.2)])[:int(SR * 2.2)] if False else pad(np.concatenate([np.zeros(int(SR * 0.22 * k)), np.sin(2 * np.pi * f * t(1.6)) * np.exp(-t(1.6) * 2.2)]), 2.5)[:int(SR * 2.5)] for k, f in enumerate((196, 247, 294, 392))), 0.5)
print('wrote', len(os.listdir(OUT)), 'files,', round(sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT)) / 1e6, 1), 'MB')
