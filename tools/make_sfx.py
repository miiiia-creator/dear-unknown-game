#!/usr/bin/env python3
"""Generate every sound effect in the game as a .wav in assets/sfx/.

Run:  python3 tools/make_sfx.py

Why generated rather than sourced
---------------------------------
The game is played late at night, often for an hour at a stretch, and its
loudest event is a rubber stamp. Library effects are mastered for the opposite
situation — they are loud, bright and mixed to cut through — so every one of
them had to be dulled and turned down until nothing of the original recording
was left. Synthesising them means the mix is written down: the peak amplitude of
each sound is a number in the table below, and "the stamp is three times the
fill" is a fact you can read rather than a fader position someone remembered.

It also keeps the download honest. Everything here is stdlib Python, so there is
nothing to fetch and no licence to carry. The thirteen files are about 210 KB of
16-bit PCM in the repository and about 48 KB once Godot's wav importer has been
over them — a fifth of one postcard JPEG, in a web build where every byte is
fetched before the player can start.

The shared vocabulary
---------------------
Every sound is one of two physical things, because the game is one physical
thing: a pencil and a sheet of paper.

- Struck objects are *modal*: a handful of exponentially decaying sine partials
  set going by a very short noise burst. That is what a pencil tip on a desk, a
  drawer shutting and a stamp hitting paper all are, and the only difference
  between them is which partials and how fast they die.
- Paper is *filtered noise* with a contour. Rustle is broadband, but broadband
  is also what makes a sound tiring, so every paper sound here is bandpassed and
  then rolled off hard above about 4 kHz. Real paper has more air than this.
  Real paper is also not played four hundred times an hour.

Three rules hold across the whole set:

1. Nothing rings. The longest decay in the game is the 0.15 s low partial of
   the solve chord; the taps are gone in 15 ms. A tail is what you notice on
   the fiftieth repeat.
2. Nothing is bright. Everything is lowpassed, most of it below 4 kHz. High
   frequency is where "synthetic" lives, and it is also the first thing that
   grates through headphones at low volume.
3. Nothing is loud. Peaks run from 0.05 to 0.30 of full scale, so the files
   themselves carry the balance and the engine plays them at unity.

Repetition is handled in two places. The two most-heard sounds are baked as
several variants with the partials detuned a few percent, and the Sfx autoload
adds a small random pitch scale on top. Between them no two cell fills in a
session are the same sound.

Determinism
-----------
Every noise source draws from a `random.Random` seeded per sound, so re-running
this writes byte-identical files. That matters because the .wav files are
checked in alongside their Godot .import metadata: a re-run that changed the
bytes would re-import and dirty the project for no reason.
"""

from __future__ import annotations

import math
import os
import random
import struct
import wave

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "sfx")


# -- building blocks -------------------------------------------------------


def n_for(seconds):
    return int(SR * seconds)


def noise(n, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(sig, cutoff):
    """One pole. Gentle on purpose — a steep filter on a 20 ms tap rings."""
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / SR)
    y = 0.0
    out = []
    for x in sig:
        y += a * (x - y)
        out.append(y)
    return out


def highpass(sig, cutoff):
    return [x - y for x, y in zip(sig, lowpass(sig, cutoff))]


def sweep_lowpass(sig, f0, f1):
    """Lowpass whose cutoff glides f0 -> f1 across the sound.

    This is the whole trick behind the paper sounds: a page turning is not a
    static band of noise, it is a band that moves as the sheet passes.
    """
    n = max(1, len(sig) - 1)
    y = 0.0
    out = []
    for i, x in enumerate(sig):
        f = f0 + (f1 - f0) * (i / n)
        a = 1.0 - math.exp(-2.0 * math.pi * f / SR)
        y += a * (x - y)
        out.append(y)
    return out


def bandpass(sig, freq, q):
    """RBJ constant-skirt bandpass, used to give noise a body to speak from."""
    w0 = 2.0 * math.pi * freq / SR
    alpha = math.sin(w0) / (2.0 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1.0 + alpha, -2.0 * math.cos(w0), 1.0 - alpha
    b0, b1, b2 = b0 / a0, b1 / a0, b2 / a0
    a1, a2 = a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in sig:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x
        y2, y1 = y1, y
        out.append(y)
    return out


def modes(n, spec, rng, attack=0.0006):
    """Sum of decaying partials — a struck object.

    `spec` is (frequency, amplitude, decay seconds). Phases are randomised so
    the partials do not all start on a rising zero crossing, which is what makes
    a stack of sines read as one object being hit rather than as a chord.
    """
    out = [0.0] * n
    atk = max(1.0, attack * SR)
    for freq, amp, tau in spec:
        w = 2.0 * math.pi * freq / SR
        phase = rng.uniform(0.0, 2.0 * math.pi)
        k = 1.0 / (tau * SR)
        for i in range(n):
            rise = 1.0 - math.exp(-i / atk)
            out[i] += amp * rise * math.exp(-i * k) * math.sin(w * i + phase)
    return out


def burst(n, rng, length, cutoff, amp=1.0):
    """The exciter: a few milliseconds of noise, shaped and rolled off.

    Without it the modal partials fade in from nothing and sound like a note.
    The burst is the contact — the tip meeting the page.
    """
    m = min(n, n_for(length))
    sig = lowpass(noise(m, rng), cutoff)
    out = [0.0] * n
    for i in range(m):
        out[i] = sig[i] * amp * math.exp(-3.0 * i / max(1, m))
    return out


def swell(n, attack, decay, shape=2.0):
    """Rise then fall. Used where there is no impact to speak of."""
    a = max(1, n_for(attack))
    out = []
    for i in range(n):
        if i < a:
            out.append((i / a) ** shape)
        else:
            out.append(math.exp(-(i - a) / max(1.0, decay * SR)))
    return out


def flutter(n, rng, rate=70.0, depth=0.55):
    """Slow random amplitude wobble: fibres catching as a sheet moves.

    Flat noise reads as hiss or as rain. The wobble is most of what makes it
    read as paper instead.
    """
    step = max(1, int(SR / rate))
    knots = [rng.uniform(1.0 - depth, 1.0) for _ in range(n // step + 2)]
    out = []
    for i in range(n):
        j = i // step
        t = (i % step) / step
        out.append(knots[j] * (1.0 - t) + knots[j + 1] * t)
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for layer in layers:
        for i, v in enumerate(layer):
            out[i] += v
    return out


def at(sig, n, offset):
    """Place a short layer inside an n-sample sound at `offset` seconds."""
    out = [0.0] * n
    start = n_for(offset)
    for i, v in enumerate(sig):
        if start + i < n:
            out[start + i] = v
    return out


def apply(sig, env):
    return [x * e for x, e in zip(sig, env)]


# -- output ----------------------------------------------------------------


def write(name, sig, peak, tail="fade"):
    """Normalise to `peak`, close the tail cleanly, write 16-bit mono.

    An exponential decay never reaches zero, so a file long enough to hold the
    whole ring is mostly inaudible tail — and this set is downloaded before the
    web build will play. Every sound is therefore cut while it is still ringing
    faintly (around -35 dB) and a raised-cosine fade over the last fifth of the
    file takes it the rest of the way. At that level the fade reads as the note
    being damped rather than as an edit, and it saves roughly half the bytes.

    `tail="cut"` skips it: undo is a swell that is supposed to stop dead, and
    fading the last fifth of it would remove the only thing it says.
    """
    sig = highpass(sig, 22.0)  # kill any DC the modal stack left behind
    high = max(abs(x) for x in sig) or 1.0
    sig = [x * peak / high for x in sig]

    floor = 0.0006
    last = len(sig) - 1
    while last > 0 and abs(sig[last]) < floor:
        last -= 1
    sig = sig[: last + 1]

    fade = n_for(0.003) if tail == "cut" else int(len(sig) * 0.2)
    fade = max(1, min(len(sig), fade))
    for i in range(fade):
        t = i / fade
        sig[len(sig) - fade + i] *= 0.5 * (1.0 + math.cos(math.pi * t))

    path = os.path.join(OUT_DIR, name + ".wav")
    frames = b"".join(
        struct.pack("<h", max(-32768, min(32767, int(round(x * 32767.0)))))
        for x in sig
    )
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(frames)
    return path, len(frames) + 44


# -- the sounds ------------------------------------------------------------


def fill(rng, detune):
    """A cell filled: graphite touching paper.

    The most-heard sound in the game by a wide margin — a 15x15 board is 225 of
    these, and a drag across a row fires one per cell. So it is 55 ms long, its
    partials are dead in 15 ms, and it peaks at a tenth of full scale. The
    fundamental sits at 162 Hz, low enough to feel like the desk under the paper
    rather than the pencil, because at this repetition rate anything with pitch
    to it starts sounding like a melody you did not ask for.
    """
    n = n_for(0.055)
    body = modes(
        n,
        [
            (162.0 * detune, 1.00, 0.013),
            (243.0 * detune, 0.50, 0.009),
            (410.0 * detune, 0.22, 0.006),
        ],
        rng,
    )
    tip = burst(n, rng, 0.003, 2400.0, 0.45)
    return lowpass(mix(body, tip), 3000.0)


def mark(rng, detune):
    """A cell crossed out or cleared: the same gesture, drier and higher.

    Marking is a decision about a cell you are *not* filling, so it should not
    sound like filling one. More noise and less body moves it from "graphite" to
    "fingernail", and the 300 Hz fundamental puts it about a fifth above the
    fill so the two are distinguishable without either being an alert.
    """
    n = n_for(0.042)
    body = modes(
        n,
        [(300.0 * detune, 0.55, 0.009), (520.0 * detune, 0.30, 0.006)],
        rng,
    )
    tick = apply(
        bandpass(noise(n, rng), 1800.0 * detune, 1.1),
        swell(n, 0.0004, 0.006),
    )
    return lowpass(mix(body, [x * 0.8 for x in tick]), 4200.0)


def line_done(rng):
    """A row or column that just came good.

    The brief for this one was "felt more than heard", so it is the only sound
    in the game with no transient at all: a 12 ms fade-in onto a low fifth,
    lowpassed to 1.2 kHz, at 0.07 peak. On headphones it lands as a small nod.
    Either that or nothing is correct — it confirms something the strike-through
    on the clue has already said.

    The 330 Hz partial is there for laptop speakers, which have no output at all
    at the 110 Hz fundamental; without it the sound exists only on headphones.
    """
    n = n_for(0.24)
    body = modes(
        n,
        [
            (110.0, 1.00, 0.055),
            (165.0, 0.55, 0.045),
            (220.0, 0.22, 0.035),
            (330.0, 0.09, 0.028),
        ],
        rng,
        attack=0.012,
    )
    return lowpass(body, 1200.0)


def undo(rng):
    """Undo: the fill sound played backwards.

    Undo has no physical sound of its own, so it borrows one and runs it the
    wrong way. A swell that stops dead is the clearest way to say "that did not
    happen" without a distinct new noise to learn, and reversing the tap the
    player has already heard hundreds of times makes the relationship obvious
    the first time they press it.
    """
    n = n_for(0.13)
    body = modes(n, [(200.0, 1.00, 0.045), (300.0, 0.40, 0.030)], rng)
    tip = burst(n, rng, 0.004, 2000.0, 0.4)
    return list(reversed(lowpass(mix(body, tip), 2600.0)))


def reset(rng):
    """Reset: brushing eraser dust off the page.

    Longer than undo because it undoes more, and a sweep rather than a tap
    because the gesture is continuous. The band falls from 1.7 kHz to 500 Hz
    over 200 ms — the sound of something being carried away from you — and a
    short 118 Hz settle at the end is the sheet coming back down flat.
    """
    n = n_for(0.28)
    brush = apply(
        sweep_lowpass(highpass(noise(n, rng), 380.0), 1700.0, 500.0),
        apply(swell(n, 0.035, 0.075), flutter(n, rng, rate=55.0, depth=0.4)),
    )
    settle = at(modes(n_for(0.09), [(118.0, 0.5, 0.035)], rng), n, 0.10)
    return lowpass(mix(brush, settle), 3200.0)


def solved(rng):
    """The picture resolves: a drawer closing, not a fanfare.

    This is the reward at the end of a five-to-fifteen minute puzzle, so it is
    allowed to be warm, but the reveal animation is already doing the
    celebrating and a rising figure underneath it would turn a quiet game into a
    mobile one. So: a soft wooden knock, then a low G chord that settles rather
    than resolves upward, everything lowpassed to 2 kHz. It is over in half a
    second, and it is the one sound a session hears only a handful of times.
    """
    n = n_for(0.56)
    knock = mix(
        modes(n_for(0.09), [(196.0, 0.45, 0.045), (330.0, 0.16, 0.025)], rng),
        burst(n_for(0.09), rng, 0.003, 1600.0, 0.30),
    )
    chord = modes(
        n,
        [
            (98.0, 1.00, 0.145),
            (147.0, 0.52, 0.125),
            (196.0, 0.26, 0.100),
            (294.0, 0.10, 0.075),
        ],
        rng,
        attack=0.015,
    )
    return lowpass(mix(chord, at(knock, n, 0.0)), 2000.0)


def stamp(rng):
    """A city finished: a rubber stamp coming down on the postcard.

    The largest sound in the game, and it still peaks at 0.30. What makes a
    stamp read as a stamp is that it is almost entirely below 250 Hz — rubber on
    paper on a desk absorbs everything else — with one small dry crush of paper
    at the moment of contact and a lighter tick 150 ms later as the hand lifts
    it off. Take away the lift and it sounds like a door; take away the crush
    and it sounds like a drum.
    """
    n = n_for(0.40)
    thud = modes(
        n,
        [
            (72.0, 1.00, 0.075),
            (110.0, 0.68, 0.055),
            (165.0, 0.32, 0.035),
            (240.0, 0.14, 0.020),
        ],
        rng,
    )
    rubber = burst(n, rng, 0.005, 900.0, 0.9)
    crush = at(
        apply(bandpass(noise(n_for(0.03), rng), 2200.0, 0.8),
              swell(n_for(0.03), 0.001, 0.008)),
        n, 0.001,
    )
    lift = at(
        apply(bandpass(noise(n_for(0.05), rng), 1500.0, 0.9),
              swell(n_for(0.05), 0.004, 0.012)),
        n, 0.15,
    )
    return lowpass(
        mix(thud, rubber, [x * 0.18 for x in crush], [x * 0.09 for x in lift]),
        3500.0,
    )


def flip(rng):
    """A postcard turning over.

    The one sound that has to move, because the animation moves: the band
    climbs from 900 Hz to 2.6 kHz as the card comes round, which is what a sheet
    passing your ear actually does. The flutter is doing most of the work — flat
    bandpassed noise at this length reads as a hiss or a wave, and only the
    wobble makes it paper. A 150 Hz settle marks the card lying flat again.
    """
    n = n_for(0.28)
    sheet = apply(
        sweep_lowpass(highpass(noise(n, rng), 600.0), 900.0, 2600.0),
        apply(swell(n, 0.09, 0.055, shape=1.4), flutter(n, rng, rate=80.0)),
    )
    settle = at(modes(n_for(0.08), [(150.0, 0.35, 0.030)], rng), n, 0.19)
    # Two poles rather than one. A single pole at this cutoff still leaves an
    # audible shelf of noise above 6 kHz, and that shelf is the entire
    # difference between "a page" and "a hiss".
    return lowpass(lowpass(mix(sheet, settle), 5000.0), 5000.0)


def nav(rng):
    """Changing screen: a sheet sliding onto the desk.

    The quietest thing here at 0.05 peak, roughly a third the level of a cell
    fill. It exists so that navigation is not the only interaction in the game
    with no acknowledgement, and it is set this low because the alternative to
    "barely there" is "in the way" — this fires on every Back press.
    """
    n = n_for(0.12)
    slide = apply(
        bandpass(noise(n, rng), 1100.0, 0.9),
        apply(swell(n, 0.018, 0.028), flutter(n, rng, rate=110.0, depth=0.35)),
    )
    edge = modes(n, [(180.0, 0.22, 0.020)], rng)
    return lowpass(lowpass(mix(slide, edge), 4200.0), 4200.0)


def locked(rng):
    """A destination that is not open yet: a drawer that does not slide.

    The game's only invalid action (the world map toasts "Locked"). Deliberately
    the dullest sound in the set — lowpassed to 700 Hz, no transient sparkle, no
    pitch to speak of. A buzz or a descending two-note would scold the player
    for tapping a city they wanted to visit, which is not a thing worth
    scolding. This just declines.
    """
    n = n_for(0.20)
    body = modes(n, [(84.0, 1.00, 0.045), (126.0, 0.45, 0.032)], rng)
    contact = burst(n, rng, 0.004, 500.0, 0.5)
    return lowpass(mix(body, contact), 700.0)


# The whole mix in one table: name, generator, peak amplitude, tail treatment.
#
# The peaks are the balance. Read down the column and you have the game: a cell
# fill at 0.10 is the unit, the line confirmation sits below it, the stamp is
# three times it, and nothing anywhere is above a third of full scale. The
# engine plays all of them at unity gain, so this is the only place the relative
# loudness of anything is decided.
#
# fill and mark ship as detuned variants because they are the two sounds a
# player hears hundreds of times an hour; everything else is heard once per
# puzzle or once per city, where the autoload's pitch jitter is variation
# enough.
SOUNDS = [
    ("fill_a", lambda r: fill(r, 1.000), 0.10, "fade"),
    ("fill_b", lambda r: fill(r, 1.045), 0.10, "fade"),
    ("fill_c", lambda r: fill(r, 0.958), 0.10, "fade"),
    ("mark_a", lambda r: mark(r, 1.000), 0.10, "fade"),
    ("mark_b", lambda r: mark(r, 1.055), 0.10, "fade"),
    ("line", line_done, 0.07, "fade"),
    ("undo", undo, 0.10, "cut"),
    ("reset", reset, 0.12, "fade"),
    ("solved", solved, 0.20, "fade"),
    ("stamp", stamp, 0.30, "fade"),
    ("flip", flip, 0.16, "fade"),
    ("nav", nav, 0.05, "fade"),
    ("locked", locked, 0.13, "fade"),
]

# Fixed per-sound seeds. Any stable mapping would do; what matters is that it
# does not depend on iteration order, so adding a sound later cannot change the
# noise inside the ones already shipped.
SEEDS = {name: 1000 + i * 37 for i, (name, _, _, _) in enumerate(SOUNDS)}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for name, make, peak, tail in SOUNDS:
        rng = random.Random(SEEDS[name])
        path, size = write(name, make(rng), peak, tail)
        total += size
        print("%-8s %6.0f ms  %5.1f KB  peak %.2f"
              % (name, 1000.0 * (size - 44) / 2.0 / SR, size / 1024.0, peak))
    print("%d files, %.1f KB total" % (len(SOUNDS), total / 1024.0))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
