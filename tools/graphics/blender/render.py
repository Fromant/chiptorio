"""Render saved geometry. Directions and animation are independent options.
blender -b server-rack.blend --python-exit-code 1 -P render.py -- --animate
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--angles',default='north,east,south,west')
p.add_argument('--animate',action='store_true')
p.add_argument('--frames',type=int,default=16)
p.add_argument('--samples',type=int,default=96)
p.add_argument('--resolution',type=int,default=384)
p.add_argument('--output-dir',type=Path,default=Path(__file__).resolve().parent/'renders/final')
p.add_argument('--no-shadows',action='store_true')
p.add_argument('--device',choices=('auto','cpu','hip'),default='auto')
p.add_argument('--gpu-name',default='',help='Match a HIP device name; e.g. 9070')
p.add_argument('--game-view',action='store_true',help='One fixed game camera, 64 rendered pixels per tile')
p.add_argument('--fixed-scale',action='store_true',help='64 rendered pixels per tile for existing directional adapters')
p.add_argument('--idle',action='store_true',help='Disable all state-driven bulbs and render the rest pose')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
angles={'north':0,'east':90,'south':180,'west':270,'hero':35}
requested=[v.strip() for v in a.angles.split(',')]
if a.game_view:
    angles['game']=0
    requested=['game']
if a.idle and a.animate:p.error('Idle export is a single rest frame')
if any(v not in angles for v in requested):p.error('Unknown direction')
if a.frames<1 or a.frames>128 or a.samples<1 or a.resolution<1:p.error('Frames must be 1..128; samples and resolution positive')
a.output_dir=a.output_dir.resolve()
a.output_dir.mkdir(parents=True,exist_ok=True)
frames=a.frames if a.animate else 1
s=bpy.context.scene
if 'working' in s:
    s['working']=0.0 if a.idle else 1.0
    s.update_tag()
    bpy.context.view_layer.update()
cam=s.camera
if a.game_view or a.fixed_scale:cam.data.ortho_scale=a.resolution/64
ground=bpy.data.objects['Shadow Plane']
model=[o for name in ('Base','Details','Emission','Cables') for o in bpy.data.collections[name].objects]
rotors=[o for o in bpy.data.objects if o.get('animation_channel')=='fan']
lamps=[m for m in bpy.data.materials if m.get('animation_channel')=='lamp']
s.render.engine='CYCLES'
device_name='CPU'
if a.device != 'cpu':
    prefs=bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type='HIP'
        prefs.refresh_devices()
        candidates=[d for d in prefs.devices if d.type=='HIP' and a.gpu_name.lower() in d.name.lower()]
        candidates.sort(key=lambda d: ' RX ' not in d.name)
        if not candidates: raise RuntimeError('No matching HIP GPU found')
        chosen=candidates[0]
        for device in prefs.devices: device.use=device.id==chosen.id
        s.cycles.device='GPU'
        device_name=chosen.name
    except Exception as error:
        if a.device=='hip' or a.gpu_name: raise
        print('GPU unavailable; using CPU:',error)
        s.cycles.device='CPU'
else:
    s.cycles.device='CPU'
print('RENDER DEVICE:',device_name,flush=True)
s.cycles.samples=a.samples
s.cycles.use_denoising=True
s.render.use_persistent_data=True
s.render.resolution_percentage=100
s.render.image_settings.file_format='PNG'
s.render.image_settings.color_mode='RGBA'
s.render.image_settings.color_depth='8'
s.render.film_transparent=True
s.cycles.seed=42
s.cycles.use_animated_seed=False
entity=s.get('asset_name','server-rack')
sprite_scale=s.get('sprite_scale',.475)
if a.game_view or a.fixed_scale:sprite_scale=.5
meta={'entity':entity,'footprint':list(s.get('footprint_tiles',[3,3])),'frames':frames,'line_length':math.ceil(math.sqrt(frames)),
      'animation_speed':.5,'sprite_scale':sprite_scale,'fps':s.get('animation_fps',30),'directions':{}}
meta['device']=device_name
meta['shadows']=not a.no_shadows
meta['shadow_direction']='screen-right'
if a.game_view or a.fixed_scale:
    meta['game_view']=True
    meta['state']='idle' if a.idle else 'working'
    meta['origin_px']=[a.resolution/2,a.resolution/2+s.get('camera_target_z',.65)*64/math.sqrt(2)]
if s.get('animation_period'):
    meta['layout']=s.get('layout','')
    meta['concept_revision']=s.get('concept_revision',1)
    meta['loop_seconds']=s['animation_period']/s.get('animation_fps',24)
    if frames>1:
        meta['fps']=frames/meta['loop_seconds']
        meta['animation_speed']=meta['fps']/60
def pose(frame):
    if s.get('animation_period'):
        time=1+frame/frames*s['animation_period']
        s.frame_set(int(time),subframe=time-int(time))
    for o in rotors:
        # Seven equally spaced blades repeat after 1/7 turn, with no loop hitch.
        o.rotation_euler.z=o['phase']+frame/frames*math.tau/7
    for m in lamps:
        node=m.node_tree.nodes.get('Principled BSDF')
        phase=(frame+int(m['phase'])*3)%frames
        lit=phase in (0,1,4,5,9,12,13) if m['activity'] else phase!=int(m['phase'])%frames
        if a.idle:lit=False
        level=(.025 if a.idle else 1 if lit else .07)
        node.inputs['Base Color'].default_value=tuple(v*level for v in m['base_color'][:3])+(1,)
        node.inputs['Emission Strength'].default_value=m['emission_strength']*(1 if lit else 0)
original_cam=cam.matrix_world.copy()
roots=[o for o in model if o.parent is None]
original_roots={o:o.matrix_world.copy() for o in roots}
turntable=bpy.data.objects.new('Render orientation',None)
s.collection.objects.link(turntable)
for o in roots:o.parent=turntable
try:
    for direction in requested:
        angle=math.radians(angles[direction])
        target=Vector((0,0,s.get('camera_target_z',.65)))
        # Camera and lighting stay fixed in screen space. Rotate geometry only,
        # including rotor parents, so every direction casts shadows to the right.
        turntable.rotation_euler.z=-angle
        cam.location=(0,-12,target.z+12)
        cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
        size=a.resolution*(2 if direction=='hero' else 1)
        s.render.resolution_x=s.render.resolution_y=size
        names=[]
        for frame in range(frames):
            pose(frame)
            for o in model:o.visible_camera=True
            ground.hide_render=True
            filename=f'{entity}_{direction}.png' if frame==0 else f'frames/{entity}_{direction}_{frame:03}.png'
            path=a.output_dir/filename
            path.parent.mkdir(parents=True,exist_ok=True)
            s.render.filepath=str(path)
            bpy.ops.render.render(write_still=True)
            names.append(filename)
        meta['directions'][direction]={'size':size,'files':names,'sprite_scale':sprite_scale if a.game_view or a.fixed_scale else sprite_scale*384/size}
        if not a.no_shadows:
            pose(0)
            ground.hide_render=False
            for o in model:o.visible_camera=False
            s.render.filepath=str(a.output_dir/f'{entity}_{direction}_shadow.png')
            bpy.ops.render.render(write_still=True)
finally:
    pose(0)
    ground.hide_render=True
    for o in model:o.visible_camera=True
    cam.matrix_world=original_cam
    for o in roots:
        o.parent=None
        o.matrix_world=original_roots[o]
    bpy.data.objects.remove(turntable,do_unlink=True)
(a.output_dir/'render-manifest.json').write_text(json.dumps(meta,indent=2),encoding='utf-8')
print(f'Rendered {frames} frame(s) x {len(requested)} directions to {a.output_dir}')
