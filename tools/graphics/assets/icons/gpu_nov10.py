from nov10_geometry import gpu

def build(w):
    result=gpu(w)
    for sign in (-1,1):
        w.box('Perforated upper shroud panel',(0,sign*.76,.78),(3.15,.26,.06),w.iron,.018)
    return result
