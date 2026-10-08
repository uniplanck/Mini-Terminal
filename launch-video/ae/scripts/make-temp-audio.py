#!/usr/bin/env python3
"""TEMP music + SFX for the launch-film preview (placeholder only, replace before release).

Synthesised locally (no samples, no licensed material), 48 kHz stereo 16-bit, 18.0 s.
Event times come from planning/timeline.json so the hits line up with the AE build:
120 BPM grid, key impact at S02 press.impactFrame, S03 typing schedule, run/copy/click cues.

Usage: python3 -I ae/scripts/make-temp-audio.py   ->  assets/audio/temp/temp_mix.wav
"""
import json, math, os, random, struct, wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
T = json.load(open(os.path.join(ROOT, "planning", "timeline.json"), encoding="utf-8"))
SR = 48000
N = int(T["duration"] * SR)
L = [0.0] * N
R = [0.0] * N
rng = random.Random(7)
shots = {s["id"]: s for s in T["shots"]}
beat = T["beatSeconds"]


def add(t0, samples, gain=1.0, pan=0.0):
    i0 = int(t0 * SR)
    gl, gr = gain * (1 - max(0, pan)), gain * (1 + min(0, pan))
    for k, v in enumerate(samples):
        i = i0 + k
        if 0 <= i < N:
            L[i] += v * gl
            R[i] += v * gr


def env(n, a, d):  # attack/decay in samples, exponential decay
    return [min(1.0, k / max(1, a)) * math.exp(-k / max(1, d)) for k in range(n)]


def kick(t):
    n = int(0.35 * SR)
    out, ph = [], 0.0
    for k in range(n):
        f = 45 + 90 * math.exp(-k / (0.03 * SR))
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * math.exp(-k / (0.12 * SR)))
    add(t, out, 0.55)


def noise_burst(t, dur, decay, gain, hp=0.0, pan=0.0):
    n = int(dur * SR)
    out, prev, lp = [], 0.0, 0.0
    for k in range(n):
        x = rng.uniform(-1, 1)
        y = x - prev * hp  # crude high-pass
        prev = x
        out.append(y * math.exp(-k / (decay * SR)))
    add(t, out, gain, pan)


def hat(t, gain=0.08):
    noise_burst(t, 0.05, 0.012, gain, hp=0.95, pan=0.2)


def tone(t, freq, dur, gain, a=0.005, d=None, pan=0.0, glide=0.0):
    n = int(dur * SR)
    d = d or dur * 0.4
    out, ph = [], 0.0
    for k in range(n):
        f = freq * (1 + glide * k / n)
        ph += 2 * math.pi * f / SR
        out.append(math.sin(ph) * min(1.0, k / (a * SR)) * math.exp(-k / (d * SR)))
    add(t, out, gain, pan)


def swoosh(t, dur=0.25, gain=0.12):
    n = int(dur * SR)
    out, lp = [], 0.0
    for k in range(n):
        p = k / n
        c = 0.02 + 0.25 * p          # opening low-pass
        lp += c * (rng.uniform(-1, 1) - lp)
        out.append(lp * math.sin(math.pi * p))
    add(t, out, gain * 3)


def click(t, gain=0.18):
    noise_burst(t, 0.012, 0.002, gain, hp=0.6)
    tone(t, 2400, 0.02, gain * 0.4, a=0.0005, d=0.004)


def key_impact(t):
    noise_burst(t, 0.03, 0.004, 0.35, hp=0.4)
    tone(t, 180, 0.12, 0.25, a=0.001, d=0.03)


def pad():
    # A minor colour, slow swell; pad continues under the break and dies at 18.0.
    freqs = [110.0, 164.81, 220.0, 261.63]
    for f in freqs:
        ph = rng.random() * 6.28
        for i in range(N):
            t = i / SR
            amp = min(1.0, t / 1.2) * (1.0 if t < 17.4 else max(0.0, (18.0 - t) / 0.6))
            ph += 2 * math.pi * f * (1 + 0.002 * math.sin(t * 0.7)) / SR
            v = math.sin(ph) * amp * 0.035
            L[i] += v
            R[i] += v * 0.96


def bass(t, f, dur):
    tone(t, f, dur, 0.16, a=0.004, d=dur * 0.6)


pad()
impact = shots["S02"]["start"] + shots["S02"]["press"]["impactFrame"] / T["fps"]
# Intro: hi-hats only (beat 1–4), then the music proper starts on the key impact.
t = 0.0
while t < impact - 0.01:
    hat(t, 0.05)
    t += beat / 2
key_impact(impact)
kick(impact)
roots = [55.0, 43.65, 65.41, 49.0]  # Am F C G, one per bar
music_end = shots["S07"]["end"]
b = 0
t = shots["S02"]["end"]
while t < music_end - 0.01:
    kick(t)
    hat(t + beat / 2, 0.07)
    hat(t, 0.04)
    if b % 2 == 0:
        bass(t, roots[(b // 4) % 4], beat * 1.8)
    b += 1
    t += beat

# S03: panel appears, typing ticks on the AE typing schedule, run.
s3 = shots["S03"]; e3 = s3["events"]
swoosh(s3["start"] - 0.05, 0.18, 0.06)
tt = s3["start"] + e3["typeStart"]
for ch in "git rev-parse --short HEAD":
    noise_burst(tt, 0.01, 0.0025, 0.05, hp=0.5)
    tt += (e3["spaceFrames"] if ch == " " else e3["typeFrames"]) / T["fps"]
click(s3["start"] + e3["execute"], 0.2)
tone(s3["start"] + e3["execute"] + 0.04, 1320, 0.15, 0.06, d=0.05)

# S04: select + ⌘C, summon, run, copy rise.
s4 = shots["S04"]; e4 = s4["events"]
click(s4["start"] + e4["chips"][0]["at"], 0.16)
swoosh(s4["start"] + e4["summon"] - 0.06, 0.2, 0.08)
tone(s4["start"] + e4["summon"] + 0.02, 1320, 0.12, 0.06, d=0.04)
for k, w in enumerate(e4["words"]["at"]):
    tone(s4["start"] + w, [880, 1108.7, 1318.5][k], 0.18, 0.05, d=0.08)

# S05: split click, run, result.
s5 = shots["S05"]; e5 = s5["events"]
click(s5["start"] + e5["click"], 0.18)
click(s5["start"] + e5["execute"], 0.2)
tone(s5["start"] + e5["execute"] + 0.03, 1320, 0.15, 0.06, d=0.05)

# S06: history click, short low warning (not alarming) on the dialog cut.
s6 = shots["S06"]; e6 = s6["events"]
click(s6["start"] + e6["click"], 0.18)
tone(s6["start"] + e6["cut"], 220, 0.35, 0.10, a=0.01, d=0.15)
tone(s6["start"] + e6["cut"], 233.1, 0.35, 0.06, a=0.01, d=0.15)

# S07: riser into the break at S08.
s7 = shots["S07"]
n = int((s7["end"] - s7["start"]) * SR)
riser, lp = [], 0.0
for k in range(n):
    p = k / n
    lp += (0.01 + 0.3 * p * p) * (rng.uniform(-1, 1) - lp)
    riser.append(lp * p * p)
add(s7["start"], riser, 0.5)
tone(s7["end"], 440, 1.6, 0.05, a=0.02, d=0.8)

peak = max(max(abs(v) for v in L), max(abs(v) for v in R))
g = 0.89 / peak if peak > 0 else 1.0
out_dir = os.path.join(ROOT, "assets", "audio", "temp")
os.makedirs(out_dir, exist_ok=True)
path = os.path.join(out_dir, "temp_mix.wav")
with wave.open(path, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(b"".join(struct.pack("<hh", int(L[i] * g * 32767), int(R[i] * g * 32767)) for i in range(N)))
print(f"wrote {path} ({T['duration']}s, impact at {impact:.3f}s, peak normalised to -1 dBFS)")
