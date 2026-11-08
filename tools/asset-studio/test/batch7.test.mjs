import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {root} from '../host.mjs';
import {loadRegistry} from '../registry.mjs';
import {checkBinding} from '../integration.mjs';
test('batch seven uses square footprints, explicit link owners and rotatable native cooling',async()=>{
 const plan=await loadRegistry(root),assets=plan.assets.filter(a=>a.group==='batch-7');
 assert.equal(assets.length,5);
 const sizes={'cooling-tower':7,'quantum-fab':11,'network-switch':3,'network-router':3,'memory-bank':5};
 for(const a of assets){assert.deepEqual(a.render.footprint,[sizes[a.name],sizes[a.name]]);assert.equal(a.source.format,'python');assert.equal(a.locked,false);checkBinding(a);await readFile(path.join(root,a.source.builder));assert.equal(a.render.frames,a.mode==='scripted'?24:96);if(a.mode==='scripted')assert.equal(a.activity,a.name);}
 const cooler=assets.find(a=>a.name==='cooling-tower');assert.equal(cooler.integration.directional,true);assert.equal(cooler.integration.basePipeSprites,true);
 assert.deepEqual(cooler.render.views,['north','east','south','west']);
 const broken=structuredClone(cooler);broken.render.views=['north'];assert.throws(()=>checkBinding(broken),/four cardinal/);
 const raw=JSON.parse(await readFile(path.join(root,'tools/asset-studio/.cache/prototypes.json'),'utf8'));
 for(const a of assets.filter(a=>a.mode==='native-crafting')){
  const original=raw['assembling-machine'][a.name].fluid_boxes.flatMap((b,i)=>b.pipe_connections.map((p,j)=>({box:i+1,connection:j+1,...p})));
  assert.equal(a.integration.fluidPorts.length,original.length);
  for(const [i,p] of a.integration.fluidPorts.entries()){assert.deepEqual(p.from,original[i].position);assert.equal(p.direction,original[i].direction);assert.equal(Math.abs(p.position[1]),sizes[a.name]/2-.5);}
 }
});
