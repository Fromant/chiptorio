"""Czochralski puller with a serviceable travelling spindle gearbox."""
import bpy
from semiconductor_geometry import crystal_puller


def build(w):
    result = crystal_puller(w)
    head = next(o for o in bpy.data.objects if o.name.startswith('Travelling pull head'))
    previous = w.parent
    w.parent = head
    try:
        w.box('Pull head gearbox cover', (0, -.16, 3.29), (.39, .15, .24), w.steel, .035)
        w.cyl('Side mounted spindle motor', (.31, .12, 3.31), .15, .36, w.iron, 'X')
        for x in (.19, .25, .31, .37, .43):
            w.ring('Motor cooling rib', (x, .12, 3.31), .16, .016, w.steel, 'X')
        w.box('Gearbox oil inspection glass', (0, -.245, 3.29), (.14, .018, .08), w.blue, .005)
        for x in (-.15, .15):
            for z in (3.21, 3.37):
                w.cyl('Gearbox cover fastener', (x, -.249, z), .019, .018, w.iron, 'Y', vertices=6)
        for z in (3.00, 3.06, 3.12):
            w.ring('Spindle bearing retaining collar', (0, 0, z), .205, .018, w.steel)
        w.pipe('Spindle lubrication tube', [(-.18,.12,3.24),(-.26,.02,3.12),(-.16,0,3.02)], .022, w.copper)
    finally:
        w.parent = previous
    return result
