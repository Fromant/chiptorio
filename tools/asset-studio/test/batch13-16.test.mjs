import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {root} from '../host.mjs';
import {loadRegistry} from '../registry.mjs';

test('batches thirteen through sixteen stage twenty independent 64px icons',async()=>{
 const plan=await loadRegistry(root),groups=['batch-13','batch-14','batch-15','batch-16'];
 const assets=plan.assets.filter(a=>groups.includes(a.group));assert.equal(assets.length,20);
 assert.equal(new Set(assets.map(a=>a.targets[0].path)).size,20);
 for(const group of groups)assert.equal(assets.filter(a=>a.group===group).length,5);
 for(const a of assets){
  assert.equal(a.profile,'image');assert.equal(a.mode,'image');assert.equal(a.render.frames,1);
  assert.equal(a.render.width,64);assert.equal(a.render.height,64);assert.equal(a.render.samples,64);
  await readFile(path.join(root,a.source.builder));
  for(const dep of a.source.dependencies)await readFile(path.join(root,dep));
  assert.deepEqual(a.targets,[{artifact:'image.png',path:`graphics/icons/${a.name}.png`}]);
  const entity=plan.assets.find(e=>e.id==='entity:'+a.name);if(entity)assert.deepEqual(a.source,entity.source);
 }
});
