"""Game labs: fixed-view machinery, low-poly primitives, working/idle states.

No privileged operator face. One unit = one tile. Working loops are editable
Blender drivers with a 48-frame period; static/animated exports share geometry.
"""
import math
import sys
from contextlib import contextmanager
from pathlib import Path

import bpy
from mathutils import Vector

ASSETS = ("analytical-engine", "tube-mainframe", "mainframe-cluster", "datacenter-lab", "cryostat",
          "metrology-lab", "answer-engine", "qln-storage-drive", "quantum-entanglement-core", "construction-core",
          "foup-dock", "wireless-access-point", "qln-import-node", "qln-export-node", "qln-provider-node",
          "qln-requester-node", "qln-terminal", "training-cluster", "inference-lab",
          "circuit-assembler", "network-monitor")
TAU = math.tau


class Workshop:
    def __init__(self):
        self.scene = bpy.context.scene
        self.scene["working"] = 1.0
        self.parent = None
        self.cols = {}
        for name in ("Base", "Details", "Emission", "Cables", "Rig", "Reference"):
            col = bpy.data.collections.new(name)
            self.scene.collection.children.link(col)
            self.cols[name] = col
        self.iron = self.material("Cast iron", (.045, .060, .064), .65, .48)
        self.paint = self.material("Industrial green enamel", (.17, .23, .20), .45, .43)
        self.steel = self.material("Machined steel", (.43, .49, .50), .8, .30)
        self.white = self.material("Laboratory enamel", (.60, .68, .69), .48, .34)
        self.black = self.material("Recesses and rubber", (.008, .014, .017), .05, .76)
        self.brass = self.material("Oiled brass", (.53, .29, .067), .82, .28)
        self.copper = self.material("Annealed copper", (.43, .13, .045), .78, .29)
        self.ivory = self.material("Ivory number enamel", (.79, .75, .57), .1, .50)
        self.pcb = self.material("Green circuit substrate", (.02, .17, .075), .2, .43)
        self.gold = self.material("Gold plated contact", (.70, .44, .10), .82, .25)
        self.blue = self.material("Coolant blue", (.025, .21, .29), .35, .3)
        self.frost = self.material("Rime ice", (.57, .79, .83), .05, .86)
        self.ochre = self.material("Safety ochre", (.63, .32, .045), .3, .55)
        self.glass = self.material("Quartz envelope", (.37, .50, .49), .0, .13)
        shader = self.glass.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Transmission Weight"].default_value = .82
        shader.inputs["IOR"].default_value = 1.45

    def material(self, name, color, metal=0, rough=.45, emission=0):
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = (*color, 1)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        for key, value in (("Base Color", (*color, 1)), ("Metallic", metal),
                           ("Roughness", rough), ("Emission Color", (*color, 1)),
                           ("Emission Strength", emission)):
            shader.inputs[key].default_value = value
        if not emission:
            nodes, links = mat.node_tree.nodes, mat.node_tree.links
            noise = nodes.new("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = 65
            bump = nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = .10
            bump.inputs["Distance"].default_value = .006
            links.new(noise.outputs["Fac"], bump.inputs["Height"])
            links.new(bump.outputs["Normal"], shader.inputs["Normal"])
            ramp = nodes.new("ShaderNodeValToRGB")
            ramp.color_ramp.elements[0].color = (*(v*.80 for v in color), 1)
            ramp.color_ramp.elements[1].color = (*color, 1)
            links.new(noise.outputs["Fac"], ramp.inputs[0])
            links.new(ramp.outputs[0], shader.inputs["Base Color"])
        return mat

    def finish(self, obj, name, mat=None, bevel=0, col="Details"):
        obj.name = name
        for old in list(obj.users_collection):
            old.objects.unlink(obj)
        self.cols[col].objects.link(obj)
        obj.parent = self.parent
        if mat:
            obj.data.materials.append(mat)
        if bevel:
            mod = obj.modifiers.new("Machined edges", "BEVEL")
            mod.width, mod.segments = bevel, 1
            obj.modifiers.new("Corner normals", "WEIGHTED_NORMAL")
        return obj

    def box(self, name, loc, size, mat=None, bevel=.01, col="Details"):
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        obj = bpy.context.object
        obj.dimensions = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        return self.finish(obj, name, mat or self.iron, bevel, col)

    def cyl(self, name, loc, radius, depth, mat=None, axis="Z", vertices=None):
        vertices = vertices or (8 if radius < .08 else 16 if radius < .35 else 24)
        rot = {"X": (0, math.pi/2, 0), "Y": (math.pi/2, 0, 0), "Z": (0, 0, 0)}[axis]
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                           depth=depth, location=loc, rotation=rot)
        obj = self.finish(bpy.context.object, name, mat or self.steel, .003 if radius > .10 else 0)
        for face in obj.data.polygons:
            face.use_smooth = len(face.vertices) == 4
        return obj

    def ring(self, name, loc, radius, thickness, mat=None, axis="Z"):
        rot = {"X": (0, math.pi/2, 0), "Y": (math.pi/2, 0, 0), "Z": (0, 0, 0)}[axis]
        bpy.ops.mesh.primitive_torus_add(major_segments=24 if radius > .20 else 16, minor_segments=4,
                                       major_radius=radius, minor_radius=thickness,
                                       location=loc, rotation=rot)
        return self.finish(bpy.context.object, name, mat or self.steel)

    def pipe(self, name, points, radius=.025, mat=None):
        curve = bpy.data.curves.new(name, "CURVE")
        curve.dimensions, curve.bevel_depth, curve.bevel_resolution = "3D", radius, 1
        curve.resolution_u = 5
        spline = curve.splines.new("BEZIER")
        spline.bezier_points.add(len(points)-1)
        for point, co in zip(spline.bezier_points, points):
            point.co = co
            point.handle_left_type = point.handle_right_type = "AUTO"
        obj = bpy.data.objects.new(name, curve)
        self.cols["Cables"].objects.link(obj)
        obj.parent = self.parent
        curve.materials.append(mat or self.copper)
        return obj

    @contextmanager
    def part(self, name, loc=(0, 0, 0), angle=0):
        obj = bpy.data.objects.new(name, None)
        self.cols["Details"].objects.link(obj)
        obj.parent, obj.location = self.parent, loc
        obj.rotation_euler.z = angle
        previous, self.parent = self.parent, obj
        try:
            yield obj
        finally:
            self.parent = previous

    def driver(self, obj, path, index, expression):
        obj.driver_add(path, index).driver.expression = expression

    def spin(self, obj, turns=1, phase=0, axis=2):
        self.driver(obj, "rotation_euler", axis, f"{phase}+{turns}*2*pi*(frame-1)/48")

    def travel(self, obj, axis, distance, phase=0):
        origin = obj.location[axis]
        self.driver(obj, "location", axis, f"{origin}+{distance}*sin(2*pi*(frame-1)/48+{phase})")

    def pulse(self, name, color, phase, level=2):
        mat = self.material(name, color, emission=level)
        socket = mat.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"]
        def state_driver(socket, index, expression):
            curve = socket.driver_add("default_value") if index is None else socket.driver_add("default_value", index)
            driver = curve.driver
            variable = driver.variables.new()
            variable.name, variable.type = "working", "SINGLE_PROP"
            variable.targets[0].id_type = "SCENE"
            variable.targets[0].id = self.scene
            variable.targets[0].data_path = '["working"]'
            driver.expression = expression
        state_driver(socket, None, f"working*{level}*(0.6+0.4*sin(2*pi*(frame-1)/48+{phase}))")
        base = mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"]
        for index in range(3):
            state_driver(base, index, f"{color[index]}*(0.025+0.975*working)")
        return mat

    def bolt(self, loc, axis="Z"):
        self.cyl("Captive hex bolt", loc, .021, .018, self.steel, axis, 6)

    def base(self, size, color=None, depth=None):
        depth = depth or size
        for x in (-size*.36, size*.36):
            self.box("Isolation skid", (x, 0, .07), (.23, depth*.92, .14), self.black, .02, "Base")
        self.box("Cast plinth", (0, 0, .19), (size, depth, .19), self.iron, .04, "Base")
        self.box("Machined perimeter rim", (0, 0, .30), (size+.02, depth+.02, .05), self.steel)
        self.box("Service deck", (0, 0, .37), (size-.12, depth-.12, .10), color or self.paint)
        for side in range(4):
            width, length = (size, depth) if side % 2 == 0 else (depth, size)
            with self.part("Perimeter service edge", angle=side*math.pi/2):
                self.box("Panel gasket", (0, -length/2-.005, .20), (width*.72, .015, .055), self.black)
                for x in (-width*.42, width*.42):
                    self.bolt((x, -length*.42, .44))
                for x in (-.18, 0, .18):
                    self.box("Edge safety marking", (x, -length/2-.016, .21), (.065, .014, .035), self.ochre, .002)

    def gear(self, name, radius, teeth=20, turns=1, mat=None):
        with self.part(name) as rotor:
            self.spin(rotor, turns)
            self.cyl("Gear web", (0, 0, 0), radius*.85, .055, mat or self.brass)
            self.cyl("Axle boss", (0, 0, .025), radius*.22, .12, self.steel)
            for i in range(teeth):
                a = i*TAU/teeth
                tooth = self.box("Cut gear tooth", (radius*math.cos(a), radius*math.sin(a), 0),
                                 (radius*.19, radius*.15, .07), mat or self.brass, .003)
                tooth.rotation_euler.z = a
            for i in range(5):
                a = i*TAU/5
                self.cyl("Gear lightening recess", (radius*.56*math.cos(a), radius*.56*math.sin(a), .031),
                         radius*.11, .006, self.black, vertices=12)

    def fan(self, loc, radius=.22, phase=0):
        self.cyl("Fan well", loc, radius*1.12, .05, self.black)
        self.ring("Fan rim", (loc[0], loc[1], loc[2]+.035), radius*1.08, .014)
        with self.part("Working fan rotor", (loc[0], loc[1], loc[2]+.04)) as rotor:
            self.spin(rotor, 1, phase)
            self.cyl("Fan hub", (0, 0, 0), radius*.23, .04, self.steel)
            for i in range(7):
                a = i*TAU/7
                blade = self.box("Swept fan blade", (radius*.53*math.cos(a), radius*.53*math.sin(a), 0),
                                 (radius*.66, radius*.22, .02), self.steel, .01)
                blade.rotation_euler.z = a+.4
        for i in (-2, -1, 0, 1, 2):
            self.box("Fan safety grille", (loc[0]+i*radius*.30, loc[1], loc[2]+.08),
                     (.009, radius*1.78, .012), self.iron, .002)


def analytical(w):
    """A 4x2 open mechanical hall: two long stores, mill and drive aisle between."""
    w.base(3.86, depth=1.86)
    w.box("Central inspection walkway", (0, 0, .45), (3.35, .25, .06), w.iron)
    for side in (-1, 1):
        y = side*.53
        w.box("Continuous lower bearing beam", (0, y, .51), (3.45, .16, .14), w.iron)
        w.box("Continuous upper bearing beam", (0, y, 1.39), (3.45, .14, .12), w.paint)
        for column in range(6):
            x = -1.45+column*.58
            with w.part("Arithmetic register bay", (x, y, 0)):
                w.cyl("Register spindle", (0, 0, .96), .027, .92, w.steel)
                for digit in range(4):
                    z = .67+digit*.17
                    with w.part("Decimal register drum", (0, 0, z)) as drum:
                        w.spin(drum, 1 if digit % 2 == 0 else -1, digit*.35+column*.3)
                        w.cyl("Brass decimal wheel", (0, 0, 0), .14, .13, w.brass)
                        w.cyl("Number band", (0, 0, .005), .142, .077, w.iron)
                        for number in range(10):
                            a = number*TAU/10
                            curve = bpy.data.curves.new("Decimal numeral", "FONT")
                            curve.body, curve.size, curve.align_x = str(number), .058, "CENTER"
                            curve.resolution_u = 2
                            obj = bpy.data.objects.new("Number " + str(number), curve)
                            w.cols["Details"].objects.link(obj)
                            obj.parent = w.parent
                            obj.location = (.145*math.sin(a), -.145*math.cos(a), -.022)
                            obj.rotation_euler = (math.pi/2, 0, a)
                            curve.materials.append(w.ivory)
                        for tooth in range(10):
                            a = tooth*TAU/10
                            pin = w.box("Carry tooth", (.14*math.cos(a), .14*math.sin(a), -.052),
                                        (.042, .028, .025), w.brass, 0)
                            pin.rotation_euler.z = a
                w.cyl("Upper spindle bearing", (0, 0, 1.33), .063, .07, w.brass)
                with w.part("Register drive gear", (0, 0, .57)):
                    w.gear("Decimal carry pinion", .15, 12, -1)
                comb = w.box("Reciprocating carry comb", (0, -side*.21, .96), (.33, .055, .04), w.steel)
                w.travel(comb, 2, .065, column*.7)
                for z in (.68, .85, 1.02, 1.19):
                    pawl = w.box("Carry pawl", (0, -side*.15, z), (.035, .12, .028), w.copper, 0)
                    w.travel(pawl, 2, .065, column*.7)
            if side == 1:
                with w.part("Aisle mill gearing", (x, 0, .62)):
                    w.gear("Arithmetic mill gear", .22, 16, 1 if column % 2 == 0 else -1)
                with w.part("Eccentric drive", (x, 0, .72)) as crank:
                    w.spin(crank, 1, column*.7)
                    w.box("Drive eccentric", (.07, 0, 0), (.19, .045, .025), w.steel)
            link = w.box("Store-to-mill transfer linkage", (x, side*.24, .77), (.035, .38, .04), w.steel)
            w.travel(link, 1, .035, column*.7)
        for x in (-1.68, 0, 1.68):
            w.box("Hall frame stanchion", (x, side*.78, .88), (.07, .07, 1.03), w.iron)
            w.bolt((x, side*.78, 1.43))
        w.pipe("Lubrication rail", [(-1.65, side*.72, .48), (0, side*.72, .48), (1.65, side*.72, .48)], .016)
    for side in (-1, 1):
        with w.part("Program feed at hall end", (side*1.73, 0, 0), side*math.pi/2):
            w.box("Card feed throat", (0, 0, .62), (.48, .25, .25), w.paint)
            card = w.box("Advancing punched program", (0, -.08, .77), (.41, .33, .012), w.ivory, .002)
            w.travel(card, 1, .04)
            for col in range(6):
                for row in range(2):
                    hole = w.box("Program perforation", (-.16+col*.06, -.13+row*.09, .778),
                                 (.017, .032, .002), w.black, 0)
                    w.travel(hole, 1, .04)
    return [4, 2], .65, 5.4


def tube_mainframe(w):
    w.base(1.89)
    w.cyl("Central sequencing relay", (0, 0, .85), .23, .74, w.iron)
    w.ring("Copper relay bus", (0, 0, 1.18), .24, .026, w.copper)
    with w.part("Rotary relay distributor", (0, 0, 1.25)) as rotor:
        for i in range(4):
            a = i*math.pi/2
            arm = w.box("Distributor contact", (.13*math.cos(a), .13*math.sin(a), 0), (.26, .035, .025), w.brass)
            arm.rotation_euler.z = a
    for side in range(4):
        with w.part("Symmetric tube bank", angle=side*math.pi/2):
            w.box("Tube bank ceramic bed", (0, -.58, .57), (.86, .53, .18), w.ivory)
            for col, x in enumerate((-.24, 0, .24)):
                for row, y in enumerate((-.47, -.72)):
                    h = 1.08 + (row % 2)*.17
                    w.cyl("Valve socket", (x, y, .72), .102, .11, w.iron)
                    w.cyl("Vacuum glass envelope", (x, y, (h+.77)/2), .089, h-.77, w.glass)
                    w.ring("Glass envelope crown", (x, y, h), .065, .022, w.glass)
                    glow = w.pulse("Filament activity", (1, .17, .018), side+row+col, 3)
                    w.cyl("Heated cathode", (x, y-.032, (h+.77)/2), .018, h-.81, glow)
                    for z in (.79, h-.02):
                        w.ring("Anode collar", (x, y, z), .058, .01, w.copper)
                    w.pipe("Tube signal jumper", [(x, y, .73), (x+.06, y+.06, .68), (x+.08, y+.10, .58)], .01, w.copper)
            w.pipe("Copper signal manifold", [(-.37, -.32, .67), (0, -.28, .70), (.37, -.32, .67)], .025)
            w.cyl("Upward analogue meter", (0, -.87, .51), .10, .03, w.brass)
            w.cyl("Meter face", (0, -.87, .53), .079, .01, w.ivory)
            with w.part("Moving meter needle", (0, -.87, .54)) as needle:
                w.box("Needle", (0, .025, 0), (.009, .09, .005), w.iron, 0)
            w.box("Corner transformer", (.69, -.69, .73), (.29, .29, .46), w.iron)
            for i in range(6):
                w.box("Transformer laminations", (.69, -.80+i*.043, .75), (.32, .018, .46), w.steel, .003)
    return 2, .70, 4.2


def mainframe(w):
    w.base(1.91)
    w.cyl("Central cooling plenum", (0, 0, .78), .37, .64, w.iron)
    w.fan((0, 0, 1.14), .31)
    for side in range(4):
        with w.part("Radial logic bank", angle=side*math.pi/2):
            w.box("Card backplane", (0, -.57, .55), (.89, .42, .14), w.iron)
            for col, x in enumerate((-.30, -.10, .10, .30)):
                w.box("Exposed logic card", (x, -.59, 1.0), (.145, .055, .77), w.pcb, .004)
                for z in (.77, .98, 1.19):
                    w.box("Ceramic logic IC", (x, -.625, z), (.085, .025, .12), w.black, .003)
                    for pin in (-1, 1):
                        for row in range(3):
                            w.box("IC lead", (x+pin*.053, -.625, z-.04+row*.04), (.022, .014, .01), w.steel, .001)
                for i in range(3):
                    w.box("Gold backplane contact", (x-.044+i*.043, -.63, .66), (.022, .012, .08), w.gold, .001)
                w.box("Card retention handle", (x, -.59, 1.43), (.15, .11, .05), w.ivory)
                activity = w.pulse("Logic bank activity", (.1, .85, .26), side+col*1.2, 2)
                w.box("Activity indicator", (x, -.64, 1.35), (.05, .017, .028), activity, .003, "Emission")
            w.box("External guard rail", (0, -.82, .73), (.94, .055, .055), w.steel)
            for x in (-.45, .45):
                w.box("Card cage upright", (x, -.58, .94), (.045, .12, .85), w.steel)
            w.pipe("Bundled backplane bus", [(-.32, -.39, .64), (-.20, -.27, .78), (0, -.26, .94)], .038)
            w.box("Corner power converter", (.72, -.72, .75), (.32, .32, .51), w.paint)
            for row in range(5):
                w.box("Converter heat sink", (.72, -.72, .60+row*.085), (.37, .37, .027), w.iron, .003)
            w.bolt((.72, -.72, 1.04))
    return 2, .76, 4.3


def datacenter(w):
    w.base(1.92, w.white)
    w.box("Central analysis chamber", (0, 0, .82), (.94, .94, .75), w.iron)
    w.box("Recessed analysis surface", (0, 0, 1.21), (.79, .79, .04), w.blue)
    for x in (-.27, -.09, .09, .27):
        for y in (-.27, -.09, .09, .27):
            w.box("Top-plane compute package", (x, y, 1.245), (.12, .12, .025), w.iron, .003)
            for pin in (-1, 1):
                w.box("Top-plane copper trace", (x+pin*.07, y, 1.235), (.02, .10, .005), w.gold, 0)
    for i in range(6):
        glow = w.pulse("Dataset scan channel", (.035, .50, .70), i*.7, 1.5)
        bar = w.box("Scanning optical head", (-.29+i*.115, 0, 1.25), (.037, .68, .016), glow, .002, "Emission")
    for side in range(4):
        with w.part("Liquid cooled research quadrant", angle=side*math.pi/2):
            w.box("Compute canister", (0, -.70, .82), (.88, .32, .76), w.white, .025)
            w.box("Canister gasket", (0, -.875, .82), (.65, .018, .55), w.black)
            for row in range(6):
                w.box("Heat exchanger fin", (0, -.89, .61+row*.065), (.59, .035, .024), w.steel, .003)
            for x in (-.32, .32):
                w.bolt((x, -.89, .55), "Y")
                w.bolt((x, -.89, 1.08), "Y")
            for x in (-.30, .30):
                w.pipe("Coolant supply and return", [(x, -.54, .63), (x, -.45, .82), (x, -.44, 1.14)], .035, w.blue)
                w.ring("Coolant coupling", (x, -.45, .88), .05, .012)
            w.fan((.70, -.70, 1.03), .19, side*.4)
            w.box("Corner radiator", (.70, -.70, .74), (.40, .40, .52), w.steel)
            for row in range(5):
                w.box("Radiator cooling fin", (.70, -.70, .55+row*.08), (.46, .46, .018), w.iron, .003)
            for row in range(4):
                w.box("Server blade seam", (0, -.89, .59+row*.13), (.61, .012, .009), w.black, 0)
                w.box("Server blade latch", (.24, -.915, .63+row*.13), (.06, .04, .06), w.white, .004)
            for i in range(5):
                indicator = w.pulse("Research telemetry", (.02, .65, .86), side+i*.8, 1.5)
                w.box("Top telemetry bar", (-.28+i*.14, -.70, 1.21), (.045, .17, .015), indicator, .003, "Emission")
    return 2, .77, 4.3


def cryostat(w):
    w.base(1.92, w.white)
    w.cyl("Vacuum vessel", (0, 0, .73), .57, .59, w.steel)
    for z in (.46, .61, .97):
        w.ring("Vacuum flange", (0, 0, z), .58, .031, w.white)
    for z, radius in ((1.04, .50), (1.26, .40), (1.48, .29)):
        w.cyl("Gold thermal radiation shield", (0, 0, z), radius, .045, w.gold)
        w.ring("Thermal shield edge", (0, 0, z+.025), radius, .014, w.copper)
        for i in range(4):
            a = i*math.pi/2+math.pi/4
            w.cyl("Thermal suspension rod", (radius*.75*math.cos(a), radius*.75*math.sin(a), z+.09),
                  .014, .19, w.steel)
    core = w.pulse("Quantum core pulse", (.025, .55, .85), 0, 3)
    w.cyl("Quantum sample stage", (0, 0, 1.58), .16, .12, w.iron)
    w.cyl("Quantum sample glow", (0, 0, 1.66), .12, .045, core)
    w.ring("Sample guard ring", (0, 0, 1.69), .18, .019, w.steel)
    for side in range(4):
        with w.part("Refrigeration quadrant", angle=side*math.pi/2):
            w.pipe("Upper helium elbow", [(0, -.25, 1.53), (0, -.52, 1.53), (0, -.71, 1.34)], .038)
            w.cyl("Straight helium riser", (0, -.71, 1.065), .038, .55, w.copper)
            w.pipe("Lower helium elbow", [(0, -.71, .79), (0, -.71, .65), (.57, -.71, .63)], .038)
            for z in (.89, 1.08, 1.27):
                w.cyl("Coaxial insulation sleeve", (0, -.71, z), .056, .065, w.frost)
            w.box("Compressor housing", (.71, -.71, .76), (.40, .40, .65), w.white)
            for row in range(5):
                w.box("Compressor heat sink", (.71, -.71, .53+row*.095), (.44, .44, .021), w.iron, .003)
            w.box("Sealed compressor head", (.71, -.71, 1.12), (.34, .34, .08), w.steel)
            for x in (.60, .82):
                for y in (-.60, -.82):
                    w.bolt((x, y, 1.17))
            w.cyl("Pressure gauge", (0, -.87, .61), .09, .04, w.steel)
            w.cyl("Pressure gauge face", (0, -.87, .64), .072, .01, w.ivory)
            for x in (-.46, .46):
                w.box("Ice on support bracket", (x, -.46, .44), (.16, .13, .10), w.frost, .035)
    return 2, .83, 4.4


def build(asset, builder=None, output=None):
    if builder is None and asset not in ASSETS:
        raise ValueError(asset)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Blender may reset Python's search path when loading factory settings.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    w = Workshop()
    builders = {
        "analytical-engine": analytical, "tube-mainframe": tube_mainframe,
        "mainframe-cluster": mainframe, "datacenter-lab": datacenter, "cryostat": cryostat,
    }
    if builder is None:
        from infrastructure_models import BUILDERS
        from logistics_models import BUILDERS as LOGISTICS
        from batch5_models import BUILDERS as BATCH5
        builders.update(BUILDERS)
        builders.update(LOGISTICS)
        builders.update(BATCH5)
    footprint, target, ortho = (builder or builders[asset])(w)
    scene = w.scene
    ground = w.box("Shadow Plane", (0, 0, -.025), (200, 200, .02), w.white, 0, "Reference")
    ground.is_shadow_catcher, ground.hide_render = True, True
    world = bpy.data.worlds.new("Studio fill")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.32, .38, .46, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .45
    scene.world = world
    for name, rotation, energy, color, angle in (
        ("Warm key", (15, -20, -30), 2.5, (1, .91, .72), .10),
        ("Cool fill", (55, 25, 145), .75, (.60, .77, 1), .25),
    ):
        data = bpy.data.lights.new(name, "SUN")
        data.energy, data.color, data.angle = energy, color, angle
        data.use_shadow = name == "Warm key"
        obj = bpy.data.objects.new(name, data)
        w.cols["Rig"].objects.link(obj)
        obj.rotation_euler = tuple(math.radians(v) for v in rotation)
    data = bpy.data.cameras.new("Fixed factory view")
    camera = bpy.data.objects.new("Fixed factory view", data)
    w.cols["Rig"].objects.link(camera)
    # The saved camera is the game camera too: 384px / 64px per tile.
    # No separate hero framing in the editable model.
    canvas = scene.get("export_canvas", 512 if asset == "answer-engine" else 384)
    data.type, data.ortho_scale = "ORTHO", canvas / 64
    camera.location = (0, -12, target+12)
    camera.rotation_euler = (Vector((0, 0, target))-camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples, scene.cycles.use_denoising = 48, True
    scene.render.resolution_x = scene.render.resolution_y = canvas
    scene.render.resolution_percentage, scene.render.fps = 100, 24
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    period = scene.get("animation_period", 48)
    scene.frame_start, scene.frame_end = 1, period
    footprint = footprint if isinstance(footprint, list) else [footprint, footprint]
    for key, value in {"asset_name": asset, "footprint_tiles": footprint,
                       "camera_target_z": target, "sprite_scale": .5, "preview_only": False,
                        "animation_period": period, "animation_fps": 24,
                         "layout": "bilateral non-facing" if asset in {"analytical-engine", "metrology-lab", "quantum-entanglement-core", "circuit-assembler", "network-monitor", "training-cluster"}
                       else "fourfold non-facing",
                       "concept_revision": 3}.items():
        scene[key] = value
    scene["light_only"] = asset in {"tube-mainframe", "cryostat", "qln-storage-drive",
                                    "quantum-entanglement-core", "construction-core", "wireless-access-point",
                                    "qln-import-node", "qln-export-node", "qln-provider-node",
                                    "qln-requester-node", "qln-terminal", "network-monitor"}
    scene.frame_set(1)
    # Bake low-resolution bevels/fonts, then batch only rigid siblings by
    # material. Driver-bearing objects and animated parent pivots stay intact.
    # This reduces BVH/object overhead without decimating a moving silhouette.
    bpy.ops.object.select_all(action="DESELECT")
    sources = [obj for obj in scene.objects if obj.type in {"MESH", "FONT"}]
    for obj in sources:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = sources[0]
    bpy.ops.object.convert(target="MESH")
    before = len([obj for obj in scene.objects if obj.type == "MESH"])
    groups = {}
    for obj in list(scene.objects):
        if obj.type != "MESH" or (obj.animation_data and obj.animation_data.drivers):
            continue
        key = (obj.parent, tuple(col.name for col in obj.users_collection),
               tuple(mat.name if mat else "" for mat in obj.data.materials))
        groups.setdefault(key, []).append(obj)
    for group in groups.values():
        if len(group) < 2:
            continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        bpy.ops.object.join()
    triangles = 0
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    scene["mesh_objects_before_batching"] = before
    scene["mesh_objects_after_batching"] = len(meshes)
    scene["triangle_count"] = triangles
    print(f"Geometry budget: {triangles} triangles; {before} -> {len(meshes)} mesh objects")
    path = Path(output) if output else Path(__file__).resolve().parent/asset/(asset+".blend")
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    print("Built native game lab model:", path)
