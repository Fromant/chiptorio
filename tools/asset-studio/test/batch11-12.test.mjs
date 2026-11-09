import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {root} from '../host.mjs';
import {loadRegistry} from '../registry.mjs';

test('batches eleven and twelve retain ten icon targets and reuse machine geometry',async()=>{
 const plan=await loadRegistry(root);
 const expected={
  'batch-11':['cmp-slurry','computer-assembler','construction-core','coolant','cooling-tower'],
  'batch-12':['cooling-unit','cryogen','cryostat','crystal-puller','datacenter-lab']
 };
 for(const [group,names] of Object.entries(expected)){
  const assets=plan.assets.filter(a=>a.group===group);assert.deepEqual(assets.map(a=>a.name),names);
  for(const a of assets){
   assert.equal(a.profile,'image');assert.equal(a.mode,'image');assert.equal(a.render.frames,1);
   assert.equal(a.render.width,64);assert.equal(a.render.height,64);await readFile(path.join(root,a.source.builder));
   assert.deepEqual(a.targets,[{artifact:'image.png',path:`graphics/icons/${a.name}.png`}]);
   const entity=plan.assets.find(e=>e.id==='entity:'+a.name);if(entity)assert.deepEqual(a.source,entity.source);
  }
 }
});
