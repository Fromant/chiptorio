"""Build the animated 3 x 3 twin-bay enclosure. One unit = one tile; front = -Y.
Run: blender -b --python-exit-code 1 -P build.py
Camera elevation follows factorioRenderingPreset_v4.blend (45 degrees).
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector
HERE = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
s = bpy.context.scene
s.render.engine = 'CYCLES'
s.cycles.samples = 128
s.cycles.use_denoising = True
s.render.resolution_x = s.render.resolution_y = 384
s.render.resolution_percentage = 100
s.render.film_transparent = True
s.render.image_settings.file_format = 'PNG'
s.render.image_settings.color_mode = 'RGBA'
s.render.image_settings.color_depth = '8'
s.render.filter_size = 1.0
s.view_settings.view_transform = 'AgX'
s.view_settings.look = 'AgX - Medium High Contrast'
s['footprint_tiles'] = [2,3]
s['pixels_per_tile'] = 64
s['camera_target_z'] = 1.0
cols = {}
for name in ('Base','Details','Emission','Cables','Rig','Reference'):
    c = bpy.data.collections.new(name)
    s.collection.children.link(c)
    cols[name] = c

def mat(name, color, metal=0, rough=.5, emission=0, weather=False):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color,1)
    m.use_nodes = True
    n = m.node_tree.nodes
    p = n.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color,1)
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = rough
    p.inputs['Emission Color'].default_value = (*color,1)
    p.inputs['Emission Strength'].default_value = emission
    if weather:
        noise = n.new('ShaderNodeTexNoise')
        noise.inputs['Scale'].default_value = 38
        noise.inputs['Detail'].default_value = 3
        ramp = n.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color = (*(v*.72 for v in color),1)
        ramp.color_ramp.elements[1].color = (*color,1)
        m.node_tree.links.new(noise.outputs['Fac'],ramp.inputs[0])
        m.node_tree.links.new(ramp.outputs[0],p.inputs['Base Color'])
        bump = n.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = .12
        bump.inputs['Distance'].default_value = .008
        m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs[0],p.inputs['Normal'])
    return m
paint=mat('Graphite enamel',(.19,.23,.23),.5,.42,weather=True)
frame=mat('Cast iron',(.065,.082,.085),.65,.45,weather=True)
panel=mat('Warm grey enamel',(.36,.38,.33),.42,.5,weather=True)
metal=mat('Brushed aluminium',(.42,.46,.46),.78,.34)
black=mat('Vent recess',(.008,.012,.014),.1,.65)
rubber=mat('Cable rubber',(.022,.029,.029),0,.75)
copper=mat('Oxidised copper',(.32,.14,.055),.65,.44)
ochre=mat('Safety ochre',(.68,.34,.065),.35,.5,weather=True)
ivory=mat('Label stock',(.68,.66,.51),0,.8)
green=mat('Online LED',(.12,.7,.29),emission=2.5)
amber=mat('Activity LED',(1,.35,.035),emission=2)
screen=mat('Terminal phosphor',(.11,.42,.36),emission=1.1)

def finish(o,name,m,col='Details',bevel=0):
    o.name=name
    for c in list(o.users_collection): c.objects.unlink(o)
    cols[col].objects.link(o)
    o.data.materials.append(m)
    if bevel:
        b=o.modifiers.new('Machined edges','BEVEL'); b.width=bevel; b.segments=2
        b=o.modifiers.new('Corner normals','WEIGHTED_NORMAL'); b.keep_sharp=True
    return o

def box(name,loc,size,m,bevel=.012,col='Details'):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object; o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,m,col,bevel)

def cyl(name,loc,r,depth,m,axis='Z',col='Details',vertices=24):
    rot={'X':(0,math.pi/2,0),'Y':(math.pi/2,0,0),'Z':(0,0,0)}[axis]
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc,rotation=rot)
    return finish(bpy.context.object,name,m,col,.006)

def tube(name,points,r,m,col='Cables'):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.resolution_u=12
    c.bevel_depth=r; c.bevel_resolution=3
    sp=c.splines.new('BEZIER'); sp.bezier_points.add(len(points)-1)
    for p,co in zip(sp.bezier_points,points):
        p.co=co; p.handle_left_type=p.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,c); cols[col].objects.link(o); c.materials.append(m)
    return o

def text(body,loc,size):
    c=bpy.data.curves.new('Rack identification','FONT'); c.body=body; c.size=size; c.extrude=.0005
    o=bpy.data.objects.new(body,c); cols['Details'].objects.link(o)
    o.location=loc; o.rotation_euler=(math.pi/2,0,0); c.materials.append(ivory)

def bolt(x,y,z,axis='Y'): cyl('Captive bolt',(x,y,z),.024,.018,metal,axis,vertices=6)

s['footprint_tiles']=[3,3]
s['camera_target_z']=.65
# Purpose-built proportions: wide two-bay chassis, short replaceable servers.
for x in (-1.05,1.05): box('Isolation skid',(x,0,.07),(.30,2.50,.14),rubber,.035,'Base')
box('Cast plinth',(0,0,.19),(2.86,2.64,.20),frame,.045,'Base')
box('Plinth rim',(0,0,.30),(2.90,2.60,.07),metal,.015,'Base')
box('Cabinet shell',(0,-.16,.94),(2.72,2.05,1.24),paint,.045,'Base')
box('Rear service spine',(0,1.03,.82),(2.56,.32,.94),frame,.025,'Base')
# Three uprights define the two independent rack bays.
for x in (-1.30,0,1.30):
    box('Front upright',(x,-1.23,.95),(.10,.15,1.26),panel,.018)
    for z in (.43,.76,1.10,1.45): bolt(x,-1.319,z)
for bay,cx in enumerate((-.65,.65)):
    box('Dark rack recess',(cx,-1.204,.94),(1.15,.045,1.11),black)
    box('Controller fascia',(cx,-1.255,1.43),(1.12,.09,.16),panel,.009)
    box('Display bezel',(cx-.25,-1.307,1.44),(.40,.025,.095),black,.005)
    box('Controller display',(cx-.25,-1.325,1.44),(.34,.012,.055),screen,.003,'Emission')
    cyl('Power button',(cx+.40,-1.322,1.44),.028,.018,green,'Y','Emission')
    for row in range(4):
        z=1.23-row*.205
        box('Server sled',(cx,-1.255,z),(1.12,.10,.178),panel if row%2==0 else paint,.01)
        for x in (cx-.49,cx+.49):
            tube('Sled pull',[(x-.024,-1.32,z-.04),(x-.024,-1.38,z),(x+.024,-1.38,z),(x+.024,-1.32,z+.04)],.010,metal,'Details')
        for disk in range(3):
            x=cx-.32+disk*.235
            box('Hot swap caddy',(x,-1.318,z),(.205,.022,.12),frame,.006)
            box('Drive latch',(x-.065,-1.335,z),(.026,.014,.080),metal,.003)
            for v in range(3):box('Caddy vent',(x+.025,-1.335,z-.032+v*.032),(.095,.008,.012),black,.002)
        for v in range(3):box('Server vent',(cx+.38,-1.32,z-.04+v*.04),(.10,.015,.014),black,.002)
        box('Online lamp',(cx+.29,-1.34,z+.035),(.022,.008,.022),green,.002,'Emission')
        box('Activity lamp',(cx+.29,-1.34,z-.018),(.022,.008,.016),amber,.002,'Emission')
    box('PSU cartridge',(cx,-1.255,.43),(1.12,.10,.17),frame,.01)
    for v in range(3):box('PSU slot',(cx,-1.32,.385+v*.045),(.84,.015,.018),black,.003)
    box('PSU release',(cx-.49,-1.33,.43),(.04,.035,.12),ochre,.004)
# Broad shared lid, two real exhaust fans, plus a distinct network/power strip.
box('Shared roof',(0,-.16,1.60),(2.86,2.15,.14),panel,.035,'Base')
box('Roof service inset',(0,-.16,1.678),(2.60,1.90,.028),paint,.009)
for cx in (-.66,.66):
    cyl('Exhaust well',(cx,-.23,1.705),.48,.027,black)
    cyl('Rotor hub',(cx,-.23,1.73),.085,.024,metal)
    for i in range(7):
        a=i*math.tau/7
        o=box('Fan blade',(cx+.23*math.cos(a),-.23+.23*math.sin(a),1.724),(.31,.10,.018),frame,.015)
        o.rotation_euler.z=a+.4
    bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=8,location=(cx,-.23,1.755),major_radius=.46,minor_radius=.018)
    finish(bpy.context.object,'Protective fan rim',metal)
    for i in range(-5,6):
        x=i*.075
        box('Fan guard',(cx+x,-.23,1.76),(.012,2*math.sqrt(.43**2-x*x),.016),metal,.003)
    for x in (-.51,.51):
        for y in (-.75,.30):bolt(cx+x,y,1.70,'Z')
box('Roof label',(0,-.96,1.70),(1.08,.14,.025),black,.004)
# Text lies flat on the roof rather than on the old tall fascia.
text('CT / SERVER ENCLOSURE',(-.46,-1.0,1.716),.060)
bpy.data.objects['CT / SERVER ENCLOSURE'].rotation_euler=(0,0,0)
for side in (-1,1):
    x=side*1.375
    box('Side panel gasket',(x,-.10,.96),(.02,1.88,1.02),black)
    box('Side access panel',(x+side*.018,-.10,.96),(.025,1.81,.96),panel,.009)
    box('Side cooling recess',(x+side*.038,-.12,1.12),(.014,1.38,.32),black,.005)
    for v in range(5):box('Side louvre',(x+side*.055,-.12,.99+v*.061),(.035,1.32,.027),paint,.004)
    box('Service accent',(x+side*.035,-.10,.67),(.014,1.49,.055),ochre,.003)
    for y in (-.88,.65):
        for z in (.56,1.36):bolt(x+side*.05,y,z,'X')
# Rear I/O: visible sockets, cable loops and power distribution.
for cx in (-.65,.65):
    box('Rear connector plate',(cx,1.214,.91),(1.12,.055,.61),paint,.012)
    for row in range(3):
        z=.73+row*.18
        for j in range(4):box('Rear exhaust',(cx-.38+j*.13,1.247,z),(.065,.012,.11),black,.003)
        cyl('Cable socket',(cx+.30,1.25,z),.041,.035,metal,'Y')
        tube('Power loop',[(cx+.30,1.28,z),(cx+.45,1.34,z-.01),(cx+.43,1.35,z-.12),(cx+.30,1.28,z-.13)],.019,copper if row%2 else rubber)
box('Rear warning plate',(0,1.214,1.14),(.48,.04,.12),ochre,.005)
ground=box('Shadow Plane',(0,0,-.018),(200,200,.02),mat('Ground',(.5,.5,.5)),0,'Reference')
ground.is_shadow_catcher=True; ground.hide_render=True
world=bpy.data.worlds.new('Studio fill'); world.use_nodes=True; s.world=world
world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.38,.46,1)
world.node_tree.nodes['Background'].inputs[1].default_value=.45
for name,rot,energy,color,angle in [('Warm key',(15,-20,-30),2.5,(1,.91,.72),.10),('Cool fill',(55,25,145),.75,(.60,.77,1),.25)]:
    d=bpy.data.lights.new(name,'SUN'); d.energy=energy; d.color=color; d.angle=angle
    d.use_shadow = name == 'Warm key'
    o=bpy.data.objects.new(name,d); cols['Rig'].objects.link(o); o.rotation_euler=tuple(math.radians(v) for v in rot)
d=bpy.data.lights.new('Front softbox','AREA'); d.energy=180; d.shape='DISK'; d.size=5; d.use_shadow=False
o=bpy.data.objects.new('Front softbox',d); cols['Rig'].objects.link(o); o.location=(1,-5,6)
o.rotation_euler=(Vector((0,0,1.5))-o.location).to_track_quat('-Z','Y').to_euler()
d=bpy.data.cameras.new('Sprite camera'); d.type='ORTHO'; d.ortho_scale=6
cam=bpy.data.objects.new('Sprite camera',d); cols['Rig'].objects.link(cam)
cam.location=(7,-10,1+math.hypot(7,10)); cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler()
s.camera=cam
s.render.filepath=str(HERE/'renders/final/server-rack_hero.png')
bpy.ops.object.select_all(action='DESELECT')
for o in cols['Base'].objects: o.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Cabinet shell']
for screen_ui in bpy.data.screens:
    for area in screen_ui.areas:
        if area.type=='VIEW_3D': area.spaces.active.region_3d.view_perspective='CAMERA'

# Named animation channels are evaluated by render.py; source remains editable.
for fan,cx in enumerate((-.66,.66)):
    rotor=bpy.data.objects.new('Fan rotor %d'%fan,None)
    cols['Details'].objects.link(rotor)
    rotor.location=(cx,-.23,1.724)
    for obj in list(cols['Details'].objects):
        if obj.name.startswith('Fan blade') and abs(obj.location.x-cx)<.45:
            obj.parent=rotor
            obj.location-=rotor.location
    rotor['animation_channel']='fan'
    rotor['phase']=fan*.19
for number,obj in enumerate(list(cols['Emission'].objects)):
    if obj.name.startswith(('Activity lamp','Online lamp')):
        material=obj.data.materials[0].copy()
        material.name='Blink %02d'%number
        obj.data.materials[0]=material
        material['animation_channel']='lamp'
        material['phase']=number
        material['activity']=obj.name.startswith('Activity')
        node=material.node_tree.nodes.get('Principled BSDF')
        material['base_color']=list(node.inputs['Base Color'].default_value)
        material['emission_strength']=node.inputs['Emission Strength'].default_value
s['animation_frames']=16
s['animation_fps']=30
s.render.filepath=str(HERE/'renders/final/server-rack_hero.png')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'server-rack.blend'))
print('Built animated 3x3 server enclosure')
