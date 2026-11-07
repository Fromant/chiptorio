"""Third batch: small 1x1 utility nodes, preserving existing logistics adjacency."""
import math


def foup_dock(w):
    w.base(.90, w.white)
    w.box("FOUP load-port bed", (0, 0, .49), (.74, .74, .15), w.iron)
    w.box("Carrier guide socket", (0, 0, .58), (.59, .59, .07), w.steel)
    w.box("Polymer wafer carrier", (0, 0, .75), (.47, .47, .29), w.ivory, .025)
    w.box("Carrier lid", (0, 0, .925), (.53, .53, .065), w.white, .02)
    w.box("Lid handling rib", (0, 0, .97), (.27, .09, .035), w.steel)
    for side in range(4):
        with w.part("FOUP sealing quadrant", angle=side*math.pi/2):
            w.box("Load-port alignment rail", (0, -.32, .61), (.65, .055, .09), w.steel)
            for row in range(4):
                w.box("Carrier wafer separator", (0, -.245, .65+row*.055), (.33, .014, .012), w.black, 0)
            with w.part("Working lid locking cam", (0, -.31, .69)) as latch:
                w.travel(latch, 1, .018, side*math.pi/2)
                w.box("Locking cam shoe", (0, 0, 0), (.14, .09, .065), w.ochre)
                w.cyl("Cam axle", (0, 0, .045), .025, .025, w.steel)
            for index in range(2):
                lamp = w.pulse("FOUP cycle indicator", (.36, .28, .75), side+index, 1.7)
                w.box("Load port cycle lamp", (-.13+index*.26, -.40, .56), (.06, .05, .014), lamp, .002)
    return 1, .57, 6


def access_point(w):
    w.base(.90, w.white)
    w.box("Radio backplane", (0, 0, .47), (.73, .73, .10), w.iron)
    for side in range(4):
        with w.part("Radio antenna quadrant", angle=side*math.pi/2):
            w.box("Ceramic patch antenna", (.22, -.22, .56), (.24, .24, .06), w.white)
            w.box("RF patch conductor", (.22, -.22, .595), (.14, .14, .008), w.gold, 0)
            w.box("RF shield can", (0, -.30, .55), (.12, .16, .055), w.steel)
            for index in range(2):
                lamp = w.pulse("Access point link status", (.22, .30, .85), side+index*.8, 1.6)
                w.box("Link status indicator", (-.11+index*.22, -.39, .53), (.05, .05, .014), lamp, .002)
    w.cyl("Antenna mast socket", (0, 0, .59), .105, .13, w.steel)
    w.cyl("Insulated antenna mast", (0, 0, .83), .026, .40, w.ivory)
    w.cyl("Antenna mast cap", (0, 0, 1.04), .038, .035, w.steel)
    return 1, .56, 6


def flow_node(w, kind):
    inward = kind == "import"
    accent = w.material("Ingress blue enamel" if inward else "Egress ochre enamel",
                        (.035, .24, .32) if inward else (.48, .25, .045), .40, .4)
    color = (.035, .65, .85) if inward else (.96, .35, .045)
    w.base(.90, accent)
    w.box("Packet transfer chassis", (0, 0, .50), (.73, .73, .17), w.iron)
    w.box("Transfer controller lid", (0, 0, .60), (.65, .65, .045), accent)
    if inward:
        w.cyl("Recessed ingress aperture", (0, 0, .63), .17, .025, w.black)
        w.ring("Ingress aperture rim", (0, 0, .65), .16, .012, w.steel)
    else:
        w.box("Raised egress manifold", (0, 0, .675), (.26, .26, .10), w.steel)
        for row in range(3):
            w.box("Manifold heat spreader", (0, -.07+row*.07, .735), (.22, .016, .018), w.iron, 0)
    for side in range(4):
        with w.part("Transfer port quadrant", angle=side*math.pi/2):
            w.box("Network cable coupling", (0, -.40, .49), (.24, .08, .10), w.steel)
            w.box("Port dielectric insert", (0, -.445, .49), (.14, .015, .05), w.black, 0)
            for index in range(3):
                phase = index*.9 if inward else -index*.9
                lamp = w.pulse("Ingress packet" if inward else "Egress packet", color, phase, 1.9)
                w.box("Directional packet indicator", (0, -.34+index*.065, .64), (.045, .033, .012), lamp, .001)
            y = -.19 if inward else -.36
            for sign in (-1, 1):
                arm = w.box("Etched flow arrow", (sign*.032, y, .65), (.09, .018, .009), w.ivory, 0)
                arm.rotation_euler.z = sign*(math.pi/4 if inward else -math.pi/4)
    return 1, .43, 6


def provider(w):
    w.base(.90, w.paint)
    w.box("Provider cargo buffer", (0, 0, .55), (.75, .75, .26), w.iron)
    w.box("Cargo compartment deck", (0, 0, .70), (.68, .68, .05), w.steel)
    for col in (-1, 1):
        for row in range(4):
            x, y = col*.155, -.235+row*.155
            w.box("Cargo buffer compartment", (x, y, .74), (.25, .12, .055), w.black)
            w.box("Cargo tray latch", (x, y, .78), (.14, .035, .035), w.ivory, .003)
    for side in range(4):
        with w.part("Cargo supply quadrant", angle=side*math.pi/2):
            w.box("Reinforced cargo rim", (0, -.375, .76), (.77, .035, .065), w.paint)
            w.box("Network supply coupling", (0, -.41, .53), (.22, .065, .09), w.steel)
            for index in range(2):
                lamp = w.pulse("Provider supply activity", (.07, .72, .25), side+index, 1.9)
                w.box("Supply indicator", (-.14+index*.28, -.40, .70), (.055, .035, .015), lamp, .002)
    return 1, .48, 6


BUILDERS = {
    "foup-dock": foup_dock,
    "wireless-access-point": access_point,
    "qln-import-node": lambda w: flow_node(w, "import"),
    "qln-export-node": lambda w: flow_node(w, "export"),
    "qln-provider-node": provider,
}
