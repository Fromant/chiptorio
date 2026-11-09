"""Solid, readable item silhouettes rendered through the shared GPU pipeline."""
import math


def board(w,name,size,color):
    mat=w.material(name,color,.25,.42)
    w.box('PCB laminate',(0,0,.20),(*size,.16),mat,.045)
    for x in (-size[0]/2+.13,size[0]/2-.13):
        for y in (-size[1]/2+.13,size[1]/2-.13):
            w.ring('Plated mounting hole',(x,y,.292),.065,.018,w.gold)
    for i in range(12):
        x=(i-5.5)*size[0]/14
        w.box('Gold edge finger',(x,-size[1]/2+.12,.29),(size[0]/24,.24,.025),w.gold,.002)


def trace(w,a,b):
    w.pipe('Copper routing trace',[(a[0],a[1],.295),(b[0],b[1],.295)],.018,w.copper)


def nand(w):
    board(w,'NAND green laminate',(3.5,1.55),(.025,.18,.08))
    for x in (-1.15,0,1.15):
        w.box('NAND substrate',(x,.12,.33),(.88,1.10,.08),w.iron,.025)
        for i in range(5):
            w.box('Vertically stacked NAND die',(x,.12,.40+i*.065),(.76,.92,.045),w.black,.012)
            w.box('Stack edge bond',(x,.12-.47,.40+i*.065),(.70,.02,.018),w.gold,.002)
        w.box('Package lid',(x,.12,.77),(.82,1.0,.08),w.iron,.035)
    return [4,4],.45,5


def accelerator(w):
    board(w,'Accelerator green laminate',(3.5,2.55),(.018,.20,.095))
    w.box('GPU package',(0,.10,.40),(1.42,1.42,.22),w.iron,.045)
    w.box('Copper thermal plate',(0,.10,.55),(1.26,1.26,.10),w.copper,.025)
    for x in (-.48,-.32,-.16,0,.16,.32,.48):
        w.box('GPU heat spreader fin',(x,.10,.77),(.075,1.14,.36),w.steel,.008)
    for x in (-1.13,1.13):
        for y in (-.42,.56):
            w.box('HBM stack',(x,y,.43),(.50,.66,.30),w.black,.025)
            w.box('HBM package stripe',(x,y,.59),(.34,.12,.018),w.blue,.003)
        trace(w,(x,-.86),(x,.92))
    for x in (-1.45,1.45):
        w.cyl('Power capacitor',(x,.98,.49),.10,.36,w.steel)
    w.box('Expansion bracket',(1.78,0,.38),(.10,2.65,.43),w.steel,.015)
    return [4,4],.50,5


def control(w):
    board(w,'Advanced control red laminate',(2.9,2.35),(.32,.035,.025))
    w.box('Controller package',(-.20,.15,.42),(1.22,1.20,.24),w.iron,.035)
    w.box('Silicon window',(-.20,.15,.56),(.72,.72,.035),w.black,.008)
    for i in range(7):
        x=-.70+i*.17
        for y in (-.54,.84):w.box('Controller pin',(x,y,.37),(.075,.22,.055),w.steel,.004)
    for y in (-.65,-.15,.35,.85):
        w.box('Power regulation block',(1.05,y,.41),(.32,.30,.23),w.iron,.015)
        trace(w,(.50,y),(1.05,y))
    for x in (-1.12,-.85,-.58):
        w.cyl('Control capacitor',(x,-.86,.44),.09,.30,w.copper)
    return [4,4],.4,5


def agi(w):
    # A stored model cartridge, deliberately distinct from the hardware PCBs.
    w.box('Model cartridge enclosure',(0,0,.35),(2.65,2.35,.52),w.iron,.12)
    w.box('Cartridge recessed face',(0,0,.625),(2.30,2.0,.05),w.black,.06)
    for i in range(9):
        w.box('Model cartridge contact',((i-4)*.24,-1.19,.29),(.14,.16,.25),w.gold,.008)
    mat=w.material('Teal model pathways',(.025,.45,.40),.4,.3,emission=.25)
    points=[(-.70,-.55),(-.80,.12),(-.48,.62),(0,.77),(.58,.55),(.78,-.12),(.48,-.60),(0,-.35)]
    for a,b in [(0,1),(1,2),(2,3),(3,4),(4,5),(5,6),(6,7),(7,0),(1,7),(2,7),(4,7),(5,7)]:
        w.pipe('Stored inference graph',[(*points[a],.68),(*points[b],.68)],.035,mat)
    for x,y in points:w.cyl('Model graph node',(x,y,.70),.10,.08,w.gold)
    for x in (-1.10,1.10):w.box('Cartridge retaining edge',(x,0,.72),(.09,1.60,.10),w.steel,.02)
    return [4,4],.50,5


def analytical(w):
    wood=w.material('Oiled mechanical base',(.20,.075,.025),.15,.5)
    w.box('Mechanical computer bed',(0,0,.20),(3.1,2.3,.30),wood,.08)
    for x in (-1.28,1.28):
        w.box('Engine upright',(x,.25,.99),(.16,1.40,1.35),w.iron,.02)
    w.box('Lower brass bed',(0,.25,.43),(2.70,1.40,.13),w.brass,.015)
    for y in (-.43,.93):w.box('Open upper frame rail',(0,y,1.70),(2.70,.10,.13),w.brass,.015)
    for x in (-.76,0,.76):
        w.cyl('Register spindle',(x,.30,1.05),.075,1.24,w.steel)
        for z in (.62,.88,1.14,1.40):
            w.cyl('Decimal register drum',(x,.30,z),.28,.17,w.brass,vertices=12)
            w.ring('Register collar',(x,.30,z+.09),.27,.018,w.ivory)
    with w.part('Visible engine drive',(0,-.75,.54)):
        w.cyl('Drive gear web',(0,0,0),.49,.10,w.brass)
        for i in range(16):
            a=i*math.tau/16
            obj=w.box('Drive gear tooth',(.51*math.cos(a),.51*math.sin(a),0),(.12,.14,.12),w.brass,.005)
            obj.rotation_euler.z=a
        w.cyl('Drive gear boss',(0,0,.10),.15,.25,w.steel)
    w.box('Crank link',(.72,-.75,.60),(.95,.12,.13),w.steel,.01)
    w.cyl('Crank handle',(1.12,-.75,.80),.09,.43,w.iron)
    return [4,4],.85,5
