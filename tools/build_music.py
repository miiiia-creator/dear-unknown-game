#!/usr/bin/env python3
"""Turn a downloaded track into a loop the game can leave running.

Music written as a piece has an ending; music for a game people leave open for
an hour must not. This takes the source file, drops the outro, and folds the
end of what is left back over the beginning so that the wrap point sits inside
continuous material rather than between a silence and a downbeat.

The construction, for a body of length T and an overlap X:

    loop[i] = body[i]                                   for i in [X, T-X)
    loop[i] = body[i]*a(i) + body[T-X+i]*(1-a(i))       for i in [0, X)

with a() an equal-power ramp from 0 to 1. Playing off the end of the loop
lands on loop[0], which is exactly body[T-X] — the sample that followed it in
the original recording. Nothing is spliced; the first seconds simply dissolve
from the old tail into the old head.

Run:  python3 tools/build_music.py [--body SECONDS] [--overlap SECONDS] [--quality N]
"""

from __future__ import annotations

import argparse
import glob
import os
import subprocess
import sys
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "assets", "music")
OUT = os.path.join(SRC_DIR, "theme.ogg")


def ffmpeg():
    for c in ("/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg",
              "/usr/local/opt/ffmpeg-full/bin/ffmpeg", "ffmpeg"):
        try:
            subprocess.run([c, "-version"], capture_output=True, check=True)
            return c
        except (OSError, subprocess.CalledProcessError):
            continue
    sys.exit("No ffmpeg found.")


def read_source(path, tmp_wav, ff):
    """Decode whatever was handed to us into float32 stereo at its own rate."""
    if not path.lower().endswith(".wav"):
        subprocess.run([ff, "-v", "error", "-y", "-i", path, tmp_wav], check=True)
        path = tmp_wav
    with wave.open(path) as w:
        sr, ch, n = w.getframerate(), w.getnchannels(), w.getnframes()
        raw = np.frombuffer(w.readframes(n), dtype=np.int16)
    return raw.astype(np.float32).reshape(-1, ch) / 32768.0, sr


def envelope_db(mono, sr, win_s=0.5):
    win = int(sr * win_s)
    frames = len(mono) // win
    env = np.sqrt((mono[:frames * win].reshape(frames, win) ** 2).mean(axis=1))
    return 20 * np.log10(np.maximum(env, 1e-9)), win


def find_body_end(mono, sr):
    """Last moment the track is still at full strength, before the outro."""
    db, win = envelope_db(mono, sr)
    level = float(np.median(db[:len(db) // 2]))
    # Walk back from the end until the music is within 2 dB of its own body.
    for i in range(len(db) - 1, 0, -1):
        if db[i] > level - 2.0:
            return (i + 1) * win / sr, level
    return len(mono) / sr, level


def make_loop(audio, sr, body_s, overlap_s):
    body = audio[:int(body_s * sr)]
    x = int(overlap_s * sr)
    if x * 2 >= len(body):
        sys.exit("Overlap is too long for the body.")
    loop = body[:len(body) - x].copy()
    ramp = np.sqrt(np.linspace(0.0, 1.0, x, dtype=np.float32))[:, None]
    loop[:x] = body[:x] * ramp + body[len(body) - x:] * ramp[::-1]
    return loop


def seam_report(loop, sr):
    mono = loop.mean(axis=1)
    step = abs(float(mono[0]) - float(mono[-1]))
    typical = float(np.abs(np.diff(mono)).mean())
    head = mono[:sr // 2]
    tail = mono[-sr // 2:]

    def db(x):
        return 20 * np.log10(max(float(np.sqrt((x ** 2).mean())), 1e-9))

    print("  loop %.1fs" % (len(loop) / sr))
    print("  head %.1f dB   tail %.1f dB   (gap %.1f dB)"
          % (db(head), db(tail), abs(db(head) - db(tail))))
    print("  seam step %.5f vs typical %.5f  ->  %s"
          % (step, typical, "audible click" if step > typical * 8 else "smooth"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--body", type=float, default=None,
                    help="seconds of the source to keep (default: measured)")
    ap.add_argument("--overlap", type=float, default=4.0)
    ap.add_argument("--quality", type=int, default=3,
                    help="Vorbis quality, 0-10; 3 is about 112 kbps")
    args = ap.parse_args()

    sources = [p for p in glob.glob(os.path.join(SRC_DIR, "*"))
               if os.path.splitext(p)[1].lower() in (".wav", ".mp3", ".m4a", ".aiff", ".flac")]
    if not sources:
        sys.exit("Put the track in assets/music/ first.")
    src = max(sources, key=os.path.getsize)
    print("source: %s (%.1f MB)" % (os.path.basename(src), os.path.getsize(src) / 1048576))

    ff = ffmpeg()
    tmp_wav = os.path.join(SRC_DIR, ".decoded.wav")
    audio, sr = read_source(src, tmp_wav, ff)
    mono = audio.mean(axis=1)

    measured, level = find_body_end(mono, sr)
    body_s = args.body if args.body else measured
    print("body level %.1f dB, outro starts at %.1fs, using %.1fs"
          % (level, measured, body_s))

    loop = make_loop(audio, sr, body_s, args.overlap)
    print("\nloop:")
    seam_report(loop, sr)

    tmp_loop = os.path.join(SRC_DIR, ".loop.wav")
    with wave.open(tmp_loop, "w") as w:
        w.setnchannels(loop.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes((np.clip(loop, -1.0, 1.0) * 32767).astype(np.int16).tobytes())

    subprocess.run([ff, "-v", "error", "-y", "-i", tmp_loop,
                    "-c:a", "libvorbis", "-q:a", str(args.quality), OUT], check=True)
    for p in (tmp_wav, tmp_loop):
        if os.path.exists(p):
            os.remove(p)

    size = os.path.getsize(OUT)
    print("\nwrote %s" % os.path.relpath(OUT, ROOT))
    print("  %.2f MB at Vorbis q%d — this is fetched after the game is on screen,"
          % (size / 1048576, args.quality))
    print("  so it costs nobody a longer wait at the loading bar.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
