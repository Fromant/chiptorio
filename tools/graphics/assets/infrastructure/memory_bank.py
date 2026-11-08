"""Five-tile memory installation: visible blade banks, capacity bus and cooling."""
from common import base,cabinet,finish

def build(w):
    base(w,5)
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
    for y in (-2.03,2.03):
        w.box('Memory bus enclosure',(0,y,1.03),(4.15,.34,.55),w.paint)
        for x in (-1.35,0,1.35):
            w.box('Memory bus coupler',(x,y,1.37),(.54,.34,.15),w.copper)
            w.box('Capacity status lens',(x,y+(-.19 if y<0 else .19),1.05),(.22,.018,.07),w.blue,.002)
    return finish(w,5,1.15)
