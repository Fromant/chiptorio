"""Rotatable twin-cell dry cooler with fin-and-tube radiators and axial fans."""
import math
from common import base,animate,cabinet,active,finish,tube

def build(w):
    base(w,7,True,[(0,'Radiator airflow'),(48,'Fan quarter cycle'),(96,'Return cooling flow'),(144,'Fan three-quarter cycle')])
    for x in (-1.55,1.55):
        w.box('Radiator cell skid',(x,.25,.65),(2.60,1.50,.36),w.iron,.04)
        for dx in (-1.20,1.20):w.box('Radiator structural upright',(x+dx,.25,1.98),(.12,.85,2.48),w.paint)
        for z in (.83,3.25):w.box('Radiator header frame',(x,.25,z),(2.50,.85,.12),w.steel)
        for i in range(37):
            w.box('Aluminium heat exchange fin',(x-.94+i*.052,.25,1.98),(.018,.56,2.02),w.steel,0)
        for z in (1.08,1.38,1.68,1.98,2.28,2.58,2.88):
            w.cyl('Radiator copper tube',(x,.25,z),.045,2.12,w.copper,'X')
        for dx in (-1.08,1.08):w.cyl('Vertical radiator header',(x+dx,.25,1.98),.10,2.16,w.copper)
        w.ring('Axial fan safety hoop',(x,-.85,1.98),1.07,.045,w.steel,'Y')
        w.cyl('Axial fan motor',(x,-.28,1.98),.20,.24,w.iron,'Y')
        w.cyl('Fan spindle',(x,-.49,1.98),.055,.24,w.steel,'Y')
        with w.part('Radiator axial fan',(x,-.67,1.98)) as rotor:
            animate(rotor,'rotation_euler',lambda p,sign=1 if x<0 else -1:(0,sign*4*math.pi*p/192,0))
            w.cyl('Rotor hub',(0,0,0),.21,.16,w.steel,'Y')
            for i in range(6):
                a=i*math.tau/6
                blade=w.box('Pitched axial fan blade',(.54*math.cos(a),0,.54*math.sin(a)),(.80,.065,.18),w.ivory,.008)
                blade.rotation_euler.y=-a;blade.rotation_euler.x=.20
        for dx in (-.50,.50):w.box('Fan safety grille',(x+dx,-.87,1.98),(.022,.025,1.90),w.steel)
        for z in (1.48,2.48):w.box('Fan safety crossbar',(x,-.87,z),(1.90,.025,.022),w.steel)
    for sign in (-1,1):
        # Native Factorio pipe pictures/covers finish the ends at the tile ports.
        for y in (-3.0,3.0):
            w.cyl('Native pipe seat',(sign,y,.65),.16,.22,w.steel,'Y')
            w.ring('Port mounting flange',(sign,y,.65),.18,.025,w.iron,'Y')
        tube(w,'Radiator inlet',[(sign,-3,.65),(sign,-2.65,.65),(sign*2.63,-2.65,.65),(sign*2.63,-.40,.65),(sign*2.63,-.40,.94),(sign*2.63,.25,.94)],.10,w.steel)
        tube(w,'Radiator outlet',[(sign*.47,.25,3.02),(sign*.47,2.30,3.02),(sign*.47,2.30,.65),(sign,2.30,.65),(sign,3,.65)],.10,w.steel)
        for y in (-2.20,-1.30):
            w.box('Pipe saddle',(sign*2.63,y,.50),(.34,.18,.18),w.iron)
            w.ring('Pipe clamp',(sign*2.63,y,.65),.115,.015,w.steel,'Y')
    cabinet(w,'Fan controller',0,-2.18,.70,1.05)
    w.box('Airflow status',(0,-2.55,1.12),(.30,.02,.09),active(w,'Airflow online',(.05,.55,.85)))
    return finish(w,7,1.55)
