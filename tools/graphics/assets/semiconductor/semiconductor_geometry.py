"""Industrial semiconductor machinery: five different processes on 5x5 foundations.

No entrypoint registrations, installed files or external references. Motion is
authored as closed handling/process cycles; props are baked, not runtime items.
"""
import math
import bpy
from mathutils import Vector

PERIOD = 96


def smooth(t):
    t = min(1, max(0, t))
    return t*t*(3-2*t)


def sample(phase, poses):
    for (a, p), (b, q) in zip(poses, poses[1:]):
        if a <= phase <= b:
            t = smooth((phase-a)/(b-a))
            return p+(q-p)*t
    return poses[0][1]


def track(obj, channel, axis, poses, period=PERIOD):
    """Empty-parent keyframes keep moving mechanisms out of static mesh batching."""
    for frame in range(1, period+2):
        getattr(obj, channel)[axis] = sample(frame-1, poses)
        obj.keyframe_insert(data_path=channel, index=axis, frame=frame)
    action = obj.animation_data.action
    for slot in action.slots:
        for layer in action.layers:
            for strip in layer.strips:
                for curve in strip.channelbag(slot).fcurves:
                    for point in curve.keyframe_points:
                        point.interpolation = 'LINEAR'


def validate_cycle(w, check):
    """Process-specific interlocks run before rendering, in addition to pipeline bounds checks."""
    for phase in range(PERIOD):
        w.scene.frame_set(phase+1)
        bpy.context.view_layer.update()
        check(phase)
    w.scene.frame_set(1)


def lamp(w, name, color, gate="1", strength=1.5):
    mat = w.material(name, color, emission=strength)
    shader = mat.node_tree.nodes.get('Principled BSDF')
    for socket, index, expression in [(shader.inputs['Emission Strength'], None,
                                       f'working*{strength}*({gate})')] + [
            (shader.inputs['Base Color'], i, f'{c}*(0.025+0.975*working*({gate}))')
            for i, c in enumerate(color)]:
        driver = (socket.driver_add('default_value') if index is None else
                  socket.driver_add('default_value', index)).driver
        variable = driver.variables.new()
        variable.name, variable.type = 'working', 'SINGLE_PROP'
        variable.targets[0].id_type, variable.targets[0].id = 'SCENE', w.scene
        variable.targets[0].data_path = '["working"]'
        driver.expression = expression
    return mat


def foundation(w, color=None):
    w.scene['animation_period'] = PERIOD
    w.scene['art_revision'] = 2
    w.scene['export_canvas'] = 768
    w.base(4.78, color or w.paint)
    # Walking/access surfaces are part of the machine, not a vacant oversized slab.
    for x in (-2.18, 2.18):
        w.box('Perimeter service tread', (x, 0, .44), (.27, 3.88, .025), w.steel, .004)
        for y in (-1.70, -1.13, -.56, .01, .58, 1.15, 1.72):
            w.box('Tread raised grip', (x, y, .459), (.23, .035, .015), w.steel, .001)


def service(w, loc, width=.65, height=.80, color=None):
    with w.part('Power and process service', loc):
        w.box('Anchored service cabinet', (0, 0, height/2+.45), (width, .63, height), color or w.paint, .025)
        w.box('Recessed access panel', (0, -.325, height/2+.44), (width*.76, .022, height*.70), w.iron, .004)
        for z in range(4):
            w.box('Cabinet ventilation slit', (0, -.341, .55+z*.10), (width*.63, .012, .025), w.black, .001)
        w.box('Isolator pull handle', (width*.26, -.35, height*.68+.4), (.035, .045, .12), w.ivory, .003)


def gauge(w, loc, radius=.10):
    x, y, z = loc
    w.cyl('Pressure gauge bezel', loc, radius, .04, w.steel, 'Y')
    w.cyl('Pressure gauge dial', (x, y-.027, z), radius*.78, .013, w.ivory, 'Y')
    needle = w.box('Pressure gauge needle', (x+.015, y-.037, z+.012), (.012, .009, radius*1.1), w.iron, 0)
    needle.rotation_euler.y = -.48


def fluid_ports(w, xs):
    """Native input/output tile positions are pinned separately in the candidate binding."""
    for side in (-1, 1):
        for x in xs:
            w.cyl('Perimeter process coupling', (x, side*2.23, .43), .075, .31, w.steel, 'Y')
            w.ring('Coupling lock flange', (x, side*2.35, .43), .085, .018, w.iron, 'Y')
            w.pipe('Connected underfloor process service', [(x, side*2.23, .43), (x, side*.65, .43), (0, side*.65, .43), (0, side*.65, .70)], .06, w.steel)
            w.ring('Process line identification band', (x, side*2.16, .43), .078, .012, w.blue, 'Y')


def wafer(w, name, loc=(0, 0, 0), radius=.40, etched=True):
    with w.part(name, loc):
        silicon = w.material(name+' polished silicon', (.12, .20, .27), .82, .23)
        w.cyl(name+' disk', (0, 0, 0), radius, .025, silicon, vertices=48)
        if etched:
            # Restrict every scribe line to the circular wafer; no square lattice overhangs.
            for i in (-2, -1, 0, 1, 2):
                offset = i*radius*.29
                length = 2*math.sqrt(max(0, (radius*.91)**2-offset**2))
                w.box('Wafer scribe lane', (offset, 0, .015), (.008, length, .003), w.gold, 0)
                w.box('Wafer orthogonal scribe lane', (0, offset, .015), (length, .008, .003), w.gold, 0)
        w.box('Wafer orientation flat', (0, -radius+.025, .019), (radius*.35, .018, .004), w.steel, 0)


def cassette(w, loc, count=5, radius=.30):
    with w.part('Open wafer carrier', loc):
        w.box('Carrier bottom', (0, 0, 0), (.76, .78, .08), w.ivory)
        for x in (-.37, .37):
            w.box('Carrier slotted side', (x, .10, .35), (.055, .60, .64), w.iron)
            for i in range(count):
                w.box('Carrier wafer support', (x*.92, .04, .10+i*.11), (.065, .58, .025), w.ivory, .002)
        for i in range(count):
            wafer(w, 'Stored wafer', (0, -.035, .12+i*.11), radius, False)
        w.box('Carrier back retaining spine', (0, .37, .35), (.72, .055, .64), w.ivory)


def crystal_puller(w):
    """Grow a boule, lift clear, transfer to the cooling well, then reseed."""
    foundation(w)
    graphite = w.material('Graphite hot-zone lining', (.025, .028, .029), .08, .8)
    silicon = w.material('Faceted crystalline silicon', (.31, .38, .43), .90, .20)
    heat = lamp(w, 'Contained molten-silicon heat', (1, .24, .028),
                '(1 if ((frame-1)%96)<69 else 0.15)', 2.1)
    # Vessel has a deliberately open near-side inspection cutaway, not a solid roof.
    with w.part('Czochralski vessel', (-.52, -.12, 0)):
        w.cyl('Heavy furnace footing', (0, 0, .58), 1.01, .30, w.iron)
        w.cyl('Water-cooled vessel shell', (0, 0, .96), .87, .52, w.steel)
        w.cyl('Refractory furnace crown', (0, 0, 1.24), .92, .14, graphite)
        w.ring('Bolted pressure flange', (0, 0, 1.34), .87, .065, w.steel)
        w.cyl('Graphite crucible mouth', (0, 0, 1.33), .73, .08, graphite)
        w.cyl('Visible melt surface', (0, 0, 1.39), .54, .025, heat)
        w.ring('Crucible ceramic lip', (0, 0, 1.42), .60, .032, w.ivory)
        for i in range(12):
            a = i*math.tau/12
            w.cyl('Flange tie rod', (.84*math.cos(a), .84*math.sin(a), 1.05), .025, .63, w.iron)
        # A rear partial heat shield leaves crystal neck and melt visible at the game camera.
        for i in range(2, 7):
            a = i*math.pi/6
            p = w.box('Segmented thermal shield', (.77*math.cos(a), .77*math.sin(a), 1.69), (.32, .075, .47), w.paint)
            p.rotation_euler.z = a+math.pi/2
    for x in (-1.70, 2.10):
        w.box('Hoist tower cast shoe', (x, .45, .58), (.48, .63, .28), w.iron)
        for dx in (-.17, .17):
            for dy in (-.23, .23):
                w.cyl('Hoist anchor bolt', (x+dx, .45+dy, .75), .035, .10, w.steel)
        for side in (-1, 1):
            brace=w.box('Hoist tapered shoe gusset', (x+side*.12, .45, .94), (.075, .40, .53), w.paint)
            brace.rotation_euler.y=side*.30
        w.box('Hoist drive cover', (x, .64, 1.27), (.31, .23, .46), w.paint)
        for z in (1.15, 1.25, 1.35):
            w.box('Hoist cover vent', (x, .762, z), (.20, .015, .025), w.steel, .001)
        w.box('Braced extraction upright', (x, .45, 2.03), (.20, .24, 2.78), w.steel)
        w.box('Hoist guide strip', (x, .31, 2.03), (.08, .035, 2.53), w.iron)
    w.box('Extraction bridge', (.20, .45, 3.48), (4.34, .47, .30), w.paint, .035)
    w.box('Extraction bridge drive rail', (.20, .18, 3.48), (4.10, .045, .10), w.steel)
    with w.part('Travelling pull head', (-.52, -.12, 0)) as head:
        track(head, 'location', 0, [(0, -.52), (66, -.52), (77, 1.34), (86, 1.34), (94, -.52), (96, -.52)])
        w.box('Pull-head carriage', (0, .17, 3.31), (.45, .55, .33), w.ochre)
        w.cyl('Spindle reduction drive', (0, 0, 3.11), .19, .31, w.steel)
        with w.part('Crystal extraction spindle', (0, 0, 0)) as spindle:
            track(spindle, 'location', 2, [(0, 0), (60, .74), (70, .96), (79, .96), (85, -.15), (89, .96), (96, 0)])
            w.cyl('Seed pull shaft', (0, 0, 2.35), .035, 1.25, w.steel)
            with w.part('Boule rotation', (0, 0, .88)) as turning:
                w.driver(turning, 'rotation_euler', 2, '2*pi*(frame-1)/96')
                boule = w.cyl('Single-crystal boule', (0, 0, .37), .23, .74, silicon, vertices=12)
                # Growth below a fixed neck; deposit is occluded by the cooling well.
                height = '(.26+.74*min(1,((frame-1)%96)/60) if ((frame-1)%96)<85 else .26)'
                w.driver(boule, 'scale', 2, f'{height}/.74')
                w.driver(boule, 'location', 2, f'.77-{height}/2')
                w.cyl('Crystal shoulder', (0, 0, .79), .13, .13, silicon, vertices=12)
                w.cyl('Seed neck', (0, 0, .91), .045, .16, silicon)
    # Lower cooling/collection well and local vacuum/coolant services fill the square.
    w.cyl('Boule cooling well', (1.34, -.12, .91), .49, .91, w.paint)
    w.cyl('Cooling well dark interior', (1.34, -.12, 1.38), .38, .035, graphite)
    w.ring('Cooling-well guard lip', (1.34, -.12, 1.43), .43, .045, w.steel)
    service(w, (1.58, -1.56, 0), .77, .80)
    w.cyl('Vacuum pump motor', (-1.54, -1.65, .79), .24, .69, w.steel, 'X')
    w.box('Pump mounting block', (-1.54, -1.65, .55), (.93, .55, .20), w.iron)
    w.pipe('Vessel vacuum elbow', [(-1.23, -.40, .90), (-1.81, -.61, .90), (-1.81, -1.52, .79)], .075, w.steel)
    w.pipe('Chamber cooling supply', [(.14, -.87, .91), (.55, -1.30, .64), (1.46, -1.30, .64)], .055, w.blue)
    w.pipe('Argon service', [(-.72, .70, 1.02), (-.72, 1.55, 1.02), (-1.58, 1.55, .65)], .035, w.copper)
    gauge(w, (-.99, -.96, .92))
    for x in (-.85, -.25, .35):
        w.box('Cooling exchanger fin', (x, 1.65, .85), (.055, .56, .70), w.steel, .003)
    w.box('Rear cooling header', (-.25, 1.65, .49), (1.45, .64, .15), w.paint)
    def check(phase):
        if -.10 < head.location.x < 1.25:
            bottom = min((boule.matrix_world @ Vector(corner)).z for corner in boule.bound_box)
            assert bottom > 1.47, 'Crystal transfers before clearing the vessel/cooling-well lips'
        if spindle.location.z < .20 and 70 < phase < 89:
            assert abs(head.location.x-1.34) < .001, 'Crystal lowers before reaching the cooling well'
    validate_cycle(w, check)
    return [5, 5], 1.15, 12


def wafer_fab(w):
    """Low radial wet/vacuum cluster: handling arm visits three processing vessels."""
    foundation(w, w.white)
    fluid_ports(w, (-1, 1))
    for x, y, r in [(-1.30, .10, .68), (1.10, -.12, .68), (0, 1.00, .72)]:
        with w.part('Wafer process pod', (x, y, 0)):
            w.cyl('Process chamber foot', (0, 0, .56), r+.06, .22, w.iron)
            w.cyl('Stainless chamber barrel', (0, 0, .97), r, .67, w.steel)
            w.ring('Process flange', (0, 0, 1.32), r, .045, w.iron)
            w.cyl('Top chamber insulation', (0, 0, 1.38), r*.91, .11, w.white)
            for side in (-1, 1):
                w.box('Chamber lid clamp', (side*r*.76, -.15, 1.48), (.12, .31, .11), w.ochre)
            w.cyl('Exhaust throat', (.43, .40, 1.62), .11, .37, w.steel)
            w.ring('Exhaust coupling', (.43, .40, 1.79), .13, .022, w.iron)
            gauge(w, (0, -r-.02, .96))
    w.cyl('Central vacuum transfer drum', (0, -.12, .79), .68, .59, w.iron)
    w.cyl('Open transfer chamber tray', (0, -.12, 1.08), .63, .04, w.black)
    for x,y in [(-1.30,.10),(1.10,-.12),(0,1.00)]:
        w.cyl('Top loading wafer receiver', (x,y,1.49), .40, .06, w.iron)
        w.ring('Receiver locating rim', (x,y,1.53), .41, .02, w.steel)
    with w.part('Vacuum wafer robot', (0, -.12, 1.90)) as robot:
        track(robot, 'rotation_euler', 2, [(0,0),(17,0),(27,math.pi/2),(64,math.pi/2),(74,0),(96,0)])
        w.cyl('Robot hub', (0, 0, .015), .18, .14, w.steel)
        w.box('Fixed telescoping slide', (0,-.39,0), (.23,.95,.12), w.iron)
        with w.part('Telescoping wafer blade', (0, 0, 0)) as blade:
            track(blade, 'location', 1, [(0,-.97),(11,-.97),(17,-.62),(27,-.62),(33,-.94),(57,-.94),(64,-.62),(74,-.62),(78,-.97),(83,-.97),(89,-.62),(96,-.97)])
            w.box('Wafer robot transfer beam', (0, .25, 0), (.16, .90, .08), w.steel)
            for x in (-.10, .10):
                w.box('Vacuum fork tine', (x, -.16, .015), (.055, .38, .045), w.ivory, .003)
            track(blade, 'location', 2, [(0,-.30),(11,-.30),(17,0),(28,0),(32,-.30),(57,-.30),(64,0),(74,0),(78,-.30),(83,-.30),(89,0),(96,-.30)])
            with w.part('Transferred wafer payload') as payload:
                for axis in range(3):
                    w.driver(payload,'scale',axis,'1 if 8<=((frame-1)%96)<34 or 56<=((frame-1)%96)<80 else 0')
                wafer(w, 'Handled wafer', (0, -.16, .055), .36)
    with w.part('Wafer resting on right receiver', (1.10,-.12,1.655)) as deposited:
        for axis in range(3):
            w.driver(deposited,'scale',axis,'1 if 34<=((frame-1)%96)<56 else 0')
        wafer(w,'Deposited process wafer',radius=.36)
    with w.part('Wafer at input pickup', (0,-1.25,1.655)) as incoming:
        for axis in range(3):
            w.driver(incoming,'scale',axis,'1 if ((frame-1)%96)<8 or ((frame-1)%96)>=80 else 0')
        wafer(w,'Input wafer',radius=.36)
    w.box('Input wafer loading shelf', (0,-1.25,1.58), (.88,.83,.08), w.steel)
    for x in (-.73, .73):
        w.box('FOUP docking pedestal', (x, -1.62, .65), (.90, .92, .40), w.paint)
        cassette(w, (x, -1.65, .90))
    for x in (-1.89, 1.89):
        w.pipe('Process gas header', [(1 if x>0 else -1, -2.23, .43), (x, -1.40, .61), (x, .35, .61), (x, 1.48, .90), (x*.89, 1.48, .90)], .055, w.copper)
        service(w, (x*.89, 1.48, 0), .53, .77, w.white)
    ready = lamp(w, 'Wafer transfer ready', (.08, .54, .24), '(1 if ((frame-1)%24)<6 else 0.02)')
    for x in (-.73, .73):
        w.box('Dock status window', (x, -2.10, .70), (.17, .025, .06), ready, .003)
    previous = [0]
    def check(phase):
        if phase and abs(robot.rotation_euler.z-previous[0]) > .0001:
            assert blade.location.y > -.631, 'Wafer robot turns before withdrawing from a process pod'
        previous[0] = robot.rotation_euler.z
    validate_cycle(w, check)
    return [5, 5], .85, 12


def package(w, x, y, z, lid=False):
    w.box('Leadframe carrier island', (x, y, z), (.38, .37, .025), w.copper, .003)
    w.box('Package die substrate', (x, y, z+.035), (.24, .25, .045), w.black, .003)
    if lid:
        w.box('Moulded package cap', (x, y, z+.085), (.29, .30, .07), w.iron, .004)
    else:
        w.box('Exposed silicon die', (x, y, z+.069), (.12, .13, .018), w.steel, .002)
        for dx in (-.08, .08):
            for i in range(3):
                yy = y-.06+i*.06
                w.pipe('Fine bond wire', [(x+dx*.45, yy, z+.079), (x+dx*.75, yy, z+.10), (x+dx*1.1, yy, z+.061)], .0035, w.gold)
    for side in (-1, 1):
        for pin in range(4):
            w.box('Package pin', (x-.13+pin*.085, y+side*.22, z), (.035, .12, .018), w.gold, 0)


def assembly_fab(w):
    """An open leadframe line, twin bonders and a separate moulding press."""
    foundation(w)
    fluid_ports(w, (0,))
    w.box('Raised precision process bed', (0, -.12, .70), (3.76, 1.56, .47), w.white, .025)
    for y in (-.63, .40):
        w.box('Indexed leadframe guide', (0, y, .99), (3.80, .075, .10), w.steel)
    with w.part('Leadframe indexing carriage', (0, -.10, 1.01)) as strip:
        track(strip, 'location', 0, [(0, 0), (56, 0), (64, .16), (82, .16), (94, 0), (96, 0)])
        for i in range(7):
            package(w, -1.47+i*.49, 0, 0, i>=5)
            for side in (-1, 1):
                w.box('Leadframe edge strip', (-1.47+i*.49, side*.31, -.015), (.49, .055, .025), w.copper, 0)
    bond_heads = []
    for x in (-.98, .49):
        with w.part('Wire bonder C-frame', (x, .86, 0)):
            w.box('Bonding column shoe', (0, 0, .62), (.56, .75, .30), w.iron)
            w.box('Bonder vertical casting', (0, .14, 1.28), (.31, .38, 1.21), w.white)
            w.box('Overhanging capillary bridge', (0, -.20, 1.88), (.53, 1.03, .22), w.white)
            with w.part('Bonding head slide', (0, -.96, 1.69)) as head:
                bond_heads.append(head)
                track(head, 'location', 0, [(0, -.045), (12, -.045), (20, .045), (28, .045), (36, -.045), (48, .045), (56, .045), (64, 0), (96, -.045)])
                track(head, 'location', 2, [(0, 1.69), (8, 1.40), (14, 1.40), (18, 1.61), (24, 1.40), (30, 1.40), (35, 1.61), (42, 1.40), (49, 1.40), (56, 1.69), (96, 1.69)])
                w.cyl('Capillary head barrel', (0, 0, -.03), .10, .32, w.steel)
                w.cyl('Gold bonding capillary', (0, 0, -.25), .025, .13, w.brass)
                w.box('Bond microscope', (.17, -.035, -.12), (.11, .17, .18), w.iron)
            w.cyl('Bond wire supply hub', (0, .14, 2.13), .16, .18, w.steel, 'X')
            w.ring('Gold wire supply', (.10, .14, 2.13), .12, .025, w.gold, 'X')
    # Output moulding press has a distinct lower, broader silhouette.
    w.box('Package mould lower die', (1.34, -.10, .94), (.72, .81, .11), w.iron)
    for y in (-.54, .37):
        for x in (.95, 1.74):
            w.cyl('Mould press guide post', (x, y, 1.53), .037, 1.03, w.steel)
    w.box('Mould press crosshead', (1.34, -.10, 2.07), (.94, 1.06, .22), w.ochre)
    with w.part('Mould closing platen', (1.34, -.10, 1.73)) as platen:
        track(platen, 'location', 2, [(0, 1.73), (14, 1.73), (24, 1.23), (45, 1.23), (55, 1.73), (96, 1.73)])
        w.box('Upper mould tool', (0, 0, 0), (.70, .75, .18), w.steel)
        w.cyl('Press actuator', (0, 0, .19), .11, .32, w.iron)
    cassette(w, (-1.44, -1.62, .53), 4, .25)
    service(w, (1.44, 1.55, 0), .83, .83)
    w.box('Input die tape tray', (-1.40, 1.55, .70), (.82, .74, .43), w.iron)
    for i in range(4):
        w.box('Die tray pocket row', (-1.65+i*.16, 1.55, .95), (.09, .48, .025), w.black, .001)
    w.pipe('Press pneumatic feed', [(1.77, 1.52, 1.1), (1.98, .84, .70), (1.80, .05, .72)], .045, w.blue)
    for x in (.07, 1.28):
        w.box('Low package transfer tray', (x, -1.67, .57), (.89, .74, .20), w.iron)
        for dx in (-.21, .21):
            for dy in (-.15, .15):
                w.box('Package tray pocket', (x+dx, -1.67+dy, .685), (.30, .23, .03), w.black, .002)
                w.box('Moulded package in output tray', (x+dx, -1.67+dy, .724), (.22, .18, .05), w.steel, .003)
    def check(phase):
        if 56 < phase < 96:
            assert platen.location.z > 1.68, 'Leadframe indexes under a closed mould press'
            assert all(h.location.z > 1.63 for h in bond_heads), 'Leadframe indexes under a lowered bonding head'
    validate_cycle(w, check)
    return [5, 5], .93, 12


def computer_assembler(w):
    """Gantry inserts daughtercards in a backplane/chassis, followed by probe test."""
    foundation(w)
    fluid_ports(w, (0,))
    w.box('Computer assembly table', (0, 0, .69), (2.45, 2.67, .47), w.iron)
    with w.part('Computer chassis work pallet', (0, -.13, .98)) as pallet:
        track(pallet, 'location', 1, [(0, -.13), (65, -.13), (76, .26), (87, .26), (96, -.13)])
        w.box('Backplane substrate', (0, 0, .04), (1.65, 1.69, .055), w.pcb, .004)
        for side in (-1, 1):
            w.box('Open chassis rail', (side*.88, 0, .18), (.10, 1.94, .28), w.steel)
            w.box('Chassis end rail', (0, side*.91, .11), (1.80, .075, .14), w.steel)
        for x in (-.52, -.18, .18, .52):
            w.box('Backplane card connector', (x, .19, .11), (.12, 1.23, .075), w.ivory, .003)
            if x<.2:
                w.box('Installed daughtercard', (x, .19, .42), (.045, 1.13, .55), w.pcb, .003)
                for y in (-.19, .16, .51):
                    w.box('Daughtercard package', (x-.039, y, .44), (.035, .21, .20), w.iron, .003)
        with w.part('Inserted card payload', (.52,.21,.45)) as inserted:
            for axis in range(3):
                w.driver(inserted,'scale',axis,'1 if 48<=((frame-1)%96)<90 else 0')
            w.box('Newly inserted daughtercard',(0,0,0),(.044,.83,.41),w.pcb,.003)
            for y in (-.25,0,.25):
                w.box('Inserted card IC',(-.035,y,0),(.025,.14,.17),w.iron,.002)
        for y in (-.64, .65):
            w.box('Copper power bus', (0, y, .10), (1.47, .045, .025), w.copper, .002)
    for x in (-1.49, 1.49):
        w.box('Gantry foundation', (x, .0, .57), (.41, 3.61, .22), w.iron)
        for y in (-1.54, 1.54):
            w.box('Assembly portal upright', (x, y, 1.52), (.16, .20, 1.96), w.paint)
        w.box('Longitudinal gantry rail', (x, 0, 2.52), (.18, 3.50, .18), w.steel)
    with w.part('Insertion gantry bridge', (0, -.10, 2.55)) as gantry:
        track(gantry, 'location', 1, [(0, -1.13), (17, -1.13), (33, .08), (56, .08), (73, -1.13), (96, -1.13)])
        w.box('Insertion bridge crossbeam', (0, 0, 0), (4.30, .28, .26), w.ochre)
        with w.part('Module insertion carriage', (-.52, 0, -.18)) as head:
            track(head, 'location', 0, [(0, -1.97), (18, -1.97), (32, .52), (57, .52), (75, -1.97), (96, -1.97)])
            track(head, 'location', 2, [(0, -.18), (8, -.59), (17, -.59), (24, -.18), (34, -.18), (43, -.69), (52, -.69), (60, -.18), (96, -.18)])
            w.box('Insertion head casting', (0, 0, -.04), (.43, .42, .31), w.iron)
            for x in (-.12, .12):
                w.box('Parallel card gripping jaw', (x, 0, -.31), (.055, .43, .29), w.steel)
            with w.part('Gripped card payload') as payload:
                for axis in range(3):
                    w.driver(payload,'scale',axis,'1 if 12<=((frame-1)%96)<48 else 0')
                w.box('Handled daughtercard', (0, 0, -.43), (.044, .83, .41), w.pcb, .003)
                for y in (-.25, 0, .25):
                    w.box('Handled card IC', (-.035, y, -.43), (.025, .14, .17), w.iron, .002)
    for x in (-1.97, 1.97):
        w.box('Module magazine plinth', (x, -.48, .65), (.48, 1.93, .40), w.white)
        for y in (-1.12, -.72, -.32, .08):
            if x<0 and y==-1.12:
                with w.part('Next magazine card',(x,y,1.53)) as incoming:
                    for axis in range(3):
                        w.driver(incoming,'scale',axis,'1 if ((frame-1)%96)<12 or ((frame-1)%96)>=90 else 0')
                    w.box('Magazine pickup daughtercard',(0,0,0),(.044,.83,.41),w.pcb,.003)
            else:
                w.box('Vertical card feeder', (x, y, 1.14), (.38, .12, .61), w.pcb, .004)
            w.box('Magazine retention latch', (x, y-.09, .96), (.41, .05, .10), w.ivory, .003)
    service(w, (-1.91, 1.53, 0), .54, .75)
    service(w, (1.91, 1.53, 0), .54, .75)
    w.box('Burn-in test socket bank', (0, 1.65, .80), (1.94, .69, .63), w.white)
    test = lamp(w, 'Successful test indicator', (.11, .61, .25), '(1 if 75<=((frame-1)%96)<89 else 0.02)')
    for i in range(6):
        w.box('Test probe channel', (-.70+i*.28, 1.27, .92), (.12, .035, .22), w.black, .002)
        w.box('Test result lens', (-.70+i*.28, 1.25, 1.10), (.06, .02, .045), test, .002)
    def check(phase):
        if 65 < phase < 96 and abs(head.location.x) < 1.2:
            assert head.location.z > -.20, 'Computer pallet indexes while the insertion head is down'
    validate_cycle(w, check)
    return [5, 5], 1.04, 12


def vlsi_fab(w):
    """Tall precision optics, a stepped exposure stage and reticle exchange services."""
    foundation(w, w.white)
    fluid_ports(w, (-1, 1))
    granite = w.material('Precision granite isolation block', (.11, .14, .15), .12, .73)
    w.box('Lithography isolation mass', (-.29, -.25, .76), (2.65, 2.77, .65), granite, .035)
    for x in (-1.24, .66):
        w.box('Optical bridge column', (x, .79, 1.94), (.35, .47, 2.44), w.white, .025)
    w.box('Precision optical bridge', (-.29, .79, 3.20), (2.42, .87, .35), w.white, .04)
    # Stepped concentric optics are not a recolor of the low three-pod wafer tool.
    for z, radius, depth, material in [(2.84, .49, .38, w.iron), (2.48, .40, .39, w.white), (2.16, .29, .27, w.steel)]:
        w.cyl('Projection lens barrel', (-.29, .20, z), radius, depth, material)
        w.ring('Lens alignment collar', (-.29, .20, z-depth/2), radius+.025, .026, w.iron)
    aperture = lamp(w, 'Contained exposure aperture', (.27, .55, .68),
                    '(1 if 24<=((frame-1)%96)<34 or 44<=((frame-1)%96)<54 or 64<=((frame-1)%96)<74 else 0)', 1.6)
    w.cyl('Exposure aperture lens', (-.29, .20, 1.99), .18, .025, aperture)
    for x in (-.98, .38):
        w.box('Wafer stage precision rail', (x, -.22, 1.15), (.10, 1.75, .12), w.steel)
    with w.part('Precision wafer XY stage', (-.29, -.22, 1.25)) as stage:
        track(stage, 'location', 0, [(0, -.54), (19, -.54), (23, -.46), (34, -.46), (43, -.13), (54, -.13), (63, -.46), (75, -.46), (88, -.54), (96, -.54)])
        track(stage, 'location', 1, [(0, -.66), (19, -.66), (23, .02), (54, .02), (63, -.10), (75, -.10), (88, -.66), (96, -.66)])
        w.box('Air bearing wafer carriage', (0, 0, 0), (1.12, 1.15, .12), w.iron)
        w.cyl('Vacuum wafer chuck', (0, 0, .10), .49, .10, w.steel)
        wafer(w, 'Exposure wafer', (0, 0, .17), .45)
    with w.part('Reticle cassette tower', (-1.83, -.05, 0)):
        w.box('Reticle storage housing', (0, 0, 1.27), (.50, 1.08, 1.58), w.white)
        for i in range(5):
            w.box('Reticle cartridge', (0, -.03, .69+i*.25), (.43, .95, .15), w.ivory, .005)
            w.box('Reticle cartridge grip', (0, -.54, .69+i*.25), (.21, .07, .07), w.ochre, .003)
    with w.part('Reticle positioning slide', (-.29, .79, 3.48)) as reticle:
        track(reticle, 'location', 0, [(0, -.80), (12, -.29), (81, -.29), (93, -.80), (96, -.80)])
        w.box('Reticle carrier frame', (0, 0, 0), (.78, .65, .09), w.iron)
        w.box('Reticle quartz window', (0, 0, .052), (.53, .41, .019), w.blue, .001)
    with w.part('Vacuum/temperature service skid', (1.61, -.09, 0)):
        w.box('Service skid mass', (0, 0, .78), (.93, 2.15, .62), w.paint)
        for y in (-.65, 0, .65):
            w.cyl('Vacuum service canister', (0, y, 1.32), .27, .48, w.steel)
            w.ring('Service canister lock ring', (0, y, 1.58), .28, .026, w.iron)
        gauge(w, (0, -1.10, .92))
    w.pipe('Temperature-stable coolant feed', [(.76, -.78, .94), (1.02, -1.22, .68), (1.64, -1.22, .68), (1.64,-.95,.78)], .05, w.blue)
    w.pipe('Vacuum manifold', [(.82, .83, 1.0), (1.02, 1.22, .70), (1.65, 1.22, .70), (1.65,.85,.78)], .07, w.steel)
    cassette(w, (-1.05, -1.91, .53), 4, .24)
    service(w, (.78, 1.82, 0), .94, .69, w.white)
    def check(phase):
        if 24 <= phase < 34 or 44 <= phase < 54 or 64 <= phase < 74:
            assert math.hypot(stage.location.x+.29, stage.location.y-.20) < .41, 'Exposure aperture misses the wafer'
            expected = (-.46, .02) if phase < 34 else (-.13, .02) if phase < 54 else (-.46, -.10)
            assert abs(stage.location.x-expected[0]) < .0001 and abs(stage.location.y-expected[1]) < .0001, 'Exposure occurs during stage movement'
    validate_cycle(w, check)
    return [5, 5], 1.18, 12
