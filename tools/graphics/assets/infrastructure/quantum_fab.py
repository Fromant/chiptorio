"""Eleven-tile cryogenic fabrication cell with a visible indexed process line."""
import math
import bpy
from common import base,animate,sample,cabinet,port,active,hood,finish

def build(w):
    base(w,11,True,[(16,'Carrier enters line'),(32,'Align under quantum probe'),(48,'Field A'),(80,'Field B'),(112,'Corrected array ready'),(148,'Unload processor')])
    w.box('Cryostat vibration bed',(0,1.25,.70),(4.5,3.9,.5),w.iron,.04)
    for x in (-1.75,1.75):
        for y in (-.1,2.60):w.cyl('Cryostat frame tie',(x,y,2.40),.07,3.25,w.steel)
    for i,(z,r) in enumerate([(1.12,1.55),(1.72,1.40),(2.32,1.20),(2.92,1.0),(3.52,.82)]):
        w.cyl('Thermal isolation plate',(0,1.25,z),r,.12,w.brass)
        w.ring('Cold plate polished rim',(0,1.25,z+.07),r,.025,w.steel)
        for x in (-.60,.60):
            w.pipe('Cryogenic feed braid',[(x,1.25,z+.08),(x+.12,1.1,z+.3),(x,1.25,z+.55)],.025,w.copper)
    w.box('Cryostat vacuum crown',(0,1.25,3.95),(3.8,3.2,.25),w.white,.035)
    for x in (-4.15,4.15):
        cabinet(w,'Cryogenic service',x,1.0,1.05,2.1)
        cabinet(w,'RF control',x,3.65,1.05,1.8)
    for x in (-1.4,1.4):w.box('Process bridge leg',(x,-1.65,1.95),(.18,.20,3.0),w.steel)
    w.box('Process bridge',(0,-2.45,3.50),(3.3,1.85,.22),w.white,.025)
    for y in (-3.42,-2.18):w.box('Indexed carrier guide',(0,y,1.16),(5.60,.10,.11),w.steel)
    hood(w,'Input vacuum load-lock',-3.8,-2.8);hood(w,'Output vacuum load-lock',3.8,-2.8)
    for x in (-3.8,3.8):
        cutter=w.box('Temporary load-lock chute',(x,-2.8,.35),(1.6,1.55,1.2),w.black,0,'Reference')
        for name in ('Cast plinth','Machined perimeter rim','Service deck'):
            obj=next(o for o in bpy.data.objects if o.name==name)
            mod=obj.modifiers.new('Load-lock elevator opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
            bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter,do_unlink=True)
    keys=[(0,(-3.8,-2.8,1.25)),(16,(-2.8,-2.8,1.25)),(32,(0,-2.8,1.25)),(124,(0,-2.8,1.25)),(148,(3.8,-2.8,1.25)),(164,(3.8,-2.8,.20)),(180,(-3.8,-2.8,.20)),(192,(-3.8,-2.8,1.25))]
    with w.part('Continuous quantum substrate carrier') as carrier:
        animate(carrier,'location',lambda p:sample(p,keys))
        w.box('Carrier plate',(0,0,0),(1.4,1.4,.07),w.steel)
        ready=active(w,'Corrected array indicator',(.08,.65,.20),'(1 if 112<=((frame-1)%192)<160 else 0)',1.1)
        w.box('Carrier test lens',(0,-.71,.08),(.40,.025,.055),ready)
        w.box('Quantum substrate',(0,0,.065),(.86,.86,.06),w.black,.006)
        for x in (-.26,0,.26):
            for y in (-.26,0,.26):
                w.box('Qubit array island',(x,y,.107),(.16,.16,.023),w.gold,.003)
    head_keys=[(0,(0,-2.8,2.35)),(32,(0,-2.8,2.35)),(40,(-.22,-3.02,1.66)),(58,(-.22,-3.02,1.66)),(70,(.22,-2.58,1.66)),(110,(.22,-2.58,1.66)),(124,(0,-2.8,2.35)),(192,(0,-2.8,2.35))]
    with w.part('Quantum process probe') as head:
        animate(head,'location',lambda p:sample(p,head_keys))
        w.cyl('Probe cold head',(0,0,0),.24,.22,w.steel)
        w.cyl('Focused process tip',(0,0,-.18),.07,.20,w.ivory)
    ram=w.cyl('Probe slide spindle',(0,0,0),.06,1,w.steel)
    animate(ram,'location',lambda p:(sample(p,head_keys)[0],sample(p,head_keys)[1],(3.39+sample(p,head_keys)[2]+.11)/2))
    animate(ram,'scale',lambda p:(1,1,3.39-sample(p,head_keys)[2]-.11))
    field=active(w,'Quantum patterning field',(.29,.12,.76),'(1 if 42<=((frame-1)%192)<110 else 0)',2.0)
    with w.part('Probe field guide') as ray:
        animate(ray,'location',lambda p:(sample(p,head_keys)[0],sample(p,head_keys)[1],1.44))
        light=w.cyl('Nonphysical process field',(0,0,0),.016,.18,field);light['diagnostic_nonphysical']=True
    for x in (-1,1):
        port(w,'Cryogenic coupling',x,-5.23);port(w,'Cryogenic coupling',x,5.23)
        side=1 if x>0 else -1
        w.pipe('Cryogen external service',[(x,-5.23,.35),(side*4.9,-4.8,.65),(side*4.9,3.0,.65),(side*1.3,2.6,1.12)],.07,w.blue)
        w.pipe('Cryogen return service',[(side*1.3,2.6,1.72),(side*2.8,3.8,1.0),(x,5.23,.35)],.06,w.steel)
    def check(p):
        if 40<=p<=112:assert abs(carrier.location.x)<.0001,'Probe runs before carrier alignment'
        if 124<=p<=148:assert head.location.z>2.3,'Carrier leaves beneath lowered probe'
    return finish(w,11,1.8,check)
