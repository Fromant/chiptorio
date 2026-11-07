"""Authored handling cycle; preserve visibility-switched payload geometry."""
import bpy
from semiconductor_geometry import computer_assembler


def build(w):
    result = computer_assembler(w)
    # Zero-scale payload parents are singular at rest. Keep their child meshes
    # out of static joining, whose inverse transform would corrupt their geometry.
    for obj in bpy.data.objects:
        if obj.type != 'MESH':
            continue
        parent = obj.parent
        while parent:
            if parent.animation_data and any(c.data_path == 'scale' for c in parent.animation_data.drivers):
                w.driver(obj, 'scale', 0, str(obj.scale.x))
                break
            parent = parent.parent
    return result
