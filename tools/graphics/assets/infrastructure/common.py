"""Batch 7 authoring helpers. Rendering and publication stay in Asset Studio."""
import math
import bpy

def sample(p,keys):
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if a<=p<=b:
            t=(p-a)/(b-a);t=t*t*(3-2*t)
            if isinstance(x,tuple):return tuple(u+(v-u)*t for u,v in zip(x,y))
            return x+(y-x)*t
    return keys[-1][1]

def animate(obj,channel,fn,period=192):
    for p in range(period+1):
        setattr(obj,channel,fn(p));obj.keyframe_insert(data_path=channel,frame=p+1)
    for slot in obj.animation_data.action.slots:
        for layer in obj.animation_data.action.layers:
            for strip in layer.strips:
                for curve in strip.channelbag(slot).fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'

def base(w,size,animated=False,markers=()):
    w.base(size-.22)
    w.scene['animation_period']=192 if animated else 48
    w.scene['export_canvas']=math.ceil((size*64+320)/256)*256
    w.scene['art_revision']=1
    for phase,title in markers:w.scene.timeline_markers.new(title,frame=phase+1)

def active(w,name,color,gate='1',strength=1.5):
    mat=w.material(name,color,emission=strength)
    node=mat.node_tree.nodes.get('Principled BSDF')
    driver=node.inputs['Emission Strength'].driver_add('default_value').driver
    var=driver.variables.new();var.name='working';var.type='SINGLE_PROP'
    var.targets[0].id_type='SCENE';var.targets[0].id=w.scene;var.targets[0].data_path='["working"]'
    driver.expression=f'working*{strength}*({gate})'
    return mat

def cabinet(w,name,x,y,width=.7,height=1.5,z=.45):
    w.box(name+' housing',(x,y,z+height/2),(width,.70,height),w.white,.025)
    w.box(name+' access panel',(x,y-.36,z+height/2),(width*.8,.025,height*.76),w.iron,.006)
    for dz in (.2,.35,.50):w.box(name+' ventilation',(x,y-.38,z+dz),(width*.60,.015,.035),w.steel,.001)
    w.box(name+' handle',(x+width*.25,y-.39,z+height*.65),(.035,.05,.16),w.ivory,.003)

def port(w,name,x,y,z=.35):
    w.cyl(name,(x,y,z),.075,.28,w.steel,'Y')
    w.ring(name+' flange',(x,y+(.10 if y>0 else -.10),z),.09,.016,w.iron,'Y')

def hood(w,name,x,y):
    for dy in (-.86,.86):w.box(name+' side',(x,y+dy,1.30),(1.9,.08,1.7),w.white)
    w.box(name+' cover',(x,y,2.18),(1.9,1.8,.08),w.white)

def finish(w,size,target=1.0,check=None):
    if check:
        for p in range(w.scene['animation_period']):
            w.scene.frame_set(p+1);bpy.context.view_layer.update();check(p)
    w.scene.frame_set(1)
    return [size,size],target,12
