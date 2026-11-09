import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {root} from '../host.mjs';
import {loadRegistry} from '../registry.mjs';

test('batch ten keeps machine icons tied to entity geometry and die icons distinct',async()=>{
 const plan=await loadRegistry(root),assets=plan.assets.filter(a=>a.group==='batch-10');
 assert.deepEqual(assets.map(a=>a.name),['answer-engine','assembly-fab','bare-die','chiplet','circuit-assembler']);
 for(const a of assets){
  assert.equal(a.profile,'image');assert.equal(a.mode,'image');assert.equal(a.render.frames,1);
  assert.equal(a.render.width,64);assert.equal(a.render.height,64);await readFile(path.join(root,a.source.builder));
  assert.deepEqual(a.targets,[{artifact:'image.png',path:`graphics/icons/${a.name}.png`}]);
  const entity=plan.assets.find(e=>e.id==='entity:'+a.name);
  if(entity)assert.deepEqual(a.source,entity.source);
 }
 assert.notEqual(assets.find(a=>a.name==='bare-die').source.builder,assets.find(a=>a.name==='chiplet').source.builder);
});
