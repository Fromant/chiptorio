"""Read-only geometry inspection: sampled multi-view renders and mesh contacts.

These are diagnostic images, never shipping sprites or a publication approval.
Surface intersections are leads for inspection, not an automatic collision verdict.
"""
import json
import math
import sys
import time
import runpy
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

cfg = json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text(encoding='utf-8'))
bpy.ops.wm.open_mainfile(filepath=cfg['model'])
s = bpy.context.scene
out = Path(cfg['output'])
out.mkdir(parents=True, exist_ok=True)
period = int(s.get('animation_period', s.frame_end))
phases = sorted(set(list(range(0,period,16))+[0, period-1]+[int(m.frame)-1 for m in s.timeline_markers]+
                    [int(m.frame)+3 for m in s.timeline_markers if m.frame+3<=period]))

def moving_group(o):
    groups = []
    while o:
        a = o.animation_data
        if a and (a.action or any(c.driver.expression not in ('1','1.0') for c in a.drivers)):
            groups.append(o.name)
        o = o.parent
    return groups[-1] if groups else None

meshes = [o for o in s.objects if o.type == 'MESH' and o.name != 'Shadow Plane' and not o.get('diagnostic_nonphysical')]
groups = {o.name:moving_group(o) for o in meshes}
static = {}
contacts = {}
part_names = json.loads(s.get('diagnostic_part_names','[]'))
deps = bpy.context.evaluated_depsgraph_get()
def geometry(o):
    e = o.evaluated_get(deps)
    mesh = e.to_mesh()
    vertices = [e.matrix_world @ v.co for v in mesh.vertices]
    mesh.calc_loop_triangles()
    faces = [tuple(t.vertices) for t in mesh.loop_triangles]
    attribute = mesh.attributes.get('asset_part')
    labels = [part_names[attribute.data[t.polygon_index].value] if attribute else o.name for t in mesh.loop_triangles]
    part_bounds = {}
    for face,label in zip(faces,labels):
        points = [vertices[i] for i in face]
        lo = Vector(tuple(min(v[i] for v in points) for i in range(3)))
        hi = Vector(tuple(max(v[i] for v in points) for i in range(3)))
        if label in part_bounds:
            a,b=part_bounds[label]
            lo=Vector(tuple(min(a[i],lo[i]) for i in range(3)))
            hi=Vector(tuple(max(b[i],hi[i]) for i in range(3)))
        part_bounds[label]=(lo,hi)
    e.to_mesh_clear()
    lo = Vector(tuple(min(v[i] for v in vertices) for i in range(3)))
    hi = Vector(tuple(max(v[i] for v in vertices) for i in range(3)))
    # Ignore collapsed process details and sub-floor resupply mechanisms here.
    tree = BVHTree.FromPolygons(vertices, faces,all_triangles=True) if min(hi-lo)>.0001 else None
    return lo, hi, tree, labels, part_bounds

started=time.monotonic()
print('STAGE: CPU geometry/contact checks (not image rendering)',flush=True)
for phase in range(period):
    s.frame_set(phase+1)
    deps.update()
    current = {}
    for o in meshes:
        if not groups[o.name] and o.name in static:
            current[o.name] = static[o.name]
        else:
            current[o.name] = geometry(o)
            if not groups[o.name]:static[o.name] = current[o.name]
    for i,a in enumerate(meshes):
        for b in meshes[i+1:]:
            ga,gb=groups[a.name],groups[b.name]
            if ga==gb or (ga is None and gb is None):continue
            alo,ahi,at,alabels,abounds=current[a.name];blo,bhi,bt,blabels,bbounds=current[b.name]
            overlap=Vector(tuple(min(ahi[k],bhi[k])-max(alo[k],blo[k]) for k in range(3)))
            if min(overlap)<.002 or min(ahi.z,bhi.z)<.45 or at is None or bt is None:continue
            hits=at.overlap(bt)
            if hits:
                pairs=set((alabels[x],blabels[y]) for x,y in hits)
                for aname,bname in pairs:
                    a0,a1=abounds[aname];b0,b1=bbounds[bname]
                    depth=min(min(a1[k],b1[k])-max(a0[k],b0[k]) for k in range(3))
                    if depth<.002 or min(a1.z,b1.z)<.45:continue
                    key=aname+' | '+bname
                    record=contacts.setdefault(key,{'a':aname,'b':bname,'groupA':ga,'groupB':gb,'phases':[],'maxAabbOverlap':0})
                    if phase not in record['phases']:record['phases'].append(phase)
                    record['maxAabbOverlap']=max(record['maxAabbOverlap'],round(depth,4))

scan_seconds=time.monotonic()-started
s.render.engine = 'CYCLES'
device=runpy.run_path(cfg['gpuHelper'])['configure_device'](s)
s.cycles.samples=8
s.cycles.use_denoising=True
s.render.use_persistent_data=True
render_started=time.monotonic()
print('STAGE: GPU diagnostic image rendering',flush=True)
s.render.resolution_x = s.render.resolution_y = cfg.get('size',384)
s.render.resolution_percentage = 100
s.render.image_settings.file_format = 'PNG'
s.render.film_transparent = False
s.display.shading.light = 'STUDIO'
s.display.shading.color_type = 'MATERIAL'
s.display.shading.show_shadows = True
s.display.shading.show_cavity = True
s.display.shading.cavity_type = 'BOTH'
s.display.shading.show_specular_highlight = True
s.display.shading.background_type = 'WORLD'
s.world.color = (.06,.07,.08)
s.view_settings.view_transform = 'Standard'
for o in s.objects:
    if o.name=='Shadow Plane':o.hide_render = True
camera=s.camera
camera.data.type='ORTHO'
camera.data.ortho_scale=6.2
target=Vector((0,0,1.1))
views={'game':(0,-9,10.1),'front':(0,-10,1.4),'left':(-10,0,1.4),
       'right':(10,0,1.4),'rear':(0,10,1.4),'top':(0,0,11.1)}
views['detail']=(3,-7,4)
detail_targets={'wafer-fab':(0,-.4,1.15),'computer-assembler':(-.3,-.25,1.6),
                'assembly-fab':(0,-.4,1.3),'crystal-puller':(.4,-.12,2.1),'vlsi-fab':(0,.3,2.0)}
images=[]
for view,position in views.items():
    aim=Vector(detail_targets.get(s.get('asset_name'),(0,0,1.1))) if view=='detail' else target
    camera.data.ortho_scale=3.9 if view=='detail' else 6.2
    camera.location=position
    camera.rotation_euler=(aim-camera.location).to_track_quat('-Z','Y').to_euler()
    for phase in phases:
        s.frame_set(phase+1)
        file=f'{view}-{phase:03}.png'
        s.render.filepath=str(out/file)
        bpy.ops.render.render(write_still=True)
        images.append({'view':view,'phase':phase,'file':file})
report={'name':s.get('asset_name'),'period':period,'phases':phases,'images':images,
        'render_device':device,'timings':{'cpu_geometry_seconds':scan_seconds,'gpu_render_seconds':time.monotonic()-render_started},
        'contacts':sorted(contacts.values(),key=lambda c:(-len(c['phases']),-c['maxAabbOverlap'])),
        'note':'Surface intersections need review: mounted joints, supports and intentional enclosure occlusion are included.'}
(out/'report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('DIAGNOSTIC PASS',s.get('asset_name'),len(images),'images;',len(contacts),'contact pairs')
