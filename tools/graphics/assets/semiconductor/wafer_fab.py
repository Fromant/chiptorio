"""Model-first process revision; scrub the marked phases in Blender."""
import math
import bpy
from mathutils import Vector
from review_geometry import PERIOD, sample, animate, move, begin, finish, ports, hood, beam
from semiconductor_geometry import service, gauge, wafer, lamp


def build(w):
    begin(w, [(8,'Pick from input pile'),(60,'Place in open chamber'),(84,'Gate closed - process'),
              (128,'Retrieve processed wafer'),(170,'Place on output pile')], True)
    ports(w, (-1, 1))
    for x, title in [(-1.35,'Input'),(1.35,'Output')]:
        w.box(title+' cassette elevator', (x,-1.35,.70), (.92,.94,.48), w.iron)
        for i in range(6):
            wafer(w,title+' pile wafer',(x,-1.35,.86+i*.035),.34,x>0)
        for dx in (-.30,.30):
            w.box(title+' singulation edge rest',(x+dx,-1.35,1.09),(.05,.25,.055),w.ivory,.003)
        # Rear cover conceals the return/resupply path below the constant pile.
        w.box(title+' elevator back', (x,-.85,.99), (.90,.08,1.04), w.white)
        for dx in (-.43,.43):
            w.box(title+' cassette upright',(x+dx,-1.35,.96),(.06,.88,.95),w.white)
    # Actual open-front chamber, not a wafer pushed through a solid cylinder.
    w.cyl('Chamber isolation foot',(0,.95,.62),.91,.30,w.iron)
    for i in range(24):
        a=(-.25+1.5*i/23)*math.pi
        wall=w.box('Vacuum vessel curved wall',(.82*math.cos(a),.95+.82*math.sin(a),1.17),(.14,.20,.94),w.steel)
        wall.rotation_euler.z=a
    w.cyl('Chamber roof',(0,.95,1.70),.87,.12,w.white)
    w.cyl('Wafer process podium',(0,.90,.92),.41,.32,w.iron)
    w.cyl('Wafer support chuck',(0,.90,1.085),.34,.025,w.steel)
    for x in (-.64,.64):
        w.box('Gate guide post',(x,.03,1.92),(.10,.18,.85),w.white)
        w.box('Gate opening sidewall',(x,.20,1.17),(.10,.38,.94),w.steel)
    w.box('Gate lift crosshead',(0,.03,2.35),(1.38,.20,.12),w.white)
    w.box('Gate threshold',(0,.20,.80),(1.20,.38,.23),w.steel)
    w.box('Chamber front lintel',(0,.25,1.54),(1.20,.30,.22),w.steel)
    with w.part('Sliding chamber gate',(0,.03,1.17)) as gate:
        gate_keys=[(0,1.17),(30,1.17),(42,1.84),(78,1.84),(84,1.17),
                   (114,1.17),(124,1.84),(148,1.84),(158,1.17),(192,1.17)]
        animate(gate,'location',lambda p:(0,.03,sample(p,gate_keys)))
        w.box('Opaque gate panel',(0,0,0),(1.20,.08,.51),w.steel)
        w.box('Gate inspection slit',(0,-.045,.06),(.54,.015,.06),w.black)
    process=lamp(w,'Chamber process glow',(.24,.47,.85),'(1 if 86<=((frame-1)%192)<112 else 0)',1.3)
    w.box('Chamber process indicator',(.63,.18,1.53),(.09,.035,.12),process)
    w.cyl('Robot pedestal',(0,-.70,.62),.27,.36,w.iron)
    w.cyl('Robot linear mast',(0,-.70,1.15),.09,.65,w.steel)
    input_p=(-1.35,-1.35,1.13)
    chuck=(0,.90,1.115)
    output=(1.35,-1.35,1.13)
    payload_keys=[(0,(-1.35,-1.35,1.13)),(8,input_p),(16,input_p),
                  (26,(-1.35,-1.35,1.40)),(40,(0,-.12,1.40)),
                  (48,(0,-.12,1.13)),(60,(0,.90,1.13)),(64,chuck),(130,chuck),
                  (136,(0,.90,1.14)),(146,(0,-.12,1.14)),(152,(0,-.12,1.40)),
                  (164,(1.35,-1.35,1.40)),(170,output),(174,output),
                  (180,output),(184,(1.35,-1.35,.20)),(188,(-1.35,-1.35,.20)),(192,(-1.35,-1.35,1.13))]
    fork_keys=[(0,(0,-.12,1.09)),(8,(-1.35,-1.35,1.09)),(16,(-1.35,-1.35,1.09)),
               (26,(-1.35,-1.35,1.36)),(40,(0,-.12,1.36)),(48,(0,-.12,1.09)),
               (60,(0,.90,1.09)),(66,(0,.90,1.04)),(76,(0,-.12,1.04)),
               (114,(0,-.12,1.04)),(128,(0,.90,1.04)),(136,(0,.90,1.10)),
               (146,(0,-.12,1.10)),(152,(0,-.12,1.36)),(164,(1.35,-1.35,1.36)),
               (170,(1.35,-1.35,1.09)),(176,(1.35,-1.35,1.075)),
               (184,(0,-.12,1.075)),(192,(0,-.12,1.09))]
    tip=lambda p:sample(p,fork_keys)
    beam(w,'Single telescoping transfer beam',(0,-.70),lambda p:(tip(p)[0],tip(p)[1],tip(p)[2]+.02))
    collar=w.cyl('Supported robot mast carriage',(0,-.70,1.1),.14,.16,w.steel)
    animate(collar,'location',lambda p:(0,-.70,tip(p)[2]-.08))
    with w.part('Wafer fork') as fork:
        move(fork,fork_keys)
        w.box('Fork crossmember',(0,0,0),(.38,.08,.055),w.steel)
        w.box('Fork to beam coupling',(0,0,-.04),(.18,.12,.12),w.steel)
        for x in (-.15,.15):
            w.box('Under-wafer vacuum tine',(x,0,0),(.055,.55,.055),w.ivory,.004)
    with w.part('One continuously transported wafer') as payload:
        move(payload,payload_keys)
        wafer(w,'Blank input wafer',radius=.34,etched=False)
        with w.part('Etched die pattern') as pattern:
            animate(pattern,'scale',lambda p:(1,1,sample(p,[(0,0),(86,0),(108,1),(178,1),(182,0),(192,0)])))
            for x in (-.16,-.08,0,.08,.16):
                for y in (-.16,-.08,0,.08,.16):
                    w.box('Processed die',(x,y,.022),(.065,.065,.009),w.gold,.001)
    service(w,(1.55,1.3,0),.66,1.05,w.white)
    w.pipe('Vacuum pump connection',[(.80,1.10,.94),(1.12,1.10,.94),(1.28,1.3,.94)],.055,w.steel)
    def check(p):
        wafer_pos=sample(p,payload_keys)
        if 64<=p<=130:
            assert (Vector(wafer_pos)-Vector(chuck)).length<.00001,'Wafer moves during chamber processing'
        if 84<=p<=114:
            assert abs(gate.location.z-1.17)<.00001,'Process runs with gate open'
        if 48<=p<=76 or 124<=p<=146:
            assert gate.location.z>1.80,'Fork approaches a closed gate'
        if 48<=p<=76 or 124<=p<=146:
            assert tip(p)[2]-.1225>.915,'Beam crosses the gate threshold'
        if p in (16,60,136,170):
            assert .02<wafer_pos[2]-tip(p)[2]<.06,'Fork must support wafer from below'
    return finish(w,check,1.0)
