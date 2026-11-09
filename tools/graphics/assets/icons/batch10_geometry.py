"""Unpackaged silicon and a known-good die on its larger interposer."""

def silicon(w,x,y,size,z):
    mat=w.material('Polished silicon',(.045,.09,.22),.72,.24)
    w.box('Silicon die',(x,y,z),(size,size,.12),mat,.012)
    for i in range(4):
        for j in range(4):
            block=w.material('Silicon functional block',(.08+i*.018,.16+j*.025,.28+i*.025),.65,.28)
            w.box('Transistor region',(x+(i-1.5)*size*.21,y+(j-1.5)*size*.21,z+.068),(size*.18,size*.18,.018),block,.002)
    for i in range(9):
        p=(i-4)*size*.095
        for sign in (-1,1):
            w.box('Gold bond pad',(x+p,y+sign*size*.47,z+.072),(size*.045,size*.035,.02),w.gold,.001)
            w.box('Gold bond pad',(x+sign*size*.47,y+p,z+.072),(size*.035,size*.045,.02),w.gold,.001)

def bare(w):
    silicon(w,0,0,2.75,.22)
    return [4,4],.30,5

def chiplet(w):
    w.box('Larger ceramic interposer',(0,0,.22),(3.15,2.65,.20),w.ivory,.045)
    w.box('Interposer routing layer',(0,0,.335),(2.95,2.45,.035),w.paint,.025)
    silicon(w,0,.15,1.45,.43)
    for i in range(12):
        x=(i-5.5)*.22
        w.box('Interposer contact',(x,-1.27,.36),(.10,.16,.04),w.gold,.002)
        w.pipe('Fanout conductor',[(x*.45,-.60,.40),(x,-1.07,.37)],.014,w.copper)
    for x in (-1.18,1.18):
        for y in (-.60,0,.60):w.box('Interposer decoupling capacitor',(x,y,.43),(.22,.30,.16),w.iron,.008)
    return [4,4],.40,5
