"""Model-first process revision; scrub the marked phases in Blender."""
import math
import bpy
from mathutils import Vector
from review_geometry import PERIOD, sample, animate, move, begin, finish, ports, hood, beam
from semiconductor_geometry import service, gauge, wafer, lamp


def build(w):
    begin(w,[(20,'Place die on leadframe'),(48,'Bond first contact'),(84,'Wire bonds complete'),
             (124,'Mould closed'),(136,'Encapsulation formed'),(166,'Finished package leaves line')])
    ports(w,(0,))
    w.box('Precision process bed',(0,-.60,.68),(3.98,1.02,.42),w.white)
    for y in (-.97,-.23):
        w.box('Carrier guide',(0,y,.95),(4.0,.06,.11),w.steel)
    hood(w,'Leadframe input',-1.85,-.60,.50,.88,1.35)
    hood(w,'Package output',1.88,-.60,.60,.88,1.45)
    carrier_keys=[(0,(-1.85,-.60,.97)),(8,(-1.10,-.60,.97)),(30,(-1.10,-.60,.97)),
                  (42,(-.10,-.60,.97)),(94,(-.10,-.60,.97)),(108,(1.08,-.60,.97)),
                  (154,(1.08,-.60,.97)),(168,(1.88,-.60,.97)),(176,(1.88,-.60,.25)),
                  (184,(-1.85,-.60,.25)),(192,(-1.85,-.60,.97))]
    with w.part('Continuous leadframe carrier') as carrier:
        move(carrier,carrier_keys)
        w.box('Copper leadframe',(0,0,0),(.40,.38,.035),w.copper,.002)
        for side in (-1,1):
            for i in range(4):
                w.box('Leadframe pin',(-.13+i*.085,side*.25,0),(.035,.16,.018),w.gold,0)
        # Bonds are deposited in contact order while the capillary dwells there.
        for i,(x,y) in enumerate([(-.10,-.10),(.10,-.10),(.10,.10),(-.10,.10)]):
            with w.part('Deposited bond wire') as bond:
                start=52+i*8
                animate(bond,'scale',lambda p,start=start:(1,1,sample(p,[(0,0),(start,0),(start+3,1),(172,1),(176,0),(192,0)])))
                w.pipe('Gold bond bridge',[(x*.45,y*.45,.088),(x*.7,y*.7,.14),(x*1.5,y*1.5,.04)],.007,w.gold)
        with w.part('Formed package encapsulation') as cap:
            animate(cap,'scale',lambda p:(1,1,sample(p,[(0,0),(124,0),(136,1),(172,1),(176,0),(192,0)])))
            w.box('Moulded black package',(0,0,.09),(.32,.32,.13),w.iron,.015)
    die_keys=[(0,(-1.10,.47,1.02)),(8,(-1.10,.47,1.02)),(14,(-1.10,.47,1.47)),
              (20,(-1.10,-.60,1.47)),(26,(-1.10,-.60,1.035)),(30,(-1.10,-.60,1.035))]
    def die_at(p):
        if p<=30:return sample(p,die_keys)
        if p<=172:
            c=sample(p,carrier_keys);return (c[0],c[1],c[2]+.065)
        return sample(p,[(172,(1.88,-.60,1.035)),(178,(1.88,-.60,.25)),(184,(-1.10,.47,.25)),(192,(-1.10,.47,1.02))])
    with w.part('Continuous placed silicon die') as die:
        animate(die,'location',die_at)
        w.box('Silicon die',(0,0,0),(.15,.15,.035),w.steel,.003)
    hood(w,'Die tape feeder',-1.10,.47,.55,.62,1.23,slot=.28)
    w.box('Die picker rear column',(-1.10,.96,1.32),(.24,.24,1.70),w.white)
    picker_keys=[(0,(-1.10,.47,1.65)),(8,(-1.10,.47,1.2675)),
                 (14,(-1.10,.47,1.7175)),(20,(-1.10,-.60,1.7175)),(26,(-1.10,-.60,1.2825)),
                 (30,(-1.10,-.60,1.2825)),(38,(-1.10,-.60,1.85)),(172,(-1.10,-.60,1.85)),(192,(-1.10,.47,1.65))]
    w.box('Die picker overhead slide',(-1.10,.17,2.15),(.22,1.80,.16),w.steel)
    ram=w.cyl('Connected die picker ram',(0,0,0),.05,1,w.steel)
    animate(ram,'location',lambda p:(-1.10,sample(p,picker_keys)[1],(2.09+sample(p,picker_keys)[2]+.12)/2))
    animate(ram,'scale',lambda p:(1,1,2.09-sample(p,picker_keys)[2]-.12))
    with w.part('Die placement vacuum nozzle') as picker:
        move(picker,picker_keys)
        w.cyl('Die vacuum tip',(0,0,-.15),.028,.16,w.steel)
        w.box('Picker head',(0,0,.02),(.24,.28,.20),w.iron)
    w.box('Wire bonder pedestal',(-.10,.45,1.20),(.46,.55,1.45),w.white)
    w.box('Bonder overhang',(-.10,-.15,1.94),(.48,1.38,.20),w.white)
    with w.part('Working bonding capillary') as head:
        key=[(0,(-.20,-.70,1.67)),(46,(-.20,-.70,1.67))]
        for i,(x,y) in enumerate([(-.10,-.10),(.10,-.10),(.10,.10),(-.10,.10)]):
            start=48+i*8
            key.extend([(start,(-.10+x,-.60+y,1.67)),(start+3,(-.10+x,-.60+y,1.41)),
                        (start+6,(-.10+x,-.60+y,1.41)),(start+7,(-.10+x,-.60+y,1.67))])
        key.extend([(90,(-.20,-.70,1.67)),(192,(-.20,-.70,1.67))])
        move(head,key)
        w.cyl('Bonding capillary',(0,0,-.20),.022,.30,w.brass)
        w.cyl('Bonding head',(0,0,.02),.095,.22,w.steel)
    w.cyl('Gold wire spool',(-.10,.45,2.12),.16,.20,w.gold,'X')
    for x in (.73,1.43):
        for y in (-1.03,-.17):
            w.cyl('Mould guide',(x,y,1.42),.035,1.0,w.steel)
    w.box('Mould crosshead',(1.08,-.60,1.99),(.88,1.03,.20),w.ochre)
    with w.part('Mould closing tool') as press:
        animate(press,'location',lambda p:(1.08,-.60,sample(p,[(0,1.72),(114,1.72),(124,1.235),(140,1.235),(152,1.72),(192,1.72)])))
        w.box('Upper cavity tool',(0,0,0),(.58,.60,.20),w.steel)
    w.box('Lower package mould',(1.08,-.60,.92),(.58,.60,.06),w.iron)
    piston=w.cyl('Mould closing piston',(0,0,0),.09,1,w.steel)
    press_z=lambda p:sample(p,[(0,1.72),(114,1.72),(124,1.235),(140,1.235),(152,1.72),(192,1.72)])
    animate(piston,'location',lambda p:(1.08,-.60,(1.89+press_z(p)+.10)/2))
    animate(piston,'scale',lambda p:(1,1,1.89-press_z(p)-.10))
    service(w,(1.52,1.38,0),.78,.85)
    w.pipe('Press air supply',[(1.52,1.08,1.05),(1.52,.48,1.05),(1.08,.12,1.88),(1.08,-.16,1.88)],.035,w.blue)
    def check(p):
        if 30<=p<=168:
            c=sample(p,carrier_keys)
            assert (Vector(die_at(p))-Vector((c[0],c[1],c[2]+.065))).length<.00001,'Placed die detaches from leadframe'
        if 124<=p<=140:assert press.location.z<1.24,'Encapsulation forms before the mould closes'
        if 94<=p<=108 or 154<=p<=168:assert press.location.z>1.70,'Carrier indexes through closed mould'
    return finish(w,check,1.0)
