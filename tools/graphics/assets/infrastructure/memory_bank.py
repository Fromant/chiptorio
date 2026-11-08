"""Five-tile memory installation: visible blade banks, capacity bus and cooling."""
from common import base,cabinet,finish,blink

def build(w):
    base(w,5,True,[(0,'Link heartbeat'),(12,'Heartbeat off'),(24,'Activity pulse'),(32,'Status idle')])
    w.scene['animation_period']=48
    for x in (-1.35,0,1.35):
        w.box('Memory blade plinth',(x,0,.65),(1.03,3.7,.40),w.iron)
        for y in (-1.62,-1.08,-.54,0,.54,1.08,1.62):
            w.box('Memory blade',(x,y,1.47),(.84,.08,1.28),w.pcb,.004)
            w.box('Blade retaining rail',(x,y,.91),(.94,.13,.12),w.ivory)
            for dx in (-.27,0,.27):
                for z in (1.20,1.65):w.box('Memory package',(x+dx,y-.065,z),(.18,.035,.28),w.iron,.004)
            w.box('Module edge connector',(x,y,.87),(.72,.09,.08),w.gold,.002)
        for dx in (-.48,.48):w.box('Memory bank upright',(x+dx,0,1.43),(.07,3.75,1.53),w.steel)
        w.box('Top service rail',(x,0,2.25),(.98,3.75,.14),w.white)
        for i,y in enumerate((-1.4,-.7,0,.7,1.4)):
            w.box('Blade readiness lens',(x,y,2.33),(.26,.12,.025),blink(w,'Blade capacity heartbeat',i*6+int((x+1.35)*7)),.003)
    for y in (-2.03,2.03):
        w.box('Memory bus enclosure',(0,y,1.03),(4.15,.34,.55),w.paint)
        for x in (-1.35,0,1.35):
            w.box('Memory bus coupler',(x,y,1.37),(.54,.34,.15),w.copper)
            lamp=blink(w,'Installed memory heartbeat',int((x+1.35)*7)+(0 if y<0 else 16))
            w.box('Capacity status lens',(x,y+(-.19 if y<0 else .19),1.05),(.34,.025,.12),lamp,.003)
            w.box('Capacity top lens',(x,y,1.31),(.40,.16,.025),lamp,.003)
    return finish(w,5,1.15)
