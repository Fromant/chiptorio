"""Process consumables and a packaged cooling component for 64px icons."""
import math


def slurry(w):
    ceramic=w.material('Creamy polishing slurry',(.65,.54,.32),.05,.65)
    w.cyl('Slurry bottle',(0,0,1.05),.78,1.80,w.ivory,vertices=32)
    w.cyl('Bottle shoulder',(0,0,1.98),.59,.22,w.ivory,vertices=32)
    w.cyl('Bottle neck',(0,0,2.20),.30,.32,w.white)
    w.cyl('Chemical safety cap',(0,0,2.41),.36,.20,w.ochre)
    w.ring('Bottle foot',(0,0,.18),.76,.04,w.steel)
    w.box('Slurry label',(0,-.765,1.10),(.92,.06,.85),ceramic,.04)
    w.cyl('Polishing disc mark',(0,-.81,1.15),.25,.035,w.steel,'Y')
    for x in (-.15,0,.15):w.box('Suspended abrasive mark',(x,-.84,.88),(.07,.02,.07),w.white,.008)
    return [4,4],1.20,5


def coolant(w):
    enamel=w.material('Coolant blue enamel',(.015,.30,.46),.35,.30)
    w.box('Coolant canister',(0,0,1.14),(1.80,1.15,1.95),enamel,.16)
    w.box('Canister base',(0,0,.20),(1.88,1.20,.16),w.steel,.035)
    w.cyl('Filling neck',(-.45,0,2.22),.25,.24,w.steel)
    w.cyl('Sealed cap',(-.45,0,2.38),.29,.14,w.iron)
    for x in (.25,.75):w.box('Handle upright',(x,0,2.34),(.13,.26,.55),w.steel,.035)
    w.box('Carrying handle',(.50,0,2.62),(.65,.26,.14),w.steel,.04)
    w.box('Coolant identification stripe',(0,-.59,1.20),(1.32,.025,.46),w.white,.02)
    for x in (-.40,0,.40):w.box('Canister strengthening rib',(x,-.59,.55),(.08,.06,.35),w.steel,.01)
    return [4,4],1.25,5


def cryogen(w):
    w.cyl('Vacuum insulated Dewar',(0,0,1.15),.76,1.95,w.steel,vertices=32)
    for z in (.22,1.97):w.ring('Dewar protective hoop',(0,0,z),.79,.055,w.iron)
    w.cyl('Vacuum shoulder',(0,0,2.17),.52,.22,w.white)
    w.cyl('Insulated valve neck',(0,0,2.39),.22,.30,w.frost)
    w.cyl('Valve head',(0,0,2.61),.32,.12,w.iron)
    w.box('Cryogenic blue plaque',(0,-.755,1.17),(.92,.05,.96),w.blue,.05)
    for i in range(3):
        a=i*math.pi/3
        w.pipe('Snowflake arm',[(-.35*math.cos(a),-.80,1.17-.35*math.sin(a)),(.35*math.cos(a),-.80,1.17+.35*math.sin(a))],.025,w.frost)
    return [4,4],1.3,5


def cooling_unit(w):
    w.box('Packaged heat exchanger base',(0,0,.20),(2.75,2.25,.22),w.iron,.05)
    for x in (-1.20,1.20):w.box('Heat exchanger end tank',(x,0,.65),(.25,1.95,.72),w.paint,.04)
    for i in range(21):w.box('Heat exchange fin',(-1.02+i*.102,0,.65),(.025,1.80,.72),w.steel,0)
    for y in (-.62,0,.62):w.cyl('Copper coolant tube',(0,y,.62),.065,2.45,w.copper,'X')
    w.ring('Cooling fan casing',(0,0,1.12),.83,.07,w.iron)
    w.cyl('Cooling fan hub',(0,0,1.13),.19,.16,w.steel)
    for i in range(7):
        a=i*math.tau/7
        blade=w.box('Cooling fan blade',(.43*math.cos(a),.43*math.sin(a),1.12),(.55,.17,.055),w.ivory,.008)
        blade.rotation_euler.z=a+.25
    for x in (-.45,0,.45):w.box('Fan protective grille',(x,0,1.27),(.018,1.55,.025),w.steel,.002)
    for x in (-1.20,1.20):
        w.cyl('Hose connector',(x,-1.12,.67),.16,.32,w.steel,'Y')
        w.ring('Connector collar',(x,-1.28,.67),.16,.025,w.copper,'Y')
    return [4,4],.70,5
