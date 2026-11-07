"""Model-first process studies. All workpieces follow continuous, closed paths.

Resupply/reset happens inside opaque feed/output hoods, never in an open gripper.
The timeline markers describe observable work rather than decorative oscillation.
"""
import math
import bpy
from mathutils import Vector
from semiconductor_geometry import foundation, service, gauge, wafer, cassette, lamp

PERIOD = 192


def sample(phase, keys):
    for (a, p), (b, q) in zip(keys, keys[1:]):
        if a <= phase <= b:
            t = (phase-a)/(b-a)
            t = t*t*(3-2*t)
            if isinstance(p, tuple):
                return tuple(x+(y-x)*t for x, y in zip(p, q))
            return p+(q-p)*t
    return keys[-1][1]


def animate(obj, channel, fn):
    for phase in range(PERIOD+1):
        setattr(obj, channel, fn(phase))
        obj.keyframe_insert(data_path=channel, frame=phase+1)
    action = obj.animation_data.action
    for slot in action.slots:
        for layer in action.layers:
            for strip in layer.strips:
                for curve in strip.channelbag(slot).fcurves:
                    for point in curve.keyframe_points:
                        point.interpolation = 'LINEAR'


def move(obj, keys):
    animate(obj, 'location', lambda p: sample(p, keys))


def begin(w, phases, white=False):
    foundation(w, w.white if white else w.paint)
    w.scene['animation_period'] = PERIOD
    w.scene['art_revision'] = 3
    w.scene['review_notes'] = 'Scrub marked phases. Workpieces reset only inside opaque magazines.'
    for phase, name in phases:
        w.scene.timeline_markers.new(name, frame=phase+1)


def finish(w, check=None, height=1.05):
    for phase in range(PERIOD):
        w.scene.frame_set(phase+1)
        bpy.context.view_layer.update()
        if check:
            check(phase)
    w.scene.frame_set(1)
    # Preserve geometry beneath visibility/shape drivers during static batching.
    for obj in bpy.data.objects:
        if obj.type not in {'MESH','CURVE'}:
            continue
        parent = obj.parent
        while parent:
            if parent.animation_data and any(c.data_path == 'scale' for c in parent.animation_data.drivers):
                w.driver(obj, 'scale', 0, str(obj.scale.x))
                break
            parent = parent.parent
    return [5, 5], height, 12


def ports(w, xs):
    # Native fluid connections terminate directly in the plinth service chase.
    # No decorative pipe crosses the process bed.
    for side in (-1, 1):
        for x in xs:
            w.cyl('Plinth service connection', (x, side*2.24, .35), .07, .28, w.steel, 'Y')
            w.ring('Connection locking collar', (x, side*2.35, .35), .085, .015, w.iron, 'Y')


def hood(w, name, x, y, width=.85, depth=.85, top=1.65, slot=0):
    """Opaque front and rear covers; workpieces enter through side openings."""
    for dy in (-depth/2, depth/2):
        w.box(name+' guard', (x, y+dy, (.48+top)/2), (width, .06, top-.48), w.white)
    if slot:
        for side in (-1,1):
            w.box(name+' slotted roof',(x+side*(width+slot)/4,y,top),((width-slot)/2,depth+.08,.08),w.white)
    else:
        w.box(name+' roof', (x, y, top), (width, depth+.08, .08), w.white)
    seam=(width+slot)/4 if slot else width*.32
    for dx in (-seam,seam):
        w.box(name+' roof seam', (x+dx, y, top+.045), (.015, depth*.78, .009), w.steel, 0)


def beam(w, name, origin, tip, thickness=.12):
    """One connected sliding beam; its end always meets the fork carriage."""
    obj = w.box(name, (0, 0, 0), (thickness, 1, .085), w.steel)
    animate(obj, 'location', lambda p: ((origin[0]+tip(p)[0])/2,
                                      (origin[1]+tip(p)[1])/2, tip(p)[2]-.10))
    animate(obj, 'rotation_euler', lambda p: (0, 0, -math.atan2(tip(p)[0]-origin[0], tip(p)[1]-origin[1])))
    animate(obj, 'scale', lambda p: (1, math.hypot(tip(p)[0]-origin[0], tip(p)[1]-origin[1]), 1))
    return obj
