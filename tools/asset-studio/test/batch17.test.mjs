import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {root} from '../host.mjs';
import {loadRegistry} from '../registry.mjs';

test('batch seventeen keeps five HBM/inference icons with independent 64px targets',async()=>{
 const plan=await loadRegistry(root),assets=plan.assets.filter(a=>a.group==='batch-17');
 assert.deepEqual(assets.map(a=>a.name),['hbm-module','hbm-science','hbm-stack','hbm3-module','inference-lab']);
 for(const a of assets){
  assert.equal(a.profile,'image');assert.equal(a.mode,'image');assert.equal(a.render.frames,1);
  assert.equal(a.render.width,64);assert.equal(a.render.height,64);assert.equal(a.render.samples,64);
  await readFile(path.join(root,a.source.builder));
  for(const dep of a.source.dependencies)await readFile(path.join(root,dep));
  assert.deepEqual(a.targets,[{artifact:'image.png',path:`graphics/icons/${a.name}.png`}]);
 }
 assert.deepEqual(assets.find(a=>a.name==='inference-lab').source,plan.assets.find(a=>a.id==='entity:inference-lab').source);
});
