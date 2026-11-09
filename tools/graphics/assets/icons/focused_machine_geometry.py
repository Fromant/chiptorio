"""Icon-only framing of existing machines; the entity sources are never modified."""
import importlib.util
from pathlib import Path
import sys
import math
import bpy

SOURCES={
    'computer-assembler':'semiconductor/computer_assembler.py',
    'crystal-puller':'semiconductor/crystal_puller.py',
    'cooling-tower':'infrastructure/cooling_tower.py',
}

def focused(w,name):
    file=Path(__file__).resolve().parents[1]/SOURCES[name]
    sys.path.insert(0,str(file.parent))
    spec=importlib.util.spec_from_file_location('icon_machine_source',file)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    result=module.build(w)
    w.scene.frame_set(73 if name=='crystal-puller' else 81 if name=='computer-assembler' else 1)
    bpy.context.view_layer.update()
    # Keep a representative productive pose rather than the empty loop-start pose.
    for obj in list(w.scene.objects):
        if obj.animation_data:obj.animation_data_clear()
    for mat in bpy.data.materials:
        if mat.node_tree and mat.node_tree.animation_data:mat.node_tree.animation_data_clear()
    prefixes=['Isolation skid','Cast plinth','Machined perimeter rim','Service deck',
              'Panel gasket','Captive hex bolt','Edge safety marking']
    if name=='cooling-tower':
        prefixes+=['Radiator inlet','Radiator outlet','Native pipe seat','Port mounting flange',
                   'Pipe saddle','Pipe clamp','Fan controller','Airflow status']
    for obj in list(w.scene.objects):
        if any(obj.name.startswith(prefix) for prefix in prefixes):bpy.data.objects.remove(obj,do_unlink=True)
    if name=='computer-assembler':
        keep=('Chassis floor','Computer backplane','Chassis side rail','Card socket','Slotted card',
              'Backplane component','Daughtercard','Gold card edge','Gripper body',
              'Opening gripping finger','Telescopic insertion ram')
        for obj in list(w.scene.objects):
            if obj.type in {'MESH','CURVE'} and not obj.name.startswith(keep):bpy.data.objects.remove(obj,do_unlink=True)
        w.box('Compact icon gantry post',(-.65,-.25,1.55),(.28,.40,2.65),w.paint,.025)
        w.box('Compact insertion bridge',(-.05,-.25,2.80),(1.50,.42,.24),w.ochre,.025)
        w.box('Compact fixture base',(.10,-.25,.48),(2.25,1.35,.22),w.iron,.035)
    elif name=='crystal-puller':
        keep=('Furnace','Water cooled vessel','Crucible','Visible melt','Flange tie rod',
              'Pull head carriage','Spindle gearbox','Geared hoist motor','Motor cooling fin',
              'Gearbox inspection glass','Variable length seed draw spindle','Continuous silicon boule','Seed neck')
        for obj in list(w.scene.objects):
            if obj.type in {'MESH','CURVE'} and not obj.name.startswith(keep):bpy.data.objects.remove(obj,do_unlink=True)
        w.box('Compact pull tower',(-.52,1.0,1.92),(.26,.26,3.05),w.steel,.02)
        w.box('Compact pull bridge',(-.52,.42,3.48),(.42,1.45,.24),w.paint,.03)
    else:
        root=bpy.data.objects.new('Icon three-quarter composition',None);w.cols['Rig'].objects.link(root)
        for obj in list(w.scene.objects):
            if obj!=root and obj.parent is None:obj.parent=root
        root.rotation_euler.z=math.radians(35)
    return result
