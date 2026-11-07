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
        angle=math.atan2(x,-.15)
        for dx in (-.30,.30):
            support=w.box(title+' singulation edge rest',(x+math.cos(angle)*dx,-1.35-math.sin(angle)*dx,1.09),(.05,.18,.055),w.ivory,.003)
            support.rotation_euler.z=-angle
        for dx in (-.42,.42):
            w.box(title+' magazine side cover',(x+dx,-1.35,1.0),(.06,.90,.12),w.white)
        for dy in (-.42,.42):
            w.box(title+' magazine end cover',(x,-1.35+dy,1.0),(.84,.06,.12),w.white)
        # Rear cover conceals the return/resupply path below the constant pile.
        w.box(title+' elevator back', (x,-.85,.99), (.90,.08,1.04), w.white)
    # Actual open-front chamber, not a wafer pushed through a solid cylinder.
    w.cyl('Chamber isolation foot',(0,.95,.62),.91,.30,w.iron)
    for i in range(24):
        a=(-.25+1.5*i/23)*math.pi
        wall=w.box('Vacuum vessel curved wall',(.82*math.cos(a),.95+.82*math.sin(a),1.17),(.14,.20,.94),w.steel)
        wall.rotation_euler.z=a
    w.cyl('Chamber roof',(0,.95,1.70),.87,.12,w.white)
    w.cyl('Wafer process podium',(0,.90,.87),.41,.22,w.iron)
    for x in (-.28,0,.28):
        w.box('Slotted chuck support land',(x,.90,1.04125),(.06,.30,.1225),w.steel,.002)
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
        w.box('Opaque gate panel',(0,0,0),(1.16,.08,.51),w.steel)
        w.box('Gate inspection slit',(0,-.045,.06),(.54,.015,.06),w.black)
    process=lamp(w,'Chamber process glow',(.24,.47,.85),'(1 if 86<=((frame-1)%192)<112 else 0)',1.3)
    w.box('Chamber process indicator',(.63,.18,1.53),(.09,.035,.12),process)
    w.cyl('Robot pedestal',(0,-1.20,.62),.27,.36,w.iron)
    w.cyl('Robot linear mast',(0,-1.20,1.35),.09,1.05,w.steel)
    origin=(0,-1.20)
    input_angle=math.atan2(-1.35,-.15)
    output_angle=-input_angle
    pile_r=math.hypot(1.35,.15)
    fork_keys=[(0,(-math.pi,.95,1.09)),(8,(input_angle,pile_r,1.09)),(16,(input_angle,pile_r,1.09)),
               (26,(input_angle,pile_r,1.76)),(40,(0,.75,1.76)),(48,(0,.75,1.09)),
               (60,(0,2.10,1.09)),(64,(0,2.10,1.075)),(66,(0,2.10,1.04)),(76,(0,.75,1.04)),
               (114,(0,.75,1.04)),(120,(0,.75,1.04)),(128,(0,2.10,1.04)),(132,(0,2.10,1.075)),(136,(0,2.10,1.10)),
               (146,(0,.75,1.10)),(152,(0,.75,1.76)),(164,(output_angle,pile_r,1.76)),
               (170,(output_angle,pile_r,1.09)),(176,(output_angle,pile_r,1.088)),
               (184,(math.pi,.95,1.088)),(192,(math.pi,.95,1.09))]
    def polar(p):return sample(p,fork_keys)
    def setback(p):return min(.60,polar(p)[1]-.25)
    def tip(p):
        angle,r,z=polar(p)
        return (origin[0]+math.sin(angle)*r,origin[1]+math.cos(angle)*r,z)
    input_p=(-1.35,-1.35,1.13);output=(1.35,-1.35,1.13);chuck=(0,.90,1.115)
    def payload_at(p):
        if p<=16:return input_p
        if p<=64 or 132<=p<=170:
            x,y,z=tip(p);return (x,y,z+.04)
        if p<132:return chuck
        if p<=180:return output
        return sample(p,[(180,output),(184,(1.35,-1.35,.20)),(188,(-1.35,-1.35,.20)),(192,input_p)])
    # The thick slide ends behind the wafer; only the slender fork enters its nest.
    arm=w.box('Single telescoping transfer beam',(0,0,0),(.12,1,.085),w.steel)
    animate(arm,'location',lambda p:(origin[0]+math.sin(polar(p)[0])*(polar(p)[1]-setback(p))/2,
                                    origin[1]+math.cos(polar(p)[0])*(polar(p)[1]-setback(p))/2,tip(p)[2]-.08))
    animate(arm,'rotation_euler',lambda p:(0,0,-polar(p)[0]))
    animate(arm,'scale',lambda p:(1,polar(p)[1]-setback(p),1))
    collar=w.cyl('Supported robot mast carriage',(0,-1.20,1.1),.14,.16,w.steel)
    animate(collar,'location',lambda p:(0,-1.20,tip(p)[2]-.08))
    with w.part('Wafer fork') as fork:
        animate(fork,'location',tip)
        animate(fork,'rotation_euler',lambda p:(0,0,-polar(p)[0]))
        crossbar=w.box('Fork crossmember',(0,0,0),(.38,.08,.055),w.steel)
        animate(crossbar,'location',lambda p:(0,-setback(p),0))
        coupling=w.box('Fork to beam coupling',(0,0,-.04),(.18,.12,.12),w.steel)
        animate(coupling,'location',lambda p:(0,-setback(p),-.04))
        for x in (-.15,.15):
            tine=w.box('Under-wafer vacuum tine',(x,0,0),(.055,1,.055),w.ivory,.004)
            animate(tine,'location',lambda p,x=x:(x,(.22-setback(p))/2,0))
            animate(tine,'scale',lambda p:(1,.22+setback(p),1))
    with w.part('One continuously transported wafer') as payload:
        animate(payload,'location',payload_at)
        wafer(w,'Blank input wafer',radius=.34,etched=False)
        with w.part('Etched die pattern') as pattern:
            animate(pattern,'scale',lambda p:(1,1,max(.0001,sample(p,[(0,0),(86,0),(108,1),(178,1),(182,0),(192,0)]))))
            for x in (-.16,-.08,0,.08,.16):
                for y in (-.16,-.08,0,.08,.16):
                    w.box('Processed die',(x,y,.022),(.065,.065,.009),w.gold,.001)
    service(w,(1.55,1.3,0),.66,1.05,w.white)
    w.pipe('Vacuum pump connection',[(.80,1.10,.94),(1.12,1.10,.94),(1.28,1.3,.94)],.055,w.steel)
    def check(p):
        wafer_pos=payload_at(p)
        if 64<=p<=132:
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
