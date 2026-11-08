"""Non-facing switch backplane: four port banks and exposed switching fabric."""
import math
from common import base,finish,blink

def build(w):
    base(w,3,True,[(0,'Link heartbeat'),(12,'Heartbeat off'),(24,'Activity pulse'),(32,'Status idle')])
    w.scene['animation_period']=48
    w.box('Switch backplane housing',(0,0,.70),(2.3,2.3,.50),w.paint,.025)
    w.box('Switching fabric substrate',(0,0,.98),(1.95,1.95,.06),w.pcb,.004)
    w.box('Switch fabric ASIC',(0,0,1.12),(.63,.63,.20),w.iron,.01)
    for x in (-.24,-.12,0,.12,.24):w.box('Fabric heat spreader',(x,0,1.26),(.045,.65,.08),w.steel,.003)
    for side in range(4):
        with w.part('Ethernet port bank',angle=side*math.pi/2):
            w.box('Port cage',(0,-1.10,1.0),(1.72,.32,.40),w.steel)
            for x in (-.60,-.20,.20,.60):
                w.box('RJ45 socket',(x,-1.272,1.01),(.27,.018,.22),w.black,.003)
                for dx in (-.075,-.025,.025,.075):w.box('Ethernet contact',(x+dx,-1.285,.97),(.012,.015,.08),w.gold,0)
                lamp=blink(w,'Switch link heartbeat',side*7+int((x+.6)*20))
                w.box('Link lens',(x+.10,-1.288,1.13),(.065,.02,.05),lamp,.002)
                w.box('Top link lens',(x,-1.10,1.215),(.12,.10,.025),lamp,.003)
            for x in (-.45,.45):w.pipe('Fabric copper bus',[(x,-.92,1.02),(x,-.55,1.02),(0,-.36,1.02)],.025,w.copper)
    return finish(w,3,.8)
