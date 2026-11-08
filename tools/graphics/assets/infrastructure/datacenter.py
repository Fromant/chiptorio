"""Eleven-tile compute-provider hall with rack aisles and an integrated service plant."""
import math
from common import base,animate,active,blink,tube,cabinet,finish


def rack(w,x,y,index,link):
    memory=y>1
    w.box('Rack isolation bed',(x,y,.59),(1.38,1.48,.32),w.iron,.025)
    w.box('Rack rear shell',(x,y+.60,1.76),(1.22,.10,2.26),w.paint)
    for dx in (-.59,.59):
        w.box('Rack frame upright',(x+dx,y,1.76),(.08,1.30,2.30),w.steel)
    w.box('Rack crown',(x,y,2.94),(1.30,1.38,.10),w.white)
    for dx in (-.38,-.19,0,.19,.38):
        w.box('Crown ventilation slot',(x+dx,y,3.0),(.055,.94,.012),w.black,.002)
    for j in range(6):
        z=.93+j*.32
        w.box('Memory chassis' if memory else 'Compute sled',(x,y,z),(1.10,1.16,.245),w.iron,.012)
        w.box('Front service fascia',(x,y-.595,z),(1.04,.035,.22),w.paint,.006)
        for dx in (-.29,-.15,-.01,.13):
            w.box('Chassis air intake',(x+dx,y-.618,z),(.075,.012,.12),w.black,.002)
        w.box('Sled pull handle',(x-.47,y-.64,z),(.03,.055,.14),w.steel,.003)
        w.box('Sled link lamp',(x+.32,y-.625,z+.04),(.055,.015,.035),link,.002)
    for j in range(3):
        busy=blink(w,'Rack online burst',index*7+j*13,(.85,.31,.035))
        for row in (j,j+3):
            w.box('Sled activity lamp',(x+.44,y-.628,.89+row*.32),(.07,.016,.045),busy,.002)
        w.box('Visible top activity lens',(x-.35+j*.35,y-.43,3.01),(.17,.13,.025),busy,.003)
    # Short side taps meet the dedicated supply/return lanes, not neighboring cabinets.
    for sign in (-1,1):
        tube(w,'Rack coolant tap',[(x+sign*.60,y,1.08),(x+sign*.78,y,1.08),(x+sign*.78,y,.95)],.035,w.steel,.05)
        w.ring('Tap coupling',(x+sign*.62,y,1.08),.052,.012,w.blue,'X')


def air_handler(w,x,period):
    w.box('Air handler skid',(x,4.25,.60),(2.85,1.55,.30),w.iron,.035)
    for dx in (-1.35,1.35):
        w.box('Air handler casing',(x+dx,4.25,1.32),(.10,1.45,1.40),w.paint)
    for i in range(24):
        w.box('Cooling radiator fin',(x-1.17+i*.102,4.25,1.12),(.022,1.24,.74),w.steel,0)
    for y in (3.80,4.10,4.40,4.70):
        w.cyl('Cooling coil',(x,y,1.20),.045,2.55,w.copper,'X')
    for dx in (-1.25,1.25):
        w.cyl('Radiator manifold',(x+dx,4.25,1.20),.085,1.22,w.copper,'Y')
    for dx in (-.69,.69):
        w.ring('Fan casing',(x+dx,4.25,1.94),.55,.045,w.paint)
        w.cyl('Cooling motor',(x+dx,4.25,1.72),.14,.24,w.iron)
        w.cyl('Motor spindle',(x+dx,4.25,1.89),.035,.18,w.steel)
        with w.part('Service plant fan',(x+dx,4.25,1.96)) as rotor:
            animate(rotor,'rotation_euler',lambda p:(0,0,math.tau*p/period),period)
            w.cyl('Fan hub',(0,0,0),.13,.11,w.steel)
            for i in range(7):
                a=i*math.tau/7
                blade=w.box('Axial impeller blade',(.29*math.cos(a),.29*math.sin(a),0),(.37,.095,.035),w.ivory,.004)
                blade.rotation_euler.z=a;blade.rotation_euler.x=.12
        for delta in (-.30,-.15,0,.15,.30):
            w.box('Close fan grille',(x+dx+delta,4.25,2.075),(.014,.96,.018),w.steel,.002)
    w.box('Air handler fascia',(x,3.49,1.34),(2.64,.035,1.12),w.paint,.01)
    for z in (1.02,1.22,1.42,1.62):
        w.box('Air handler louvre',(x,3.46,z),(2.35,.06,.055),w.steel,.003)


def build(w):
    period=96
    base(w,11,True,[(0,'Compute hall online'),(12,'Distributed rack bursts'),(24,'Cooling quarter turn'),(48,'Aisle status'),(72,'Cooling three-quarter turn')])
    w.scene['animation_period']=period
    link=active(w,'Established hardware link',(.04,.55,.12),strength=1.1)
    # Eight compute racks and four memory cabinets form a hall rather than a single enlarged rack.
    columns=(-3.45,-1.15,1.15,3.45)
    for i,x in enumerate(columns):
        for j,y in enumerate((-2.10,0,2.10)):
            rack(w,x,y,i*3+j,link)
        for sign in (-1,1):
            lane=x+sign*.78
            tube(w,'Rack service lane',[(lane,-2.50,.95),(lane,3.12 if sign>0 else 3.31,.95)],.045,w.steel)
            for y in (-2.45,.65,2.70):
                w.box('Service pipe saddle',(lane,y,.72),(.15,.10,.38),w.iron,.004)
    # Raised aisle edging keeps walking space distinct from the pipe and cable lanes.
    for x in (-2.30,0,2.30):
        w.box('Central service walkway',(x,0,.445),(.48,6.45,.04),w.steel,.005)
        for y in (-2.7,-.6,1.5):
            w.box('Walkway marker',(x,y,.47),(.28,.11,.012),w.ochre,.001)
    for y in (3.12,3.31):
        tube(w,'Cooling distribution header',[(-4.55,y,.95),(4.55,y,.95)],.075,w.blue)
    for x in (-3.10,3.10):
        air_handler(w,x,period)
        for sign in (-1,1):
            tube(w,'Heat exchanger service',[(x+sign*1.25,4.25,1.20),(x+sign*1.52,4.25,1.20),(x+sign*1.52,3.75,1.20),(x+sign*1.52,3.75,.95),(x+sign*1.52,3.12 if sign>0 else 3.31,.95)],.065,w.steel)
    cabinet(w,'Coolant distribution unit',0,4.30,.90,1.35)
    w.box('Cooling controller display',(0,3.93,1.50),(.50,.025,.17),link,.006)
    # Low front service islands preserve the game-camera view into the rack aisles.
    for sign in (-1,1):
        for x in (sign*2.35,sign*3.40,sign*4.45):
            cabinet(w,'Power distribution cabinet',x,-4.20,.82,1.10)
            w.box('Power isolator',(x,-4.585,1.02),(.22,.05,.22),w.ochre,.008)
    w.box('Network fabric pedestal',(0,-4.20,.79),(2.36,1.08,.72),w.iron,.03)
    for y in (-4.55,-4.25,-3.95):
        w.box('Fabric switch deck',(0,y,1.25),(2.10,.22,.18),w.steel,.008)
        for i in range(8):
            x=-.84+i*.24
            w.box('Fabric port',(x,y-.12,1.25),(.15,.02,.095),w.black,.002)
            w.box('Fabric top link',(x,y,1.35),(.10,.08,.025),blink(w,'Fabric online burst',i*5),.002)
    # Cable trays carry power/fabric overhead, with supports outside cabinet volumes.
    for x in (-4.85,4.85):
        for y in (-3.18,3.00):
            w.box('Cable bridge column',(x,y,1.84),(.12,.12,2.78),w.steel)
        w.box('Side cable tray',(x,-.09,3.26),(.28,6.40,.08),w.iron)
        for dx in (-.06,.06):
            tube(w,'Supported copper bus',[(x+dx,-3.18,3.33),(x+dx,3.00,3.33)],.026,w.copper)
    for y in (-3.18,3.00):
        w.box('Cross-hall cable tray',(0,y,3.26),(9.78,.28,.08),w.iron)
        for dy in (-.06,.06):
            tube(w,'Hall fabric trunk',[(-4.85,y+dy,3.33),(4.85,y+dy,3.33)],.026,w.copper)
    for sign in (-1,1):
        tube(w,'Power cabinet riser',[(sign*4.45,-4.20,1.58),(sign*4.65,-4.20,1.58),(sign*4.65,-3.18,1.58),(sign*4.65,-3.18,3.33)],.055,w.black)
    return finish(w,11,1.65)
