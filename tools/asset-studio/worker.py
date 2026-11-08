"""One Blender process per render stage. All paths point into a source snapshot."""
import importlib.util
import json
import runpy
import sys
from pathlib import Path
import bpy
from mathutils import Vector

config = json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text(encoding='utf-8'))
root = Path(config['snapshot'])
asset = config['asset']
source = asset['source']
library = root/'tools/graphics/blender'
sys.path.insert(0, str(library))
model = Path(config['model'])
if config['build']:
    if source['format'] == 'legacy-builder':
        runpy.run_path(str(root/source['builder']), run_name='__main__')
        built = root/source['model']
        bpy.ops.wm.open_mainfile(filepath=str(built))
    elif source['format'] == 'python':
        sys.path.insert(0, str((root/source['builder']).parent))
        spec = importlib.util.spec_from_file_location('asset_geometry', root/source['builder'])
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        from lab_models import build
        build(asset['name'], builder=module.build, output=model)
    elif source['format'] == 'blend':
        bpy.ops.wm.open_mainfile(filepath=str(root/source['model']))
    else:
        raise ValueError('No configured Blender source')
    model.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(model))
else:
    bpy.ops.wm.open_mainfile(filepath=str(model))

s = bpy.context.scene
if asset['mode'] == 'existing-directional' and not s.get('asset_name'):
    s['asset_name'] = asset['name']
if asset['profile'] == 'entity':
    assert s.get('asset_name') == asset['name'], 'Scene identity mismatch'
    assert list(s['footprint_tiles']) == asset['render']['footprint'], 'Scene/registry footprint mismatch'
    if asset['mode'] != 'existing-directional':
        assert s.get('animation_period', 48) == asset['render']['period'], 'Scene/registry loop mismatch'
    if source['format'] == 'legacy-builder' and asset['mode'] != 'existing-directional':
        runpy.run_path(str(library/'verify-lab-motion.py'), run_name='__main__')
    # Generic closure check for future Python builders; every frame is bounds-checked by packing.
    if asset['render']['frames'] > 1 and s.get('animation_period'):
        def pose(frame):
            s.frame_set(frame)
            bpy.context.view_layer.update()
            return [v for o in s.objects if o.type == 'MESH' for row in o.matrix_world for v in row]
        first, last = pose(1), pose(1+asset['render']['period'])
        assert max((abs(a-b) for a,b in zip(first,last)), default=0) < .0001, 'Geometry loop is not closed'
        s.frame_set(1)
    if asset['mode'] != 'existing-directional':
        old_working = s.get('working', 1)
        s['working'] = 0.0
        s.update_tag()
        bpy.context.view_layer.update()
        for material in bpy.data.materials:
            if material.use_nodes and material.node_tree:
                shader = material.node_tree.nodes.get('Principled BSDF')
                if shader:
                    assert shader.inputs['Emission Strength'].default_value < .0001, 'Idle emission must be off: '+material.name
        s['working'] = old_working
        s.update_tag()
        # Check the complete cycle's floor envelope, not just a convenient still.
        half_x, half_y = (n/2+.08 for n in asset['render']['footprint'])
        for frame in range(1, asset['render']['period']+1):
            s.frame_set(frame)
            bpy.context.view_layer.update()
            for obj in s.objects:
                if obj.type != 'MESH' or obj.name == 'Shadow Plane':
                    continue
                for corner in obj.bound_box:
                    point = obj.matrix_world @ Vector(corner)
                    assert abs(point.x) <= half_x and abs(point.y) <= half_y, 'Geometry leaves footprint at frame '+str(frame)+': '+obj.name
        s.frame_set(1)

if config.get('buildOnly'):
    print('BUILD PASS', asset['name'])
else:
    states = ['working','idle'] if asset['profile'] == 'entity' else ['working']
    for state in states:
        args = ['render.py','--','--samples',str(config['samples']),'--resolution',str(config['resolution']),
                '--device','auto','--output-dir',str(Path(config['output'])/state)]
        if asset['mode'] == 'existing-directional' or asset.get('integration',{}).get('directional'):
            args += ['--fixed-scale','--angles','north,east,south,west']
        else:
            args += ['--game-view']
        if state == 'working':
            if config['frames'] > 1:
                args += ['--animate','--frames',str(config['frames'])]
            args += ['--no-shadows']
        else:
            args += ['--idle']
        sys.argv = args
        runpy.run_path(config.get('renderer', str(library/'render.py')), run_name='__main__')
    print('RENDER PASS', asset['name'])
