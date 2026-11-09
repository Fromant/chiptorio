"""Rotatable twin-cell dry cooler with fin-and-tube radiators and axial fans."""
import math
import bpy
from common import base,animate,cabinet,active,finish,tube

def build(w):
    base(w,7,True,[(0,'Radiator airflow'),(48,'Fan quarter cycle'),(96,'Return cooling flow'),(144,'Fan three-quarter cycle')])
    for x in (-1.55,1.55):
        w.box('Radiator cell skid',(x,.25,.65),(2.60,1.50,.36),w.iron,.04)
        for dx in (-1.20,1.20):w.box('Radiator structural upright',(x+dx,.25,1.98),(.12,.85,2.48),w.paint)
        for z in (.83,3.25):w.box('Radiator header frame',(x,.25,z),(2.50,.85,.12),w.steel)
        for i in range(37):
            w.box('Aluminium heat exchange fin',(x-.94+i*.052,.25,1.98),(.018,.56,2.02),w.steel,0)
        for z in (1.08,1.38,1.68,1.98,2.28,2.58,2.88):
            w.cyl('Radiator copper tube',(x,.25,z),.045,2.12,w.copper,'X')
        for dx in (-1.08,1.08):w.cyl('Vertical radiator header',(x+dx,.25,1.98),.10,2.16,w.copper)
        panel=w.box('Close coupled fan mounting plate',(x,-.22,1.98),(2.32,.14,2.32),w.paint,0)
        cutter=w.cyl('Temporary fan opening',(x,-.22,1.98),1.0,.40,w.black,'Y',64)
        mod=panel.modifiers.new('Clear fan aperture','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
        bpy.context.view_layer.objects.active=panel;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter,do_unlink=True)
        # A short annular duct physically joins the grille rim to the mounting plate.
        vertices=[];faces=[]
        for y,r in [(-.42,1.0),(-.42,1.09),(-.22,1.0),(-.22,1.09)]:
            for i in range(64):
                a=i*math.tau/64;vertices.append((x+r*math.cos(a),y,1.98+r*math.sin(a)))
        for a,b in [(0,1),(1,3),(3,2),(2,0)]:
            for i in range(64):faces.append((a*64+i,a*64+(i+1)%64,b*64+(i+1)%64,b*64+i))
        mesh=bpy.data.meshes.new('Close fan duct');mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new('Integral fan shroud',mesh);w.cols['Details'].objects.link(obj);mesh.materials.append(w.paint)
        w.ring('Axial fan safety hoop',(x,-.44,1.98),1.07,.035,w.steel,'Y')
        w.cyl('Axial fan motor',(x,-.10,1.98),.20,.12,w.iron,'Y')
        w.cyl('Fan spindle',(x,-.20,1.98),.055,.16,w.steel,'Y')
        with w.part('Radiator axial fan',(x,-.29,1.98)) as rotor:
            animate(rotor,'rotation_euler',lambda p,sign=1 if x<0 else -1:(0,sign*4*math.pi*p/192,0))
            w.cyl('Rotor hub',(0,0,0),.21,.12,w.steel,'Y')
            for i in range(6):
                a=i*math.tau/6
                blade=w.box('Pitched axial fan blade',(.54*math.cos(a),0,.54*math.sin(a)),(.80,.065,.18),w.ivory,.008)
                blade.rotation_euler.y=-a;blade.rotation_euler.x=.20
        for dx in (-.50,.50):w.box('Fan safety grille',(x+dx,-.475,1.98),(.022,.025,1.90),w.steel)
        for z in (1.48,2.48):w.box('Fan safety crossbar',(x,-.475,z),(1.90,.025,.022),w.steel)
    for sign in (-1,1):
        # Native Factorio pipe pictures/covers finish the ends at the tile ports.
        for y in (-3.0,3.0):
            w.cyl('Native pipe seat',(sign,y,.65),.16,.22,w.steel,'Y')
            w.ring('Port mounting flange',(sign,y,.65),.18,.025,w.iron,'Y')
        tube(w,'Radiator inlet',[(sign,-3,.65),(sign,-2.65,.65),(sign*2.63,-2.65,.65),(sign*2.63,-.40,.65),(sign*2.63,-.40,.94),(sign*2.63,.25,.94)],.10,w.steel)
        tube(w,'Radiator outlet',[(sign*.47,.25,3.02),(sign*.47,2.30,3.02),(sign*.47,2.30,.65),(sign,2.30,.65),(sign,3,.65)],.10,w.steel)
        for y in (-2.20,-1.30):
            w.box('Pipe saddle',(sign*2.63,y,.50),(.34,.18,.18),w.iron)
            w.ring('Pipe clamp',(sign*2.63,y,.65),.115,.015,w.steel,'Y')
    cabinet(w,'Fan controller',0,-2.18,.70,1.05)
    w.box('Airflow status',(0,-2.55,1.12),(.30,.02,.09),active(w,'Airflow online',(.05,.55,.85)))
    return finish(w,7,1.55)
