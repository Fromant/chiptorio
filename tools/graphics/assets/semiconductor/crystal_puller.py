"""Model-first process revision; scrub the marked phases in Blender."""
import math
import bpy
from mathutils import Vector
from review_geometry import PERIOD, sample, animate, move, begin, finish, ports, hood, beam
from semiconductor_geometry import service, gauge, wafer, lamp


def build(w):
    begin(w,[(0,'Seed touches melt'),(72,'Crystal grown'),(90,'Lift clear'),
             (114,'Transfer over cooling well'),(132,'Lower into cooling well'),(156,'Return seed')])
    graphite=w.material('Hot zone graphite',(.025,.028,.029),.1,.8)
    silicon=w.material('Single crystal silicon',(.31,.38,.43),.9,.2)
    heat=lamp(w,'Silicon melt heat',(1,.24,.028),'(1 if ((frame-1)%192)<100 else .12)',2)
    w.cyl('Furnace foot',(-.52,-.12,.62),1.0,.30,w.iron)
    w.cyl('Water cooled vessel',(-.52,-.12,.96),.86,.48,w.steel)
    w.cyl('Crucible mouth',(-.52,-.12,1.23),.75,.08,graphite)
    w.ring('Furnace flange',(-.52,-.12,1.29),.85,.05,w.steel)
    w.cyl('Visible melt',(-.52,-.12,1.31),.55,.025,heat)
    for i in range(12):
        a=i*math.tau/12
        w.cyl('Flange tie rod',(-.52+.80*math.cos(a),-.12+.80*math.sin(a),1.03),.025,.46,w.iron)
    # Cooling well walls are hollow: the crystal lowers into a real void.
    w.cyl('Cooling receiver foot',(1.34,-.12,.51),.49,.08,w.iron)
    for i in range(24):
        a=i*math.tau/24
        wall=w.box('Cooling receiver wall',(1.34+.43*math.cos(a),-.12+.43*math.sin(a),1.03),(.10,.14,.76),w.paint)
        wall.rotation_euler.z=a
    w.ring('Cooling receiver lip',(1.34,-.12,1.43),.44,.04,w.steel)
    for x in (-1.70,2.10):
        w.box('Hoist cast shoe',(x,.45,.59),(.48,.62,.28),w.iron)
        for dx in (-.17,.17):
            for dy in (-.22,.22):w.cyl('Hoist anchor',(x+dx,.45+dy,.75),.035,.09,w.steel)
        w.box('Hoist upright',(x,.45,2.03),(.20,.24,2.78),w.steel)
        w.box('Hoist guide',(x,.30,2.03),(.08,.035,2.53),w.iron)
        for side in (-1,1):
            brace=w.box('Tower shoe gusset',(x+side*.12,.45,.96),(.075,.39,.56),w.paint)
            brace.rotation_euler.y=side*.30
    w.box('Extraction bridge',(.20,.45,3.48),(4.34,.47,.30),w.paint,.035)
    w.box('Carriage rail',(.20,.18,3.48),(4.10,.05,.10),w.steel)
    xkeys=[(0,-.52),(90,-.52),(114,1.34),(156,1.34),(176,-.52),(192,-.52)]
    topkeys=[(0,1.43),(72,2.13),(90,2.45),(114,2.45),(132,1.40),(140,1.40),(156,2.45),(176,2.45),(192,1.43)]
    heightkeys=[(0,.12),(72,.82),(132,.82),(140,.12),(192,.12)]
    with w.part('Travelling pull head') as head:
        animate(head,'location',lambda p:(sample(p,xkeys),-.12,0))
        w.box('Pull head carriage',(0,.17,3.31),(.45,.55,.33),w.ochre)
        w.box('Spindle gearbox',(0,-.13,3.18),(.40,.28,.27),w.steel,.035)
        w.cyl('Geared hoist motor',(.31,.12,3.31),.15,.36,w.iron,'X')
        for x in (.19,.25,.31,.37,.43):w.ring('Motor cooling fin',(x,.12,3.31),.16,.016,w.steel,'X')
        w.box('Gearbox inspection glass',(0,-.278,3.18),(.16,.018,.08),w.blue,.004)
        # Telescoping draw spindle ends at the gearbox underside, never through it.
        shaft=w.cyl('Variable length seed draw spindle',(0,0,0),.035,1,w.steel)
        animate(shaft,'location',lambda p:(0,0,(3.02+sample(p,topkeys))/2))
        animate(shaft,'scale',lambda p:(1,1,3.02-sample(p,topkeys)))
        with w.part('Growing crystal') as crystal:
            animate(crystal,'location',lambda p:(0,0,sample(p,topkeys)))
            animate(crystal,'rotation_euler',lambda p:(0,0,math.tau*p/PERIOD))
            boule=w.cyl('Continuous silicon boule',(0,0,-.5),.23,1,silicon,vertices=12)
            animate(boule,'location',lambda p:(0,0,-sample(p,heightkeys)/2))
            animate(boule,'scale',lambda p:(1,1,sample(p,heightkeys)))
            w.cyl('Seed neck',(0,0,.025),.045,.10,silicon)
    service(w,(1.58,-1.56,0),.77,.80)
    w.cyl('Vacuum pump',(-1.54,-1.65,.79),.24,.69,w.steel,'X')
    w.box('Pump mount',(-1.54,-1.65,.55),(.93,.55,.20),w.iron)
    w.pipe('Vessel vacuum elbow',[(-1.23,-.40,.90),(-1.81,-.61,.90),(-1.81,-1.52,.79)],.075,w.steel)
    w.pipe('Chamber coolant',[(-.02,-.81,.91),(.55,-1.30,.64),(1.46,-1.30,.64)],.055,w.blue)
    gauge(w,(-.99,-.96,.92))
    def check(p):
        top=sample(p,topkeys);height=sample(p,heightkeys);x=sample(p,xkeys)
        if 90<=p<=114:assert top-height>1.47,'Transfer before crystal clears vessel lip'
        if 114<p<156:assert abs(x-1.34)<.00001,'Crystal lowers away from receiver'
        if 132<=p<=140:assert top<1.44,'Crystal resizes outside the opaque cooling receiver'
        assert shaft.location.z+shaft.scale.z/2<=3.02001,'Draw spindle penetrates gearbox'
    return finish(w,check,1.15)
