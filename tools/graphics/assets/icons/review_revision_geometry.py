"""Targeted icon revisions after November 9 feedback. Approved sources stay unchanged."""
import math
import bpy


def cut(w,obj,loc,size):
    tool=w.box('Temporary PCB notch',loc,size,w.black,0)
    mod=obj.modifiers.new('Connector key notch','BOOLEAN');mod.operation='DIFFERENCE';mod.object=tool
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(tool,do_unlink=True)


def ram(w,tier):
    colors=[(.035,.22,.07),(.025,.14,.31),(.035,.24,.14),(.17,.045,.25),(.02,.20,.25)]
    pcb=w.material('RAM laminate',colors[tier-1],.25,.40)
    with w.part('Tilted DIMM') as group:
        plate=w.box('DIMM board',(0,0,.18),(3.7,1.85,.12),pcb,.015)
        cut(w,plate,(-.48+tier*.12,-.89,.18),(.19,.32,.40))
        for side in (-1,1):cut(w,plate,(side*1.84,.10,.18),(.16,.22,.40))
        for i in range(30):
            x=(i-14.5)*.116
            if abs(x-(-.48+tier*.12))<.13:continue
            w.box('DIMM gold contact',(x,-.78,.255),(.07,.28,.028),w.gold,.001)
        for i in range(8):
            x=(i-3.5)*.40
            w.box('DRAM package',(x,.10,.35),(.33,.88,.21),w.iron,.018)
            w.box('Package highlight',(x,.10,.46),(.22,.58,.015),w.black,.002)
        for x in (-1.64,1.64):
            for y in (-.35,.35,.65):w.box('DIMM passive component',(x,y,.29),(.12,.08,.08),w.ivory,.003)
        if tier>=4:
            metal=w.material('DIMM heat spreader',(.16,.18,.20) if tier==4 else (.45,.48,.49),.75,.3)
            for sign in (-1,1):
                w.box('Raised heat spreader',(sign*.90,.20,.52),(1.55,1.07,.14),metal,.035)
                for i in range(5):w.box('Heat spreader channel',(sign*.90+(i-2)*.25,.2,.60),(.045,.81,.015),w.black,.002)
        if tier==5:w.box('DIMM power controller',(0,.28,.46),(.29,.45,.16),w.gold,.01)
        for i in range(tier):w.box('Generation badge',((i-(tier-1)/2)*.20,.81,.27),(.12,.13,.04),w.ivory,.002)
        group.rotation_euler.x=math.radians(38)
    return [4,4],.45,5


def transistor(w):
    tab=w.box('Radiator mounting tab',(0,.45,.36),(1.72,2.20,.16),w.copper,.015)
    tool=w.cyl('Temporary mounting hole',(0,1.12,.36),.20,.50,w.black,vertices=48)
    mod=tab.modifiers.new('Through mounting hole','BOOLEAN');mod.operation='DIFFERENCE';mod.object=tool
    bpy.context.view_layer.objects.active=tab;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
    w.box('Transistor black encapsulation',(0,-.22,.62),(1.85,1.62,.52),w.iron,.065)
    for x in (-.55,0,.55):w.box('Three metal leads',(x,-1.55,.32),(.13,1.30,.13),w.steel,.012)
    return [4,4],.50,5


def circuit(w):
    w.box('Green control PCB',(0,0,.20),(2.85,2.3,.14),w.pcb,.025)
    for x in (-.91,0,.91):
        w.box('Control logic package',(x,.35,.36),(.63,.91,.20),w.iron,.015)
        for dx in (-.22,0,.22):
            for y in (-.20,.90):w.box('Logic package pin',(x+dx,y,.28),(.07,.20,.05),w.steel,.002)
    for i in range(6):
        x=-1.10+i*.44
        w.box('Copper edge terminal',(x,-1.04,.30),(.25,.21,.09),w.gold,.004)
        w.pipe('Visible copper route',[(x,-.87,.285),(x,-.55,.285),(x*.75,-.25,.285)],.022,w.copper)
    for x in (-.90,-.30,.30,.90):
        w.cyl('Control capacitor',(x,-.52,.43),.10,.30,w.copper)
    return [4,4],.40,5


def gpu(w):
    w.box('GPU card PCB',(0,0,.20),(3.75,2.25,.14),w.pcb,.035)
    w.box('GPU card cooler',(0,.05,.47),(3.35,1.86,.40),w.iron,.075)
    for x in (-.80,.80):
        w.cyl('GPU fan recess',(x,.05,.70),.66,.055,w.black,vertices=48)
        w.ring('GPU fan rim',(x,.05,.75),.65,.035,w.steel)
        w.cyl('GPU fan hub',(x,.05,.78),.17,.12,w.steel)
        for i in range(9):
            a=i*math.tau/9
            blade=w.box('GPU swept fan blade',(x+.36*math.cos(a),.05+.36*math.sin(a),.76),(.42,.13,.04),w.steel,.005)
            blade.rotation_euler.z=a+.45
    for i in range(20):w.box('PCIe gold contact',((i-9.5)*.13,-1.04,.29),(.075,.22,.03),w.gold,.001)
    w.box('Expansion slot bracket',(-1.93,0,.43),(.11,2.45,.55),w.steel,.015)
    for y in (-.55,.45):w.box('Display output',(-2.0,y,.44),(.05,.43,.19),w.black,.006)
    return [4,4],.50,5
