/** Regression: material batching must preserve keyframed mesh transforms. */
import {mkdtemp,mkdir,cp,writeFile,readFile,rm} from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import assert from 'node:assert/strict';
import {root,detectTools} from './host.mjs';
import {buildAsset} from './build.mjs';
import {atomicJSON,workspacePath} from './registry.mjs';
import {processLog} from './process.mjs';

const fixture=await mkdtemp(path.join(os.tmpdir(),'chiptorio-geometry-'));
try{
  await cp(path.join(root,'tools/graphics/blender'),path.join(fixture,'tools/graphics/blender'),{
    recursive:true,filter:file=>!file.split(path.sep).includes('__pycache__')&&(!path.extname(file)||file.endsWith('.py'))});
  await mkdir(path.join(fixture,'tools/asset-studio'),{recursive:true});
  await cp(path.join(root,'tools/asset-studio/worker.py'),path.join(fixture,'tools/asset-studio/worker.py'));
  await writeFile(path.join(fixture,'tools/graphics/fixture.py'),`def build(w):
    w.base(.8)
    part=w.box('Keyframed mesh actuator',(0,0,.8),(.10,.10,.20),w.steel)
    for frame,x in [(1,-.18),(13,.18),(25,-.18),(37,.18),(49,-.18)]:
        part.location.x=x
        part.keyframe_insert(data_path='location',frame=frame)
    with w.part('Singular visibility parent',(0,0,.6)) as hidden:
        w.driver(hidden,'scale',2,'0 if ((frame-1)%48)<12 else 1')
        w.box('Hidden detail A',(-.10,0,.1),(.05,.05,.05),w.gold)
        w.box('Hidden detail B',(.10,0,.1),(.05,.05,.05),w.gold)
    return [1,1], .65, 4
`);
  const asset={id:'entity:geometry-fixture',name:'geometry-fixture',group:'fixture',order:0,profile:'entity',mode:'native-crafting',locked:false,
    prototype:{type:'assembling-machine',name:'geometry-fixture'},
    source:{format:'python',builder:'tools/graphics/fixture.py',dependencies:[],placeholder:false},
    render:{frames:4,period:48,footprint:[1,1],samples:8,resolution:512,views:['game']},
    targets:['working.png','idle.png','shadow.png','sprite-def.lua'].map(file=>({artifact:file,path:'graphics/entity/geometry-fixture/'+file}))};
  await atomicJSON(path.join(fixture,'tools/asset-studio/assets.json'),{version:1,groups:[{id:'fixture',batch:1}],assets:[asset]});
  const tools=await detectTools(),job={log:''};
  const built=await buildAsset(fixture,asset,{tools,job,modelOnly:true});
  assert.equal(built.artifacts,undefined);
  const probe=path.join(fixture,'probe.py');
  await writeFile(probe,`import bpy,json
s=bpy.context.scene
o=bpy.data.objects.get('Keyframed mesh actuator')
assert o is not None and o.animation_data and o.animation_data.action, 'Keyframed mesh was merged as static geometry'
s.frame_set(1);bpy.context.view_layer.update();first=o.matrix_world.translation.x
s.frame_set(13);bpy.context.view_layer.update();second=o.matrix_world.translation.x
assert abs(first+.18)<.00001 and abs(second-.18)<.00001, 'Compiled actuator no longer follows authored transforms'
assert 'Keyframed mesh actuator' in json.loads(s['diagnostic_part_names'])
assert o.data.attributes.get('asset_part') is not None
for name,x in [('Hidden detail A',-.10),('Hidden detail B',.10)]:
    part=bpy.data.objects.get(name)
    assert part is not None, 'Collapsed siblings were joined through a singular parent matrix'
    assert abs(part.matrix_world.translation.x-x)<.00001 and abs(part.matrix_world.translation.z-.7)<.00001
print('GEOMETRY REGRESSION PASS: saved keyframes and source-part labels survived batching')
`);
  const log=path.join(fixture,'probe.log');
  await processLog(tools.blender,['-b',path.join(workspacePath(fixture),built.details.model),'--python-exit-code','1','-P',probe],{cwd:fixture,log});
  assert.match(await readFile(log,'utf8'),/GEOMETRY REGRESSION PASS/);
  console.log('Saved-model geometry regression PASS; no production art or renders changed');
}finally{
  const resolved=path.resolve(fixture),temporaryRoot=path.resolve(os.tmpdir())+path.sep;
  if(!resolved.startsWith(temporaryRoot))throw new Error('Fixture cleanup escaped temporary directory');
  await rm(resolved,{recursive:true,force:true});
}
