def build(w):
    w.box('Wide early DRAM board',(0,0,.20),(3.7,2.0,.14),w.pcb,.025)
    for i in range(26):w.box('DRAM edge contact',((i-12.5)*.13,-.90,.29),(.075,.21,.025),w.gold,.001)
    for x in (-1.23,-.41,.41,1.23):
        for y in (-.35,.49):
            w.box('DIP DRAM package',(x,y,.42),(.65,.48,.26),w.iron,.018)
            for dx in (-.22,0,.22):
                for dy in (-.29,.29):w.box('DIP gull wing lead',(x+dx,y+dy,.34),(.065,.15,.065),w.steel,.003)
    return [4,4],.40,5
