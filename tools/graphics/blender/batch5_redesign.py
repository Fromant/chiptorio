"""Industrial hypercomputing: square facilities, articulated assembly and port bursts.

Only the four revised batch-five machines live here. The approved terminal is not
rebuilt. All props are baked geometry, never runtime items or per-item renderers.
"""
import math
import bpy
from mathutils import Vector


def activity(w, name, color, seed, steady=False, period=96, gate=None):
    """Authored deterministic Ethernet bursts; unlit outside the working state."""
    mat = w.material(name, color, emission=1.8)
    shader = mat.node_tree.nodes.get("Principled BSDF")
    step = f"floor(((frame-1)%{period})/2)"
    pattern = gate or ("1" if steady else f"(1 if (({step}+{seed*7})*17)%31<6 or (({step}+{seed*3})*11)%23<3 else 0.015)")
    for socket, index, expression in [(shader.inputs["Emission Strength"], None, f"working*1.8*{pattern}")] + [
        (shader.inputs["Base Color"], i, f"{c}*(0.015+working*0.985*{pattern})") for i,c in enumerate(color)
    ]:
        curve = socket.driver_add("default_value") if index is None else socket.driver_add("default_value", index)
        variable = curve.driver.variables.new()
        variable.name, variable.type = "working", "SINGLE_PROP"
        variable.targets[0].id_type, variable.targets[0].id = "SCENE", w.scene
        variable.targets[0].data_path = '["working"]'
        curve.driver.expression = expression
    return mat


def ethernet(w, x, y, z, seed, period=96):
    """RJ45-like block: black socket, contact comb and distinct link/activity LEDs."""
    w.box("Shielded Ethernet port", (x,y,z), (.24,.17,.17), w.steel, .008)
    w.box("Recessed black port aperture", (x,y-.091,z), (.18,.015,.105), w.black, .003)
    for pin in range(4):
        w.box("Gold port contact", (x-.057+pin*.038,y-.102,z-.025), (.015,.012,.040), w.gold, 0)
    for dx, color, stable in [(-.078,(.09,.55,.17),True),(.078,(.85,.38,.035),False)]:
        led = activity(w,"Link" if stable else "Packet burst",color,seed,stable,period)
        w.box("Port status lens", (x+dx,y-.10,z+.061), (.035,.015,.025),led,.002)


def package(w, name="Packaged chip", width=.24):
    """Small shared prop: package, substrate and just enough contacts to read."""
    w.box(name+" substrate",(0,0,0),(width,width,.025),w.pcb,.003)
    w.box(name+" lid",(0,0,.037),(width*.72,width*.72,.049),w.iron,.005)
    for side in (-1,1):
        for index in range(4):
            w.box("Chip contact",(-width*.31+index*width*.205,side*width*.46,.005),
                  (width*.10,width*.14,.012),w.gold,0)


def gpu_blade(w, z, top=False):
    w.box("Accelerator blade substrate",(0,0,z),(.98,.65,.035),w.pcb,.004)
    w.box("GPU coldplate",(0,-.02,z+.055),(.46,.45,.065),w.copper,.006)
    for x in (-.35,.35):
        w.box("VRAM bank",(x,0,z+.04),(.16,.48,.055),w.iron,.003)
    w.box("Blade retaining rail",(0,-.38,z+.04),(1.02,.055,.08),w.steel,.004)
    if top:
        for index in range(6):
            w.box("Coldplate fins",(-.19+index*.076,-.02,z+.12),(.025,.44,.065),w.steel,.002)


def training(w):
    w.scene["export_canvas"] = 1024
    w.scene["art_revision"] = 4
    w.base(8.83,w.paint)
    for x in (-.20,.20):
        w.box("Central service aisle edge",(x,0,.445),(.035,8.1,.025),w.ochre,.002)
    for side in (-1,1):
        w.box("Rack plinth bank",(side*2.25,0,.52),(3.05,7.55,.24),w.iron)
        w.pipe("Supply coolant header",[(side*3.98,-3.82,.78),(side*3.98,0,.78),(side*3.98,3.82,.78)],.095,w.blue)
        w.pipe("Return coolant header",[(side*3.72,-3.82,.80),(side*3.72,0,.80),(side*3.72,3.82,.80)],.075,w.copper)
    for row,y in enumerate((-2.85,-1.35,1.35,2.85)):
        for col,x in enumerate((-3.0,-1.5,1.5,3.0)):
            with w.part("GPU cabinet",(x,y,0)):
                w.box("Open cabinet backplane",(0,.39,1.43),(1.13,.09,1.77),w.iron)
                for sx in (-.56,.56):
                    w.box("Load bearing rack upright",(sx,0,1.45),(.075,.86,1.90),w.steel)
                for index in range(6):
                    gpu_blade(w,.77+index*.245, index==5)
                    led=activity(w,"GPU workload status",(.04,.47,.17),row*31+col*7+index,period=48)
                    w.box("Blade activity lens",(.42,-.416,.83+index*.245),(.055,.018,.025),led,.002)
                w.box("Rack top crossbrace",(0,.20,2.40),(1.17,.22,.08),w.paint)
                w.box("Bank number plate",(0,-.39,2.38),(.24,.024,.09),w.ivory,.003)
                w.pipe("Coldplate supply branch",[(.50,.26,.70),(.50,.26,1.50),(.50,.26,2.27)],.027,w.blue)
    for y in (-.70,.70):
        w.box("Overhead fabric bridge",(0,y,2.62),(7.65,.22,.24),w.white)
        for x in (-3.80,3.80):
            w.box("Bridge support column",(x,y,1.48),(.15,.19,2.25),w.steel)
        for index in range(12):
            w.box("Fabric connector bay",(-3.30+index*.60,y-.13,2.62),(.24,.035,.12),w.black,.003)
    for side in range(2):
        with w.part("Cooling plant access",angle=side*math.pi):
            w.box("Plate heat exchanger",(0,-3.83,.91),(1.72,.57,.91),w.paint)
            for index in range(13):
                w.box("Exchanger plate",(-.72+index*.12,-3.83,.99),(.035,.64,.72),w.steel,.002)
            w.box("Pump service block",(1.24,-3.76,.66),(.61,.73,.38),w.iron)
            w.cyl("Pump motor",(1.24,-3.76,.97),.21,.30,w.steel)
            w.fan((1.24,-3.76,1.17),.19,side*.2)
            w.pipe("Plant coolant riser",[(.82,-3.76,.70),(1.6,-3.76,.70),(2.0,-3.76,.80)],.06,w.blue)
            for index in range(3): ethernet(w,-.40+index*.40,-4.20,.57,side*9+index,48)
    # Tall open racks, broad square plant: not a scaled-up circuit board.
    return 9,1.10,16


def inference(w):
    w.scene["export_canvas"],w.scene["animation_period"] = 1024,64
    w.scene["art_revision"] = 4
    navy=w.material("Serving-bank enamel",(.10,.17,.20),.46,.40)
    w.base(6.83,w.white)
    w.box("Central model-store footing",(0,0,.60),(2.12,2.12,.40),w.iron)
    w.box("Model-store central spine",(0,0,1.83),(.70,.70,2.50),w.steel)
    for side in range(4):
        with w.part("Model cartridge library",angle=side*math.pi/2):
            for tier in range(6):
                z=.95+tier*.34
                w.box("Model cartridge housing",(0,-.63,z),(1.33,.63,.23),navy)
                w.box("Cartridge ceramic fascia",(0,-.97,z),(1.12,.045,.17),w.white)
                for x in (-.45,.45):
                    w.box("Cartridge latch",(x,-1.01,z),(.055,.034,.12),w.ochre,.003)
                lamp=activity(w,"Resident model access",(.08,.47,.40),side*13+tier,period=64)
                w.box("Model access indicator",(0,-1.01,z),(.25,.025,.025),lamp,.002)
            w.box("Library guide rail",(.77,-1.16,1.82),(.08,.12,2.60),w.steel)
            with w.part("Model selector carriage",(.77,-1.20,1.82)) as carriage:
                w.driver(carriage,"location",2,"1.82+0.68*sin(2*pi*(frame-1)/64)")
                w.box("Model-address selector",(-.13,0,0),(.34,.27,.18),w.ochre)
            with w.part("Serving pod",(0,-2.37,0)):
                w.box("Serving cabinet",(0,0,1.05),(1.75,.88,1.22),navy)
                w.box("Exposed memory-plane recess",(0,-.45,1.10),(1.48,.045,.94),w.black)
                for bank in range(5):
                    x=-.57+bank*.285
                    w.box("Vertical serving blade",(x,-.49,1.10),(.18,.065,.82),w.steel,.005)
                    w.box("Memory-package strip",(x,-.535,1.10),(.10,.035,.57),w.iron,.003)
                w.box("Pod lid spreader",(0,0,1.73),(1.78,.95,.13),w.steel)
                for fin in range(9):
                    w.box("Passive heat-transfer rib",(-.70+fin*.175,0,1.86),(.035,.83,.14),w.steel,.003)
                for port in range(3): ethernet(w,-.45+port*.45,-.48,.66,side*11+port,64)
            w.pipe("Serving fabric trunk",[(-.45,-1.02,.70),(-.45,-1.58,.70),(-.45,-2.10,.72)],.045,w.ivory)
            w.pipe("Serving coolant return",[(.56,-1.05,.60),(.56,-1.65,.60),(.56,-2.40,.71)],.055,w.copper)
    w.box("Library roof cap",(0,0,3.04),(1.85,1.85,.16),w.white)
    for side in range(4):
        with w.part("Corner power service",angle=side*math.pi/2):
            w.box("Power conditioning block",(2.43,-2.43,.65),(.73,.73,.45),w.iron)
            for index in range(5):
                w.box("Power conditioning fin",(2.19+index*.12,-2.43,.94),(.035,.64,.18),w.steel,.003)
    return 7,1.20,16


def path_point(phase):
    # Explicit feed/grab/lift/place/dwell/return poses, not a sinusoidal wiggle.
    poses=[(0,(-1.25,-.80,1.65)),(10,(-1.20,-1.47,1.04)),(18,(-1.20,-1.47,1.04)),
           (28,(-.95,-1.05,1.95)),(40,(-.35,-.35,1.56)),(48,(-.35,-.35,.87)),
           (58,(-.35,-.35,.87)),(68,(-.35,-.35,1.74)),(82,(-1.25,-.80,1.85)),
           (96,(-1.25,-.80,1.65))]
    for (a,p),(b,q) in zip(poses,poses[1:]):
        if a<=phase<=b:
            t=(phase-a)/(b-a);t=t*t*(3-2*t)
            return tuple(u+(v-u)*t for u,v in zip(p,q))
    return poses[0][1]


def robot(w,side):
    base=Vector((-1.85*side,0,1.02)); length=1.25
    w.cyl("Anchored robot pedestal",(base.x,base.y,.69),.40,.55,w.iron)
    for bolt in range(6):
        a=bolt*math.tau/6
        w.bolt((base.x+.31*math.cos(a),base.y+.31*math.sin(a),.98))
    with w.part("Robot azimuth turret",base) as turret:
        w.cyl("Turret bearing",(0,0,0),.29,.20,w.steel)
        with w.part("Shoulder hinge",(0,0,.10)) as shoulder:
            w.cyl("Shoulder trunnion",(0,0,0),.21,.40,w.steel,"Y")
            w.box("Cast upper arm",(length/2,0,0),(length,.28,.28),w.ochre,.035)
            for sy in (-1,1):
                w.box("Recessed upper-arm service plate",(length*.51,sy*.148,0),(.67,.022,.13),w.iron,.006)
                for x in (.29,.94): w.bolt((x,sy*.165,0),"Y")
            w.cyl("Upper hydraulic barrel",(length*.48,-.21,0),.065,length*.65,w.steel,"X")
            with w.part("Elbow hinge",(length,0,0)) as elbow:
                w.cyl("Elbow pin",(0,0,0),.19,.43,w.steel,"Y")
                w.box("Forged forearm",(length/2,0,0),(length,.22,.23),w.paint,.025)
                w.box("Forearm cable conduit",(length/2,.15,0),(length*.82,.065,.08),w.black,.01)
                w.pipe("Arm vacuum line",[(.16,-.16,.04),(.50,-.16,.04),(1.12,-.16,.04)],.022,w.blue)
                with w.part("Vertical placement wrist",(length,0,0)) as wrist:
                    w.cyl("Wrist actuator",(0,0,-.03),.12,.24,w.steel)
                    w.box("Vacuum gripper",(0,0,-.20),(.28,.24,.11),w.iron)
                    for x in (-.095,.095):
                        w.box("Gripper jaw",(x,0,-.28),(.035,.20,.10),w.steel,.004)
                    phase_offset=0 if side==1 else 48
                    lamp=activity(w,"Placement vision flash",(.10,.65,.26),side,period=96,
                                  gate=f"(1 if 45<=((frame-1+{phase_offset})%96)<57 else 0)")
                    w.box("Placement inspection lens",(0,-.13,-.23),(.085,.018,.030),lamp,.003)
                    with w.part("Carried component",(0,0,-.35)) as carried:
                        package(w,width=.24)
    for frame in range(1,98):
        phase=((frame-1)+(0 if side==1 else 48))%96
        p=Vector(path_point(phase));p.x*=side;p.y*=side
        # End wrist is above the component; the base's shoulder is 0.1 higher.
        delta=p+Vector((0,0,.35))-(base+Vector((0,0,.10)))
        radial=math.hypot(delta.x,delta.y);distance=delta.length
        theta=math.atan2(delta.z,radial)+math.acos(max(-1,min(1,distance/(2*length))))
        phi=-math.acos(max(-1,min(1,(distance*distance-2*length*length)/(2*length*length))))
        turret.rotation_euler.z=math.atan2(delta.y,delta.x)
        shoulder.rotation_euler.y=-theta;elbow.rotation_euler.y=-phi
        wrist.rotation_euler.y=theta+phi
        for obj in (turret,shoulder,elbow,wrist): obj.keyframe_insert("rotation_euler",frame=frame)
        # A nonzero hidden scale keeps rigid mesh batching invertible.
        carried.scale=(1,1,1) if 17<=phase<53 else (.001,.001,.001)
        carried.keyframe_insert("scale",frame=frame)
    w.scene["robot_path_samples"] = 97


def circuit_assembler(w):
    w.scene["export_canvas"],w.scene["animation_period"] = 768,96
    w.scene["art_revision"] = 4
    w.base(4.83,w.paint)
    w.box("Recessed assembly well",(0,0,.52),(2.12,2.12,.16),w.black)
    w.box("Tooling bed",(0,0,.65),(1.88,1.88,.13),w.steel)
    for x in (-.70,.70):
        w.box("PCB shuttle guide rail",(x,.25,.72),(.11,2.70,.10),w.steel,.012)
    with w.part("Indexed PCB shuttle",(0,0,.79)) as shuttle:
        for frame in range(1,98):
            phase=(frame-1)%96
            # Index only after placement; return before the other arm descends.
            shuttle.location.y=.62*math.sin(math.pi*(phase-65)/22)**2 if 65<=phase<=87 else 0
            shuttle.keyframe_insert("location",frame=frame)
        w.box("PCB workpiece",(0,0,0),(1.27,1.27,.04),w.pcb,.005)
        for row in range(4):
            for col in range(4):
                w.box("Copper placement pads",(-.45+col*.30,-.45+row*.30,.025),(.17,.12,.008),w.gold,0)
        for x,y in ((-.35,-.35),(.35,.35)):
            with w.part("Seated component",(x,y,.04)): package(w,width=.24)
    for side in (1,-1):
        robot(w,side)
        with w.part("Component magazine",angle=0 if side==1 else math.pi):
            w.box("Cassette feeder body",(-1.20,-1.48,.73),(.72,.69,.49),w.iron)
            w.box("Indexed component tray",(-1.20,-1.48,1.00),(.60,.57,.065),w.steel)
            for x in (-.18,.18):
                with w.part("Magazine component",(-1.20+x,-1.48,1.04)): package(w,width=.20)
            w.box("Cassette release latch",(-1.20,-1.87,.77),(.29,.12,.09),w.ochre)
        for x in (-.77,.77):
            with w.part("Pneumatic work clamp",(x,side*.60,.88)) as clamp:
                for frame in range(1,98):
                    phase=(frame-1)%96
                    def window(p):
                        t=min(1,max(0,(p-41)/4))*min(1,max(0,(60-p)/4))
                        return t*t*(3-2*t)
                    closed=max(window(phase),window((phase+48)%96))
                    clamp.location.x=x-math.copysign(.08*closed,x)
                    clamp.keyframe_insert("location",frame=frame)
                w.box("Fixture clamp jaw",(0,0,0),(.20,.23,.12),w.steel)
    for side in range(4):
        with w.part("Cell perimeter services",angle=side*math.pi/2):
            w.box("Service access panel",(0,-2.12,.62),(1.38,.30,.40),w.paint)
            w.pipe("Compressed-air manifold",[(-.65,-2.13,.87),(0,-2.13,.87),(.65,-2.13,.87)],.035,w.blue)
            for index in range(4):
                w.box("Service panel vent",(-.40+index*.27,-2.28,.66),(.12,.015,.055),w.black,.002)
    for side in (1,-1):
        with w.part("Pneumatic power pack",(1.78*side,-1.58*side,0),0 if side==1 else math.pi):
            w.box("Regulator plinth",(0,0,.62),(.61,.68,.37),w.iron)
            for x in (-.13,.13):
                w.cyl("Air accumulator",(x,0,.96),.10,.43,w.steel)
                w.cyl("Accumulator cap",(x,0,1.20),.115,.045,w.copper)
            w.pipe("Compressed-air service riser",[(.21,0,.88),(.29,0,.88),(.29,.32,.66)],.025,w.blue)
    return 5,1.0,12


def monitor(w):
    w.scene["export_canvas"],w.scene["animation_period"] = 512,96
    w.scene["art_revision"] = 4
    navy=w.material("Network instrument enamel",(.075,.16,.19),.45,.40)
    w.base(2.83,navy)
    w.box("Instrument chassis",(0,0,.58),(2.49,2.49,.37),navy)
    w.box("Raised topology-map frame",(0,0,.82),(1.88,1.88,.13),w.steel)
    w.box("Dark etched topology map",(0,0,.90),(1.69,1.69,.045),w.black)
    for row in range(4):
        y=-.60+row*.40
        w.box("Passive subnet bus",(0,y,.927),(1.40,.018,.006),w.pcb,0)
        for col in range(4):
            x=-.60+col*.40
            w.box("Endpoint tile",(x,y,.93),(.12,.12,.008),w.steel,.002)
            lamp=activity(w,"Endpoint traffic",(.04,.47,.24),row*13+col*5)
            w.box("Endpoint packet LED",(x,y,.942),(.045,.045,.008),lamp,.001)
            if row<3:w.box("Subnet bridge trace",(x,y+.20,.928),(.018,.38,.005),w.blue,0)
    for side in range(4):
        with w.part("Four-sided network patch bay",angle=side*math.pi/2):
            for port in range(4): ethernet(w,-.48+port*.32,-1.17,.68,side*19+port*7)
            w.box("Port bank label",(0,-1.16,.83),(.60,.055,.035),w.ivory,.002)
    return 3,.65,8


BUILDERS={"training-cluster":training,"inference-lab":inference,
          "circuit-assembler":circuit_assembler,"network-monitor":monitor}
