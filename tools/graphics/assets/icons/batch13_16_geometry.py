"""Memory generations, semiconductor workpieces and stored-model cartridges."""
import math


def memory(w,tier=0):
    colors=[(.05,.20,.08),(.07,.25,.10),(.035,.12,.30),(.025,.24,.17),(.20,.055,.28),(.025,.20,.25)]
    pcb=w.material('Memory generation laminate',colors[tier],.25,.4)
    w.box('Memory PCB',(0,0,.20),(3.7,1.45,.13),pcb,.025)
    for i in range(28):
        if i in (10+tier%4,11+tier%4):continue
        w.box('Memory gold finger',((i-13.5)*.125,-.63,.28),(.075,.24,.025),w.gold,.001)
    count=4 if tier<2 else 6 if tier==2 else 8
    for i in range(count):
        x=(i-(count-1)/2)*(3.25/count)
        w.box('Memory package',(x,.15,.40),(2.8/count,.83,.22),w.iron,.02)
        if tier==0:
            for y in (-.32,.62):
                for dx in (-.22,-.07,.07,.22):w.box('DIP memory lead',(x+dx,y,.32),(.04,.12,.05),w.steel,.001)
    if tier>=4:
        for sign in (-1,1):
            w.box('Segmented heat spreader',(sign*.92,.15,.57),(1.62,1.03,.14),w.steel,.035)
            for i in range(5):w.box('Spreader groove',(sign*.92+(i-2)*.24,.15,.65),(.04,.78,.015),w.black,.002)
    if tier==5:w.box('Central power management package',(0,.15,.55),(.35,.64,.22),w.gold,.018)
    for i in range(max(1,tier)):
        w.box('Generation marker',((i-(max(1,tier)-1)/2)*.20,.62,.31),(.12,.13,.03),w.gold,.001)
    return [4,4],.40,5


def transistor(w):
    for x in (-.65,0,.65):w.box('Transistor lead',(x,-.20,.22),(.16,2.4,.16),w.steel,.02)
    w.box('Metal transistor tab',(0,.35,.42),(1.95,1.80,.18),w.steel,.08)
    w.box('Moulded transistor body',(0,-.05,.69),(2.05,1.35,.52),w.iron,.09)
    w.ring('Tab mounting eye',(0,1.04,.54),.22,.065,w.steel)
    w.cyl('Mounting recess',(0,1.04,.535),.16,.025,w.black)
    return [4,4],.50,5


def disk(w):
    for z in (.22,.45,.68,.91):
        w.cyl('Disk platter',(0,0,z),1.40,.08,w.steel,vertices=64)
        w.ring('Platter recording band',(0,0,z+.045),1.06,.055,w.iron)
    w.cyl('Disk pack spindle',(0,0,.67),.24,1.12,w.steel)
    for x in (-.63,.63):w.box('Pack handle foot',(x,0,1.21),(.16,.30,.52),w.iron,.025)
    w.box('Pack lifting handle',(0,0,1.49),(1.42,.30,.17),w.iron,.04)
    return [4,4],.70,5


def circuit(w):
    w.box('Early control-board laminate',(0,0,.22),(2.9,2.4,.15),w.pcb,.04)
    for x in (-.85,0,.85):
        for y in (-.55,.55):
            w.ring('Valve socket',(x,y,.37),.25,.055,w.ivory)
            w.cyl('Valve socket recess',(x,y,.32),.16,.04,w.black)
            w.pipe('Socket bus',[(x,-.55,.32),(x,.55,.32)],.025,w.copper)
    for y in (-.90,.90):w.pipe('Control bus',[(-1.15,y,.32),(1.15,y,.32)],.025,w.copper)
    for x in (-.95,-.48,0,.48,.95):w.box('Board edge terminal',(x,-1.10,.35),(.24,.20,.11),w.gold,.008)
    return [4,4],.40,5


def qubit(w):
    ceramic=w.material('Error corrected qubit substrate',(.16,.055,.25),.4,.30)
    w.box('Qubit array carrier',(0,0,.22),(2.7,2.7,.20),ceramic,.04)
    for x in (-.78,0,.78):
        for y in (-.78,0,.78):
            w.box('Qubit island',(x,y,.37),(.52,.52,.10),w.gold,.025)
            w.ring('Superconducting loop',(x,y,.44),.17,.025,w.frost)
    for p in (-1.20,1.20):
        w.box('Array shielding edge',(p,0,.46),(.09,2.48,.18),w.steel,.01)
        w.box('Array shielding edge',(0,p,.46),(2.48,.09,.18),w.steel,.01)
    return [4,4],.45,5


def etchant(w):
    amber=w.material('Amber etchant vessel',(.48,.15,.025),.1,.35)
    w.cyl('Etchant bottle',(0,0,1.10),.76,1.85,amber,vertices=32)
    w.cyl('Etchant shoulder',(0,0,2.09),.53,.20,amber)
    w.cyl('Safety cap',(0,0,2.33),.32,.30,w.iron)
    w.box('Chemical hazard label',(0,-.76,1.13),(.92,.04,.88),w.ivory,.025)
    label=w.box('Hazard diamond',(0,-.80,1.15),(.43,.025,.43),w.ochre,.005);label.rotation_euler.y=math.pi/4
    w.box('Hazard symbol',(0,-.83,1.15),(.07,.025,.24),w.black,.002)
    return [4,4],1.20,5


def wafer(w,etched=False):
    color=(.035,.12,.27) if etched else (.28,.065,.32)
    mat=w.material('Etched silicon' if etched else 'Exposed photoresist',color,.70,.25)
    w.cyl('Wafer substrate',(0,0,.20),1.50,.09,mat,vertices=64)
    w.ring('Wafer edge',(0,0,.25),1.48,.018,w.steel)
    for i in range(-3,4):
        for j in range(-3,4):
            x,y=i*.37,j*.37
            if (abs(x)+.17)**2+(abs(y)+.17)**2>1.43**2:continue
            if etched:
                w.box('Etched die island',(x,y,.28),(.31,.31,.045),w.steel,.004)
                w.box('Die circuit area',(x,y,.306),(.24,.24,.014),mat,.002)
            else:
                w.box('Exposure pattern',(x,y,.253),(.30,.30,.012),w.copper,.002)
                w.box('Resist centre',(x,y,.262),(.25,.25,.01),mat,.001)
    return [4,4],.30,5


def foup(w):
    orange=w.material('FOUP amber shell',(.52,.20,.035),.18,.38)
    w.box('Wafer carrier shell',(0,0,1.10),(2.5,1.95,1.9),orange,.18)
    w.box('Front opening door',(0,-1.0,1.10),(2.18,.12,1.63),w.white,.08)
    for x in (-.85,.85):w.box('Door latch',(x,-1.09,1.12),(.16,.11,.95),w.iron,.025)
    for z in (.66,.90,1.14,1.38,1.62):w.box('Wafer carrier door rib',(0,-1.08,z),(1.30,.04,.06),w.steel,.006)
    for x in (-.60,.60):w.box('Top handle foot',(x,0,2.16),(.16,.34,.38),w.iron,.03)
    w.box('Carrier top handle',(0,0,2.36),(1.40,.34,.14),w.iron,.04)
    return [4,4],1.15,5


def model(w,frontier=False):
    color=(.30,.07,.46) if frontier else (.025,.40,.25)
    mat=w.material('Stored model pathways',color,.3,.3,emission=.25)
    w.box('Model cartridge',(0,0,.30),(2.8,2.25,.45),w.iron,.10)
    w.box('Model graph inset',(0,0,.55),(2.48,1.95,.06),w.black,.045)
    nodes=8 if frontier else 5
    points=[(.86*math.cos(i*math.tau/nodes),.69*math.sin(i*math.tau/nodes),.62) for i in range(nodes)]
    for i,p in enumerate(points):
        w.cyl('Model graph node',p,.09,.06,w.gold)
        for step in ([1,3] if frontier else [1]):w.pipe('Model graph edge',[p,points[(i+step)%nodes]],.027,mat)
    if frontier:
        for x in (-1.20,1.20):w.box('Frontier cartridge reinforcement',(x,0,.67),(.12,1.74,.18),w.steel,.02)
    else:w.cyl('General model central node',(0,0,.64),.17,.08,w.gold)
    for i in range(10):w.box('Model edge contact',((i-4.5)*.23,-1.14,.25),(.13,.17,.22),w.gold,.005)
    return [4,4],.45,5


def glass(w):
    for i in range(3):
        x,y=i*.17,i*.15;z=.25+i*.19
        w.box('Glass sheet',(x,y,z),(2.65,2.25,.09),w.glass,.02)
        for side in (-1,1):
            w.box('Glass polished edge',(x+side*1.31,y,z),(.035,2.25,.10),w.frost,.004)
            w.box('Glass polished edge',(x,y+side*1.11,z),(2.65,.035,.10),w.frost,.004)
    return [4,4],.45,5


def gpu(w):
    w.box('GPU package substrate',(0,0,.22),(3.0,2.65,.20),w.pcb,.04)
    w.box('GPU interposer',(0,0,.36),(2.65,2.30,.10),w.gold,.025)
    w.box('GPU silicon die',(0,0,.51),(1.40,1.35,.20),w.iron,.03)
    w.box('GPU die face',(0,0,.62),(1.14,1.08,.025),w.blue,.01)
    for x in (-1.02,1.02):
        for y in (-.62,.62):
            w.box('Adjacent HBM stack',(x,y,.51),(.43,.65,.24),w.iron,.02)
            for z in (.43,.50,.57):w.box('HBM bond edge',(x,y-.33,z),(.35,.02,.025),w.steel,.002)
    return [4,4],.45,5
