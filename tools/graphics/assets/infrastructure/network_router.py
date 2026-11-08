"""Four-way routing node, distinct uplink spine and redundant control modules."""
import math
from common import base,finish

def build(w):
    base(w,3)
    w.cyl('Routing chassis',(0,0,.80),1.16,.68,w.iron,vertices=32)
    w.cyl('Routing backplane',(0,0,1.16),.95,.055,w.pcb,vertices=32)
    w.box('Route processor',(0,0,1.38),(.72,.72,.40),w.white,.025)
    for x in (-.26,-.13,0,.13,.26):w.box('Processor thermal fin',(x,0,1.65),(.045,.76,.12),w.steel)
    for side in range(4):
        with w.part('Router uplink bank',angle=side*math.pi/2):
            w.box('Uplink cage',(0,-1.12,1.04),(1.28,.30,.48),w.steel)
            for x in (-.40,0,.40):
                w.box('Uplink socket',(x,-1.285,1.04),(.25,.02,.25),w.black,.003)
                w.box('Uplink lens',(x,-1.30,1.22),(.13,.015,.035),w.blue,.001)
            w.pipe('Routing spine',[(0,-.94,1.20),(0,-.65,1.43),(0,-.35,1.43)],.045,w.copper)
    for x,y in [(-.85,-.85),(.85,.85)]:
        w.cyl('Wireless mast socket',(x,y,1.02),.10,.22,w.steel)
        w.cyl('Wireless antenna',(x,y,1.68),.038,1.15,w.iron)
        w.cyl('Antenna radome',(x,y,2.08),.065,.38,w.ivory)
    return finish(w,3,1.1)
