"""Model-first process revision; scrub the marked phases in Blender."""
import math
import bpy
from mathutils import Vector
from review_geometry import PERIOD, sample, animate, move, begin, finish, ports, hood, beam
from semiconductor_geometry import service, gauge, wafer, lamp


def build(w):
    begin(w,[(12,'Grip supplied card'),(48,'Align above socket'),(72,'Insert card'),
             (92,'Release and retract'),(120,'Electrical test'),(148,'Completed chassis enters output')])
    ports(w,(0,))
    # Real openings for the blank-chassis elevator and output chute, instead of
    # lifting the chassis through a solid foundation deck.
    for y in (-.25,1.48):
        cutter=w.box('Temporary elevator opening',(.40,y,.30),(1.60,1.06,1.40),w.black,0,'Reference')
        for name in ('Cast plinth','Service deck'):
            obj=next(o for o in bpy.data.objects if o.name==name)
            mod=obj.modifiers.new('Chassis elevator aperture','BOOLEAN')
            mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
            bpy.context.view_layer.objects.active=obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter,do_unlink=True)

    hood(w,'Card feeder',-1.45,-.65,.72,1.0,1.62,slot=.56)
    hood(w,'Output test tunnel',.40,1.48,1.72,.96,1.85)
    for x in (-1.95,1.95):
        for y in (-1.45,1.45):
            w.box('Gantry anchored column',(x,y,1.52),(.16,.18,2.10),w.paint)
        w.box('Long gantry rail',(x,0,2.62),(.16,3.22,.16),w.steel)
    for x in (-.30,1.10):
        for y in (-.72,.22):
            w.box('Chassis elevator support',(x,y,.69),(.13,.13,.48),w.iron)
    for x in (-.30,1.10):
        w.box('Chassis transfer support rail',(x,.60,.87),(.13,2.20,.09),w.steel)
    case_keys=[(0,(.40,-.25,.95)),(126,(.40,-.25,.95)),(148,(.40,1.48,.95)),
               (158,(.40,1.48,.12)),(178,(.40,-.25,.12)),(192,(.40,-.25,.95))]
    with w.part('Continuous chassis elevator pallet') as case:
        move(case,case_keys)
        w.box('Chassis floor',(0,0,0),(1.45,.92,.07),w.steel)
        w.box('Computer backplane',(0,0,.055),(1.26,.77,.035),w.pcb,.004)
        for x in (-.70,.70):
            w.box('Chassis side rail',(x,0,.13),(.065,.92,.22),w.steel)
        w.box('Card receiving socket',(0,0,.10),(.10,.65,.08),w.ivory,.003)
        for x in (-.43,.43):
            for y in (-.25,.25):
                w.box('Backplane component',(x,y,.13),(.18,.15,.09),w.iron,.003)
    card_keys=[(0,(-1.45,-.65,1.25)),(16,(-1.45,-.65,1.25)),(30,(-1.45,-.65,2.00)),
               (48,(.40,-.25,2.00)),(72,(.40,-.25,1.30)),(126,(.40,-.25,1.30)),
               (148,(.40,1.48,1.30)),(158,(.40,1.48,.10)),(180,(-1.45,-.65,.10)),(192,(-1.45,-.65,1.25))]
    with w.part('Single supplied daughtercard') as card:
        move(card,card_keys)
        w.box('Daughtercard board',(0,0,0),(.045,.64,.43),w.pcb,.003)
        for y in (-.20,0,.20):
            w.box('Daughtercard IC',(-.035,y,.015),(.025,.13,.17),w.iron,.002)
        w.box('Gold card edge',(0,0,-.21),(.048,.58,.028),w.gold,.001)
    grip_keys=[(0,(-1.45,-.65,2.20)),(8,(-1.45,-.65,1.52)),(16,(-1.45,-.65,1.52)),
               (30,(-1.45,-.65,2.27)),(48,(.40,-.25,2.27)),(72,(.40,-.25,1.57)),
               (80,(.40,-.25,1.57)),(94,(.40,-.25,2.27)),(160,(.40,-.25,2.27)),(192,(-1.45,-.65,2.20))]
    with w.part('Insertion gripper') as grip:
        move(grip,grip_keys)
        w.box('Gripper body',(0,0,.12),(.36,.40,.23),w.iron)
        for side in (-1,1):
            jaw=w.box('Opening gripping finger',(side*.10,0,-.09),(.045,.34,.28),w.steel)
            animate(jaw,'location',lambda p,side=side:(side*sample(p,[(0,.22),(8,.22),(12,.065),(76,.065),(82,.22),(192,.22)]),0,-.09))
    gantry=w.box('Travelling cross bridge',(0,0,2.63),(4.0,.22,.20),w.ochre)
    animate(gantry,'location',lambda p:(0,sample(p,grip_keys)[1],2.63))
    # The sliding vertical ram ends at the gripper, below its fixed cross bridge.
    ram=w.cyl('Telescopic insertion ram',(0,0,0),.065,1,w.steel)
    animate(ram,'location',lambda p:(sample(p,grip_keys)[0],sample(p,grip_keys)[1],(2.60+sample(p,grip_keys)[2]+.24)/2))
    animate(ram,'scale',lambda p:(1,1,2.60-sample(p,grip_keys)[2]-.24))
    tested=lamp(w,'Test passed',(.10,.70,.24),'(1 if 112<=((frame-1)%192)<126 else 0)',1.2)
    w.box('Fixture test indicator',(1.15,-.30,1.05),(.08,.16,.08),tested)
    service(w,(-1.55,1.30,0),.65,1.0)
    def check(p):
        c=sample(p,card_keys)
        if 80<=p<=126:
            assert (Vector(c)-Vector((.4,-.25,1.30))).length<.00001,'Inserted card must stay in its socket'
        if 126<=p<=148:
            assert (Vector(c)-Vector(sample(p,case_keys))-Vector((0,0,.35))).length<.00001,'Card separates from outgoing chassis'
        if 16<=p<=72:
            assert abs(sample(p,grip_keys)[2]-c[2]-.27)<.00001,'Card separates from closed gripper'
        if 94<=p<=148:
            assert sample(p,grip_keys)[2]>2.20,'Chassis indexes under lowered gripper'
    return finish(w,check,1.08)
