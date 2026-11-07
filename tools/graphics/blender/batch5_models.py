"""Batch five: functional, low top-side machinery; no privileged operator face."""
import math


def chip(w, name, x, y, z, width=.30, material=None):
    w.box(name + " substrate", (x, y, z), (width, width, .035), w.pcb, .004)
    w.box(name + " package", (x, y, z+.04), (width*.72, width*.72, .045), material or w.iron, .006)
    for side in range(4):
        with w.part(name + " contact edge", (x, y, z), side*math.pi/2):
            for pin in range(5):
                w.box("Gold bond contact", (-width*.32+pin*width*.16, -width*.47, .005),
                      (width*.075, width*.15, .012), w.gold, 0)


def terminal(w):
    w.base(.87, w.white)
    w.box("Gasket sealed terminal housing", (0, 0, .49), (.72, .72, .18), w.paint, .025)
    w.box("Horizontal glass display recess", (0, 0, .60), (.59, .59, .05), w.black, .012)
    for row in range(5):
        for col in range(5):
            glow = w.pulse("Storage map phosphor", (.025, .43, .38), row*.8+col*.7, 1.4)
            w.box("Top-facing storage map cell", (-.21+col*.105, -.21+row*.105, .631),
                  (.070, .070, .009), glow, .002)
    for side in range(4):
        with w.part("Four-way terminal access", angle=side*math.pi/2):
            w.box("Recessed reader", (0, -.363, .48), (.25, .016, .04), w.black, .002)
            w.box("Reader guide lip", (0, -.377, .46), (.27, .027, .018), w.steel, .003)
            w.box("Tactile access pad", (0, -.34, .61), (.18, .048, .018), w.ivory, .004)
            for index in range(3):
                w.box("Reader contact", (-.06+index*.06, -.378, .48), (.018, .009, .018), w.gold, 0)
    return 1, .48, 6


from batch5_redesign import BUILDERS as REDESIGNED

BUILDERS = {"qln-terminal": terminal, **REDESIGNED}
