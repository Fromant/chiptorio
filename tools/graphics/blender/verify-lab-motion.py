"""Validate native working cycles without rendering; run against each saved lab."""
import bpy

scene = bpy.context.scene
assert scene.get("concept_revision") == 3
assert scene.get("layout") in {"fourfold non-facing", "bilateral non-facing"}
period = scene.get("animation_period")
assert period in {48, 64, 96}
assert scene.camera.data.ortho_scale == scene.render.resolution_x/64, "Saved camera must match the fixed game export"
footprints = {"analytical-engine": [4, 2], "metrology-lab": [3, 3], "answer-engine": [5, 5]}
footprints.update({"training-cluster": [9, 9], "inference-lab": [7, 7],
                   "circuit-assembler": [5, 5], "network-monitor": [3, 3], "qln-terminal": [1, 1]})
for name in ("foup-dock", "wireless-access-point", "qln-import-node", "qln-export-node", "qln-provider-node",
             "qln-requester-node"):
    footprints[name] = [1, 1]
assert list(scene["footprint_tiles"]) == footprints.get(scene["asset_name"], [2, 2])
objects = [obj for obj in bpy.data.objects if obj.type == "MESH"]


def snapshot(frame):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    matrices = [tuple(value for row in obj.matrix_world for value in row) for obj in objects]
    emission = [mat.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value
                for mat in bpy.data.materials if mat.use_nodes and mat.node_tree.nodes.get("Principled BSDF")]
    return matrices, emission


start, moving, end = snapshot(1), snapshot(1+period//4), snapshot(1+period)
max_error = max(abs(a-b) for first, last in zip(start[0], end[0]) for a, b in zip(first, last))
assert max_error < 0.0001, f"Geometry loop hitch: {max_error}"
assert max(abs(a-b) for a, b in zip(start[1], end[1])) < 0.0001, "Emission loop hitch"
changed = sum(any(abs(a-b) > .0001 for a, b in zip(first, second))
              for first, second in zip(start[0], moving[0]))
light_changes = sum(abs(a-b) > .0001 for a, b in zip(start[1], moving[1]))
if scene.get("light_only", scene["asset_name"] in {"tube-mainframe", "cryostat"}):
    assert changed == 0, "Light-only machine must not have moving geometry"
    assert light_changes > 0, "Working lights are frozen"
else:
    assert changed > 0, "Working animation has no moving geometry"
if scene["asset_name"] == "circuit-assembler":
    assert scene.get("robot_path_samples") == 97, "Robot cycle must have sampled kinematics"
    assert not any("fan" in obj.name.lower() or "reel" in obj.name.lower() for obj in objects), "Assembler must not contain fans or ambiguous reels"
    # Check the complete swept floor envelope, not just an attractive rest pose.
    from mathutils import Vector
    shoulders = [o for o in scene.objects if o.type == "EMPTY" and o.name.startswith("Shoulder hinge")]
    shuttle = next(o for o in scene.objects if o.type == "EMPTY" and o.name.startswith("Indexed PCB shuttle"))
    clamps = [o for o in scene.objects if o.type == "EMPTY" and o.name.startswith("Pneumatic work clamp")]
    assert len(shoulders) == 2, "Expected two articulated robot arms"
    def segment_distance(p, q, a, b):
        u, v, r = q-p, b-a, p-a
        uu, vv, uv, ur, vr = u.dot(u), v.dot(v), u.dot(v), u.dot(r), v.dot(r)
        denominator = uu*vv-uv*uv
        s = min(1,max(0,(uv*vr-ur*vv)/denominator)) if abs(denominator) > 1e-8 else 0
        t = (uv*s+vr)/vv
        if t < 0: t=0; s=min(1,max(0,-ur/uu))
        elif t > 1: t=1; s=min(1,max(0,(uv-ur)/uu))
        return (p+s*u-a-t*v).length
    for frame in range(1, period+2):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        phase=(frame-1)%period
        if shuttle.location.y > .001:
            assert all(abs(c.location.x) > .76 for c in clamps), "PCB shuttle moves while clamps are closed"
        if any(45 <= p <= 58 for p in (phase,(phase+48)%96)):
            assert abs(shuttle.location.y) < .001, "PCB shuttle moves during component placement"
        arms=[]
        for shoulder in shoulders:
            elbow=next(o for o in shoulder.children if o.name.startswith("Elbow hinge"))
            wrist=next(o for o in elbow.children if o.name.startswith("Vertical placement wrist"))
            p,q,r=(o.matrix_world.translation.copy() for o in (shoulder,elbow,wrist))
            arms.append(((p,q),(q,r)))
        for left in arms[0]:
            for right in arms[1]:
                assert segment_distance(*left,*right) > .35, f"Robot arms intersect at frame {frame}"
        for obj in objects:
            if any(col.name == "Reference" for col in obj.users_collection):
                continue
            for corner in obj.bound_box:
                point = obj.matrix_world @ Vector(corner)
                assert abs(point.x) <= 2.51 and abs(point.y) <= 2.51, f"Robot cell leaves footprint at frame {frame}: {obj.name} {tuple(point)}"
if scene["asset_name"] == "inference-lab":
    for carriage in (o for o in scene.objects if o.name.startswith("Model selector carriage")):
        assert carriage.location.y + .27/2 < -1.027, "Model selector intersects cartridge fascia/latches"
if scene.get("art_revision") == 4:
    leds = [m.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"]
            for m in bpy.data.materials if m.name.startswith("Packet burst")]
    if leds:
        patterns = [[] for _ in leds]
        for frame in range(1, period+1):
            scene.frame_set(frame)
            bpy.context.view_layer.update()
            for pattern, socket in zip(patterns, leds): pattern.append(round(socket.default_value, 3))
        assert len(set(tuple(p) for p in patterns)) > 1, "Ethernet ports blink in lockstep"
        assert any(sum(a != b for a,b in zip(p,p[1:])) >= 4 for p in patterns), "Missing packet bursts"
scene["working"] = 0.0
scene.update_tag()
idle = snapshot(1)
assert max(idle[1]) == 0, "Idle machine still has an emissive bulb"
scene["working"] = 1.0
scene.update_tag()
scene.frame_set(1)
print(f"PASS {scene['asset_name']}: {changed} moving meshes, {light_changes} animated lights; closed loop; idle lights off")
