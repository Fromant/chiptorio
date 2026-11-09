"""Independent review revisions and HBM family. Existing accepted geometry is untouched."""
import math
import bpy

def transistor(w):
    silver=w.material('Nickel plated heat spreader',(.56,.60,.64),.8,.26)
    dark=w.material('Black resin',(.025,.03,.04),.08,.5)
    tab=w.box('Large silver mounting tab',(0,.55,.30),(2.08,2.72,.18),silver,.025)
    tool=w.cyl('Mounting hole cutter',(0,1.30,.30),.25,.65,w.black,vertices=48)
    mod=tab.modifiers.new('Radiator screw through hole','BOOLEAN');mod.operation='DIFFERENCE';mod.object=tool
    bpy.context.view_layer.objects.active=tab;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(tool,do_unlink=True)
    w.box('Resin body',(0,-.37,.57),(2.18,1.52,.53),dark,.065)
    for x in (-.65,0,.65):w.box('Nickel lead',(x,-1.66,.28),(.16,1.18,.14),silver,.012)
    return [4,4],.50,5

def gpu(w):
    from review_revision_geometry import gpu as previous
    w.iron=w.material('Graphite cooler polymer',(.045,.055,.075),.25,.45)
    w.pcb=w.material('Dark GPU laminate',(.045,.075,.10),.25,.4)
    result=previous(w)
    for obj in list(w.scene.objects):
        if obj.name.startswith('PCIe gold contact'):bpy.data.objects.remove(obj,do_unlink=True)
    trim=w.material('Cooler silver trim',(.47,.52,.57),.7,.30)
    for sign in (-1,1):
        w.box('Shroud edge rail',(0,sign*.91,.76),(3.15,.09,.12),trim,.02)
        for x in (-1.45,0,1.45):
            p=w.box('Angular shroud brace',(x,sign*.76,.80),(.38,.12,.055),trim,.012);p.rotation_euler.z=sign*.36
        for x in (-1.45,-1.30,-1.15,-.15,0,.15,1.15,1.30,1.45):
            w.cyl('Shroud perforation',(x,sign*.70,.82),.025,.015,w.black,vertices=8)
    for x in (-1.52,-.1,.1,1.52):
        w.cyl('Shroud fastener',(x,.86,.83),.04,.025,w.steel,vertices=6)
    for x in (-1.6,-1.4,-1.2,-1,-.8,-.6,-.4,-.2,0,.2,.4,.6,.8,1,1.2,1.4,1.6):
        w.box('Visible heatsink fin',(x,-.94,.48),(.025,.18,.28),w.steel,0)
    for y in (1.01,1.09):w.pipe('Exposed cooler heatpipe',[(-1.45,y,.45),(1.40,y,.45)],.035,w.copper)
    # Two unequal edge-finger groups separated by a physical key gap.
    for left,right,count in [(-1.35,-.80,5),(-.65,1.45,21)]:
        w.box('PCIe laminate tongue',((left+right)/2,-1.25,.20),(right-left,.40,.13),w.pcb,.006)
        for i in range(count):
            x=left+(i+.5)*(right-left)/count
            w.box('PCIe finger',(x,-1.30,.278),((right-left)/count*.64,.31,.022),w.gold,.001)
    w.box('PCIe retention tip',(1.57,-1.23,.20),(.22,.30,.13),w.pcb,.025)
    w.box('Auxiliary power socket',(1.25,.98,.52),(.54,.36,.32),w.black,.02)
    for x in (1.08,1.25,1.42):
        for y in (.90,1.06):w.box('Power socket cavity',(x,y,.688),(.09,.09,.015),w.steel,.002)
    return result

def computer(w):
    body=w.material('Blue grey machine enamel',(.19,.28,.37),.35,.40)
    accent=w.material('Insertion head orange',(.72,.29,.09),.25,.4)
    w.box('Solid assembly station base',(0,0,.25),(3.2,2.45,.30),body,.06)
    for x in (-1.30,1.30):
        w.box('Gantry side column',(x,.65,1.58),(.26,.36,2.42),body,.025)
        w.box('Column linear rail',(x,.43,1.65),(.10,.05,2.05),w.steel,.004)
    w.box('Assembly station bridge',(0,.65,2.83),(2.95,.62,.38),body,.045)
    w.box('Carriage',(0,.24,2.64),(.70,.36,.40),accent,.03)
    w.cyl('Insertion ram',(0,.15,2.02),.10,.91,w.steel)
    w.box('Insertion head',(0,.15,1.59),(.54,.45,.28),accent,.02)
    for x in (-.25,.25):w.box('Insertion jaw',(x,.15,1.34),(.07,.40,.30),w.steel,.008)
    w.box('Open computer chassis',(0,-.30,.60),(2.20,1.50,.25),w.steel,.025)
    w.box('Motherboard',(0,-.30,.75),(1.94,1.29,.05),w.pcb,.01)
    for x in (-1.08,1.08):w.box('Chassis wall',(x,-.30,.86),(.08,1.50,.42),w.steel,.012)
    for x,y in [(-.55,-.60),(.55,-.60),(-.55,0),(.55,0)]:w.box('Motherboard package',(x,y,.85),(.34,.34,.12),w.iron,.008)
    w.box('Daughtercard',(0,.15,1.09),(.065,.78,.57),w.pcb,.004)
    for y in (-.10,.20,.45):w.box('Card IC',(-.045,y,1.13),(.025,.17,.24),w.iron,.002)
    w.box('Station control console',(.95,-1.0,.57),(.60,.35,.35),body,.025)
    w.box('Console screen',(.95,-1.0,.76),(.40,.22,.025),w.blue,.008)
    return [4,4],1.45,5

def stack(w,x,y,z,layers=6,size=.87):
    base=w.material('HBM package ceramic',(.34,.39,.46),.35,.35)
    w.box('HBM substrate',(x,y,z),(size*1.18,size*1.18,.13),base,.018)
    for i in range(layers):
        height=z+.13+i*.09
        w.box('Stacked memory die',(x,y,height),(size,size,.065),w.iron,.008)
        for sign in (-1,1):w.box('Die interconnect edge',(x,y+sign*size*.50,height),(.80*size,.018,.025),w.steel,.001)
    w.box('Stack silicon top',(x,y,z+.15+layers*.09),(size*.85,size*.85,.025),w.blue,.004)

def hbm_stack(w):
    stack(w,0,0,.2,8,1.75)
    for x in (-.75,-.25,.25,.75):
        for y in (-.75,-.25,.25,.75):w.cyl('Microbump contact',(x,y,.10),.045,.10,w.gold)
    return [4,4],.65,5

def hbm_module(w,new=False):
    substrate=w.material('HBM interposer',(.09,.17,.24) if new else (.10,.24,.19),.35,.35)
    w.box('Memory interposer',(0,0,.20),(3.15,2.60,.18),substrate,.04)
    for x in (-.83,.83):
        if new:
            for y in (-.65,.65):stack(w,x,y,.34,5,.90)
        else:stack(w,x,0,.34,7,1.12)
    for i in range(14):w.box('Module edge terminal',((i-6.5)*.205,-1.22,.31),(.12,.16,.035),w.gold,.001)
    if new:w.box('Central HBM controller',(0,0,.44),(.32,.61,.18),w.steel,.012)
    return [4,4],.65,5

def science(w):
    violet=w.material('HBM workload cartridge',(.25,.13,.34),.35,.4)
    w.box('Research test carrier',(0,0,.26),(2.75,2.55,.30),violet,.07)
    for x in (-.65,.65):stack(w,x,.20,.47,4,.77)
    w.box('Workload readout plaque',(0,-.90,.53),(2.16,.40,.18),w.ivory,.02)
    for i in range(6):w.box('Workload result field',((i-2.5)*.29,-.92,.63),(.19,.20,.025),w.blue,.002)
    for x in (-1.20,1.20):w.box('Carrier locking rail',(x,0,.58),(.10,2.30,.40),w.steel,.01)
    return [4,4],.60,5
