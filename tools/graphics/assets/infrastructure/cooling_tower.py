"""Seven-tile induced-draft cooling plant: two fan cells and connected coils."""
import math
from common import base,animate,cabinet,port,active,finish

def build(w):
    base(w,7,True,[(0,'Coolant circulation'),(48,'Fan quarter cycle'),(96,'Return cooling flow'),(144,'Fan three-quarter cycle')])
    for x in (-1.55,1.55):
        w.box('Cell collection sump',(x,.65,.68),(2.55,2.50,.48),w.iron,.04)
        for dx in (-1.12,1.12):
            for y in (-.47,1.77):w.box('Cell structural column',(x+dx,y,1.96),(.14,.14,2.28),w.steel)
        w.box('Rear fill housing',(x,1.77,2.1),(2.35,.16,2.05),w.paint)
        for z in (1.25,1.58,1.91,2.24,2.57):
            w.pipe('Serpentine cooling coil',[(x-.87,-.52,z),(x+.87,-.52,z),(x+.94,-.40,z+.15),(x-.87,-.40,z+.15)],.045,w.copper)
        for dx in (-.95,.95):w.cyl('Coil header',(x+dx,-.46,1.85),.075,1.85,w.steel)
        for dx in (-.88,-.44,0,.44,.88):w.box('Drift eliminator',(x+dx,.65,3.07),(.055,1.9,.12),w.steel)
        w.ring('Fan guard hoop',(x,.65,3.45),1.07,.055,w.steel)
        w.cyl('Fan drive motor',(x,.65,3.16),.23,.36,w.iron)
        w.cyl('Fan spindle',(x,.65,3.35),.055,.33,w.steel)
        with w.part('Induced draft rotor',(x,.65,3.47)) as rotor:
            animate(rotor,'rotation_euler',lambda p,sign=1 if x<0 else -1:(0,0,sign*4*math.pi*p/192))
            w.cyl('Rotor hub',(0,0,0),.22,.16,w.steel)
            for i in range(6):
                a=i*math.tau/6
                blade=w.box('Pitched fan blade',(.54*math.cos(a),.54*math.sin(a),0),(.82,.16,.045),w.ivory,.008)
                blade.rotation_euler.z=a;blade.rotation_euler.x=.16
        for dx in (-1,1):w.box('Fan guard crossbar',(x+dx*.52,.65,3.59),(.025,2.05,.035),w.steel)
    for x in (-1.3,1.3):
        w.box('Pump skid',(x,-2.25,.59),(1.6,.85,.24),w.iron)
        w.cyl('Circulation pump motor',(x,-2.25,.91),.26,.95,w.steel,'X')
        w.cyl('Pump volute',(x-.53,-2.25,.91),.33,.23,w.paint,'X')
    for x in (-1,1):
        port(w,'Cooling fluid coupling',x,-3.23);port(w,'Cooling fluid coupling',x,3.23)
        side=-1 if x<0 else 1
        w.pipe('Input pump feed',[(x,-3.23,.35),(x,-2.9,.65),(side*1.3,-2.25,.65)],.075,w.blue)
        w.pipe('Cell supply',[(side*1.3,-2.25,1.04),(side*1.55,-1.45,1.04),(side*2.5,-.46,1.10)],.06,w.blue)
        w.pipe('Return service',[(side*2.5,-.46,2.65),(side*3.05,-.46,2.65),(side*3.05,2.9,.65),(x,3.23,.35)],.065,w.steel)
    cabinet(w,'Plant controls',0,2.62,.90,1.32)
    status=active(w,'Coolant flowing',(.04,.46,.67))
    w.box('Control flow indicator',(0,2.24,1.4),(.35,.02,.10),status)
    return finish(w,7,1.55)
