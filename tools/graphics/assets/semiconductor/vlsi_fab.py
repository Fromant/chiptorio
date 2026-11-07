"""Model-first process revision; scrub the marked phases in Blender."""
import math
import bpy
from mathutils import Vector
from review_geometry import PERIOD, sample, animate, move, begin, finish, ports, hood, beam
from semiconductor_geometry import service, gauge, wafer, lamp


def build(w):
    begin(w,[(24,'Load wafer into vacuum exposure cell'),(40,'Expose field A'),(72,'Expose field B'),
             (104,'Expose field C'),(136,'Expose field D'),(170,'Unload exposed wafer')], True)
    ports(w,(-1,1))
    w.box('Vibration isolated scanner bed',(0,.10,.70),(3.40,3.40,.51),w.iron,.035)
    # Enclosed light source, reflective projection chamber and attached services.
    w.box('Source containment module',(-1.32,1.13,1.47),(1.08,1.10,1.45),w.white,.04)
    w.cyl('Source vacuum flange',(-.71,1.13,1.63),.30,.20,w.steel,'X')
    w.box('Projection chamber rear',(0,1.52,1.99),(2.30,.18,2.32),w.white,.035)
    w.box('Projection chamber right',(.97,.56,1.99),(.18,1.93,2.32),w.white,.035)
    w.box('Projection chamber roof',(.02,.56,3.20),(2.30,2.10,.18),w.white,.035)
    for x in (-1.60,-1.06):
        w.box('Source service panel',(x,.565,1.48),(.45,.035,1.10),w.steel,.012)
        w.box('Source panel latch',(x+.12,.54,1.48),(.03,.03,.15),w.ivory,.003)
        for z in (1.10,1.82):
            w.cyl('Source captive screw',(x,.535,z),.025,.015,w.iron,'Y',vertices=6)
    for y in (-.05,.54,1.13):
        w.box('Roof service cassette',(.02,y,3.305),(1.84,.43,.035),w.steel,.005)
        for x in (-.75,.75):
            w.box('Roof lift handle',(x,y,3.35),(.16,.035,.07),w.iron,.004)
    for z in (1.16,1.74,2.32,2.90):
        w.box('Projection wall panel joint',(1.069,.57,z),(.016,1.60,.018),w.steel,.001)
    for z in (1.25,1.70,2.15):
        w.cyl('Vacuum access flange',(.97,-.43,z),.12,.08,w.steel,'Y')
        w.ring('Access flange seal',(.97,-.48,z),.10,.012,w.iron,'Y')
    # A deliberate front service cutaway reveals a folded reflective optical train.
    for x,y,z,tilt in [(-.45,.65,2.84,.42),(.40,.45,2.46,-.48),(-.36,.18,2.05,.50),(.30,-.05,1.70,-.38)]:
        with w.part('Reflective projection mirror',(x,y,z)) as mirror:
            mirror.rotation_euler.y=tilt
            w.cyl('Mirror backing',(0,0,0),.27,.13,w.iron)
            w.cyl('Polished reflective face',(0,0,.075),.24,.025,w.steel)
            for side in (-1,1):
                w.box('Mirror kinematic mount',(side*.29,.07,.05),(.06,.15,.20),w.steel)
        w.box('Mirror rear support',(x+math.sin(tilt)*.05,(y+.14+1.43)/2,z+math.cos(tilt)*.05),(.07,1.43-y-.14,.07),w.steel)
    for x in (-.50,.50):
        w.box('Reticle rear cantilever',(x,1.05,2.91),(.10,.86,.08),w.steel)
    w.box('Reticle vacuum stage',(0,.65,2.99),(1.14,.87,.11),w.iron)
    w.box('Reticle carrier',(0,.65,3.07),(.65,.57,.04),w.blue,.002)
    for x in (-.57,.57):
        w.box('Reticle stage guide',(x,.65,3.04),(.06,1.05,.05),w.steel)
    for x in (-.85,.85):
        w.box('Projection bridge upright',(x,-.25,1.22),(.10,.18,.56),w.white)
    w.box('Projection aperture support bridge',(0,-.25,1.49),(1.80,.18,.10),w.steel)
    w.box('Exposure aperture shroud',(0,-.45,1.58),(.90,.66,.15),w.iron)
    exposure=lamp(w,'Contained exposure light',(.34,.48,.83),
                  '(1 if 36<=((frame-1)%192)<48 or 68<=((frame-1)%192)<80 or 100<=((frame-1)%192)<112 or 132<=((frame-1)%192)<144 else 0)',1.2)
    w.cyl('Exposure aperture',(0,-.45,1.49),.22,.025,exposure)
    for x in (-.59,.59):
        w.box('Air bearing stage rail',(x,-.54,1.02),(.10,1.96,.12),w.steel)
    stage_keys=[(0,(0,-1.36,1.395)),(16,(0,-1.36,1.395)),(32,(-.13,-.58,1.395)),
                (48,(-.13,-.58,1.395)),(64,(.13,-.58,1.395)),(80,(.13,-.58,1.395)),
                (96,(-.13,-.32,1.395)),(112,(-.13,-.32,1.395)),(128,(.13,-.32,1.395)),
                (144,(.13,-.32,1.395)),(170,(0,-1.36,1.395)),(176,(0,-1.36,1.395)),
                (184,(0,-1.36,1.395)),(192,(0,-1.36,1.395))]
    with w.part('Lower Y air-bearing sled') as sled:
        animate(sled,'location',lambda p:(0,sample(p,stage_keys)[1],1.13))
        w.box('Y sled bearing plate',(0,0,0),(1.44,.95,.10),w.steel)
        for y in (-.27,.27):
            w.box('Upper X guide',(0,y,.075),(1.50,.08,.05),w.steel)
    with w.part('Scanner wafer stage') as stage:
        move(stage,stage_keys)
        w.box('XY air bearing carriage',(0,0,-.10),(1.02,.95,.13),w.steel)
        w.cyl('Electrostatic wafer chuck',(0,0,-.0425),.40,.06,w.iron)
        wafer(w,'Scanner wafer',radius=.37,etched=False)
        for i,(x,y) in enumerate([(-.10,-.10),(.10,-.10),(-.10,.10),(.10,.10)]):
            with w.part('Exposed wafer field',(x,y,0)) as field:
                start=36+i*32
                animate(field,'scale',lambda p,start=start:(1,1,max(.0001,sample(p,[(0,0),(start,0),(start+10,1),(174,1),(180,0),(192,0)]))))
                for dx in (-.035,.035):
                    for dy in (-.035,.035):
                        w.box('Lithographic die pattern',(dx,dy,.022),(.055,.055,.006),w.gold,.001)
    for x in (-.90,.90):
        w.box('Load-lock sidewall',(x,-1.53,1.085),(.07,.72,1.23),w.white)
    w.box('Load-lock front wall',(0,-1.91,1.085),(1.86,.07,1.23),w.white)
    w.box('Load-lock roof',(0,-1.53,1.70),(1.86,.80,.08),w.white)
    for x in (-1.55,1.58):
        service(w,(x,-.36,0),.61,1.50,w.white)
        for z in (1.03,1.43,1.83):
            w.box('Service module seam',(x,-.69,z),(.44,.015,.012),w.steel,.001)
    service(w,(1.59,1.24,0),.63,1.65,w.white)
    w.cyl('Vacuum turbo pump',(1.49,.68,1.13),.25,.46,w.steel,'Y')
    w.pipe('Vacuum chamber pump elbow',[(1.00,.68,1.13),(1.23,.68,1.13),(1.49,.68,1.13)],.10,w.steel)
    w.pipe('Enclosed source service feed',[(-1.45,.65,.84),(-1.45,.84,.84),(-1.32,.84,.84)],.055,w.blue)
    gauge(w,(1.52,-.70,1.72),.08)
    def check(p):
        for start in (36,68,100,132):
            if start<=p<start+12:
                a=sample(p,stage_keys);b=sample(start,stage_keys)
                assert (Vector(a)-Vector(b)).length<.00001,'Exposure occurs during wafer stage motion'
    return finish(w,check,1.27)
