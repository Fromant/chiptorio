"""Second five assets: functional top-side layouts, fixed game camera, no hero faces."""
import math
import bpy


def flat_text(w, body, loc, size, material):
    curve = bpy.data.curves.new(body, "FONT")
    curve.body, curve.size, curve.resolution_u = body, size, 2
    curve.align_x = "CENTER"
    obj = bpy.data.objects.new(body, curve)
    w.cols["Details"].objects.link(obj)
    obj.parent, obj.location = w.parent, loc
    curve.materials.append(material)


def wafer(w, radius=.43):
    silicon = w.material("Iridescent silicon wafer", (.13, .22, .31), .82, .22)
    w.cyl("Silicon wafer", (0, 0, 0), radius, .014, silicon)
    for step in range(-3, 4):
        offset = step*radius*.22
        length = 2*math.sqrt(max(0, radius*radius-offset*offset))*.92
        w.box("Wafer die scribe X", (offset, 0, .009), (.004, length, .002), w.gold, 0)
        w.box("Wafer die scribe Y", (0, offset, .009), (length, .004, .002), w.gold, 0)


def metrology(w):
    w.base(2.86, w.white)
    w.box("Vibration isolated optical bed", (0, 0, .54), (2.20, 2.20, .25), w.iron)
    w.box("Granite inspection surface", (0, 0, .69), (2.03, 2.03, .075), w.black)
    # Real XY wafer stage under a fixed optical head; all motion stays over the bed.
    for y in (-.48, .48):
        w.box("Stage linear bearing rail", (0, y, .78), (1.55, .075, .075), w.steel)
    with w.part("Working XY wafer stage", (0, 0, .83)) as stage:
        w.travel(stage, 0, .11)
        w.travel(stage, 1, .08, math.pi/2)
        w.box("XY carriage", (0, 0, 0), (1.19, 1.19, .09), w.steel)
        w.cyl("Vacuum wafer chuck", (0, 0, .075), .52, .07, w.iron)
        with w.part("Inspected wafer", (0, 0, .125)):
            wafer(w, .47)
    for side in range(4):
        with w.part("Optical support quadrant", angle=side*math.pi/2):
            w.box("Optical bridge support", (.94, -.94, 1.04), (.18, .18, .83), w.white)
            w.bolt((.94, -.94, 1.49))
            w.box("Service cassette", (0, -1.17, .69), (.71, .31, .46), w.white)
            for row in range(4):
                w.box("Cassette seam", (0, -1.335, .56+row*.09), (.53, .015, .012), w.black, 0)
            for col in range(3):
                lamp = w.pulse("Metrology channel", (.04, .65, .77), side+col, 1.5)
                w.box("Qualification status lamp", (-.19+col*.19, -1.17, .93), (.09, .12, .015), lamp, .003)
            w.pipe("Vacuum manifold", [(.55, -.96, .71), (.73, -.80, .76), (.81, -.60, .76)], .023, w.blue)
    for y in (-.94, .94):
        w.box("Optical bridge cross rail", (0, y, 1.51), (2.07, .12, .13), w.steel)
    w.box("Fixed microscope bridge", (0, 0, 1.51), (.31, 1.98, .15), w.white)
    w.cyl("Optical objective housing", (0, 0, 1.33), .16, .31, w.steel)
    light = w.pulse("Inspection objective illumination", (.15, .54, .73), 0, 1.6)
    w.cyl("Objective illumination aperture", (0, 0, 1.16), .11, .025, light)
    return 3, .80, 6


def answer_engine(w):
    w.base(4.86, w.iron)
    w.box("Central computation vault", (0, 0, .87), (2.12, 2.12, .91), w.paint, .035)
    w.box("Answer display roof gasket", (0, 0, 1.36), (1.90, 1.90, .08), w.steel)
    w.box("Answer display glass", (0, 0, 1.42), (1.74, 1.74, .035), w.black)
    glow = w.pulse("The Answer phosphor", (.07, .62, .74), 0, 2.3)
    flat_text(w, "42", (0, -.40, 1.445), .97, glow)
    for side in range(4):
        with w.part("Answer computation quadrant", angle=side*math.pi/2):
            w.box("Dense compute cabinet", (0, -1.63, 1.01), (2.02, .78, 1.16), w.paint, .035)
            for row in range(5):
                z = .58+row*.20
                w.box("Server blade fascia", (0, -2.035, z), (1.79, .045, .16), w.iron)
                for col in range(5):
                    w.box("Hot swap tray", (-.68+col*.34, -2.07, z), (.28, .035, .12), w.steel, .005)
                status = w.pulse("Answer compute activity", (.09, .66, .22), side+row*.7, 1.8)
                w.box("Blade bank indicator", (.83, -2.10, z), (.035, .016, .07), status, .002)
            w.box("Cabinet lid", (0, -1.63, 1.64), (2.13, .88, .075), w.steel)
            w.fan((0, -1.63, 1.71), .29, side*.4)
            for x in (-.79, .79):
                w.pipe("Vault cooling supply", [(x, -1.29, .73), (x, -1.12, .95), (x, -.98, 1.15)], .047, w.blue)
            w.box("Corner power tower", (1.83, -1.83, 1.09), (.68, .68, 1.32), w.white)
            for i in range(7):
                w.box("Power tower heat spreader", (1.83, -1.83, .57+i*.16), (.75, .75, .035), w.iron, .004)
            w.box("Tower terminal cover", (1.83, -1.83, 1.80), (.67, .67, .09), w.steel)
            for x in (1.61, 2.05):
                for y in (-1.61, -2.05):
                    w.bolt((x, y, 1.86))
            for index in range(7):
                phase = w.pulse("Answer data conduit", (.04, .46, .74), side+index*.6, 1.8)
                w.box("Roof computation trace", (-.60+index*.20, -.88, 1.48), (.045, .13, .018), phase, .002)
    return 5, 1.0, 8


def storage_drive(w):
    w.base(1.89)
    w.box("Memory bus chassis", (0, 0, .59), (1.68, 1.68, .39), w.iron)
    w.box("Serviceable top backplane", (0, 0, .81), (1.47, 1.47, .065), w.pcb)
    for side in range(4):
        with w.part("One installed memory bay", angle=side*math.pi/2):
            w.box("Memory cartridge recess", (0, -.49, .91), (.88, .38, .16), w.black)
            w.box("Memory cartridge PCB", (0, -.49, 1.00), (.73, .28, .04), w.pcb)
            for col in range(4):
                w.box("Memory package", (-.27+col*.18, -.49, 1.035), (.13, .17, .035), w.iron, .003)
                w.box("Memory edge contact", (-.27+col*.18, -.65, 1.015), (.09, .04, .015), w.gold, 0)
            for x in (-.43, .43):
                w.box("Cartridge guide rail", (x, -.49, .99), (.045, .43, .11), w.steel)
                w.box("Toolless release tab", (x, -.71, 1.04), (.08, .10, .055), w.ivory)
            for index in range(3):
                activity = w.pulse("Storage online heartbeat", (.05, .67, .59), side+index*.9, 1.7)
                w.box("Storage status segment", (-.20+index*.20, -.79, .85), (.07, .065, .015), activity, .002)
            w.bolt((.77, -.77, .86))
    w.cyl("Backplane controller", (0, 0, .93), .19, .09, w.iron)
    w.ring("Controller heat spreader", (0, 0, .99), .17, .014, w.steel)
    return 2, .60, 6


def quantum_core(w):
    w.base(1.89, w.white)
    for side in (-1, 1):
        x = side*.47
        w.cyl("Quantum isolation well", (x, 0, .69), .31, .49, w.iron)
        for z, r in ((.52, .31), (.78, .27), (1.03, .20)):
            w.cyl("Cryogenic shield", (x, 0, z), r, .045, w.gold)
            w.ring("Shield perimeter", (x, 0, z+.03), r, .016, w.copper)
        sample = w.pulse("Entangled quantum sample", (.43, .13, .78), 0 if side == 1 else math.pi, 2.8)
        w.cyl("Entangled sample", (x, 0, 1.12), .12, .085, sample)
        w.ring("Sample protection cage", (x, 0, 1.16), .16, .014, w.steel)
        for y in (-.61, .61):
            w.box("Control readout module", (x, y, .72), (.47, .29, .45), w.white)
            for row in range(4):
                w.box("Readout heat sink", (x, y, .56+row*.10), (.50, .31, .025), w.iron, .003)
    for y in (-.25, .25):
        w.pipe("Optical link guide", [(-.47, y, 1.01), (0, y, 1.13), (.47, y, 1.01)], .024, w.steel)
        for index in range(7):
            pulse = w.pulse("Entanglement link activity", (.54, .11, .77), index*.7, 2)
            w.box("Optical link packet", (-.30+index*.10, y, 1.12), (.035, .035, .025), pulse, .002)
    return 2, .65, 6


def construction(w):
    w.base(1.89, w.ochre)
    w.box("Construction power distribution", (0, 0, .77), (.64, .64, .71), w.iron)
    w.box("Insulated bus cover", (0, 0, 1.16), (.72, .72, .08), w.steel)
    flat_text(w, "+", (0, -.12, 1.21), .37, w.ochre)
    for side in range(4):
        with w.part("Battery service quadrant", angle=side*math.pi/2):
            for x in (-.25, .25):
                w.cyl("Power cell ceramic sleeve", (x, -.60, .81), .17, .72, w.white)
                w.cyl("Power cell terminal cap", (x, -.60, 1.20), .16, .06, w.steel)
                w.cyl("Insulated terminal", (x, -.60, 1.25), .065, .05, w.ochre)
                w.pipe("Heavy copper bus", [(x, -.60, 1.27), (x, -.41, 1.30), (x*.7, -.29, 1.20)], .022)
            w.box("Charge indicator fascia", (0, -.87, .82), (.77, .07, .58), w.iron)
            for index in range(5):
                lamp = w.pulse("Construction charging indicator", (.09, .70, .30), side+index*.8, 1.9)
                w.box("Charge bar segment", (-.27+index*.135, -.91, .91), (.08, .017, .17), lamp, .002)
            for x in (-.70, .70):
                w.box("Protective battery corner", (x, -.70, .78), (.13, .13, .77), w.steel)
                w.bolt((x, -.70, 1.19))
    return 2, .70, 6


def requester_node(w):
    """QLN Requester Node: 1x1, one filter slot, requests items from storage."""
    w.base(.89, w.paint)
    w.box("Request filter chassis", (0, 0, .46), (.74, .74, .22), w.iron)
    w.box("Filter item recess", (0, 0, .60), (.59, .59, .11), w.black)
    w.box("Filter template item", (0, 0, .66), (.45, .45, .08), w.pcb)
    for col in range(3):
        w.box("Filter contact pin", (-.14+col*.14, 0, .72), (.02, .02, .03), w.gold, 0)
    for side in range(4):
        with w.part("Request indicator quadrant", angle=side*math.pi/2):
            w.box("Network coupling port", (0, -.38, .50), (.20, .08, .10), w.steel)
            for index in range(3):
                lamp = w.pulse("Request pulse indicator", (.22, .30, .85), side+index*.8, 1.7)
                w.box("Request lamp", (-.09+index*.18, -.47, .54), (.05, .05, .014), lamp, .002)
            w.box("Status arrow", (0, -.40, .68), (.09, .018, .009), w.ivory, 0)
    return 1, .56, 6


BUILDERS = {
    "metrology-lab": metrology,
    "answer-engine": answer_engine,
    "qln-storage-drive": storage_drive,
    "quantum-entanglement-core": quantum_core,
    "construction-core": construction,
    "qln-requester-node": requester_node,
}
