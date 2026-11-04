#!/usr/bin/env python3
"""Builds every placeholder sound and music track for Sengoku Battlefield.

Output layout (what the game reads):
    audio/sfx/<event_id>/TEMP_<event_id>_<n>.wav   one folder per sound event
    audio/music/TEMP_<track_id>.wav                 one file per music track

Sources:
  * tools/audio/ashigaru_synth.py - procedural generators copied unchanged from the
    ASHIGARU project (original synthesis, CC0). Used for muskets, katana, impacts,
    footsteps, pain/death voices, UI and ambience.
  * tools/audio/kengeki_sfx/      - procedurally generated placeholder WAVs copied
    from Kengeki (blade clash / block / parry / heavy swing).
  * New generators in this file   - matchlock ignition, battle cries, distant battle
    and crowd beds, objective cues, conch-horn ticket warning, music.

Everything is a placeholder (files are prefixed TEMP_). To replace a sound, drop
.wav/.ogg/.mp3 files into the event's folder and delete the TEMP_ files; no code changes.

Usage: python3 tools/audio/build_audio.py      (deterministic: fixed seeds)
"""
import json
import os
import shutil
import sys

import numpy as np
from scipy import signal
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import ashigaru_synth as A  # noqa: E402

SR = A.SR
SFX = os.path.join(ROOT, "audio", "sfx")
MUSIC = os.path.join(ROOT, "audio", "music")
MANIFEST = {}

rng, tt, noise, lp, hp, bp = A.rng, A.tt, A.noise, A.lp, A.hp, A.bp
edecay, attack, put, modal, sweep, soft = A.edecay, A.attack, A.put, A.modal, A.sweep, A.soft


# ----------------------------------------------------------------------------- output
def write(path, x, sr, peak_db=None, rms_db=None):
    x = np.asarray(x, dtype=np.float64)
    if rms_db is not None:
        x = x / (np.sqrt(np.mean(x ** 2)) + 1e-12) * 10 ** (rms_db / 20)
        peak = np.max(np.abs(x))
        if peak > 0.95:
            x = x / peak * 0.95
    elif peak_db is not None:
        x = A.norm(x, peak_db)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    wavfile.write(path, sr, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    return len(x) / sr


def sfx(event, x, peak_db=-3.0, tail=0.05, sr=SR, index=None):
    """Writes one variation of a sound event."""
    d = os.path.join(SFX, event)
    n = index if index is not None else len([f for f in os.listdir(d)]) + 1 if os.path.isdir(d) else 1
    x = A.fade_out(np.asarray(x, dtype=np.float64), tail, sr) if tail else x
    secs = write(os.path.join(d, f"TEMP_{event}_{n}.wav"), x, sr, peak_db=peak_db)
    MANIFEST.setdefault(event, []).append(round(secs, 3))


def loop_sfx(event, x, sr, rms_db):
    x = seamless(np.asarray(x, dtype=np.float64), sr)
    secs = write(os.path.join(SFX, event, f"TEMP_{event}_1.wav"), x, sr, rms_db=rms_db)
    MANIFEST.setdefault(event, []).append(round(secs, 3))


def copy_dir(src, event):
    d = os.path.join(SFX, event)
    os.makedirs(d, exist_ok=True)
    for i, f in enumerate(sorted(os.listdir(src))):
        shutil.copy(os.path.join(src, f), os.path.join(d, f"TEMP_{event}_kengeki_{i + 1}.wav"))
        MANIFEST.setdefault(event, []).append("kengeki:" + f)


def wrap(x, length):
    """Folds a buffer longer than `length` back onto its start so the result loops seamlessly."""
    out = np.zeros(length)
    for i in range(0, len(x), length):
        seg = x[i:i + length]
        out[:len(seg)] += seg
    return out


def seamless(x, sr, fade=0.12):
    """Equal-power crossfade of the tail into the head so the file loops without a click."""
    k = int(fade * sr)
    out = x[:-k].copy()
    ramp = np.linspace(0, np.pi / 2, k)
    out[:k] = x[:k] * np.sin(ramp) + x[-k:] * np.cos(ramp)
    return out


def resample(x, sr_from, sr_to):
    return signal.resample_poly(x, sr_to, sr_from)


# ----------------------------------------------------------------------------- matchlock
def make_matchlock(seed):
    """Tanegashima: the serpentine drops the lit match into the pan (soft snap + fizz),
    a short hang-fire, then the report. Built on ASHIGARU's shot core and room."""
    r = rng(seed)
    shot = A.make_shot(seed)
    lead = int(0.07 * SR)
    pre = np.zeros(lead + len(shot))
    snap = modal([1900, 3300], [0.006, 0.004], [0.4, 0.25], 0.04, r, jitter=0.05)
    put(pre, snap, 0.0, 0.35)
    fz = int(0.09 * SR)
    fizz = bp(noise(fz, r), 1800, 7500) * np.sin(np.linspace(0, np.pi, fz)) ** 1.5
    put(pre, fizz, 0.008, 0.22)
    put(pre, shot, lead / SR, 1.0)
    # extra low "thud" of the heavier Japanese bore
    put(pre, sweep(120, 38, 0.1, 0.9) * edecay(int(0.9 * SR), 0.22), lead / SR + 0.042, 0.5)
    return pre


def make_bullet_whiz(seed):
    """Near miss: supersonic-ish crack followed by a falling whistle."""
    r = rng(seed)
    n = int(0.5 * SR)
    x = np.zeros(n)
    crack = hp(noise(int(0.01 * SR), r), 1500) * edecay(int(0.01 * SR), 0.0015)
    put(x, crack, 0.0, 0.6)
    t = tt(0.4)
    f = np.interp(t, [0, 0.4], [r.uniform(2400, 3000), r.uniform(900, 1200)])
    whistle = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * t / 0.4) ** 2
    air = bp(noise(len(t), r), 1200, 5000) * np.sin(np.pi * t / 0.4) ** 2
    put(x, whistle * 0.25 + air * 0.6, 0.004)
    return x


# ----------------------------------------------------------------------------- voices
def make_battle_cry(seed):
    """A single soldier's shout: 'Ei!' / 'Oo!' / 'Yaa!' style, rough and loud."""
    r = rng(seed)
    dur = r.uniform(0.7, 1.4)
    f0 = r.uniform(150, 230)
    v0, v1 = [("e", "a"), ("o", "o"), ("a", "a"), ("a", "o"), ("u", "o")][seed % 5]
    rise = r.uniform(1.05, 1.25)
    env = lambda t, d: attack(len(t), 0.04) * np.clip(1 - (t / d) ** 3, 0, 1)
    y = A.voice(dur, f0 * rise, f0 * r.uniform(0.75, 0.95), v0, v1, 0.6, seed, env,
                rough=r.uniform(0.3, 0.5), vib=0.015)
    return soft(y, 2.6)


def crowd(seconds, sr, seed, voices, f_lo=110, f_hi=240, wet=0.5):
    """Many overlapping shouts placed cyclically, with a diffuse roar under them."""
    r = rng(seed)
    n = int(seconds * sr)
    buf = np.zeros(n + 3 * sr)
    for i in range(voices):
        v = make_battle_cry(seed * 31 + i)
        v = resample(v, SR, sr) if sr != SR else v
        put(buf, v * r.uniform(0.2, 1.0), r.uniform(0, seconds), 1.0, sr)
    roar = A.periodic_noise(seconds, A.band_shape(f_lo * 2, 1600, 2.0), seed + 7, sr)
    roar *= A.periodic_lfo(seconds, sr, [1, 2, 3, 5, 7], seed + 8, 0.6)
    out = wrap(buf, n)
    out = out / (np.std(out) + 1e-9) + roar * 0.6
    imp = A.ir(1.8, 2.2, r, 3000, 700, sr=sr)
    wet_sig = wrap(signal.fftconvolve(np.r_[out, out[:int(2.2 * sr)]], imp)[:n + int(2.2 * sr)], n)
    wet_sig *= np.std(out) / (np.std(wet_sig) + 1e-9)
    return out * (1 - wet) + wet_sig * wet


def make_distant_battle(seconds, sr, seed):
    """Far-off fighting: rolling matchlock volleys, clashing steel, a roaring crowd."""
    r = rng(seed)
    n = int(seconds * sr)
    buf = np.zeros(n + 5 * sr)
    far = [resample(A.make_shot_far(9000 + i), SR, sr) for i in range(4)]
    t = 0.0
    while t < seconds:  # volleys: clusters of shots
        k = r.integers(1, 6)
        for _ in range(k):
            put(buf, far[r.integers(0, 4)] * r.uniform(0.25, 0.8), t + r.uniform(0, 0.6), 1.0, sr)
        t += r.uniform(1.2, 4.0)
    for _ in range(int(seconds * 3)):  # steel on steel
        c = modal([r.uniform(1500, 2400), r.uniform(2800, 4200), r.uniform(5000, 6500)],
                  [0.12, 0.08, 0.05], [0.6, 0.4, 0.2], 0.4, r, sr=sr)
        put(buf, lp(c, 2600, sr=sr) * r.uniform(0.05, 0.25), r.uniform(0, seconds), 1.0, sr)
    hits = wrap(buf, n)
    hits /= np.std(hits) + 1e-9
    roar = crowd(seconds, sr, seed + 1, voices=int(seconds * 2.5), wet=0.7)
    roar = lp(roar, 1500, sr=sr)
    bed = A.periodic_noise(seconds, A.band_shape(40, 400, 3.0), seed + 2, sr) * A.periodic_lfo(seconds, sr, [1, 2, 3], seed + 3, 0.5)
    mix = hits * 0.7 + roar * 0.9 + bed * 0.5
    imp = A.ir(3.0, 3.5, r, 2000, 400, sr=sr)
    wet = wrap(signal.fftconvolve(np.r_[mix, mix[:int(3.5 * sr)]], imp)[:n + int(3.5 * sr)], n)
    wet *= np.std(mix) / (np.std(wet) + 1e-9)
    return lp(mix * 0.5 + wet * 0.7, 2200, sr=sr)


# ----------------------------------------------------------------------------- instruments
# D miyako-bushi (in) scale: D Eb G A Bb
SCALE = [146.83, 155.56, 196.00, 220.00, 233.08]


def note(degree, octave=0):
    return SCALE[degree % 5] * 2 ** (octave + degree // 5)


def koto(f, dur, r, g=1.0, sr=SR):
    """Plucked string: inharmonic partials, bright attack, darkening decay."""
    t = tt(dur, sr)
    y = np.zeros_like(t)
    for k in range(1, 9):
        fk = f * k * (1 + 0.0008 * k * k)
        y += (0.9 ** k) / k ** 0.6 * np.sin(2 * np.pi * fk * t + r.uniform(0, 6)) * np.exp(-t * (1.2 + 0.9 * k))
    pl = int(0.012 * sr)
    y[:pl] += hp(noise(pl, r), 1500, sr=sr) * np.linspace(1, 0, pl) * 0.3
    return y * g


def shakuhachi(f, dur, r, g=1.0, sr=SR):
    """Breathy end-blown flute: swelling tone, late vibrato, wind noise."""
    t = tt(dur, sr)
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.0 * t) * np.clip((t - dur * 0.35) / (dur * 0.4), 0, 1)
    bend = 1 - 0.03 * np.exp(-t / 0.08)  # meri attack: scoop into the pitch
    ph = np.cumsum(f * vib * bend) / sr
    tone = np.sin(2 * np.pi * ph) + 0.25 * np.sin(4 * np.pi * ph) + 0.08 * np.sin(6 * np.pi * ph)
    breath = bp(noise(len(t), r), f * 0.8, f * 4, sr=sr) * 0.35
    env = np.clip(t / 0.25, 0, 1) ** 1.5 * np.clip((dur - t) / 0.4, 0, 1)
    return (tone + breath) * env * g


def drum(r, f0, dur, g=1.0, sr=SR):
    y = A.taiko(r, f0, dur, g)
    return resample(y, SR, sr) if sr != SR else y


def make_menu_music(sr=32000):
    """48 s, slow and sparse: shakuhachi phrases over koto and a low drone."""
    r = rng(5100)
    L = 48.0
    n = int(L * sr)
    buf = np.zeros(n + 6 * sr)
    t = tt(L, sr)
    cyc = lambda f: round(f * L) / L  # whole cycles per loop: no seam click
    drone = (np.sin(2 * np.pi * cyc(73.42) * t) + 0.4 * np.sin(2 * np.pi * cyc(110.0) * t)) * 0.12
    drone *= 0.8 + 0.2 * np.sin(2 * np.pi * t / L * 2)
    put(buf, drone, 0.0, 1.0, sr)
    phrase = [(0, 3.5), (3, 2.0), (4, 2.5), (3, 1.5), (2, 4.5)]
    phrase2 = [(5, 3.0), (4, 2.0), (3, 2.0), (1, 2.5), (0, 5.0)]
    at = 1.5
    for ph in (phrase, phrase2):
        for deg, d in ph:
            put(buf, shakuhachi(note(deg, 1), d * 1.1, r, 0.22, sr), at, 1.0, sr)
            at += d
        at += 2.5
    for beat in range(0, 48, 3):
        deg = [0, 2, 3, 0, 4, 3, 2, 1][(beat // 3) % 8]
        put(buf, koto(note(deg), 2.8, r, 0.16, sr), beat + 0.0, 1.0, sr)
        put(buf, koto(note(deg + 2), 2.2, r, 0.09, sr), beat + 0.75, 1.0, sr)
    mix = wrap(buf, n)
    imp = A.ir(2.6, 3.0, r, 5000, 900, sr=sr)
    wet = wrap(signal.fftconvolve(np.r_[mix, mix[:3 * sr]], imp)[:n + 3 * sr], n)
    wet *= np.std(mix) / (np.std(wet) + 1e-9)
    return mix * 0.75 + wet * 0.45, sr


def make_battle_music(sr=32000):
    """32 s at 120 bpm: driving taiko patterns, koto ostinato, shakuhachi calls."""
    r = rng(5200)
    bpm = 120
    beat = 60 / bpm
    bars = 16
    L = bars * 4 * beat
    n = int(L * sr)
    buf = np.zeros(n + 4 * sr)
    big = [drum(r, 70, 1.6, 1.0, sr) for _ in range(3)]
    mid = [drum(r, 110, 1.0, 0.7, sr) for _ in range(3)]
    rim = [modal([900, 1500], [0.03, 0.02], [0.5, 0.3], 0.1, r, sr=sr) for _ in range(3)]
    pattern = "B..mB.m.B..mBmmm"  # 16 eighths per 2 beats? -> per bar of 4 beats at 8ths
    for bar in range(bars):
        for i, ch in enumerate(pattern[:8] if bar % 2 == 0 else pattern[8:]):
            at = bar * 4 * beat + i * beat / 2
            if ch == "B":
                put(buf, big[r.integers(0, 3)], at, 1.0, sr)
            elif ch == "m":
                put(buf, mid[r.integers(0, 3)], at, r.uniform(0.6, 0.9), sr)
            else:
                put(buf, rim[r.integers(0, 3)], at, 0.25, sr)
        if bar % 4 == 3:  # fill
            for k in range(4):
                put(buf, mid[k % 3], bar * 4 * beat + 3 * beat + k * beat / 4, 0.8, sr)
    osti = [0, 2, 3, 2, 4, 3, 2, 1]
    for i in range(bars * 8):
        at = i * beat / 2
        deg = osti[i % 8] + (2 if (i // 32) % 2 else 0)
        put(buf, koto(note(deg), 0.9, r, 0.12, sr), at, 1.0, sr)
    calls = [(5, 4), (4, 4), (3, 6), (2, 2)]
    at = 4 * 4 * beat
    for deg, beats in calls:
        put(buf, shakuhachi(note(deg, 1), beats * beat * 1.05, r, 0.18, sr), at, 1.0, sr)
        at += beats * beat
    at = 12 * 4 * beat
    for deg, beats in [(7, 3), (6, 1), (5, 4), (4, 8)]:
        put(buf, shakuhachi(note(deg, 0), beats * beat * 1.05, r, 0.18, sr), at, 1.0, sr)
        at += beats * beat
    t = tt(L, sr)
    cyc = lambda f: round(f * L) / L
    drone = np.sin(2 * np.pi * cyc(73.42) * t) * 0.10 + np.sin(2 * np.pi * cyc(36.71) * t) * 0.08
    put(buf, drone, 0.0, 1.0, sr)
    mix = wrap(buf, n)
    imp = A.ir(1.6, 2.0, r, 6000, 1200, sr=sr)
    wet = wrap(signal.fftconvolve(np.r_[mix, mix[:2 * sr]], imp)[:n + 2 * sr], n)
    wet *= np.std(mix) / (np.std(wet) + 1e-9)
    return soft(mix * 0.8 + wet * 0.35, 1.2), sr


def make_stinger(kind, sr=SR):
    r = rng(5300 + len(kind))
    if kind == "victory":
        x = A.make_victory(3001)
        for i, deg in enumerate([0, 2, 3, 5, 7]):
            put(x, koto(note(deg), 2.5, r, 0.35), 1.0 + i * 0.12)
        return x
    x = A.make_defeat(3002)
    for i, deg in enumerate([4, 3, 1, 0]):
        put(x, koto(note(deg, -1), 2.5, r, 0.3), 0.6 + i * 0.35)
    return x


# ----------------------------------------------------------------------------- objective & UI cues
def make_objective(kind, seed):
    r = rng(seed)
    x = np.zeros(int(2.2 * SR))
    if kind == "captured":
        put(x, A.taiko(r, 95, 1.4), 0.0, 0.9)
        for i, deg in enumerate([0, 3, 5]):
            put(x, koto(note(deg, 1), 1.8, r, 0.6), 0.05 + i * 0.09)
        put(x, modal([1046, 1568, 2637], [0.9, 0.6, 0.3], [0.4, 0.2, 0.1], 1.5, r), 0.3, 0.35)
    elif kind == "lost":
        put(x, A.taiko(r, 62, 1.8), 0.0, 1.0)
        for i, deg in enumerate([3, 1, 0]):
            put(x, koto(note(deg), 1.8, r, 0.6), 0.1 + i * 0.16)
    elif kind == "contested":
        x = np.zeros(int(0.5 * SR))
        for i in range(2):
            put(x, modal([780, 1350], [0.05, 0.03], [0.7, 0.35], 0.2, r), i * 0.13, 0.9)
    return x


def make_conch(seed):
    """Horagai (conch-shell trumpet): the Sengoku battlefield signal. Ticket warning."""
    r = rng(seed)
    dur = 1.9
    env = lambda t, d: np.clip(t / 0.25, 0, 1) ** 2 * np.clip((d - t) / 0.35, 0, 1)
    y = A.voice(dur, 228, 236, "o", "a", 0.35, seed, env, rough=0.15, vib=0.006)
    y += 0.4 * A.voice(dur, 456, 470, "o", "o", 0.2, seed + 1, env)
    y = soft(y * 1.5, 1.8)
    imp = A.ir(2.4, 2.8, r, 3500, 800)
    return A.reverb(np.r_[y, np.zeros(int(1.5 * SR))], imp, 0.5)


# ----------------------------------------------------------------------------- build
def build():
    for d in (SFX, MUSIC):
        if os.path.isdir(d):
            shutil.rmtree(d)
        os.makedirs(d)

    # --- katana (ASHIGARU generators + Kengeki clash/block/parry) ---
    for i in range(3):
        sfx("katana_swing_light", A.make_swing(1650 + i, False), -9.0)
        sfx("katana_swing_heavy", A.make_swing(1600 + i, True), -5.0)
        sfx("katana_hit", A.make_hit_flesh(1700 + i), -2.0)
    for s, i in [("soil", 0), ("wood", 1), ("stone", 2)]:
        sfx("katana_hit_world", A.make_clank(1750 + i, s), -4.0, tail=0.2)
    for i in range(2):
        sfx("katana_draw", A.make_draw(1500 + i), -6.0, tail=0.3)
    copy_dir(os.path.join(HERE, "kengeki_sfx", "clash"), "blade_clash")
    copy_dir(os.path.join(HERE, "kengeki_sfx", "block"), "blade_block")

    # --- matchlock ---
    for i in range(3):
        sfx("matchlock_fire", make_matchlock(1000 + i), -1.5, tail=0.35)
    for i in range(3):
        sfx("matchlock_fire_far", A.make_shot_far(1100 + i), -3.0, tail=0.6)
    sfx("matchlock_dry", A.make_dry_click(1200), -6.0)
    for i in range(2):
        sfx("reload_powder", A.make_powder(1310 + i), -8.0)
        sfx("reload_ball", A.make_ram_in(1320 + i), -8.0)
        sfx("reload_ram", A.make_ram_tamp(1330 + i), -6.0)
        sfx("reload_prime", A.make_prime(1340 + i), -7.0)
        sfx("reload_match", A.make_cock(1350 + i), -5.0)
    sfx("weapon_raise", A.make_raise(1400), -7.0)
    sfx("weapon_lower", A.make_lower(1401), -9.0)
    for i in range(3):
        sfx("bullet_whiz", make_bullet_whiz(1900 + i), -6.0, tail=0.1)
    for i in range(2):
        sfx("bullet_hit_flesh", A.make_bullet_impact(1800 + i + 50, "flesh"), -3.0, tail=0.2)
    for i in range(3):
        sfx("bullet_hit_ground", A.make_bullet_impact(1800 + i + 40, "soil"), -3.0, tail=0.2)
        sfx("bullet_hit_wood", A.make_bullet_impact(1800 + i + 40, "wood"), -3.0, tail=0.2)

    # --- body ---
    for i in range(5):
        sfx("footstep", A.make_step(2000 + i + 30 * 4 + ord("s"), "soil"), -7.0, tail=0.1)
    for i in range(2):
        sfx("land", A.make_land(2200 + i + ord("s"), "soil"), -4.0, tail=0.15)
    for i in range(3):
        sfx("hurt", A.make_pain(2400 + i * 7), -5.0)
    for i in range(3):
        sfx("death_cry", A.make_death(2500 + i * 11), -3.0, tail=0.3)
    sfx("body_fall", A.make_body_fall(2600), -3.0, tail=0.2)
    sfx("respawn", A.make_respawn(2700), -9.0, tail=0.2)
    for i in range(8):
        sfx("battle_cry", make_battle_cry(4000 + i), -3.0, tail=0.15)

    # --- UI & match ---
    for k in ("hover", "click", "confirm", "back"):
        sfx("ui_" + k, A.make_ui(k, 2800 + len(k)), -8.0 if k == "hover" else -5.0)
    sfx("capture_tick", A.make_ui("tick", 2804), -10.0)
    sfx("hit_marker", A.make_confirm_hit(2900, "hit"), -6.0)
    sfx("kill_marker", A.make_confirm_hit(2902, "kill"), -3.0, tail=0.2)
    sfx("match_start", A.make_match_start(3000), -3.0, tail=0.5)
    sfx("objective_captured", make_objective("captured", 4100), -3.0, tail=0.4)
    sfx("objective_lost", make_objective("lost", 4101), -3.0, tail=0.4)
    sfx("objective_contested", make_objective("contested", 4102), -6.0, tail=0.05)
    sfx("ticket_warning", make_conch(4200), -3.0, tail=0.6)

    # --- ambience ---
    for v in range(6):
        sfx("amb_bird", A.make_bird(3100 + v, v), -10.0, tail=0.3)
    sfx("amb_gust", A.make_wind_gust(3300), -14.0, tail=0.5)
    sr = 24000
    L = 24
    wind = A.periodic_noise(L, A.band_shape(90, 700, 2.4), 11, sr) * A.periodic_lfo(L, sr, [1, 2, 3, 5], 12, 0.7)
    wind += A.periodic_noise(L, A.band_shape(700, 2600, 2.0), 13, sr) * 0.35 * A.periodic_lfo(L, sr, [2, 3, 4], 14, 0.9)
    loop_sfx("amb_wind_loop", wind, sr, -24)
    sr2 = 32000
    grass = A.periodic_noise(28, A.band_shape(2200, 9000, 1.6), 21, sr2) * A.periodic_lfo(28, sr2, [1, 2, 4, 6], 23, 0.6)
    loop_sfx("amb_field_loop", grass, sr2, -30)
    loop_sfx("battle_distant_loop", make_distant_battle(30, 24000, 6000), 24000, -22)
    loop_sfx("battle_crowd_loop", crowd(20, 24000, 6100, voices=40, wet=0.5), 24000, -24)

    # --- music ---
    menu, msr = make_menu_music()
    MANIFEST["music_menu"] = round(write(os.path.join(MUSIC, "TEMP_menu.wav"), seamless(menu, msr), msr, rms_db=-20), 3)
    battle, bsr = make_battle_music()
    MANIFEST["music_battle"] = round(write(os.path.join(MUSIC, "TEMP_battle.wav"), seamless(battle, bsr, 0.01), bsr, rms_db=-19), 3)
    MANIFEST["music_victory"] = round(write(os.path.join(MUSIC, "TEMP_victory.wav"), make_stinger("victory"), SR, peak_db=-3), 3)
    MANIFEST["music_defeat"] = round(write(os.path.join(MUSIC, "TEMP_defeat.wav"), make_stinger("defeat"), SR, peak_db=-3), 3)

    with open(os.path.join(ROOT, "audio", "manifest.json"), "w") as f:
        json.dump(MANIFEST, f, indent=1, sort_keys=True)
    events = [k for k in MANIFEST if not k.startswith("music_")]
    print(f"{len(events)} sound events, 4 music tracks -> {os.path.relpath(SFX, ROOT)}, {os.path.relpath(MUSIC, ROOT)}")


if __name__ == "__main__":
    build()
